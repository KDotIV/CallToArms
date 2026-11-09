local _, A = ...
local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value, extra = pcall(fn, ...)
    if not ok then return end
    if issecretvalue and (issecretvalue(value) or issecretvalue(extra)) then return end
    return value, extra
end

-- One bounded snapshot on user input; no background scan or retained unit frames.
function A.Snapshot(simulate)
    local result = {radiusYards = 100, complete = false, players = {}, unknownRange = 0}
    local seen = {}
    local function inspect(unit)
        if #result.players >= 64 then return end
        if read(UnitIsPlayer, unit) ~= true then return end
        local flagged = read(UnitIsPVP, unit) == true
        if not simulate and not flagged then return end
        local guid = read(UnitGUID, unit)
        if type(guid) ~= "string" or seen[guid] then return end
        seen[guid] = true
        local distance, checked = read(UnitDistanceSquared, unit)
        if simulate and unit == "player" then distance, checked = 0, true end
        if checked ~= true or type(distance) ~= "number" or distance ~= distance or distance < 0 then
            result.unknownRange = result.unknownRange + 1
            return
        end
        if distance > 10000 then return end
        result.players[#result.players + 1] = {
            guid = guid, name = A.CleanText(read(UnitName, unit), 64),
            faction = read(UnitFactionGroup, unit), pvpFlagged = flagged,
            simulatedCombat = simulate == true,
            distanceYards = math.floor(math.sqrt(distance)),
        }
    end
    if simulate then inspect("player") end
    for _, unit in ipairs({"target", "targettarget", "mouseover", "focus"}) do inspect(unit) end
    for i = 1, 40 do inspect("raid" .. i) end
    for i = 1, 4 do inspect("party" .. i) end
    local plates = read(C_NamePlate and C_NamePlate.GetNamePlates)
    if type(plates) == "table" then
        for i = 1, math.min(#plates, 64) do
            local plate = plates[i]
            if plate and (not plate.IsForbidden or not plate:IsForbidden()) then
                local unit = plate.namePlateUnitToken
                if not (issecretvalue and issecretvalue(unit)) and type(unit) == "string" then inspect(unit) end
            end
        end
    end
    return result
end

function A.Report()
    if not A.db then return false, "Addon is not ready." end
    if A.RefreshScope and not A.RefreshScope() then return false, "Ruleset/region unavailable; report not sent. Run /cta status." end
    local now = GetServerTime()
    local test = A.testMode == true
    local lastSubmit = test and A.lastTestSubmit or A.db.lastSubmit
    if now - (lastSubmit or 0) < (test and 10 or 120) then return false, "Report cooldown active." end
    if A.lastAttempt and GetTime() - A.lastAttempt < 5 then return false, "Please wait before retrying." end
    A.lastAttempt = GetTime()
    local loc = A.CurrentLocation()
    if not loc then return false, "Current location unavailable; report not sent." end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(loc.mapID)
    local request = {
        version = 1, id = "local:" .. now, kind = "report", manual = true,
        faction = UnitFactionGroup("player"), ruleset = A.db.ruleset,
        mapID = loc.mapID, x = loc.x, y = loc.y, zone = info and info.name or "",
        title = "PvP activity reported", reporter = UnitName("player"),
        updatedAt = now, expiresAt = now + 300,
        count = 0, countUnknown = true, test = test, snapshot = A.Snapshot(test),
        note = "Observer report. Flagged players are not confirmed combatants.",
    }
    request.observedCount = #request.snapshot.players
    request.unknownRange = request.snapshot.unknownRange
    request.syntheticCount = test and math.max(0, 4 - request.observedCount) or 0
    if test then
        request.title = "Simulated PvP report"
        request.count = request.observedCount + request.syntheticCount
        request.countUnknown = false
    end
    A.lastSnapshot = request.snapshot -- local-only sampled identities; wire uses bounded counts.
    request.note = A.ReportNote(test, request.observedCount, request.unknownRange, request.syntheticCount)
    if not A.adapter then
        request.demo = true
        local ok, reason = A.Receive(request)
        return ok, ok and "Local report preview created. Nothing was sent." or reason
    end
    local safe, accepted, message = pcall(A.adapter, request)
    if not safe or accepted ~= true then return false, (safe and message) or "Delivery unavailable; report not sent." end
    if test then A.lastTestSubmit = now else A.db.lastSubmit = now end
    return true, message or "Report submitted; remote delivery not confirmed."
end

function A.RunReport()
    local _, message = A.Report()
    A.Print(message)
end
