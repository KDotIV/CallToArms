local addonName, ns = ...
local frame = CreateFrame("Frame")
local db, counter, lastSend = nil, 0, -math.huge
local function secret(v) return issecretvalue and issecretvalue(v) end
local function safe(v)
    if secret(v) then return "<restricted>" end
    if type(v) == "string" then return v:gsub("|", ""):gsub("[%c]", " "):sub(1, 220) end
    if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    return "<" .. type(v) .. ">"
end
local function printLine(s) print("|cffedbf69CTA Probe:|r " .. s) end
local function record(kind, message)
    if not db then return end
    local row = GetServerTime() .. " " .. kind .. " " .. message
    table.insert(db.entries, row)
    if #db.entries > 200 then table.remove(db.entries, 1) end
    printLine(row)
end
local function state(fn)
    if type(fn) ~= "function" then return "unavailable" end
    local ok, value = pcall(fn)
    return ok and safe(value) or "API error"
end
local function status()
    local ci = C_ChatInfo or {}
    record("STATUS", "combat=" .. state(InCombatLockdown)
        .. " chatLockdown=" .. state(ci.InChatMessagingLockdown)
        .. " addonOutgoingRestricted=" .. state(ci.AreOutgoingAddonChatMessagesRestricted))
end
local function send(id)
    if GetTime() - lastSend < 5 then printLine("Wait five seconds between sends."); return end
    if id == "" then counter = counter + 1; id = "wow-" .. GetServerTime() .. "-" .. counter end
    if #id > 48 or not id:match("^[%w_-]+$") then printLine("Use a short alphanumeric/hyphen/underscore ID."); return end
    if not IsInGuild() then printLine("A guild is required."); return end
    lastSend = GetTime()
    local text = "CTA-PROBE v1 id=" .. id .. " dir=addon ts=" .. GetServerTime()
    local ci = C_ChatInfo or {}
    local fn = ci.SendAddonMessage
    if type(fn) ~= "function" then record("SEND_UNAVAILABLE", id); return end
    status()
    local ok, result = pcall(fn, "CTAPROBE", text, "GUILD")
    record(ok and "SEND_ATTEMPT" or "SEND_ERROR", text .. " result=" .. safe(result))
    printLine("An API return is not delivery proof. Check the second player's RECEIVED log.")
end
local function export()
    if not frame.export then
        local f = CreateFrame("Frame", "CallToArmsProbeExport", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(620,400); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f.TitleText:SetText("CTA Probe - Ctrl+A, Ctrl+C to copy")
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",12,-35); scroll:SetPoint("BOTTOMRIGHT",-30,15)
        local edit = CreateFrame("EditBox",nil,scroll)
        edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(560)
        edit:SetAutoFocus(false); edit:SetScript("OnEscapePressed",function() f:Hide() end)
        scroll:SetScrollChild(edit); f.edit = edit; frame.export = f
        table.insert(UISpecialFrames,"CallToArmsProbeExport")
    end
    frame.export.edit:SetText(table.concat(db.entries,"\n")); frame.export:Show()
    frame.export.edit:SetFocus(); frame.export.edit:HighlightText()
end
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent",function(_,event,...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        if type(CallToArmsProbeDB) ~= "table" then CallToArmsProbeDB = {} end
        db = CallToArmsProbeDB
        if type(db.entries) ~= "table" then db.entries = {} end
        while #db.entries > 200 do table.remove(db.entries,1) end
        ns.Snapshot.Initialize(record, safe)
        for _, name in ipairs({"CHAT_MSG_ADDON"}) do
            local ok = pcall(frame.RegisterEvent,frame,name)
            if not ok then record("EVENT_UNAVAILABLE",name) end
        end
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,"CTAPROBE") end
        SLASH_CALLTOARMSPROBE1 = "/ctaprobe"
        SlashCmdList.CALLTOARMSPROBE = function(input)
            local cmd, arg = input:match("^%s*(%S*)%s*(.-)%s*$")
            cmd = cmd:lower()
            if cmd == "addon" then send(arg)
            elseif cmd == "status" then status()
            elseif cmd == "snapshot" then ns.Snapshot.Command(arg)
            elseif cmd == "export" then export()
            elseif cmd == "clear" then db.entries = {}; printLine("Capture cleared.")
            elseif cmd == "watch" then db.watch = arg == "on"; printLine("Metadata watch " .. (db.watch and "on" or "off"))
            else printLine("/ctaprobe addon [id] | status | snapshot | export | clear | watch on/off") end
        end
        local version, build, _, interface = GetBuildInfo()
        record("LOADED", "version=" .. safe(version) .. " build=" .. safe(build) .. " interface=" .. safe(interface))
        return
    end
    local args = {...}
    if event ~= "CHAT_MSG_ADDON" then return end
    if secret(args[1]) or args[1] ~= "CTAPROBE" then return end
    local msg = args[2]
    if secret(msg) then
        -- Never compare/parse secret text; only count that a restricted event occurred.
        if db.watch then record("RESTRICTED", event) end
        return
    end
    if type(msg) ~= "string" or not msg:match("^CTA%-PROBE v1 ") then
        if db.watch then record("EVENT",event .. " payloadType=" .. type(msg)) end
        return
    end
    record("RECEIVED",event .. " " .. safe(msg))
    record("META", "prefix=" .. safe(args[1]) .. " route=" .. safe(args[3]) .. " sender=" .. safe(args[4]))
end)
