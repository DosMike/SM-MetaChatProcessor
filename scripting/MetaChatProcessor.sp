#define _MetaChatProcessor_

#include <sourcemod>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "22w12a"

public Plugin myinfo = {
	name = "Meta Chat Processor",
	author = "reBane, based on SCP Redux, Chat-Processor and Cider",
	description = "Process chat and allows other plugins to manipulate chat.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

/**
 * As defined in SCP Redux
 */
#define SENDER_WORLD			0
#define MAXLENGTH_NATIVECOLOR	12		//actually 9: \x08rrggbbaa, but for a bit of a buffer, let's say 12
#define MAXLENGTH_COLORTAG		32
#define MAXLENGTH_TRANPHRASE	64
#define MAXLENGTH_INPUT			192 	// Inclues \0. The size of the chat input box is 128. This is a bit longer than the chat box to allow plugins inserting long color namewhen formatting, as those might collapse when parsed.
#define MAXLENGTH_NAME			128		// This is backwards math to get compability.  Sourcemod has it set at 32, but there is room for more.
#define MAXLENGTH_MESSAGE		256		// This is based upon the SDK and the length of the entire message, including tags, name, : etc.

/**
 * Sender flags appear before the chat entry in asterisks: *DEAD*
 * Their purpose is to give more information about the senders status.
 * These are bitflags and can be combined in mcp, even if not originally supported.
 *
 * Note: These flags are for formatting only, the recipients list is still relevant!
 */
enum mcpSenderFlag (<<=1) {
	mcpSenderNone      = 0,
	mcpSenderDead      = 1, /* the sender is currently dead */
	mcpSenderSpectator = 2, /* the sender is specating */
	/* other values should be treated as custom, not invalid */
}

/**
 * Target groups appear in paranthesis before the chat entry: (TEAM)
 * Their purpose is to tell you who can read this message.
 * Ordering is choosen deliberately so GetClientTeam should match spec...team4
 *
 * Note: These flags are for formatting only, the recipients list is still relevant!
 */
enum mcpTargetGroup {
	mcpTargetNone         = 0, /* hide the group */
	mcpTargetSpecator     = 1, /* spectator intern chat, e.g. (Spectator) */
	mcpTargetTeam1        = 2, /* chat for team 1 (index 2), e.g. (Terrorist) */
	mcpTargetTeam2        = 3, /* chat for team 2 (index 3), e.g. (Counter-Terrorist) */
	mcpTargetTeam3        = 4, /* chat for team 3 (index 4) */
	mcpTargetTeam4        = 5, /* chat for team 4 (index 5) */
	mcpTargetTeamSender   = 6, /* sender team, e.g. (TEAM) */
	mcpTargetAll          = 7, /* Non-standard special highlighted /chat or @message, e.g. (ALL) */
	mcpTargetAdmin        = 8, /* Non-standard special admin chat, e.g. (ADMIN) */
	mcpTargetDirect       = 9, /* Non-standard special private message, e.g. (DM) */
	/* other values should be treated as custom, not invalid */
}

enum mcpMessageOption (<<=1) {
	mcpMsgDefault         = 0, // white *flag* and (group), allow colors in name and message. Not that default also means the message gets copied to console
	mcpMsgProcessColors   = 1, //This message should process color templates like {Red} -> intended to give plugins multicolor support
	mcpMsgRemoveColors    = 2, //This message should remove colos including \x07RRGGBB -> intended to clean input
	mcpMsgGrouptagColor   = 4, //This message has a custom group tag color set
	mcpMsgIgnoreNameColor = 8, //The group tag color will replace tag and name color
	mcpMsgNoConsoleCopy   = 16, //The message will only print to chat, and not to console
}

bool g_bUseProtobuf;
bool g_bIsSource2009;
bool g_bIsCSGOColors;

int g_teamColorMode; //use \x03 for author team color or not
char g_teamColors[6][MAXLENGTH_NATIVECOLOR]; //manual team colors for unassigned...team4
int g_msgNameTagCount; //team name tags for msg_format
char g_msgNameTags[4][MAXLENGTH_COLORTAG]; 

char clientNamePrefix[MAXPLAYERS+1][MAXLENGTH_NAME];
char clientChatColor[MAXPLAYERS+1][MAXLENGTH_COLORTAG];

enum mcpCompatibility (<<=1) {
	mcpCompatNone     = 0,
	mcpCompatSCPRedux = 1, // Support for SCP Redux 2.3.0 - https://forums.alliedmods.net/showpost.php?p=2629088&postcount=413
	mcpCompatDrixevel = 2, // Support for Drixevel's Chat Processor - https://forums.alliedmods.net/showthread.php?t=286913
	mcpCompatCiderCP  = 4, // Support for CiderChatProcessor - https://forums.alliedmods.net/showthread.php?p=2646798
}
mcpCompatibility g_compatLevel = mcpCompatNone;
enum mcpTransportMethod (+=1) {
	mcpTransport_SayText, //means SayText*, so SayText2 if applicable
	mcpTransport_PrintToChat, //on drixevels discussion thread unf404 seemd to like this more, will probably break chat filters tho
}
mcpTransportMethod g_messageTransport = mcpTransport_SayText; //how to send message
bool g_fixCompatPostCalls = true; //always call OnChatMessagePost for scp?

enum struct ExternalPhrase {
	Handle plugin;
	char string[MAXLENGTH_TRANPHRASE];
}

enum struct MessageData {
	bool valid;
	bool changed;
	int sender;
	char msg_name[MAXLENGTH_COLORTAG];
	mcpSenderFlag senderflags;
	mcpTargetGroup group;
	mcpMessageOption options;
	char customTagColor[MAXLENGTH_COLORTAG]; //name or literal color
	char sender_name[MAXLENGTH_NAME];
	char sender_display[MAXLENGTH_NAME];
	char message[MAXLENGTH_INPUT];
	
	int recipientCount;
	int recipients[MAXPLAYERS];
	
	void Reset() {
		this.valid = false;
		this.changed = false;
		this.senderflags = mcpSenderNone;
		this.group = mcpTargetNone;
		this.options = mcpMsgDefault;
		int i;
		for (;i<MAXLENGTH_COLORTAG;i++) this.msg_name[i] = this.sender_name[i] = this.customTagColor[i] = this.sender_display[i] = this.message[i] = 0;
		for (;i<MAXLENGTH_NAME;i++) this.sender_name[i] = this.sender_display[i] = this.message[i] = 0;
		for (;i<MAXLENGTH_INPUT;i++) this.message[i] = 0;
		this.recipientCount=0;
	}
	void SetRecipients(ArrayList list) {
		this.recipientCount = 0;
		for (int i=0; i<list.Length; i+=1) {
			int client = list.Get(i);
			if (1<=client<=MaxClients && IsClientInGame(client) && !IsFakeClient(client)) {
				this.recipients[this.recipientCount] = client;
				this.recipientCount += 1;
			}
		}
	}
	void GetRecipients(ArrayList list) {
		list.Clear();
		for (int i; i<this.recipientCount; i+=1) {
			int client = this.recipients[i];
			if (1<=client<=MaxClients && IsClientInGame(client) && !IsFakeClient(client))
				list.Push(client);
		}
	}
}
MessageData g_currentMessage;/** since source engine logic is single-threaded, we can do this, so yea, that's singleton */

/** once the message passed the onMessage forward, it's enqueued here to be re-sent asap 
 * are datapacks better? idk
 */
ArrayList g_processedMessages;
/** Translation keys for mcpTargetGroup that plugins can add to */
ArrayList g_groupTranslations;
/** Translation keys for mcpSenderFlag that plugins can add to */
ArrayList g_senderflagTranslations;

/** module includes that may rely on globals */
#include "MetaChatCommon/utilities.inc"
#include "MetaChatProcessor/utilities.sp"
#include "MetaChatProcessor/pluginapi.sp"
#include "MetaChatProcessor/compat_scpredux.sp"
#include "MetaChatProcessor/compat_drixevel.sp"
#include "MetaChatProcessor/compat_cider.sp"

/* -------------------- Main Plugin Code -------------------- */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bIsCSGOColors = GetEngineVersion() == Engine_CSGO;
	g_bIsSource2009 = IsSource2009();
	if (!g_bIsSource2009 && !g_bIsCSGOColors) SetFailState("This mod is currently not supported");
	
	pluginAPI_register();
}

