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
    debugMode = true,  -- Temporarily enabled for testing
    showKeyHints = true,
}

-- Runtime state
local DB
local frame = CreateFrame("Frame")
local isProcessingKey = false
local activeChoices = {}
local activeChoiceSignature = nil
local optionWatcherElapsed = 0
local gossipTraceCounter = 0

local MAX_NUMBER_KEYS = 9

local UpdateKeyHints
local RefreshChoicesSoon

-- Debug helper
local function Debug(...)
    if DB and DB.debugMode then
        print("|cff0070dd[QuestKeys]|r", ...)
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

local function StripQuestKeyHintText(text)
    if type(text) ~= "string" then
        return text
    end

    -- Remove QuestKeys suffix/prefix tags while preserving the NPC-provided label.
    text = text:gsub(" |c........%[%d+%]|r$", "")
    text = text:gsub(" |c........%[SPACE%]|r$", "")
    text = text:gsub("^|c........%[%d+%]|r ", "")
    return text
end

local function ClearKeyHints()
    wipe(activeChoices)

    -- Strip QuestKeys hint tags from current text instead of forcing cached labels.
    for button in pairs(originalButtonTexts) do
        if button and button.GetText and button.SetText then
            local currentText = button:GetText()
            if currentText then
                button:SetText(StripQuestKeyHintText(currentText))
            end
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
    
    local currentText = button:GetText()
    if not currentText then return end
    
    -- Get original text (strip any existing hint)
    local originalText = originalButtonTexts[button] or currentText
    originalText = StripQuestKeyHintText(originalText)
    
    -- Store original and append new hint
    originalButtonTexts[button] = originalText
    button:SetText(originalText .. " |cff0070dd[" .. keyNum .. "]|r")
end

local function CreateKeyHintLabel(parent, text, anchor, xOffset, yOffset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1, 0.8) -- White with slight transparency
    fs:SetPoint(anchor, parent, anchor, xOffset, yOffset)
    table.insert(hintFontStrings, fs)
    return fs
end

local function SortButtonsByPosition(leftButton, rightButton)
    local leftTop = leftButton:GetTop() or 0
    local rightTop = rightButton:GetTop() or 0

    if math.abs(leftTop - rightTop) > 2 then
        return leftTop > rightTop
    end

    local leftOffset = leftButton:GetLeft() or 0
    local rightOffset = rightButton:GetLeft() or 0
    return leftOffset < rightOffset
end

local function CollectVisibleButtons(prefix, maxButtons)
    local buttons = {}

    for i = 1, maxButtons do
        local button = _G[prefix .. i]
        if button and button:IsVisible() then
            table.insert(buttons, button)
        end
    end

    table.sort(buttons, SortButtonsByPosition)
    return buttons
end

