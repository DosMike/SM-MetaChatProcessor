#if defined _mcp_pluginapi
#endinput
#endif
#define _mcp_pluginapi
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

/** Early inspection like cider chat processor, originally intended to mainly manipulate visibility for other plugin 
 * f(&sender, recipients, &sendflags, &group, &options)
 */
PrivateForward g_fwdOnMessagePre;
/** Main processing hook, add colors, filter slurs, whatever...
 * f(&sender, recipients, &sendflags, &group, &options, &name, &message)
 */
PrivateForward g_fwdOnMessage_Early;
PrivateForward g_fwdOnMessage_Normal;
PrivateForward g_fwdOnMessage_Late;
/**
 * Compat forward for when colors are 'applied' to name aka before the format is stiched.
 * f(sender, senderflags, group, options, &nameTag, &displayName, &chatColor)
 */
PrivateForward g_fwdOnMessageColors;
/** Forward to fill additional placeholders in groupname translation phrases
 * f(sender, recipient, senderflags, targetgroup, groupphrase, groupname)
 */
PrivateForward g_fwdOnMessageGroupName;
/* From just chat-processor, before the message is sent. contained the translated & formatted message and called for every target
 * Why does chat-processor allow last minute edits? I don't fully understand
 * f(sender, recipient, sendflags, group, options, buffer, buffersize);
 */
PrivateForward g_fwdOnMessageFormatted;
/** This message was sent, we done
 * f(sender, recipients, sendflags, group, options, name, message)
 */
PrivateForward g_fwdOnMessagePost;

public void pluginAPI_register() {
	MarkNativeAsOptional("GetUserMessageType");//so check for protobuf works even if sm is so old this native doesnt exist
	LoadCompatConfig();
	
	if (g_compatLevel & mcpCompatSCPRedux)
		mcp_scp_init();
	if (g_compatLevel & mcpCompatDrixevel)
		mcp_drixevel_init();
	if (g_compatLevel & mcpCompatCiderCP)
		mcp_cider_init();
	
	CreateNative("MCP_HookChatMessage", Native_HookChatMessage);
	CreateNative("MCP_UnhookChatMessage", Native_UnhookChatMessage);
	CreateNative("MCP_UnhookAllChatMessages", Native_UnhookAllChatMessage);
	CreateNative("MCP_RegisterSenderFlag", Native_RegisterSenderFlag);
	CreateNative("MCP_RegisterTargetGroup", Native_RegisterTargetGroup);
	CreateNative("MCP_UnregisterSenderFlags", Native_UnregisterSenderFlag);
	CreateNative("MCP_UnregisterTargetGroups", Native_UnregisterTargetGroup);
	CreateNative("MCP_SendChat", Native_SendChat);
	
	CreateNative("MCP_SetClientDefaultNamePrefix", Native_SetNamePrefix);
	CreateNative("MCP_GetClientDefaultNamePrefix", Native_GetNamePrefix);
	CreateNative("MCP_SetClientDefaultChatColor", Native_SetChatColor);
	CreateNative("MCP_GetClientDefaultChatColor", Native_GetChatColor);
	
	CreateNative("MCP_SetMessageData", Native_SetMsgData);
	CreateNative("MCP_GetMessageData", Native_GetMsgData);
	
	RegPluginLibrary("MetaChatProcessor");
}

