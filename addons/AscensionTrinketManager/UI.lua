-- Ascension Trinket Manager - UI
-- Trinket button interface

-- Create trinket button container
function ATM:CreateTrinketButtons()
    -- Main container
    local container = CreateFrame("Frame", "ATM_Container", UIParent)
    container:SetSize(80, 40)
    container:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    container:SetMovable(true)
    container:EnableMouse(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function(self, button)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        ATM.db.position = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)
    container:SetScale(ATM.db.scale)
    
    -- Background
    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()
    container.bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Drag overlay to capture Shift+drag anywhere
    container.dragOverlay = CreateFrame("Frame", nil, container)
    container.dragOverlay:SetAllPoints()
    container.dragOverlay:EnableMouse(false)  -- Only enable when Shift is held
    container.dragOverlay:SetFrameLevel(container:GetFrameLevel() + 10)  -- Above buttons
    
    -- Set up drag overlay to pass drag events to container
    container.dragOverlay:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            container:StartMoving()
        end
    end)
    container.dragOverlay:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            container:StopMovingOrSizing()
            -- Save position
            local point, _, relativePoint, xOfs, yOfs = container:GetPoint()
            ATM.db.position = {
                point = point,
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs
            }
            -- Disable overlay after dropping so buttons work again
            self:EnableMouse(false)
        end
    end)
    
    ATM.container = container
    ATM.trinketButtons = {}
    
    -- Create buttons for each trinket slot
    for i, slotID in ipairs(ATM.TRINKET_SLOTS) do
        local btn = ATM:CreateTrinketButton(slotID, i)
        ATM.trinketButtons[i] = btn
    end
    
    ATM:UpdateLayout()
    ATM:UpdateTrinketButtons()
    
    container:Show()
end

