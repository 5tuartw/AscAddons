-- Ascension Trinket Manager - Core
-- Lightweight trinket swap and activation manager

-- Create addon namespace
ATM = {}
ATM.version = "1.1.2"

-- Trinket slot IDs
ATM.TRINKET_SLOTS = {13, 14}
ATM.CARROT_ITEM_ID = 339075  -- Stick on a Carrot

-- Pending swap for retry logic
ATM.pendingSwap = nil
ATM.retryTimer = nil
ATM.pendingContainerVisibility = false
ATM.pendingButtonRefresh = false

-- Frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("UNIT_AURA")  -- Mount/buff changes in 3.3.5
frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")  -- Cooldown updates
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Left combat

-- Default settings
local defaultDB = {
    scale = 1.0,
    orientation = "horizontal",  -- horizontal or vertical
    expandDirectionHorizontal = "up",  -- up or down for horizontal layout
    expandDirectionVertical = "right", -- left or right for vertical layout
    position = nil,               -- Saved position
    autoCarrot = true,            -- Auto-equip Stick on a Carrot when mounted
    carrotSlot = 14,              -- Which trinket slot to use (13 or 14)
    carrotInInstance = false,     -- Enable auto-carrot in instances
    carrotInBattleground = false, -- Enable auto-carrot in battlegrounds
    useMountEquipmentSet = false, -- If carrot is not in bags, use a mount set
    mountEquipmentSetName = "",  -- Name of equipment manager set used while mounted
    hideNoActionTrinkets = false, -- Hide trinket buttons that have no use effect
    locked = false,               -- Lock buttons in place
    showButtons = true,           -- Show trinket buttons
}

local function GetItemIDFromLink(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end

    return tonumber(itemLink:match("item:(%d+)"))
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AscensionTrinketManager" then
        ATM:OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        ATM:OnLogin()
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
        ATM:OnInventoryChanged()
    elseif event == "BAG_UPDATE" then
        ATM:OnBagUpdate()
    elseif event == "UNIT_AURA" and arg1 == "player" then
        ATM:OnMountChanged()
    elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
        ATM:UpdateCooldowns()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ATM:OnLeaveCombat()
    end
end)

-- Initialize addon
function ATM:OnInitialize()
    -- Initialize SavedVariables
    if not AscensionTrinketManagerDB then
        AscensionTrinketManagerDB = {}
    end
    
    -- Merge with defaults
    for key, value in pairs(defaultDB) do
        if AscensionTrinketManagerDB[key] == nil then
            AscensionTrinketManagerDB[key] = value
        end
    end
    
    ATM.db = AscensionTrinketManagerDB
    
    -- Register slash commands
    SLASH_ASCENSIONTRINKETMANAGER1 = "/atm"
    SLASH_ASCENSIONTRINKETMANAGER2 = "/trinkets"
    SlashCmdList["ASCENSIONTRINKETMANAGER"] = function(msg)
        ATM:SlashCommand(msg)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Ascension Trinket Manager|r v" .. ATM.version .. " loaded. Type |cff00ffff/atm|r for options.")
end

-- Login handler
function ATM:ApplyContainerVisibility()
    if not ATM.container then
        return
    end

    if InCombatLockdown() then
        ATM.pendingContainerVisibility = true
        return
    end

    if ATM.db.showButtons then
        ATM.container:Show()
    else
        ATM.container:Hide()
    end

    ATM.pendingContainerVisibility = false
end

function ATM:OnLogin()
    -- Create options panel
    ATM:CreateOptionsPanel()
    
    -- Create UI
    ATM:CreateTrinketButtons()
    
    -- Restore position
    if ATM.db.position then
        ATM.container:ClearAllPoints()
        ATM.container:SetPoint(ATM.db.position.point, UIParent, ATM.db.position.relativePoint, ATM.db.position.xOfs, ATM.db.position.yOfs)
    end
    
    -- Show/hide based on settings (deferred if in combat)
    ATM:ApplyContainerVisibility()
    
    -- Initial update
    ATM:UpdateTrinketButtons()
end

-- Inventory changed
function ATM:OnInventoryChanged()
    if ATM.container then
        ATM:UpdateTrinketButtons()
    end
