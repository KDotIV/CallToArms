local _, A = ...
local colors = { heat = {1, .42, .20}, defense = {.35, .75, 1}, raid = {1, .76, .28}, report = {.35, .75, 1} }
A.colors = colors
A.testColor = {.8, .45, 1}

local function label(parent, size, x, y, value)
    local f = parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
    f:SetPoint("TOPLEFT", x, y); f:SetText(value or ""); f:SetJustifyH("LEFT")
    return f
end
local function button(parent, title, w, x, y, action)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 24); b:SetPoint("TOPLEFT", x, y); b:SetText(title)
    b:SetScript("OnClick", action)
    return b
end
local function edit(parent, title, x, y, width, limit)
    label(parent, "GameFontNormalSmall", x, y, title)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 24); e:SetPoint("TOPLEFT", x + 5, y - 18)
    e:SetAutoFocus(false); e:SetMaxLetters(limit)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

function A.Tooltip(owner, r)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(A.DisplayTitle(r), 1, .82, .35)
    GameTooltip:AddLine(A.LocationText(r), 1, 1, 1)
    GameTooltip:AddLine(A.CountText(r), 1, 1, 1)
    if r.reporter ~= "" then GameTooltip:AddLine("Reported by: " .. r.reporter, .7, .7, .7) end
    if r.opposition ~= "" then GameTooltip:AddLine("Reported opposition: " .. r.opposition, 1, .6, .5, true) end
    if r.note ~= "" then GameTooltip:AddLine(r.note, .8, .8, .8, true) end
    GameTooltip:AddLine("Expires in " .. math.max(0, r.expiresAt - GetServerTime()) .. "s", .6, .6, .6)
    GameTooltip:Show()
end

function A.BuildUI()
    if A.panel then return end
    local p = CreateFrame("Frame", "CallToArmsPanel", UIParent, "BackdropTemplate")
    A.panel = p
    p:SetSize(460, 520); p:SetPoint("CENTER"); p:SetFrameStrata("DIALOG")
    p:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    p:SetBackdropColor(.045, .055, .07, .97); p:SetBackdropBorderColor(.3, .34, .39)
    p:SetClampedToScreen(true); p:SetMovable(true); p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving); p:SetScript("OnDragStop", p.StopMovingOrSizing)
    table.insert(UISpecialFrames, "CallToArmsPanel")
    label(p, "GameFontNormalLarge", 20, -18, "CALL TO ARMS")
    p.status = label(p, "GameFontHighlightSmall", 20, -44)
    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    A.filter, A.page = "all", 1
    for i, entry in ipairs({{"All", "all"}, {"Heat", "heat"}, {"Defense", "defense"}, {"Raids", "raid"}}) do
        local kind = entry[2]
        button(p, entry[1], 98, 20 + (i - 1) * 106, -68, function()
            A.filter, A.page = kind, 1; A.RefreshUI()
        end)
    end
    p.rows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, p)
        row:SetSize(420, 62); row:SetPoint("TOPLEFT", 20, -104 - (i - 1) * 66)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(3, 50); row.bar:SetPoint("LEFT")
        row.title = label(row, "GameFontNormal", 13, -6); row.title:SetWidth(395)
        row.where = label(row, "GameFontHighlightSmall", 13, -26); row.where:SetWidth(395)
        row.meta = label(row, "GameFontDisableSmall", 13, -43)
        row:SetScript("OnClick", function(self) if self.record then A.ShowDetails(self.record) end end)
        row:SetScript("OnEnter", function(self) if self.record then A.Tooltip(self, self.record) end end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.rows[i] = row
    end
    p.empty = label(p, "GameFontHighlight", 35, -180, "No active reports.\n\nUse /cta demo to preview the interface.")
    p.empty:SetWidth(390)
    p.page = label(p, "GameFontHighlightSmall", 170, -444)
    button(p, "Previous", 95, 20, -436, function() A.page = math.max(1, A.page - 1); A.RefreshUI() end)
    button(p, "Next", 95, 345, -436, function() A.page = A.page + 1; A.RefreshUI() end)
    button(p, "Report PvP (/cta report)", 210, 20, -478, function() A.RunReport() end)
    p.mute = button(p, "", 130, 310, -478, function()
        A.db.muted = not A.db.muted
        if A.db.muted and A.toast then A.toast:Hide() end
        A.RefreshUI()
    end)
    p:SetScript("OnShow", function() A.RefreshUI() end)
    p:Hide()
end

function A.RefreshUI()
    local p = A.panel
    if not p or not p:IsShown() then return end
    local list = A.List(A.filter)
    local pages = math.max(1, math.ceil(#list / 5))
    A.page = math.min(A.page, pages)
    p.status:SetText((UnitFactionGroup("player") or "Unknown") .. " | " .. (A.scopeRuleset or "Unknown ruleset") .. " | "
        .. (A.testMode and "TEST MODE | " or "") .. (A.guildReady and A.scopeRuleset and "Guild reports" or "Transport unavailable"))
    p.page:SetText(A.filter .. "  /  " .. A.page .. " of " .. pages)
    p.mute:SetText(A.db.muted and "Alerts: muted" or "Alerts: on")
    p.empty:SetShown(#list == 0)
    for i, row in ipairs(p.rows) do
        local r = list[(A.page - 1) * 5 + i]
        row.record = r; row:SetShown(r ~= nil)
        if r then
            local c = r.test and A.testColor or colors[r.kind]; row.bar:SetColorTexture(c[1], c[2], c[3], 1)
            row.title:SetText(A.DisplayTitle(r))
            row.where:SetText(A.LocationText(r))
            row.meta:SetText(r.kind:upper() .. "  |  " .. A.CountText(r) .. "  |  " .. math.ceil((r.expiresAt - GetServerTime()) / 60) .. "m left")
        end
    end
end

function A.ShowComposer()
    if not A.composer then
        local f = CreateFrame("Frame", "CallToArmsComposer", UIParent, "BackdropTemplate")
        A.composer = f
        f:SetSize(410, 330); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        f:SetBackdropColor(.06, .07, .09, 1); f:SetBackdropBorderColor(.35, .5, .65)
        f:EnableMouse(true); table.insert(UISpecialFrames, "CallToArmsComposer")
        label(f, "GameFontNormalLarge", 20, -20, "Request reinforcements")
        f.location = label(f, "GameFontHighlightSmall", 20, -50)
        f.count = edit(f, "Estimated participants (4+)", 20, -80, 150, 4)
        f.enemy = edit(f, "Reported opposing guild / group (optional)", 20, -135, 350, 64)
        f.note = edit(f, "Situation (optional)", 20, -190, 350, 160)
        f.feedback = label(f, "GameFontHighlightSmall", 20, -245); f.feedback:SetWidth(370)
        button(f, "Submit", 170, 20, -287, function()
            local ok, message = A.SubmitDefense(f.count:GetText(), f.enemy:GetText(), f.note:GetText())
            f.feedback:SetText(message)
            if ok then f:Hide() end
        end)
        button(f, "Cancel", 170, 215, -287, function() f:Hide() end)
    end
    local f = A.composer
    f.count:SetText("4"); f.enemy:SetText(""); f.note:SetText("")
    local loc = A.CurrentLocation()
    f.location:SetText(loc and A.LocationText(loc) or "Your current location is unavailable.")
    f.feedback:SetText(A.adapter and "Sent to your faction only." or "Preview only: no alert will be broadcast.")
    f:Show()
end
