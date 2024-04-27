#define _MetaChatProcessor_

#include <sourcemod>

// the decision logic in multicolors will slow some aspects a tiny bit.
// if you really wanna squeeze out the last bit of performance for color processing,
// you might want to replace this with the game specific library instead.
// (color.inc for csgo, morecolors.inc for source 2009 games)
// why is this even here? i think processing and more importantly suppressing
// the well known color format codes in the chat processor is an ok option to have.
#include <multicolors>

/* snipets for profiling */
//#include <profiler>
//	Profiler profiler = new Profiler();
//	profiler.Start();

//	profiler.Stop();
//	float time = profiler.Time;
//	float ticks = time * 100.0 / GetTickInterval();
//	PrintToServer("[MCP] Processing took %.3f ms / %f%% ticks", time*1000.0, ticks);
//	delete profiler;

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "24w17a"

public Plugin myinfo = {
	name = "Meta Chat Processor",
	author = "reBane",
	description = "Process chat and allows other plugins to manipulate chat, based on SCP Redux, Chat-Processor and Cider",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=337455"
};

#include "include/metachatprocessor/types.inc"
#define MCP_MAXLENGTH_NATIVECOLOR	12		// actually 10: \x08rrggbbaa\0, but 12 bytes is 3 cells

bool g_bUseProtobuf;
bool g_bIsSource2009;
bool g_bIsCSGOColors;

int g_teamColorMode; //use \x03 for author team color or not
char g_teamColors[6][MCP_MAXLENGTH_NATIVECOLOR]; //manual team colors for unassigned...team4
int g_msgNameTagCount; //team name tags for msg_format
char g_msgNameTags[4][32]; //arbitrary short buffer that can contain a format suffix for msg_name (e.g. _survivor)

char clientNamePrefix[MAXPLAYERS+1][MCP_MAXLENGTH_NAME];
char clientChatColor[MAXPLAYERS+1][MCP_MAXLENGTH_COLORTAG];

enum mcpCompatibility {
	mcpCompatNone      = 0,
	mcpCompatSCPRedux  = (1<<0), // Support for SCP Redux 2.3.0 - https://forums.alliedmods.net/showpost.php?p=2629088&postcount=413
	mcpCompatDrixevel  = (1<<1), // Support for Drixevel's Chat Processor - https://forums.alliedmods.net/showthread.php?t=286913
	mcpCompatCiderCP   = (1<<2), // Support for CiderChatProcessor - https://forums.alliedmods.net/showthread.php?p=2646798
	mcpCompatCCC       = (1<<16), // Support for Custom Chat Colors - https://forums.alliedmods.net/showthread.php?p=1721580
	mcpCompatHexTags   = (1<<17), // Support for HexTags - https://forums.alliedmods.net/showthread.php?p=2566623
	mcpCompatExtFormat = (1<<31), // Support any plugin that consistently applies tags and colors
}
mcpCompatibility g_compatLevel = mcpCompatNone;
enum mcpTransportMethod {
	mcpTransport_SayText = 0, //means SayText*, so SayText2 if applicable
	mcpTransport_PrintToChat = 1, //on drixevels discussion thread unf404 seemd to like this more, will probably break chat filters tho
}
mcpTransportMethod g_messageTransport = mcpTransport_SayText; //how to send message
enum mcpMessageHookMethod {
	mcpHook_UserMessage = 0,
	mcpHook_CommandListener = 1
}
mcpMessageHookMethod g_hookMethod = mcpHook_UserMessage; //how to hook messages
bool g_fixCompatPostCalls = true; //always call OnChatMessagePost for scp?
enum mcpInputSanity {
	mcpInputUnchecked   = 0,
	mcpInputTrimMBSpace = (1<<0), // Trim Multibyte spaces from messages; messages containing only spaces can break chat
	mcpInputStripColors = (1<<1), // Strip native color codes by default (bytes < 32); game actually does this by default, chat-processors didn't
	mcpInputBanNewline  = (1<<2), // NewLines cannot be input without hacked clients. Not in chat, not in console, not with copy paste, not with configs.
}
mcpInputSanity g_sanitizeInput = mcpInputUnchecked;

