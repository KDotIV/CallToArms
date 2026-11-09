local _, A = ...
local function label(parent, x, y, width, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", x, y); text:SetWidth(width); text:SetJustifyH("LEFT")
    return text
end
local function surface(kind, name, w, h)
    local f = CreateFrame(kind, name, UIParent, "BackdropTemplate")
    f:SetSize(w, h); f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(.045,.055,.07,.97); f:SetBackdropBorderColor(.35,.5,.65)
    return f
end
function A.CountText(r)
    if r.test then return r.count .. " simulated participants (TEST)" end
    if r.countUnknown then return "Fight size unknown" end
    return r.count .. (r.estimated and " estimated participants" or " reported participants")
end
function A.ShowDetails(r)
    if not A.details then
        local f = surface("Frame", "CallToArmsDetails", 400, 310)
        A.details = f; f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
        f.title = label(f,16,-18,350,"GameFontNormalLarge")
        f.body = label(f,16,-50,365); f.body:SetSpacing(5)
        local close = CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT")
        local map = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        map:SetSize(160,24); map:SetPoint("BOTTOM",0,16); map:SetText("Show on map")
        map:SetScript("OnClick",function() A.OpenMap(f.record) end)
        table.insert(UISpecialFrames,"CallToArmsDetails")
    end
    local f = A.details; f.record = r
    f.title:SetText(A.DisplayTitle(r))
    f.body:SetText(A.LocationText(r) .. "\n" .. A.CountText(r)
        .. "\nReported by: " .. r.reporter
        .. "\nRuleset: " .. r.ruleset .. " | Layer: unknown"
        .. "\nAsk the reporter for a group invite to coordinate layers."
        .. (r.opposition ~= "" and "\nReported opposition: " .. r.opposition or "")
        .. "\n" .. r.note
        .. "\n" .. (r.expiresAt <= GetServerTime() and "Expired report" or "Expires in " .. (r.expiresAt - GetServerTime()) .. "s"))
    f:Show()
end
function A.ShowToast(r)
    if not A.toast then
        local f = surface("Button",nil,300,88)
        A.toast = f; f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-30,-180)
        f:SetFrameStrata("HIGH"); f:RegisterForClicks("LeftButtonUp","RightButtonUp")
        f.title=label(f,12,-10,275,"GameFontNormal")
        f.location=label(f,12,-31,275)
        f.hint=label(f,12,-53,275)
        f:SetScript("OnClick",function(self,button)
            if button == "LeftButton" and self.record then A.ShowDetails(self.record) end
            self:Hide()
        end)
    end
    local f=A.toast; f.record=r
    f.title:SetText(A.DisplayTitle(r))
    f.location:SetText(A.LocationText(r))
    f.hint:SetText(A.CountText(r) .. "\nClick: details   Right-click: dismiss")
    if A.toastTimer then A.toastTimer:Cancel() end
    f:Show(); A.toastTimer=C_Timer.NewTimer(10,function() f:Hide(); A.toastTimer=nil end)
end
