#if defined _mcp_pluginapi
#endinput
#endif
#define _mcp_pluginapi
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

typeset ChatMessageCallback {
	/**
	 * mcpHookPre:
	 * A chat message was just hooked, here you can do dummy default stuff to messages or do early blocking.
	 *
	 * @param sender - the client writing this chat message
	 * @param recipients - a list of clients receiving this chat message
	 * @param senderflags - flags on what to contain in the ** string before a chat message
	 * @param targetgroup - the group that this message is directed to, displayed in () before a chat message
	 * @param options - some message processing options
	 * @param targetgroupColor - color for the targetgroup, if mcpMsgGrouptagColor is set. Can be a color name (without curlies) or a color code. MCP_MAXLENGTH_COLORTAG
	 * @return Action as usual, >= Plugin_Handled to prevent sending, Plugin_Changed if you changed a value
	 */
	function Action (int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor);
	
	/**
	 * mcpHookEarly,
	 * mcpHookDefault,
	 * mcpHookLate:
	 * Listen for and edit chat messages
	 * 
	 * @param sender - the client writing this chat message
	 * @param recipients - a list of clients receiving this chat message
	 * @param senderflags - flags on what to contain in the ** string before a chat message
	 * @param targetgroup - the group that this message is directed to, displayed in () before a chat message
	 * @param options - some message processing options
	 * @param targetgroupColor - color for the targetgroup, if mcpMsgGrouptagColor is set. Can be a color name (without curlies) or a color code. MCP_MAXLENGTH_COLORTAG
	 * @param name - the senders displayname. MCP_MAXLENGTH_NAME
	 * @param message - the mesage to send. MCP_MAXLENGTH_INPUT
	 * @return Action as usual, >= Plugin_Handled to prevent sending, Plugin_Changed if you changed a value
	 */
	function Action (int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor, char[] name, char[] message);
	
	/**
	 * mcpHookColors:
	 * Intercept name tagging / coloring
	 * This is intended to be use to HOOK the processing of coloring the clients name, chat, etc.
	 * You can set default tag, name and chat color directly! This is meant to change colors in specific cases or for compat plugins!
	 * The result will be used to format the message as follows:
	 *  *{flags}*{groupcolor optional}({group}) {nameTag optional} {displayName} : {chatColor}{message}
	 * 
	 * @param sender - the client writing this chat message
	 * @param senderflags - flags on what to contain in the ** string before a chat message
	 * @param targetgroup - the group that this message is directed to, displayed in () before a chat message
	 * @param options - some message processing options
	 * @param nameTag - a tag for the clients name. usually things like [Admin]. Includes colors!
	 * @param displayName - the name that will be displayed. Includes colors!
	 * @param chatColor - the default color for this clients chat. Can be a color name (without curlies) or color code. MCP_MAXLENGTH_COLORTAG
	 * @return Plugin_Handled will block changes, Plugin_Stop will strip colors!
	 */
	function Action (int sender, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, char[] nameTag, char[] displayName, char[] chatColor);
	
	/**
	 * mcpHookFormatted:
	 * Allows you to late manipulate the message on a per-recipient basis, just before it's sent.
	 * Note: This is only called for messages that were changed previously, as unchanged messages are pass-through and should use valve localizations.
	 * The message is rougly formatted as follows:
	 *  *{flags}*{groupcolor optional}({group}) {nameTag optional} {displayName} : {chatColor}{message}
	 * 
	 * @param sender - the client writing this chat message
	 * @param recipients - a list of clients receiving this chat message
	 * @param senderflags - flags on what to contain in the ** string before a chat message
	 * @param targetgroup - the group that this message is directed to, displayed in () before a chat message
	 * @param options - some message processing options
	 * @param formatted - the fully formatted message as about to be sent. MCP_MAXLENGTH_NETMESSAGE
	 * @return Action as usual, >= Plugin_Handled to prevent sending, Plugin_Changed if you changed a value
	 */
	function Action (int sender, int recipient, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, char[] formatted);
	
	/**
	 * mcpHookPost
	 * This chat message was sent to the recipients. The message may not be 100% accurate if changed in the *Formatted hook.
	 *
	 * @param sender - the client writing this chat message
	 * @param recipients - a list of clients receiving this chat message
	 * @param senderflags - flags on what to contain in the ** string before a chat message
	 * @param targetgroup - the group that this message is directed to, displayed in () before a chat message
	 * @param options - some message processing options
	 * @param targetgroupColor - color for the targetgroup, if mcpMsgGrouptagColor is set. Can be a color name (without curlies) or a color code. MCP_MAXLENGTH_COLORTAG
	 * @param name - the senders displayname. MCP_MAXLENGTH_NAME
	 * @param message - the mesage to send. MCP_MAXLENGTH_INPUT
	 * @noreturn
	 */
	function void (int sender, ArrayList recipients, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, const char[] targetgroupColor, const char[] name, const char[] message);
}

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
	CreateNative("MCP_RegisterSenderFlag", Native_RegisterSenderFlag);
	CreateNative("MCP_RegisterTargetGroup", Native_RegisterTargetGroup);
	CreateNative("MCP_UnregisterSenderFlags", Native_UnregisterSenderFlag);
	CreateNative("MCP_UnregisterTargetGroups", Native_UnregisterTargetGroup);
	CreateNative("MCP_SendChat", Native_SendChat);
	
	CreateNative("MCP_SetClientDefaultNamePrefix", Native_SetNamePrefix);
	CreateNative("MCP_GetClientDefaultNamePrefix", Native_GetNamePrefix);
	CreateNative("MCP_SetClientDefaultChatColor", Native_SetChatColor);
	CreateNative("MCP_GetClientDefaultChatColor", Native_GetChatColor);
	
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
	if (g_compatLevel & mcpCompatSCPRedux)
		mcp_scp_pluginsloaded();
	if (g_compatLevel & mcpCompatDrixevel)
		mcp_drixevel_pluginsloaded();
	if (g_compatLevel & mcpCompatCiderCP)
		mcp_cider_pluginsloaded();
}


