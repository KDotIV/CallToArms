FOREVER PVP - FRONTEND ALPHA 0.2.0

Read UX.txt for the current one-action report flow and notification behavior.
The older composer remains internal; the primary action is now /cta report.

Install
Copy the ForeverPVP folder into World of Warcraft/_forever_/Interface/AddOns/.
The resulting path must be AddOns/ForeverPVP/ForeverPVP.toc.
Restart the client after first installation. Use /reload after Lua edits.
Targets interface 16001, based on Forever source version 1.60.1.70790.
Confirm your installed interface with /dump select(4, GetBuildInfo()).
This alpha has not been run or visually verified in the actual WoW client.

Commands
/fwp                    Toggle the draggable activity panel (Escape closes it).
/fwp demo               Add three explicitly labeled local demo reports.
/fwp clear              Clear the current session's reports.
/fwp ruleset pvp        Set audience; also accepts normal, rp, rppvp.
Ruleset defaults to pvp. This is a manual configuration, not automatic detection.
Click an activity row to open details, then Show on map. Pins appear on the exact zone map,
not parent continent/world maps. Hover a row or pin for report details.
Use /cta report or the Report PvP keybinding to report at your current position.
With no adapter, Submit creates only a local preview. Nothing is broadcast.
Alerts on/muted controls toast notifications; the map and list remain available.

Scope
Native Blizzard frames, five reusable list rows, up to 64 reusable map pins.
No bundled libraries, custom textures, animation, OnUpdate loop, combat listener,
network client, Discord credentials, automatic chat parsing, or world scanning.
UI frames are created on first use. A 15-second expiry ticker runs only while
reports exist. Expired reports are filtered immediately on reads and removed on
the next tick. Only settings and the successful-submit cooldown are persisted.
Reports are transient. Activity updates redraw visible UI only.
Map API use is isolated in Map.lua. An unavailable map leaves the list usable.
This alpha uses the native map canvas as a parent and hooks map/size changes;
it does not replace Blizzard methods or alter built-in map data providers.

Responsibility split
Client: render validated alerts, collect an explicit request, audience checks,
bounded storage, local notification throttling, local submit cooldown.
Backend/adapter: authenticated origin, organizer permissions, ruleset/region
and faction routing, participant deduplication, encounter clustering, city
classification and active-raid exception, distributed spam protection, revisions,
and delivery acknowledgements. Client filters are not a security boundary.
The chosen city rule allows both factions to learn minimal active city-raid
status, but heat still requires fresh reports from the receiving faction.
Any addon user may request defense. Guild raid creation belongs to the backend.
Duel exclusion is deferred. Live PvP detection is not implemented in this alpha.

Transport boundary
The addon cannot call your HTTP API directly. A supported transport must be
validated in Forever before live delivery is enabled. Discord chat mirroring
is a candidate, not a verified transport. In particular, test webhook/bot relay,
message readability, identity, channel reach and combat restrictions first.
Do not attempt to evaluate restricted/secret payloads: the adapter must supply
ordinary Lua values only. Never put credentials in the addon.

After the addon has loaded, another in-game adapter can register:
ForeverPVP.SetTransport(function(request)
    -- Validate/encode and send through a supported in-game transport.
    -- Return true only when accepted for delivery; false on failure.
end)
Use SetTransport(nil) to detach. The function is synchronous and must not yield.
The UI says 'submitted' on acceptance, not 'delivered'. Acknowledged alerts
are received separately through ForeverPVP.Receive(record).
There is no unbounded retry queue and no automatic transmission of demo records.

Receive record schema (plain Lua table, version 1)
version      1
id           Stable authoritative encounter/alert ID; 1-80 ASCII word/:.- chars
kind         heat | defense | raid
faction      Alliance | Horde (must match local faction)
ruleset      pvp | normal | rp | rppvp (must match local setting)
mapID        Positive integer UiMapID
x, y         Normalized map coordinates, each 0..1
count        Integer 0..1000; heat requires at least 4 unique players
updatedAt    Unix seconds; no older than 1 hour or >30 seconds in future
expiresAt    Unix seconds; future, after updatedAt, at most 1 hour from now
title        Plain text, max 72 bytes
reporter     Plain text, max 64 bytes
opposition   Optional reported guild/group, max 64 bytes
note         Optional plain text, max 160 bytes
estimated    Boolean; explicitly labels estimated participant counts
cityAllowed  Must be true for heat: backend approved location/city exception
demo         Reserved for local preview; production adapter must reject/strip it

Receive returns true on acceptance or false, reason on rejection. Duplicate IDs
replace existing entries only with a strictly newer updatedAt. Use at most one
revision per second per ID for this MVP. There is no replay tombstone after
expiry/eviction; the adapter must enforce replay protection. Storage eviction
drops the oldest updated record. The frontend does not merge different IDs.
All inbound text strips WoW pipe markup and control characters before display.
Server-side audience/authentication checks remain mandatory.

Anti-spam defaults
One local submitted report or defensive request per 120 seconds, persisted across reloads.
At most one toast notification per 30 seconds; heat updates remain silent.
Repeated IDs update the map/list without another notification. Muting does not
hide intelligence. Backend must enforce per-account/community/location limits;
local controls cannot stop a modified client. Notifications use a small clickable top-right toast.

Manual acceptance checks in Forever
1. Load normally with script errors enabled; /fwp shows a clean empty panel.
2. Outdoors, /fwp demo shows heat, defense and raid previews; filters/page buttons
   work; rows open their map; three crossed-sword icons and tooltips appear.
3. Change maps, pan, zoom, resize, close/reopen map; verify pins follow positions
   and no pins leak onto another zone. Check both windowed and fullscreen maps.
4. Wait five minutes; demo rows and pins disappear. /fwp clear does the same.
5. Open defense form; invalid counts fail; valid preview does not send anything.
6. Mock a rejected transport: preserve form and show delivery failure. Mock an
   accepted transport: mark request submitted and enforce the 120-second cooldown.
7. Inject wrong-faction, wrong-ruleset, malformed and expired records: reject all.
8. Enter combat: passive display remains usable; row navigation asks you to wait.
9. Reload: settings persist, intelligence is cleared; no startup notifications.

Source references checked November 6, 2026
https://github.com/Gethe/wow-ui-source/tree/forever
https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/version.txt
https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvas.lua

The package's small file size is not an in-game memory/CPU benchmark. Validate
actual runtime compatibility and visual layout on the target client before use.
