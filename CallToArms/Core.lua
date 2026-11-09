local name, A = ...
function A.Print(message) print("|cffedbf69Call to Arms:|r " .. message) end

function A.Changed()
    A.RefreshUI(); A.RefreshMap()
    if not A.timer and next(A.records) then
        A.timer = C_Timer.NewTicker(15, function()
            A.Prune(GetServerTime()); A.RefreshUI(); A.RefreshMap()
            if not next(A.records) then A.timer:Cancel(); A.timer = nil end
        end)
    end
end

function A.Notify(r)
    if A.db.muted then return end
    local now = GetTime()
    local field = r.test and "lastTestNotice" or "lastNotice"
    if A[field] and now - A[field] < (r.test and 5 or 30) then return end
    A[field] = now
    A.ShowToast(r)
end

function A.SetTestMode(enabled)
    A.testMode = enabled == true
    if not A.testMode then
        for id, r in pairs(A.records) do if r.test then A.records[id] = nil end end
        for _, f in ipairs({A.toast or false, A.details or false}) do
            if f and f.record and f.record.test then f:Hide() end
        end
    end
    A.Changed()
    A.Print(A.testMode and "TEST MODE ON for this session. /cta report sends simulated guild reports."
        or "Test mode off; simulated reports cleared and incoming tests ignored.")
end

function A.SubmitDefense(count, opposition, note)
    count = tonumber(count)
    if not count or count ~= math.floor(count) or count < 4 or count > 1000 then
        return false, "Enter a participant estimate from 4 to 1000."
    end
    local now = GetServerTime()
    if now - (A.db.lastSubmit or 0) < 120 then return false, "Please wait before issuing another alert." end
    local loc = A.CurrentLocation()
    if not loc then return false, "Current location unavailable." end
    local r = {
        version = 1, id = "local:" .. now, kind = "defense", mapID = loc.mapID,
        x = loc.x, y = loc.y, faction = UnitFactionGroup("player"), ruleset = A.db.ruleset,
        title = "Defensive Call to Arms", count = count, estimated = true,
        reporter = UnitName("player"), opposition = A.CleanText(opposition, 64),
        note = A.CleanText(note, 160), updatedAt = now, expiresAt = now + 300,
    }
    if not A.adapter then
        r.demo = true
        local ok, reason = A.Receive(r)
        if not ok then return false, reason end
        A.Print("Local preview created. Nothing was sent.")
        return true, "Preview created"
    end
    -- Contract: return true only when accepted for delivery; server acknowledgement
    -- must arrive through Receive. No optimistic public alert or hidden retry queue.
    local safe, accepted = pcall(A.adapter, r)
    if not safe or accepted ~= true then return false, "Delivery unavailable. Please try again later." end
    A.db.lastSubmit = now
    A.Print("Request submitted; awaiting delivery confirmation.")
    return true, "Submitted"
end

function A.Demo()
    local loc = A.CurrentLocation()
    if not loc then A.Print("Move outdoors to preview reports at your location."); return end
    local now = GetServerTime()
    for i, kind in ipairs({"heat", "defense", "raid"}) do
        A.Receive({version = 1, id = "demo:" .. kind, kind = kind,
            faction = UnitFactionGroup("player"), ruleset = A.db.ruleset,
            mapID = loc.mapID, x = math.min(.98, loc.x + (i - 1) * .03), y = loc.y,
            updatedAt = now, expiresAt = now + 300, count = 4 + i * 4,
            title = ({"Fighting reported nearby", "Reinforcements requested", "Guild raid rally"})[i],
            reporter = "Preview organizer", opposition = "Example guild", note = "Sample data only.",
            demo = true, estimated = true, cityAllowed = true})
    end
    A.BuildUI(); A.panel:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GAME_RULES_CHANGED")
events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == name then
        if type(CallToArmsDB) ~= "table" then CallToArmsDB = {} end
        A.db = CallToArmsDB
        if A.db.ruleset ~= "pvp" and A.db.ruleset ~= "normal" and A.db.ruleset ~= "rp" and A.db.ruleset ~= "rppvp" then A.db.ruleset = "pvp" end
        A.db.muted = A.db.muted == true
        if type(A.db.lastSubmit) ~= "number" or A.db.lastSubmit ~= A.db.lastSubmit or A.db.lastSubmit > GetServerTime() then A.db.lastSubmit = 0 end
        -- Guild packets use a narrow versioned protocol, never ordinary chat.
        A.testMode = false
        if A.RefreshScope then A.RefreshScope() end
        if A.InitGuildTransport then A.InitGuildTransport() end
        CallToArms = {
            Report = A.RunReport,
            Receive = A.Receive,
            SetTransport = function(send)
                if send ~= nil and type(send) ~= "function" then return false end
                A.adapter = send; A.RefreshUI(); return true
            end,
            Version = 1,
        }
        SLASH_CALLTOARMS1 = "/cta"
        BINDING_HEADER_CALLTOARMS = "Call to Arms"
        BINDING_NAME_CALLTOARMS_REPORT = "Report PvP at my location"
        SlashCmdList.CALLTOARMS = function(command)
            command = command:lower():match("^%s*(.-)%s*$")
            if command == "report" then A.RunReport()
            elseif command == "test on" then A.SetTestMode(true)
            elseif command == "test off" then A.SetTestMode(false)
            elseif command == "status" then
                if A.RefreshScope then A.RefreshScope() end
                A.Print("0.4.4-alpha | guild=" .. tostring(IsInGuild()) .. " | messaging=" .. tostring(A.guildReady == true)
                    .. " | ruleset=" .. (A.scopeRuleset or "UNKNOWN - network disabled")
                    .. " | region=" .. tostring(A.scopeRegion) .. " | test=" .. tostring(A.testMode == true))
            elseif command == "mapdebug" then A.MapDebug()
            elseif command == "pincheck" then A.PinCheck()
            elseif command == "demo" then A.Demo()
            elseif command == "clear" then
                A.records = {}; if A.toast then A.toast:Hide() end; if A.details then A.details:Hide() end; A.Changed()
            elseif command:match("^ruleset ") then
                A.Print("Network rulesets are detected from the game; manual overrides are disabled. Use /cta status.")
            else A.BuildUI(); A.panel:SetShown(not A.panel:IsShown()) end
        end
    elseif event == "GAME_RULES_CHANGED" then
        if A.db and A.RefreshScope then A.RefreshScope() end
    elseif event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and addon == "Blizzard_WorldMap") then
        if A.db and A.RefreshScope then A.RefreshScope() end
        A.AttachMap()
    end
end)
