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
#include <clientprefs>

static Cookie cookieTag = null;
static Cookie cookieName = null;
static Cookie cookieChat = null;

void mcp_ccc_init() {
	cookieTag = RegClientCookie("ccc_toggle_tag", "Custom Chat Colors Toggle - Tag", CookieAccess_Private);
	cookieName = RegClientCookie("ccc_toggle_name_color", "Custom Chat Colors Toggle - Name Color", CookieAccess_Private);
	cookieChat = RegClientCookie("ccc_toggle_chat_color", "Custom Chat Colors Toggle - Chat Color", CookieAccess_Private);
}

//this will parse back colors from ccc into mcp
// this allows other plugins to constistently fetch player colors without
// having to know or bother with ccc

//reloading the ccc config should trigger this again as well
// is @noreturn
public int CCC_OnUserConfigLoaded(int client) {
	if ((g_compatLevel & mcpCompatCCC) == mcpCompatNone) return;

	LoadClientColor(client);
}

public Action CCC_OnColor(int client, const char[] message, CCC_ColorType type) {
	if ((g_compatLevel & mcpCompatCCC) == mcpCompatNone) return Plugin_Continue;

	// because CCC toggle also uses this forward, we will always supress and handle
	// colors ourselfs. This means we need to reload this client, condidering
	// their CCC-T config, and skip loading stuff accordingly.
	LoadClientColor(client);
	return Plugin_Handled;
}

static void LoadClientColor(int client) {
	char prefixBuffer[128];
	char temp[64];
	bool tagHasAlpha;

	bool useClientTag = true;
	bool useClientNameColor = true;
	bool useClientChatColor = true;
	if (cookieTag != null) {
		// support for CCC-Toggle
		// color should not bleed, there are defaults in CCC
		cookieTag.Get(client, temp, sizeof(temp));
		useClientTag = StringToInt(temp)==0;
		cookieName.Get(client, temp, sizeof(temp));
		useClientNameColor = StringToInt(temp)==0;
		cookieChat.Get(client, temp, sizeof(temp));
		useClientChatColor = StringToInt(temp)==0;
	}

	if (useClientTag) {
		//read prefix color
		int tagColor = CCC_GetColor(client, CCC_TagColor, tagHasAlpha);
		parseColor(temp, sizeof(temp), tagColor, tagHasAlpha);
		StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
		//read prefix tag
		CCC_GetTag(client, temp, sizeof(temp));
		StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
	}
	if (useClientNameColor) {
		//read name color
		bool nameHasAlpha;
		int nameColor = CCC_GetColor(client, CCC_NameColor, nameHasAlpha);
		parseColor(temp, sizeof(temp), nameColor, nameHasAlpha);
		StrCat(prefixBuffer, sizeof(prefixBuffer), temp);
	} else {
		StrCat(prefixBuffer, sizeof(prefixBuffer), "\x03")
	}
	if (useClientChatColor) {
		//read chat color
		bool chatHasAlpha;
		int chatColor = CCC_GetColor(client, CCC_ChatColor, chatHasAlpha);
		parseColor(temp, sizeof(temp), chatColor, chatHasAlpha);
	} else {
		temp="\x01";
	}
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
			if (tagHasAlpha) Format(buffer, size, "\x08;%08X", tagColor);
			else Format(buffer, size, "\x07;%06X", tagColor);
		}
	}
}