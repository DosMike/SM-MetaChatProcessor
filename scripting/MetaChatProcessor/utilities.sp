#if defined _mcp_utilitites
#endinput
#endif
#define _mcp_utilitites
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif


void ParseConfigs() {
	GameData gameData = new GameData("metachatprocessor.games");
	if (gameData == INVALID_HANDLE) SetFailState("Could not load gamedata file");
	char buffer[64];
	
	//these colors are used if \x03 is broken, indicated by teamcolor_mode
	gameData.GetKeyValue("teamcolor_mode", buffer, sizeof(buffer));
	g_teamColorMode = StringToInt(buffer);
	if (g_teamColorMode<0) g_teamColorMode=0;
	else if (g_teamColorMode>1) g_teamColorMode=1;
	//actual colors, spec == unansigned
	gameData.GetKeyValue("teamcolor_spec", g_teamColors[0], sizeof(g_teamColors[]));
	g_teamColors[1] = g_teamColors[0];
	gameData.GetKeyValue("teamcolor_team1", g_teamColors[2], sizeof(g_teamColors[]));
	gameData.GetKeyValue("teamcolor_team2", g_teamColors[3], sizeof(g_teamColors[]));
	gameData.GetKeyValue("teamcolor_team3", g_teamColors[4], sizeof(g_teamColors[]));
	gameData.GetKeyValue("teamcolor_team4", g_teamColors[5], sizeof(g_teamColors[]));
	
	//how many team are in _Chat_ translation format string
	gameData.GetKeyValue("msgname_teams", buffer, sizeof(buffer));
	g_msgNameTagCount = StringToInt(buffer);
	if (g_msgNameTagCount<0) g_msgNameTagCount=0;
	else if (g_msgNameTagCount>4) g_msgNameTagCount=4;
	//read the team msgname tags
	for (int i=0; i<g_msgNameTagCount && i<4; i++) {
		Format(buffer, sizeof(buffer), "msgname_tag%i", i+1);
		if (!gameData.GetKeyValue(buffer, g_msgNameTags[i], sizeof(g_msgNameTags[]))) {
			SetFailState("Game was set to have %i name identifiers, but no %i was missing (msgname_tag%i)", g_msgNameTagCount, i+1, i+1);
		}
	}
	//get game specific translations
	gameData.GetKeyValue("translation_file", buffer, sizeof(buffer));
	TrimString(buffer);
	if (!AutoLoadTranslations(buffer)) {
		LogError("[MCP] Warning: No explicit translation found for this game, using default");
	}
	
	delete gameData;
}

void LoadCompatConfig() {
	//load compat layer configuration
	KeyValues kv = new KeyValues("config");
	char buffer[256];
	char part[64];
	BuildPath(Path_SM, buffer, sizeof(buffer), "configs/metachatprocessor.cfg");
	if (!FileExists(buffer)) GenerateDefaultConfig(kv, buffer);
	else if (!(kv.ImportFromFile(buffer))) { //goes into the root section, skipping the name
		LogError("[MCP] Configuration is broken, please regenerate it!");
		return;
	}
	
	if (kv.JumpToKey("Compatibility")) { //jump to key goes into the section
		if (kv.GetNum("SCP Redux")>0) g_compatLevel |= mcpCompatSCPRedux;
		if (kv.GetNum("Drixevel")>0) g_compatLevel |= mcpCompatSCPRedux;
		if (kv.GetNum("Cider")>0) g_compatLevel |= mcpCompatSCPRedux;
		g_fixCompatPostCalls = (kv.GetNum("Fix Post Calls")>0);
		kv.GoBack();
	} else LogError("[MCP] 'Compatibility' section missing from config");
	if (kv.GetDataType("Transport")==KvData_String) {
		kv.GetString("Transport", part, sizeof(part), "SayText");
		if (StrEqual(part, "PrintToChat", false)) {
			g_messageTransport = mcpTransport_PrintToChat;
		} else if (StrEqual(part, "SayText", false)) {
			g_messageTransport = mcpTransport_SayText;
		} else {
			LogError("[MCP] WARNING: Transport method '%s' not supported, using SayText instead", part);
		}
	} else LogError("[MCP] WARNING: Transport method not set, using SayText instead", part);
	delete kv;
}

static void GenerateDefaultConfig(KeyValues kv, const char[] path) {
	kv.ImportFromString("config { Compatibility { \"SCP Redux\" 1 Drixevel 1 Cider 1 \"Fix Post Calls\" 0 } Transport SayText }");
	kv.ExportToFile(path);
}

/** this file is for all functions that are not directly related to the SayText
 * hook/processing in order to keep the main file clean and hopefully more
 * maintainable */

