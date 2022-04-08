#if defined _mcp_compat_cider
#endinput
#endif
#define _mcp_compat_cider
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

#define MCP_CCP_PLUGIN_VERSION "1.0.3 MCP"

static GlobalForward ccp_fwdOnChatMessagePre;
static GlobalForward ccp_fwdOnChatMessage;
static GlobalForward ccp_fwdOnChatMessagePost;

static StringMap ccp_FormatCache;

void mcp_cider_init() {
	ccp_fwdOnChatMessagePre = CreateGlobalForward("CCP_OnChatMessagePre", ET_Hook, Param_CellByRef, Param_Cell, Param_String);
	ccp_fwdOnChatMessage = CreateGlobalForward("CCP_OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String, Param_String);
	ccp_fwdOnChatMessagePost = CreateGlobalForward("CCP_OnChatMessagePost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String);
	
	RegPluginLibrary("CiderChatProcessor");
}

public void mcp_ccp_OnCVarChanged_Version(ConVar convar, const char[] oldValue, const char[] newValue) {
	char value[32];
	convar.GetString(value, sizeof(value));
	if (!StrEqual(value, MCP_CCP_PLUGIN_VERSION)) convar.SetString(MCP_CCP_PLUGIN_VERSION);
}
void mcp_cider_start() {
	//idk maybe someone checks that cvar
	ConVar version = CreateConVar("sm_ciderchatprocessor_version", MCP_CCP_PLUGIN_VERSION, "Compat Version Convar for Cider Chat-Processor", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	version.AddChangeHook(mcp_ccp_OnCVarChanged_Version);
	mcp_ccp_OnCVarChanged_Version(version,"","");
	delete version;
	ccp_FormatCache = new StringMap();
}

void mcp_cider_pluginsloaded() {
	g_fwdOnMessagePre.AddFunction(INVALID_HANDLE, MCP_CCP_OnChatMessagePre);
	g_fwdOnMessage_Normal.AddFunction(INVALID_HANDLE, MCP_CCP_OnChatMessage);
	g_fwdOnMessagePost.AddFunction(INVALID_HANDLE, MCP_CCP_OnChatMessagePost);
}

public Action MCP_CCP_OnChatMessagePre(int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor) {
	char flags[64];
	BuildMessageFormat(senderflags, targetgroup, flags, sizeof(flags));
	Call_StartForward(ccp_fwdOnChatMessagePre);
	Call_PushCellRef(sender);
	Call_PushCell(recipients);
	Call_PushStringEx(flags, sizeof(flags), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	if (error != SP_ERROR_NONE) ThrowError("[MCP] CCP OnChatMessagePre call failed with code %i", error);
	if (result == Plugin_Changed) ParseMessageFormat(flags, senderflags, targetgroup);
	return result;
}

public Action MCP_CCP_OnChatMessage(int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor, char[] name, char[] message) {
	char flags[64];
	BuildMessageFormat(senderflags, targetgroup, flags, sizeof(flags));
	Call_StartForward(ccp_fwdOnChatMessage);
	Call_PushCellRef(sender);
	Call_PushCell(recipients);
	Call_PushStringEx(flags, sizeof(flags), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(name, MCP_MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(message, MCP_MAXLENGTH_INPUT, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	if (error != SP_ERROR_NONE) ThrowError("[MCP] CCP OnChatMessage call failed with code %i", error);
	if (result == Plugin_Changed) ParseMessageFormat(flags, senderflags, targetgroup);
	return result;
}

public void MCP_CCP_OnChatMessagePost(int sender, ArrayList recipients, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, const char[] targetgroupColor, const char[] name, const char[] message) {
	char format[64], flags[64];
	BuildMessageFormat(senderflags, targetgroup, flags, sizeof(flags));
	GetFlagFormatString(flags, format, sizeof(format));
	Call_StartForward(ccp_fwdOnChatMessagePost);
	Call_PushCell(sender);
	Call_PushCell(recipients);
	Call_PushString(flags);
	Call_PushString(format);
	Call_PushString(name);
	Call_PushString(message);
	int error = Call_Finish();
	if (error != SP_ERROR_NONE) ThrowError("[MCP] CCP OnChatMessagePost call failed with code %i", error);
}

/** this is basically the same as from drixevel's */
static void GetFlagFormatString(const char[] input, char[] output, int maxsize) {
	//try to get a cached version
	int tmp; output[0]=0; //make sure we don't accidentally copy some default into the stringmap, erroring and then using that random string
	if (ccp_FormatCache.GetString(input, output, maxsize, tmp) && tmp) return;
	
	//parse format into flags
	mcpSenderFlag flags;
	mcpTargetGroup group;
	ParseMessageFormat(input, flags, group);
	//build fake format string for game & input
	if (group == mcpTargetSpecator && (flags & mcpSenderSpectator)) {
		FormatEx(output, maxsize, "(%T) {1} : {2}", "Group_Spectator", LANG_SERVER);
	} else if (group == mcpTargetTeamSender) {
		if (flags & mcpSenderDead) {
			FormatEx(output, maxsize, "*%T*(%T) {1} : {2}", "Senderflag_Dead", LANG_SERVER, "Group_Team", LANG_SERVER);
		} else {
			FormatEx(output, maxsize, "(%T) {1} : {2}", "Group_Team", LANG_SERVER);
		}
	} else if (mcpTargetTeam1 <= group <= mcpTargetTeam4) {
		char teamPhrase[12] = "Group_Team0";
		teamPhrase[10] = '1' + view_as<int>(group-mcpTargetTeam1); //generates char 1..4
		if (!TranslationPhraseExists(teamPhrase)) teamPhrase[10]=0; //use generic team phrase instead
		if (flags & mcpSenderDead) {
			FormatEx(output, maxsize, "*%T*(%T) {1} : {2}", "Senderflag_Dead", LANG_SERVER, teamPhrase, LANG_SERVER);
		} else {
			FormatEx(output, maxsize, "(%T) {1} : {2}", teamPhrase, LANG_SERVER);
		}
	} else {
		FormatEx(output, maxsize, "{1} : {2}");
	}
	ccp_FormatCache.SetString(input, output);
}

