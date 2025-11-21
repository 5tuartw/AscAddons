-- ME Stats: Core addon logic
local addonName = "MEStats"
local ME = {}
_G[addonName] = ME

-- Saved variables default structure
local defaults = {
    minimap = {
        hide = false,
        minimapPos = 220,
        radius = 80,
    },
    percentMode = false,
}

-- Initialize addon
function ME:OnLoad()
    -- Initialize saved variables
    if not MEStatsDB then
        MEStatsDB = {}
    end
    
    -- Merge defaults
    for k, v in pairs(defaults) do
        if MEStatsDB[k] == nil then
            if type(v) == "table" then
                MEStatsDB[k] = {}
                for k2, v2 in pairs(v) do
                    MEStatsDB[k][k2] = v2
                end
            else
                MEStatsDB[k] = v
            end
        end
    end
    
    self.db = MEStatsDB
    
    -- Create minimap button
    self:CreateMinimapButton()
end

-- Create minimap button using native API (no library dependencies)
function ME:CreateMinimapButton()
    local button = CreateFrame("Button", "MEStatsMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(32, 32)
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Icon texture
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    button.icon = icon
    
    -- Border overlay
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Click handler
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            ME:ToggleFrame()
        elseif btn == "RightButton" then
            -- Future: Show options menu
            print("Mystic Encyclopedia: Right-click options coming soon!")
        end
    end)
    
    -- Drag to move around minimap
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isMoving = true
    end)
    
    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isMoving = false
    end)
    
    -- Update position while dragging
    button:SetScript("OnUpdate", function(self)
        if self.isMoving then
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            
            local angle = math.atan2(py - my, px - mx)
            local angleDegrees = math.deg(angle)
            ME.db.minimap.minimapPos = angleDegrees
            ME:UpdateMinimapButtonPosition()
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("ME Stats", 1, 1, 1)
        
        -- Add current stats if available
        if ME.snapshot and ME.snapshot.byClass then
            local _, playerClass = UnitClass("player")
            
            -- All classes stats
            local allStats = ME.snapshot.byClass["ALL"]
            if allStats and allStats.total > 0 then
                local pct = (allStats.known / allStats.total) * 100
                local r, g, b = ME:ColorForPercent(pct)
                GameTooltip:AddLine(string.format("All: %d/%d (%.0f%%)", 
                    allStats.known, allStats.total, pct), r, g, b)
            end
            
            -- Current class stats
            if playerClass and ME.snapshot.byClass[playerClass] then
                local classStats = ME.snapshot.byClass[playerClass]
                if classStats.total > 0 then
                    local pct = (classStats.known / classStats.total) * 100
                    local r, g, b = ME:ColorForPercent(pct)
                    local className = (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[playerClass])
                                   or (_G.LOCALIZED_CLASS_NAMES_FEMALE and _G.LOCALIZED_CLASS_NAMES_FEMALE[playerClass])
                                   or playerClass
                    GameTooltip:AddLine(string.format("%s: %d/%d (%.0f%%)", 
                        className, classStats.known, classStats.total, pct), r, g, b)
                end
            end
            
            GameTooltip:AddLine(" ")  -- Blank line separator
        end
        
        GameTooltip:AddLine("Left-click: Toggle statistics panel", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: Move this button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
    
    -- Hide if configured
    if self.db.minimap.hide then
        button:Hide()
    end
end

-- Update minimap button position based on angle
function ME:UpdateMinimapButtonPosition()
    local button = self.minimapButton
    if not button then return end
    
    local angle = math.rad(self.db.minimap.minimapPos or 220)
    local x = math.cos(angle) * (self.db.minimap.radius or 80)
    local y = math.sin(angle) * (self.db.minimap.radius or 80)
    
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Toggle main frame
function ME:ToggleFrame()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        -- Auto-refresh when opening
        self:RefreshMysticData()
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ME:OnLoad()
    elseif event == "PLAYER_LOGIN" then
        -- Could do additional initialization here
    end
end)