// -------------------- FORWARD WRAPPER --------------------

/**
 * Check for no errors, validate recipients and optionally rebuild msg_format string.
 * will close the recipients handle as that's temporary now
 */
static void ValidateAfterCall(const char[] stage, int error, Action returnedAction, ArrayList recipients, bool rebuildMessageFormat=false) {
	if (recipients != null && !IsValidHandle(recipients)) {//use is fine: handle.close() is not nulling, so i have to check this was if plugins are bad
		ThrowError("MCP_OnChatMessage%s closed the recipients handle! What are you, mad?", stage);
	} else if (returnedAction == Plugin_Changed && recipients.Length == 0 && g_currentMessage.recipientCount > 0) {
		static bool hasWarned;
		if (!hasWarned) {
			hasWarned = true;
			LogError("MCP_OnChatMessage%s cleard the recipients list instead of cancelling - As PluginDev, Please reconsider", stage);
		}
		g_currentMessage.recipientCount = 0;
		delete recipients;
	} else { //remove doubles
		recipients.Sort(Sort_Ascending, Sort_Integer);
		for (int i=recipients.Length-1; i>0; i-=1) {
			if (recipients.Get(i) == recipients.Get(i-1))
				recipients.Erase(i);
		}
		g_currentMessage.SetRecipients(recipients);
		delete recipients;
	}
	if (error != SP_ERROR_NONE) {
		ThrowError("MCP_OnChatMessage%s failed with error code %i", stage, error);
	}
	if (returnedAction == Plugin_Changed && rebuildMessageFormat)
		BuildMessageFormat(g_currentMessage.senderflags, g_currentMessage.group, g_currentMessage.msg_name, sizeof(MessageData::msg_name));
}

