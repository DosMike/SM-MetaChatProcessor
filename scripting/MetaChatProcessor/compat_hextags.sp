#if defined _mcp_compat_hextags
#endinput
#endif
#define _mcp_compat_hextags
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

#undef REQUIRE_PLUGIN
#include <hextags>
#define REQUIRE_PLUGIN

//this will parse back colors from hextags into mcp
// this allows other plugins to constistently fetch player colors without
// having to know or bother with hextags

public void HexTags_OnTagsUpdated(int client) {
	parseColors(client);
}
public void HexTags_ResetClientTag(int client) {
	parseColors(client);
}
static void parseColors(int client) {
	if ((g_compatLevel & mcpCompatHexTags) == mcpCompatNone) return;
	
	char prefixBuffer[128];
	//read prefix color&tag
	char temp[64];
	bool tagHasAlpha;
	HexTags_GetClientTag(client, ChatTag, temp, sizeof(temp));
	CFormatColor(temp, sizeof(temp), client);
	StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
	//read name color
	HexTags_GetClientTag(client, NameColor, temp, sizeof(temp))
	CFormatColor(temp, sizeof(temp), client);
	StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
	//copy into client prefix
	strcopy(clientNamePrefix[client], sizeof(clientNamePrefix[]), prefixBuffer);
	//read chat color
	HexTags_GetClientTag(client, ChatColor, temp, sizeof(temp))
	CFormatColor(temp, sizeof(temp), client);
	GetNativeColor(temp, clientChatColor[client], sizeof(clientChatColor[]));
}