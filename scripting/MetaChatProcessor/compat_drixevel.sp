#if defined _mcp_compat_drixevel
#endinput
#endif
#define _mcp_compat_drixevel
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

#define MCP_DRIXEVEL_PLUGIN_VERSION "2.2.9 MCP"

// Tag data for dcp
static ArrayList drixevel_NameTags[MAXPLAYERS + 1];
static char drixevel_NameColor[MAXPLAYERS + 1][MAXLENGTH_NAME];
static char drixevel_ChatColor[MAXPLAYERS + 1][MAXLENGTH_MESSAGE];

// "normal" forwards
static Handle drixevel_fwdOnChatMessageSendPre;
static Handle drixevel_fwdOnChatMessage;
static Handle drixevel_fwdOnChatMessagePost;
// tag related forwards
static Handle drixevel_fwdOnAddClientTagPost;
static Handle drixevel_fwdOnRemoveClientTagPost;
static Handle drixevel_fwdOnSwapClientTagsPost;
static Handle drixevel_fwdOnStripClientTagsPost;
static Handle drixevel_fwdOnSetTagColorPost;
static Handle drixevel_fwdOnSetNameColorPost;
static Handle drixevel_fwdOnSetChatColorPost;
static Handle drixevel_fwdOnReloadChatData;

static StringMap drixevel_FormatCache;

