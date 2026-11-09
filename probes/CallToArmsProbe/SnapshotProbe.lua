local _, ns = ...
local Snapshot = {}
ns.Snapshot = Snapshot
local record, safe
local prefix = "CallToArmsProbeSnapshot"

local function api(name)
    return (C_AddOns and C_AddOns[name]) or _G[name]
end

local function query(name, addon)
    local fn = api(name)
    if type(fn) ~= "function" then return nil, "unavailable" end
    local ok, value = pcall(fn, addon)
    if not ok then return nil, "API error" end
    return value, safe(value)
end

local function payload(addon)
    local rows = CallToArmsProbeSnapshots
    local row = type(rows) == "table" and rows[addon]
    if type(row) ~= "table" then return nil end
    return row
end

local function show(addon)
    local _, loaded = query("IsAddOnLoaded", addon)
    local _, lod = query("IsAddOnLoadOnDemand", addon)
    local _, exists = query("DoesAddOnExist", addon)
    record("SNAPSHOT_STATE", "addon=" .. addon .. " exists=" .. exists
        .. " loadedOrLoading=" .. loaded .. " loadOnDemand=" .. lod)
    local row = payload(addon)
    if row then
        record("SNAPSHOT_DATA", "addon=" .. addon .. " marker=" .. safe(row.marker)
            .. " writtenUtc=" .. safe(row.writtenUtc) .. " executions=" .. safe(row.executions))
    end
end

function Snapshot.Initialize(log, format)
    record, safe = log, format
    -- Snapshot values deliberately have no SavedVariables declaration.
    record("SNAPSHOT_SESSION", "uiStartServerTime=" .. GetServerTime()
        .. " uptime=" .. GetTime() .. " slots=3; no slots loaded by diagnostics")
end

function Snapshot.Command(input)
    if input == "status" then
        for i = 1, 3 do show(prefix .. string.format("%02d", i)) end
        return
    end
    local slot, expected = input:match("^load%s+(%d+)%s+([A-Za-z0-9_-]+)$")
    local n = tonumber(slot)
    if not n or n < 1 or n > 3 or #expected > 48 then
        record("SNAPSHOT_HELP", "/ctaprobe snapshot status | snapshot load 01 EXPECTED_MARKER (slots 01-03)")
        return
    end
    local addon = prefix .. string.format("%02d", n)
    if InCombatLockdown and InCombatLockdown() then
        record("SNAPSHOT_STOP", "combat; retry outside combat without reloading")
        return
    end
    local wasLoaded, loadedState = query("IsAddOnLoaded", addon)
    local lod, lodState = query("IsAddOnLoadOnDemand", addon)
    local exists = query("DoesAddOnExist", addon)
    local fn = api("LoadAddOn")
    if exists == false or type(wasLoaded) ~= "boolean" or not lod or type(fn) ~= "function" then
        record("SNAPSHOT_STOP", "addon=" .. addon .. " missing/unsupported/not-LoD; loaded="
            .. loadedState .. " loadOnDemand=" .. lodState .. "; check installation, then stop if inconclusive")
        return
    end
    -- Calling again is intentional for the already-loaded negative control.
    -- Never clear the previous value: its persistence is part of the observation.
    record("SNAPSHOT_ATTEMPT", "addon=" .. addon .. " wasLoaded=" .. tostring(wasLoaded)
        .. " expected=" .. expected)
    local ok, result, reason = pcall(fn, addon)
    record("SNAPSHOT_API", "pcall=" .. tostring(ok) .. " returned=" .. safe(result) .. " reason=" .. safe(reason))
    show(addon)
    local loaded = query("IsAddOnLoaded", addon)
    local row = payload(addon)
    if not ok or not result or not loaded or not row or type(row.marker) ~= "string" then
        record("SNAPSHOT_RESULT", "INCONCLUSIVE addon=" .. addon .. "; export and stop")
        return
    end
    local comparison = row.marker == expected and "MATCH" or "MISMATCH"
    record("SNAPSHOT_RESULT", comparison .. " addon=" .. addon
        .. " firstLoad=" .. tostring(not wasLoaded) .. " expected=" .. expected .. " actual=" .. safe(row.marker))
    -- MATCH is an observation, not proof the disk write occurred after login.
    record("SNAPSHOT_NOTE", "Correlate writer UTC/hash and session steps. No reload/relog allowed between write and load.")
end
