local _, A = ...
local PREFIX = "CTA_REPORT1"
local seq, rates, budget, refill = 0, {}, 12, 0
local function secret(v) return issecretvalue and issecretvalue(v) end
local function integer(s, lo, hi)
    if type(s) ~= "string" or not s:match("^%d+$") then return end
    local n = tonumber(s)
    if n and n >= lo and n <= hi then return n end
end
local function identity(sender)
    if not sender:find("-", 1, true) then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
        sender = sender .. "-" .. realm
    end
    return sender
end
local function key(sender)
    -- Compact sender namespace; sender comes from the event, never the payload.
    local a, b = 5381, 17
    for i = 1, #sender do
        a = (a * 33 + sender:byte(i)) % 4294967296
        b = (b * 31 + sender:byte(i)) % 4294967296
    end
    return string.format("%.0f-%.0f", a, b)
end
function A.ReportNote(test, observed, unknown, synthetic)
    if test then
        return "Simulated PvP: " .. observed .. " observed players incl. reporter; " .. synthetic
            .. " synthetic. 100yd sample incomplete; " .. unknown .. " unknown range. Not real combat evidence."
    end
    return "Observer report; fight size unknown. Snapshot: " .. observed
        .. " flagged players within 100yd; " .. unknown .. " unknown range. Coverage incomplete."
end

function A.EncodeGuildReport(r)
    if r.kind ~= "report" or r.demo then return nil, "Guild transport currently supports /cta report only." end
    seq = seq + 1
    local nonce = string.format("%d-%d-%d", GetServerTime(), math.floor(GetTime() * 1000) % 1000000000, seq)
    local packet = table.concat({"1", r.test and "T" or "R", nonce, tostring(r.updatedAt),
        tostring(r.mapID), tostring(math.floor(r.x * 10000 + .5)), tostring(math.floor(r.y * 10000 + .5)),
        r.faction == "Horde" and "H" or "A", r.ruleset,
        tostring(r.observedCount or 0), tostring(r.unknownRange or 0), tostring(r.syntheticCount or 0),
        tostring(A.scopeRegion)}, "\t")
    if #packet > 255 then return nil, "Report exceeds message limit." end
    return packet
end

function A.DecodeGuildReport(packet, sender)
    if type(packet) ~= "string" or #packet > 255 or type(sender) ~= "string" or #sender == 0 or #sender > 128 then return end
    local f = {}
    for value in (packet .. "\t"):gmatch("(.-)\t") do f[#f+1] = value; if #f > 13 then return end end
    if #f ~= 13 or f[1] ~= "1" or (f[2] ~= "T" and f[2] ~= "R") then return end
    if #f[3] > 40 or not f[3]:match("^%d+%-%d+%-%d+$") then return end
    local now = GetServerTime()
    local time = integer(f[4], math.max(0, now - 299), now + 30)
    local map = integer(f[5], 1, 100000)
    local x, y = integer(f[6], 0, 10000), integer(f[7], 0, 10000)
    local observed, unknown, synthetic = integer(f[10], 0, 64), integer(f[11], 0, 128), integer(f[12], 0, 4)
    if not time or not map or not x or not y or not observed or not unknown or not synthetic then return end
    if f[8] ~= "H" and f[8] ~= "A" then return end
    if f[9] ~= "pvp" and f[9] ~= "normal" and f[9] ~= "rp" and f[9] ~= "rppvp" and f[9] ~= "hardcore" then return end
    local region = integer(f[13], 1, 99)
    if not region or region ~= A.scopeRegion or f[9] ~= A.scopeRuleset then return end
    local test = f[2] == "T"
    if test and synthetic ~= math.max(0, 4 - observed) then return end
    if not test and synthetic ~= 0 then return end
    sender = identity(sender)
    return {
        version=1, id="guild:" .. key(sender) .. ":" .. f[3], kind="report",
        faction=f[8] == "H" and "Horde" or "Alliance", ruleset=f[9],
        mapID=map, x=x/10000, y=y/10000, updatedAt=time, expiresAt=time+300,
        reporter=sender, title=test and "Simulated PvP report" or "PvP activity reported",
        test=test, count=test and (observed+synthetic) or 0, countUnknown=not test,
        observedCount=observed, unknownRange=unknown, syntheticCount=synthetic,
        note=A.ReportNote(test, observed, unknown, synthetic),
    }
end

function A.GuildSend(r)
    if not A.RefreshScope() then return false, "Ruleset/region unavailable; network reporting disabled." end
    if not IsInGuild() then return false, "Join a guild to send reports." end
    if not A.guildReady then return false, "Guild messaging is unavailable; use /cta status." end
    local packet, reason = A.EncodeGuildReport(r)
    if not packet then return false, reason end
    local sender = UnitName("player")
    if secret(sender) or type(sender) ~= "string" then return false, "Character identity unavailable." end
    local decoded = A.DecodeGuildReport(packet, sender)
    if not decoded or not A.Validate(decoded, GetServerTime(), UnitFactionGroup("player"), A.db.ruleset) then
        return false, "Report could not be encoded safely."
    end
    if decoded.test and not A.testMode then return false, "Enable test mode first." end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, packet, "GUILD")
    local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
    if not ok or secret(result) or (result ~= success and result ~= true) then
        return false, "Guild send rejected or unconfirmed. No automatic retry."
    end
    -- Show the accepted submission locally. The same wire ID deduplicates self echo.
    local displayed = pcall(A.Receive, decoded)
    if not displayed then A.Print("Guild send accepted, but the local display failed. Check Lua errors before retrying.") end
    return true, "Guild send accepted; check your guildmate's client for delivery."
end

function A.OnGuildMessage(prefix, packet, route, sender)
    if secret(prefix) or secret(packet) or secret(route) or secret(sender) then return end
    if prefix ~= PREFIX or route ~= "GUILD" or not A.db or not IsInGuild() then return end
    if not A.RefreshScope() then return end
    local now = GetTime()
    budget = math.min(12, budget + math.max(0, now - refill)); refill = now
    if budget < 1 then return end
    budget = budget - 1
    local r = A.DecodeGuildReport(packet, sender)
    if not r or (r.test and not A.testMode) then return end
    if not A.Validate(r, GetServerTime(), UnitFactionGroup("player"), A.db.ruleset) then return end
    if A.records[r.id] then return end
    local rateKey = identity(sender) .. (r.test and ":test" or ":real")
    if rates[rateKey] and now - rates[rateKey] < (r.test and 10 or 120) then return end
    local size = 0
    for k, time in pairs(rates) do
        if now - time >= 120 then rates[k] = nil else size = size + 1 end
    end
    if size >= 128 and not rates[rateKey] then return end
    local accepted = A.Receive(r)
    if accepted then
        rates[rateKey] = now
        A.Print((r.test and "[TEST] " or "") .. "Guild report received from " .. A.CleanText(sender,64) .. ".")
    end
end

function A.InitGuildTransport()
    A.adapter = A.GuildSend
    local ci = C_ChatInfo
    if not ci or not ci.RegisterAddonMessagePrefix or not ci.SendAddonMessage then return end
    local ok, result = pcall(ci.RegisterAddonMessagePrefix, PREFIX)
    local success = Enum and Enum.RegisterAddonMessagePrefixResult and Enum.RegisterAddonMessagePrefixResult.Success or 0
    local duplicate = Enum and Enum.RegisterAddonMessagePrefixResult and Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
    A.guildReady = ok and not secret(result) and (result == true or result == success or result == duplicate)
    if not A.guildReady then return end
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, ...) A.OnGuildMessage(...) end)
end
