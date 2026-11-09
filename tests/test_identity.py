from pathlib import Path
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1] / 'CallToArms'
toc = (root/'CallToArms.toc').read_text()
assert '## SavedVariables: CallToArmsDB' in toc
for line in toc.splitlines():
    if line and not line.startswith('#'):
        assert (root/line).is_file(), line
binding = ET.parse(root/'Bindings.xml').getroot().find('Binding')
assert binding.attrib == {'name':'CALLTOARMS_REPORT','header':'CALLTOARMS'}
for path in root.glob('*.lua'):
    assert 'ForeverPVP' not in path.read_text()

lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
function CreateFrame() return {RegisterEvent=function() end,
 SetScript=function(self,event,fn) handler=fn end} end
function GetServerTime() return 10000 end
SlashCmdList={}
A={Receive=function() end,RunReport=function() reports=(reports or 0)+1 end,
 RefreshUI=function() end,Demo=function() demos=(demos or 0)+1 end,
 Changed=function() end}
CallToArmsDB={ruleset='rp',muted=true,lastSubmit=9900}
''')
lua.execute('assert(loadstring(...))("CallToArms",A)',(root/'Core.lua').read_text())
lua.execute('''
handler(nil,'ADDON_LOADED','Unrelated')
assert(CallToArms==nil)
handler(nil,'ADDON_LOADED','CallToArms')
A.Demo=function() demos=(demos or 0)+1 end
assert(CallToArms.Version==1 and A.db==CallToArmsDB)
assert(A.db.ruleset=='rp' and A.db.muted and A.db.lastSubmit==9900)
assert(SLASH_CALLTOARMS1=='/cta' and BINDING_HEADER_CALLTOARMS=='Call to Arms')
assert(type(CallToArms.Report)=='function' and type(CallToArms.Receive)=='function')
assert(CallToArms.SetTransport(function() return true end))
SlashCmdList.CALLTOARMS(' report '); assert(reports==1)
SlashCmdList.CALLTOARMS('demo'); assert(demos==1)
assert(ForeverPVP==nil and SlashCmdList.FOREVERPVP==nil)
''')
lua.execute(binding.text)
lua.execute('assert(reports==2)')
print('PASS: manifest, renamed initialization/API, saved settings, command dispatch and XML binding.')
