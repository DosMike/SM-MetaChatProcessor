#include <sourcemod>
#include <clientprefs>

#include "include/metachatprocessor.inc"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "23w31b"

#define STR_NO_PROFILE "None"
#define STR_PERSONAL "Personal"

enum ChatStyleOptions {
	CS_NONE = 0,
	CS_TAGCOLOR = 1,
	CS_TAGTEXT = 2,
	CS_NAMECOLOR = 4,
	CS_CHATCOLOR = 8,
	CS_PREFIX = 7,
}

enum struct ChatStyle {
	char filter[MAX_AUTHID_LENGTH];
	char name[32];
	char tag[64];
	char chat[12];
	void apply(int client, ChatStyleOptions style) {
		ApplyProfileValues(client, this.name, this.tag, this.chat, style);
	}
}

ArrayList profiles;

Cookie mcpct_style; //what to color
Cookie mcpct_profile; //profile name
Cookie mcpct_crc; //if the crc changes, we have a new profile

GlobalForward mcpct_fwd_change;

ConVar cvar_settingsMenuEnabled;
ConVar cvar_loadBehaviour;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("MCP_CT_GetClientProfiles", Native_GetProfiles);
	CreateNative("MCP_CT_ForceClientProfile", Native_SetProfile);
	RegPluginLibrary("MCPChatTags");
	return APLRes_Success;
}


public void OnPluginStart() {
	profiles = new ArrayList(sizeof(ChatStyle));
	LoadConfig();
	
	mcpct_style = new Cookie("mcpchattag_style", "Style of MCP Chat Tag", CookieAccess_Private);
	mcpct_profile = new Cookie("mcpchattag_profile", "Style of MCP Chat Tag", CookieAccess_Private);
	mcpct_crc = new Cookie("mcpchattag_checksum", "CRC of available profiles to detect changes", CookieAccess_Private);
	
	mcpct_fwd_change = CreateGlobalForward("MCP_CT_OnProfileChanged", ET_Event, Param_Cell, Param_String, Param_String, Param_String, Param_CellByRef);
	
	SetCookieMenuItem(ChatTagCookieMenu, 0, "Chat Tag Settings");
	
	cvar_settingsMenuEnabled = CreateConVar("chattag_menu_enabled", "1", "0=Disable the /settings menu, 1=Enable", _, true, 0.0, true, 1.0);
	cvar_loadBehaviour = CreateConVar("chattag_load_behaviour", "2", "What to do when a client connects. 0=Use last active profil, 1=Use forst matching profile, 2=Like 1 if available profiles changed", _, true, 0.0, true, 2.0);
	
	RegAdminCmd("sm_reloadchattags", Cmd_Reload, ADMFLAG_CONFIG, "Reload chat tags");
	
	for (int client=1;client<=MaxClients;client++) {
		OnClientPostAdminCheck(client);
	}
}

public void ChatTagCookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen) {
	if (action == CookieMenuAction_SelectOption) {
		ShowChatTagMenu(client);
	}
}

public Action Cmd_Reload(int admin, int args) {
	LoadConfig();
	for (int client=1;client<=MaxClients;client++) {
		OnClientPostAdminCheck(client);
	}
	ReplyToCommand(admin, "[ChatTag] Reloaded %d profiles", profiles.Length);
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client) {
	if (!IsClientInGame(client) || IsFakeClient(client) || IsClientReplay(client) || IsClientSourceTV(client) || !IsClientAuthorized(client))
		return;
	
	char tmp[32];
	ArrayList list = FindApplicableProfiles(client);
	
	//check profile hash
	// // make crc16
	int crc;
	for (int i; i<list.Length; i++) {
		list.GetString(i, tmp, sizeof(tmp));
		for (int c; tmp[c] != 0; c+=2) {
			crc += (tmp[c]<<8)|(tmp[c+1]);
			if ((crc & 0x10000)!=0) crc = (crc&0xffff)+1;
			if (tmp[c+1]==0) break; //next loop would be oob
		}
	}
	// // get old hash
	mcpct_crc.Get(client, tmp, sizeof(tmp));
	int oldCrc = StringToInt(tmp,16);
	// // store new hash
	FormatEx(tmp, sizeof(tmp), "%04X", crc);
	mcpct_crc.Set(client, tmp);
	// // get load behaviour
	cvar_loadBehaviour.GetString(tmp, sizeof(tmp));
	int load = StringToInt(tmp);
	// // should we refresh?
	bool refresh = ((crc != oldCrc && load==2) || load==1);
	
	PrintToServer("[ChatTag] %N %s (%04X -> %04X)", client, refresh ? "Refresh" : "Keep", oldCrc, crc);
	
	//if profile should refresh, pick the first match and save
	if (refresh && list.Length>0) {
		list.GetString(0, tmp, sizeof(tmp));
		PrintToServer("[ChatTag] %N active profile now %s", client, tmp);
		mcpct_profile.Set(client, tmp);
		mcpct_style.Set(client, "15");
	}
	delete list;
	UpdateProfile(client);
}

