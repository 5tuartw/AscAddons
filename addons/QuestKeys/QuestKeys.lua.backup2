--[[
    QuestKeys - Keyboard shortcuts for quest and gossip interaction
    
    Features:
    - Spacebar: Accept quest, complete quest, continue gossip
    - Number keys (1-9): Select gossip options or quest rewards
    - ESC: Decline quest or close dialog
    
    Built for WoW 3.3.5 (WotLK)
]]--

local ADDON_NAME = "QuestKeys"
local VERSION = "1.0"

-- Saved variables (defaults)
local defaults = {
    enabled = true,
    spacebarAccept = true,
    numberKeysSelect = true,
    escDecline = true,
    debugMode = false,
    showKeyHints = true,
}

-- Runtime state
local DB
local frame = CreateFrame("Frame")
local isProcessingKey = false

-- Debug helper
local function Debug(...)
    if DB and DB.debugMode then
        print("|cff00ff00[QuestKeys]|r", ...)
    end
end

-- Utility: Check if we're at quest/gossip window
local function IsQuestWindowOpen()
    return QuestFrameGreetingPanel:IsVisible() or 
           QuestFrameDetailPanel:IsVisible() or 
           QuestFrameProgressPanel:IsVisible() or 
           QuestFrameRewardPanel:IsVisible() or
           GossipFrame:IsVisible()
end

-- Add key hints to UI elements
local originalButtonTexts = {}
local hintFontStrings = {}

local function ClearKeyHints()
    -- Restore original button texts
    for button, originalText in pairs(originalButtonTexts) do
        if button and button:IsVisible() then
            button:SetText(originalText)
        end
    end
    wipe(originalButtonTexts)
    
    -- Remove hint font strings
    for _, fs in ipairs(hintFontStrings) do
        fs:Hide()
    end
    wipe(hintFontStrings)
end

local function AddKeyHintToButton(button, keyNum)
    if not button or not button:IsVisible() then return end
    
    local originalText = button:GetText()
    if originalText and not originalButtonTexts[button] then
        originalButtonTexts[button] = originalText
        button:SetText("|cff00ff00[" .. keyNum .. "]|r " .. originalText)
    end
end

local function CreateKeyHintLabel(parent, text, anchor, xOffset, yOffset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1, 0.8) -- White with slight transparency
    fs:SetPoint(anchor, parent, anchor, xOffset, yOffset)
    table.insert(hintFontStrings, fs)
    return fs
end

local function UpdateKeyHints()
    if not DB or not DB.showKeyHints or not DB.enabled then
        ClearKeyHints()
        return
    end
    
    ClearKeyHints()
    
    -- Gossip options
    if GossipFrame:IsVisible() then
        local numOptions = GetNumGossipOptions()
        for i = 1, numOptions do
            local button = _G["GossipTitleButton" .. i]
            AddKeyHintToButton(button, i)
        end
        
        -- Active quests
        local numActive = GetNumGossipActiveQuests()
        for i = 1, numActive do
            local button = _G["GossipTitleButton" .. (numOptions + i)]
            AddKeyHintToButton(button, i)
        end
        
        -- Available quests
        local numAvailable = GetNumGossipAvailableQuests()
        for i = 1, numAvailable do
            local button = _G["GossipTitleButton" .. (numOptions + numActive + i)]
            AddKeyHintToButton(button, numActive + i)
        end
        
        -- Goodbye button (if only option, allow interact key)
        if numOptions == 1 and numActive == 0 and numAvailable == 0 then
            local button = _G["GossipTitleButton1"]
            if button then
                local text = button:GetText()
                if text and (text:lower():find("goodbye") or text:lower():find("farewell")) then
                    originalButtonTexts[button] = originalButtonTexts[button] or text
                    button:SetText("|cff00ff00[1]|r " .. originalButtonTexts[button] .. " |cffFFFFFF[SPACE]|r")
                end
            end
        end
        
        -- Check if there's a goodbye button
        if GossipFrameGreetingGoodbyeButton and GossipFrameGreetingGoodbyeButton:IsVisible() then
            CreateKeyHintLabel(GossipFrameGreetingGoodbyeButton, "[ESC]", "LEFT", 5, 0)
        end
    end
    
    -- Quest greeting (multiple quests from same NPC)
    if QuestFrameGreetingPanel:IsVisible() then
        local numActive = GetNumActiveQuests()
        for i = 1, numActive do
            local button = _G["QuestTitleButton" .. i]
            AddKeyHintToButton(button, i)
        end
        
        local numAvailable = GetNumAvailableQuests()
        for i = 1, numAvailable do
            local button = _G["QuestTitleButton" .. (numActive + i)]
            AddKeyHintToButton(button, numActive + i)
        end
    end
    
    -- Quest rewards
    if QuestFrameRewardPanel:IsVisible() then
        local numChoices = GetNumQuestChoices()
        for i = 1, numChoices do
            local itemName = _G["QuestInfoItem" .. i .. "Name"]
            if itemName and itemName:IsVisible() then
                local originalText = itemName:GetText()
                if originalText and not originalButtonTexts[itemName] then
                    originalButtonTexts[itemName] = originalText
                    itemName:SetText("|cff00ff00[" .. i .. "]|r " .. originalText)
                end
            end
        end
        
        -- Add hint label next to Complete button
        if DB.spacebarAccept and QuestFrameCompleteQuestButton then
            CreateKeyHintLabel(QuestFrameCompleteQuestButton, "[SPACE]", "LEFT", 5, 0)
        end
    end
    
    -- Quest accept/decline buttons
    if QuestFrameDetailPanel:IsVisible() then
        if DB.spacebarAccept and QuestFrameAcceptButton then
            CreateKeyHintLabel(QuestFrameAcceptButton, "[SPACE]", "LEFT", 5, 0)
        end
        
        if QuestFrameDeclineButton then
            CreateKeyHintLabel(QuestFrameDeclineButton, "[ESC]", "RIGHT", -5, 0)
        end
    end
    
    -- Quest complete button (progress screen)
    if QuestFrameProgressPanel:IsVisible() and DB.spacebarAccept and IsQuestCompletable() then
        if QuestFrameCompleteButton then
            CreateKeyHintLabel(QuestFrameCompleteButton, "[SPACE]", "LEFT", 5, 0)
        end
    end
