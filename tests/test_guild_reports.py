"""Two separate mocked Lua clients; no real network calls or game-state claims."""
from pathlib import Path
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / 'CallToArms'
template = ET.parse(ROOT/'MapPins.xml').getroot()[0]
assert template.attrib == {'name':'CallToArmsMapPinTemplate','virtual':'true','enableMouse':'true','mixin':'CallToArmsMapPinMixin'}
assert '## Dependencies: Blizzard_MapCanvas' in (ROOT/'CallToArms.toc').read_text()
BOOT = '''
NOW=1794240000; CLOCK=100; frames={}; packets={}; messages={}; sends=0; inGuild=true
function GetServerTime() return NOW end
function GetTime() return CLOCK end
function GetCurrentRegion() return 1 end
function GetNormalizedRealmName() return 'TestRealm' end
function UnitFactionGroup() return 'Horde' end
function UnitName(u) return u=='player' and PLAYER or u end
function UnitGUID(u) return 'Player-'..u end
function UnitIsPlayer(u) return u=='player' or u=='target' or u=='focus' end
function UnitIsPVP() return false end
function UnitDistanceSquared(u) return u=='target' and 10000 or 10001,true end
function InCombatLockdown() return false end
function IsInGuild() return inGuild end
function issecretvalue(v) return v=='SECRET' end
function print(s) table.insert(messages,s) end
Enum={GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3},
 SendAddonMessageResult={Success=0},RegisterAddonMessagePrefixResult={Success=0,DuplicatePrefix=1}}
C_GameRules={IsGameRuleActive=function(rule) return rule==3 end}
SlashCmdList={}; UISpecialFrames={}
local methods={}
function methods:RegisterEvent(e) self.events[e]=true end
function methods:SetScript(e,f) self.scripts[e]=f end
function methods:HookScript(e,f) self.scripts[e]=f end
function methods:CreateFontString() return frame('FontString') end
function methods:CreateTexture() return frame('Texture') end
function methods:CreateLine() return frame('Line') end
function methods:SetStartPoint(...) self.startPoint={...} end
function methods:SetEndPoint(...) self.endPoint={...} end
function methods:SetThickness(n) self.thickness=n end
function methods:SetText(s) self.text=s end
function methods:SetTexture(path)
 error('Report pins must not load file textures')
end
function methods:SetPoint(...) self.point={...} end
function methods:SetSize(w,h) self.w=w; self.h=h end
function methods:GetWidth() return self.w or 1000 end
function methods:GetHeight() return self.h or 600 end
function methods:GetFrameLevel() return 1 end
function methods:SetFrameLevel(level) self.level=level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetVertexColor(...) self.color={...} end
function methods:SetColorTexture(...) self.color={...} end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetShown(v) self.shown=v end
function methods:IsShown() return self.shown==true end
function methods:GetText() return self.text end
function frame(kind,name,parent)
 local f=setmetatable({kind=kind,events={},scripts={},parent=parent},
 {__index=function(_,k) return methods[k] or (k:match('^[A-Z]') and function() end) or nil end})
 table.insert(frames,f); if name then _G[name]=f end; return f
end
function CreateFrame(kind,name,parent) return frame(kind,name,parent) end
function CreateFromMixins(...)
 local obj={}
 for i=1,select('#',...) do for k,v in pairs(select(i,...)) do obj[k]=v end end
 return obj
end
MapCanvasPinMixin={
 OnReleased=function() end,
 UseFrameLevelType=function(self,t) self.frameLevelType=t end,
 SetScalingLimits=function(self,...) self.scaling={...} end,
 SetAlphaLimits=function(self,...) self.alphaLimits={...} end,
 SetPosition=function(self,x,y)
  self.normalizedX=x; self.normalizedY=y
  self:SetPoint('CENTER',canvas,'TOPLEFT',x*canvas:GetWidth(),-y*canvas:GetHeight())
 end,
}
MapCanvasDataProviderMixin={
 OnAdded=function(self,map) self.owningMap=map end,
 GetMap=function(self) return self.owningMap end,
 OnMapChanged=function(self) self:RefreshAllData() end,
}
UIParent=frame('Root'); GameTooltip=frame('Tooltip')
canvas=frame('Canvas')
WorldMapFrame=frame('Map'); WorldMapFrame.shown=true; WorldMapFrame.map=1
WorldMapFrame.GetCanvas=function() return canvas end
WorldMapFrame.GetMapID=function(self) return self.map end
WorldMapFrame.SetMapID=function(self,id)
 self.map=id; if self.provider then self.provider:OnMapChanged() end
end
WorldMapFrame.OnMapChanged=function() end
WorldMapFrame.pool={}
-- Preserve the critical relative ordering from Blizzard_WorldMap.lua:
-- DEFAULT is BELOW exploration/fog, so it is not a visible report-pin layer.
local pinLevels={PIN_FRAME_LEVEL_DEFAULT=2000, PIN_FRAME_LEVEL_MAP_EXPLORATION=2002,
 PIN_FRAME_LEVEL_FOG_OF_WAR=2006, PIN_FRAME_LEVEL_AREA_POI=2023}
WorldMapFrame.AddDataProvider=function(self,p) self.provider=p; p:OnAdded(self) end
WorldMapFrame.RemoveAllPinsByTemplate=function(self,t)
 assert(t=='CallToArmsMapPinTemplate')
 for _,p in ipairs(self.pool) do
  if p.active then p:OnReleased(); p.active=false; p:Hide() end
 end
end
WorldMapFrame.AcquirePin=function(self,t,r)
 assert(t=='CallToArmsMapPinTemplate')
 local pin
 for _,p in ipairs(self.pool) do if not p.active then pin=p; break end end
 if not pin then
  pin=frame('Frame',nil,canvas); pin:SetSize(28,28)
  for k,v in pairs(CallToArmsMapPinMixin) do pin[k]=v end
  pin:OnLoad(); table.insert(self.pool,pin)
 end
 pin.active=true; pin:Show(); pin:OnAcquired(r)
 pin:SetFrameLevel(pinLevels[pin.frameLevelType] or pinLevels.PIN_FRAME_LEVEL_DEFAULT)
 assert(pin:GetFrameLevel()>pinLevels.PIN_FRAME_LEVEL_MAP_EXPLORATION)
 assert(pin:GetFrameLevel()>pinLevels.PIN_FRAME_LEVEL_FOG_OF_WAR)
 return pin
end
function hooksecurefunc() end
C_Timer={NewTicker=function(_,fn) return {Cancel=function() end,fn=fn} end,
 NewTimer=function(_,fn) return {Cancel=function() end,fn=fn} end}
C_Map={GetBestMapForUnit=function() return 1 end,
 GetPlayerMapPosition=function() return {GetXY=function() return .25,.75 end} end,
 GetMapInfo=function(id) return {name='Zone '..id} end}
C_ChatInfo={RegisterAddonMessagePrefix=function(p) assert(p=='CTA_REPORT1'); return 0 end,
 SendAddonMessage=function(prefix,payload,route)
  assert(prefix=='CTA_REPORT1' and route=='GUILD' and #payload<=255)
  if sendFailure then return 3 end
  packets[#packets+1]=payload; sends=sends+1; return 0
 end}
A={}
'''

