-- AutoCollect v1.0 - Ascension
-- Automatically collects appearances and manages collection features
-- Based on AutoCollectAppearance v6.0 by Ashi-Ryu
-- Enhanced by 5tuartw with icon mode, counters, filtering, and loot overlays

local ADDON_NAME = "AutoCollect"
local BUTTON_NAME = "AutoCollectButton"
local ADDON_VERSION = "1.0"
local DB

local function AcceptAppearancePopups()
    for i = 1, STATICPOPUP_NUMDIALOGS do
        local frame = _G["StaticPopup"..i]
        if frame and frame:IsShown() and frame.which then
            local text = frame.text and frame.text:GetText()
            if text and string.find(text, "Are you sure you want to collect the appearance of") then
                if frame.button1 and frame.button1:IsVisible() then
                    frame.button1:Click()
                end
            end
        end
    end
end

-- Hook popup show and also run periodically
hooksecurefunc("StaticPopup_Show", function(name, text, ... )
    C_Timer.After(0.01, AcceptAppearancePopups)
end)

-- Run every frame to catch delayed popups
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", function(_, elapsed)
    AcceptAppearancePopups()
end)

-- Loot overlay system
local lootOverlays = {}
local NUM_LOOT_ITEMS = 16  -- Max loot slots in 3.3.5

-- Quest reward overlay system
local questRewardOverlays = {}
local NUM_QUEST_REWARDS = 10  -- Max quest reward items

-- Loot roll overlay system  
local lootRollOverlays = {}
local NUM_LOOT_ROLLS = 4  -- Max simultaneous group loot rolls

local function UpdateQuestRewardOverlays()
    if not DB or not DB.showLootOverlay then
        -- Hide all overlays if disabled
        for i = 1, NUM_QUEST_REWARDS do
            if questRewardOverlays[i] then
                questRewardOverlays[i]:Hide()
            end
        end
        return
    end
    
    local c = C_AppearanceCollection
    -- Check both reward choice and non-choice rewards
    local numChoices = GetNumQuestChoices()
    local numRewards = GetNumQuestRewards()
    
    -- Handle quest choice rewards (items you can pick one from)
    for i = 1, numChoices do
        local rewardButton = _G["QuestInfoItem" .. i]
        if rewardButton and rewardButton:IsShown() then
            local itemLink = GetQuestItemLink("choice", i)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                    
                    -- Create overlay if needed
                    if not questRewardOverlays[i] then
                        local iconTexture = _G["QuestInfoItem" .. i .. "IconTexture"]
                        if iconTexture then
                            local overlay = rewardButton:CreateTexture(nil, "OVERLAY")
                            overlay:SetTexture("Interface\\Icons\\Spell_ChargePositive")
                            overlay:SetSize(16, 16)
                            overlay:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", 2, -2)
                            overlay:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                            questRewardOverlays[i] = overlay
                        end
                    end
                    
                    -- Show overlay if appearance is uncollected
                    if questRewardOverlays[i] and appearanceID and not c.IsAppearanceCollected(appearanceID) then
                        questRewardOverlays[i]:Show()
                    elseif questRewardOverlays[i] then
                        questRewardOverlays[i]:Hide()
                    end
                else
                    if questRewardOverlays[i] then questRewardOverlays[i]:Hide() end
                end
            else
                if questRewardOverlays[i] then questRewardOverlays[i]:Hide() end
            end
        else
            if questRewardOverlays[i] then questRewardOverlays[i]:Hide() end
        end
    end
    
    -- Hide unused choice reward overlays
    for i = numChoices + 1, NUM_QUEST_REWARDS do
        if questRewardOverlays[i] then
            questRewardOverlays[i]:Hide()
        end
    end
end