enum struct ExternalPhrase {
	Handle plugin;
	char string[MCP_MAXLENGTH_TRANPHRASE];
}
enum struct ExternalData {
	Handle plugin;
	any data;
}

enum struct MessageData {
	bool valid;
	bool changed;
	int sender;
	char msg_name[MCP_MAXLENGTH_TRANPHRASE]; //Cstrike_Chat_AllSpec like stuff from resources/game_locale.txt
	mcpSenderFlag senderflags;
	mcpTargetGroup group;
	mcpMessageOption options;
	char customTagColor[MCP_MAXLENGTH_COLORTAG]; //name or literal color
	char sender_name[MCP_MAXLENGTH_NAME]; //should be equal to %N
	char sender_display[MCP_MAXLENGTH_NAME]; //normally ends up as \x03%N
	char message[MCP_MAXLENGTH_INPUT];
	
	ArrayList listRecipients; //other plugins can't close our handle, so we are fine using this
	ArrayList userMessageData; //data bag for other plugins to attach data to the message during processing

	void ClientsToUserIds() {
		if (this.sender!=0)
			this.sender = GetClientUserId(this.sender);
		for (int recipientNo=this.listRecipients.Length-1; recipientNo>=0; recipientNo-=1) {
			int recipientAt = this.listRecipients.Get(recipientNo);
			if (recipientAt==0) continue; //don't touch server recipient, that's always 0
			if (1<=recipientAt<=MaxClients && IsClientConnected(recipientAt))
				this.listRecipients.Set(recipientNo, GetClientUserId(recipientAt));
			else
				this.listRecipients.Erase(recipientNo);
		}
	}
	void UserIdsToClients() {
		if (this.sender!=0) {
			this.sender = GetClientOfUserId(this.sender);
			if (this.sender==0) this.valid = false;
		}
		for (int recipientNo=this.listRecipients.Length-1; recipientNo>=0; recipientNo-=1) {
			int recipientAt = this.listRecipients.Get(recipientNo);
			if (recipientAt==0) continue; //don't touch server recipient, that's always 0
			if ((recipientAt = GetClientOfUserId(recipientAt)) != 0)
				this.listRecipients.Set(recipientNo, recipientAt);
			else
				this.listRecipients.Erase(recipientNo);
		}
	}
	