void pluginAPI_init() {
	//MCP_OnChatMessagePre
	g_fwdOnMessagePre = new PrivateForward(ET_Hook, 
		Param_CellByRef, Param_Cell, //sender, recipients
		Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_String); //senderflags, group, options, groupcolor
	//MCP_OnChatMessage_Early
	g_fwdOnMessage_Early = new PrivateForward(ET_Event, 
		Param_CellByRef, Param_Cell, //sender, recipients
		Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_String, //senderflags, group, options, groupcolor
		Param_String, Param_String); //name, message
	//MCP_OnChatMessage_Default
	g_fwdOnMessage_Normal = new PrivateForward(ET_Event,
		Param_CellByRef, Param_Cell, //sender, recipients
		Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_String, //senderflags, group, options, groupcolor
		Param_String, Param_String); //name, message
	//MCP_OnChatMessage_Late
	g_fwdOnMessage_Late = new PrivateForward(ET_Event,
		Param_CellByRef, Param_Cell, //sender, recipients
		Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_String, //senderflags, group, options, groupcolor
		Param_String, Param_String); //name, message
	//MCP_OnChatMessageColors
	g_fwdOnMessageColors = new PrivateForward(ET_Event,
		Param_CellByRef, Param_Cell, //sender, recipients
		Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_String, //senderflags, group, options, groupcolor
		Param_String, Param_String, Param_String); //prefix, name, chatcolor
	//MCP_OnChatMessageGroupName
	g_fwdOnMessageGroupName = new PrivateForward(ET_Event,
		Param_Cell, Param_Cell, //sender, recipient
		Param_Cell, Param_Cell, //senderflags, group
		Param_String, Param_String); //groupphrase, groupname
	//MCP_OnChatMessageFormatted
	g_fwdOnMessageFormatted = new PrivateForward(ET_Event, 
		Param_Cell, Param_Cell, //sender, recipients
		Param_Cell, Param_Cell, Param_Cell, //senderflags, group, options
		Param_String); //formatted message, 
	//MCP_OnChatMessagePost
	g_fwdOnMessagePost = new PrivateForward(ET_Ignore, 
		Param_Cell, Param_Cell, //sender, recipients
		Param_Cell, Param_Cell, Param_Cell, Param_String, //senderglags, group, option, groupcolor
		Param_String, Param_String); //name, message
	
	if (g_compatLevel & mcpCompatSCPRedux)
		mcp_scp_start();
	if (g_compatLevel & mcpCompatDrixevel)
		mcp_drixevel_start();
	if (g_compatLevel & mcpCompatCiderCP)
		mcp_cider_start();
}

public void OnAllPluginsLoaded() {
	if (g_compatLevel & mcpCompatSCPRedux) {
		mcp_scp_pluginsloaded();
		if (IsPluginLoaded("[Source 2013] Custom Chat Colors Toggle Module")) {
			mcp_ccc_init();
		}
	}
	if (g_compatLevel & mcpCompatDrixevel)
		mcp_drixevel_pluginsloaded();
	if (g_compatLevel & mcpCompatCiderCP)
		mcp_cider_pluginsloaded();
}


// -------------------- FORWARD WRAPPER --------------------

/**
 * Check for no errors, validate recipients and optionally rebuild msg_format string
 */
