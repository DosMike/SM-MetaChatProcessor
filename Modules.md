# BaseChat

This variation of the AM plugin uses MCP to proxy it's various chat commands.
This allows admin snooping, as well as player the player prefix to be applied to /say /psay and /chat.

#mcp-sayredirects

Replacement for Cider ChatProcessors AllChat and DeadChat with some bonus features.

`sm_sayredirect_allchat` - Redirect team chat as follows:   
  0 - Disables this option
  1 - All team chat is converted to global chat
  2 - Team messages from team 2 are converted to global chat
  3 - Team messages from team 3 are converted to global chat

`sm_sayredirect_deadchat` - Allows alive and dead players to chat (1/0)

`sm_sayredirect_snoopflag` - Add staff members with the specified admin bit as recipients to MCP chat messages (Default z, empty to disable)

`sm_sayredirect_colorteamtag` - Set the (TEAM)-say prefix to use team color (1/0)