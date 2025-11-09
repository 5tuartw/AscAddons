-- Ascension Vanity Helper - UI
-- Main window and interface

-- Create the main window
function AVH:CreateMainWindow()
    -- Main frame
    local frame = CreateFrame("Frame", "AVH_MainFrame", UIParent)
    frame:SetSize(400, 450)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        AVH.db.windowPosition = { point, "UIParent", relativePoint, xOfs, yOfs }
    end)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    
    -- Restore saved position
    if AVH.db.windowPosition then
        frame:ClearAllPoints()
        frame:SetPoint(unpack(AVH.db.windowPosition))
    end
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cff00ff00Ascension Vanity Helper|r")
    
    -- Set dropdown
    local setDropdown = CreateFrame("Frame", "AVH_SetDropdown", frame, "UIDropDownMenuTemplate")
    setDropdown:SetPoint("TOP", title, "BOTTOM", 0, -5)
    UIDropDownMenu_SetWidth(setDropdown, 200)
    UIDropDownMenu_SetText(setDropdown, AVH.db.currentSet or "Starter Kit")
    
    -- Dropdown initialize function
    UIDropDownMenu_Initialize(setDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- Add "Starter Kit" (default)
        info.text = "Starter Kit"
        info.func = function()
            AVH.db.currentSet = "Starter Kit"
            UIDropDownMenu_SetText(setDropdown, "Starter Kit")
            AVH:RefreshItemList()
        end
        info.checked = (AVH.db.currentSet == "Starter Kit")
        UIDropDownMenu_AddButton(info)
        
        -- Add all available sets (user + built-in)
        local allSets = AVH:GetAllAvailableSets()
        for _, setName in ipairs(allSets) do
            if setName ~= (AVH.db.currentSet or "Starter Kit") then
                info = UIDropDownMenu_CreateInfo()
                info.text = setName
                info.func = function()
                    AVH.db.currentSet = setName
                    UIDropDownMenu_SetText(setDropdown, setName)
                    AVH:RefreshItemList()
                end
                info.checked = false
                UIDropDownMenu_AddButton(info)
            end
        end
        
        -- Separator
        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.disabled = true
        UIDropDownMenu_AddButton(info)
        
        -- Create new set option
        info = UIDropDownMenu_CreateInfo()
        info.text = "|cff00ff00+ Create New Set|r"
        info.func = function()
            AVH:ShowCreateSetDialog()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)
        
        -- Delete current set option (if not default)
        if AVH.db.currentSet and AVH.db.currentSet ~= "Starter Kit" then
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cffff0000Delete Current Set|r"
            info.func = function()
                AVH:DeleteSet(AVH.db.currentSet)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    frame.setDropdown = setDropdown
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Instructions text
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", setDropdown, "BOTTOM", 0, -5)
    instructions:SetText("Click items to summon them from your collection")
    instructions:SetTextColor(0.7, 0.7, 0.7)
    
    -- Add Item button
    local addItemBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    addItemBtn:SetSize(120, 30)
    addItemBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 15)
    addItemBtn:SetText("+ Add Item")
    addItemBtn:SetNormalFontObject("GameFontNormal")
    addItemBtn:SetHighlightFontObject("GameFontHighlight")
    addItemBtn:SetScript("OnClick", function()
        AVH:ShowAddItemDialog()
    end)
    
    -- Deliver Set button (summons items sequentially with delay)
    local summonAllBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    summonAllBtn:SetSize(100, 30)
    summonAllBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
    summonAllBtn:SetText("Deliver Set")
    summonAllBtn:SetNormalFontObject("GameFontNormal")
    summonAllBtn:SetHighlightFontObject("GameFontHighlight")
    summonAllBtn:SetScript("OnClick", function()
        AVH:SummonAll()
        AVH:RefreshItemList()
    end)
    
    -- Cleanup button (delete collected vanity items)
    local cleanupBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    cleanupBtn:SetSize(100, 30)
    cleanupBtn:SetPoint("RIGHT", summonAllBtn, "LEFT", -5, 0)
    cleanupBtn:SetText("Cleanup")
    cleanupBtn:SetNormalFontObject("GameFontNormal")
    cleanupBtn:SetHighlightFontObject("GameFontHighlight")
    cleanupBtn:SetScript("OnClick", function()
        AVH:ShowCleanupHelper()
    end)
    
    -- Scroll frame for items
    local scrollFrame = CreateFrame("ScrollFrame", "AVH_ScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -95)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -39, 55)
    
    -- Content frame inside scroll
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(350, 1) -- Height will be set dynamically
    scrollFrame:SetScrollChild(content)
    
    -- Store references
    frame.scrollFrame = scrollFrame
    frame.content = content
    frame.itemButtons = {}
    
    AVH.mainFrame = frame
    
    -- Populate the list
    AVH:RefreshItemList()
    
    -- Add to special frames for ESC key
    tinsert(UISpecialFrames, "AVH_MainFrame")
    
    return frame
end

-- Refresh the item list
function AVH:RefreshItemList()
    if not AVH.mainFrame then return end
    
    local content = AVH.mainFrame.content
    local buttons = AVH.mainFrame.itemButtons
    
    -- Clear existing buttons
    for _, btn in ipairs(buttons) do
        btn:Hide()
    end
    wipe(buttons)
    
    local yOffset = -10
    local buttonHeight = 50
    
    -- Get items from current set
    local items = AVH:GetCurrentSetItems()
    
    -- Create/update buttons for each item
    for i, itemData in ipairs(items) do
        local btn = AVH:CreateItemButton(content, itemData, i)
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        btn:Show()
        
        table.insert(buttons, btn)
        yOffset = yOffset - buttonHeight - 5
    end
    
    -- Update content height
    content:SetHeight(math.abs(yOffset) + 10)
end

-- Refresh the set dropdown
function AVH:RefreshSetDropdown()
    if not AVH.mainFrame or not AVH.mainFrame.setDropdown then return end
    
    local currentSet = AVH.db.currentSet or "Starter Kit"
    UIDropDownMenu_SetText(AVH.mainFrame.setDropdown, currentSet)
    UIDropDownMenu_Initialize(AVH.mainFrame.setDropdown, AVH.mainFrame.setDropdown.initialize)
end

-- Show create set dialog
function AVH:ShowCreateSetDialog()
    StaticPopupDialogs["AVH_CREATE_SET"] = {
        text = "Enter name for new set:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(self)
            local setName = self.editBox:GetText()
            if setName and setName ~= "" then
                AVH:CreateSet(setName)
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local setName = parent.editBox:GetText()
            if setName and setName ~= "" then
                AVH:CreateSet(setName)
            end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
    }
    StaticPopup_Show("AVH_CREATE_SET")
end

-- Show add item dialog
function AVH:ShowAddItemDialog()
    StaticPopupDialogs["AVH_ADD_ITEM"] = {
        text = "Enter item ID to add to current set:",
        button1 = "Add",
        button2 = "Cancel",
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(self)
            local input = self.editBox:GetText()
            if input and input ~= "" then
                AVH:AddItemToSet(input)
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local input = parent.editBox:GetText()
            if input and input ~= "" then
                AVH:AddItemToSet(input)
            end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
    }
    StaticPopup_Show("AVH_ADD_ITEM")
end

-- Create a button for an item
function AVH:CreateItemButton(parent, itemData, index)
    local buttonName = "AVH_ItemButton" .. index
    local btn = _G[buttonName] or CreateFrame("Button", buttonName, parent)
    btn:SetSize(340, 50)
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    -- Icon
    if not btn.icon then
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(40, 40)
        btn.icon:SetPoint("LEFT", btn, "LEFT", 5, 0)
    end
    
    -- Item name
    if not btn.nameText then
        btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.nameText:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 8, -2)
        btn.nameText:SetWidth(180)
        btn.nameText:SetJustifyH("LEFT")
    end
    
    -- Status text
    if not btn.statusText then
        btn.statusText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.statusText:SetPoint("BOTTOMLEFT", btn.icon, "BOTTOMRIGHT", 8, 2)
        btn.statusText:SetWidth(180)
        btn.statusText:SetJustifyH("LEFT")
    end
    
    -- Category badge
    if not btn.categoryText then
        btn.categoryText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.categoryText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, -5)
        btn.categoryText:SetTextColor(0.7, 0.7, 0.7)
    end
    
    -- Open button (for openable items) - use SecureActionButton to avoid taint
    if not btn.openButton then
        btn.openButton = CreateFrame("Button", "AVH_OpenButton" .. index, btn, "SecureActionButtonTemplate, GameMenuButtonTemplate")
        btn.openButton:SetSize(50, 20)
        btn.openButton:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
        btn.openButton:SetText("Open")
        btn.openButton:SetNormalFontObject("GameFontNormalSmall")
        btn.openButton:SetHighlightFontObject("GameFontHighlightSmall")
        btn.openButton:Hide()
        
        -- Set it to use the item by name when clicked
        btn.openButton:SetAttribute("type", "item")
        
        -- PostClick handler to refresh window after opening
        btn.openButton:SetScript("PostClick", function(self, button)
            -- Delay refresh to allow item to be consumed from bags
            C_Timer.After(0.3, function()
                AVH:RefreshItemList()
            end)
        end)
    end
    
    -- Remove button (for custom items)
    if not btn.removeButton then
        btn.removeButton = CreateFrame("Button", nil, btn, "UIPanelCloseButton")
        btn.removeButton:SetSize(20, 20)
        btn.removeButton:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        btn.removeButton:Hide()
    end
    
    -- Store item data
    btn.itemID = itemData.itemID
    btn.itemName = itemData.name
    btn.isOpenable = itemData.isOpenable
    
    -- Update display based on item info
    AVH:UpdateItemButton(btn, itemData)
    
    -- Click handler for main button (summon)
    btn:SetScript("OnClick", function(self)
        if AVH:SummonItem(self.itemID, self.itemName) then
            -- Refresh after a short delay to show updated status
            C_Timer.After(0.5, function()
                AVH:RefreshItemList()
            end)
        end
    end)
    
    -- Note: Open button uses SecureActionButton, no OnClick handler needed
    -- The secure attribute "item" handles opening automatically
    
    -- Click handler for remove button
    btn.removeButton:SetScript("OnClick", function(self)
        if AVH:RemoveItemFromSet(tostring(btn.itemID)) then
            -- Refresh immediately
            AVH:RefreshItemList()
        end
    end)
    
    -- Tooltip for remove button
    btn.removeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Remove from Set", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    btn.removeButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        
        -- Add status info
        GameTooltip:AddLine(" ")
        if C_VanityCollection.IsCollectionItemOwned(self.itemID) then
            GameTooltip:AddLine("|cff00ff00In Collection|r", 1, 1, 1)
            if AVH:HasItemInBags(self.itemID) then
                GameTooltip:AddLine("|cff00ffffAlready in bags|r", 1, 1, 1)
            else
                GameTooltip:AddLine("Click to summon", 0.7, 0.7, 0.7)
            end
        else
            GameTooltip:AddLine("|cffff0000Not in collection|r", 1, 1, 1)
        end
        
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Hover effect
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
        -- Show tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        
        -- Use hyperlink instead of SetItemByID for 3.3.5 compatibility
        local itemLink = select(2, GetItemInfo(self.itemID))
        if itemLink then
            GameTooltip:SetHyperlink(itemLink)
        else
            GameTooltip:AddLine(self.itemName or "Unknown Item")
        end
        
        GameTooltip:AddLine(" ")
        if C_VanityCollection.IsCollectionItemOwned(self.itemID) then
            GameTooltip:AddLine("|cff00ff00In Collection|r", 1, 1, 1)
            if AVH:HasItemInBags(self.itemID) then
                GameTooltip:AddLine("|cff00ffffAlready in bags|r", 1, 1, 1)
            elseif AVH:HasItemEquipped(self.itemID) then
                GameTooltip:AddLine("|cff00ffffAlready equipped|r", 1, 1, 1)
            else
                GameTooltip:AddLine("Click to summon", 0.7, 0.7, 0.7)
            end
        else
            GameTooltip:AddLine("|cffff0000Not in collection|r", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        GameTooltip:Hide()
    end)
    
    return btn
