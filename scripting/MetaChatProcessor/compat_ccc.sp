#if defined _mcp_compat_ccc
#endinput
#endif
#define _mcp_compat_ccc
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

#undef REQUIRE_PLUGIN
#pragma newdecls optional
#include <ccc>
#pragma newdecls required
#define REQUIRE_PLUGIN

//this will parse back colors from ccc into mcp
// this allows other plugins to constistently fetch player colors without
// having to know or bother with ccc

//reloading the ccc config should trigger this again as well
// is @noreturn
public int CCC_OnUserConfigLoaded(int client) {
	if ((g_compatLevel & mcpCompatCCC) == mcpCompatNone) return;
	
	char prefixBuffer[128];
	//read prefix color
	char temp[64];
	bool tagHasAlpha;
	int tagColor = CCC_GetColor(client, CCC_TagColor, tagHasAlpha);
	parseColor(temp, sizeof(temp), tagColor, tagHasAlpha);
	StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
	//read prefix tag
	CCC_GetTag(client, temp, sizeof(temp));
	StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
	//read name color
	bool nameHasAlpha;
	int nameColor = CCC_GetColor(client, CCC_NameColor, nameHasAlpha);
	parseColor(temp, sizeof(temp), nameColor, nameHasAlpha);
	StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
	//read chat color
	bool chatHasAlpha;
	int chatColor = CCC_GetColor(client, CCC_ChatColor, chatHasAlpha);
	parseColor(temp, sizeof(temp), chatColor, chatHasAlpha);
	//copy cat
	strcopy(clientNamePrefix[client], sizeof(clientNamePrefix[]), prefixBuffer);
	strcopy(clientChatColor[client], sizeof(clientChatColor[]), temp);
}

static void parseColor(char[] buffer, int size, int tagColor, bool tagHasAlpha) {
	switch (tagColor) {
		case COLOR_NONE: { strcopy(buffer, size, "\x01"); }
		case COLOR_TEAM: { strcopy(buffer, size, "\x03"); }
		case COLOR_GREEN: { strcopy(buffer, size, "\x04"); }
		case COLOR_OLIVE: { strcopy(buffer, size, "\x05"); }
		default: {
			if (tagHasAlpha) Format(buffer, size, "\x08%08X", tagColor);
			else Format(buffer, size, "\x07%06X", tagColor);
		}
	}
}