/** return true if a game specific translation was loaded */
static bool AutoLoadTranslations(const char[] translation) {
	bool specific;
	if (translation[0]) {
		char transFile[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, transFile, sizeof(transFile), "translations/metachatprocessor.%s.phrases.txt", translation);
		
		if (( specific = FileExists(transFile) )) {
			Format(transFile, sizeof(transFile), "metachatprocessor.%s.phrases", translation);
			LoadTranslations(transFile);
		}
	}
	if (!specific) LoadTranslations("metachatprocessor.phrases");
	
	g_groupTranslations = new ArrayList(sizeof(ExternalPhrase));
	PushPhraseToList(g_groupTranslations, ""); //mcpTargetNone (dummy)
	PushPhraseToList(g_groupTranslations, "Group_Spectator"); //mcpTargetSpecator
	//not all games have four teams, to we put the generic team as fallback/placeholder to prevent errors
	PushPhraseToList(g_groupTranslations, TranslationPhraseExists("Group_Team1") ? "Group_Team1" : "Group_Team"); //mcpTargetTeam1
	PushPhraseToList(g_groupTranslations, TranslationPhraseExists("Group_Team2") ? "Group_Team2" : "Group_Team"); //mcpTargetTeam2
	PushPhraseToList(g_groupTranslations, TranslationPhraseExists("Group_Team3") ? "Group_Team3" : "Group_Team"); //mcpTargetTeam3
	PushPhraseToList(g_groupTranslations, TranslationPhraseExists("Group_Team4") ? "Group_Team4" : "Group_Team"); //mcpTargetTeam4
	PushPhraseToList(g_groupTranslations, "Group_Team"); //mcpTargetTeamSender
	PushPhraseToList(g_groupTranslations, "Group_All"); //mcpTargetAll
	PushPhraseToList(g_groupTranslations, "Group_Admin"); //mcpTargetAdmin
	PushPhraseToList(g_groupTranslations, "Group_Direct"); //mcpTargetDirect
	
	g_senderflagTranslations = new ArrayList(sizeof(ExternalPhrase));
	PushPhraseToList(g_senderflagTranslations, "Senderflag_Dead"); //mcpSenderDead
	PushPhraseToList(g_senderflagTranslations, "Senderflag_Spectator"); //mcpSenderSpectator
	
	return specific;
}

int PushPhraseToList(ArrayList list, const char[] phrase, Handle plugin=INVALID_HANDLE, const char[] fromFile=NULL_STRING) {
	bool lenient = plugin == INVALID_HANDLE;
	if (plugin == INVALID_HANDLE) plugin = GetMyHandle();
	if (!TranslationPhraseExists(phrase) && !lenient) {
		//probably called from native
		if (IsNullString(fromFile)) ThrowError("MCP Translation file seems to be broken, could not find '%s'", phrase);
		LoadTranslations(fromFile);
		if (!TranslationPhraseExists(phrase)) {
			char pluginName[64];
			GetPluginInfo(plugin, PlInfo_Name, pluginName, sizeof(pluginName));
			ThrowNativeError(SP_ERROR_PARAM, "MCP could not load translation '%s' from '%s' on behalf of %s", phrase, fromFile, pluginName);
		}
	}
	ExternalPhrase ephrase;
	int at = list.FindValue(INVALID_HANDLE, ExternalPhrase::plugin);
	if (at >= 0) {
		list.GetArray(at, ephrase);
		ephrase.plugin = plugin;
		strcopy(ephrase.string, sizeof(ExternalPhrase::string), phrase);
		list.SetArray(at, ephrase);
		return at;
	} else {
		ephrase.plugin = plugin;
		strcopy(ephrase.string, sizeof(ExternalPhrase::string), phrase);
		return list.PushArray(ephrase);
	}
}
void DropPhrasesFromList(ArrayList list, Handle plugin) {
	for (int i=0;i<list.Length;i++) {
		if (list.Get(i,ExternalPhrase::plugin)==plugin) {
			list.Set(i, INVALID_HANDLE, ExternalPhrase::plugin);
		}
	}
}
bool GetNthPhrase(ArrayList list, int index, char[] buffer, int buffersize) {
	ExternalPhrase p;
	if (index < 0 || index >= list.Length) return false;
	list.GetArray(index, p);
	if (p.plugin == INVALID_HANDLE) return false;
	strcopy(buffer, buffersize, p.string);
	return true;
}

void ParseMessageFormat(const char[] format, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup) {
	//break up the format string to get senderflags, group and options
	bool ffAll = StrContains(format, "all", false)>0;
	bool ffTeam = StrContains(format, "team", false)>0;
	bool ffSpec = StrContains(format, "spec", false)>0;
	bool ffDead = StrContains(format, "dead", false)>0;
	int iTeam;
	for (int tag;tag<g_msgNameTagCount;tag++) {
		if (StrContains(format, g_msgNameTags[tag], false)>0) {
			iTeam=tag+2; //unassigned and spectator are always skipped, spec has its own format
			break;
		}
	}
	senderflags = mcpSenderNone;
	if (ffSpec) senderflags |= mcpSenderSpectator;
	if (ffDead) senderflags |= mcpSenderDead;
	targetgroup = mcpTargetNone;
	if (iTeam) targetgroup = view_as<mcpTargetGroup>(iTeam);
	else if (ffTeam) targetgroup = mcpTargetTeamSender;
	else if (!ffAll && ffSpec) targetgroup = mcpTargetSpecator;
}
/**
 * Tries to rebuild a message format string that resembles the original enough
 * to allow other plugins to parse it again. only the game name will be off.
 * Unusual combination of senderflags and targetgroup may result in a broken/incomplete format.
 */