end

-- Handler: Spacebar for accept/continue/complete
local function HandleSpacebar()
    if not DB or not DB.spacebarAccept or isProcessingKey then return end
    
    isProcessingKey = true
    
    -- Quest detail (accept new quest)
    if QuestFrameDetailPanel:IsVisible() then
        Debug("Accepting quest")
        AcceptQuest()
        
    -- Quest progress (turn in - with items)
    elseif QuestFrameProgressPanel:IsVisible() then
        if IsQuestCompletable() then
            Debug("Completing quest (progress)")
            CompleteQuest()
        end
        
    -- Quest reward (choose reward)
    elseif QuestFrameRewardPanel:IsVisible() then
        local numChoices = GetNumQuestChoices()
        if numChoices <= 1 then
            -- Auto-select if 0 or 1 choice
            Debug("Getting quest reward (auto)")
            GetQuestReward(1)
        end
        
    -- Gossip window
    elseif GossipFrame:IsVisible() then
        local numOptions = GetNumGossipOptions()
        local numActive = GetNumGossipActiveQuests()
        local numAvailable = GetNumGossipAvailableQuests()
        
        -- If there's only one option, select it
        if numOptions == 1 and numActive == 0 and numAvailable == 0 then
            Debug("Selecting single gossip option")
            SelectGossipOption(1)
        elseif numActive == 1 and numOptions == 0 and numAvailable == 0 then
            Debug("Selecting single active quest")
            SelectGossipActiveQuest(1)
        elseif numAvailable == 1 and numOptions == 0 and numActive == 0 then
            Debug("Selecting single available quest")
            SelectGossipAvailableQuest(1)
        end
        
    -- Quest greeting (multiple quests from NPC)
    elseif QuestFrameGreetingPanel:IsVisible() then
        local numActive = GetNumActiveQuests()
        local numAvailable = GetNumAvailableQuests()
        
        if numActive == 1 and numAvailable == 0 then
            Debug("Selecting single active quest")
            SelectActiveQuest(1)
        elseif numAvailable == 1 and numActive == 0 then
            Debug("Selecting single available quest")
            SelectAvailableQuest(1)
        end
    end
    
    C_Timer.After(0.1, function() isProcessingKey = false end)
end

-- Handler: Number keys for selection
local function HandleNumberKey(num)
    if not DB or not DB.numberKeysSelect or isProcessingKey then return end
    
    isProcessingKey = true
    
    -- Quest reward selection
    if QuestFrameRewardPanel:IsVisible() then
        local numChoices = GetNumQuestChoices()
        if num <= numChoices then
            Debug("Selecting reward", num)
            GetQuestReward(num)
        end
        
    -- Gossip options
    elseif GossipFrame:IsVisible() then
        local numOptions = GetNumGossipOptions()
        if num <= numOptions then
            Debug("Selecting gossip option", num)
            SelectGossipOption(num)
        else
            -- Try active quests
            local numActive = GetNumGossipActiveQuests()
            if num <= numActive then
                Debug("Selecting active quest", num)
                SelectGossipActiveQuest(num)
            else
                -- Try available quests
                local numAvailable = GetNumGossipAvailableQuests()
                local availableIndex = num - numActive
                if availableIndex > 0 and availableIndex <= numAvailable then
                    Debug("Selecting available quest", availableIndex)
                    SelectGossipAvailableQuest(availableIndex)
                end
            end
        end
        
    -- Quest greeting (multiple quests)
    elseif QuestFrameGreetingPanel:IsVisible() then
        local numActive = GetNumActiveQuests()
        if num <= numActive then
            Debug("Selecting active quest", num)
            SelectActiveQuest(num)
        else
            local numAvailable = GetNumAvailableQuests()
            local availableIndex = num - numActive
            if availableIndex > 0 and availableIndex <= numAvailable then
                Debug("Selecting available quest", availableIndex)
                SelectAvailableQuest(availableIndex)
            end
        end
    end
    
    C_Timer.After(0.1, function() isProcessingKey = false end)