	void Reset(bool newRecipientsInstace=false) {
		this.valid = false;
		this.changed = false;
		this.senderflags = mcpSenderNone;
		this.group = mcpTargetNone;
		this.options = mcpMsgDefault;
		int i;
		for (;i<MCP_MAXLENGTH_COLORTAG;i++) this.msg_name[i] = this.sender_name[i] = this.customTagColor[i] = this.sender_display[i] = this.message[i] = 0;
		for (;i<MCP_MAXLENGTH_NAME;i++) this.sender_name[i] = this.sender_display[i] = this.message[i] = 0;
		for (;i<MCP_MAXLENGTH_INPUT;i++) this.message[i] = 0;
		if (this.listRecipients==null || newRecipientsInstace) {
			this.listRecipients = new ArrayList();
		} else {
			this.listRecipients.Clear();
		}
		if (this.userMessageData==null || newRecipientsInstace) {
			this.userMessageData = new ArrayList(sizeof(ExternalData));
		} else {
			this.userMessageData.Clear();
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
#include "MetaChatProcessor/strings.sp"
#include "MetaChatProcessor/utilities.sp"
#include "MetaChatProcessor/pluginapi.sp"
#include "MetaChatProcessor/compat_scpredux.sp"
#include "MetaChatProcessor/compat_drixevel.sp"
#include "MetaChatProcessor/compat_cider.sp"
#include "MetaChatProcessor/compat_ccc.sp"
#include "MetaChatProcessor/compat_hextags.sp"

/* -------------------- Main Plugin Code -------------------- */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bIsCSGOColors = GetEngineVersion() == Engine_CSGO;
	g_bIsSource2009 = IsSource2009();
	if (!g_bIsSource2009 && !g_bIsCSGOColors) SetFailState("This mod is currently not supported");

	pluginAPI_register();
	return APLRes_Success;
}

public void OnCVarChanged_Version(ConVar convar, const char[] oldValue, const char[] newValue) {
	char value[32];
	convar.GetString(value, sizeof(value));
	if (!StrEqual(value, PLUGIN_VERSION)) convar.SetString(PLUGIN_VERSION);
}

public void OnPluginStart() {
	
	g_bUseProtobuf = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf);
	g_processedMessages = new ArrayList(sizeof(MessageData));
	
	LoadDataFiles();
	pluginAPI_init();

	switch (g_hookMethod) {
		case mcpHook_UserMessage: {
			UserMsg userMessage;
			if ((userMessage = GetUserMessageId("SayText2")) != INVALID_MESSAGE_ID) {
				if (g_bUseProtobuf)
					HookUserMessage(userMessage, OnUserMessage_SayText2Proto, true);
				else
					HookUserMessage(userMessage, OnUserMessage_SayText2BB, true);
			//} else if ((userMessage = GetUserMessageId("SayText")) != INVALID_MESSAGE_ID) {
				//SCP only supported dods? maybe add that if people ask for it
			} else {
				LogError("Could not hook chat messages for this game - UserMessage SayText2 invalid");
				SetFailState("This game is currently not supported, you might try switching hook mode");
			}
		}
		case mcpHook_CommandListener: {
			if (!CommandExists("say") || !CommandExists("say_team")) {
				LogError("Could not hook chat messages for this game - Commands do not exist");
				SetFailState("This game is currently not supported, you might try switching hook mode");
			}
		}
		default: {
			SetFailState("Invalid value for g_hookMethod");
		}
	}

	ConVar version = CreateConVar("mcp_version", PLUGIN_VERSION, "MetaChatProcessor Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	version.AddChangeHook(OnCVarChanged_Version);
	OnCVarChanged_Version(version, "", "");
	delete version;

}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
	//reset client data very early, so other plugins can load/set their defaults
	// on client connected as usual. I know that this will poke stuff even when
	// the clients cancel their connection attempt, but this is not doing a lot.

	strcopy(clientNamePrefix[client], sizeof(clientNamePrefix[]), ""); //use game default method to color name
	strcopy(clientChatColor[client], sizeof(clientChatColor[]), ""); //whatever the format is using

	if (g_compatLevel & mcpCompatDrixevel)
		mcp_drixevel_client_connect(client);
	return true;
}

public void OnClientDisconnect(int client) {
	if (g_compatLevel & mcpCompatDrixevel)
		mcp_drixevel_client_disconnect(client);
}

public Action OnUserMessage_SayText2Proto(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	// collect the message
	Protobuf buf = UserMessageToProtobuf(msg);
	g_currentMessage.Reset();
	g_currentMessage.sender = buf.ReadInt("ent_idx");
	if (!g_currentMessage.sender) return Plugin_Continue;
	if (IsClientInKickQueue(g_currentMessage.sender)) return Plugin_Stop;
	g_currentMessage.options = buf.ReadBool("chat") ? mcpMsgDefault : mcpMsgNoConsoleCopy;
	//by default the game does not allow colors, we let config decide
	if (g_sanitizeInput & mcpInputStripColors) g_currentMessage.options |= mcpMsgRemoveColors;
	buf.ReadString("msg_name", g_currentMessage.msg_name, sizeof(MessageData::msg_name));

	buf.ReadString("params", g_currentMessage.sender_name, sizeof(MessageData::sender_name), 0);
	buf.ReadString("params", g_currentMessage.message, sizeof(MessageData::message), 1);

	//ignore custom colored messages, that are not chat (CPrintToChat).
	// according to color includes, these start with a non alpha character
	// (no translation identifier) and have no (=empty) params.
	if (g_currentMessage.msg_name[0] <= ' ' || (g_currentMessage.sender_name[0] == 0 && g_currentMessage.message[0] == 0))
		return Plugin_Continue;

	if (!IsValidMessage())
		return Plugin_Handled;

	// check if this is a spliterated message
	int spliterated = FindExistingMessage();
	if (spliterated >= 0) {
		// all we need to do is append the recipients list, the rest is equal
		ArrayList recipients = g_processedMessages.Get(spliterated, MessageData::listRecipients);
		for (int recipientIndex = 0; recipientIndex < playersNum; recipientIndex+=1) {
			recipients.Push( GetClientUserId( players[recipientIndex] ) );
		}
	} else {
		//this is a new message, do some additional processing
		
		// replace all control characters with a question mark. not possible through steam, but hacker can do
		int len = strlen(g_currentMessage.sender_name);
		for (int pos; pos<len; pos++) if (g_currentMessage.sender_name[pos] < 0x20) g_currentMessage.sender_name[pos]='?';
		// copy as initial display name
		strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);
		
		g_currentMessage.listRecipients.Clear();
		for (int recipientIndex = 0; recipientIndex < playersNum; recipientIndex+=1) {
			g_currentMessage.listRecipients.Push( players[recipientIndex] );
		}
		
		ParseMessageFormat(g_currentMessage.msg_name, g_currentMessage.senderflags, g_currentMessage.group);
		
		QueueMessage();
	}
	return Plugin_Handled;
}

