local _, A = ...
local pins = {}

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
    local map = WorldMapFrame
    if not A.mapAttached or not map:IsShown() then return end
    local canvas = map:GetCanvas()
    local w, h, index = canvas:GetWidth(), canvas:GetHeight(), 0
    for _, r in ipairs(A.List()) do
        if r.mapID == map:GetMapID() then
            index = index + 1
            local pin = pins[index]
            if not pin then
                pin = CreateFrame("Button", nil, canvas)
                pin:SetSize(28, 28); pin:SetFrameLevel(canvas:GetFrameLevel() + 20)
                local icon = pin:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints()
                icon:SetTexture("Interface\\Icons\\Ability_DualWield")
                pin.icon = icon
                pin:SetScript("OnEnter", function(self) A.Tooltip(self, self.record) end)
                pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
                pin:SetScript("OnClick", function(self) if self.record then A.ShowDetails(self.record) end end)
                pins[index] = pin
            end
            local c = A.colors[r.kind]
            pin.record = r; pin.icon:SetVertexColor(c[1], c[2], c[3])
            pin:ClearAllPoints(); pin:SetPoint("CENTER", canvas, "TOPLEFT", r.x * w, -r.y * h)
            pin:Show()
        end
    end
    for i = index + 1, #pins do pins[i].record = nil; pins[i]:Hide() end
end

function A.AttachMap()
    if A.mapAttached or not WorldMapFrame or not WorldMapFrame.GetCanvas
        or not WorldMapFrame.GetMapID or not WorldMapFrame.OnMapChanged then return end
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end
    A.mapAttached = true
    WorldMapFrame:HookScript("OnShow", A.RefreshMap)
    canvas:HookScript("OnSizeChanged", A.RefreshMap)
    hooksecurefunc(WorldMapFrame, "OnMapChanged", A.RefreshMap)
end