end

-- Update item button display
function AVH:UpdateItemButton(btn, itemData)
    -- Get item info (may return nil if not cached yet)
    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.itemID)
    
    -- Set icon
    if itemTexture then
        btn.icon:SetTexture(itemTexture)
    else
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    -- Set name with quality color
    local displayName = itemData.name
    if itemLink then
        local _, _, _, colorCode = GetItemQualityColor(itemQuality)
        displayName = colorCode .. itemData.name .. "|r"
    end
    btn.nameText:SetText(displayName)
    
    -- Set category
    btn.categoryText:SetText(itemData.category or "")
    
    -- Check status
    local isOwned = C_VanityCollection.IsCollectionItemOwned(itemData.itemID)
    local hasInBags = AVH:HasItemInBags(itemData.itemID)
    local isEquipped = AVH:HasItemEquipped(itemData.itemID)
    local startTime, duration = GetItemCooldown(itemData.itemID)
    local cooldownRemaining = duration - (GetTime() - startTime)
    
    -- Show/hide open button for openable items (check both itemData and global table)
    local isOpenable = btn.isOpenable or itemData.isOpenable or (AVH_OPENABLE_CONTAINERS and AVH_OPENABLE_CONTAINERS[itemData.itemID])
    
    if isOpenable and hasInBags then
        if btn.openButton then
            btn.openButton:SetAttribute("item", itemData.name)
            btn.openButton:Show()
        end
    else
        if btn.openButton then btn.openButton:Hide() end
    end
    
    -- Show/hide remove button (only for custom items or custom sets)
    local currentSet = AVH.db.currentSet or "Starter Kit"
    local isCustomItem = itemData.category == "Custom"
    local isCustomSet = currentSet ~= "Starter Kit"
    local showRemove = (isCustomItem or isCustomSet) and AVH.db.itemSets[currentSet] and #AVH.db.itemSets[currentSet] > 0
    if showRemove and btn.removeButton then
        btn.removeButton:Show()
    elseif btn.removeButton then
        btn.removeButton:Hide()
    end
    
    -- Set status text
    if not isOwned then
        btn.statusText:SetText("|cffff0000Not in collection|r")
        btn:Disable()
        btn:SetAlpha(0.5)
    elseif hasInBags then
        local _, _, _, bagCount = AVH:HasItemInBags(itemData.itemID)
        if bagCount and bagCount > 1 then
            btn.statusText:SetText("|cff00ffffIn bags (" .. bagCount .. ")|r")
        else
            btn.statusText:SetText("|cff00ffffIn bags|r")
        end
        btn:Enable()
        btn:SetAlpha(1.0)
    elseif isEquipped then
        btn.statusText:SetText("|cff00ffffEquipped|r")
        btn:Enable()
        btn:SetAlpha(1.0)
    elseif cooldownRemaining > 0 then
        local minutes = math.ceil(cooldownRemaining / 60)
        btn.statusText:SetText("|cffff8800Cooldown: " .. minutes .. " min|r")
        btn:Enable()
        btn:SetAlpha(0.7)
    else
        btn.statusText:SetText("|cff00ff00Ready to summon|r")
        btn:Enable()
        btn:SetAlpha(1.0)
    end
end

-- ========================================
-- Warchest Helper Window
-- ========================================