public Action OnUserMessage_SayText2BB(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	// collect the message
	
	g_currentMessage.Reset();
	g_currentMessage.sender = msg.ReadByte();
	if (!g_currentMessage.sender) return Plugin_Continue;
	if (IsClientInKickQueue(g_currentMessage.sender)) return Plugin_Stop;
	g_currentMessage.options = msg.ReadByte() ? mcpMsgDefault : mcpMsgNoConsoleCopy;
	//by default the game does not allow colors, we let config decide
	if (g_sanitizeInput & mcpInputStripColors) g_currentMessage.options |= mcpMsgRemoveColors;

	msg.ReadString(g_currentMessage.msg_name, sizeof(MessageData::msg_name));
	if (msg.BytesLeft) msg.ReadString(g_currentMessage.sender_name, sizeof(MessageData::sender_name));
	if (msg.BytesLeft) msg.ReadString(g_currentMessage.message, sizeof(MessageData::message));

	//ignore custom colored messages, that are not chat (CPrintToChat).
	// according to color includes, these start with a non alpha character
	// (no translation identifier) and have no (=empty) params.
	if (g_currentMessage.msg_name[0] <= ' ' || (g_currentMessage.sender_name[0] == 0 && g_currentMessage.message[0] == 0))
		return Plugin_Continue;

	if (!IsValidMessage())
		return Plugin_Handled;
	
	// check if this is a spliterated message
	int spliterated = FindExistingMessage();
	if (spliterated >= 0) {
		// all we need to do is append the recipients list, the rest is equal
		ArrayList recipients = g_processedMessages.Get(spliterated, MessageData::listRecipients);
		for (int recipientIndex = 0; recipientIndex < playersNum; recipientIndex+=1) {
			recipients.Push( GetClientUserId( players[recipientIndex] ) );
		}
	} else {
		//this is a new message, do some additional processing

		// replace all control characters with a question mark. not possible through steam, but hacker can do
		int len = strlen(g_currentMessage.sender_name);
		for (int pos; pos<len; pos++) if (g_currentMessage.sender_name[pos] < 0x20) g_currentMessage.sender_name[pos]='?';
		// copy as initial display name
		strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);

		g_currentMessage.listRecipients.Clear();
		for (int recipientIndex = 0; recipientIndex < playersNum; recipientIndex++) {
			g_currentMessage.listRecipients.Push( players[recipientIndex] );
		}

		ParseMessageFormat(g_currentMessage.msg_name, g_currentMessage.senderflags, g_currentMessage.group);

		QueueMessage();
	}
	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
	if (g_hookMethod != mcpHook_CommandListener) return Plugin_Continue;
	if (!client || !IsClientInGame(client)) return Plugin_Continue;
	bool teamSay;
	int team = GetClientTeam(client);
	if (StrEqual(command, "say_team")) teamSay = true;
	else if (!StrEqual(command,"say")) return Plugin_Continue; //dont process say_party, if that's even received
	
	// collect basic message options
	g_currentMessage.Reset();
	g_currentMessage.sender = client;
	g_currentMessage.options = mcpMsgDefault;
	if (g_sanitizeInput & mcpInputStripColors) g_currentMessage.options |= mcpMsgRemoveColors;
	
	// generate sender flags
	if (team == 1) g_currentMessage.senderflags = mcpSenderSpectator;
	else if (!IsPlayerAlive(client)) g_currentMessage.senderflags = mcpSenderDead;
	else g_currentMessage.senderflags = mcpSenderNone;
	// generate target group
	if (team == 1) g_currentMessage.group = mcpTargetSpecator;
	else if (team && teamSay) {
		if (g_msgNameTagCount) g_currentMessage.group = view_as<mcpTargetGroup>(team);
		else g_currentMessage.group = mcpTargetTeamSender;
	}
	else g_currentMessage.group = mcpTargetNone;
	
	if (!IsValidMessage())
		return Plugin_Handled;

	// build message format string mock
	BuildMessageFormat(g_currentMessage.senderflags, g_currentMessage.group, g_currentMessage.msg_name, sizeof(MessageData::msg_name));
	// fetch name and message
	GetClientName(client, g_currentMessage.sender_name, sizeof(MessageData::sender_name));
	strcopy(g_currentMessage.message, sizeof(MessageData::message), sArgs);
	if (GetCmdArgs() == 1 && g_currentMessage.message[0]=='"') {
		//higly probable that this message is sent from chat. GetCmdArgs()==1 makes this check more robust than base game xD
		StripQuotes(g_currentMessage.message);
	}
	g_currentMessage.message[128]=0; //this uses the max length of the chat box, no cheating
	
	// replace all control characters with a question mark. not possible through steam, but hacker can do
	int len = strlen(g_currentMessage.sender_name);
	for (int pos; pos<len; pos++) if (g_currentMessage.sender_name[pos] < 0x20) g_currentMessage.sender_name[pos]='?';
	// copy as initial display name
	strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);
	
	// collect recipients
	g_currentMessage.listRecipients.Clear();
	for (int target=1; target<=MaxClients; target++) {
		if (!IsClientInGame(target) || IsFakeClient(target)) continue;
		if (teamSay && GetClientTeam(target) != team) continue;
		g_currentMessage.listRecipients.Push(target);
	}
	
	QueueMessage();
	return Plugin_Handled;
}