def client(name):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(BOOT)
    lua.globals().PLAYER = name
    for line in (ROOT/'CallToArms.toc').read_text().splitlines():
        if line.endswith('.lua'):
            lua.execute('assert(loadstring(...))("CallToArms",A)', (ROOT/line).read_text())
    lua.execute('''
    for _,f in ipairs(frames) do if f.events.ADDON_LOADED then core=f end end
    core.scripts.OnEvent(nil,'ADDON_LOADED','CallToArms')
    core.scripts.OnEvent(nil,'PLAYER_LOGIN')
    assert(sends==0 and A.scopeRuleset=='pvp' and A.scopeRegion==1 and A.guildReady)
    ''')
    return lua

alice, bob = client('Alice'), client('Bob')
alice.execute('''
SlashCmdList.CALLTOARMS('test on')
assert(A.testMode)
CallToArms.Report() -- same entry point as binding
assert(sends==1 and #A.List()==1)
local r=A.List()[1]
assert(r.test and r.count==4 and r.observedCount==2 and r.syntheticCount==2)
assert(not r.countUnknown and A.lastSnapshot.players[1].pvpFlagged==false)
assert(A.lastSnapshot.players[1].simulatedCombat)
assert(A.toast.title.text:find('[TEST]',1,true) and A.toast.shown)
CallToArms.Report(); assert(sends==1) -- cooldown
''')
packet = alice.globals().packets[1]

