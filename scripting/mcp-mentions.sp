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
}

void SaveClientCookie(int client)
{
	char buffer[4];
	FormatEx(buffer, sizeof(buffer), "%c%c", gNotify[client] + 'A', gNotifyAtOnly[client] ? '@' : '*');
	gCookieMention.Set(client, buffer);
}

public void OnAllPluginsLoaded()
{
	MCP_HookChatMessage(OnMessage_Format, mcpHookFormatted);
	MCP_HookChatMessage(OnMessage_Post, mcpHookPost);
}

public Action OnMessage_Format(int sender, int recipient, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, char[] formatted)
{
	char name[48];
	if (!GetClientName(recipient, name, sizeof(name))) return Plugin_Continue;
	int offset = strlen(name);
	if (offset >= strlen(formatted)) return Plugin_Continue; //very short message?
	int at = StrContains(formatted[offset], ":"); //search for : roughly name length into the message
	if (at == -1) return Plugin_Continue; //no chat?
	offset += at;
	at = StrContains(formatted[offset], name, false); //now search for the name after that offset
	if (at == -1) return Plugin_Continue; //not mentioned
	offset += at;

	//get the color at name
	formatted[offset] = '\0';
	char color[12];
	MCP_GetStringColor(formatted, color, sizeof(color), true);
	formatted[offset] = name[0];
	//build highlighted name
	char highlight[48];
	FormatEx(highlight, sizeof(highlight), "\x04%s%s", name, color);
	//highlight and return
	ReplaceString(formatted[offset], MCP_MAXLENGTH_MESSAGE-offset, name, highlight, false);
	return Plugin_Changed;
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
		int pos = StrContains(message, myname, false);
		if (pos == -1) continue;
		bool atted=false;
		if (pos > 0 && message[pos-1] != ' ' && (atted = message[pos-1] != '@')) continue;
		int namelen = strlen(myname);
		if (message[pos + namelen] != ' ' && message[pos + namelen] != '\0') continue;
		if (atted || !gNotifyAtOnly[player])
			notifClient(player);
	}
}

public void ChatMentionCookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen) {
	if (action == CookieMenuAction_SelectOption) {
		ShowChatMentionMenu(client);
	}
}

void ShowChatMentionMenu(int client) {
	Menu menu = new Menu(ChatMentionMenuHandler);
	menu.SetTitle("Chat Mention Settings");
	char ibuf[4], dbuf[32];
	for (int i=0; i<=NUM_SOUNDS; i++) {
		bool thissnd = i == gNotify[client] || gNotify[client] == -1 && i == 1;
		FormatEx(ibuf, sizeof(ibuf), "S%c", 'A'+i);
		FormatEx(dbuf, sizeof(dbuf), "%s%s", thissnd ? "[X] " : "[  ] ", gNotifSoundNames[i]);
		menu.AddItem(ibuf, dbuf);
	}
	FormatEx(dbuf, sizeof(dbuf), "When: %s", gNotifyAtOnly[client] ? "@prefix only" : "always");
	menu.AddItem("@", dbuf);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
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
		if (info[0] == '@') {
			gNotifyAtOnly[param1] = !gNotifyAtOnly[param1];
		} else if (info[0] == 'S') {
			int value = info[1] - 'A';
			gNotify[param1] = value;
			value -= 1; //sound index
			if (value >= 0)
				EmitSoundToClient(param1, gNotifSounds[value]);
		}
		SaveClientCookie(param1);
		ShowChatMentionMenu(param1);
	}
	return 0;
}
