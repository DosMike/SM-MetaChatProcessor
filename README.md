# Meta Chat Processor

**Motivation:** The usual, existing chat-processors did not offer the feature set I required. At the same time I didn't want to drop existing plugins / configs that used previous chat-processors, so I naturally went for the most complex thing I could have done:
Switch to private forwards and implement compatibility layers. Until now my other plugin implements a pretty rudimentary implementation of SCP forwards to allow CCC to work, while I change the chat format from AllChat/TeamChat to WorldChat/RegionChat (message 'target group' changes), but I can hopefully do it in a nicer way with MCP soon.
I want to note that I tested MCP with both Custom-ChatColors and HexTags, both seem to work without any issues.

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

## Config & Setup

As mentioned above, MCP implements compatibility layers for Simple Chat-Processor, Drixevel's Chat-Processor and Cider Chat-Processor. As I expect most people to not read the docs or just skim over them, all three compat layers are enabled by default.
I want to emphasise here that I am only implementing API compatibility, not feature pairity! In addition you can switch the transport method from using SayText2 packets to TextMsg packets (system/plugin messages).
Simple Chat-Processor also had the quirk that the Post call was only called if the message was changed. I have an optional fix for that in place, that you can enable in the config as well.
The compatibility options for `Custom-ChatColors` and `HexTags` will try to read the clients chat colors back into MCP for other plugins to access.
In case you still encounter weird issues with external plugins that reliably format chat messages manually or through a compatibility layer, you can turn on the `External Formatting` option and check if things improve.

By Default MCP will also perform input sanitation that brings chat messages back in-line with vanilla behaviour. Native colors are not actually allowed by games by default, neither are empty messages.
The `Trim All Whitespaces` option will catch unicode spaces as well, to properly block messages without content.
Lastly there's the option `Ban On NewLine`, this option will automatically perma-ban clients sending new line characters in chat. This should get picked up by SourceBans and other ban management utilities.
There is no way (that I know of) for a player to input new line characters into a chat message, and this seems to be only used by hack clients to disrupt chat flow (With the latest TF2 patch this should not longer be possible in that game anyways).

The config can be found at `addons/sourcemod/config/metachatprocessor.cfg`:
```c
"config"
{
	"Compatibility"
	{
		"SCP Redux"		"1"
		"Drixevel"		"1"
		"Cider"			"1"
		"Custom-ChatColors"	"1"
		"HexTags"		"1"
		"Fix Post Calls"	"0"
		"External Formatting" "0"
	}
	// Transport defines the message channel/type. You should probably keep it at SayText.
	// Possible values: [ PrintToChat , SayText ]
	"Transport"		"SayText"
	// HookMode defines how messages are cought. Command listener is experimental and might not block the original message correctly in all cases.
	// Possible values: [ Command , UserMessage ]
	"HookMode"		"UserMessage"
	"Input Sanitizer"
	{
		// Trim messages of "space" codepoints (utf8 support) ?
		"Trim All Whitespaces"		1
		// get rid of hackers
		"Ban On NewLine"			1
		// clients are not allowed to use \x01..\x08 colors
		"Strip Native Colorcodes"	1
	} 
}
```

## [Modules](Modules.md)

## Forwards & Call order

#### mcpHookPre:
`Action (int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor)`

Called before the usual processing for early blocking/management.

#### mcpHookEarly, mcpHookDefault:
`Action (int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor, char[] name, char[] message)`

These are the main forwards, please use mcpHookDefault unless there's a conflict and it would break.

#### mcpHookColors:
`Action (int sender, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, char[] nameTag, char[] displayName, char[] chatColor)`

The dedicated forward for when mcp prefix and colors are applied. the display name might have formats from earlier forwards, nameTag has the tag&color from mcp.

#### mcpHookLate:
`Action (int& sender, ArrayList recipients, mcpSenderFlag& senderflags, mcpTargetGroup& targetgroup, mcpMessageOption& options, char[] targetgroupColor, char[] name, char[] message)`

