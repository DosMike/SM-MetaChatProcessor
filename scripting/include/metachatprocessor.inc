#if defined _mcp_included
#endinput
#endif
#define _mcp_included

//yywwrr: y year, w week in year, r revision in week
#define MCP_VERSION 221101

#include "metachatprocessor/types.inc"

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