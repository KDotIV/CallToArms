CALL TO ARMS - IN-GAME DIAGNOSTICS 0.3.0
November 9, 2026

Observed result
Two-way cross-zone guild delivery and remote receipt of each player's PvE-combat
send have been observed. See RESULTS.txt for exact markers and limitations.
This diagnostic remains optional for troubleshooting; the current main-addon
acceptance pass is in ../docs/PRE_LAYER_TEST_CHECKLIST.txt. No probe reinstall
or additional snapshot trial is needed merely to reproduce the map pin fix.

Purpose
Verify C_ChatInfo.SendAddonMessage -> CHAT_MSG_ADDON between two guild members.
The probe sends short diagnostic markers, not production /cta report records.
It has no external-service integration or ordinary chat send/receive path.
No C# console, bot, account linking or external packages are needed in WoW.

Install/update BOTH players
Copy CallToArmsProbe into the active client's Interface/AddOns directory.
The final file must be CallToArmsProbe/CallToArmsProbe.toc.
Enable Call to Arms - Diagnostics. Restart after first installation; for this
update to the existing addon, /reload outside combat to load the new code.
The release ZIP contains only CallToArmsProbe. Snapshot slots are optional,
separate fixtures and are not needed for messaging. Interface target: 16001.

Two-way test
Both players must be online in the same guild and faction. Start outside combat.
Both run:
  /ctaprobe watch off
  /ctaprobe status
Player A runs:
  /ctaprobe addon playerA03
Player B must see RECEIVED CHAT_MSG_ADDON containing id=playerA03, plus META
with prefix=CTAPROBE, route=GUILD and Player A's character as sender.
Player B then runs:
  /ctaprobe addon playerB03
Player A must see the corresponding RECEIVED and META lines from Player B.
Both run /ctaprobe export to copy logs. Wait five seconds between sends from
the same character. No automatic sends, replies or retry loops are implemented.
An API return or sender's own echo is not delivery proof.

If the status command or sending triggers a blocked-action popup, stop and
record the exact command, addon name, client build and combat state.
If delivery is missing, /ctaprobe watch on records metadata/restricted payload
events for our CTAPROBE prefix only. Use a new test ID for a deliberate retry.
Do not interpret unreadable/restricted content as confirmed delivery of that ID.
Capture LOADED build information and status lines in the exported log.
The export holds at most 200 lines; SavedVariables flush on logout/reload.

After the baseline passes, repeat both directions in different zones, during
outdoor combat, and after combat. This tests only guild delivery; it does not
establish faction-wide, cross-guild, cross-realm or backend transport.

Commands
  /ctaprobe addon [id]       Explicitly attempt one guild addon message
  /ctaprobe status           Combat and chat capability flags
  /ctaprobe watch on/off     Metadata for our prefix only
  /ctaprobe export           Copyable bounded capture
  /ctaprobe clear            Clear capture, not loaded snapshot slots
  /ctaprobe snapshot         Help for optional snapshot experiment
The old 'send' command has been removed; it performs no send.

Snapshots
See SNAPSHOT_EXPERIMENT.txt and SNAPSHOT_RESULTS_2026-11-09.txt. The live trial
observed updated data on first load of an unused slot, but no refresh of an
already-loaded slot. No further snapshot test is needed for guild messaging.

Offline tests (development only)
  python -m pip install lupa
  python probes/tests/test_probe.py
  python probes/tests/test_snapshots.py
These mocks do not establish real-client delivery or security compatibility.
