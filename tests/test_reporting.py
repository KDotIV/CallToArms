from pathlib import Path
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
root = Path(__file__).resolve().parents[1] / 'CallToArms'
lua.execute('''
NOW=10000
function GetServerTime() return NOW end
function GetTime() return NOW end
function UnitFactionGroup() return 'Horde' end
function UnitName(u) return u end
function UnitIsPlayer(u) return u=='target' or u=='targettarget' or u=='mouseover' or u=='focus' end
function UnitIsPVP() return true end
function UnitGUID(u) return u=='targettarget' and 'target' or u end
function UnitDistanceSquared(u)
 if u=='target' then return 10000,true end
 if u=='focus' then return 10001,true end
 return 0,false
end
A={db={ruleset='pvp'}}
''')
for name in ['Model.lua','GuildTransport.lua','Report.lua']:
    lua.execute('assert(loadstring(...))("CallToArms",A)', (root/name).read_text())
lua.execute('''
local s=A.Snapshot()
assert(#s.players==1 and s.players[1].guid=='target')
assert(s.complete==false and s.unknownRange==1)
A.CurrentLocation=function() return {mapID=1,x=.5,y=.5} end
local ok,msg=A.Report(); assert(ok,msg)
local list=A.List(); assert(#list==1 and list[1].kind=='report' and list[1].countUnknown)
assert(#A.List('defense')==1)
assert(not A.Report()) -- retry debounce
NOW=NOW+5
A.adapter=function(r)
 assert(r.kind=='report' and r.snapshot.complete==false and r.count==0 and r.countUnknown)
 return true
end
assert(A.Report()); assert(not A.Report()) -- accepted submission cooldown
NOW=NOW+120
A.adapter=function() return false end
assert(not A.Report())
NOW=NOW+5
UnitDistanceSquared=function() error('API unavailable') end
assert(#A.Snapshot().players==0)
issecretvalue=function(v) return v=='secret' end
UnitGUID=function() return 'secret' end
assert(#A.Snapshot().players==0)
''')
print('PASS: partial snapshot, 100-yard boundary, GUID deduplication, unknown range, API failures, secret values, single-action report, audience, cooldown and rejected delivery.')
