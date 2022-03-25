#if defined _mcp_included
#endinput
#endif
#define _mcp_included

//yywwrr: y year, w week in year, r revision in week
#define MCP_VERSION 221101

/**
 * Sender flags appear before the chat entry in asterisks: *DEAD*
 * Their purpose is to give more information about the senders status.
 * These are bitflags and can be combined in mcp, even if not originally supported.
 *
 * Note: These flags are for formatting only, the recipients list is still relevant!
 */
enum mcpSenderFlag (<<=1) {
	mcpSenderNone      = 0,
	mcpSenderDead      = 1, /* the sender is currently dead */
	mcpSenderSpectator = 2, /* the sender is specating */
	/* other values should be treated as custom, not invalid */
}

/**
 * Target groups appear in paranthesis before the chat entry: (TEAM)
 * Their purpose is to tell you who can read this message.
 * Ordering is choosen deliberately so GetClientTeam should match spec...team4
 *
 * Note: These flags are for formatting only, the recipients list is still relevant!
 */
enum mcpTargetGroup (+=1) {
	mcpTargetNone         = 0, /* hide the group */
	mcpTargetSpecator     = 1, /* spectator intern chat, e.g. (Spectator) */
	mcpTargetTeam1        = 2, /* chat for team 1 (index 2), e.g. (Terrorist) */
	mcpTargetTeam2        = 3, /* chat for team 2 (index 3), e.g. (Counter-Terrorist) */
	mcpTargetTeam3        = 4, /* chat for team 3 (index 4) */
	mcpTargetTeam4        = 5, /* chat for team 4 (index 5) */
	mcpTargetTeamSender   = 6, /* sender team, e.g. (TEAM) */
	mcpTargetAll          = 7, /* Non-standard special highlighted /chat or @message, e.g. (ALL) */
	mcpTargetAdmin        = 8, /* Non-standard special admin chat, e.g. (ADMIN) */
	mcpTargetDirect       = 9, /* Non-standard special private message, e.g. (DM) */
	/* other values should be treated as custom, not invalid */
}

enum mcpMessageOption (<<=1) {
	mcpMsgDefault         = 0, // white *flag* and (group), allow colors in name and message. Not that default also means the message gets copied to console
	mcpMsgProcessColors   = 1, //This message should process color templates like {Red}
	mcpMsgRemoveColors    = 2, //This message should remove colos including \x07RRGGBB
	mcpMsgGrouptagColor   = 4, //This message has a custom group tag color set
	mcpMsgIgnoreNameColor = 8, //The group tag color will replace tag and name color
	mcpMsgNoConsoleCopy   = 16, //The message will only print to chat, and not to console
}

enum mcpHookType (+=1) {
	mcpHookPre=0,      //message was just parsed, name and message not available
	mcpHookEarly,      //eraly message hook. ONLY USE IF DEFAULT IS TOO LATE!
	mcpHookDefault,    //normal message hook
	mcpHookLate,       //late message hook. ONLY USE IF DEFAULT IS TOO EARLY!
	mcpHookFormatted,  //per-recipient callback for changed(!) messages
	mcpHookPost,       //message left the server
}

#define MCP_MAXLENGTH_COLORTAG 32
#define MCP_MAXLENGTH_TRANPHRASE 64
#define MCP_MAXLENGTH_NAME 128
#define MCP_MAXLENGTH_INPUT 128
#define MCP_MAXLENGTH_NETMESSAGE 256

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
	 * mcpHookFormatted:
	 * Allows you to late manipulate the message on a per-recipient basis, just before it's sent.
	 * Note: This is only called for messages that were changed previously, as unchanged messages are pass-through and should use valve localizations.
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

/**
 * Add a callback to the corresponding mcpHookType, see the comments in the typedef for what to use when.
 * 
 * @param callback - the function to add
 * @param type - what type the specified callback is
 * @noreturn
 */
native void MCP_HookChatMessage(ChatMessageCallback callback, mcpHookType type=mcpHookDefault);

/**
 * Add a translation phrase for a custom sender flag prefix.
 * You can OR the return value to senderflags to add the prefix in ** before a chat message.
 * 
 * @param phrase - the translation phrase to use for this senderflag
 * @param translationFile - the translation file that contains your phrase, so mcp can format the message
 * @return 0 if the flag could not be registered; the bit mask for the flag on success
 * @error if the pharse could not be found / loaded
 */
native int MCP_RegisterSenderFlag(const char[] phrase, const char[] translationFile);

/**
 * Add a translation phrase for a custom target group prefix.
 * You can set the targetgroup to the returned value in your message hook to set the () prefix before a chat message.
 *
 * @param phrase - the translation phrase to use for this targetgroup
 * @param translationFile - the translation file that contains your phrase, so mcp can format the message
 * @return 0 if the group phrase could not be registered; the index for your group phrase on success
 */
native int MCP_RegisterTargetGroup(const char[] phrase, const char[] translationFile);

/**
 * Remove your custom sender flags from the registry
 */
native void MCP_UnregisterSenderFlags();

/**
 * Remove your custom sender flags from the registry
 */
native void MCP_UnregisterTargetGroups();

//ok, so to make PrintToChat work properly, we would have to do the following:
// * pre parse the message, and check if it roughly has the chat format
//  *words*(words) name : message
// * reverse parse out the name, reverse lookup the group and senderflag phrase
// * group up all usermsgs within a tick that have the same message & group/flags
// * before we can do the usual callback shenanigans; what a mess
//  oh yea, and also don't forget that e.g. chineese does not use ascii symbols to
//  prefix their message **()
// the intermediate storage would be a stringmap<message,meta>
//  with meta being recipient & prefix data
// BUT since most plugins are using CPrintToChat and that defaults to an unhookable
// SayText2 message we cannot even rely on that to be working!
// My solution: Make a native

/**
 * Sends a Chat-Formatted SayText message ala
 *  *DEAD*(ADMIN) name :  Hello There
 * MCP_SendChat(author, recipients, "Hello There", mcpSenderDead, mcpTargetAdmin, mcpMsgGrouptagColor|mcpMsgIgnoreNameColor, "\x04");
 *  This call has no guarantee that the message will actually arrive at the
 *  recipients as the chat processor hooks might block it.
 */
native void MCP_SendChat(int author, ArrayList recipients, const char[] message, mcpSenderFlag flags = mcpSenderNone, mcpTargetGroup group = mcpTargetNone, mcpMessageOption options = mcpMsgDefault, const char[] tagColor = "");

/**
Shared plugin information
**/
public SharedPlugin __pl_MetaChatProcessor = {
	name = "MetaChatProcessor",
	file = "MetaChatProcessor.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_MetaChatProcessor_SetNTVOptional() {
	MarkNativeAsOptional("MCP_HookChatMessage");
	MarkNativeAsOptional("MCP_RegisterSenderFlag");
	MarkNativeAsOptional("MCP_RegisterTargetGroup");
	MarkNativeAsOptional("MCP_UnregisterSenderFlags");
	MarkNativeAsOptional("MCP_UnregisterTargetGroups");
	MarkNativeAsOptional("MCP_SendChat");
}
#endif