public void OnCVarChanged_Version(ConVar convar, const char[] oldValue, const char[] newValue) {
	char value[32];
	convar.GetString(value, sizeof(value));
	if (!StrEqual(value, PLUGIN_VERSION)) convar.SetString(PLUGIN_VERSION);
}

public void OnPluginStart() {
	
	g_bUseProtobuf = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf);
	g_processedMessages = new ArrayList(sizeof(MessageData));
	
	ParseConfigs();
	pluginAPI_init();
	
	UserMsg userMessage;
	if ((userMessage = GetUserMessageId("SayText2")) != INVALID_MESSAGE_ID) {
		if (g_bUseProtobuf) HookUserMessage(userMessage, OnUserMessage_SayText2Proto, true);
		else HookUserMessage(userMessage, OnUserMessage_SayText2BB, true);
	//} else if ((userMessage = GetUserMessageId("SayText")) != INVALID_MESSAGE_ID) {
		//SCP only supported dods? maybe add that if people ask for it
	} else {
		LogError("Could not hook chat messages for this game - UserMessage SayText2 invalid");
		SetFailState("This game is currently not supported");
	}
	
	ConVar version = CreateConVar("mcp_version", PLUGIN_VERSION, "MetaChatProcessor Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	version.AddChangeHook(OnCVarChanged_Version);
	OnCVarChanged_Version(version, "", "");
	delete version;
	
}