end

-- Bag update
function ATM:OnBagUpdate()
    if ATM.container and ATM.container:IsShown() then
        ATM:UpdateTrinketButtons()
    end
end

function ATM:CanUseEquipmentSets()
    return type(GetNumEquipmentSets) == "function" and
           type(GetEquipmentSetInfo) == "function" and
           type(UseEquipmentSet) == "function"
end

function ATM:GetEquipmentSetNames()
    if not ATM:CanUseEquipmentSets() then
        return {}
    end

    local names = {}
    local numSets = GetNumEquipmentSets() or 0
    for i = 1, numSets do
        local name = GetEquipmentSetInfo(i)
        if type(name) == "string" and name ~= "" then
            table.insert(names, name)
        end
    end

    table.sort(names)
    return names
end

function ATM:EquipmentSetExists(setName)
    if type(setName) ~= "string" or setName == "" then
        return false
    end

    local names = ATM:GetEquipmentSetNames()
    for _, name in ipairs(names) do
        if name == setName then
            return true
        end
    end

    return false
end

function ATM:GetEquippedEquipmentSetName()
    if not ATM:CanUseEquipmentSets() then
        return nil
    end

    local numSets = GetNumEquipmentSets() or 0

    if type(IsEquipmentSetEquipped) == "function" then
        for i = 1, numSets do
            local name = GetEquipmentSetInfo(i)
            if type(name) == "string" and name ~= "" and IsEquipmentSetEquipped(name) then
                return name
            end
        end
    end

    for i = 1, numSets do
        local name, _, _, isEquipped = GetEquipmentSetInfo(i)
        if type(name) == "string" and name ~= "" and isEquipped then
            return name
        end
    end

    return nil
end

function ATM:FindItemInBagsByID(itemID)
    if not itemID then
        return nil, nil
    end

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if GetItemIDFromLink(itemLink) == itemID then
                return bag, slot
            end
        end
    end

    return nil, nil
end

function ATM:GetFirstEmptyBagSlot()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if not itemLink then
                return bag, slot
            end
        end
    end

    return nil, nil
end

function ATM:MoveEquippedItemToBags(slotID)
    if InCombatLockdown() then
        return false
    end

    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then
        return false
    end

    local bag, slot = ATM:GetFirstEmptyBagSlot()
    if not bag then
        return false
    end

    ClearCursor()
    PickupInventoryItem(slotID)
    PickupContainerItem(bag, slot)

    if CursorHasItem and CursorHasItem() then
        ClearCursor()
        return false
    end

    return true
end

function ATM:UseEquipmentSetByName(setName)
    if not ATM:CanUseEquipmentSets() then
        return false
    end

    if type(setName) ~= "string" or setName == "" then
        return false
    end

    if not ATM:EquipmentSetExists(setName) then
        return false
    end

    if InCombatLockdown() then
        return false
    end

    local ok = pcall(UseEquipmentSet, setName)
    return ok and true or false
end

-- Update cooldowns only
function ATM:UpdateCooldowns()
    if not ATM.trinketButtons then
        return
    end
    
    for i, btn in ipairs(ATM.trinketButtons) do
        local start, duration, enable = GetInventoryItemCooldown("player", btn.slotID)
        if start and duration and duration > 1.5 then
            btn.cooldown:SetCooldown(start, duration)
        else
            btn.cooldown:Hide()
        end
    end
end

-- Mount changed
function ATM:OnMountChanged()
    -- Check if mount state actually changed
    local isMounted = IsMounted()

    if not ATM.db.autoCarrot then
        -- If auto-carrot was disabled while mounted, still restore on the next dismount.
        if not isMounted and ATM.wasMounted then
            ATM:RestorePreviousTrinket()
        end
        ATM.wasMounted = isMounted
        return
    end
    
    -- Check zone restrictions
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        if instanceType == "pvp" and not ATM.db.carrotInBattleground then
            return  -- In BG but disabled
        elseif instanceType ~= "pvp" and not ATM.db.carrotInInstance then
            return  -- In instance but disabled
        end
    end
    
    if isMounted and not ATM.wasMounted then
        -- Just mounted
        ATM:EquipCarrot()
    elseif not isMounted and ATM.wasMounted then
        -- Just dismounted
        ATM:RestorePreviousTrinket()
    end
    
    ATM.wasMounted = isMounted
