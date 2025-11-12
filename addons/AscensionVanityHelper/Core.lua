-- Ascension Vanity Helper - Core
-- Main addon initialization and functionality

-- Use internal namespace provided by WoW
local addonName, AVH = ...
AVH.version = "0.1.0"

-- Frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE")

-- Default settings
local defaultDB = {
    windowPosition = nil,
    autoShowOnLogin = false,
    currentSet = "Starter Kit",
    itemSets = {},  -- User custom sets
    minimapButton = {
        hide = false,
        minimapPos = 225,
        radius = 80,
    },
    warchestHelperEnabled = true,
    showBuiltinSets = true,  -- Master toggle for all built-in sets
    visibleBuiltinSets = {   -- Per-set visibility toggles
        ["Starter Kit"] = true,
        ["Heirloom - Cloth Int+Hit"] = true,
        ["Heirloom - Leather Agility"] = true,
        ["Heirloom - Leather Int+Spi"] = true,
        ["Heirloom - Leather Agi+Int"] = true,
        ["Heirloom - Leather Int+Mp5"] = true,
        ["Heirloom - Mail Strength"] = true,
        ["Heirloom - Mail Defense"] = true,
        ["Heirloom - PvP Armor"] = true,
        ["Heirloom - Physical Dmg Weapons"] = true,
        ["Heirloom - Spellpower Weapons"] = true,
        ["Heirloom - PvP Weapons"] = true,
        ["Heirloom - Relics"] = true,
        ["Heirloom - Misc"] = true,
    }
}

-- Event handler
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AscensionVanityHelper" then
        AVH:OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        AVH:OnLogin()
    elseif event == "BAG_UPDATE" then
        AVH:OnBagUpdate(arg1)
    end
end)

-- Initialize addon
function AVH:OnInitialize()
    -- Initialize SavedVariables
    if not AscensionVanityHelperDB then
        AscensionVanityHelperDB = {}
    end
    
    -- Merge with defaults
    for key, value in pairs(defaultDB) do
        if AscensionVanityHelperDB[key] == nil then
            AscensionVanityHelperDB[key] = value
        end
    end
    
    AVH.db = AscensionVanityHelperDB
    
    -- All built-in set names are now hardcoded in Data.lua (no need to populate)
    
    -- Register slash commands
    SLASH_ASCENSIONVANITYHELPER1 = "/avh"
    SLASH_ASCENSIONVANITYHELPER2 = "/vanityhelper"
    SlashCmdList["ASCENSIONVANITYHELPER"] = function(msg)
        AVH:SlashCommand(msg)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Ascension Vanity Helper|r v" .. AVH.version .. " loaded. Type |cff00ffff/avh|r to open.")
end

-- Populate item names for built-in sets (queries game API)
-- All built-in set names are now hardcoded in Data.lua
-- This function is no longer needed but kept for compatibility

-- Get all available sets (user sets + optionally built-in sets in specific order)
function AVH:GetAllAvailableSets()
    local sets = {}
    
    -- Define the order for built-in sets
    local builtinOrder = {
        "Starter Kit",
        "Heirloom - Cloth Int+Hit",
        "Heirloom - Leather Agility",
        "Heirloom - Leather Int+Spi",
        "Heirloom - Leather Agi+Int",
        "Heirloom - Leather Int+Mp5",
        "Heirloom - Mail Strength",
        "Heirloom - Mail Defense",
        "Heirloom - PvP Armor",
        "Heirloom - Physical Dmg Weapons",
        "Heirloom - Spellpower Weapons",
        "Heirloom - PvP Weapons",
        "Heirloom - Relics",
        "Heirloom - Misc",
    }
    
    -- Add built-in sets in order based on individual visibility settings
    for _, setName in ipairs(builtinOrder) do
        if AVH_BUILTIN_SETS[setName] and AVH.db.visibleBuiltinSets[setName] then
            table.insert(sets, setName)
        end
    end
    
    -- Add user custom sets after built-in sets
    for setName, _ in pairs(AVH.db.itemSets) do
        -- Don't duplicate if user has a set with same name as built-in
        local isDuplicate = false
        for _, existingSet in ipairs(sets) do
            if existingSet == setName then
                isDuplicate = true
                break
            end
        end
        if not isDuplicate then
            table.insert(sets, setName)
        end
    end
    
    return sets