static void ValidateAfterCall(const char[] stage, int error, Action& returnedAction=Plugin_Continue, bool rebuildMessageFormat=false) {
	//other plugins are not allowed to close handles owned by different plugins, so recipients should always be valid
	if (returnedAction == Plugin_Changed && g_currentMessage.listRecipients.Length == 0) {
		static bool hasWarned;
		if (!hasWarned) {
			hasWarned = true;
			LogError("MCP_OnChatMessage%s cleard the recipients list instead of cancelling - As PluginDev, Please reconsider", stage);
		}
		returnedAction = Plugin_Stop;
	}
	//remove doubled recipients
	g_currentMessage.listRecipients.Sort(Sort_Ascending, Sort_Integer);
	for (int i = g_currentMessage.listRecipients.Length-1; i > 0; i -= 1) {
		if (g_currentMessage.listRecipients.Get(i) == g_currentMessage.listRecipients.Get(i-1)) {
			g_currentMessage.listRecipients.Erase(i);
		}
	}
	//check error code
	if (error != SP_ERROR_NONE) {
		ThrowError("MCP_OnChatMessage%s failed with error code %i", stage, error);
	}
	//rebuild message format string if required
	if (returnedAction == Plugin_Changed && rebuildMessageFormat)
		BuildMessageFormat(g_currentMessage.senderflags, g_currentMessage.group, g_currentMessage.msg_name, sizeof(MessageData::msg_name));
	
	//always strip and process colors
	if (returnedAction == Plugin_Changed) {
		if ( (g_currentMessage.options & mcpMsgRemoveColors) == mcpMsgRemoveColors ) {
			RemoveTextColors(g_currentMessage.sender_display, sizeof(MessageData::sender_display), false);
			g_currentMessage.changed |= RemoveTextColors(g_currentMessage.message, sizeof(MessageData::message), false);
		}
		if ( (g_currentMessage.options & mcpMsgProcessColors) == mcpMsgProcessColors ) {
			CFormatColor(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender);
			if (g_currentMessage.changed) {
				//we already know the message changes, we can save ourselfs the strcopy and compare
				CFormatColor(g_currentMessage.message, sizeof(MessageData::message), g_currentMessage.sender);
			} else {
				char compcpy[MAX_MESSAGE_LENGTH];
				strcopy(compcpy, sizeof(compcpy), g_currentMessage.message);
				CFormatColor(g_currentMessage.message, sizeof(MessageData::message), g_currentMessage.sender);
				if (!StrEqual(g_currentMessage.message, compcpy)) g_currentMessage.changed = true;
			}
		}
	}
	//reset for the next forward
	g_currentMessage.options &=~ (mcpMsgRemoveColors|mcpMsgProcessColors);
}