void LoadConfig() {
	KeyValues kv = new KeyValues("admin_colors");
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), "configs/mcp-chattags.cfg");
	if (!FileExists(buffer)) {
		BuildPath(Path_SM, buffer, sizeof(buffer), "configs/custom-chatcolors.cfg");
		PrintToServer("Loading legacy CCC profiles");
	} else if (!FileExists(buffer)) {
		PrintToServer("Could not find profiles config");
	}
	kv.ImportFromFile(buffer);
	
	profiles.Clear();
	ChatStyle style;
	if (kv.GotoFirstSubKey()) {
		do {
			bool isPersonal;
			kv.GetSectionName(buffer, sizeof(buffer));
			if (strncmp(buffer,"STEAM_",6)==0 || buffer[0]=='[') {
				isPersonal = true;
				strcopy(style.filter, sizeof(ChatStyle::filter), buffer);
				style.name = STR_PERSONAL;
			} else {
				isPersonal = false;
				kv.GetString("flag", style.filter, sizeof(ChatStyle::filter), "");
				strcopy(style.name, sizeof(ChatStyle::name), buffer);
			}
			style.tag[0]=0;
			kv.GetString("tagcolor", buffer, sizeof(buffer), "");
			TranslateColor(buffer, sizeof(buffer));
			StrCat(style.tag, sizeof(ChatStyle::tag), buffer);
			kv.GetString("tag", buffer, sizeof(buffer), "");
			MCP_RemoveTextColors(buffer, sizeof(buffer), false);
			StrCat(style.tag, sizeof(ChatStyle::tag), buffer);
			kv.GetString("namecolor", buffer, sizeof(buffer), "");
			TranslateColor(buffer, sizeof(buffer));
			StrCat(style.tag, sizeof(ChatStyle::tag), buffer);
			StrCat(style.tag, sizeof(ChatStyle::tag), " ");
			kv.GetString("textcolor", buffer, sizeof(buffer), "\x01");
			TranslateColor(buffer, sizeof(buffer));
			strcopy(style.chat, sizeof(ChatStyle::chat), buffer);
			if (isPersonal) {
				//insert front
				profiles.ShiftUp(0);
				profiles.SetArray(0, style);
			} else {
				//push back
				profiles.PushArray(style);
			}
		} while (kv.GotoNextKey());
	}
	
	delete kv;
}

ChatStyleOptions Util_StyleFromCookie(int client) {
	char val[32];
	mcpct_style.Get(client, val, sizeof(val));
	if (val[0]==0) return CS_PREFIX|CS_CHATCOLOR; //all by default
	return view_as<ChatStyleOptions>(StringToInt(val));
}

bool UpdateProfile(int client) {
	if (IsFakeClient(client)||IsClientSourceTV(client)||IsClientReplay(client))
		return false;
	char name[32];
	ChatStyleOptions style = Util_StyleFromCookie(client);
	mcpct_profile.Get(client, name, sizeof(name));
	if (style==CS_NONE || name[0]=='\0') {
		ApplyProfileValues(client, "", "", "", CS_NONE);
		return true; //successfully apply no profile
	}
	ChatStyle prof;
	for (int i=profiles.Length-1; i>=0; i--) {
		profiles.GetArray(i,prof);
		if ( StrEqual(prof.name, name, false) ||
			(StrEqual(STR_PERSONAL, name) && (prof.filter[0]=='[' || strncmp(prof.filter, "STEAM_", 6)==0)) ) {
			
			// can we still use this group?
			if (!HasPermission(client, prof.filter)) continue;
			
			prof.apply(client, style);
			return true;
		}
	}
	ApplyProfileValues(client, "", "", "", CS_NONE);
	return false;
}