end

-- Get items for a specific set (checks user sets first, then built-in)
function AVH:GetItemsForSet(setName)
    -- Check user sets first
    if AVH.db.itemSets[setName] then
        return AVH.db.itemSets[setName]
    end
    
    -- Check built-in sets (if globally enabled and individually visible)
    if AVH.db.showBuiltinSets and AVH.db.visibleBuiltinSets[setName] and AVH_BUILTIN_SETS[setName] then
        return AVH_BUILTIN_SETS[setName]
    end
    
    -- Fallback to default
    return AVH_ITEMS
end

-- Handle login
function AVH:OnLogin()
    -- Create minimap button
    AVH:CreateMinimapButton()
    
    -- Debug: Check if button was created
    if AVH.minimapButton then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Minimap button created. Hide setting: " .. tostring(AVH.db.minimapButton.hide))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Failed to create minimap button!")
    end
    
    -- Create interface options panel
    AVH:CreateInterfaceOptions()
    
    -- Mark as fully loaded (prevents bag update spam during login)
    C_Timer.After(2, function()
        AVH.isFullyLoaded = true
    end)
    
    -- Auto-show window on login if enabled
    if AVH.db.autoShowOnLogin then
        AVH:ToggleWindow()
    end
end

-- Handle bag updates (detect Warchest contents)
function AVH:OnBagUpdate(bagID)
    -- Removed auto-show behavior - use Helper button instead
    -- Helper window is now toggled on-demand via the Helper button
end

-- Slash command handler
function AVH:SlashCommand(msg)
    msg = msg:lower():trim()
    
    if msg == "" or msg == "show" then
        AVH:ToggleWindow()
    elseif msg == "cleanup" then
        AVH:ShowCleanupHelper()
    elseif msg == "hide" then
        if AVH.mainFrame and AVH.mainFrame:IsVisible() then
            AVH.mainFrame:Hide()
        end
    elseif msg == "auto" then
        AVH.db.autoShowOnLogin = not AVH.db.autoShowOnLogin
        local status = AVH.db.autoShowOnLogin and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("Ascension Vanity Helper: Auto-show on login " .. status)
    elseif msg == "debug" then
        AVH.db.debug = not AVH.db.debug
        local status = AVH.db.debug and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("Ascension Vanity Helper: Debug mode " .. status)
    elseif msg:match("^add%s+(.+)") then
        local input = msg:match("^add%s+(.+)")
        AVH:AddItemToSet(input)
    elseif msg:match("^remove%s+(.+)") then
        local input = msg:match("^remove%s+(.+)")
        AVH:RemoveItemFromSet(input)
    elseif msg:match("^create%s+(.+)") then
        local setName = msg:match("^create%s+(.+)")
        AVH:CreateSet(setName)
    elseif msg:match("^delete%s+(.+)") then
        local setName = msg:match("^delete%s+(.+)")
        AVH:DeleteSet(setName)
    elseif msg == "reset" then
        AVH:ResetCurrentSet()
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Ascension Vanity Helper Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh|r or |cff00ffff/avh show|r - Toggle main window")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh cleanup|r - Open Cleanup Helper")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh hide|r - Hide main window")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh auto|r - Toggle auto-show on login")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh debug|r - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh add <itemID>|r - Add item to current set")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh remove <itemID>|r - Remove item from current set")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh create <name>|r - Create new set")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh delete <name>|r - Delete a custom set")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh reset|r - Reset current set to defaults")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/avh help|r - Show this help")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Unknown command. Type |cff00ffff/avh help|r for help.")
    end
end
-- Toggle main window
function AVH:ToggleWindow()
    if not AVH.mainFrame then
        AVH:CreateMainWindow()
        AVH.mainFrame:Show()
    else
        if AVH.mainFrame:IsVisible() then
            AVH.mainFrame:Hide()
        else
            AVH.mainFrame:Show()
        end
    end
end