public void OnGameFrame() {
	while (g_processedMessages.Length > 0) {
		// pop message
		//delete the previous handle, we will fetch an old one from the list
		delete g_currentMessage.listRecipients;
		g_processedMessages.GetArray(0, g_currentMessage);
		g_processedMessages.Erase(0);
		//re-map recipients from uids to clients
		g_currentMessage.UserIdsToClients();
		if (!g_currentMessage.valid) continue; //sender left

		// process message
		//if this failes we hopefully threw an error and will continue processing
		//other messages in the next game tick, as this one was already dequeued
		if (ProcessMessage()) {
			ResendChatMessage();
			Call_OnChatMessagePost();
		} else if (g_currentMessage.message[0]!=0) { //process returned false, and message was not trimmed out? -> error
			LogError("Pushed or didnt clear invalid message! %N :  %s", g_currentMessage.sender, g_currentMessage.message);
		}
	}
	//we still have an old recipients list here that wasn't deleted. this instance
	//will be cleared and reused by the next SayText2 hook
	//until then, the message structure is invalid tho
	g_currentMessage.valid = false;
}

int FindExistingMessage() {
	//expects current message to be in client mode, queued messages are in userid mode
	int sendUser = GetClientUserId(g_currentMessage.sender);
	for (int msgNo = g_processedMessages.Length-1; msgNo >= 0; msgNo -= 1) {
		if (g_processedMessages.Get(msgNo, MessageData::sender) != sendUser) continue;
		return msgNo;
		//a player can't send multiple messages a tick (game limitation), so we dont need to string compare
		//also we store an already pre-filtered and trimmed string, so comparing becomes inaccurate
	}
	return -1;
}