Action Call_OnChatMessagePre() {
	if (!g_fwdOnMessagePre.FunctionCount) return Plugin_Continue;
	mcpSenderFlag preFlags = g_currentMessage.senderflags;
	mcpTargetGroup preGroup = g_currentMessage.group;
	
	Call_StartForward(g_fwdOnMessagePre);
	Call_PushCellRef(g_currentMessage.sender);
	Call_PushCell(g_currentMessage.listRecipients);
	Call_PushCellRef(g_currentMessage.senderflags);
	Call_PushCellRef(g_currentMessage.group);
	Call_PushCellRef(g_currentMessage.options);
	Call_PushStringEx(g_currentMessage.customTagColor, sizeof(MessageData::customTagColor), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall("Pre", error, result, (g_currentMessage.senderflags != preFlags || g_currentMessage.group != preGroup));
	return result;
}

Action Call_OnChatMessage(int stage) {
	PrivateForward funForward;
	if (stage < 0) funForward = g_fwdOnMessage_Early;
	else if (stage > 0) funForward = g_fwdOnMessage_Late;
	else funForward = g_fwdOnMessage_Normal;
	if (!funForward.FunctionCount) return Plugin_Continue;
	mcpSenderFlag preFlags = g_currentMessage.senderflags;
	mcpTargetGroup preGroup = g_currentMessage.group;
	
	Call_StartForward(funForward);
	Call_PushCellRef(g_currentMessage.sender);
	Call_PushCell(g_currentMessage.listRecipients);
	Call_PushCellRef(g_currentMessage.senderflags);
	Call_PushCellRef(g_currentMessage.group);
	Call_PushCellRef(g_currentMessage.options);
	Call_PushStringEx(g_currentMessage.customTagColor, sizeof(MessageData::customTagColor), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(g_currentMessage.message, sizeof(MessageData::message), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall(stage<0?"Early":(stage?"Late":""), error, result, (g_currentMessage.senderflags != preFlags || g_currentMessage.group != preGroup));
	return result;
}

Action Call_OnChatMessageColors(char[] nameTag, char[] displayName, char[] chatColorTag) {
	if (!g_fwdOnMessageColors.FunctionCount) return Plugin_Continue;
	
	Call_StartForward(g_fwdOnMessageColors);
	Call_PushCell(g_currentMessage.sender);
	Call_PushCell(g_currentMessage.senderflags);
	Call_PushCell(g_currentMessage.group);
	Call_PushCell(g_currentMessage.options);
	Call_PushStringEx(nameTag, MCP_MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(displayName, MCP_MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(chatColorTag, MCP_MAXLENGTH_COLORTAG, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall("Colors", error, result);
	return result;
}

Action Call_OnChatMessageGroupName(int target, const char[] groupphrase, char[] groupname) {
	if (!g_fwdOnMessageGroupName.FunctionCount) return Plugin_Continue;
	
	Call_StartForward(g_fwdOnMessageGroupName);
	Call_PushCell(g_currentMessage.sender);
	Call_PushCell(target);
	Call_PushCell(g_currentMessage.senderflags);
	Call_PushCell(g_currentMessage.group);
	Call_PushString(groupphrase);
	Call_PushStringEx(groupname, MCP_MAXLENGTH_TRANPHRASE, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall("GroupName", error);
	return result;
}

Action Call_OnChatMessageFormatted(int target, char[] message, int maxlen) {
	if (!g_fwdOnMessageFormatted.FunctionCount) return Plugin_Continue;
	
	Call_StartForward(g_fwdOnMessageFormatted);
	Call_PushCell(g_currentMessage.sender);
	Call_PushCell(target);
	Call_PushCell(g_currentMessage.senderflags);
	Call_PushCell(g_currentMessage.group);
	Call_PushCell(g_currentMessage.options);
	Call_PushStringEx(message, maxlen, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall("Formatted", error, result);
	return result;
}

void Call_OnChatMessagePost() {
	if (!g_fwdOnMessagePost.FunctionCount) return;
	
	Call_StartForward(g_fwdOnMessagePost);
	Call_PushCell(g_currentMessage.sender);
	Call_PushCell(g_currentMessage.listRecipients);
	Call_PushCell(g_currentMessage.senderflags);
	Call_PushCell(g_currentMessage.group);
	Call_PushCell(g_currentMessage.options);
	Call_PushStringEx(g_currentMessage.customTagColor, sizeof(MessageData::customTagColor), SM_PARAM_STRING_UTF8, 0);
	Call_PushStringEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), SM_PARAM_STRING_UTF8, 0);
	Call_PushStringEx(g_currentMessage.message, sizeof(MessageData::message), SM_PARAM_STRING_UTF8, 0);
	int error = Call_Finish();
	
	ValidateAfterCall("Post", error);
}

// -------------------- NATIVES --------------------

public int Native_HookChatMessage(Handle plugin, int numParams) {
	Function fun = GetNativeFunction(1);
	switch (GetNativeCell(2)) {
		case 0: g_fwdOnMessagePre.AddFunction(plugin, fun);
		case 1: g_fwdOnMessage_Early.AddFunction(plugin, fun);
		case 2: g_fwdOnMessage_Normal.AddFunction(plugin, fun);
		case 3: g_fwdOnMessage_Late.AddFunction(plugin, fun);
		case 4: g_fwdOnMessageColors.AddFunction(plugin, fun);
		case 5: g_fwdOnMessageGroupName.AddFunction(plugin, fun);
		case 6: g_fwdOnMessageFormatted.AddFunction(plugin, fun);
		case 7: g_fwdOnMessagePost.AddFunction(plugin, fun);
		default: ThrowNativeError(SP_ERROR_PARAM, "Invalid hook type");
	}
	return 0;
}
public int Native_UnhookChatMessage(Handle plugin, int numParams) {
	Function fun = GetNativeFunction(1);
	if (fun == INVALID_FUNCTION) {
		switch (GetNativeCell(2)) {
			case 0: g_fwdOnMessagePre.RemoveAllFunctions(plugin);
			case 1: g_fwdOnMessage_Early.RemoveAllFunctions(plugin);
			case 2: g_fwdOnMessage_Normal.RemoveAllFunctions(plugin);
			case 3: g_fwdOnMessage_Late.RemoveAllFunctions(plugin);
			case 4: g_fwdOnMessageColors.RemoveAllFunctions(plugin);
			case 5: g_fwdOnMessageGroupName.RemoveAllFunctions(plugin);
			case 6: g_fwdOnMessageFormatted.RemoveAllFunctions(plugin);
			case 7: g_fwdOnMessagePost.RemoveAllFunctions(plugin);
			default: ThrowNativeError(SP_ERROR_PARAM, "Invalid hook type");
		}
	} else {
		switch (GetNativeCell(2)) {
			case 0: g_fwdOnMessagePre.RemoveFunction(plugin, fun);
			case 1: g_fwdOnMessage_Early.RemoveFunction(plugin, fun);
			case 2: g_fwdOnMessage_Normal.RemoveFunction(plugin, fun);
			case 3: g_fwdOnMessage_Late.RemoveFunction(plugin, fun);
			case 4: g_fwdOnMessageColors.RemoveFunction(plugin, fun);
			case 5: g_fwdOnMessageGroupName.RemoveFunction(plugin, fun);
			case 6: g_fwdOnMessageFormatted.RemoveFunction(plugin, fun);
			case 7: g_fwdOnMessagePost.RemoveFunction(plugin, fun);
			default: ThrowNativeError(SP_ERROR_PARAM, "Invalid hook type");
		}
	}
	return 0;
}
public int Native_UnhookAllChatMessage(Handle plugin, int numParams) {
	g_fwdOnMessagePre.RemoveAllFunctions(plugin);
	g_fwdOnMessage_Early.RemoveAllFunctions(plugin);
	g_fwdOnMessage_Normal.RemoveAllFunctions(plugin);
	g_fwdOnMessage_Late.RemoveAllFunctions(plugin);
	g_fwdOnMessageColors.RemoveAllFunctions(plugin);
	g_fwdOnMessageGroupName.RemoveAllFunctions(plugin);
	g_fwdOnMessageFormatted.RemoveAllFunctions(plugin);
	g_fwdOnMessagePost.RemoveAllFunctions(plugin);
	return 0;
}

public int Native_RegisterSenderFlag(Handle plugin, int numParams) {
	char phrase[64];
	char file[128];
	GetNativeString(1,phrase,sizeof(phrase));
	GetNativeString(2,file,sizeof(file));
	int insert = PushPhraseToList(g_senderflagTranslations, phrase, plugin, file);
	if (insert >= 32) {
		g_senderflagTranslations.Erase(insert);
		return 0;
	} else {
		return insert;
	}
}

public int Native_RegisterTargetGroup(Handle plugin, int numParams) {
	char phrase[64];
	char file[128];
	GetNativeString(1,phrase,sizeof(phrase));
	GetNativeString(2,file,sizeof(file));
	return PushPhraseToList(g_groupTranslations, phrase, plugin, file);
}

public int Native_UnregisterSenderFlag(Handle plugin, int numParams) {
	DropPhrasesFromList(g_senderflagTranslations, plugin);
	return 0;
}

public int Native_UnregisterTargetGroup(Handle plugin, int numParams) {
	DropPhrasesFromList(g_groupTranslations, plugin);
	return 0;
}

public int Native_SendChat(Handle plugin, int numParams) {
	int sender = GetNativeCell(1);
	ArrayList orec = GetNativeCell(2);
	
	// build up current message data
	g_currentMessage.Reset();
	if (!(0<=sender<=MaxClients)) ThrowNativeError(SP_ERROR_INDEX, "Invalid sender index");
	g_currentMessage.sender = sender;
	if (orec == INVALID_HANDLE) {
		for (int client=1;client<=MaxClients;client++) {
			if (IsClientInGame(client)) {
				g_currentMessage.listRecipients.Push(client);
			}
		}
	} else {
		for (int at;at<orec.Length;at++) {
			int client = orec.Get(at);
			if (1<=client<=MaxClients && IsClientInGame(client)) {
				g_currentMessage.listRecipients.Push(client);
			}
		}
	}
	
	FormatEx(g_currentMessage.sender_name, sizeof(MessageData::sender_name), "%N", sender);
	GetNativeString(3, g_currentMessage.message, sizeof(MessageData::message));
	
	// replace all control characters with a question mark. not possible through steam, but hacker can do
	int len = strlen(g_currentMessage.sender_name);
	for (int pos; pos<len; pos++) if (g_currentMessage.sender_name[pos] < 0x32) g_currentMessage.sender_name[pos]='?';
	// copy as initial display name
	strcopy(g_currentMessage.sender_display, sizeof(MessageData::sender_display), g_currentMessage.sender_name);
	
	g_currentMessage.senderflags = GetNativeCell(4);
	g_currentMessage.group = GetNativeCell(5);
	g_currentMessage.options = GetNativeCell(6);
	if (g_currentMessage.options & mcpMsgGrouptagColor)
		GetNativeString(7, g_currentMessage.customTagColor, sizeof(MessageData::customTagColor));
	
	BuildMessageFormat(g_currentMessage.senderflags, g_currentMessage.group, g_currentMessage.msg_name, sizeof(MessageData::msg_name));
	g_currentMessage.valid = true;
	g_currentMessage.changed = true; //force resend
	//shimmy in custom data
	any pluginData = GetNativeCell(8);
	if (pluginData != 0) {
		ExternalData data;
		data.plugin = plugin;
		data.data = pluginData;
		g_currentMessage.userMessageData.PushArray(data);
	}
	//temporarily allow newlines, this is a hack and should probably be done cleaner
	bool wouldBan = (g_sanitizeInput & mcpInputBanNewline) == mcpInputBanNewline;
	g_sanitizeInput &=~ mcpInputBanNewline;
	QueueMessage();
	if (wouldBan) g_sanitizeInput |= mcpInputBanNewline;
	return 0;
}

public int Native_SetNamePrefix(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (1<=client<=MaxClients && IsClientConnected(client))
		GetNativeString(2, clientNamePrefix[client], sizeof(clientNamePrefix[]));
	else
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index or client not connected");
	return 0;
}

public int Native_GetNamePrefix(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	if (1<=client<=MaxClients && IsClientConnected(client))
		SetNativeString(2, clientNamePrefix[client], maxlen);
	else
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index or client not connected");
	return 0;
}

public int Native_SetChatColor(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (1<=client<=MaxClients && IsClientConnected(client))
		GetNativeString(1, clientChatColor[client], sizeof(clientChatColor[]));
	else
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index or client not connected");
	return 0;
}

public int Native_GetChatColor(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	if (1<=client<=MaxClients && IsClientConnected(client))
		SetNativeString(2, clientChatColor[client], maxlen);
	else
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index or client not connected");
	return 0;
}

public any Native_SetMsgData(Handle plugin, int numParams) {
	if (!g_currentMessage.valid) ThrowNativeError(SP_ERROR_ABORTED, "There is currently no chat message processed!");
	int at = g_currentMessage.userMessageData.FindValue(plugin, ExternalData::plugin);
	if (at>=0) {
		any value = g_currentMessage.userMessageData.Get(at, ExternalData::data);
		g_currentMessage.userMessageData.Set(at, GetNativeCell(1), ExternalData::data);
		return value;
	} else {
		ExternalData data;
		data.plugin = plugin;
		data.data = GetNativeCell(1);
		g_currentMessage.userMessageData.PushArray(data);
		return 0;
	}
}

public any Native_GetMsgData(Handle plugin, int numParams) {
	if (!g_currentMessage.valid) ThrowNativeError(SP_ERROR_ABORTED, "There is currently no chat message processed!");
	int at = g_currentMessage.userMessageData.FindValue(plugin, ExternalData::plugin);
	if (at>=0) {
		return g_currentMessage.userMessageData.Get(at, ExternalData::data);
	}
	return 0;
}