void ProcessTagStyle(char[] tag, int taglen, ChatStyleOptions style) {
	PrintToServer("[ChatTag] Style: %X", style);
	char tagcopy[MCP_MAXLENGTH_NAME];
	if ((style & CS_PREFIX) != CS_NONE) {
		strcopy(tagcopy, sizeof(tagcopy), tag);
		if ((style & CS_TAGTEXT)==CS_NONE) style&=~CS_TAGCOLOR; //no point w/o text
		switch (style & CS_PREFIX) {
			case CS_PREFIX: {
			}
			case CS_NAMECOLOR: {
				MCP_GetStringColor(tagcopy, tagcopy, sizeof(tagcopy), true);
			}
			case CS_TAGTEXT|CS_NAMECOLOR: {
				char buffer[12];
				MCP_GetStringColor(tagcopy, buffer, sizeof(buffer), true);
				MCP_RemoveTextColors(tagcopy, sizeof(tagcopy), false);
				StrCat(tagcopy, sizeof(tagcopy), buffer);
			}
			case CS_TAGTEXT: {
				MCP_RemoveTextColors(tagcopy, sizeof(tagcopy), false);
				StrCat(tagcopy, sizeof(tagcopy), "\x03");
			}
			case CS_TAGTEXT|CS_TAGCOLOR: {
				StrCat(tagcopy, sizeof(tagcopy), "\x03");
			}
		}
		MCP_CollapseColors(tagcopy);
	}
	strcopy(tag, taglen, tagcopy);
}

void ApplyProfileValues(int client, const char[] name, const char[] prefix, const char[] color, ChatStyleOptions style) {
	Call_StartForward(mcpct_fwd_change);
	Call_PushCell(client);
	Call_PushString(name);
	Call_PushString(prefix);
	Call_PushString(color);
	ChatStyleOptions copyStyle=style;
	Call_PushCellRef(copyStyle);
	Action result;
	if (Call_Finish(result)==SP_ERROR_NONE) {
		if (result == Plugin_Stop) {
			char buffer[32];
			if (name[0]!=0) strcopy(buffer, sizeof(buffer), name);
			else buffer = STR_NO_PROFILE;
			PrintToChat(client, "[ChatTag] Could not activate profile \"%s\", change was blocked", buffer);
			return;
		} else if (result == Plugin_Handled) return;
		else if (result == Plugin_Changed) style = copyStyle;
	}
	
	char tagcopy[MCP_MAXLENGTH_COLORTAG];
	strcopy(tagcopy, sizeof(tagcopy), prefix);
	ProcessTagStyle(tagcopy, sizeof(tagcopy), style);
	
	MCP_SetClientDefaultNamePrefix(client, tagcopy);
	if ((style&CS_CHATCOLOR)!=CS_NONE) MCP_SetClientDefaultChatColor(client, color);
	else MCP_SetClientDefaultChatColor(client, "");
}

ArrayList FindApplicableProfiles(int client) {
	ArrayList applicable = new ArrayList(ByteCountToCells(32));
	if (IsFakeClient(client)||IsClientSourceTV(client)||IsClientReplay(client)) {
		return applicable;
	}
	ChatStyle prof;
	int max = profiles.Length;
	for (int i; i<max; i++) {
		profiles.GetArray(i,prof);
		
		// can we use this group?
		if (HasPermission(client, prof.filter))
			applicable.PushString(prof.name);
	}
	return applicable;
}

/** 
 * Check if a client has a permission described by thingString.
 * This is compatible to CCC keys.
 * emtpy: pass
 * strlen 1: single permission flag
 * startswith /: command override permission
 * startswith STEAM_: check steamid2
 * startswith [: check steamid3
 * otherwise: require all flag bit from flag string
 * @return true if permitted
 */
