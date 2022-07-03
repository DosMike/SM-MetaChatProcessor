/** Example Plugin */

#include <sourcemod>
#include <metachatprocessor>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "22w26a"

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
bool g_TeamTagColor;

static void HookAndLoadConVar(ConVar convar, ConVarChanged hook) {
	//I sometimes hate convars...
	// You need to manually read the value after the convars are set up, as that will not trigger a change!
	// This wrapper will invoke the change handler manually before hooking the convar, so the currrent value is always processed
	char value[4]; //too small for general use!
	convar.GetString(value, sizeof(value));
	Call_StartFunction(INVALID_HANDLE, hook);
	Call_PushCell(convar);
	Call_PushString("");
	Call_PushString(value);
	Call_Finish();
	convar.AddChangeHook(hook);
}

public void OnPluginStart() {
	ConVar cvar1 = CreateConVar("sm_sayredirect_snoopflag", "z", "AdminFlag that shall be able to snoop chat messages, empty to disable");
	ConVar cvar2 = CreateConVar("sm_sayredirect_allchat", "0", "Redirect team chat as follows: 0-Don't change; 1-Always to all; 2-Team 2 chat to all; 3-Team 3 chat to all", _, true, 0.0, true, 3.0);
	ConVar cvar3 = CreateConVar("sm_sayredirect_deadchat", "0", "Send messages from dead players to alive players", _, true, 0.0, true, 1.0);
	ConVar cvar4 = CreateConVar("sm_sayredirect_colorteamtag", "0", "Color the (TEAM) tag for say_team in team color", _, true, 0.0, true, 1.0);
	AutoExecConfig(); //gen/load config
	HookAndLoadConVar(cvar1,OnConVarChanged_SnoopFlag);
	HookAndLoadConVar(cvar2,OnConVarChanged_AllChat);
	HookAndLoadConVar(cvar3,OnConVarChanged_DeadChat);
	HookAndLoadConVar(cvar4,OnConVarChanged_TeamTagColor);
	delete cvar1;
	delete cvar2;
	delete cvar3;
	delete cvar4;
}

public void OnAllPluginsLoaded() {
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
public void OnConVarChanged_TeamTagColor(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_TeamTagColor = convar.BoolValue;
}

public Action OnMessage_Redirect(int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor) {
	bool isTeamSay = mcpTargetTeam1 <= targetgroup <= mcpTargetTeamSender;
	bool isDeadChat = (senderflags & mcpSenderDead)!=mcpSenderNone;
	int fromTeam = sender ? GetClientTeam(sender) : 0;
	
	//true if this message stays withing the senders team
	bool checkTeam = isTeamSay;
	if (isTeamSay && (g_AllChatMode==1||(g_AllChatMode>1 && g_AllChatMode==fromTeam))) {
		targetgroup = mcpTargetNone; //remove (TEAM) grouptag
		isTeamSay = false;
		checkTeam = false; //add any team
	}
	
	//i like if the TEAM tag is team colored
	if (isTeamSay && g_TeamTagColor) {
		options |= mcpMsgGrouptagColor;
		strcopy(targetgroupColor, MCP_MAXLENGTH_COLORTAG, "\x03");
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

