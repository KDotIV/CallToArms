local _, A = ...
local TEMPLATE = "CallToArmsMapPinTemplate"

local function drawSwords(owner)
    owner.strokes = {}
    if type(owner.CreateLine) ~= "function" then
        owner.fallback = owner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        owner.fallback:SetPoint("CENTER"); owner.fallback:SetText("X")
        return
    end
    local segments = {
        {5,5,19,19,3}, {20,20,24,24,2}, {17,23,23,17,2},
        {23,5,9,19,3}, {8,20,4,24,2}, {5,17,11,23,2},
    }
    -- Native solid-color strokes, not sampled file textures or atlases.
    for pass = 1, 2 do
        for _, s in ipairs(segments) do
            local line = owner:CreateLine(nil, "OVERLAY", nil, pass)
            line:SetStartPoint("TOPLEFT", owner, s[1], -s[2])
            line:SetEndPoint("TOPLEFT", owner, s[3], -s[4])
            line:SetThickness(s[5] + (pass == 1 and 2 or 0))
            line:SetColorTexture(pass == 1 and .02 or 1, pass == 1 and .02 or 1, pass == 1 and .02 or 1, 1)
            if pass == 2 then owner.strokes[#owner.strokes+1] = line end
            line:Show()
        end
    end
end

local function colorSwords(owner, c)
    for _, line in ipairs(owner.strokes) do line:SetColorTexture(c[1],c[2],c[3],1); line:Show() end
    if owner.fallback then owner.fallback:SetTextColor(c[1],c[2],c[3]); owner.fallback:Show() end
end

CallToArmsMapPinMixin = CreateFromMixins(MapCanvasPinMixin)
function CallToArmsMapPinMixin:OnLoad()
    -- WorldMap registers exploration and fog ABOVE DEFAULT. Use its POI layer
    -- so the artwork is drawn above terrain rather than merely remaining hittable.
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1, 1)
    self:SetAlphaLimits(1, 1, 1)
    drawSwords(self)
end
function CallToArmsMapPinMixin:OnAcquired(r)
    self.record = r
    local c = r.test and A.testColor or A.colors[r.kind]
    colorSwords(self, c)
    self:SetPosition(r.x, r.y)
end
function CallToArmsMapPinMixin:OnReleased()
    if self:IsMouseOver() then GameTooltip:Hide() end
    self.record = nil
    MapCanvasPinMixin.OnReleased(self)
end
function CallToArmsMapPinMixin:OnMouseEnter()
    if self.record then A.Tooltip(self, self.record) end
end
function CallToArmsMapPinMixin:OnMouseLeave() GameTooltip:Hide() end
function CallToArmsMapPinMixin:OnMouseClickAction(button)
    if button == "LeftButton" and self.record then A.ShowDetails(self.record) end
end

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
function Provider:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate(TEMPLATE) end
function Provider:RefreshAllData()
    self:RemoveAllData()
    local map = self:GetMap()
    if not map:IsShown() then return end
    for _, r in ipairs(A.List()) do
        if r.mapID == map:GetMapID() then map:AcquirePin(TEMPLATE, r) end
    end
end

function A.LocationText(r)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(r.mapID)
    return string.format("%s  /  %.1f, %.1f", info and info.name or ("Map " .. r.mapID), r.x * 100, r.y * 100)
end

function A.CurrentLocation()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
    local id = C_Map.GetBestMapForUnit("player")
    local pos = id and C_Map.GetPlayerMapPosition(id, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
    return {mapID = id, x = x, y = y}
end

function A.OpenMap(r)
    if InCombatLockdown() then A.Print("Open the map after combat to select this report."); return end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WorldMap") end
    if not WorldMapFrame or not WorldMapFrame.SetMapID then A.Print("World map unavailable."); return end
    WorldMapFrame:Show(); WorldMapFrame:SetMapID(r.mapID)
    A.AttachMap(); A.RefreshMap()
end

function A.RefreshMap()
    if A.mapProvider then A.mapProvider:RefreshAllData() end
end

function A.AttachMap()
    if A.mapAttached or not WorldMapFrame or not WorldMapFrame.AddDataProvider
        or not WorldMapFrame.AcquirePin or not WorldMapFrame.RemoveAllPinsByTemplate then return end
    A.mapProvider = CreateFromMixins(Provider)
    WorldMapFrame:AddDataProvider(A.mapProvider)
    A.mapAttached = true
    A.RefreshMap()
end

function A.MapDebug()
    A.AttachMap()
    local map = WorldMapFrame
    if not A.mapAttached then A.Print("Native map provider unavailable."); return end
    A.Print("Native map=" .. tostring(map:GetMapID()) .. " shown=" .. tostring(map:IsShown())
        .. " pins=" .. tostring(map:GetNumActivePinsByTemplate(TEMPLATE)))
    for pin in map:EnumeratePinsByTemplate(TEMPLATE) do
        A.Print("Pin level=" .. tostring(pin:GetFrameLevel()) .. " alpha=" .. tostring(pin:GetEffectiveAlpha())
            .. " layer=" .. tostring(pin:GetFrameLevelType())
            .. " renderer=native-lines strokes=" .. tostring(#pin.strokes)
            .. " size=" .. tostring(pin:GetWidth()) .. "x" .. tostring(pin:GetHeight()))
        break
    end
end

-- An independent reference at screen center separates map layering from drawing.
function A.PinCheck()
    if not A.pinCheck then
        local f = CreateFrame("Frame", "CallToArmsPinCheck", UIParent, "BackdropTemplate")
        f:SetSize(220,100); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        f:SetBackdropColor(.04,.04,.05,.98)
        local text = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        text:SetPoint("TOP",0,-12); text:SetText("Pin rendering check")
        local symbol = CreateFrame("Frame",nil,f)
        symbol:SetSize(28,28); symbol:SetPoint("CENTER",0,-5)
        drawSwords(symbol); colorSwords(symbol,A.testColor)
        local hint = f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        hint:SetPoint("BOTTOM",0,10); hint:SetText("/cta pincheck to close")
        f:Hide(); A.pinCheck = f
    end
    A.pinCheck:SetShown(not A.pinCheck:IsShown())
end