end

-- Check if trinket has usable effect
function ATM:TrinketHasUseEffect(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    if not itemLink then
        return false
    end
    
    -- Check if item has "Use:" in tooltip
    if not ATM.scanTooltip then
        ATM.scanTooltip = CreateFrame("GameTooltip", "ATM_ScanTooltip", nil, "GameTooltipTemplate")
        ATM.scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    
    ATM.scanTooltip:ClearLines()
    ATM.scanTooltip:SetInventoryItem("player", slot)
    
    for i = 1, ATM.scanTooltip:NumLines() do
        local line = _G["ATM_ScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("^Use:") then
                return true
            end
        end
    end
    
    return false
end

-- Get trinkets in bags
function ATM:GetBagTrinkets()
    local trinkets = {}
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    local _, _, _, _, _, _, _, _, equipSlot = GetItemInfo(itemID)
                    if equipSlot == "INVTYPE_TRINKET" then
                        local _, count = GetContainerItemInfo(bag, slot)
                        table.insert(trinkets, {
                            itemID = itemID,
                            itemLink = itemLink,
                            bag = bag,
                            slot = slot,
                            count = count or 1
                        })
                    end
                end
            end
        end
    end
    
    return trinkets
end

-- Equip trinket from bags
function ATM:EquipTrinketFromBag(bag, slot, trinketSlot)
    -- Check if blocked (in combat or casting)
    if InCombatLockdown() or UnitCastingInfo("player") or UnitChannelInfo("player") then
        -- Save for retry
        ATM.pendingSwap = {
            bag = bag,
            slot = slot,
            trinketSlot = trinketSlot,
            timestamp = GetTime()
        }
        
        -- Cancel existing retry timer
        if ATM.retryTimer then
            ATM.retryTimer:Cancel()
        end
        
        -- Set up retry timer (only if not in combat)
        if not InCombatLockdown() then
            ATM.retryTimer = C_Timer.NewTicker(2, function()
                ATM:RetryPendingSwap()
            end)
        end
        
        return false
    end
    
    -- Clear any pending swap
    ATM.pendingSwap = nil
    if ATM.retryTimer then
        ATM.retryTimer:Cancel()
        ATM.retryTimer = nil
    end
    
    -- Pick up item from bag
    PickupContainerItem(bag, slot)
    
    -- Place in trinket slot
    PickupInventoryItem(trinketSlot)
    
    -- Update UI after brief delay
    C_Timer.After(0.2, function()
        ATM:UpdateTrinketButtons()
    end)
    
    return true
end

-- Retry pending trinket swap
function ATM:RetryPendingSwap()
    if not ATM.pendingSwap then
        if ATM.retryTimer then
            ATM.retryTimer:Cancel()
            ATM.retryTimer = nil
        end
        return
    end
    
    -- Check if swap is still valid (item still in bag, not too old)
    local age = GetTime() - ATM.pendingSwap.timestamp
    if age > 30 then
        -- Give up after 30 seconds
        ATM.pendingSwap = nil
        if ATM.retryTimer then
            ATM.retryTimer:Cancel()
            ATM.retryTimer = nil
        end
        return
    end
    
    -- Verify item is still in the expected bag slot
    local itemLink = GetContainerItemLink(ATM.pendingSwap.bag, ATM.pendingSwap.slot)
    if not itemLink then
        -- Item moved or was equipped manually
        ATM.pendingSwap = nil
        if ATM.retryTimer then
            ATM.retryTimer:Cancel()
            ATM.retryTimer = nil
        end
        return
    end
    
    -- Try to equip again
    local success = ATM:EquipTrinketFromBag(
        ATM.pendingSwap.bag,
        ATM.pendingSwap.slot,
        ATM.pendingSwap.trinketSlot
    )
    
    if success and ATM.retryTimer then
        ATM.retryTimer:Cancel()
        ATM.retryTimer = nil
    end
end

-- Called when leaving combat
function ATM:OnLeaveCombat()
    -- Retry pending swap if exists
    if ATM.pendingSwap and not ATM.retryTimer then
        -- Start retry timer now that we're out of combat
        ATM.retryTimer = C_Timer.NewTicker(2, function()
            ATM:RetryPendingSwap()
        end)
        
        -- Try immediately
        ATM:RetryPendingSwap()
    end

    if ATM.pendingContainerVisibility then
        ATM:ApplyContainerVisibility()
    end

    if ATM.pendingButtonRefresh then
        ATM.pendingButtonRefresh = false
        ATM:UpdateTrinketButtons()
    end
end

-- Auto-equip Stick on a Carrot when mounting
function ATM:EquipCarrot()
    ATM.mountSwapContext = nil

    -- Find carrot in bags first (preferred, safest path).
    local carrotBag, carrotSlot = ATM:FindItemInBagsByID(ATM.CARROT_ITEM_ID)
    
    -- Check if carrot is already equipped
    for _, trinketSlot in ipairs(ATM.TRINKET_SLOTS) do
        local itemLink = GetInventoryItemLink("player", trinketSlot)
        if itemLink then
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            if itemID == ATM.CARROT_ITEM_ID then
                return  -- Already equipped
            end
        end
    end
    
    -- Save current trinket in configured slot
    local trinketSlot = ATM.db.carrotSlot
    local currentLink = GetInventoryItemLink("player", trinketSlot)
    local context = {
        slot = trinketSlot,
        previousTrinketLink = currentLink,
        previousSetName = ATM:GetEquippedEquipmentSetName(),
        usedEquipmentSet = false,
    }

    if currentLink then
        ATM.savedTrinket = {
            itemLink = currentLink,
            slot = trinketSlot
        }
    end

    -- If carrot is in bags, use normal swap logic.
    if carrotBag and carrotSlot then
        ATM:EquipTrinketFromBag(carrotBag, carrotSlot, trinketSlot)
        return
    end

    -- Optional fallback: mount equipment set can fetch items from bank on Ascension.
    local mountSetName = ATM.db.mountEquipmentSetName
    if ATM.db.useMountEquipmentSet and type(mountSetName) == "string" and mountSetName ~= "" then
        if not context.previousSetName and context.previousTrinketLink then
            -- No active set detected: move currently worn trinket into bags first so we can always restore safely.
            local moved = ATM:MoveEquippedItemToBags(trinketSlot)
            if not moved then
                return
            end
        end

        if ATM:UseEquipmentSetByName(mountSetName) then
            context.usedEquipmentSet = true
            context.mountSetName = mountSetName
            ATM.mountSwapContext = context
            return
        end
    end

    -- Neither bag carrot nor equipment-set fallback worked.
    ATM.mountSwapContext = nil
    ATM.savedTrinket = nil
    return
end

-- Restore previous trinket after dismounting
function ATM:RestorePreviousTrinket()
    if ATM.mountSwapContext and ATM.mountSwapContext.usedEquipmentSet then
        local context = ATM.mountSwapContext
        ATM.mountSwapContext = nil

        -- Preferred restore path: reactivate the previously equipped set.
        if context.previousSetName and ATM:UseEquipmentSetByName(context.previousSetName) then
            return
        end

        -- Fallback path: restore trinket directly from bags.
        local savedItemID = GetItemIDFromLink(context.previousTrinketLink)
        if savedItemID then
            local bag, slot = ATM:FindItemInBagsByID(savedItemID)
            if bag and slot then
                ATM:EquipTrinketFromBag(bag, slot, context.slot or ATM.db.carrotSlot)
            end
        end

        return
    end

    if not ATM.savedTrinket then
        return
    end
    
    -- Check if carrot is still equipped
    local trinketSlot = ATM.savedTrinket.slot
    local currentLink = GetInventoryItemLink("player", trinketSlot)
    if not currentLink then
        ATM.savedTrinket = nil
        return
    end
    
    local itemID = GetItemIDFromLink(currentLink)
    if itemID ~= ATM.CARROT_ITEM_ID then
        -- Carrot was already swapped out
        ATM.savedTrinket = nil
        return
    end
    
    -- Find the saved trinket in bags
    local savedItemID = GetItemIDFromLink(ATM.savedTrinket.itemLink)
    local bag, slot = ATM:FindItemInBagsByID(savedItemID)
    if bag and slot then
        -- Found it, swap back
        ATM:EquipTrinketFromBag(bag, slot, trinketSlot)
        ATM.savedTrinket = nil
        return
    end
    
    ATM.savedTrinket = nil
end

-- Manual carrot swap (Alt+click on trinket button)
function ATM:ManualCarrotSwap(trinketSlot)
    -- Find carrot in bags
    local carrotBag, carrotSlot = ATM:FindItemInBagsByID(ATM.CARROT_ITEM_ID)
    
    if not carrotBag then
        return
    end
    
    -- Check if carrot is already equipped in this slot
    local currentLink = GetInventoryItemLink("player", trinketSlot)
    if currentLink then
        local itemID = GetItemIDFromLink(currentLink)
        if itemID == ATM.CARROT_ITEM_ID then
            return
        end
        
        -- Save current trinket for restore on dismount
        ATM.savedTrinket = {
            itemLink = currentLink,
            slot = trinketSlot
        }
    end
    
    -- Equip carrot
    ATM:EquipTrinketFromBag(carrotBag, carrotSlot, trinketSlot)
end

-- Slash command handler
function ATM:SlashCommand(msg)
    msg = msg:lower():trim()
    
    if msg == "show" then
        ATM.db.showButtons = true
        ATM:ApplyContainerVisibility()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Buttons shown.")
    elseif msg == "hide" then
        ATM.db.showButtons = false
        ATM:ApplyContainerVisibility()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Buttons hidden.")
    elseif msg == "" or msg == "config" or msg == "options" then
        -- Open options panel
        InterfaceOptionsFrame_OpenToCategory(ATM.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(ATM.optionsPanel)  -- Call twice for Blizzard bug
    elseif msg == "lock" then
        ATM.db.locked = true
        ATM.container:EnableMouse(false)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Buttons locked.")
    elseif msg == "unlock" then
        ATM.db.locked = false
        ATM.container:EnableMouse(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Buttons unlocked. Drag to reposition.")
    elseif msg:match("^scale%s+") then
        local scale = tonumber(msg:match("^scale%s+([%d%.]+)"))
        if scale and scale >= 0.5 and scale <= 2.0 then
            ATM.db.scale = scale
            ATM.container:SetScale(scale)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Scale set to " .. scale)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[ATM]|r Invalid scale (use 0.5 - 2.0)")
        end
    elseif msg == "horizontal" or msg == "h" then
        ATM.db.orientation = "horizontal"
        ATM:UpdateTrinketButtons()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Orientation: Horizontal")
    elseif msg == "vertical" or msg == "v" then
        ATM.db.orientation = "vertical"
        ATM:UpdateTrinketButtons()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Orientation: Vertical")
    elseif msg == "carrot on" then
        ATM.db.autoCarrot = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Auto-carrot enabled")
    elseif msg == "carrot off" then
        ATM.db.autoCarrot = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Auto-carrot disabled")
    elseif msg == "reset" then
        ATM:ResetToDefaults()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Ascension Trinket Manager v" .. ATM.version)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm|r or |cff00ffff/trinkets|r - Show buttons")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm lock|r - Lock position")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm unlock|r - Unlock position")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm scale <0.5-2.0>|r - Set button scale")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm horizontal|r - Horizontal layout")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm vertical|r - Vertical layout")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm carrot on/off|r - Toggle auto-carrot")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff/atm reset|r - Reset to defaults")
    end
end

-- Reset to default settings
function ATM:ResetToDefaults()
    -- Reset all settings to defaults
    for key, value in pairs(defaultDB) do
        ATM.db[key] = value
    end
    
    -- Reset position
    ATM.container:ClearAllPoints()
    ATM.container:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    ATM.container:SetScale(ATM.db.scale)

    ATM.savedTrinket = nil
    ATM.mountSwapContext = nil
    ATM.wasMounted = IsMounted()
    
    -- Update UI
    ATM:UpdateLayout()
    ATM:UpdateTrinketButtons()
    
    ATM:ApplyContainerVisibility()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Settings reset to defaults.")
end