bool IsValidMessage() {
	//check preconditions on the message to discard early.
	//does is some basic chat sanitizing. should we do this as chat processor?
	// i think most server operators wont event know this can be an issue, and
	// as they wouldn't look for it otherwise i'll do it.
	// - Drop empty messages (vanilla behaviour)
	// - Ban if the chat input contains newlines and configured, clear them otherwise.
	//   THIS CAN BAN CLIENTS IF A FAKE MESSAGE WITH NEWLINES IS SENT!
	//   The API call is temporarily removing this flag to prevent false bans
	// - Copy back the multibyte whitespace trimmed message if configured
	bool hasNewLines=false;
	char tmp[MCP_MAXLENGTH_INPUT];
	strcopy(tmp, sizeof(tmp), g_currentMessage.message);
	for (int c=strlen(tmp)-1; c>=0; c--) {
		if (tmp[c] == '\n' || tmp[c] == '\r') {
			tmp[c] = ' '; //defo replace these as they get used to break chat by hacks
			hasNewLines = true;
		}
	}
	if (hasNewLines && (g_sanitizeInput & mcpInputBanNewline)) {
		if (!IsClientInKickQueue(g_currentMessage.sender)) {
			if (!BanClient(g_currentMessage.sender, 0, BANFLAG_AUTHID|BANFLAG_AUTO, "Hacked Client: Invalid characters in chat input (line breaks)", "Hacked client detected", "say", g_currentMessage.sender))
				KickClient(g_currentMessage.sender, "Hacked client detected");
		}
		g_currentMessage.Reset();
		return false;
	}
	TrimStringMB(tmp);
	if (tmp[0]==0) { //message is empty or a "break chat" message
		g_currentMessage.Reset();
		return false;
	}
	if (g_sanitizeInput & mcpInputTrimMBSpace) strcopy(g_currentMessage.message, sizeof(MessageData::message), tmp);
	return true;
}

void QueueMessage() {
	g_currentMessage.valid = true;
	g_currentMessage.ClientsToUserIds();
	g_processedMessages.PushArray(g_currentMessage); //push with .valid = true
	g_currentMessage.Reset(.newRecipientsInstace = true); //because we pushed the list handle, sets .valid false
}

bool ProcessMessage() {
#define THEN_CANCEL { g_currentMessage.valid = false; return false; }
	Action result;
	
	//mcpHookPre
	result = Call_OnChatMessagePre();
	if (result >= Plugin_Handled) THEN_CANCEL
	else if (result == Plugin_Changed) g_currentMessage.changed = true;
	
	//processing message hooks (early)
	result = Call_OnChatMessage(-1);
	if (result >= Plugin_Handled) THEN_CANCEL
	else if (result == Plugin_Changed) g_currentMessage.changed = true;
	
	//processing message hooks (normal)
	//ccc/drixevel technically apply color to messages in the normal hook...
	result = Call_OnChatMessage(0);
	if (result >= Plugin_Handled) THEN_CANCEL
	else if (result == Plugin_Changed) g_currentMessage.changed = true;
	
	//...but default colors are added after, if missing, so i guess i'll just do it here?
	//process colors. this applies prefix and colors if not already done
	g_currentMessage.changed |= ApplyClientChatColors();
	
	//processing message hooks (late)
	result = Call_OnChatMessage(1); //can still change colors if wanted i guess
	if (result >= Plugin_Handled) THEN_CANCEL
	else if (result == Plugin_Changed) g_currentMessage.changed = true;
	
	//check if message was cleared, we dont want to send empty messages (clutter)
	if (g_currentMessage.message[0]==0) THEN_CANCEL

	return true;
#undef THEN_CANCEL
}

