CALL TO ARMS
Lightweight WoW Forever PvP reporting frontend, version 0.2.0-alpha.

Repository: C:\Users\Brwnber\source\repos\CallToArms

START HERE
docs/BACKEND_HANDOFF.txt - agreed requirements, implementation state, exact Lua
contracts, backend plan, integration blockers and acceptance scenarios.

SOURCE AND INSTALLATION
ForeverPVP/ - installable addon. The repository was renamed; internal addon
names have not been migrated. Keep the inner folder named ForeverPVP for now.
ForeverPVP/UX.txt - current one-action reporting and notification behavior.
ForeverPVP/README.txt - installation, earlier alpha details and manual checks.
Where older notes differ, UX.txt and docs/BACKEND_HANDOFF.txt describe 0.2.0.

/cta report - immediately report at your current location; macro/keybind ready.
/fwp - activity panel. /fwp demo - local sample reports.
No transport attached means local preview only. Nothing is broadcast.

DEVELOPMENT TESTS
python -m pip install lupa
python tests/test_addon.py
python tests/test_reporting.py
Lupa is development-only; the addon has no bundled runtime dependencies.

Release ZIPs are in releases/ and ignored by Git.
Live transport, backend and automatic combat detection remain unimplemented.
Real-client rendering, security behavior and performance remain unverified.
