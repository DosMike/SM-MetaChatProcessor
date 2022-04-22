#if defined _mcp_included
#endinput
#endif
#define _mcp_included

//yywwrr: y year, w week in year, r revision in week
#define MCP_VERSION 221501

#include <metachatprocessor/types>

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
 * If you want to transform messages using color tags you might want to use this,
 * to prevent user input from being converted, before.
 * However, if you can, it is recommended to use native colors, to save on processing
 * time on color tags (if the message flag mcpMsgProcessColors is set).
 * After adding your color tags, call MCP_UnescapeCurlies().
 *
 * MCP_EscapeCurlies(message, sizeof(message));
 * Format(message, sizeof(message), "{gold}%s", message);
 * CFormatColor(message, sizeof(message), author);
 * MCP_UnescapeCurlies(message, sizeof(message));
 *
 * @param message - the message buffer to process
 * @param maxlength - the buffer size
 */
stock void MCP_EscapeCurlies(char[] message, int maxlength) {
	ReplaceString(message, maxlength, "{", MCP_PUA_ESCAPED_LCURLY);
}

/**
 * Call this function after color tags have been processed.
 *
 * MCP_EscapeCurlies(message, sizeof(message));
 * Format(message, sizeof(message), "{gold}%s", message);
 * CFormatColor(message, sizeof(message), author);
 * MCP_UnescapeCurlies(message, sizeof(message));
 *
 * @param message - the message buffer to process
 * @param maxlength - the buffer size
 */
stock void MCP_UnecapeCurlies(char[] message, int maxlength) {
	ReplaceString(message, maxlength, MCP_PUA_ESCAPED_LCURLY, "{");
}

/**
 * Collect all clients with the specified team into the arraylist
 * 
 * @param team - if 0, all clients are collected
 * @param clients - accumulator for clients
 * @param subtract - remove the clients from the accumulator, instead of adding one
 * @param bots - set true to allow bots in the results
 */
stock void MCP_FindClientsByTeam(int team, ArrayList clients, bool subtract=false, bool bots=false) {
	for (int client=1; client<=MaxClients; client++) {
		if (IsClientInGame(client) && (bots||!IsFakeClient(client)) && (team==0 || GetClientTeam(client)==team)) {
			if (subtract) {
				int at;
				while ((at=clients.FindValue(client)) != -1) clients.Erase(at);
			} else {
				clients.Push(client);
			}
		}
	}
}
/**
 * Collect all clients with the specified team into the arraylist
 * 
 * @param clients - accumulator for clients
 * @param subtract - remove the clients from the accumulator, instead of adding one
 * @param alive - set false to get dead players instead
 * @param bots - set true to allow bots in the results
 */
stock void MCP_FindClientsAlive(ArrayList clients, bool subtract=false, bool alive=true, bool bots=false) {
	for (int client=1; client<=MaxClients; client++) {
		if (IsClientInGame(client) && (bots||!IsFakeClient(client)) && (GetClientHealth(client)>0) == alive) {
			if (subtract) {
				int at;
				while ((at=clients.FindValue(client)) != -1) clients.Erase(at);
			} else {
				clients.Push(client);
			}
		}
	}
}
/**
 * Collect all clients with the specified admin flag into the arraylist. Skips bots.
 * 
 * @param flag - the admin flag to check
 * @param clients - accumulator for clients
 * @param subtract - remove the clients from the accumulator, instead of adding one
 */
stock void MCP_FindClientsByFlag(AdminFlag flag, ArrayList clients, bool subtract=false) {
	for (int client=1; client<=MaxClients; client++) {
		AdminId admin;
		if (IsClientInGame(client) && !IsFakeClient(client) && (admin=GetUserAdmin(client))!=INVALID_ADMIN_ID && admin.HasFlag(flag)) {
			if (subtract) {
				int at;
				while ((at=clients.FindValue(client)) != -1) clients.Erase(at);
			} else {
				clients.Push(client);
			}
		}
	}
}
/**
 * Collect all clients with the specified access into the arraylist. as this is using
 * CheckCommandAccess, command can be an override. Skips bots.
 * 
 * @param command - the command or override to check
 * @param clients - accumulator for clients
 * @param subtract - remove the clients from the accumulator, instead of adding one
 * @param override_only - passed to CheckCommandAccess; don't check commands
 */
stock void MCP_FindClientsByAccess(const char[] command, ArrayList clients, bool subtract=false, bool override_only=false) {
	for (int client=1; client<=MaxClients; client++) {
		if (IsClientInGame(client) && !IsFakeClient(client) && CheckCommandAccess(client, command, 0, override_only)) {
			if (subtract) {
				int at;
				while ((at=clients.FindValue(client)) != -1) clients.Erase(at);
			} else {
				clients.Push(client);
			}
		}
	}
}
/**
 * Adds all clients matching the target selector to the arraylist.
 * You can specify the admin and filterflags parameters to be passed to ProcessTargetString
 * 
 * @param pattern - the target selector pattern
 * @param clients - the accumulator for clients
 * @param subtract - remove the clients from the accumulator, instead of adding one
 * @param admin - the client to assume @me
 * @param filterflags - the filter flags for processing
 * @return the result from ProcessTargetString. You can ReplyToTargetError or not idc.
 */
stock int MCP_FindClientsBySelector(const char[] pattern, ArrayList clients, bool subtract=false, int admin=0, int filterFlags=0) {
	int targets[MAXPLAYERS];
	char targetName[0]; //dummy
	bool tn_is_ml;
	int result = ProcessTargetString(pattern, admin, targets, sizeof(targets), filterFlags, targetName, sizeof(targetName), tn_is_ml);
	if (result <= 0) {
		return result;
	}
	for (int i; i<result; i++) {
		if (IsClientInGame(targets[i])) {
			if (subtract) {
				int at;
				while ((at=clients.FindValue(targets[i])) != -1) clients.Erase(at);
			} else {
				clients.Push(targets[i]);
			}
		}
	}
	return result;
}
/**
 * Remove all elements of a subset from a different collection of elements.
 * Operates on block 0!
 * 
 * @param subset - the elements to remove
 * @param collection - the collection to remove from
 */
stock void MCP_RemoveListElements(ArrayList subset, ArrayList collection) {
	for (int i=0; i < subset.Length; i++) {
		any value=subset.Get(i);
		int at;
		while ((at = collection.FindValue(value)) != -1) {
			collection.Erase(at);
		}
	}
}

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