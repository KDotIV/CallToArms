from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
now=100; registered={}; prints={}; sends=0
function GetTime() return now end
function GetServerTime() return 1794220000 end
function GetBuildInfo() return '1.60.1','test','date',16001 end
function IsInGuild() return true end
function InCombatLockdown() return false end
function print(s) table.insert(prints,s) end
function issecretvalue(v) return v=='SECRET' end
function CreateFrame() return {
 RegisterEvent=function(_,event) registered[event]=true end,
 SetScript=function(_,_,f) handler=f end} end
SlashCmdList={}
C_ChatInfo={RegisterAddonMessagePrefix=function(p) assert(p=='CTAPROBE') end,
 InChatMessagingLockdown=function() return false end,
 AreOutgoingAddonChatMessagesRestricted=function() return false end,
 SendAddonMessage=function(p,text,kind)
   assert(p=='CTAPROBE' and kind=='GUILD'); sent=text; sends=sends+1
 end}
''')
addon = Path(__file__).resolve().parents[1] / 'CallToArmsProbe'
lua.execute('probeNamespace={}')
for file in ('SnapshotProbe.lua', 'Probe.lua'):
    lua.execute('assert(loadstring(...))("CallToArmsProbe", probeNamespace)', (addon/file).read_text())
lua.execute('''
handler(nil,'ADDON_LOADED','CallToArmsProbe')
local count=0; for _ in pairs(registered) do count=count+1 end
assert(count==2 and registered.ADDON_LOADED and registered.CHAT_MSG_ADDON)
assert(sends==0)
SlashCmdList.CALLTOARMSPROBE('status'); assert(sends==0)
assert(CallToArmsProbeDB.entries[#CallToArmsProbeDB.entries]:find('addonOutgoingRestricted=false',1,true))
SlashCmdList.CALLTOARMSPROBE('send removed'); assert(sends==0)
SlashCmdList.CALLTOARMSPROBE('addon first01')
assert(sends==1 and sent:find('id=first01 dir=addon',1,true))
SlashCmdList.CALLTOARMSPROBE('addon fast'); assert(sends==1)
handler(nil,'CHAT_MSG_ADDON','CTAPROBE','CTA-PROBE v1 id=remote dir=addon ts=0','GUILD','Friend')
assert(sends==1)
assert(CallToArmsProbeDB.entries[#CallToArmsProbeDB.entries]:find('sender=Friend',1,true))
local n=#CallToArmsProbeDB.entries
handler(nil,'CHAT_MSG_ADDON','OTHER','CTA-PROBE v1 id=wrong dir=addon ts=0','GUILD','Friend')
handler(nil,'CHAT_MSG_GUILD','CTA-PROBE v1 id=wrong dir=addon ts=0','Friend')
handler(nil,'CHAT_MSG_ADDON','SECRET','SECRET','GUILD','Friend')
handler(nil,'CHAT_MSG_ADDON','CTAPROBE','unrelated text','GUILD','Friend')
assert(#CallToArmsProbeDB.entries==n)
SlashCmdList.CALLTOARMSPROBE('watch on')
handler(nil,'CHAT_MSG_ADDON','CTAPROBE','SECRET','GUILD','Friend')
assert(CallToArmsProbeDB.entries[#CallToArmsProbeDB.entries]:find('RESTRICTED'))
now=now+5; SlashCmdList.CALLTOARMSPROBE('addon second02'); assert(sends==2)
now=now+5; SlashCmdList.CALLTOARMSPROBE('addon invalid|id'); assert(sends==2)
-- An unavailable addon API must not fall back to ordinary chat.
C_ChatInfo.SendAddonMessage=nil
SlashCmdList.CALLTOARMSPROBE('addon unavailable'); assert(sends==2)
assert(CallToArmsProbeDB.entries[#CallToArmsProbeDB.entries]:find('SEND_UNAVAILABLE'))
for i=1,300 do handler(nil,'CHAT_MSG_ADDON','CTAPROBE','SECRET','GUILD','Friend') end
assert(#CallToArmsProbeDB.entries==200)
SlashCmdList.CALLTOARMSPROBE('clear'); assert(#CallToArmsProbeDB.entries==0)
''')
print('PASS: in-game-only event registration, explicit guild sends, removed command inert, prefix filtering, no echo, debounce, restricted payloads, missing API and bounded logs.')