static void ResendChatMessage() {
	char message[MCP_MAXLENGTH_MESSAGE];
	
	ArrayList tFlags = new ArrayList(ByteCountToCells(MCP_MAXLENGTH_TRANPHRASE));
	char tGroup[MCP_MAXLENGTH_TRANPHRASE];
	char tGroupColor[MCP_MAXLENGTH_COLORTAG];
	char sEffectiveName[MCP_MAXLENGTH_NAME];
	int template = PrepareChatFormat(tFlags, tGroup, sizeof(tGroup), tGroupColor, sizeof(tGroupColor), sEffectiveName, sizeof(sEffectiveName));
	bool chatFlag = !(g_currentMessage.options & mcpMsgNoConsoleCopy);
	
	int recipientCount = g_currentMessage.listRecipients.Length;
	for (int i; i < recipientCount; i+=1) {
		int recipient = g_currentMessage.listRecipients.Get(i);
		if (!recipient) continue;

		//because i made the prefixes transalteable, we need to format for every player
		if (!FormatChatMessage(recipient, message, sizeof(message), template, tFlags, tGroup, tGroupColor, sEffectiveName)) continue;

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
			//  console output. I guess system messages in chat are not copied to console?
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
	//  sender flags format
	for (int i=0, f=g_currentMessage.senderflags; i<32 && i<g_senderflagTranslations.Length && f; i+=1, f>>=1) {
		if ((f&1)==0) continue;
		char buffer[MCP_MAXLENGTH_TRANPHRASE];
		if (GetNthPhrase(g_senderflagTranslations, i, buffer, sizeof(buffer))) {
			tFlags.PushString(buffer);
		}
	}
	if ( tFlags.Length==0 ) g_currentMessage.senderflags = mcpSenderNone;
	//  target group format
	if (g_currentMessage.group <= mcpTargetNone || !GetNthPhrase(g_groupTranslations, g_currentMessage.group, tGroup, nGroupSz)) {
		g_currentMessage.group = mcpTargetNone;
	}
	
	if ( (g_currentMessage.options & mcpMsgGrouptagColor) == mcpMsgGrouptagColor ) {
		if (!ParseChatColor(g_currentMessage.customTagColor, sGroupColor, nGroupColorSz, g_currentMessage.sender)) {
			g_currentMessage.options &=~ mcpMsgGrouptagColor; //no color provided
		}
	}
	//  name formatting
	
	//perform message option transformations, as they are the same for all instances.
	// stripping native colors and processing tags is now done after every stage
	// if the flag is set, allowing for a more dynamic processing.

	strcopy(sEffectiveName, nEffectiveNameSz, g_currentMessage.sender_display);
	if ( (g_currentMessage.options & mcpMsgIgnoreNameColor) == mcpMsgIgnoreNameColor ) {
		//we need to remove all color characters from the possibly tagged display name
		RemoveTextColors(sEffectiveName, nEffectiveNameSz, false);
	}
	//  pick the correct format template
	// returns 0..3 as template index for all combinations
	return (g_currentMessage.senderflags != mcpSenderNone ? 1 : 0) + (g_currentMessage.group != mcpTargetNone ? 2 : 0);
}

static bool FormatChatMessage(int client, char[] message, int maxlen, int template, ArrayList tFlags, const char[] tGroup, const char[] tGroupColor, const char[] sEffectiveName) {
	
	char flags[33]; //skip first comma with 1 index
	for (int i=0; i<tFlags.Length; i++) {
		char buffer[64];
		tFlags.GetString(i, buffer, sizeof(buffer));
		Format(flags, sizeof(flags), "%s,%T", flags, buffer, client);
	}
	
	char group[MCP_MAXLENGTH_TRANPHRASE];
	if (tGroup[0]) {
		if (Call_OnChatMessageGroupName(client, tGroup, group) == Plugin_Continue)
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
	
	//notify that we just formatted the message
	Action result = Call_OnChatMessageFormatted(client, message, MCP_MAXLENGTH_MESSAGE);
	return result < Plugin_Handled;

}

/** @return true on changes */
bool ApplyClientChatColors() {
	char namePrefix[MCP_MAXLENGTH_NAME];
	char displayName[MCP_MAXLENGTH_NAME];
	char chatColor[MCP_MAXLENGTH_COLORTAG];
	strcopy(namePrefix, sizeof(namePrefix), clientNamePrefix[g_currentMessage.sender]);
	strcopy(displayName, sizeof(displayName), g_currentMessage.sender_display);
	strcopy(chatColor, sizeof(chatColor), clientChatColor[g_currentMessage.sender]);
	
	Action result = Call_OnChatMessageColors(namePrefix, displayName, chatColor);
	if (result >= Plugin_Handled) {
		return true; //handled? ok I wont do anything. is it actually changed? i guess
	} else if (result == Plugin_Stop) {
		//we say stop prevents coloring, sender_name should have the unformatted name, so check
		strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);
		RemoveTextColors(g_currentMessage.message, sizeof(MessageData::message), false);
		return true;
	}
	bool changed = result >= Plugin_Changed;
	
	char colTagEnd[MCP_MAXLENGTH_NATIVECOLOR];
	//was the name formatted? does the name tag spill color onto the name?
	if (StrEqual(g_currentMessage.sender_name, displayName) && !GetStringColor(namePrefix, colTagEnd, sizeof(colTagEnd), true)) {
		//no color for the name at all? add team color
		if (g_teamColorMode==1) {
			FormatEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), "%s%s%s", namePrefix, g_teamColors[GetClientTeam(g_currentMessage.sender)], g_currentMessage.sender_name);
		} else {
			FormatEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), "%s\x03%s", namePrefix, g_currentMessage.sender_name);
		}
		//don't set changed flag here, as that's standard behaviour/colors
	} else if (!(g_compatLevel & mcpCompatExtFormat)) {
		//name and prefix are changed, and we are tasked to format the message
		//we only need to concat these two
		FormatEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), "%s%s", namePrefix, displayName);
		changed = true;
	}
	//alright now let's check. normally formats prefix char with the default color, so if we have a color and it's not default, prepend to message
	if (chatColor[0] > 1 && !(g_compatLevel & mcpCompatExtFormat)) {//not empty string, not \x01 color
		Format(g_currentMessage.message, sizeof(MessageData::message), "%s%s", chatColor, g_currentMessage.message);
		changed = true;
	}
	return changed;
}

// void DumpCurrentMessage() {
// 	PrintToServer("Current Message: %s from %i (%s, %s)\n  Flags: %i  Group: %i  Options : %i\n  Tag: ''%s'', Name: ''%s''\n  Message: ''%s''",
// 	g_currentMessage.msg_name,
// 	g_currentMessage.sender,
// 	g_currentMessage.valid ? "valid" : "invalid",
// 	g_currentMessage.changed ? "changed" : "unchanged",
// 	g_currentMessage.senderflags,
// 	g_currentMessage.group,
// 	g_currentMessage.options,
// 	g_currentMessage.customTagColor,
// 	g_currentMessage.sender_name,
// 	g_currentMessage.message);
// }
