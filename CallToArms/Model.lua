local _, A = ...
A.MAX_ALERTS = 64
A.records = {}

local function number(v, lo, hi)
    return type(v) == "number" and v == v and v >= lo and v <= hi
end
local function text(v, limit)
    if type(v) ~= "string" then return "" end
    -- Never allow incoming text to inject WoW hyperlinks, textures or colors.
    return v:gsub("|", ""):gsub("[%c]", " "):sub(1, limit)
end
A.CleanText = text
function A.DisplayTitle(r)
    return (r.test and "[TEST] " or r.demo and "[DEMO] " or "") .. r.title
end

function A.Validate(r, now, faction, ruleset)
    if type(r) ~= "table" or r.version ~= 1 then return nil, "Unsupported alert" end
    if type(r.id) ~= "string" or #r.id == 0 or #r.id > 80
        or r.id:find("[^%w_:%-%.]") then return nil, "Invalid ID" end
    if r.faction ~= faction or r.ruleset ~= ruleset then return nil, "Wrong audience" end
    if r.kind ~= "heat" and r.kind ~= "defense" and r.kind ~= "raid" and r.kind ~= "report" then
        return nil, "Invalid kind"
    end
    if not number(r.mapID, 1, 100000) or r.mapID % 1 ~= 0
        or not number(r.x, 0, 1) or not number(r.y, 0, 1)
        or not number(r.updatedAt, now - 3600, now + 30)
        or not number(r.expiresAt, now + 1, now + 3600)
        or r.expiresAt <= r.updatedAt then return nil, "Invalid location or time" end
    if not number(r.count, 0, 1000) or r.count % 1 ~= 0 then return nil, "Invalid count" end
    for _, field in ipairs({"observedCount", "unknownRange", "syntheticCount"}) do
        if r[field] ~= nil and (not number(r[field], 0, 128) or r[field] % 1 ~= 0) then return nil, "Invalid snapshot summary" end
    end
    if r.kind == "heat" and r.count < 4 then return nil, "Below heat threshold" end
    if r.kind == "heat" and r.countUnknown then return nil, "Unknown heat count" end
    -- The authenticated adapter/backend resolves city exceptions and authorization.
    -- This is an explicit display decision, not a client-inferred city classification.
    if r.kind == "heat" and r.cityAllowed ~= true then return nil, "Heat not approved" end
    return {
        version = 1, id = r.id, faction = r.faction, ruleset = r.ruleset,
        kind = r.kind, mapID = r.mapID, x = r.x, y = r.y, count = r.count,
        updatedAt = r.updatedAt, expiresAt = r.expiresAt,
        title = text(r.title, 72), reporter = text(r.reporter, 64),
        opposition = text(r.opposition, 64), note = text(r.note, 160),
        estimated = r.estimated == true, demo = r.demo == true,
        test = r.test == true,
        observedCount = r.observedCount, unknownRange = r.unknownRange, syntheticCount = r.syntheticCount,
        countUnknown = (r.kind == "report" and not r.test) or r.countUnknown == true,
    }
end

function A.Prune(now)
    local changed = false
    for id, r in pairs(A.records) do
        if r.expiresAt <= now then A.records[id] = nil; changed = true end
    end
    return changed
end

function A.Receive(r)
    if not A.db then return false, "Not initialized" end
    if type(r) == "table" and r.test == true and not A.testMode then return false, "Test mode disabled" end
    local now = GetServerTime()
    local clean, reason = A.Validate(r, now, UnitFactionGroup("player"), A.db.ruleset)
    if not clean then return false, reason end
    A.Prune(now)
    local old = A.records[clean.id]
    if old and clean.updatedAt <= old.updatedAt then return false, "Stale or duplicate" end
    if not old then
        local size, oldest = 0, nil
        for id, item in pairs(A.records) do
            size = size + 1
            if not oldest or item.updatedAt < A.records[oldest].updatedAt then oldest = id end
        end
        if size >= A.MAX_ALERTS then A.records[oldest] = nil end
    end
    A.records[clean.id] = clean
    if A.Changed then A.Changed() end
    if not old and clean.kind ~= "heat" and A.Notify then A.Notify(clean) end
    return true
end

function A.List(filter)
    local list, now = {}, GetServerTime()
    for _, r in pairs(A.records) do
        if r.expiresAt > now and (not filter or filter == "all" or r.kind == filter or (filter == "defense" and r.kind == "report")) then
            list[#list + 1] = r
        end
    end
    table.sort(list, function(a, b)
        if a.updatedAt == b.updatedAt then return a.id < b.id end
        return a.updatedAt > b.updatedAt
    end)
    return list
end
