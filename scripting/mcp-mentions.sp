/** Example Plugin */

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <metachatprocessor>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "24w17a"

public Plugin myinfo = {
	name = "Mention Sound",
	author = "reBane",
	description = "Get a notification sound if you are mentioned in chat",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

Cookie gCookieMention;
int gNotify[MAXPLAYERS+1];
bool gNotifyAtOnly[MAXPLAYERS+1];
Cookie gCookieShort;
bool gMentionShortSet[MAXPLAYERS+1];
char gMentionShort[MAXPLAYERS+1][32];

char gNotifSounds[][] = {
	"friends/message.wav",
	"ui/message_update.wav",
	//"npc/turret_floor/alert.wav",
	"hl1/fvox/beep.wav",
	"vo/streetwar/alyx_gate/al_hey.wav"
};
char gNotifSoundNames[][] = {
	"No Sound",
	"Legacy Steam",
	"GoldSrc",
	//"Turret Alert",
	"HEV beep",
	"Alyx hey"
};
#define NUM_SOUNDS 4

public void OnPluginStart()
{
	gCookieMention = new Cookie("mcp_chat_mention", "Play a notification sound when mentioned in chat", CookieAccess_Private);
	gCookieShort = new Cookie("mcp_chat_mention_nick", "Short handle you can be mentioned with", CookieAccess_Private);
	for (int client=1; client < MaxClients; client++) {
		if (!IsClientInGame(client))
			continue;
		OnClientConnected(client);
		if (AreClientCookiesCached(client))
			OnClientCookiesCached(client);
	}

	SetCookieMenuItem(ChatMentionCookieMenu, 0, "Chat Mention Settings");
	// RegAdminCmd("rawsay", CmdSayRaw, ADMFLAG_CHAT);
}

// int hexDec(char c) {
// 	if ('0' <= c <= '9') return c-'0';
// 	else if ('a' <= c <= 'f') return c-'a';
// 	else if ('A' <= c <= 'F') return c-'A';
// 	else ThrowError("Invalid hex character %c", c);
// 	return 0;
// }

// Action CmdSayRaw(int client, int args)
// {
// 	char message[128], output[128];
// 	int o;
// 	GetCmdArgString(message, sizeof(message));
// 	for (int c; c<strlen(message); c++) {
// 		if (message[c] == '\\') {
// 			c+=1;
// 			if (message[c] == 'r') output[o++] = '\r';
// 			else if (message[c] == 'n') output[o++] = '\n';
// 			else if (message[c] == 't') output[o++] = '\t';
// 			else if (message[c] == 'x') {
// 				output[o++] = hexDec(message[c+1]) * 16 + hexDec(message[c+2]) ;
// 				c+=2;
// 			}
// 			else output[o++] = message[c];
// 		} else {
// 			output[o++] = message[c];
// 		}
// 	}
// 	output[o] = '\0';
// 	PrintToChat(client, "%s", output);
// 	return Plugin_Handled;
// }

public void OnMapStart()
{
	for (int i; i < NUM_SOUNDS; i++) {
		PrecacheSound(gNotifSounds[i]);
	}
}

public void OnClientConnected(int client)
{
	OnClientDisconnect(client);
}

public void OnClientDisconnect(int client)
{
	gNotify[client] = -1;
	gNotifyAtOnly[client] = false;
	gMentionShort[client][0] = '\0';
	gMentionShortSet[client] = false;
}

public void OnClientCookiesCached(int client)
{
	char buffer[32];
	gCookieMention.Get(client, buffer, sizeof(buffer));
	if (strlen(buffer)>0) {
		gNotify[client] = buffer[0] - 'A';
		gNotifyAtOnly[client] = buffer[1] == '@';
	} else  {
		gNotify[client] = -1;
		gNotifyAtOnly[client] = false;
	}
	gCookieShort.Get(client, gMentionShort[client], 32);
}

void SaveClientCookie(int client)
{
	char buffer[4];
	FormatEx(buffer, sizeof(buffer), "%c%c", gNotify[client] + 'A', gNotifyAtOnly[client] ? '@' : '*');
	gCookieMention.Set(client, buffer);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (!StrEqual(command, "say_team")) return Plugin_Continue;
	if (!gMentionShortSet[client]) return Plugin_Continue;

	int len=strlen(sArgs);
	if (len>=32) {
		PrintToChat(client, "That nickname is too long");
		return Plugin_Handled;
	}

	for (int i; i<len; i++) {
		if (!('a' <= sArgs[i] <= 'z' || 'A' <= sArgs[i] <= 'Z' || '0' <= sArgs[i] <= '9' || sArgs[i] == '_' || sArgs[i] == '-')) {
			PrintToChat(client, "Your nick can only contain: a-z A-Z 0-9 _ -");
			return Plugin_Handled;
		}
	}

	PrintToChat(client, "Set your mention nickname to \"%s\"", sArgs);
	strcopy(gMentionShort[client], 32, sArgs);
	gCookieShort.Set(client, sArgs);
	ShowChatMentionMenu(client); //"refresh menu"
	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	MCP_HookChatMessage(OnMessage_Format, mcpHookFormatted);
	MCP_HookChatMessage(OnMessage_Post, mcpHookPost);
}
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "MetaChatProcessor")) OnAllPluginsLoaded();
}