bool HasPermission(int client, const char[] thingString) {
	if (thingString[0]==0) return true;
	else if (thingString[1]==0) {
		AdminFlag flag;
		return FindFlagByChar(thingString[0], flag) && GetAdminFlag(GetUserAdmin(client), flag);
	} else if (thingString[1]=='[') {
		char buffer[32];
		return (GetClientAuthId(client, AuthId_Steam3, buffer, sizeof(buffer)) && StrEqual(thingString, buffer));
	} else if (thingString[1]=='/') {
		return CheckCommandAccess(client, thingString[1], ADMFLAG_ROOT);
	} else if (strncmp(thingString, "STEAM_", 6) == 0) {
		char buffer[32];
		return (GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer)) && StrEqual(thingString, buffer));
	} else {
		int read;
		int flags = ReadFlagString(thingString, read);
		return read == strlen(thingString) && (GetAdminFlags(GetUserAdmin(client), Access_Effective) & flags) == flags;
	}
}

void TranslateColor(char[] buffer, int len) {
	if (buffer[0]=='\0') return;
	if (buffer[1]=='\0') {
		if ((buffer[0]|' ')=='t') {
			strcopy(buffer, len, "\x03\0");
			return;
		} else if ((buffer[0]|' ')=='o') {
			strcopy(buffer, len, "\x05\0");
			return;
		} else if ((buffer[0]|' ')=='g') {
			strcopy(buffer, len, "\x04\0");
			return;
		}
	}
	if (buffer[0]=='#') {
		if (strlen(buffer)==7) buffer[0] = '\x07';
		else if (strlen(buffer)==9) buffer[0] = '\x08';
	}
	if (!MCP_ParseChatColor(buffer, buffer, len, 0)) {
		buffer[0] = '\0'; //nuke invalid stuff
	}
}

void ShowChatTagMenu(int client) {
	char buffer[64];
	cvar_settingsMenuEnabled.GetString(buffer, sizeof(buffer));
	int itemdraw = StringToInt(buffer) != 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Menu menu = new Menu(ChatTagMenuHandler);
	menu.SetTitle("Chat Tag Settings");
	mcpct_profile.Get(client, buffer, sizeof(buffer));
	if (buffer[0]==0) buffer = STR_NO_PROFILE;
	Format(buffer, sizeof(buffer), "Profile: %s", buffer);
	menu.AddItem("profile", buffer, itemdraw);
	ChatStyleOptions style = Util_StyleFromCookie(client);
	FormatEx(buffer, sizeof(buffer), "Name Tag: %s", (style&(CS_TAGTEXT|CS_TAGCOLOR)) ? "Shown" : "Hidden");
	menu.AddItem("tag", buffer, itemdraw);
	FormatEx(buffer, sizeof(buffer), "Name Color: %s", (style&CS_NAMECOLOR) ? "Shown" : "Hidden");
	menu.AddItem("name", buffer, itemdraw);
	FormatEx(buffer, sizeof(buffer), "Chat Color: %s", (style&CS_CHATCOLOR) ? "Shown" : "Hidden");
	menu.AddItem("chat", buffer, itemdraw);
	menu.AddItem("all", "Hide all", (style&(CS_PREFIX|CS_CHATCOLOR)) ? itemdraw : ITEMDRAW_DISABLED);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ChatTagMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack) {
			ShowCookieMenu(param1);
		}
	} else if (action == MenuAction_Select) {
		char info[16];
		menu.GetItem(param2, info, sizeof(info));
		int value;
		if (StrEqual(info, "profile")) {
			ShowChatTagProfileMenu(param1);
			return 0;
		} else if (StrEqual(info, "tag")) {
			value = view_as<int>((CS_TAGTEXT|CS_TAGCOLOR));
		} else if (StrEqual(info, "name")) {
			value = view_as<int>(CS_NAMECOLOR);
		} else if (StrEqual(info, "chat")) {
			value = view_as<int>(CS_CHATCOLOR);
		} else if (StrEqual(info, "all")) {
			value = 0;
		}
		int style = view_as<int>(Util_StyleFromCookie(param1));
		if (value) style ^= value;
		else style = 0;
		FormatEx(info, sizeof(info), "%d", style);
		mcpct_style.Set(param1, info);
		UpdateProfile(param1);
		ShowChatTagMenu(param1);
	}
	return 0;
}