-- Create individual trinket button
function ATM:CreateTrinketButton(slotID, index)
    -- Use SecureActionButton to avoid taint
    local btn = CreateFrame("Button", "ATM_TrinketButton" .. index, ATM.container, "SecureActionButtonTemplate, ActionButtonTemplate")
    btn:SetSize(36, 36)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Set secure attributes for left-click (use trinket)
    btn:SetAttribute("type1", "item")
    btn:SetAttribute("item1", slotID)  -- Slot ID for trinket
    
    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    
    -- Border
    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetAllPoints()
    btn.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    btn.border:SetBlendMode("ADD")
    btn.border:Hide()
    
    -- Cooldown
    btn.cooldown = CreateFrame("Cooldown", "ATM_TrinketCooldown" .. index, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    
    -- Empty slot texture
    btn.emptyTexture = btn:CreateTexture(nil, "BACKGROUND")
    btn.emptyTexture:SetAllPoints()
    btn.emptyTexture:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket")
    btn.emptyTexture:SetDesaturated(true)
    btn.emptyTexture:SetAlpha(0.3)
    
    -- Dropdown container (hidden by default)
    btn.dropdown = CreateFrame("Frame", nil, btn)
    btn.dropdown:SetSize(36, 100)
    btn.dropdown:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    btn.dropdown:SetFrameStrata("DIALOG")
    btn.dropdown:Hide()
    
    btn.dropdown.bg = btn.dropdown:CreateTexture(nil, "BACKGROUND")
    btn.dropdown.bg:SetAllPoints()
    btn.dropdown.bg:SetColorTexture(0, 0, 0, 0.9)
    
    btn.dropdown.buttons = {}
    
    -- Right-click handler (can't be secure, but doesn't affect combat)
    btn:SetScript("PreClick", function(self, button)
        if button == "RightButton" then
            -- Toggle dropdown
            ATM:ToggleDropdown(self)
        elseif button == "LeftButton" and IsAltKeyDown() then
            -- Alt+click to manually equip carrot (will auto-restore on dismount)
            ATM:ManualCarrotSwap(self.slotID)
        end
    end)
    
    -- Enable drag overlay when Shift is held over this button
    btn:SetScript("OnUpdate", function(self)
        if IsShiftKeyDown() then
            ATM.container.dragOverlay:EnableMouse(true)
        else
            ATM.container.dragOverlay:EnableMouse(false)
        end
    end)
    
    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", slotID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Left-click:|r Use trinket", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Alt+Left-click:|r Swap with Carrot", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Right-click:|r Swap trinket", 1, 1, 1)
        GameTooltip:AddLine("|cff888888Shift+drag container to move|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    btn.slotID = slotID
    btn.index = index
    
    btn:Show()
    btn.emptyTexture:Show()
    
    return btn
end

-- Update trinket button appearance
function ATM:UpdateTrinketButtons()
    if not ATM.trinketButtons then
        return
    end
    
    for i, btn in ipairs(ATM.trinketButtons) do
        local itemLink = GetInventoryItemLink("player", btn.slotID)
        
        if itemLink then
            -- Has trinket equipped
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            local texture = GetItemIcon(itemID)
            
            btn.icon:SetTexture(texture)
            btn.icon:Show()
            btn.emptyTexture:Hide()
            
            -- Check if it has use effect
            local hasUse = ATM:TrinketHasUseEffect(btn.slotID)
            if hasUse then
                btn.icon:SetDesaturated(false)
                btn.icon:SetAlpha(1.0)
            else
                btn.icon:SetDesaturated(true)
                btn.icon:SetAlpha(0.6)
            end
            
            -- Update cooldown
            local start, duration, enable = GetInventoryItemCooldown("player", btn.slotID)
            if start and duration and duration > 1.5 then
                btn.cooldown:SetCooldown(start, duration)
            else
                btn.cooldown:Hide()
            end
        else
            -- Empty slot
            btn.icon:Hide()
            btn.emptyTexture:Show()
            btn.cooldown:Hide()
        end
    end
end

-- Toggle trinket swap dropdown
function ATM:ToggleDropdown(btn)
    -- Hide other dropdowns
    for _, otherBtn in ipairs(ATM.trinketButtons) do
        if otherBtn ~= btn and otherBtn.dropdown:IsShown() then
            otherBtn.dropdown:Hide()
        end
    end
    
    if btn.dropdown:IsShown() then
        btn.dropdown:Hide()
    else
        ATM:PopulateDropdown(btn)
        btn.dropdown:Show()
    end
end

-- Populate dropdown with bag trinkets
function ATM:PopulateDropdown(btn)
    local trinkets = ATM:GetBagTrinkets()
    
    -- Clear existing buttons
    for _, dropBtn in ipairs(btn.dropdown.buttons) do
        dropBtn:Hide()
    end
    
    -- Create/update buttons for each trinket
    local yOffset = -2
    for i, trinket in ipairs(trinkets) do
        local dropBtn = btn.dropdown.buttons[i]
        
        if not dropBtn then
            -- Create new button
            dropBtn = CreateFrame("Button", nil, btn.dropdown)
            dropBtn:SetSize(32, 32)
            dropBtn:RegisterForClicks("LeftButtonUp")
            
            dropBtn.icon = dropBtn:CreateTexture(nil, "ARTWORK")
            dropBtn.icon:SetAllPoints()
            dropBtn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            
            dropBtn.border = dropBtn:CreateTexture(nil, "OVERLAY")
            dropBtn.border:SetAllPoints()
            dropBtn.border:SetTexture("Interface\\Buttons\\UI-Slot-Background")
            dropBtn.border:SetBlendMode("ADD")
            
            btn.dropdown.buttons[i] = dropBtn
        end
        
        -- Set icon
        local texture = GetItemIcon(trinket.itemID)
        dropBtn.icon:SetTexture(texture)
        
        -- Position
        dropBtn:ClearAllPoints()
        dropBtn:SetPoint("TOP", btn.dropdown, "TOP", 0, yOffset)
        yOffset = yOffset - 34
        
        -- Click handler
        dropBtn:SetScript("OnClick", function()
            ATM:EquipTrinketFromBag(trinket.bag, trinket.slot, btn.slotID)
            btn.dropdown:Hide()
        end)
        
        -- Tooltip
        dropBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(trinket.itemLink)
            GameTooltip:Show()
        end)
        
        dropBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        dropBtn:Show()
    end
    
    -- Adjust dropdown size
    local height = math.max(40, #trinkets * 34 + 4)
    btn.dropdown:SetHeight(height)
    
    -- Update dropdown position based on orientation and expand direction
    ATM:UpdateDropdownPosition(btn)
end

-- Update dropdown position based on settings
function ATM:UpdateDropdownPosition(btn)
    btn.dropdown:ClearAllPoints()
    
    local expandDir = ATM.db.orientation == "horizontal" and ATM.db.expandDirectionHorizontal or ATM.db.expandDirectionVertical
    
    if ATM.db.orientation == "horizontal" then
        if expandDir == "down" then
            btn.dropdown:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        else  -- up
            btn.dropdown:SetPoint("BOTTOM", btn, "TOP", 0, 2)
        end
    else  -- vertical
        if expandDir == "right" then
            btn.dropdown:SetPoint("LEFT", btn, "RIGHT", 2, 0)
        else  -- left
            btn.dropdown:SetPoint("RIGHT", btn, "LEFT", -2, 0)
        end
    end
end

-- Update layout based on orientation
function ATM:UpdateLayout()
    if not ATM.trinketButtons then
        return
    end
    
    for i, btn in ipairs(ATM.trinketButtons) do
        btn:ClearAllPoints()
        
        if ATM.db.orientation == "horizontal" then
            -- Horizontal layout
            local xOffset = (i - 1) * 38
            btn:SetPoint("LEFT", ATM.container, "LEFT", xOffset + 2, 0)
            ATM.container:SetSize(80, 40)
        else
            -- Vertical layout
            local yOffset = -(i - 1) * 38
            btn:SetPoint("TOP", ATM.container, "TOP", 0, yOffset - 2)
            ATM.container:SetSize(40, 80)
        end
    end
    
    -- Update container background
    ATM.container.bg:SetAllPoints()
end
