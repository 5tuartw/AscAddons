-- Cleanup Helper for deleting collected vanity items

-- Use internal namespace
local addonName, AVH = ...

-- ========================================
-- Vanity Item Cleanup Helper Window
-- ========================================

function AVH:CreateCleanupHelper()
    local frame = CreateFrame("Frame", "AVH_CleanupHelper", UIParent)
    frame:SetSize(450, 400)  -- Larger for grid layout
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("Vanity Item Cleanup")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Instructions
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -10)
    instructions:SetWidth(320)
    instructions:SetJustifyH("CENTER")
    instructions:SetText("Delete collected vanity items from bags")
    
    -- Scan Now button
    local scanBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    scanBtn:SetSize(100, 30)
    scanBtn:SetPoint("TOP", instructions, "BOTTOM", 0, -10)
    scanBtn:SetText("Scan Now")
    scanBtn:SetNormalFontObject("GameFontNormal")
    scanBtn:SetHighlightFontObject("GameFontHighlight")
    scanBtn:SetScript("OnClick", function()
        AVH:ScanForCleanup()
    end)
    
    -- Container frame for grid layout
    local gridContainer = CreateFrame("Frame", "AVH_CleanupGridContainer", frame)
    gridContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -100)  -- Fixed offset from frame
    gridContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 15)
    gridContainer:Show()
    
    frame.gridContainer = gridContainer
    frame.itemButtons = {}
    
    AVH.cleanupHelper = frame
    
    return frame
end

-- Create a grid item button (icon with delete X overlay)
function AVH:CreateCleanupItemButton(parent, itemID, bag, slot, index, customTooltip)
    local btn = CreateFrame("Frame", "AVH_CleanupItem" .. index, parent)
    btn:SetSize(50, 50)
    btn:EnableMouse(true)
    
    -- Background
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Item icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(42, 42)
    btn.icon:SetPoint("CENTER", 0, 0)
    
    local itemTexture = GetItemIcon(itemID)
    if itemTexture then
        btn.icon:SetTexture(itemTexture)
    else
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    -- Delete X overlay (small red X in center)
    btn.deleteX = btn:CreateTexture(nil, "OVERLAY")
    btn.deleteX:SetSize(16, 16)  -- Small X
    btn.deleteX:SetPoint("CENTER", 0, 0)
    btn.deleteX:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")  -- Small red X
    btn.deleteX:SetAlpha(0.9)
    
    -- Click to delete
    btn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self:IsMouseEnabled() then
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                ClearCursor()
                PickupContainerItem(bag, slot)
                DeleteCursorItem()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Deleted: " .. itemLink)
                
                -- Grey out the button
                self:SetBackdropColor(0.3, 0.3, 0.3, 0.5)
                self:EnableMouse(false)
                self.icon:SetDesaturated(true)
                self.icon:SetAlpha(0.5)
                
                -- Refresh main window if it's open
                if AVH.mainFrame and AVH.mainFrame:IsShown() then
                    C_Timer.After(0.2, function()
                        AVH:RefreshItemList()
                    end)
                end
            end
        end
    end)
    
    -- Tooltip (use custom tooltip if provided)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local itemLink = select(2, GetItemInfo(itemID))
        if itemLink then
            GameTooltip:SetHyperlink(itemLink)
        end
        GameTooltip:AddLine(" ")
        if customTooltip then
            GameTooltip:AddLine(customTooltip, 1, 0.2, 0.2)  -- Red text, custom message
        else
            GameTooltip:AddLine("Click to delete", 1, 0.2, 0.2)  -- Red text, default
        end
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    btn.itemID = itemID
    btn:Show()
    return btn
end

function AVH:ShowCleanupHelper()
    if not AVH.cleanupHelper then
        AVH:CreateCleanupHelper()
    end
    
    AVH.cleanupHelper:Show()
    AVH:ScanForCleanup()
end

function AVH:ScanForCleanup()
    if not AVH.cleanupHelper then return end
    
    -- Clear existing buttons
    for _, btn in ipairs(AVH.cleanupHelper.itemButtons) do
        btn:Hide()
    end
    wipe(AVH.cleanupHelper.itemButtons)
    
    local itemIndex = 0
    local itemsPerRow = 7
    local iconSize = 50
    local spacing = 5
    
    -- Scan all bags for vanity items
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    local shouldShow = false
                    local customTooltip = nil
                    
                    -- Check if it's a special cleanup item (always show, even if not collected)
                    if AVH_CLEANUP_SPECIAL and AVH_CLEANUP_SPECIAL[itemID] then
                        -- Only show in bags, not equipped
                        local isEquipped = AVH:HasItemEquipped(itemID)
                        if not isEquipped then
                            shouldShow = true
                            customTooltip = AVH_CLEANUP_SPECIAL[itemID].tooltipWarning
                        end
                    else
                        -- Check if it's a collected vanity item
                        local isKnown = AVH:IsVanityItemKnown(itemID, bag, slot)
                        if isKnown then
                            shouldShow = true
                        end
                    end
                    
                    if shouldShow then
                        itemIndex = itemIndex + 1
                        local btn = AVH:CreateCleanupItemButton(
                            AVH.cleanupHelper.gridContainer,
                            itemID,
                            bag,
                            slot,
                            itemIndex,
                            customTooltip
                        )
                        
                        -- Position in grid (clear any existing points first)
                        btn:ClearAllPoints()
                        local row = math.floor((itemIndex - 1) / itemsPerRow)
                        local col = (itemIndex - 1) % itemsPerRow
                        local xOffset = col * (iconSize + spacing)
                        local yOffset = -row * (iconSize + spacing)
                        btn:SetPoint("TOPLEFT", AVH.cleanupHelper.gridContainer, "TOPLEFT", xOffset, yOffset)
                        
                        table.insert(AVH.cleanupHelper.itemButtons, btn)
                    end
                end
            end
        end
    end
end