bool isWordBound(char c)
{
	// non word ascii chars, good enough for us
	return (c < '0' || ':' <= c <= '@' || '[' <= c <= '\x60' || '{' <= c <= '}');
}

bool doHighlight(const char[] name, char[] message) {
	if (name[0] == '\0') return false;
	int offset = strlen(name);
	if (offset >= strlen(message)) return false; //very short message?
	int at = StrContains(message[offset], ":"); //search for : roughly name length into the message
	if (at == -1) return false; //no chat?
	offset += at;
	at = StrContains(message[offset], name, false); //now search for the name after that offset
	if (at == -1) return false; //not mentioned
	offset += at;

	//get the color at name
	message[offset] = '\0';
	char color[12];
	MCP_GetStringColor(message, color, sizeof(color), true);
	message[offset] = name[0];
	//build highlighted name
	char highlight[48];
	FormatEx(highlight, sizeof(highlight), "\x04%s%s", name, color);
	//highlight and return
	ReplaceString(message[offset], MCP_MAXLENGTH_MESSAGE-offset, name, highlight, false);
	return true;
}

public Action OnMessage_Format(int sender, int recipient, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, char[] formatted)
{
	char name[48];
	if (!GetClientName(recipient, name, sizeof(name))) return Plugin_Continue;
	return (doHighlight(name, formatted) || doHighlight(gMentionShort[recipient], formatted))
		? Plugin_Changed : Plugin_Continue;
}

bool containsMention(int client, const char[] name, const char[] message) {
	if (name[0] == '\0') return false;
	int pos = StrContains(message, name, false);
	if (pos == -1) return false;
	if (pos > 0 && !isWordBound(message[pos-1])) return false;
	bool atted = pos > 0 && message[pos-1] != '@';
	int namelen = strlen(name);
	if (!isWordBound(message[pos + namelen])) return false;
	return (atted || !gNotifyAtOnly[client]);
}

void notifClient(int client)
{
	if (gNotify[client] == -1) {
		gNotify[client] = 0;
		PrintToChat(client, "\x01\x04HEY, You were \x01@mentioned\x04 in chat, check \x01/settings\x04 to configure sounds!");
	} else if (gNotify[client] > 0) {
		int snd = gNotify[client]-1;
		if (snd >= NUM_SOUNDS) snd = 1;
		EmitSoundToClient(client, gNotifSounds[snd]);
	}
}

public void OnMessage_Post(int sender, ArrayList recipients, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, const char[] targetgroupColor, const char[] name, const char[] message)
{
	char myname[48];
	for (int i; i<recipients.Length; i++) {
		int player = recipients.Get(i);
		if (!IsClientInGame(player) || gNotify[player]==0) continue;
		if (!GetClientName(player, myname, sizeof(myname))) continue;
		if (containsMention(player, myname, message) || containsMention(player, gMentionShort[player], message))
			notifClient(player);
	}
}

public void ChatMentionCookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen) {
	if (action == CookieMenuAction_SelectOption) {
		ShowChatMentionMenu(client);
	}
}

void ShowChatMentionMenu(int client, int page=0) {
	Menu menu = new Menu(ChatMentionMenuHandler);
	menu.SetTitle("Chat Mention Settings");

	gMentionShortSet[client] = true;
	char ibuf[4], dbuf[32];

	FormatEx(dbuf, sizeof(dbuf), "When: %s", gNotifyAtOnly[client] ? "@prefix only" : "always");
	menu.AddItem("@", dbuf);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("", "You are mentioned by:", ITEMDRAW_DISABLED);
	menu.AddItem("N", gMentionShort[client][0] ? gMentionShort[client] : "<ONLY USERNAME>");
	menu.AddItem("", "Set with team chat", ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("", "Pick sound on next page", ITEMDRAW_DISABLED);

	for (int i=0; i<=NUM_SOUNDS; i++) {
		bool thissnd = i == gNotify[client] || gNotify[client] == -1 && i == 1;
		FormatEx(ibuf, sizeof(ibuf), "S%c", 'A'+i);
		FormatEx(dbuf, sizeof(dbuf), "%s%s", thissnd ? "[X] " : "[  ] ", gNotifSoundNames[i]);
		menu.AddItem(ibuf, dbuf);
	}

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page*7, MENU_TIME_FOREVER);
}

public int ChatMentionMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack) {
			ShowCookieMenu(param1);
		}
	} else if (action == MenuAction_Select) {
		char info[16];
		menu.GetItem(param2, info, sizeof(info));
		int page=0;
		if (info[0] == '@') {
			gNotifyAtOnly[param1] = !gNotifyAtOnly[param1];
			SaveClientCookie(param1);
			page=1;
		} else if (info[0] == 'S') {
			int value = info[1] - 'A';
			gNotify[param1] = value;
			value -= 1; //sound index
			if (value >= 0)
				EmitSoundToClient(param1, gNotifSounds[value]);
			SaveClientCookie(param1);
			page=param2/7;
		} else if (info[0] == 'N') {
			PrintToChat(param1, "Reset your mention trigger to your nickname!");
			gMentionShort[param1][0]='\0';
			gCookieShort.Set(param1, "");
			gMentionShortSet[param1] = false; //it's reasonable to assume the menu will go away now (unless redrawn, but that's later)
		}
		ShowChatMentionMenu(param1, page);
	}
	return 0;
}
