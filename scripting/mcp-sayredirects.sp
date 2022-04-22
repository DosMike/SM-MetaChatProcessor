/** Example Plugin */

#include <sourcemod>
#include <metachatprocessor>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "22w16a"

public Plugin myinfo = {
	name = "SayRedirects",
	author = "reBane",
	description = "Commonly implemented redirects for chat messages",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

AdminFlag g_SnoopFlag;
bool g_SnoopingEnabled;
int g_AllChatMode;
bool g_DeadChat;

public void OnPluginStart() {
	ConVar cvar1 = CreateConVar("sm_sayredirect_snoopflag", "z", "AdminFlag that shall be able to snoop chat messages, empty to disable");
	cvar1.AddChangeHook(OnConVarChanged_SnoopFlag);
	ConVar cvar2 = CreateConVar("sm_sayredirect_allchat", "0", "Redirect team chat as follows: 0-Don't change; 1-Always to all; 2-Team 2 chat to all; 3-Team 3 chat to all", _, true, 0.0, true, 3.0);
	cvar2.AddChangeHook(OnConVarChanged_AllChat);
	ConVar cvar3 = CreateConVar("sm_sayredirect_deadchat", "0", "Send messages from dead players to alive players", _, true, 0.0, true, 1.0);
	cvar3.AddChangeHook(OnConVarChanged_DeadChat);
	AutoExecConfig();
	delete cvar1;
	delete cvar2;
	delete cvar3;
}

public void OnAllPluginsLoaded() {
	if (LibraryExists("MetaChatProcessor")) HookMessages();
}
public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name,"MetaChatProcessor")) HookMessages();
}
void HookMessages() {
	MCP_HookChatMessage(OnMessage_Redirect, mcpHookPre);
	MCP_HookChatMessage(OnMessage_Snoop, mcpHookLate);
}

public void OnConVarChanged_SnoopFlag(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_SnoopingEnabled = newValue[0]!=0 && FindFlagByChar(newValue[0], g_SnoopFlag);
}
public void OnConVarChanged_AllChat(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_AllChatMode = convar.IntValue;
}
public void OnConVarChanged_DeadChat(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_DeadChat = convar.BoolValue;
}

public Action OnMessage_Redirect(int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor) {
	bool isTeamSay = mcpTargetTeam1 <= targetgroup <= mcpTargetTeamSender;
	bool isDeadChat = (senderflags & mcpSenderDead)!=mcpSenderNone;
	int fromTeam = GetClientTeam(sender);
	
	//true if this message stays withing the senders team
	bool checkTeam = isTeamSay;
	if (isTeamSay && (g_AllChatMode==1||(g_AllChatMode>1 && g_AllChatMode==fromTeam))) {
		targetgroup = mcpTargetNone; //remove (TEAM) grouptag
		checkTeam = false; //add any team
	}
	
	//if we do dead chat and the sender is dead, add all alive players
	//otherwise, if we drop teamcheck we need to add other teams alive players
	bool addAlive = !checkTeam || (isDeadChat && g_DeadChat);
	
	for (int client=1;client<=MaxClients;client++) {
		if (!IsClientInGame(client) || IsFakeClient(client) || client==sender) continue;
		if (checkTeam && GetClientTeam(client)!=fromTeam) continue;
		if (!addAlive && IsPlayerAlive(client)) continue;
		recipients.Push(client);
	}
	return Plugin_Changed;
}

public Action OnMessage_Snoop(int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor, char[] name, char[] message) {
	if (!g_SnoopingEnabled) return Plugin_Continue;
	MCP_FindClientsByFlag(g_SnoopFlag, recipients);
	return Plugin_Changed;
}

