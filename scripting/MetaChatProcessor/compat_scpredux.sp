#if defined _mcp_compat_scpredux
#endinput
#endif
#define _mcp_compat_scpredux
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

#define MCP_SCP_PLUGIN_VERSION "2.3.0 MCP"

/* scp compat */
//#define SCP_CHATFLAGS_INVALID		0
//#define SCP_CHATFLAGS_ALL			(1 << 0)
//#define SCP_CHATFLAGS_TEAM			(1 << 1)
//#define SCP_CHATFLAGS_SPEC			(1 << 2)
//#define SCP_CHATFLAGS_DEAD			(1 << 3)
static int messageFlags;

static GlobalForward scp_fwdOnMessage;
static GlobalForward scp_fwdOnMessagePost;

void mcp_scp_init() {
	CreateNative("GetMessageFlags", Native_SCP_GetMessageFlags);
	RegPluginLibrary("scp");
}

public void mcp_scp_OnCVarChanged_Version(ConVar convar, const char[] oldValue, const char[] newValue) {
	char value[32];
	convar.GetString(value, sizeof(value));
	if (!StrEqual(value, MCP_SCP_PLUGIN_VERSION)) convar.SetString(MCP_SCP_PLUGIN_VERSION);
}
void mcp_scp_start() {
	ConVar version = CreateConVar("scp_version", MCP_SCP_PLUGIN_VERSION, "Plugin Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	version.AddChangeHook(mcp_scp_OnCVarChanged_Version);
	mcp_scp_OnCVarChanged_Version(version,"","");
	delete version;
	
	scp_fwdOnMessage = CreateGlobalForward("OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String);
	scp_fwdOnMessagePost = CreateGlobalForward("OnChatMessage_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
}

void mcp_scp_pluginsloaded() {
	g_fwdOnMessage_Normal.AddFunction(INVALID_HANDLE, MCP_SCP_OnChatMessage);
	g_fwdOnMessagePost.AddFunction(INVALID_HANDLE, MCP_SCP_OnChatMessagePost);
}

public int Native_SCP_GetMessageFlags(Handle plugin, int numParams) {
	return messageFlags;
}

Action MCP_SCP_OnChatMessage(int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor, char[] name, char[] message) {
	messageFlags = 0;
	if (targetgroup >= mcpTargetTeam1 && targetgroup <= mcpTargetTeamSender) messageFlags |= (1<<1); //Team
	if (targetgroup != mcpTargetSpecator && messageFlags == 0) messageFlags |= (1<<0); //All* if target not team and not spec
	if (targetgroup == mcpTargetSpecator || senderflags == mcpSenderSpectator) messageFlags |= (1<<2); //(Spectator) or *SPEC*
	if (senderflags & mcpSenderDead) messageFlags |= (1<<3); //*DEAD*
	
	Call_StartForward(scp_fwdOnMessage);
	Call_PushCellRef(sender);
	Call_PushCell(recipients);
	Call_PushStringEx(name, MCP_MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(message, MCP_MAXLENGTH_INPUT, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	if (error != SP_ERROR_NONE) ThrowError("[MCP] SCP OnChatMessage call failed with code %i", error);
	messageFlags = 0;
	return result;
}

void MCP_SCP_OnChatMessagePost(int sender, ArrayList recipients, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, const char[] targetgroupColor, const char[] name, const char[] message) {
	// so originall post callback were only fired if the message was changed because
	// a OnChatMessage return of Plugin_Continue propagated to the hook and thus dropped the callback
	// this was not noticable if you had anything like ccc as that would basically touch every message
	if (!g_currentMessage.changed && !g_fixCompatPostCalls) return;
	
	messageFlags = 0;
	if (targetgroup >= mcpTargetTeam1 && targetgroup <= mcpTargetTeamSender) messageFlags |= (1<<1); //Team
	if (targetgroup != mcpTargetSpecator && messageFlags == 0) messageFlags |= (1<<0); //All* if target not team and not spec
	if (targetgroup == mcpTargetSpecator || senderflags == mcpSenderSpectator) messageFlags |= (1<<2); //(Spectator) or *SPEC*
	if (senderflags & mcpSenderDead) messageFlags |= (1<<3); //*DEAD*
	
	Call_StartForward(scp_fwdOnMessagePost);
	Call_PushCell(sender);
	Call_PushCell(recipients);
	Call_PushString(name);
	Call_PushString(message);
	Action result;
	int error = Call_Finish(result);
	if (error != SP_ERROR_NONE) ThrowError("[MCP] SCP OnChatMessage call failed with code %i", error);
	messageFlags = 0;
}