public Action OnUserMessage_SayText2Proto(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	// collect the message
	Protobuf buf = UserMessageToProtobuf(msg);
	g_currentMessage.Reset();
	g_currentMessage.sender = buf.ReadInt("ent_idx");
	if (!g_currentMessage.sender) return Plugin_Continue;
	g_currentMessage.options = buf.ReadBool("chat") ? mcpMsgDefault : mcpMsgNoConsoleCopy;
	buf.ReadString("msg_name", g_currentMessage.msg_name, sizeof(MessageData::msg_name));
	
	buf.ReadString("params", g_currentMessage.sender_name, sizeof(MessageData::sender_name), 0);
	buf.ReadString("params", g_currentMessage.message, sizeof(MessageData::message), 1);
	
	// replace all control characters with a question mark. not possible through steam, but hacker can do
	int len = strlen(g_currentMessage.sender_name);
	for (int pos; pos<len; pos++) if (g_currentMessage.sender_name[pos] < 0x32) g_currentMessage.sender_name[pos]='?';
	// copy as initial display name
	strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);
	
	for (int reci=0;reci<playersNum;reci++) {
		g_currentMessage.recipients[reci] = players[reci];
		g_currentMessage.recipientCount = playersNum;
	}
	
	ParseMessageFormat(g_currentMessage.msg_name, g_currentMessage.senderflags, g_currentMessage.group);
	g_currentMessage.valid = true;
	return ProcessSayText2();
}
public Action OnUserMessage_SayText2BB(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	// collect the message
	g_currentMessage.Reset();
	g_currentMessage.sender = msg.ReadByte();
	if (!g_currentMessage.sender) return Plugin_Continue;
	g_currentMessage.options = msg.ReadByte() ? mcpMsgDefault : mcpMsgNoConsoleCopy;
	
	msg.ReadString(g_currentMessage.msg_name, sizeof(MessageData::msg_name));
	if (msg.BytesLeft) msg.ReadString(g_currentMessage.sender_name, sizeof(MessageData::sender_name));
	if (msg.BytesLeft) msg.ReadString(g_currentMessage.message, sizeof(MessageData::message));
	
	// replace all control characters with a question mark. not possible through steam, but hacker can do
	int len = strlen(g_currentMessage.sender_name);
	for (int pos; pos<len; pos++) if (g_currentMessage.sender_name[pos] < 0x32) g_currentMessage.sender_name[pos]='?';
	// copy as initial display name
	strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);
	
	for (int reci=0;reci<playersNum;reci++) {
		g_currentMessage.recipients[reci] = players[reci];
		g_currentMessage.recipientCount = playersNum;
	}
	
	ParseMessageFormat(g_currentMessage.msg_name, g_currentMessage.senderflags, g_currentMessage.group);
	g_currentMessage.valid = true;
	return ProcessSayText2();
}

