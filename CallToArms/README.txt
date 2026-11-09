CALL TO ARMS 0.4.4-alpha

Install this folder as Interface/AddOns/CallToArms. Restart after first install;
enable Call to Arms. Interface target: 16001. No bundled libraries are required.

Bind Call to Arms -> Report PvP at my location in Key Bindings, or use an
action-bar macro containing /cta report. Both send the same one-action report.

Both players run /cta status first. Guild membership, available messaging and
detected ruleset/region are required. Unknown scope disables network reports.
For simulation, BOTH run /cta test on, then press the report binding. Click the
TEST toast to see details, then Show on map outside combat for the purple pin.
Wait ten seconds between test reports. /cta test off clears test records.

Normal reports have unknown fight size and a 120-second cooldown. Only the
partial flagged-player snapshot summary is sent, not player names/GUIDs.
Test reports simulate observable players and fill to four using synthetic
participant counts. They never become real heat or city-raid authorization.

Guild messages can cross layers. Details show Layer: unknown; coordinate a
group invite with the reporter and use Blizzard's world-refresh UI as needed.
The addon cannot guarantee co-location or force a layer change.

See repository docs/GUILD_REPORT_TEST.txt for the complete test and protocol.
