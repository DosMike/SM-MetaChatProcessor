#if defined _mcp_common_types
#endinput
#endif
#define _mcp_common_types

/**
 * Different constants
 */
#define MCP_MAXLENGTH_COLORTAG		32		// Maximum buffer for you to put a color in. only one color code or color name should be contained
#define MCP_MAXLENGTH_TRANPHRASE	64		// Size buffer for a translation phrase for sender flag or group names.
#define MCP_MAXLENGTH_INPUT			192		// Inclues \0. The size of the chat input box is 128. This is a bit longer than the chat box to allow plugins inserting long color namewhen formatting, as those might collapse when parsed.
#define MCP_MAXLENGTH_NAME			128		// Game has a max length of 32, this buffer is bigger to allow for tags and colors without breaking the name
#define MCP_MAXLENGTH_MESSAGE		256		// This is based upon the SDK and the length of the entire message, including tags, name, etc. (we can't send more)

/** unicode block E000..F8FF is private use area, E000..EFFF is "user zone" for linux
 * so let's use that block to properly escape curlies for clients that are not allowed to use colors
 * these unicodes are 3 bytes! EE8080..EEBFBF with 4,2,2 bits per byte reserved for utf8 multibyte markers
 *  I'm using C01 for "C01or" so it wont clash as easily if other people use the PUA block
 */
#define MCP_PUA_ESCAPED_LCURLY "\uEC01"

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
enum mcpTargetGroup {
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
	mcpMsgProcessColors   = 1, //This message should process color templates like {Red} -> intended to give plugins multicolor support
	mcpMsgRemoveColors    = 2, //This message should remove colos including \x07RRGGBB -> intended to clean input
	mcpMsgGrouptagColor   = 4, //This message has a custom group tag color set
	mcpMsgIgnoreNameColor = 8, //The group tag color will replace tag and name color
	mcpMsgNoConsoleCopy   = 16, //The message will only print to chat, and not to console
}

/** executed in this order */
enum mcpHookType (+=1) {
	mcpHookPre       = 0, //message was just parsed, name and message not available
	mcpHookEarly     = 1, //eraly message hook. ONLY USE IF DEFAULT IS TOO LATE!
	mcpHookDefault   = 2, //normal message hook
	mcpHookLate      = 3, //late message hook. ONLY USE IF DEFAULT IS TOO EARLY!
	mcpHookColor     = 4, //name tag and default chat colors are applied
	mcpHookFormatted = 5, //per-recipient callback for changed(!) messages
	mcpHookPost      = 6, //message left the server
}

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
