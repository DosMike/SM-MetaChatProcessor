# BaseChat

This variation of the AM plugin uses MCP to proxy it's various chat commands.
This allows admin snooping, as well as player the player prefix to be applied to /say /psay and /chat.

# mcp-chattags

Replacement for Custom Chat-Colors and Custom Chat-Colors Toggle.

Config is compatible, but you should also be able to key on flag groups and overrides.

A difference to CCC Toggle is, that players can select which of the profiles they 
want active. If you want it to behave like CCC without CCC Toggle, you can set the 
convar `chattag_menu_enabled` to 0.

Setting the convar `chattag_load_behaviour` to 1, as well will also reload the
first matching profile every time a player connects, while zero will not change 
the profile on connect.

If you set `chattag_load_behaviour` to 2, it will try to detect changes in access to 
profiles, and switch profile, if the list of accessible profiles changes for a user. 
This is intended to help with ranks that get unlocked externally, so users don't have 
to know /settings is a thing. It is not possible to detect what profile excatly was 
granted or revoked permission to, so it will always pick first in the config.

Reloading the config can be done with the ADMFLAG_CONFIG command `sm_reloadchattags`.

The config will be loaded from sourcemod/configs/mcp-chattags.cfg. If that file is not found,
it will try the legacy [sourcemod/configs/custom-chatcolors.cfg](https://github.com/DoctorMcKay/sourcemod-plugins/blob/master/configs/custom-chatcolors.cfg) instead.

```
admin_colors 
{
	// if you disable the menus, these entries become "first match = active profile".
	// you can specify gobal defaults by a match all profile with an empty "flag" option.
	// if menus are enabled such a profile can still be disabled.

	// SteamID2 and SteamID3 are supported
	// These profiles will show up as "Personal" in the menu
	"SteamID"
	{
		//the "flag" option is ignored in this case
		...
	}
	"ProfileName"
	{
		// flag can be
		// - one or more admin flags, the player all needs to have have (e.g. "a", "z", "bo")
		// - a steamId 2 or steamId 3 (STEAM_0:0:123 or [U:1:123])
		// - a admin command override, prefix with / (for "myCustomOverride" use "/myCustomOverride")
		"flag" "filter"
		
		// tag color, tag and name color will be prefixed in front of a clients name.
		// the text color is for the message itself, after the name.
		// parts of it can be disabled by the player, if menus are enabled.
		"tagcolor" "color"
		"tag" "text"
		"namecolor" "color"
		"textcolor" "color"
		// color values can be
		// - t/o/g as with CCC for Team color / Olive / Green
		// - #rrggbb for a rgb color
		// - #rrggbbaa for a color with transparency
		// - one of the color names in [this list](https://github.com/DoctorMcKay/sourcemod-plugins/blob/6c7ffca2b580b3b313ee2027ac4dd12b7fad226a/scripting/include/morecolors.inc#L500)
	}
}
```

# mcp-sayredirects

Replacement for Cider ChatProcessors AllChat and DeadChat with some bonus features.

`sm_sayredirect_allchat` - Redirect team chat as follows:   
  0 - Disables this option
  1 - All team chat is converted to global chat
  2 - Team messages from team 2 are converted to global chat
  3 - Team messages from team 3 are converted to global chat

`sm_sayredirect_deadchat` - Allows alive and dead players to chat (1/0)

`sm_sayredirect_snoopflag` - Add staff members with the specified admin bit as recipients to MCP chat messages (Default z, empty to disable)

`sm_sayredirect_colorteamtag` - Set the (TEAM)-say prefix to use team color (1/0)

`sm_sayredirect_forceteamname` - Force say_team messages to use the team name instead of the generic (TEAM) prefix (1/0)