void ShowChatTagProfileMenu(int client, int page=1) {
	char buffer[128], name[32], active[32];
	mcpct_profile.Get(client, active, sizeof(active));
	if (active[0]==0) active = STR_NO_PROFILE;
	FormatEx(buffer, sizeof(buffer), "Pick the ChatTag Profile\nActive: %s", active);
	Menu menu = new Menu(ChatTagProfileMenuHandler);
	menu.SetTitle(buffer);
	if (StrEqual(STR_NO_PROFILE, active)) {
		FormatEx(buffer, sizeof(buffer), "[%s]", STR_NO_PROFILE);
		menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	} else {
		menu.AddItem("", STR_NO_PROFILE);
	}
	
	ArrayList choices = FindApplicableProfiles(client);
	
	int at = choices.FindString(STR_PERSONAL);
	if (at >= 0) {
		choices.Erase(at);
		if (StrEqual(STR_PERSONAL, active)) {
			FormatEx(buffer, sizeof(buffer), "[%s]", STR_PERSONAL);
			menu.AddItem(STR_PERSONAL, buffer, ITEMDRAW_DISABLED);
		} else {
			menu.AddItem(STR_PERSONAL, STR_PERSONAL);
		}
	}
	
	int max=choices.Length;
	for (int i=0; i<max; i+=1) {
		choices.GetString(i, name, sizeof(name));
		if (StrEqual(name, active)) {
			FormatEx(buffer, sizeof(buffer), "[%s]", name);
			menu.AddItem(name, buffer, ITEMDRAW_DISABLED);
		} else {
			menu.AddItem(name, name);
		}
	}
	
	delete choices;
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	
	if (menu.ItemCount > 7) 
		menu.DisplayAt(client, (page-1)*7, MENU_TIME_FOREVER);
	else
		menu.Display(client, MENU_TIME_FOREVER);
}

public int ChatTagProfileMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack) {
			ShowChatTagMenu(param1);
		}
	} else if (action == MenuAction_Select) {
		char buffer[32], name[32];
		menu.GetItem(param2, buffer, 0, _, name, sizeof(name)); //info buffer is too small
		if (!StrEqual(name, STR_NO_PROFILE)) buffer = name;
		mcpct_profile.Set(param1, buffer);
		if (UpdateProfile(param1)) {
			PrintToChat(param1, "[ChatTag] You activate profile \"%s\"", name);
		} else {
			PrintToChat(param1, "[ChatTag] Could not activate profile \"%s\", you probably no longer have access", name);
		}
		ShowChatTagProfileMenu(param1, param2/7);
	}
	return 0;
}

public any Native_GetProfiles(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!(1<=client<=MaxClients) || !IsClientInGame(client)) 
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index");
	ArrayList list = FindApplicableProfiles(client);
	Handle retValue = CloneHandle(list, plugin);
	delete list;
	return retValue;
}

public any Native_SetProfile(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (!(1<=client<=MaxClients) || !IsClientInGame(client)) 
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index");
	char name[32];
	ChatStyle profile;
	GetNativeString(2, name, sizeof(name));
	ChatStyleOptions style = GetNativeCell(3);
	
	if (StrEqual(name, STR_PERSONAL)) {
		for (int i=profiles.Length-1; i>=0; i++) {
			profiles.GetArray(i, profile);
			if (StrEqual(profile.name, name) && !HasPermission(client, profile.filter)) {
				profile.apply(client, style);
				return 0;
			}
		}
	} else if (name[0]==0 || StrEqual(name, STR_NO_PROFILE)) {
		ApplyProfileValues(client, "", "", "", CS_NONE);
		return 0;
	} else {
		for (int i=profiles.Length-1; i>=0; i++) {
			profiles.GetArray(i, profile);
			if (StrEqual(profile.name, name)) {
				profile.apply(client, style);
				return 0;
			}
		}
	}
	ThrowNativeError(SP_ERROR_PARAM, "Unknown profile name \"%s\"", name);
	return 0;
}

