local _, A = ...
local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, v = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(v)) then return end
    return v
end
function A.CurrentScope()
    local rules = Enum and Enum.GameRule
    local fn = C_GameRules and C_GameRules.IsGameRuleActive
    if not rules or not rules.HardcoreRuleset or not rules.RPRuleset or not rules.PvPRuleset then return end
    local hc, rp, pvp = read(fn, rules.HardcoreRuleset), read(fn, rules.RPRuleset), read(fn, rules.PvPRuleset)
    local region = read(GetCurrentRegion)
    if type(hc) ~= "boolean" or type(rp) ~= "boolean" or type(pvp) ~= "boolean"
        or type(region) ~= "number" or region % 1 ~= 0 or region < 1 or region > 99 then return end
    if hc then return "hardcore", region end
    return rp and (pvp and "rppvp" or "rp") or (pvp and "pvp" or "normal"), region
end
function A.RefreshScope()
    local ruleset, region = A.CurrentScope()
    local changed = A.scopeRuleset ~= ruleset or A.scopeRegion ~= region
    A.scopeRuleset, A.scopeRegion = ruleset, region
    if ruleset and A.db then A.db.ruleset = ruleset end
    if changed then
        A.records = {}
        if A.toast then A.toast:Hide() end
        if A.details then A.details:Hide() end
        if A.Changed then A.Changed() end
    end
    return ruleset ~= nil
end