end

-- Set up key bindings using 3.3.5 compatible method  
local function SetupKeyBindings()
    -- Use OnUpdate to poll for specific keys - doesn't block anything!
    local pollFrame = CreateFrame("Frame")
    local lastKeys = {}
    
    pollFrame:SetScript("OnUpdate", function(self, elapsed)
        if not DB or not DB.enabled or not IsQuestWindowOpen() then 
            wipe(lastKeys)
            return 
        end
        
        -- Check SPACE
        if IsKeyDown(57) then -- Spacebar keycode
            if not lastKeys[57] and DB.spacebarAccept then
                lastKeys[57] = true
                HandleSpacebar()
            end
        else
            lastKeys[57] = false
        end
        
        -- Check ESC
        if IsKeyDown(1) then -- ESC keycode
            if not lastKeys[1] then
                lastKeys[1] = true
                if QuestFrame:IsVisible() then
                    if QuestFrameDetailPanel:IsVisible() and DB.escDecline then
                        Debug("Declining quest")
                        DeclineQuest()
                    else
                        Debug("Closing quest frame")
                        HideUIPanel(QuestFrame)
                    end
                elseif GossipFrame:IsVisible() then
                    Debug("Closing gossip")
                    CloseGossip()
                end
            end
        else
            lastKeys[1] = false
        end
        
        -- Check number keys (1-9)
        if DB.numberKeysSelect then
            for i = 1, 9 do
                local keycode = i + 1  -- Key codes: 2=1, 3=2, etc.
                if IsKeyDown(keycode) then
                    if not lastKeys[keycode] then
                        lastKeys[keycode] = true
                        HandleNumberKey(i)
                    end
                else
                    lastKeys[keycode] = false
                end
            end
        end
    end)
end

-- Slash commands
SLASH_QUESTKEYS1 = "/questkeys"
SLASH_QUESTKEYS2 = "/qk"
SlashCmdList["QUESTKEYS"] = function(msg)
    if not DB then
        print("|cff00ff00[QuestKeys]|r Not initialized yet. Please wait a moment and try again.")
        return
    end
    
    msg = msg:lower():trim()
    
    if msg == "" or msg == "help" then
        print("|cff00ff00QuestKeys v" .. VERSION .. "|r")
        print("  |cffFFFF00/qk toggle|r - Enable/disable addon")
        print("  |cffFFFF00/qk hints|r - Toggle key hint overlays")
        print("  |cffFFFF00/qk debug|r - Toggle debug mode")
        print("  |cffFFFF00/qk status|r - Show current settings")
        print("")
        print("Keybinds:")
        print("  |cffFFFF00Spacebar|r - Accept/complete/continue")
        print("  |cffFFFF001-9|r - Select gossip option or quest reward")
        print("  |cffFFFF00ESC|r - Decline quest or close dialog")
        
    elseif msg == "toggle" then
        DB.enabled = not DB.enabled
        print("|cff00ff00[QuestKeys]|r", DB.enabled and "Enabled" or "Disabled")
        
    elseif msg == "debug" then
        DB.debugMode = not DB.debugMode
        print("|cff00ff00[QuestKeys]|r Debug mode:", DB.debugMode and "ON" or "OFF")
        
    elseif msg == "hints" then
        DB.showKeyHints = not DB.showKeyHints
        print("|cff00ff00[QuestKeys]|r Key hints:", DB.showKeyHints and "ON" or "OFF")
        if IsQuestWindowOpen() then
            UpdateKeyHints()
        end
        
    elseif msg == "status" then
        print("|cff00ff00[QuestKeys]|r Status:")
        print("  Enabled:", DB.enabled and "Yes" or "No")
        print("  Spacebar Accept:", DB.spacebarAccept and "Yes" or "No")
        print("  Number Keys:", DB.numberKeysSelect and "Yes" or "No")
        print("  ESC Decline:", DB.escDecline and "Yes" or "No")
        print("  Show Key Hints:", DB.showKeyHints and "Yes" or "No")
        print("  Debug Mode:", DB.debugMode and "Yes" or "No")
    else
        print("|cff00ff00[QuestKeys]|r Unknown command. Type |cffFFFF00/qk help|r")
    end
end

-- Event handler
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize saved variables
        QuestKeysDB = QuestKeysDB or {}
        DB = QuestKeysDB
        
        -- Apply defaults
        for k, v in pairs(defaults) do
            if DB[k] == nil then
                DB[k] = v
            end
        end
        
        print("|cff00ff00[QuestKeys]|r v" .. VERSION .. " loaded. Type |cffFFFF00/qk help|r for commands")
        
    elseif event == "PLAYER_LOGIN" then
        SetupKeyBindings()
        
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or 
           event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or 
           event == "QUEST_COMPLETE" then
        C_Timer.After(0.05, UpdateKeyHints)
    end
end)