Action ProcessSayText2() {
	Action result;
	
	//primitive pre hook
	result = Call_OnChatMessagePre();
	if (result >= Plugin_Handled) return Plugin_Handled;
	else if (result == Plugin_Changed) g_currentMessage.changed = true;
	
	if (g_currentMessage.options & mcpMsgRemoveColors) {
		RemoveTextColors(g_currentMessage.sender_display, sizeof(MessageData::sender_display), false);
		//^ changes in display name will be picked up later
		g_currentMessage.changed |= RemoveTextColors(g_currentMessage.message, sizeof(MessageData::message), false);
	}
	
	//processing message hooks
	for (int i=-1;i<=1;i++) {
		result = Call_OnChatMessage(i);
		if (result >= Plugin_Handled) return Plugin_Handled;
		else if (result == Plugin_Changed) g_currentMessage.changed = true;
	}
	
	//process colors
	g_currentMessage.changed |= FinalizeChatColors();
	
	result = g_currentMessage.changed ? Plugin_Handled : Plugin_Continue;
	
	g_processedMessages.PushArray(g_currentMessage);
	g_currentMessage.Reset();
	return result;
}

public void OnGameFrame() {
	for (int index; index < g_processedMessages.Length; index++) {
		// pop message
		g_processedMessages.GetArray(index, g_currentMessage);
		g_processedMessages.Erase(index);
		
		// process message
		//if this failes we hopefully threw an error and will continue processing
		//other messages in the next game tick, as this one was already dequeued
		if (g_currentMessage.changed) ResendChatMessage();
		Call_OnChatMessagePost();
	}
}