Same signature as as mcpHookEarly and mcpHookDefault, but already catches the default coloring applied by MCP or other most other plugins.

#### mcpHookGroupName:
`Action (int sender, int recipient, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, const char[] groupphrase, char[] groupname)`

This is intended for complex target group names that eventually contains placeholders withing their target group.
An example could be SourceMods DM format that would resolve to `(To %N)`, that would require this hook to `Format` that username in.

#### mcpHookFormatted:
`Action (int sender, int recipient, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, char[] formatted)`

Called after the client specific format translations are applied and the message is about to be sent to a client.

#### mcpHookPost:
`void (int sender, ArrayList recipients, mcpSenderFlag senderflags, mcpTargetGroup targetgroup, mcpMessageOption options, const char[] targetgroupColor, const char[] name, const char[] message)`

The message is sent and you may do some post sending cleanup.

## Other natives

#### Manage Senderflags:
With `MCP_RegisterSenderFlag` and `MCP_UnregisterSenderFlags` you can register custom sender flags.
This is done by translation phrase and will return a flag bit. Since theres 32 bits in a cell, there's a global limit of 32 senderflag. These will be concatinated within asterisks in front of a chat message (default flags are `*DEAD*` and `*SPEC*`).

#### Manage Targetgroup:
Using `MCP_RegisterTargetGroup` and `MCP_UnregisterTargetGroups` you can add custom message target group names.
Again, these use translation phrases but as only one target group can be used at a time, there can be almost any amount of target groups. Target groups are formatted between sender flags and username (default groups are `(TEAM)` or `(Spectator)`).
Through the modular translation system you can exchange the `(TEAM)` prefix for named team prefixes like `(Terrorists)` or `(Survivors)` and vice versa.
These groups are put into the enum in sequence, so checking for a team message can be done with this condition: `(mcpTargetTeam1 <= targetgroup <= mcpTargetTeamSender)`.

#### Name Prefixes and Chat Colors
Yes, MetaChatProcessor has natives to set the name prefix and chat color. I added it, as Drixevel's Chat-Processor has a whole tag system and it felt kinda wrong to have that in the compat layer but nothing comparable in Meta Chat-Processor itself.
The name prefix combines tag color, tag string and name color as it's usually really only one value. The chat color is more strongly enforced to be a color instead of a chat prefix. The values are not stored and reset on connect.

#### Manually Sending messages:
You can bypass the SayText2 hook by calling `MCP_SendChat` directly. This allows you to easily create messages outside the normal format specifications.

#### Escaping colors:
If you want to apply colors by color tags, as we are pretty much used to now, you might run into troubles when a client inputs curly braces / color codes in the input.
To prevent those from parsing, you can use `MCP_EscapeCurlies` and `MCP_UnecapeCurlies` which uses `MCP_PUA_ESCAPED_LCURLY` (\uEC01) as temporary replacement.
This character is from the private use block and should neither break anything nor render in the client. Since I can not predict how plugins will use curlies I cannot default replace them, in neither input nor color tags.

#### Manipulating recipients:
In order to help you manage the recipients list, there the `MCP_FindClients*` group of methods as well as `MCP_RemoveListElements`.
You should not worry about duplicate entries in the recipients list, that is already handled by MCP after each forward is called.

## About buffers:
The message buffers in MCP are a bit bigger then previously. This is mostly to give color tags some additional space as they might collapse to no more than 7 bytes when parsed.
Please keep in mind that the maximum length for these network packages is around 256 bytes so you should not exceed `MCP_MAXLENGTH_MESSAGE`.

## Compatibility:
Out of the box MCP should work with Custom-ChatColors and HexTags, replacing SCP Redux, DCP and CCP. Keep in mind that MCP only provides API compatibility. This means features like All-Talk or Dead-Talk are not included in MCP itself.
The Colortags from Custom-ChatColors and HexTags are pulled into MCPs prefix system, so other plugins can read and work with them, but are NOT pushed back into Custom-ChatColors or HexTags if set through MCP.