local function UpdateLootRollOverlays()
    if not DB or not DB.showLootOverlay then
        -- Hide all overlays if disabled
        for i = 1, NUM_LOOT_ROLLS do
            if lootRollOverlays[i] then
                lootRollOverlays[i]:Hide()
            end
        end
        return
    end
    
    local c = C_AppearanceCollection
    for i = 1, NUM_LOOT_ROLLS do
        local rollFrame = _G["GroupLootFrame" .. i]
        if rollFrame and rollFrame:IsShown() then
            -- Get the item link from the roll frame
            local itemLink = GetLootRollItemLink(rollFrame.rollID)
            
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                    
                    -- Create overlay if needed
                    if not lootRollOverlays[i] then
                        -- Try multiple possible icon frame names for 3.3.5
                        local iconTexture = _G["GroupLootFrame" .. i .. "IconFrame"] or 
                                          _G["GroupLootFrame" .. i .. "Icon"] or
                                          rollFrame.Icon or
                                          rollFrame.IconFrame
                        if iconTexture then
                            local overlay = rollFrame:CreateTexture(nil, "OVERLAY")
                            overlay:SetTexture("Interface\\Icons\\Spell_ChargePositive")
                            overlay:SetSize(16, 16)
                            overlay:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", 2, -2)
                            overlay:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                            lootRollOverlays[i] = overlay
                        end
                    end
                    
                    -- Show overlay if appearance is uncollected
                    if lootRollOverlays[i] and appearanceID and not c.IsAppearanceCollected(appearanceID) then
                        lootRollOverlays[i]:Show()
                    elseif lootRollOverlays[i] then
                        lootRollOverlays[i]:Hide()
                    end
                else
                    if lootRollOverlays[i] then lootRollOverlays[i]:Hide() end
                end
            else
                if lootRollOverlays[i] then lootRollOverlays[i]:Hide() end
            end
        else
            if lootRollOverlays[i] then lootRollOverlays[i]:Hide() end
        end
    end
end

local function UpdateLootOverlays()
    if not DB or not DB.showLootOverlay then
        -- Hide all overlays if disabled
        for i = 1, NUM_LOOT_ITEMS do
            if lootOverlays[i] then
                lootOverlays[i]:Hide()
            end
        end
        return
    end
    
    local c = C_AppearanceCollection
    for i = 1, GetNumLootItems() do
        local lootButton = _G["LootButton" .. i]
        if lootButton and lootButton:IsShown() then
            -- Check if it's an item (has item link) vs currency/money
            local itemLink = GetLootSlotLink(i)
            
            if itemLink and itemLink:match("item:") then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                    
                    -- Create overlay if needed
                    if not lootOverlays[i] then
                        local iconTexture = _G["LootButton" .. i .. "IconTexture"]
                        if iconTexture then
                            local overlay = lootButton:CreateTexture(nil, "OVERLAY")
                            overlay:SetTexture("Interface\\Icons\\Spell_ChargePositive")
                            overlay:SetSize(16, 16)
                            overlay:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", 2, -2)
                            overlay:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                            lootOverlays[i] = overlay
                        end
                    end
                    
                    -- Show overlay if appearance is uncollected
                    if lootOverlays[i] and appearanceID and not c.IsAppearanceCollected(appearanceID) then
                        lootOverlays[i]:Show()
                    elseif lootOverlays[i] then
                        lootOverlays[i]:Hide()
                    end
                else
                    if lootOverlays[i] then lootOverlays[i]:Hide() end
                end
            else
                if lootOverlays[i] then lootOverlays[i]:Hide() end
            end
        else
            if lootOverlays[i] then lootOverlays[i]:Hide() end
        end
    end
end

-- Hook loot window updates
local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("LOOT_OPENED")
lootFrame:RegisterEvent("LOOT_SLOT_CLEARED")
lootFrame:RegisterEvent("LOOT_CLOSED")
lootFrame:SetScript("OnEvent", function(self, event)
    if event == "LOOT_OPENED" then
        C_Timer.After(0.1, UpdateLootOverlays)  -- Small delay for item data to load
    elseif event == "LOOT_SLOT_CLEARED" then
        UpdateLootOverlays()
    elseif event == "LOOT_CLOSED" then
        -- Hide all overlays
        for i = 1, NUM_LOOT_ITEMS do
            if lootOverlays[i] then
                lootOverlays[i]:Hide()
            end
        end
    end
end)

-- Hook quest frame updates for reward overlays
local questFrame = CreateFrame("Frame")
questFrame:RegisterEvent("QUEST_DETAIL")
questFrame:RegisterEvent("QUEST_PROGRESS")
questFrame:RegisterEvent("QUEST_COMPLETE")
questFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(0.1, UpdateQuestRewardOverlays)  -- Small delay for item data to load
end)

-- Hook loot roll updates
local lootRollFrame = CreateFrame("Frame")
lootRollFrame:RegisterEvent("START_LOOT_ROLL")
lootRollFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(0.1, UpdateLootRollOverlays)  -- Small delay for item data to load
end)