def deliver(lua, data=packet, sender='Alice-TestRealm', prefix='CTA_REPORT1', route='GUILD'):
    lua.globals().A.OnGuildMessage(prefix, data, route, sender)

deliver(bob)  # explicit recipient opt-in required
bob.execute("assert(#A.List()==0); SlashCmdList.CALLTOARMS('test on')")
deliver(bob)
bob.execute('''
assert(#A.List()==1 and sends==0) -- receive never rebroadcasts
local r=A.List()[1]
assert(r.reporter=='Alice-TestRealm' and r.mapID==1 and r.x==.25 and r.y==.75)
assert(r.count==4 and r.syntheticCount==2 and A.toast.shown)
assert(A.toast.title.text:find('[TEST]',1,true))
A.toast.scripts.OnClick(A.toast,'LeftButton')
assert(A.details.shown and not A.toast.shown)
assert(A.details.body.text:find('Layer: unknown',1,true))
assert(A.details.body.text:find('2 synthetic',1,true))
local pins=0
for _,f in ipairs(frames) do
 if f.parent==canvas and f.shown then
  pins=pins+1; assert(f.record.id==r.id and #f.strokes==6)
  for _,line in ipairs(f.strokes) do
   assert(line.kind=='Line' and line.color[1]==A.testColor[1] and line.color[4]==1)
   assert(line.thickness>=2 and line.startPoint and line.endPoint and line.shown)
  end
  assert(f.point[4]==250 and f.point[5]==-450)
  assert(f.normalizedX==.25 and f.normalizedY==.75 and f.frameLevelType=='PIN_FRAME_LEVEL_AREA_POI')
  assert(f.scaling[2]==1 and f.scaling[3]==1 and f.alphaLimits[2]==1)
  A.details:Hide(); f:OnMouseClickAction('LeftButton'); assert(A.details.shown)
 end
end
assert(pins==1)
SlashCmdList.CALLTOARMS('pincheck'); assert(A.pinCheck.shown)
SlashCmdList.CALLTOARMS('pincheck'); assert(not A.pinCheck.shown)
local poolSize=#WorldMapFrame.pool
WorldMapFrame:SetMapID(2)
for _,p in ipairs(WorldMapFrame.pool) do assert(not p.active and not p.record) end
WorldMapFrame:SetMapID(1)
assert(#WorldMapFrame.pool==poolSize and WorldMapFrame.pool[1].active)
A.RefreshMap(); assert(#WorldMapFrame.pool==poolSize) -- pooled, not growing each tick
''')
deliver(bob); deliver(alice)  # replay and self echo do not duplicate
alice.execute('assert(#A.List()==1)')
bob.execute('assert(#A.List()==1 and sends==0)')

# Reverse direction while the recipient is in mocked combat.
bob.execute('CallToArms.Report(); assert(sends==1)')
alice.execute('function InCombatLockdown() return true end; CLOCK=CLOCK+6')
deliver(alice, bob.globals().packets[1], 'Bob-TestRealm')
alice.execute('assert(#A.List()==2 and A.toast.record.reporter=="Bob-TestRealm")')