Action Call_OnChatMessagePre() {
	if (!g_fwdOnMessagePre.FunctionCount) return Plugin_Continue;
	ArrayList recipients = new ArrayList();
	g_currentMessage.GetRecipients(recipients);
	mcpSenderFlag preFlags = g_currentMessage.senderflags;
	mcpTargetGroup preGroup = g_currentMessage.group;
	
	Call_StartForward(g_fwdOnMessagePre);
	Call_PushCellRef(g_currentMessage.sender);
	Call_PushCell(recipients);
	Call_PushCellRef(g_currentMessage.senderflags);
	Call_PushCellRef(g_currentMessage.group);
	Call_PushCellRef(g_currentMessage.options);
	Call_PushStringEx(g_currentMessage.customTagColor, sizeof(MessageData::customTagColor), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall("Pre", error, result, recipients, (g_currentMessage.senderflags != preFlags || g_currentMessage.group != preGroup));
	return result;
}

Action Call_OnChatMessage(int stage) {
	PrivateForward funForward;
	if (stage < 0) funForward = g_fwdOnMessage_Early;
	else if (stage > 0) funForward = g_fwdOnMessage_Late;
	else funForward = g_fwdOnMessage_Normal;
	if (!funForward.FunctionCount) return Plugin_Continue;
	ArrayList recipients = new ArrayList();
	g_currentMessage.GetRecipients(recipients);
	mcpSenderFlag preFlags = g_currentMessage.senderflags;
	mcpTargetGroup preGroup = g_currentMessage.group;
	
	Call_StartForward(funForward);
	Call_PushCellRef(g_currentMessage.sender);
	Call_PushCell(recipients);
	Call_PushCellRef(g_currentMessage.senderflags);
	Call_PushCellRef(g_currentMessage.group);
	Call_PushCellRef(g_currentMessage.options);
	Call_PushStringEx(g_currentMessage.customTagColor, sizeof(MessageData::customTagColor), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(g_currentMessage.message, sizeof(MessageData::message), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall(stage<0?"Early":(stage?"Late":""), error, result, recipients, (g_currentMessage.senderflags != preFlags || g_currentMessage.group != preGroup));
	return result;
}

Action Call_OnChatMessageColors(char[] nameTag, char[] displayName, char[] chatColorTag) {
	if (!g_fwdOnMessageFormatted.FunctionCount) return Plugin_Continue;
	
	Call_StartForward(g_fwdOnMessageFormatted);
	Call_PushCell(g_currentMessage.sender);
	Call_PushCell(g_currentMessage.senderflags);
	Call_PushCell(g_currentMessage.group);
	Call_PushCell(g_currentMessage.options);
	Call_PushStringEx(nameTag, MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(displayName, MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(chatColorTag, MAXLENGTH_COLORTAG, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall("Colors", error, result, null);
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
	Call_PushCell(maxlen);
	Action result;
	int error = Call_Finish(result);
	
	ValidateAfterCall("Formatted", error, result, null);
	return result;
}

void Call_OnChatMessagePost() {
	if (!g_fwdOnMessagePost.FunctionCount) return;
	ArrayList recipients = new ArrayList();
	g_currentMessage.GetRecipients(recipients);
	
	Call_StartForward(g_fwdOnMessagePost);
	Call_PushCell(g_currentMessage.sender);
	Call_PushCell(recipients);
	Call_PushCell(g_currentMessage.senderflags);
	Call_PushCell(g_currentMessage.group);
	Call_PushCell(g_currentMessage.options);
	Call_PushStringEx(g_currentMessage.customTagColor, sizeof(MessageData::customTagColor), SM_PARAM_STRING_UTF8, 0);
	Call_PushStringEx(g_currentMessage.sender_display, sizeof(MessageData::sender_display), SM_PARAM_STRING_UTF8, 0);
	Call_PushStringEx(g_currentMessage.message, sizeof(MessageData::message), SM_PARAM_STRING_UTF8, 0);
	int error = Call_Finish();
	
	ValidateAfterCall("Post", error, Plugin_Continue, recipients);
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
		case 5: g_fwdOnMessageFormatted.AddFunction(plugin, fun);
		case 6: g_fwdOnMessagePost.AddFunction(plugin, fun);
		default: ThrowNativeError(SP_ERROR_PARAM, "Invalid hook type");
	}
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
}

public int Native_UnregisterTargetGroup(Handle plugin, int numParams) {
	DropPhrasesFromList(g_groupTranslations, plugin);
}

public int Native_SendChat(Handle plugin, int numParams) {
	int sender = GetNativeCell(1);
	ArrayList orec = GetNativeCell(2);
	
	// build up current message data
	g_currentMessage.Reset();
	if (!sender) ThrowNativeError(SP_ERROR_INDEX, "Server not supported as Sender");
	else if (!(1<=sender<=MaxClients)) ThrowNativeError(SP_ERROR_INDEX, "Invalid client index");
	g_currentMessage.sender = sender;
	if (orec == INVALID_HANDLE) {
		for (int client=1;client<=MaxClients;client++)
			if (IsClientInGame(client)) {
				g_currentMessage.recipients[g_currentMessage.recipientCount] = client;
				g_currentMessage.recipientCount += 1;
			}
	} else {
		for (int at;at<orec.Length;at++) {
			int client = orec.Get(at);
			if (1<=client<=MaxClients && IsClientInGame(client)) {
				g_currentMessage.recipients[g_currentMessage.recipientCount] = client;
				g_currentMessage.recipientCount += 1;
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
	ProcessSayText2();
}