-- Check if player has item in bags (returns found, bag, slot, count)
function AVH:HasItemInBags(itemID)
    local totalCount = 0
    local firstBag, firstSlot = nil, nil
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local item = GetContainerItemLink(bag, slot)
            if item then
                local found, _, id = item:find('^|c%x+|Hitem:(%d+):.+')
                if found and tonumber(id) == itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    totalCount = totalCount + (count or 1)
                    if not firstBag then
                        firstBag = bag
                        firstSlot = slot
                    end
                end
            end
        end
    end
    
    if totalCount > 0 then
        return true, firstBag, firstSlot, totalCount
    end
    return false
end

-- Check if vanity item is already known (scan tooltip)
function AVH:IsVanityItemKnown(itemID, bag, slot)
    if not AVH.scanTooltip then
        AVH.scanTooltip = CreateFrame("GameTooltip", "AVH_ScanTooltip", nil, "GameTooltipTemplate")
        AVH.scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    
    AVH.scanTooltip:ClearLines()
    AVH.scanTooltip:SetBagItem(bag, slot)
    
    -- Scan tooltip lines for "already known" or "you own this"
    for i = 1, AVH.scanTooltip:NumLines() do
        local line = _G["AVH_ScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                local lower = text:lower()
                if lower:find("already known") or lower:find("you own this") then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Get empty bag slots (slots 19-22 are bag slots, 19=backpack is always equipped)
-- Check if player has item equipped
function AVH:HasItemEquipped(itemID)
    for slot = 0, 19 do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local found, _, id = itemLink:find('^|c%x+|Hitem:(%d+):.+')
            if found and tonumber(id) == itemID then
                return true, slot
            end
        end
    end
    return false
end

-- Check if item is unique (can only have one)
function AVH:IsItemUnique(itemID)
    -- Get item info from cache or tooltip
    local _, _, _, _, _, _, _, maxStack = GetItemInfo(itemID)
    if maxStack and maxStack == 1 then
        -- Check tooltip for "Unique" text
        local tooltip = AVH:GetItemTooltipInfo(itemID)
        if tooltip and tooltip.isUnique then
            return true
        end
    end
    return false
end

-- Get tooltip info for an item
function AVH:GetItemTooltipInfo(itemID)
    if not AVH.scanTooltip then
        AVH.scanTooltip = CreateFrame("GameTooltip", "AVH_ScanTooltip", nil, "GameTooltipTemplate")
        AVH.scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    
    local tooltip = AVH.scanTooltip
    tooltip:ClearLines()
    
    -- Use hyperlink instead of SetItemByID for 3.3.5 compatibility
    local itemLink = select(2, GetItemInfo(itemID))
    if itemLink then
        tooltip:SetHyperlink(itemLink)
    else
        tooltip:Hide()
        return {}
    end
    
    local info = {}
    for i = 1, tooltip:NumLines() do
        local text = _G["AVH_ScanTooltipTextLeft"..i]:GetText()
        if text then
            if text:find("Unique") or text:find("Unique%-Equipped") then
                info.isUnique = true
            end
        end
    end
    
    tooltip:Hide()
    return info
end

-- Summon item from collection
function AVH:SummonItem(itemID, itemName)
    -- Check if item is in collection
    if not C_VanityCollection.IsCollectionItemOwned(itemID) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r You don't own " .. (itemName or "this item") .. " in your collection.")
        return false
    end
    
    -- Get item info to check if unique
    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, itemIsUnique = GetItemInfo(itemID)
    
    -- Only check equipped/bags status for unique items
    if itemIsUnique then
        local isEquipped = AVH:HasItemEquipped(itemID)
        local hasInBags = AVH:HasItemInBags(itemID)
        
        if isEquipped then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[AVH]|r " .. (itemName or "Item") .. " is already equipped (Unique).")
            return false
        elseif hasInBags then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[AVH]|r " .. (itemName or "Item") .. " is already in your bags (Unique).")
            return false
        end
    end
    
    -- Check cooldown
    local startTime, duration = GetItemCooldown(itemID)
    local cooldownRemaining = duration - (GetTime() - startTime)
    if cooldownRemaining > 0 then
        local minutes = math.ceil(cooldownRemaining / 60)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[AVH]|r " .. (itemName or "Item") .. " is on cooldown (" .. minutes .. " min remaining).")
        return false
    end
    
    -- Summon the item
    RequestDeliverVanityCollectionItem(itemID)
    return true
end

-- Summon all items from the list
function AVH:SummonAll()
    local currentSet = AVH.db.currentSet or "Starter Kit"
    local items = AVH:GetItemsForSet(currentSet)
    
    -- Queue items to summon
    local itemQueue = {}
    for _, item in ipairs(items) do
        table.insert(itemQueue, item)
    end
    
    -- Summon items sequentially with 2-second delay
    local index = 0
    local summoned = 0
    local skipped = 0
    
    local function summonNext()
        index = index + 1
        if index > #itemQueue then
            -- All done, refresh UI
            if AVH.mainFrame and AVH.mainFrame:IsShown() then
                AVH:RefreshItemList()
            end
            return
        end
        
        local item = itemQueue[index]
        if AVH:SummonItem(item.itemID, item.name) then
            summoned = summoned + 1
        else
            skipped = skipped + 1
        end
        
        -- Schedule next summon after 2 seconds
        C_Timer.After(2, summonNext)
    end
    
    -- Start the chain
    summonNext()
end

-- Note: OpenItem function removed - now using SecureActionButton in UI
-- The Open button directly uses items via secure attributes to avoid taint

-- Add item to current set (by ID or name)
function AVH:AddItemToSet(input)
    if not input or input == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Please provide an item ID or name.")
        return false
    end
    
    local itemID = tonumber(input)
    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture
    
    -- If input is a number, treat as item ID
    if itemID then
        itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
        if not itemName then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Item ID " .. itemID .. " not found. It may not be cached yet.")
            return false
        end
    else
        -- Try to find item by name
        itemName = input
        -- Attempt to get item info by name (this may not work in 3.3.5, so we'll use ID)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[AVH]|r Please use item ID instead of name for best results.")
        return false
    end
    
    -- Get current set
    local currentSet = AVH.db.currentSet or "Starter Kit"
    
    -- Initialize set if it doesn't exist - copy from defaults if it's the default set
    if not AVH.db.itemSets[currentSet] then
        AVH.db.itemSets[currentSet] = {}
        -- If this is the default set, copy the base items first
        if currentSet == "Starter Kit" then
            for _, item in ipairs(AVH_ITEMS) do
                table.insert(AVH.db.itemSets[currentSet], {
                    itemID = item.itemID,
                    name = item.name,
                    category = item.category,
                    isOpenable = item.isOpenable
                })
            end
        end
    elseif currentSet == "Starter Kit" and #AVH.db.itemSets[currentSet] == 0 then
        -- If the default set exists but is empty, copy base items
        for _, item in ipairs(AVH_ITEMS) do
            table.insert(AVH.db.itemSets[currentSet], {
                itemID = item.itemID,
                name = item.name,
                category = item.category,
                isOpenable = item.isOpenable
            })
        end
    end
    
    -- Check if item already exists in set
    for _, item in ipairs(AVH.db.itemSets[currentSet]) do
        if item.itemID == itemID then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[AVH]|r " .. itemName .. " is already in this set.")
            return false
        end
    end
    
    -- Add to set
    table.insert(AVH.db.itemSets[currentSet], {
        itemID = itemID,
        name = itemName,
        category = "Custom"
    })
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Added " .. itemName .. " to set '" .. currentSet .. "'.")
    
    -- Refresh UI if open
    if AVH.mainFrame and AVH.mainFrame:IsVisible() then
        AVH:RefreshItemList()
    end
    
    return true
end

-- Remove item from current set
function AVH:RemoveItemFromSet(input)
    if not input or input == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Please provide an item ID.")
        return false
    end
    
    local itemID = tonumber(input)
    if not itemID then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Invalid item ID.")
        return false
    end
    
    -- Get current set
    local currentSet = AVH.db.currentSet or "Starter Kit"
    
    -- Check if set exists in DB
    if not AVH.db.itemSets[currentSet] or #AVH.db.itemSets[currentSet] == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Cannot remove items from the default set until it's been modified. Use /avh reset to restore defaults.")
        return false
    end
    
    -- Find and remove item
    local found = false
    local itemName = "Item"
    for i, item in ipairs(AVH.db.itemSets[currentSet]) do
        if item.itemID == itemID then
            itemName = item.name or itemName
            table.remove(AVH.db.itemSets[currentSet], i)
            found = true
            break
        end
    end
    
    if not found then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[AVH]|r Item " .. itemID .. " not found in current set.")
        return false
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Removed " .. itemName .. " from set '" .. currentSet .. "'.")
    
    -- Refresh UI if open
    if AVH.mainFrame and AVH.mainFrame:IsVisible() then
        AVH:RefreshItemList()
    end
    
    return true
end

-- Create a new set
function AVH:CreateSet(setName)
    if not setName or setName == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Please provide a set name.")
        return false
    end
    
    if AVH.db.itemSets[setName] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[AVH]|r Set '" .. setName .. "' already exists.")
        return false
    end
    
    AVH.db.itemSets[setName] = {}
    AVH.db.currentSet = setName
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Created new set '" .. setName .. "'.")
    
    -- Refresh UI if open
    if AVH.mainFrame and AVH.mainFrame:IsVisible() then
        AVH:RefreshSetDropdown()
        AVH:RefreshItemList()
    end
    
    return true
end

-- Delete a set
function AVH:DeleteSet(setName)
    if not setName or setName == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Please provide a set name.")
        return false
    end
    
    -- Protect default set from deletion
    if setName == "Starter Kit" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Cannot delete the default set. Use /avh reset to restore it to defaults.")
        return false
    end
    
    if not AVH.db.itemSets[setName] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[AVH]|r Set '" .. setName .. "' does not exist.")
        return false
    end
    
    AVH.db.itemSets[setName] = nil
    
    -- If deleting current set, switch to default
    if AVH.db.currentSet == setName then
        AVH.db.currentSet = "Starter Kit"
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Deleted set '" .. setName .. "'.")
    
    -- Refresh UI if open
    if AVH.mainFrame and AVH.mainFrame:IsVisible() then
        AVH:RefreshSetDropdown()
        AVH:RefreshItemList()
    end
    
    return true
end

-- Reset current set to defaults
function AVH:ResetCurrentSet()
    local currentSet = AVH.db.currentSet or "Starter Kit"
    
    if currentSet == "Starter Kit" then
        -- Reset to default items
        AVH.db.itemSets[currentSet] = {}
        for _, item in ipairs(AVH_ITEMS) do
            table.insert(AVH.db.itemSets[currentSet], {
                itemID = item.itemID,
                name = item.name,
                category = item.category,
                isOpenable = item.isOpenable
            })
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Reset '" .. currentSet .. "' to default items.")
    else
        -- For custom sets, just clear them
        AVH.db.itemSets[currentSet] = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[AVH]|r Cleared all items from '" .. currentSet .. "'.")
    end
    
    -- Refresh UI if open
    if AVH.mainFrame and AVH.mainFrame:IsVisible() then
        AVH:RefreshItemList()
    end
    
    return true
end

-- Get current set items
function AVH:GetCurrentSetItems()
    local currentSet = AVH.db.currentSet or "Starter Kit"
    return AVH:GetItemsForSet(currentSet)
end

-- ========================================
-- Minimap Button
-- ========================================

function AVH:CreateMinimapButton()
    local button = CreateFrame("Button", "AVH_MinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Icon
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    button.icon = icon
    
    -- Border
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    
    -- Drag functionality
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isMoving = true
        self:SetScript("OnUpdate", AVH.MinimapButton_OnUpdate)
    end)
    
    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isMoving = false
        self:SetScript("OnUpdate", nil)
    end)
    
    -- Click functionality
    button:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            AVH:ToggleWindow()
        elseif button == "RightButton" then
            AVH:OpenInterfaceOptions()
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00ff00Ascension Vanity Helper|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffffffffLeft-click:|r Open window", 1, 1, 1)
        GameTooltip:AddLine("|cffffffffRight-click:|r Options", 1, 1, 1)
        GameTooltip:AddLine("|cffffffffDrag:|r Move button", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    AVH.minimapButton = button
    AVH:UpdateMinimapButtonPosition()
    
    if not AVH.db.minimapButton.hide then
        button:Show()
    else
        button:Hide()
    end
end

function AVH.MinimapButton_OnUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    
    local angle = math.atan2(py - my, px - mx)
    local degrees = math.deg(angle)
    
    AVH.db.minimapButton.minimapPos = degrees
    AVH:UpdateMinimapButtonPosition()
end

function AVH:UpdateMinimapButtonPosition()
    if not AVH.minimapButton then return end
    
    local angle = math.rad(AVH.db.minimapButton.minimapPos or 225)
    local x = math.cos(angle) * (AVH.db.minimapButton.radius or 80)
    local y = math.sin(angle) * (AVH.db.minimapButton.radius or 80)
    
    AVH.minimapButton:ClearAllPoints()
    AVH.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function AVH:ToggleMinimapButton()
    AVH.db.minimapButton.hide = not AVH.db.minimapButton.hide
    if AVH.db.minimapButton.hide then
        AVH.minimapButton:Hide()
    else
        AVH.minimapButton:Show()
    end
end

-- ========================================
-- Interface Options Panel
-- ========================================

function AVH:CreateInterfaceOptions()
    local panel = CreateFrame("Frame", "AVH_OptionsPanel", UIParent)
    panel.name = "Ascension Vanity Helper"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00Ascension Vanity Helper|r v" .. AVH.version)
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(580)
    desc:SetJustifyH("LEFT")
    desc:SetText("Manage and summon vanity collection items with customizable sets.")
    
    -- Open Main Window button
    local openButton = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    openButton:SetSize(200, 30)
    openButton:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    openButton:SetText("Open Vanity Helper")
    openButton:SetNormalFontObject("GameFontNormal")
    openButton:SetHighlightFontObject("GameFontHighlight")
    openButton:SetScript("OnClick", function()
        AVH:ToggleWindow()
    end)
    
    -- Minimap button toggle
    local minimapCheck = CreateFrame("CheckButton", "AVH_MinimapCheck", panel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -20)
    minimapCheck:SetSize(24, 24)
    
    local minimapLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 5, 0)
    minimapLabel:SetText("Show minimap button")
    
    minimapCheck:SetScript("OnShow", function(self)
        self:SetChecked(not AVH.db.minimapButton.hide)
    end)
    
    minimapCheck:SetScript("OnClick", function(self)
        AVH:ToggleMinimapButton()
    end)
    
    -- Auto-show on login toggle
    local autoShowCheck = CreateFrame("CheckButton", "AVH_AutoShowCheck", panel, "UICheckButtonTemplate")
    autoShowCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -10)
    autoShowCheck:SetSize(24, 24)
    
    local autoShowLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoShowLabel:SetPoint("LEFT", autoShowCheck, "RIGHT", 5, 0)
    autoShowLabel:SetText("Auto-show window on login")
    
    autoShowCheck:SetScript("OnShow", function(self)
        self:SetChecked(AVH.db.autoShowOnLogin)
    end)
    
    autoShowCheck:SetScript("OnClick", function(self)
        AVH.db.autoShowOnLogin = self:GetChecked()
    end)
    
    -- Built-in sets section
    local builtinTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    builtinTitle:SetPoint("TOPLEFT", autoShowCheck, "BOTTOMLEFT", 0, -30)
    builtinTitle:SetText("|cffffffffVisible Built-in Sets:|r")
    
    -- Master toggle for all built-in sets
    local masterToggle = CreateFrame("CheckButton", "AVH_MasterBuiltinCheck", panel, "UICheckButtonTemplate")
    masterToggle:SetPoint("TOPLEFT", builtinTitle, "BOTTOMLEFT", 0, -10)
    masterToggle:SetSize(24, 24)
    
    local masterLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    masterLabel:SetPoint("LEFT", masterToggle, "RIGHT", 5, 0)
    masterLabel:SetText("Show all built-in sets")
    
    -- Store references to individual checkboxes for master toggle
    local individualChecks = {}
    
    masterToggle:SetScript("OnShow", function(self)
        -- Master is checked only if ALL individual sets are checked
        local allChecked = true
        for setName, _ in pairs(AVH.db.visibleBuiltinSets) do
            if not AVH.db.visibleBuiltinSets[setName] then
                allChecked = false
                break
            end
        end
        self:SetChecked(allChecked)
    end)
    
    masterToggle:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        
        -- Check or uncheck all individual sets
        for _, check in ipairs(individualChecks) do
            AVH.db.visibleBuiltinSets[check.setName] = isChecked
            check:SetChecked(isChecked)
        end
        
        -- If unchecking all and current set is a built-in, reset to default
        if not isChecked and AVH.mainFrame then
            local currentSet = AVH.db.currentSet or "New Character Set"
            if AVH_BUILTIN_SETS[currentSet] then
                AVH.db.currentSet = "New Character Set"
                UIDropDownMenu_SetText(AVH.mainFrame.setDropdown, "New Character Set")
            end
        end
        
        -- Refresh dropdown if window is open
        if AVH.mainFrame and AVH.mainFrame:IsVisible() then
            AVH:RefreshSetDropdown()
            AVH:RefreshItemList()
        end
    end)
    
    -- Individual set checkboxes in 2 columns
    local builtinSets = {
        "Starter Kit",
        "Heirloom - Cloth Int+Hit",
        "Heirloom - Leather Agility",
        "Heirloom - Leather Int+Spi",
        "Heirloom - Leather Agi+Int",
        "Heirloom - Leather Int+Mp5",
        "Heirloom - Mail Strength",
        "Heirloom - Mail Defense",
        "Heirloom - PvP Armor",
        "Heirloom - Physical Dmg Weapons",
        "Heirloom - Spellpower Weapons",
        "Heirloom - PvP Weapons",
        "Heirloom - Relics",
        "Heirloom - Misc",
    }
    
    local colWidth = 250
    local rowHeight = -25
    local indent = 20
    
    for i, setName in ipairs(builtinSets) do
        local check = CreateFrame("CheckButton", "AVH_SetCheck_" .. i, panel, "UICheckButtonTemplate")
        check:SetSize(20, 20)
        
        -- Calculate row (0-6 for both columns)
        local row = ((i - 1) % 7)
        
        -- Alternate between columns (7 items per column)
        if i <= 7 then
            -- Left column
            check:SetPoint("TOPLEFT", masterToggle, "BOTTOMLEFT", indent, (row * rowHeight) - 5)
        else
            -- Right column
            check:SetPoint("TOPLEFT", masterToggle, "BOTTOMLEFT", indent + colWidth, (row * rowHeight) - 5)
        end
        
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", check, "RIGHT", 5, 0)
        label:SetText(setName)
        
        check.setName = setName
        check:SetScript("OnShow", function(self)
            self:SetChecked(AVH.db.visibleBuiltinSets[self.setName])
        end)
        
        check:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            AVH.db.visibleBuiltinSets[self.setName] = isChecked
            
            -- Update master toggle: check if ALL individual sets are checked
            local allChecked = true
            for setName, _ in pairs(AVH.db.visibleBuiltinSets) do
                if not AVH.db.visibleBuiltinSets[setName] then
                    allChecked = false
                    break
                end
            end
            masterToggle:SetChecked(allChecked)
            
            -- Refresh dropdown if window is open
            if AVH.mainFrame and AVH.mainFrame:IsVisible() then
                AVH:RefreshSetDropdown()
                AVH:RefreshItemList()
            end
        end)
        
        table.insert(individualChecks, check)
    end
    
    InterfaceOptions_AddCategory(panel)
    AVH.optionsPanel = panel
end

function AVH:OpenInterfaceOptions()
    InterfaceOptionsFrame_OpenToCategory(AVH.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(AVH.optionsPanel) -- Call twice due to Blizzard bug
end