void BuildMessageFormat(mcpSenderFlag senderflags, mcpTargetGroup targetgroup, char[] buffer, int bufferlen) {
	bool ffSpec = (senderflags & mcpSenderSpectator) || (targetgroup & mcpTargetSpecator);
	bool ffAll = targetgroup == mcpTargetAll || targetgroup == mcpTargetNone;
	bool ffDead = (senderflags & mcpSenderDead) && !ffSpec;
	bool ffTeam = targetgroup == mcpTargetTeamSender;
	int iTeam;
	if (targetgroup >= mcpTargetTeam1 && targetgroup <= mcpTargetTeam4) iTeam = view_as<int>(targetgroup)-2;
	
	int pos=10;
	strcopy(buffer, bufferlen, "game_Chat_");
	if (pos < bufferlen) {
		if (iTeam && iTeam < g_msgNameTagCount) {
			strcopy(buffer[pos], bufferlen-pos, g_msgNameTags[iTeam]);
			pos += strlen(g_msgNameTags[iTeam]);
		} else if (ffTeam || iTeam) {
			strcopy(buffer[pos], bufferlen-pos, "Team");
			pos += 4;
		} else if (ffAll) {
			strcopy(buffer[pos], bufferlen-pos, "All");
			pos += 3;
		}
	}
	if (pos < bufferlen) {
		if (ffAll && ffDead) {
			strcopy(buffer[pos], bufferlen-pos, "Dead");
		} else if ((ffTeam || iTeam) && ffDead) {
			strcopy(buffer[pos], bufferlen-pos, "_Dead");
		} else if (ffSpec) {
			strcopy(buffer[pos], bufferlen-pos, "Spec");
		}
	}
}

/**
 * roughly check if the color is a valid color code, or a rgb/rgba color specifier, or and existing color name
 * and return the native color string for that color.
 * for CSGO: check if strlen==1 && 0<char[0]<32
 * for old source: check if 0<char[0]<=6 && strlen == 1 || char[0]==7/'#' && strlen == 7 || char[0]==9/'#' && strlen==9
 * for all: check if string is valid color name
 * note: output size should be at least 2
 * @param color - the color specifier, 
 * @param output - the native color \x01..\x10 i think for csgo, \x01..\x08 for others
 * @param maxsize - size of output buffer
 * @return true if the color seemd valid and output was set.
 */
bool ParseChatColor(const char[] color, char[] output, int maxsize, int author) {
	if (!color[0]) return false;
	//control character == native color
	if( (GetEngineVersion() == Engine_CSGO && 0 < color[0] <= 0x10) || 
		(color[0] <= 0x06) ){ //all default colors supported by non csgo
		output[0] = color[0];
		output[1] = 0;
		return true;
	} else if (color[0] == 7 || color[0] == 8 || color[0] == '#' ) {
		//color buffer is \x07rrggbb\x00 OR \x08rrggbbaa\x00
		int bytes = 8;
		int inlen = strlen(color);
		if (color[0]=='#') {
			if (inlen == 9) bytes = 10;
			else if (inlen != 7) ThrowError("Input has no complete color hex tag!");
		} else if (color[0]==8) {
			if (inlen != 9) ThrowError("Input has no complete x8 color tag!");
			bytes = 10;
		} else if (inlen != 7) ThrowError("Input has no complete x7 color tag!");
		if (bytes > maxsize) ThrowError("Output can't hold color format");
		strcopy(output, bytes, color);
		output[0] = (bytes==10)?8:7;
		return true;
	} else if( CColorExists(color) ){
		char tmp[32];
		FormatEx(tmp, sizeof(tmp), "{%s}", color);
		CFormatColor(tmp, sizeof(tmp), author);
		strcopy(output, maxsize, tmp);
		return true;
	}
	output[0] = 0;
	return false;
}

void RemoveTextColors(char[] message, int maxsize, bool removeTags) {
	if (removeTags) CRemoveTags(message, maxsize);
	int read,write;
	if (GetEngineVersion()==Engine_CSGO) {
		for (;message[read] && read < maxsize;read+=1) {
			if (0 < message[read] <= 0x32) continue; //just skip all control chars, they have no business here
			if (read!=write)
				message[write] = message[read];
			write+=1;
		}
	} else {
		for (;message[read] && read < maxsize;read+=1) {
			if (message[read]==7) { read+=6; continue; } //skip following RRGGBB as well
			else if (message[read]==8) { read+=8; continue; } //skip following RRGGBBAA as well
			else if (0 < message[read] <= 0x32) continue; //just skip all control chars, they have no business here
			if (read!=write)
				message[write] = message[read];
			write+=1;
		}
	}
	if (read!=write) {//changed
		//move 0 terminator as well; max index is at size-1
		if (write < maxsize-1) message[write]=0;
		else message[maxsize-1] = 0; //safety
	}
}
