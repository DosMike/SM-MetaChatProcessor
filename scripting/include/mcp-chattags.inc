#if defined _mcp_chattags_included
#endinput
#endif
#define _mcp_chattags_included

enum MCP_CT_ChatStyleOptions {
	MCP_CS_NONE = 0,
	MCP_CS_TAGCOLOR = 1,
	MCP_CS_TAGTEXT = 2,
	MCP_CS_NAMECOLOR = 4,
	MCP_CS_CHATCOLOR = 8,
}

/**
 * Called when the Chat Tag profile for the client changes and replaces the
 * clients default values.
 * You can change the style options to control what's used.
 * Stopping this will keep the previous profile active.
 * @param client - the client that changed their profile
 * @param prefix - the chat prefix
 * @param chatcolor - the text color
 * @param style - style bits that are active
 * @return Plugin_Changed to override the style, Plugin_Handled if you intend to override manually, and Plugin_Stop to get the client notified that the change was blocked
 */
forward Action MCP_CT_OnProfileChanged(int client, const char[] profile, const char[] prefix, const char[] chatcolor, MCP_CT_ChatStyleOptions& style);

/**
 * Fill an arraylist with names of profiles the client can activate
 * @param client - the player
 * @return an arraylist with profile names. you have to delete this
 */
native ArrayList MCP_CT_GetClientProfiles(int client);

/**
 * Force a specific chat tag profile and style active on the client.
 * This will replace the user picked settings, and might confuse players!
 * If you want to override format, use MCP events instead.
 * @param client - the player
 * @param name - take from list
 * @param style - what to display
 */
native void MCP_CT_ForceClientProfile(int client, const char[] name, MCP_CT_ChatStyleOptions style);

/**
Shared plugin information
**/
public SharedPlugin __pl_MCPChatTags = {
	name = "MCP-ChatTags",
	file = "mcp-chattags.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_MCPChatTags_SetNTVOptional() {
	MarkNativeAsOptional("MCP_CT_GetClientProfiles");
	MarkNativeAsOptional("MCP_CT_ForceClientProfile");
}
#endif
