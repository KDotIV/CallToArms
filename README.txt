CALL TO ARMS 0.4.4-alpha
Documentation reconciled November 9, 2026

CallToArms/ is the installable MAIN addon. /cta report sends one bounded guild
addon message. Matching recipients display the report; accepted submissions also
display locally. Only remote receipt proves delivery. No external service or
third-party library is required. Target interface: 16001.

Start here:
  docs/GUILD_REPORT_TEST.txt - install, bind and run the two-player report test
  docs/GUILD_REPORT_RESULTS_2026-11-09.txt - observed results and evidence limits
  docs/PRE_LAYER_TEST_CHECKLIST.txt - remaining checks before layer coordination
  docs/BACKEND_HANDOFF.txt - current architecture, wire contract and future scope
  docs/BACKEND_STACK.txt - C# recommendation and external-transport boundary

Verified so far: two-way cross-zone guild diagnostic delivery, including sends
during PvE combat; main report receipt/details; visible map pins after the 0.4.4
fix. The managed AREA_POI map layer places the native line swords above fog and
exploration overlays. See docs/MAP_PIN_FIX_0.4.4.txt for the cause and correction.
Final remote-origin pin/toast tests on BOTH updated clients, keybinding use and
main UI combat/lifecycle checks remain open. Probe combat success alone does not
prove the full report UI in combat. Actual PvP detection is not implemented.

/cta report       One-action report, also in Key Bindings or an action-bar macro
/cta test on      Session-only simulated report; recipients must also opt in
/cta test off     End simulation and clear test reports
/cta status       Version, detected scope, guild transport and test state
/cta              Activity panel and notification toggle
/cta demo         Local-only interface preview
/cta clear        Clear local records; cooldowns remain
/cta mapdebug     Current map/pin diagnostics
/cta pincheck     Toggle independent crossed-swords rendering check

Normal reports retain unknown fight size. Simulation includes the reporter and
fills the participant count to four when needed, with explicit synthetic counts.
Only accessible players with verified distance are sampled; this is not a full
100-yard census. No actual combat/PvP flags are changed. Test mode resets off
on reload/login. Normal send cooldown: 120s; test send cooldown: 10s.

Audience uses detected game-rule flags, region and faction. Unknown scope disables
networking; manual ruleset overrides are not used. Guild broadcast is not a
faction-wide or cross-guild network, and client filtering is not confidentiality.
Layer IDs remain unknown. No automatic invites, layer transfer or world refresh
are implemented. Different-zone message receipt does not prove different layers.

Development checks (already passed for the 0.4.4 implementation; mocks do not
replace live acceptance):
  python -m pip install lupa
  python tests/test_addon.py
  python tests/test_reporting.py
  python tests/test_identity.py
  python tests/test_guild_reports.py

probes/ contains separate in-game messaging diagnostics (current version 0.3.0)
and the closed snapshot experiment. probes/RESULTS.txt records live transport
evidence. Discord/relay tooling is not active. No backend connection is proven.
Current main release: releases/CallToArms-0.4.4-alpha.zip; install its inner
CallToArms folder. Historical releases are not the current installation package.