local function BuildChoiceSignature(prefix, maxButtons)
    local buttons = CollectVisibleButtons(prefix, maxButtons)
    local parts = {}

    for index, button in ipairs(buttons) do
        local label = ""
        if button and button.GetText then
            label = button:GetText() or ""
            label = label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            label = label:gsub("%s+", " ")
        end

        parts[#parts + 1] = index .. ":" .. label
    end

    return table.concat(parts, "|")
end

local function ComputeActiveChoiceSignature()
    if GossipFrame:IsVisible() then
        return "gossip|" .. BuildChoiceSignature("GossipTitleButton", 32)
    end

    if QuestFrameGreetingPanel:IsVisible() then
        return "greeting|" .. BuildChoiceSignature("QuestTitleButton", 32)
    end

    return nil
end

local function ShortDebugText(text, maxLen)
    if type(text) ~= "string" then
        return ""
    end

    text = text:gsub("%s+", " ")
    if #text <= maxLen then
        return text
    end

    return text:sub(1, maxLen) .. "..."
end

local function DumpGossipDebugState(reason)
    if not DB or not DB.debugMode then
        return
    end

    if not GossipFrame:IsVisible() then
        Debug("GossipTrace", reason, "(GossipFrame hidden)")
        return
    end

    local numOptions = GetNumGossipOptions()
    local numActive = GetNumGossipActiveQuests()
    local numAvailable = GetNumGossipAvailableQuests()
    local optionsRaw = { GetGossipOptions() }
    local buttons = CollectVisibleButtons("GossipTitleButton", 32)
    local signature = BuildChoiceSignature("GossipTitleButton", 32)

    Debug("GossipTrace", reason,
        "counts:", "opts=" .. numOptions,
        "active=" .. numActive,
        "avail=" .. numAvailable,
        "visibleButtons=" .. #buttons,
        "signature=" .. ShortDebugText(signature, 220)
    )

    local linesToDump = math.min(math.max(numOptions, #buttons), 12)
    for i = 1, linesToDump do
        local button = buttons[i]
        local buttonText = button and StripQuestKeyHintText(button:GetText() or "") or "<none>"
        local buttonName = button and (button:GetName() or "<unnamed>") or "<none>"
        local apiText = "<n/a>"

        if i <= numOptions then
            apiText = StripQuestKeyHintText(optionsRaw[(i * 2) - 1] or "")
        end

        local mismatch = ""
        if i <= numOptions and buttonText ~= apiText then
            mismatch = " MISMATCH"
        end

        Debug("GossipTrace", reason, "line", i,
            "api=", ShortDebugText(apiText, 120),
            "btn=", ShortDebugText(buttonText, 120),
            "button=", buttonName,
            mismatch
        )
    end
end

local function TraceGossipTransition(reason)
    if not DB or not DB.debugMode then
        return
    end

    gossipTraceCounter = gossipTraceCounter + 1
    local traceId = gossipTraceCounter

    DumpGossipDebugState("trace#" .. traceId .. " " .. reason .. " [before]")

    C_Timer.After(0, function()
        if DB and DB.debugMode then
            DumpGossipDebugState("trace#" .. traceId .. " " .. reason .. " [after+0.00]")
        end
    end)

    C_Timer.After(0.05, function()
        if DB and DB.debugMode then
            DumpGossipDebugState("trace#" .. traceId .. " " .. reason .. " [after+0.05]")
        end
    end)

    C_Timer.After(0.20, function()
        if DB and DB.debugMode then
            DumpGossipDebugState("trace#" .. traceId .. " " .. reason .. " [after+0.20]")
        end
    end)
end

local function RegisterChoice(keyNum, button, context)
    activeChoices[keyNum] = {
        keyNum = keyNum,
        context = context,
        button = button,
        buttonName = button and button:GetName() or "<unknown>",
        label = button and button:GetText() or "",
    }

    Debug("Registered choice", keyNum, context, activeChoices[keyNum].buttonName, activeChoices[keyNum].label or "")
end

local function DumpChoiceRegistry()
    if not DB or not DB.debugMode then
        return
    end

    if not next(activeChoices) then
        Debug("Choice registry empty")
        return
    end

    for keyNum, choice in pairs(activeChoices) do
        Debug("Choice", keyNum, "context=", choice.context, "button=", choice.buttonName, "label=", choice.label or "")
    end
end

local function TriggerMappedChoice(keyNum)
    local choice = activeChoices[keyNum]
    if not choice then
        Debug("No mapped choice for key", keyNum)
        return false
    end

    local button = choice.button
    if not button or not button:IsVisible() or not button:IsEnabled() then
        Debug("Mapped button unavailable for key", keyNum, choice.buttonName)
        return false
    end

    Debug("Triggering mapped choice", keyNum, choice.context, choice.buttonName, choice.label or "")

    if choice.context == "gossip" then
        TraceGossipTransition("TriggerMappedChoice key=" .. keyNum)
    end

    if button.Click then
        button:Click()
        if RefreshChoicesSoon then
            RefreshChoicesSoon()
        end
        return true
    end

    local onClick = button:GetScript("OnClick")
    if onClick then
        onClick(button, "LeftButton")
        if RefreshChoicesSoon then
            RefreshChoicesSoon()
        end
        return true
    end

    Debug("Mapped button has no click handler", keyNum, choice.buttonName)
    return false
end

UpdateKeyHints = function()
    if not DB or not DB.enabled then
        ClearKeyHints()
        return
    end
    
    ClearKeyHints()
    local showHints = DB.showKeyHints
    
    -- Gossip options
    if GossipFrame:IsVisible() then
        local numOptions = GetNumGossipOptions()
        local numActive = GetNumGossipActiveQuests()
        local numAvailable = GetNumGossipAvailableQuests()
        local buttons = CollectVisibleButtons("GossipTitleButton", 32)
        
        Debug("Gossip: numOptions=", numOptions, "numActive=", numActive, "numAvailable=", numAvailable)
        
        for keyNum, button in ipairs(buttons) do
            if keyNum > MAX_NUMBER_KEYS then
                break
            end
            RegisterChoice(keyNum, button, "gossip")
            if showHints then
                CreateKeyHintLabel(button, "[" .. keyNum .. "]", "LEFT", 0, 0)
            end
        end

        if #buttons > MAX_NUMBER_KEYS then
            Debug("Gossip has", #buttons, "choices; only first", MAX_NUMBER_KEYS, "are keyboard-bound")
        end
        
        -- Goodbye button (if only option, allow interact key)
        if numOptions == 1 and numActive == 0 and numAvailable == 0 then
            local button = _G["GossipTitleButton1"]
            if button then
                local text = button:GetText()
                if showHints and text and (text:lower():find("goodbye") or text:lower():find("farewell")) then
                    CreateKeyHintLabel(button, "[SPACE]", "RIGHT", -8, 0)
                end
            end
        end
        
    end
    
    -- Quest greeting (multiple quests from same NPC)
    if QuestFrameGreetingPanel:IsVisible() then
        local numActive = GetNumActiveQuests()
        local numAvailable = GetNumAvailableQuests()
        local buttons = CollectVisibleButtons("QuestTitleButton", 32)
        Debug("Quest Greeting - Active:", numActive, "Available:", numAvailable)

        for keyNum, button in ipairs(buttons) do
            if keyNum > MAX_NUMBER_KEYS then
                break
            end
            RegisterChoice(keyNum, button, "questGreeting")
            if showHints then
                CreateKeyHintLabel(button, "[" .. keyNum .. "]", "LEFT", 0, 0)
            end
        end

        if #buttons > MAX_NUMBER_KEYS then
            Debug("Quest greeting has", #buttons, "choices; only first", MAX_NUMBER_KEYS, "are keyboard-bound")
        end
    end

    activeChoiceSignature = ComputeActiveChoiceSignature()

    if GossipFrame:IsVisible() and DB and DB.debugMode then
        DumpGossipDebugState("UpdateKeyHints complete")
    end

    DumpChoiceRegistry()
    
    -- Quest rewards
    if QuestFrameRewardPanel:IsVisible() then
        local numChoices = GetNumQuestChoices()
        if showHints then
            for i = 1, numChoices do
                local itemName = _G["QuestInfoItem" .. i .. "Name"]
                if itemName and itemName:IsVisible() then
                    local originalText = itemName:GetText()
                    if originalText and not originalButtonTexts[itemName] then
                        originalButtonTexts[itemName] = originalText
                        itemName:SetText("|cff0070dd[" .. i .. "]|r " .. originalText)
                    end
                end
            end
        end
        
        -- Only show [SPACE] hint if 0 or 1 choice (auto-selectable)
        if showHints and DB.spacebarAccept and QuestFrameCompleteQuestButton and numChoices <= 1 then
            CreateKeyHintLabel(QuestFrameCompleteQuestButton, "[SPACE]", "LEFT", QuestFrameCompleteQuestButton:GetWidth() + 5, 0)
        end
    end
    
    -- Quest accept/decline buttons
    if QuestFrameDetailPanel:IsVisible() then
        if showHints and DB.spacebarAccept and QuestFrameAcceptButton then
            CreateKeyHintLabel(QuestFrameAcceptButton, "[SPACE]", "LEFT", QuestFrameAcceptButton:GetWidth() + 5, 0)
        end
    end
    
    -- Quest complete button (progress screen)
    if showHints and QuestFrameProgressPanel:IsVisible() and DB.spacebarAccept and IsQuestCompletable() then
        if QuestFrameCompleteButton then
            CreateKeyHintLabel(QuestFrameCompleteButton, "[SPACE]", "LEFT", QuestFrameCompleteButton:GetWidth() + 5, 0)
        end
    end
end

RefreshChoicesSoon = function()
    C_Timer.After(0.05, function()
        if DB and DB.enabled and IsQuestWindowOpen() then
            UpdateKeyHints()
        end
    end)
end

-- Handler: Spacebar for accept/continue/complete
local function HandleSpacebar()
    if not DB or not DB.spacebarAccept or isProcessingKey then return end
    
    isProcessingKey = true
    local handledChoice = false
    
    -- Quest detail (accept new quest)
    if QuestFrameDetailPanel:IsVisible() then
        Debug("Accepting quest")
        AcceptQuest()
        handledChoice = true
        
    -- Quest progress (turn in - with items)
    elseif QuestFrameProgressPanel:IsVisible() then
        if IsQuestCompletable() then
            Debug("Completing quest (progress)")
            CompleteQuest()
            handledChoice = true
        end
        
    -- Quest reward (choose reward)
    elseif QuestFrameRewardPanel:IsVisible() then
        local numChoices = GetNumQuestChoices()
        if numChoices <= 1 then
            -- Auto-select if 0 or 1 choice
            Debug("Getting quest reward (auto)")
            GetQuestReward(1)
            handledChoice = true
        end
        
    -- Gossip window
    elseif GossipFrame:IsVisible() then
        if not TriggerMappedChoice(1) then
            local numOptions = GetNumGossipOptions()
            local numActive = GetNumGossipActiveQuests()
            local numAvailable = GetNumGossipAvailableQuests()

            -- Select first available option (gossip option, then active quest, then available quest)
            if numOptions > 0 then
                Debug("Selecting first gossip option")
                SelectGossipOption(1)
                handledChoice = true
            elseif numActive > 0 then
                Debug("Selecting first active quest")
                SelectGossipActiveQuest(1)
                handledChoice = true
            elseif numAvailable > 0 then
                Debug("Selecting first available quest")
                SelectGossipAvailableQuest(1)
                handledChoice = true
            end
        else
            handledChoice = true
        end
        
    -- Quest greeting (multiple quests from NPC)
    elseif QuestFrameGreetingPanel:IsVisible() then
        if not TriggerMappedChoice(1) then
            local numActive = GetNumActiveQuests()
            local numAvailable = GetNumAvailableQuests()

            -- Select first visible option if we failed to map one directly.
            if numAvailable > 0 then
                Debug("Selecting first available quest")
                SelectAvailableQuest(1)
                handledChoice = true
            elseif numActive > 0 then
                Debug("Selecting first active quest")
                SelectActiveQuest(1)
                handledChoice = true
            end
        else
            handledChoice = true
        end
    end

    if handledChoice and RefreshChoicesSoon then
        RefreshChoicesSoon()
    end
    
    C_Timer.After(0.1, function() isProcessingKey = false end)
end

-- Handler: Number keys for selection
local function HandleNumberKey(num)
    if not DB or not DB.numberKeysSelect or isProcessingKey then return end
    
    isProcessingKey = true
    local handledChoice = false
    
    -- Quest reward selection
    if QuestFrameRewardPanel:IsVisible() then
        local numChoices = GetNumQuestChoices()
        if num <= numChoices then
            Debug("Selecting reward", num)
            GetQuestReward(num)
            handledChoice = true
        end
        
    -- Gossip window
    elseif GossipFrame:IsVisible() then
        if TriggerMappedChoice(num) then
            C_Timer.After(0.1, function() isProcessingKey = false end)
            return
        end
        
    -- Quest greeting (multiple quests)
    elseif QuestFrameGreetingPanel:IsVisible() then
        Debug("Quest Greeting: pressing key", num)

        if TriggerMappedChoice(num) then
            C_Timer.After(0.1, function() isProcessingKey = false end)
            return
        end
    end

    if handledChoice and RefreshChoicesSoon then
        RefreshChoicesSoon()
    end
    
    C_Timer.After(0.1, function() isProcessingKey = false end)
end

-- Create invisible buttons for keybinding
local spaceButton = CreateFrame("Button", "QuestKeysSpaceButton", UIParent)
spaceButton:SetScript("OnClick", function() HandleSpacebar() end)
spaceButton:RegisterForClicks("AnyDown")

local numberButtons = {}
for i = 1, 9 do
    numberButtons[i] = CreateFrame("Button", "QuestKeysNum" .. i .. "Button", UIParent)
    numberButtons[i]:SetScript("OnClick", function() HandleNumberKey(i) end)
    numberButtons[i]:RegisterForClicks("AnyDown")
end

-- Set up key bindings using SetOverrideBinding
local function SetupKeyBindings()
    Debug("SetupKeyBindings called")
end

local function BindKeys()
    if not DB or not DB.enabled then return end
    
    Debug("Binding keys for quest window")
    
    -- Bind spacebar
    if DB.spacebarAccept then
        SetOverrideBindingClick(frame, true, "SPACE", "QuestKeysSpaceButton")
        Debug("Bound SPACE")
    end
    
    -- Bind number keys
    if DB.numberKeysSelect then
        for i = 1, 9 do
            SetOverrideBindingClick(frame, true, tostring(i), "QuestKeysNum" .. i .. "Button")
        end
        Debug("Bound number keys 1-9")
    end
end

local function UnbindKeys()
    Debug("Unbinding keys")
    ClearOverrideBindings(frame)
    ClearKeyHints()
end

frame:SetScript("OnUpdate", function(self, elapsed)
    if not DB or not DB.enabled or isProcessingKey then
        return
    end

    if not GossipFrame:IsVisible() and not QuestFrameGreetingPanel:IsVisible() then
        activeChoiceSignature = nil
        optionWatcherElapsed = 0
        return
    end

    optionWatcherElapsed = optionWatcherElapsed + elapsed
    if optionWatcherElapsed < 0.15 then
        return
    end

    optionWatcherElapsed = 0

    local currentSignature = ComputeActiveChoiceSignature()
    if currentSignature and currentSignature ~= activeChoiceSignature then
        Debug("Detected dialogue option page change; refreshing key bindings")
        if DB and DB.debugMode and GossipFrame:IsVisible() then
            Debug("Signature old:", ShortDebugText(activeChoiceSignature or "<nil>", 220))
            Debug("Signature new:", ShortDebugText(currentSignature, 220))
            DumpGossipDebugState("OnUpdate signature changed (before refresh)")
        end
        UpdateKeyHints()
    end
end)

-- Initialize DB immediately
QuestKeysDB = QuestKeysDB or {}
DB = QuestKeysDB
for k, v in pairs(defaults) do
    if DB[k] == nil then
        DB[k] = v
    end
end

-- Slash commands
SLASH_QUESTKEYS1 = "/questkeys"
SLASH_QUESTKEYS2 = "/qk"
SlashCmdList["QUESTKEYS"] = function(msg)
    if not DB then
        print("|cff0070dd[QuestKeys]|r Not initialized yet. Please wait a moment and try again.")
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
        print("|cff0070dd[QuestKeys]|r", DB.enabled and "Enabled" or "Disabled")
        
    elseif msg == "debug" then
        DB.debugMode = not DB.debugMode
        print("|cff0070dd[QuestKeys]|r Debug mode:", DB.debugMode and "ON" or "OFF")
        
    elseif msg == "hints" then
        DB.showKeyHints = not DB.showKeyHints
        print("|cff0070dd[QuestKeys]|r Key hints:", DB.showKeyHints and "ON" or "OFF")
        if IsQuestWindowOpen() then
            UpdateKeyHints()
        end
        
    elseif msg == "status" then
        print("|cff0070dd[QuestKeys]|r Status:")
        print("  Enabled:", DB.enabled and "Yes" or "No")
        print("  Spacebar Accept:", DB.spacebarAccept and "Yes" or "No")
        print("  Number Keys:", DB.numberKeysSelect and "Yes" or "No")
        print("  ESC Decline:", DB.escDecline and "Yes" or "No")
        print("  Show Key Hints:", DB.showKeyHints and "Yes" or "No")
        print("  Debug Mode:", DB.debugMode and "Yes" or "No")
    else
        print("|cff0070dd[QuestKeys]|r Unknown command. Type |cffFFFF00/qk help|r")
    end
end

-- Event handler
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("QUEST_ACCEPTED")  -- Refresh when quest is accepted
frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat

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
        
        print("|cff0070dd[QuestKeys]|r v" .. VERSION .. " loaded. Type |cffFFFF00/qk help|r for commands")
        
    elseif event == "PLAYER_LOGIN" then
        SetupKeyBindings()
        
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or 
           event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or 
           event == "QUEST_COMPLETE" then
        ClearKeyHints()
        C_Timer.After(0.1, UpdateKeyHints)
        BindKeys()
        
    elseif event == "QUEST_ACCEPTED" then
        -- When a quest is accepted, refresh the greeting panel if it's still open
        if QuestFrameGreetingPanel:IsVisible() then
            Debug("Quest accepted, refreshing greeting panel hints")
            ClearKeyHints()
            C_Timer.After(0.1, UpdateKeyHints)
        end
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: unbind keys to prevent them getting stuck
        Debug("Entering combat, unbinding keys")
        UnbindKeys()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat: rebind keys if quest window still open
        Debug("Leaving combat")
        if IsQuestWindowOpen() then
            Debug("Quest window still open, rebinding keys")
            C_Timer.After(0.1, function()
                if IsQuestWindowOpen() then
                    BindKeys()
                end
            end)
        end
        
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
        UnbindKeys()
    end
end)