static void ResendChatMessage() {
	char message[MAXLENGTH_MESSAGE];
	
	ArrayList tFlags = new ArrayList(ByteCountToCells(MAXLENGTH_TRANPHRASE));
	char tGroup[MAXLENGTH_TRANPHRASE];
	char tGroupColor[MAXLENGTH_COLORTAG];
	char sEffectiveName[MAXLENGTH_NAME];
	int template = PrepareChatFormat(tFlags, tGroup, sizeof(tGroup), tGroupColor, sizeof(tGroupColor), sEffectiveName, sizeof(sEffectiveName));
	bool chatFlag = !(g_currentMessage.options & mcpMsgNoConsoleCopy);
	
	for (int i;i<g_currentMessage.recipientCount;i++) {
		int recipient=g_currentMessage.recipients[i];
		if (!recipient) continue;
		
		//because i made the prefixes transalteable, we need to format for every player
		FormatChatMessage(recipient, message, sizeof(message), template, tFlags, tGroup, tGroupColor, sEffectiveName);
		//notify that we just formatted the message
		Action result = Call_OnChatMessageFormatted(recipient, message, sizeof(message));
		if (result >= Plugin_Handled) {
			continue;
		}
		
		//send a single targeted message
		if (g_messageTransport == mcpTransport_PrintToChat) {
			// we could use TextMsg manually to prevent hooking this,
			// but i don't think that's really a problem. 
			PrintToChat(recipient, "%s", message);
		} else {
			//  ok, so a bit about my findings on SayText2:
			//  you could theoretically use a custom format string as message / msg_name
			//  and %s1..%s4 would reference into the repeated params; but i guess the 
			//  client is actually stripping all colors (and probably control chars) from
			//  the parameters to prevent bad user input... guess we're breaking that for
			//  the sake of colors! ;D there also seems to be no harm in having references
			//  in your message if the references are not present, at least in TF2 that
			//  didn't seem to cause any issues and printed %s1 just fine.
			//  The chat field is a bit missleading. A more fitting name for it would be
			//  consoleMirrored, because if true the chat message get's also printed in
			//  the clients console window. Setting chat to false supresses the additional
			//  console output.
			Handle msg = StartMessageOne("SayText2", recipient, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
			if (msg == INVALID_HANDLE) ThrowError("Failed to create SayText2 message");
			if (g_bUseProtobuf) {
				Protobuf buf = UserMessageToProtobuf(msg);
				buf.SetInt("ent_idx", g_currentMessage.sender);
				buf.SetBool("chat", chatFlag);
				buf.SetString("msg_name", message);
				buf.AddString("params", "");
				buf.AddString("params", "");
				buf.AddString("params", "");
				buf.AddString("params", "");
			} else {
				BfWrite buf = UserMessageToBfWrite(msg);
				buf.WriteByte(g_currentMessage.sender);
				buf.WriteByte(chatFlag);
				buf.WriteString(message);
			}
			EndMessage();
		}
	}
	
	delete tFlags;
}

/**
 * The intention of this is to take all this work out of the loop so it's not
 * done for every recipient. The flags won't change anymore so we do it only once.
 * 
 * @param tFlags collect translation phrases for flags [*DEAD*, *SPEC*, ...]
 * @param tGroup collect translation phrase for target group [(TEAM), ...]
 * @param nGroupSz max length
 * @param tGroupColor convert the color name to an actual color code
 * @param nGroupColorSz max length
 * @param sEffectiveName depending on the message options, the display name with or without colors
 * @param nEffectiveNameSz max length
 */
static int PrepareChatFormat(ArrayList tFlags, char[] tGroup, int nGroupSz, char[] sGroupColor, int nGroupColorSz, char[] sEffectiveName, int nEffectiveNameSz) {
	
	for (int i=0, f=g_currentMessage.senderflags; i<32 && i<g_senderflagTranslations.Length && f; i+=1, f>>=1) {
		if ((f&1)==0) continue;
		char buffer[MAXLENGTH_TRANPHRASE];
		if (GetNthPhrase(g_senderflagTranslations, i, buffer, sizeof(buffer))) {
			tFlags.PushString(buffer);
		}
	}
	if (tFlags.Length==0) g_currentMessage.senderflags = mcpSenderNone;
	
	if (g_currentMessage.group <= mcpTargetNone || !GetNthPhrase(g_groupTranslations, g_currentMessage.group, tGroup, nGroupSz)) {
		g_currentMessage.group = mcpTargetNone;
	}
	
	if ((g_currentMessage.options & mcpMsgGrouptagColor)) {
		if (!ParseChatColor(g_currentMessage.customTagColor, sGroupColor, nGroupColorSz, g_currentMessage.sender)) {
			g_currentMessage.options &=~ mcpMsgGrouptagColor; //no color provided
		}
	}
	
	//perform message option transformations, as they are the same for all instances
	if (g_currentMessage.options & mcpMsgProcessColors)
		CFormatColor(g_currentMessage.message, sizeof(MessageData::message), g_currentMessage.sender);
//	else if (g_currentMessage.options & mcpMsgRemoveColors) { //this is now done after pre to clean user input, not this late
//		RemoveTextColors(g_currentMessage.message, sizeof(MessageData::message), false);
//	}

	strcopy(sEffectiveName, nEffectiveNameSz, g_currentMessage.sender_display);
	if (g_currentMessage.options & mcpMsgIgnoreNameColor) {
		//we need to remove all color characters from the possibly tagged display name
		RemoveTextColors(sEffectiveName, nEffectiveNameSz, false);
	}
	
	// returns 0..3 as template index for all combinations
	return (g_currentMessage.senderflags != mcpSenderNone ? 1 : 0) + (g_currentMessage.group != mcpTargetNone ? 2 : 0);
}

static void FormatChatMessage(int client, char[] message, int maxlen, int template, ArrayList tFlags, const char[] tGroup, const char[] tGroupColor, const char[] sEffectiveName) {
	
	char flags[33]; //skip first comma with 1 index
	for (int i=0; i<tFlags.Length; i++) {
		char buffer[64];
		tFlags.GetString(i, buffer, sizeof(buffer));
		Format(flags, sizeof(flags), "%s,%T", flags, buffer, client);
	}
	
	char group[32];
	if (tGroup[0]) {
		FormatEx(group, sizeof(group), "%T", tGroup, client);
	}
	
	//note: formats already specify a color as first char, we don't need to do that
	// but! we still need to fix colors for csgo
	// why? IDK, ask valve https://forums.alliedmods.net/showthread.php?t=193328
	if (g_bIsCSGOColors) {
		switch (template) {
			case 3: FormatEx(message, maxlen, "\x01\x0B%T", "Pattern_SendflagsGroup", client, flags[1], tGroupColor, group, sEffectiveName, g_currentMessage.message);
			case 2: FormatEx(message, maxlen, "\x01\x0B%T", "Pattern_Group", client, tGroupColor, group, sEffectiveName, g_currentMessage.message);
			case 1: FormatEx(message, maxlen, "\x01\x0B%T", "Pattern_Sendflags", client, flags[1], sEffectiveName, g_currentMessage.message);
			case 0: FormatEx(message, maxlen, "\x01\x0B%T", "Pattern_Clean", client, sEffectiveName, g_currentMessage.message);
			default: ThrowError("Message parsing broke");
		}
		CollapseColors(message[2], maxlen-2); //don't optimize away the hack that enables colors
	} else {
		switch (template) {
			case 3: FormatEx(message, maxlen, "%T", "Pattern_SendflagsGroup", client, flags[1], tGroupColor, group, sEffectiveName, g_currentMessage.message);
			case 2: FormatEx(message, maxlen, "%T", "Pattern_Group", client, tGroupColor, group, sEffectiveName, g_currentMessage.message);
			case 1: FormatEx(message, maxlen, "%T", "Pattern_Sendflags", client, flags[1], sEffectiveName, g_currentMessage.message);
			case 0: FormatEx(message, maxlen, "%T", "Pattern_Clean", client, sEffectiveName, g_currentMessage.message);
			default: ThrowError("Message parsing broke");
		}
		//keep the first color from the format message, some games might need that to color at all
		// if the translation file has no color on index 0, returns no offset
		int offset = GetNativeColor(message);
		CollapseColors(message[offset], maxlen-offset);
	}
	
}
/** @return true on changes */
bool FinalizeChatColors() {
	char namePrefix[MAXLENGTH_NAME];
	char displayName[MAXLENGTH_NAME];
	char chatColor[MAXLENGTH_COLORTAG];
	strcopy(namePrefix, sizeof(namePrefix), clientNamePrefix[g_currentMessage.sender]);
	strcopy(displayName, sizeof(displayName), g_currentMessage.sender_display);
	strcopy(chatColor, sizeof(chatColor), clientChatColor[g_currentMessage.sender]);
	
	Action result = Call_OnChatMessageColors(namePrefix, displayName, chatColor);
	if (result >= Plugin_Handled) {
		return false; //handled? ok I wont do anything
	} else if (result == Plugin_Stop) {
		//we say stop prevents coloring, sender_name should have the unformatted name, so check
		strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);
		strcopy(namePrefix, sizeof(namePrefix), "");
		strcopy(chatColor, sizeof(chatColor), "");
		return true;
	}
	bool changed = result == Plugin_Changed;
	
	if (g_currentMessage.options & mcpMsgProcessColors) {
		CFormatColor(namePrefix, sizeof(namePrefix), g_currentMessage.sender);
		CFormatColor(displayName, sizeof(displayName), g_currentMessage.sender);
	}
	char colTagEnd[MAXLENGTH_COLORTAG];
	//was the name formatted? does the name tag spill color onto the name?
	if (StrEqual(g_currentMessage.sender_name, displayName) && !GetStringColor(namePrefix, colTagEnd, sizeof(colTagEnd), true)) {
		//no color for the name at all? add team color
		if (g_teamColorMode==1) {
			FormatEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), "%s%s%s", namePrefix, g_teamColors[GetClientTeam(g_currentMessage.sender)], g_currentMessage.sender_name);
		} else {
			FormatEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), "%s\x03%s", namePrefix, g_currentMessage.sender_name);
		}
		//don't set changed flag here, as that's standard behaviour/colors
	} else { //there's custom formatting going on
		//we only need to concat these two
		FormatEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), "%s%s", namePrefix, displayName);
		changed = true;
	}
	//alright now let's check. normally formats prefix char with the default color, so if we have a color and it's not default, prepend to message
	if (chatColor[0] > 1) {//not empty string, not \x01 color
		Format(g_currentMessage.message, sizeof(MessageData::message), "%s%s", chatColor, g_currentMessage.message);
		changed = true;
	}
	return changed;
}