-- Create the floating clickable button first
local button = CreateFrame("Button", BUTTON_NAME, UIParent, "UIPanelButtonTemplate")
button:SetSize(120, 30)
button:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Default position
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForDrag("LeftButton")
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Create action-button-like border for icon mode
local border = button:CreateTexture(nil, "BACKGROUND")
border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
border:SetBlendMode("ADD")
border:SetAlpha(0.5)
border:SetAllPoints(button)
button.border = border
border:Hide()

-- Create icon texture
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints(button)
icon:SetTexture("Interface\\Icons\\Spell_ChargePositive")
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop icon edges for better look
button.icon = icon
icon:Hide()  -- Hidden by default

-- Create count text overlay
local countText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
countText:SetPoint("CENTER", button, "CENTER", 0, 0)
countText:SetJustifyH("CENTER")
countText:SetJustifyV("MIDDLE")
button.countText = countText
countText:Hide()

-- Create additional outline text layers for mode 6 (8-direction outline)
local outlineTexts = {}
local offsets = {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
for i, offset in ipairs(offsets) do
    local outline = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    outline:SetPoint("CENTER", button, "CENTER", offset[1], offset[2])
    outline:SetJustifyH("CENTER")
    outline:SetJustifyV("MIDDLE")
    outline:SetTextColor(0, 0, 0, 1)
    outline:Hide()
    outlineTexts[i] = outline
end
button.outlineTexts = outlineTexts

-- Function to apply text style based on mode
local function ApplyCountTextStyle(mode, text)
    mode = mode or 1
    
    -- Hide all outline layers first
    for _, outline in ipairs(button.outlineTexts) do
        outline:Hide()
    end
    
    if mode == 1 then
        -- Larger font with thick outline
        button.countText:SetFontObject(GameFontNormalHuge)
        button.countText:SetTextColor(0, 0, 0, 1)
        button.countText:SetShadowOffset(2, -2)
        button.countText:SetShadowColor(1, 1, 1, 1)
    elseif mode == 2 then
        -- White text with black outline
        button.countText:SetFontObject(GameFontNormalLarge)
        button.countText:SetTextColor(1, 1, 1, 1)
        button.countText:SetShadowOffset(1, -1)
        button.countText:SetShadowColor(0, 0, 0, 1)
    elseif mode == 4 then
        -- Border glow (multiple shadow layers)
        button.countText:SetFontObject(GameFontNormalLarge)
        button.countText:SetTextColor(1, 1, 1, 1)
        button.countText:SetShadowOffset(2, -2)
        button.countText:SetShadowColor(0, 0, 0, 0.8)
    elseif mode == 6 then
        -- Full 8-direction outline
        button.countText:SetFontObject(GameFontNormalLarge)
        button.countText:SetTextColor(1, 1, 1, 1)
        button.countText:SetShadowOffset(0, 0)
        -- Show and configure outline layers
        for _, outline in ipairs(button.outlineTexts) do
            outline:SetFontObject(GameFontNormalLarge)
            outline:SetText(text)
            outline:Show()
        end
    elseif mode == 8 then
        -- GameFontNormalHuge
        button.countText:SetFontObject(GameFontNormalHuge)
        button.countText:SetTextColor(1, 1, 1, 1)
        button.countText:SetShadowOffset(1, -1)
        button.countText:SetShadowColor(0, 0, 0, 1)
    elseif mode == 9 then
        -- Two-tone: white text with colored glow
        button.countText:SetFontObject(GameFontNormalLarge)
        button.countText:SetTextColor(1, 1, 1, 1)
        -- Green glow for collectible items (we'll adjust based on count later)
        button.countText:SetShadowOffset(2, -2)
        button.countText:SetShadowColor(0.2, 1, 0.2, 0.9)
    end
end

-- Store button template textures for toggling
button.templateTextures = {
    button:GetNormalTexture(),
    button:GetPushedTexture(),
    button:GetHighlightTexture(),
    button:GetDisabledTexture()
}

-- Function to get uncollected items list
local function GetUncollectedItems()
    local items = {}
    local c = C_AppearanceCollection
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b) do
            local itemID = GetContainerItemID(b, s)
            if itemID then
                local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                if appearanceID and not c.IsAppearanceCollected(appearanceID) then
                    local itemName, itemLink, itemQuality = GetItemInfo(itemID)
                    if itemName then
                        table.insert(items, {
                            name = itemName,
                            link = itemLink,
                            quality = itemQuality or 1
                        })
                    end
                end
            end
        end
    end
    return items
end

-- Helper function to check if a rarity should be collected based on settings
local function ShouldCollectRarity(quality)
    if not DB or not DB.collectRarities then return true end
    
    if quality == 0 then
        return DB.collectRarities.poor
    elseif quality == 1 then
        return DB.collectRarities.common
    elseif quality == 2 then
        return DB.collectRarities.uncommon
    elseif quality == 3 then
        return DB.collectRarities.rare
    else  -- 4 and above (epic, legendary, artifact, heirloom)
        return DB.collectRarities.epic
    end
end

-- Function to count uncollected appearances in bags
local function CountUncollectedAppearances()
    local items = GetUncollectedItems()
    local willCollectCount = 0
    local wontCollectCount = 0
    
    for _, item in ipairs(items) do
        -- Check if item is bound
        local isBound = false
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                local bagItemLink = GetContainerItemLink(b, s)
                if bagItemLink == item.link then
                    local tooltip = CreateFrame("GameTooltip", "AC_CountTooltip" .. b .. s, nil, "GameTooltipTemplate")
                    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                    tooltip:SetBagItem(b, s)
                    for i = 1, tooltip:NumLines() do
                        local line = _G["AC_CountTooltip" .. b .. s .. "TextLeft" .. i]
                        if line then
                            local text = line:GetText()
                            if text and (string.find(text, "Soulbound") or string.find(text, "Bound to")) then
                                isBound = true
                                break
                            end
                        end
                    end
                    tooltip:Hide()
                    break
                end
            end
            if isBound then break end
        end
        
        -- Count based on whether it will be collected
        if isBound then
            -- Bound items always collected
            willCollectCount = willCollectCount + 1
        elseif ShouldCollectRarity(item.quality) then
            -- Unbound items collected if rarity is enabled
            willCollectCount = willCollectCount + 1
        else
            -- Unbound items with disabled rarity not collected
            wontCollectCount = wontCollectCount + 1
        end
    end
    
    return willCollectCount, wontCollectCount
end

-- Function to update button text/count
local function UpdateButtonDisplay()
    local willCollect, wontCollect = CountUncollectedAppearances()
    local totalCount = willCollect + wontCollect
    
    -- Hide button if count is zero and hideWhenZero is enabled
    if DB.hideWhenZero and totalCount == 0 then
        button:Hide()
        return
    else
        button:Show()
    end
    
    -- Determine display format
    local displayText
    if willCollect == 0 and wontCollect > 0 then
        -- Only excluded items - show in brackets
        displayText = "(" .. wontCollect .. ")"
    elseif wontCollect > 0 then
        -- Mix of will collect and won't collect
        displayText = willCollect .. " (" .. wontCollect .. ")"
    else
        -- Only items that will be collected
        displayText = tostring(willCollect)
    end
    
    if DB.useIcon then
        -- Icon mode: no count text on icon
        button.countText:Hide()
        for _, outline in ipairs(button.outlineTexts) do
            outline:Hide()
        end
    else
        -- Text mode: always show count
        button:SetText(DB.text .. " " .. displayText)
        button.countText:Hide()
        for _, outline in ipairs(button.outlineTexts) do
            outline:Hide()
        end
    end
end

-- Tooltip
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    
    -- Show uncollected items if enabled
    if DB.showItemsInTooltip and DB.showItemsInTooltip > 0 then
        local items = GetUncollectedItems()
        local maxShow = DB.showItemsInTooltip
        local itemCount = #items
        
        if itemCount > 0 then
            -- Separate items into will collect / won't collect based on rarity
            local willCollect = {}
            local wontCollect = {}
            
            for _, item in ipairs(items) do
                -- Check if item is bound
                local isBound = false
                -- We need to scan bags again to check bind status
                for b = 0, 4 do
                    for s = 1, GetContainerNumSlots(b) do
                        local bagItemLink = GetContainerItemLink(b, s)
                        if bagItemLink == item.link then
                            local tooltip = CreateFrame("GameTooltip", "AC_TooltipCheck" .. b .. s, nil, "GameTooltipTemplate")
                            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                            tooltip:SetBagItem(b, s)
                            for i = 1, tooltip:NumLines() do
                                local line = _G["AC_TooltipCheck" .. b .. s .. "TextLeft" .. i]
                                if line then
                                    local text = line:GetText()
                                    if text and (string.find(text, "Soulbound") or string.find(text, "Bound to")) then
                                        isBound = true
                                        break
                                    end
                                end
                            end
                            tooltip:Hide()
                            break
                        end
                    end
                    if isBound then break end
                end
                
                -- Determine if will be collected
                if isBound then
                    -- Bound items always collected
                    table.insert(willCollect, item)
                elseif ShouldCollectRarity(item.quality) then
                    -- Unbound items collected if rarity is enabled
                    table.insert(willCollect, item)
                else
                    -- Unbound items with disabled rarity not collected
                    table.insert(wontCollect, item)
                end
            end
            
            -- Show "Will be collected" section
            if #willCollect > 0 then
                GameTooltip:AddLine("Will be collected:", 0.2, 1, 0.2)
                for i = 1, math.min(#willCollect, maxShow) do
                    local item = willCollect[i]
                    local r, g, b = GetItemQualityColor(item.quality)
                    GameTooltip:AddLine("  " .. item.name, r, g, b)
                end
                if #willCollect > maxShow then
                    GameTooltip:AddLine("  ... and " .. (#willCollect - maxShow) .. " more", 0.7, 0.7, 0.7)
                end
            end
            
            -- Show "Will not be collected" section
            if #wontCollect > 0 then
                GameTooltip:AddLine("Will not be collected:", 1, 0.5, 0.5)
                local remaining = maxShow - math.min(#willCollect, maxShow)
                for i = 1, math.min(#wontCollect, math.max(0, remaining)) do
                    local item = wontCollect[i]
                    local r, g, b = GetItemQualityColor(item.quality)
                    GameTooltip:AddLine("  " .. item.name, r, g, b)
                end
                if #wontCollect > remaining then
                    GameTooltip:AddLine("  ... and " .. (#wontCollect - remaining) .. " more", 0.7, 0.7, 0.7)
                end
            end
        end
    end
    
    -- Show instructions if enabled
    if not DB.hideTooltipInstructions then
        GameTooltip:AddLine("Left-click: Collect appearances", 0.2, 1, 0.2)
        GameTooltip:AddLine("Shift-click: Collect all including unbound", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click and drag: Move button", 0.5, 0.5, 1)
        GameTooltip:AddLine("Right-click: Open settings", 0.5, 0.5, 1)
    end
    
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

button:SetScript("OnDragStart", button.StartMoving)
button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    DB.position = {
        point = point,
        relativeToName = relativeTo and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs
    }
end)

-- Macro logic as OnClick script
button:SetScript("OnClick", function(self, btn)
    if btn == "LeftButton" then
        local forceAll = IsShiftKeyDown()
        local c = C_AppearanceCollection
        local collected = 0
        local skipped = 0
        
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                local itemID = GetContainerItemID(b, s)
                if itemID then
                    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                    if appearanceID and not c.IsAppearanceCollected(appearanceID) then
                        local itemName, itemLink, itemQuality = GetItemInfo(itemID)
                        
                        -- Check if we should collect based on rarity settings
                        local shouldCollect = false
                        if forceAll then
                            shouldCollect = true  -- Shift-click collects everything
                        else
                            -- Check if item is bound
                            local tooltip = CreateFrame("GameTooltip", "AC_CollectTooltip" .. b .. s, nil, "GameTooltipTemplate")
                            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                            tooltip:SetBagItem(b, s)
                            local isBound = false
                            for i = 1, tooltip:NumLines() do
                                local line = _G["AC_CollectTooltip" .. b .. s .. "TextLeft" .. i]
                                if line then
                                    local text = line:GetText()
                                    if text and (string.find(text, "Soulbound") or string.find(text, "Bound to")) then
                                        isBound = true
                                        break
                                    end
                                end
                            end
                            tooltip:Hide()
                            
                            -- Collect if bound OR if rarity is enabled for unbound items
                            if isBound then
                                shouldCollect = true
                            elseif itemQuality and ShouldCollectRarity(itemQuality) then
                                shouldCollect = true
                            end
                        end
                        
                        if shouldCollect then
                            c.CollectItemAppearance(GetContainerItemGUID(b, s))
                            collected = collected + 1
                        else
                            skipped = skipped + 1
                        end
                    end
                end
            end
        end
        
        -- Update counter to reflect collections
        UpdateButtonDisplay()
    elseif btn == "RightButton" then
        -- Open settings panel
        InterfaceOptionsFrame_OpenToCategory("AutoCollect")
        InterfaceOptionsFrame_OpenToCategory("AutoCollect")  -- Called twice to fix Blizzard bug
    end
end)

-- Event frame for bag updates and appearance collection
local bagUpdateFrame = CreateFrame("Frame")
bagUpdateFrame:RegisterEvent("BAG_UPDATE")
bagUpdateFrame:RegisterEvent("APPEARANCE_COLLECTED")
bagUpdateFrame:SetScript("OnEvent", function(self, event)
    -- Small delay to allow item data to load
    C_Timer.After(0.1, UpdateButtonDisplay)
end)

-- Make the button visible on load
button:Show()

-- Event frame for ADDON_LOADED (after button creation)
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == ADDON_NAME then
        AutoCollectDB = AutoCollectDB or {}
        DB = AutoCollectDB
        DB.scale = DB.scale or 1.0
        DB.text = DB.text or "Collect Tmog"
        DB.useIcon = DB.useIcon or false  -- Default to text mode
        DB.hideWhenZero = DB.hideWhenZero or false  -- Default to always show
        -- Rarity-based collection settings (default: collect Uncommon, Rare, Epic only)
        DB.collectRarities = DB.collectRarities or {
            poor = false,      -- Gray (0)
            common = false,    -- White (1)
            uncommon = true,   -- Green (2)
            rare = true,       -- Blue (3)
            epic = true        -- Purple (4+)
        }
        -- Migrate old addUnbound setting if it exists
        if DB.addUnbound ~= nil then
            -- If addUnbound was true, enable all rarities; if false, keep current defaults
            if DB.addUnbound == true then
                DB.collectRarities.poor = true
                DB.collectRarities.common = true
            end
            DB.addUnbound = nil  -- Remove old setting
        end
        DB.hideTooltipInstructions = DB.hideTooltipInstructions or false  -- Default to show instructions
        DB.showItemsInTooltip = DB.showItemsInTooltip or 0  -- Default to 0 (don't show items)
        DB.showLootOverlay = DB.showLootOverlay ~= false  -- Default to true (show overlay)
        DB.countTextMode = DB.countTextMode or 1  -- Default to mode 1 (larger font with thick outline)
        DB.position = DB.position or { point = "CENTER", relativeToName = "UIParent", relativePoint = "CENTER", xOfs = 0, yOfs = 0 }

        -- Apply settings to button
        button:ClearAllPoints()
        button:SetPoint(DB.position.point, DB.position.relativeToName, DB.position.relativePoint, DB.position.xOfs, DB.position.yOfs)
        button:SetScale(DB.scale)
        
        -- Apply icon or text mode
        if DB.useIcon then
            button:SetSize(40, 40)  -- Square for icon
            button:SetText("")
            button.icon:Show()
            button.border:Show()
            -- Hide button template textures to show icon cleanly
            for _, tex in pairs(button.templateTextures) do
                if tex then tex:Hide() end
            end
        else
            button:SetSize(140, 30)  -- Wider rectangle for text + count
            button:SetText(DB.text)
            button.icon:Hide()
            button.border:Hide()
            -- Restore button template textures
            for _, tex in pairs(button.templateTextures) do
                if tex then tex:Show() end
            end
        end
        
        -- Initial count update
        UpdateButtonDisplay()

        -- Create options panel
        local panel = CreateFrame("Frame", "AutoCollectOptions", UIParent)
        panel.name = ADDON_NAME
        InterfaceOptions_AddCategory(panel)

        -- Title
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(ADDON_NAME .. " Options")

        -- Scale Slider
        local slider = CreateFrame("Slider", "AC_ScaleSlider", panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -32)
        slider:SetWidth(200)
        slider:SetMinMaxValues(0.5, 2.0)
        slider:SetValueStep(0.1)
        slider:SetValue(DB.scale)
        _G[slider:GetName() .. "Low"]:SetText("0.5")
        _G[slider:GetName() .. "High"]:SetText("2.0")
        _G[slider:GetName() .. "Text"]:SetText("Button Scale")
        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value * 10 + 0.5) / 10  -- Round to 1 decimal place
            DB.scale = value
            button:SetScale(value)
            self.tooltipText = tostring(value)  -- Optional: Show current value in tooltip if desired
        end)

        -- Icon Mode Checkbox
        local checkbox = CreateFrame("CheckButton", "AC_IconCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -16)
        _G[checkbox:GetName() .. "Text"]:SetText("Use Icon Instead of Text")
        checkbox:SetChecked(DB.useIcon)
        checkbox:SetScript("OnClick", function(self)
            DB.useIcon = self:GetChecked()
            if DB.useIcon then
                button:SetSize(40, 40)  -- Square for icon
                button:SetText("")
                button.icon:Show()
                button.border:Show()
                -- Hide button template textures to show icon cleanly
                for _, tex in pairs(button.templateTextures) do
                    if tex then tex:Hide() end
                end
            else
                button:SetSize(140, 30)  -- Wider rectangle for text + count
                button:SetText(DB.text)
                button.icon:Hide()
                button.border:Hide()
                -- Restore button template textures
                for _, tex in pairs(button.templateTextures) do
                    if tex then tex:Show() end
                end
            end
            UpdateButtonDisplay()
        end)

        -- Hide When Zero Checkbox
        local hideCheckbox = CreateFrame("CheckButton", "AC_HideCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        hideCheckbox:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -8)
        _G[hideCheckbox:GetName() .. "Text"]:SetText("Hide Button When No Uncollected Items")
        hideCheckbox:SetChecked(DB.hideWhenZero)
        hideCheckbox:SetScript("OnClick", function(self)
            DB.hideWhenZero = self:GetChecked()
            UpdateButtonDisplay()
        end)

        -- Rarity-based collection settings
        local rarityLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        rarityLabel:SetPoint("TOPLEFT", hideCheckbox, "BOTTOMLEFT", 0, -16)
        rarityLabel:SetText("Automatically collect unbound items of these rarities:")
        
        -- First row: Poor, Common, Uncommon
        local poorCheckbox = CreateFrame("CheckButton", "AC_PoorCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        poorCheckbox:SetPoint("TOPLEFT", rarityLabel, "BOTTOMLEFT", 20, -4)
        _G[poorCheckbox:GetName() .. "Text"]:SetText("|cFF9d9d9dPoor|r")
        poorCheckbox:SetChecked(DB.collectRarities.poor)
        poorCheckbox:SetScript("OnClick", function(self)
            DB.collectRarities.poor = self:GetChecked()
            UpdateButtonDisplay()
        end)
        
        local commonCheckbox = CreateFrame("CheckButton", "AC_CommonCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        commonCheckbox:SetPoint("LEFT", poorCheckbox, "RIGHT", 100, 0)
        _G[commonCheckbox:GetName() .. "Text"]:SetText("|cFFffffffCommon|r")
        commonCheckbox:SetChecked(DB.collectRarities.common)
        commonCheckbox:SetScript("OnClick", function(self)
            DB.collectRarities.common = self:GetChecked()
            UpdateButtonDisplay()
        end)
        
        local uncommonCheckbox = CreateFrame("CheckButton", "AC_UncommonCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        uncommonCheckbox:SetPoint("LEFT", commonCheckbox, "RIGHT", 100, 0)
        _G[uncommonCheckbox:GetName() .. "Text"]:SetText("|cFF1eff00Uncommon|r")
        uncommonCheckbox:SetChecked(DB.collectRarities.uncommon)
        uncommonCheckbox:SetScript("OnClick", function(self)
            DB.collectRarities.uncommon = self:GetChecked()
            UpdateButtonDisplay()
        end)
        
        -- Second row: Rare, Epic+
        local rareCheckbox = CreateFrame("CheckButton", "AC_RareCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        rareCheckbox:SetPoint("TOPLEFT", poorCheckbox, "BOTTOMLEFT", 0, -8)
        _G[rareCheckbox:GetName() .. "Text"]:SetText("|cFF0070ddRare|r")
        rareCheckbox:SetChecked(DB.collectRarities.rare)
        rareCheckbox:SetScript("OnClick", function(self)
            DB.collectRarities.rare = self:GetChecked()
            UpdateButtonDisplay()
        end)
        
        local epicCheckbox = CreateFrame("CheckButton", "AC_EpicCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        epicCheckbox:SetPoint("LEFT", rareCheckbox, "RIGHT", 100, 0)
        _G[epicCheckbox:GetName() .. "Text"]:SetText("|cFFa335eeEpic+|r")
        epicCheckbox:SetChecked(DB.collectRarities.epic)
        epicCheckbox:SetScript("OnClick", function(self)
            DB.collectRarities.epic = self:GetChecked()
            UpdateButtonDisplay()
        end)

        -- Hide Tooltip Instructions Checkbox
        local hideInstructionsCheckbox = CreateFrame("CheckButton", "AC_HideInstructionsCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        hideInstructionsCheckbox:SetPoint("TOPLEFT", rareCheckbox, "BOTTOMLEFT", -20, -16)
        _G[hideInstructionsCheckbox:GetName() .. "Text"]:SetText("Hide tooltip instructions")
        hideInstructionsCheckbox:SetChecked(DB.hideTooltipInstructions)
        hideInstructionsCheckbox:SetScript("OnClick", function(self)
            DB.hideTooltipInstructions = self:GetChecked()
        end)

        -- Show Loot Overlay Checkbox
        local lootOverlayCheckbox = CreateFrame("CheckButton", "AC_LootOverlayCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        lootOverlayCheckbox:SetPoint("TOPLEFT", hideInstructionsCheckbox, "BOTTOMLEFT", 0, -8)
        _G[lootOverlayCheckbox:GetName() .. "Text"]:SetText("Show icon on loot window for collectable items")
        lootOverlayCheckbox:SetChecked(DB.showLootOverlay)
        lootOverlayCheckbox:SetScript("OnClick", function(self)
            DB.showLootOverlay = self:GetChecked()
            if LootFrame and LootFrame:IsShown() then
                UpdateLootOverlays()
            end
        end)

        -- Show Items in Tooltip Dropdown
        local dropdownLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        dropdownLabel:SetPoint("TOPLEFT", lootOverlayCheckbox, "BOTTOMLEFT", 0, -16)
        dropdownLabel:SetText("Show items in tooltip:")

        local dropdown = CreateFrame("Frame", "AC_ItemsDropdown", panel, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", dropdownLabel, "BOTTOMLEFT", -15, -4)
        
        local function OnClick(self)
            UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
            DB.showItemsInTooltip = self.value
        end
        
        local function initialize(self, level)
            local info = UIDropDownMenu_CreateInfo()
            
            info.text, info.value, info.func, info.checked = "Don't show items", 0, OnClick, DB.showItemsInTooltip == 0
            info.arg1 = info.value
            UIDropDownMenu_AddButton(info)
            
            info.text, info.value, info.func, info.checked = "Show up to 5 items", 5, OnClick, DB.showItemsInTooltip == 5
            info.arg1 = info.value
            UIDropDownMenu_AddButton(info)
            
            info.text, info.value, info.func, info.checked = "Show up to 10 items", 10, OnClick, DB.showItemsInTooltip == 10
            info.arg1 = info.value
            UIDropDownMenu_AddButton(info)
            
            info.text, info.value, info.func, info.checked = "Show all items", 999, OnClick, DB.showItemsInTooltip == 999
            info.arg1 = info.value
            UIDropDownMenu_AddButton(info)
        end
        
        UIDropDownMenu_Initialize(dropdown, initialize)
        UIDropDownMenu_SetWidth(dropdown, 150)
        
        -- Set initial selection
        if DB.showItemsInTooltip == 0 then
            UIDropDownMenu_SetSelectedID(dropdown, 1)
        elseif DB.showItemsInTooltip == 5 then
            UIDropDownMenu_SetSelectedID(dropdown, 2)
        elseif DB.showItemsInTooltip == 10 then
            UIDropDownMenu_SetSelectedID(dropdown, 3)
        else
            UIDropDownMenu_SetSelectedID(dropdown, 4)
        end

        -- Set initial selection
        local modeToID = {[1]=1, [2]=2, [4]=3, [6]=4, [8]=5, [9]=6}
        -- TODO: countModeDropdown is not defined - feature incomplete
        -- UIDropDownMenu_SetSelectedID(countModeDropdown, modeToID[DB.countTextMode] or 1)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

print("|cFF00FF00AutoCollect v" .. ADDON_VERSION .. " loaded - Auto-collect appearances with enhanced features by 5tuartw (based on AutoCollectAppearance by Ashi-Ryu)|r")