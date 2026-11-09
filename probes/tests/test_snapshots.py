"""Offline checks only: cannot establish WoW's actual disk/cache behavior."""
from pathlib import Path
from tempfile import TemporaryDirectory
import shutil
import subprocess
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
ns = {}; logs = {}; files = {}; loaded = {}; calls = 0; combat = false
function GetTime() return 100 end
function GetServerTime() return 1794220000 end
function InCombatLockdown() return combat end
function log(kind, text) table.insert(logs, kind .. " " .. text) end
function contains(text)
    for _, row in ipairs(logs) do if row:find(text, 1, true) then return true end end
    return false
end
C_AddOns = {
    DoesAddOnExist = function(name) return files[name] ~= nil end,
    IsAddOnLoaded = function(name) return loaded[name] == true end,
    IsAddOnLoadOnDemand = function(name) return files[name] ~= nil end,
    LoadAddOn = function(name)
        calls = calls + 1
        if failLoad then error('test failure') end
        if not loaded[name] then
            assert(loadstring(files[name]))()
            loaded[name] = true
        end
        return true
    end,
}
''')
lua.execute('assert(loadstring(...))("CallToArmsProbe", ns)',
            (ROOT / 'CallToArmsProbe/SnapshotProbe.lua').read_text())
for slot in range(1, 4):
    name = f'CallToArmsProbeSnapshot{slot:02}'
    folder = ROOT / 'SnapshotSlots' / name
    toc = (folder / f'{name}.toc').read_text()
    assert '## LoadOnDemand: 1' in toc and 'SavedVariables' not in toc
    assert 'Dependencies:' not in toc
    lua.globals().files[name] = (folder / 'Snapshot.lua').read_text()

lua.execute('''
ns.Snapshot.Initialize(log, tostring)
ns.Snapshot.Command('status')
assert(calls == 0 and CallToArmsProbeSnapshots == nil)
ns.Snapshot.Command('load 01 BASELINE_01')
assert(contains('MATCH addon=CallToArmsProbeSnapshot01 firstLoad=true'))
assert(CallToArmsProbeSnapshots.CallToArmsProbeSnapshot01.executions == 1)
-- Simulated stale contents: must report mismatch, not assume a successful read.
logs = {}
ns.Snapshot.Command('load 02 EDITED_02')
assert(contains('MISMATCH addon=CallToArmsProbeSnapshot02 firstLoad=true'))
local priorCalls = calls
ns.Snapshot.Command('load 04 BAD')
ns.Snapshot.Command('load 01 unsafe|value')
ns.Snapshot.Command('load 01')
ns.Snapshot.Command('load 01 ' .. string.rep('a',49))
combat = true; ns.Snapshot.Command('load 03 BASELINE_03'); combat = false
assert(calls == priorCalls)
local third = files.CallToArmsProbeSnapshot03
files.CallToArmsProbeSnapshot03 = nil
ns.Snapshot.Command('load 03 BASELINE_03'); assert(calls == priorCalls)
files.CallToArmsProbeSnapshot03 = third
failLoad = true; logs = {}
ns.Snapshot.Command('load 03 BASELINE_03')
assert(contains('INCONCLUSIVE'))
failLoad = false
''')

shell = shutil.which('pwsh') or shutil.which('powershell')
assert shell, 'PowerShell is needed to verify the companion writer.'
with TemporaryDirectory(prefix='cta snapshot test ') as temp:
    target = Path(temp) / 'AddOns'
    shutil.copytree(ROOT / 'SnapshotSlots', target)

    def write(slot, marker, succeeds=True, path=target):
        result = subprocess.run([
            shell, '-NoProfile', '-NonInteractive', '-File', str(ROOT / 'Write-Snapshot.ps1'),
            '-AddOnsPath', str(path), '-Slot', str(slot), '-Marker', marker,
        ], capture_output=True, text=True)
        assert (result.returncode == 0) == succeeds, result.stdout + result.stderr
        return result.stdout

    output = write(3, 'EDITED_03')
    third_file = target / 'CallToArmsProbeSnapshot03/Snapshot.lua'
    generated = third_file.read_text(encoding='utf-8')
    assert 'EDITED_03' in output and 'SHA256' in output
    assert not third_file.read_bytes().startswith(b'\xef\xbb\xbf')
    lua.globals().files['CallToArmsProbeSnapshot03'] = generated
    lua.execute('''
    logs = {}; ns.Snapshot.Command('load 03 EDITED_03')
    assert(contains('MATCH addon=CallToArmsProbeSnapshot03 firstLoad=true'))
    assert(CallToArmsProbeSnapshots.CallToArmsProbeSnapshot03.executions == 1)
    ''')
    write(3, 'AFTER_LOAD_03')
    lua.globals().files['CallToArmsProbeSnapshot03'] = third_file.read_text()
    lua.execute('''
    logs = {}; ns.Snapshot.Command('load 03 AFTER_LOAD_03')
    assert(contains('MISMATCH addon=CallToArmsProbeSnapshot03 firstLoad=false'))
    assert(CallToArmsProbeSnapshots.CallToArmsProbeSnapshot03.marker == 'EDITED_03')
    assert(CallToArmsProbeSnapshots.CallToArmsProbeSnapshot03.executions == 1)
    ''')
    before = third_file.read_bytes()
    write(3, 'bad"; error("injected")', succeeds=False)
    write(3, 'x\ny', succeeds=False)
    write(4, 'BAD_SLOT', succeeds=False)
    write(3, 'MISSING_ROOT', succeeds=False, path=target / 'missing')
    assert third_file.read_bytes() == before
    assert not (target / 'missing').exists()
    assert not list(target.rglob('*.tmp'))
    first_toc = target / 'CallToArmsProbeSnapshot01/CallToArmsProbeSnapshot01.toc'
    first_file = first_toc.with_name('Snapshot.lua')
    first_before = first_file.read_bytes()
    first_toc.write_text('## LoadOnDemand: 0\nSnapshot.lua\n')
    write(1, 'INVALID_TOC', succeeds=False)
    assert first_file.read_bytes() == first_before

lua.execute('''
-- Legacy globals remain usable if C_AddOns is absent.
for k,v in pairs(C_AddOns) do _G[k] = v end
C_AddOns = nil; logs = {}; ns.Snapshot.Command('load 01 BASELINE_01')
assert(contains('MATCH addon=CallToArmsProbeSnapshot01 firstLoad=false'))
-- A successful API return without an executed payload is inconclusive.
CallToArmsProbeSnapshots.CallToArmsProbeSnapshot01 = nil
logs = {}; ns.Snapshot.Command('load 01 BASELINE_01'); assert(contains('INCONCLUSIVE'))
LoadAddOn = nil; logs = {}; ns.Snapshot.Command('load 01 BASELINE_01')
assert(contains('SNAPSHOT_STOP'))
''')
print('PASS: snapshot controls, no automatic loads, mismatch/error classification, legacy APIs, writer validation and generated Lua 5.1 execution.')
print('NOT TESTED: WoW file discovery, caching, security, or reloadless snapshot delivery.')