void mcp_drixevel_init() {
	//pretty much same as in scp
	CreateNative("ChatProcessor_GetFlagFormatString", Native_Drixevel_GetFlagFormatString);
	//tag related natives
	CreateNative("ChatProcessor_AddClientTag", Native_Drixevel_AddClientTag);
	CreateNative("ChatProcessor_RemoveClientTag", Native_Drixevel_RemoveClientTag);
	CreateNative("ChatProcessor_SwapClientTags", Native_Drixevel_SwapClientTags);
	CreateNative("ChatProcessor_StripClientTags", Native_Drixevel_StripClientTags);
	CreateNative("ChatProcessor_SetTagColor", Native_Drixevel_SetTagColor);
	CreateNative("ChatProcessor_SetNameColor", Native_Drixevel_SetNameColor);
	CreateNative("ChatProcessor_SetChatColor", Native_Drixevel_SetChatColor);
	//create "normal" forwards
	drixevel_fwdOnChatMessage = CreateGlobalForward("CP_OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String, Param_String, Param_CellByRef, Param_CellByRef);
	drixevel_fwdOnChatMessageSendPre = CreateGlobalForward("CP_OnChatMessageSendPre", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_String, Param_Cell);
	drixevel_fwdOnChatMessagePost = CreateGlobalForward("CP_OnChatMessagePost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_Cell, Param_Cell);
	//create tag related forwards
	drixevel_fwdOnAddClientTagPost = CreateGlobalForward("CP_OnAddClientTagPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	drixevel_fwdOnRemoveClientTagPost = CreateGlobalForward("CP_OnRemoveClientTagPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	drixevel_fwdOnSwapClientTagsPost = CreateGlobalForward("CP_OnSwapClientTagsPost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
	drixevel_fwdOnStripClientTagsPost = CreateGlobalForward("CP_OnStripClientTagsPost", ET_Ignore, Param_Cell);
	drixevel_fwdOnSetTagColorPost = CreateGlobalForward("CP_OnSetTagColorPost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
	drixevel_fwdOnSetNameColorPost = CreateGlobalForward("CP_OnSetNameColorPost", ET_Ignore, Param_Cell, Param_String);
	drixevel_fwdOnSetChatColorPost = CreateGlobalForward("CP_OnSetChatColorPost", ET_Ignore, Param_Cell, Param_String);
	drixevel_fwdOnReloadChatData = CreateGlobalForward("CP_OnReloadChatData", ET_Ignore);
	//reg library
	RegPluginLibrary("chat-processor");
}

public void mcp_drixevel_OnCVarChanged_Version(ConVar convar, const char[] oldValue, const char[] newValue) {
	char value[32];
	convar.GetString(value, sizeof(value));
	if (!StrEqual(value, MCP_DRIXEVEL_PLUGIN_VERSION)) convar.SetString(MCP_DRIXEVEL_PLUGIN_VERSION);
}
void mcp_drixevel_start() {
	//idk maybe someone checks that cvar
	ConVar version = CreateConVar("sm_chatprocessor_version", MCP_DRIXEVEL_PLUGIN_VERSION, "Compat Version Convar for Drixevel's Chat-Processor", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	version.AddChangeHook(mcp_drixevel_OnCVarChanged_Version);
	mcp_drixevel_OnCVarChanged_Version(version,"","");
	delete version;
	drixevel_FormatCache = new StringMap();
	//imo creating forwards should be done here, and registering to them should be done in AllPluginsLoaded, but whatever
}
void mcp_drixevel_client_connect(int client) {
	if (drixevel_NameTags[client] == null) {
		drixevel_NameTags[client] = new ArrayList(ByteCountToCells(MCP_MAXLENGTH_NAME));
	} else {
		drixevel_NameTags[client].Clear();
	}
}
void mcp_drixevel_client_disconnect(int client) {
	delete drixevel_NameTags[client];
	drixevel_NameColor[client][0]=0;
	drixevel_ChatColor[client][0]=0;
}

void mcp_drixevel_pluginsloaded() {
	g_fwdOnMessage_Normal.AddFunction(INVALID_HANDLE, MCP_Drixevel_OnChatMessage);
	g_fwdOnMessageFormatted.AddFunction(INVALID_HANDLE, MCP_Drixevel_OnChatFormatted);
	g_fwdOnMessagePost.AddFunction(INVALID_HANDLE, MCP_Drixevel_OnChatMessagePost);
}

static void UpdateClientPrefixAndColor(int client) {
	char prefix[MCP_MAXLENGTH_NAME];
	char color[MCP_MAXLENGTH_COLORTAG];
	//update name prefix
	if (drixevel_NameColor[client][0]) {
		strcopy(prefix, sizeof(prefix), drixevel_NameColor[client]);
	} else if (drixevel_NameTags[client].Length) {
		strcopy(prefix, sizeof(prefix), "\x03");
	}// else will clear prefix
	char tagbuf[64];
	for (int i; i<drixevel_NameTags[client].Length; i+=1) {
		drixevel_NameTags[client].GetString(i, tagbuf, sizeof(tagbuf));
		Format(prefix, MCP_MAXLENGTH_NAME, "%s%s", tagbuf, prefix);
	}
	//update chat color
	strcopy(clientNamePrefix[client], sizeof(clientNamePrefix[]), prefix);
	if (drixevel_ChatColor[client][0]) {//buffer in dcp is ludicrously large for the purpose lul, i just force color
		int at;
		if( (at=StringStartsWithColor(drixevel_ChatColor[client]))<0 ||
			!ParseChatColor(drixevel_ChatColor[client][at], clientChatColor[client], sizeof(clientChatColor[]), client)) {
			LogError("[MCP] Drixevel Chat-Processor chat color prefix is not a simple color; Ignoring value to prevent truncated message")
			clientChatColor[client][0]=0;
		}
	} else {
		clientChatColor[client][0]=0;
	}
}

public Action MCP_Drixevel_OnChatMessage(int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor, char[] name, char[] message) {
	char sFlag[64];
	bool processColors = options & mcpMsgProcessColors;
	bool removeColors = options & mcpMsgRemoveColors;
	BuildMessageFormat(senderflags, targetgroup, sFlag, sizeof(sFlag));
	Call_StartForward(drixevel_fwdOnChatMessage);
	Call_PushCellRef(sender);
	Call_PushCellRef(recipients);
	Call_PushStringEx(sFlag, sizeof(sFlag), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(name, MCP_MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(message, MCP_MAXLENGTH_INPUT, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCellRef(processColors);
	Call_PushCellRef(removeColors);
	Action result;
	int error = Call_Finish(result);
	if (error != SP_ERROR_NONE) ThrowError("[MCP] Drixevel's OnChatMessage call failed with code %i", error);
	if (result == Plugin_Changed) {
		if (processColors) options |= mcpMsgProcessColors;
		else options &=~ mcpMsgProcessColors;
		if (removeColors) options |= mcpMsgRemoveColors;
		else options &=~ mcpMsgRemoveColors;
	}
}

public Action MCP_Drixevel_OnChatFormatted(int sender, int recipient, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, char[] formatted) {
	
}

public void MCP_Drixevel_OnChatMessagePost(int sender, ArrayList recipients, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, const char[] targetgroupColor, const char[] name, const char[] message) {
	
}

static void GetFlagFormatString(const char[] input, char[] output, int maxsize) {
	//try to get a cached version
	int tmp; output[0]=0; //make sure we don't accidentally copy some default into the stringmap, erroring and then using that random string
	if (drixevel_FormatCache.GetString(input, output, maxsize, tmp) && tmp) return;
	
	//parse format into flags
	mcpSenderFlag flags;
	mcpTargetGroup group;
	ParseMessageFormat(input, flags, group);
	//build fake format string for game & input
	if (group == mcpTargetSpecator && (flags & mcpSenderSpectator)) {
		FormatEx(output, sizeof(output), "(%T) {1} : {2}", "Group_Spectator", LANG_SERVER);
	} else if (group == mcpTargetTeamSender) {
		if (flags & mcpSenderDead) {
			FormatEx(output, sizeof(output), "*%T*(%T) {1} : {2}", "Senderflag_Dead", LANG_SERVER, "Group_Team", LANG_SERVER);
		} else {
			FormatEx(output, sizeof(output), "(%T) {1} : {2}", "Group_Team", LANG_SERVER);
		}
	} else if (mcpTargetTeam1 <= group <= mcpTargetTeam4) {
		char teamPhrase[12] = "Group_Team0";
		teamPhrase[10] = '1' + (group-mcpTargetTeam1); //generates char 1..4
		if (!TranslationPhraseExists(teamPhrase)) teamPhrase[10]=0; //use generic team phrase instead
		if (flags & mcpSenderDead) {
			FormatEx(output, sizeof(output), "*%T*(%T) {1} : {2}", "Senderflag_Dead", LANG_SERVER, teamPhrase, LANG_SERVER);
		} else {
			FormatEx(output, sizeof(output), "(%T) {1} : {2}", teamPhrase, LANG_SERVER);
		}
	} else {
		FormatEx(output, sizeof(output), "{1} : {2}");
	}
	drixevel_FormatCache.SetString(input, output);
}

// -------------------- Forwards --------------------

static Call_Drixevel_OnChatMessage() {
	
}

// -------------------- Natives --------------------

public any Native_Drixevel_GetFlagFormatString(Handle plugin, int numParams) {
	int len, error;
	if ((error=GetNativeStringLength(1,len))!=SP_ERROR_NONE) ThrowNativeError(error, "Faile to create native string");
	char input[len+1];
	GetNativeString(1, input, len+1);
	char output[64];
	
	GetFlagFormatString(input, output, sizeof(output));
	SetNativeString(2, output, GetNativeCell(3));
}