# Opt-out clears simulated data and ignores incoming tests, retaining real data.
bob.execute('''
SlashCmdList.CALLTOARMS('test off')
assert(#A.List()==0 and not A.details.shown and not A.toast.shown)
CLOCK=CLOCK+10; NOW=NOW+10
CallToArms.Report(); assert(sends==2)
assert(not A.List()[1].test and A.List()[1].countUnknown)
''')
real = bob.globals().packets[2]
alice.execute('CLOCK=CLOCK+10; NOW=NOW+10')
deliver(alice, real, 'Bob-TestRealm')
alice.execute('assert(#A.List()==3)')
deliver(bob)
bob.execute('assert(#A.List()==1)')

def altered(index, value):
    fields = packet.split('\t'); fields[index] = value
    return '\t'.join(fields)

# Fresh receiver for adversarial input. Wrong scope never enters store or toasts.
guard = client('Guard')
guard.execute("SlashCmdList.CALLTOARMS('test on')")
for bad in [altered(8, 'rppvp'), altered(12, '2'), altered(7, 'A'),
            altered(5, '10001'), altered(3, '1'), altered(4, 'nan'),
            altered(11, '0'), packet+'\textra', 'x'*256, 'SECRET']:
    deliver(guard, bad)
    guard.execute('CLOCK=CLOCK+2')
deliver(guard, prefix='OTHER'); deliver(guard, route='PARTY')
guard.execute('assert(#A.List()==0 and sends==0)')
guard.execute('''
Enum.GameRule.PvPRuleset=nil
CallToArms.Report(); assert(sends==0 and A.scopeRuleset==nil)
''')
deliver(guard)
guard.execute('assert(#A.List()==0)')

# API failure must not become a local success or consume network cooldown.
failed = client('Failed')
failed.execute('''
sendFailure=true
CallToArms.Report(); assert(sends==0 and #A.List()==0 and A.db.lastSubmit==0)
sendFailure=false; CLOCK=CLOCK+5; NOW=NOW+5
CallToArms.Report(); assert(sends==1 and A.db.lastSubmit==NOW)
''')

# Automatic rulesets cannot be changed by a slash override; RP-PvP differs from PvP.
failed.execute('''
C_GameRules.IsGameRuleActive=function(rule) return rule==2 or rule==3 end
A.RefreshScope(); assert(A.scopeRuleset=='rppvp' and #A.List()==0)
SlashCmdList.CALLTOARMS('ruleset pvp'); assert(A.db.ruleset=='rppvp')
C_GameRules.IsGameRuleActive=function(rule) return rule==1 end
A.RefreshScope(); assert(A.scopeRuleset=='hardcore')
C_GameRules.IsGameRuleActive=function(rule) return rule==2 end
A.RefreshScope(); assert(A.scopeRuleset=='rp')
C_GameRules.IsGameRuleActive=function() return false end
A.RefreshScope(); assert(A.scopeRuleset=='normal')
C_GameRules.IsGameRuleActive=function() return 'SECRET' end
assert(not A.RefreshScope() and A.scopeRuleset==nil)
''')
# A UI exception after a successful send must not report a network failure or
# invite an immediate duplicate retry.
display_failure = client('DisplayFailure')
display_failure.execute('''
A.Changed=function() error('mock UI failure') end
local ok,msg=A.Report()
assert(ok and sends==1 and A.db.lastSubmit==NOW)
assert(msg:find('accepted',1,true))
''')
print('PASS: separate-client reports, test isolation, native map provider/template, normalized placement, managed frame level, pooled refresh/zone changes, click details, packet bounds, duplicates, cooldowns and scope filtering.')
print('Mock combat validates code paths only; real client UI/security behavior still requires testing.')
