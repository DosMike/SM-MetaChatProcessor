# Meta Chat Processor

This plugin is intended to merge, replace and extend some previous chat processors.
With the difference to other chat processors, that I want to keep compatibility for plugins that depend on these chat processors to some degree.

Differences: Instead of a simple forward, there's 3.5 stacked forwards for pre, early, normal and late manipulation, followed by a 'color', and 'formatted' forward if the message was changed before the post forward.
This should offer enough flexibility to implement compatibility for other chat processors and then some.
Supporting certain chat processors requires basic name tagging capabilities. In MCP this is done through name prefixes, instead of tags. The prefix merges tag color, tag and name color.
The message format in MCP is broken down more than usual, allowing for a more refined manipulation, and registration of custom prefixes, e.g. (Region)name : message.
Lastly the message is post processed to remove redundant colors and subsequently save bytes in case two plugins can't agree on where to put colors.
The last difference is probably that MCP uses private forwards instead of global forwards, meaning you have to register your functions like e.g. Events or SDKHooks.

In order to implement some of these features, the available data has to be expanded. This is done with a gamedata file on one side, and translation files on the other.
The gamedata file can handle team colors, while the translation file handles things like default colors, team names, ect. Note that games that use (TEAM) as prefix can
be forced to use the actual team name and vice versa, thus a translation file per game is required. To keep the localized nature, custom senderflag and group names have
to be registered with translation phrases, that can then be manipulated numerically.

On PrintToChat support
While CPrintToChat from the color includes uses SayText2 to send messages, they are marked as non-hookable so only regular PrintToChat messages could be hooked.
In addition to that, these messages might already be sent on a per-client basis for translation or otherwise, making parsing very hard!
Instead of doing the impossible, MCP instead has a native to send SayText2 messages, to basically fake say messages.

Time estimation:
The profiler timed about .035 ms for pre and about .06 ms post processing with one player on the server (that is with SCP compat and CCC formatting the name).
With a 32 slot TF2 server at 15 mspt my wort case estimation is roughly 13% of a game tick.
Without baseline and chat messages not happening every game tick I'd say this is not hyper speed, but acceptable.
