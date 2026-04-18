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
    hintMode = "overlay", -- overlay | inline (for option hints)
    overlayOffsetX = 0,
    overlayOffsetY = 0,
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
local OVERLAY_OFFSET_MIN = -30
local OVERLAY_OFFSET_MAX = 30

local UpdateKeyHints
local RefreshChoicesSoon
local OpenOptionsPanel

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

local function ClampOverlayOffset(value)
    if value < OVERLAY_OFFSET_MIN then
        return OVERLAY_OFFSET_MIN
    end
    if value > OVERLAY_OFFSET_MAX then
        return OVERLAY_OFFSET_MAX
    end
    return value
end

local function CreateOffsetOverlayHintLabel(parent, text, anchor, xOffset, yOffset)
    local offsetX = DB and DB.overlayOffsetX or 0
    local offsetY = DB and DB.overlayOffsetY or 0
    return CreateKeyHintLabel(parent, text, anchor, xOffset + offsetX, yOffset + offsetY)
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
    local useInlineOptionHints = DB.hintMode == "inline"
    
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
                if useInlineOptionHints then
                    AddKeyHintToButton(button, keyNum)
                else
                    CreateOffsetOverlayHintLabel(button, "[" .. keyNum .. "]", "LEFT", 0, 0)
                end
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
                    if useInlineOptionHints then
                        AddKeyHintToButton(button, "SPACE")
                    else
                        CreateOffsetOverlayHintLabel(button, "[SPACE]", "RIGHT", -8, 0)
                    end
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
                if useInlineOptionHints then
                    AddKeyHintToButton(button, keyNum)
                else
                    CreateOffsetOverlayHintLabel(button, "[" .. keyNum .. "]", "LEFT", 0, 0)
                end
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
            CreateOffsetOverlayHintLabel(QuestFrameCompleteQuestButton, "[SPACE]", "LEFT", QuestFrameCompleteQuestButton:GetWidth() + 5, 0)
        end
    end
    
    -- Quest accept/decline buttons
    if QuestFrameDetailPanel:IsVisible() then
        if showHints and DB.spacebarAccept and QuestFrameAcceptButton then
            CreateOffsetOverlayHintLabel(QuestFrameAcceptButton, "[SPACE]", "LEFT", QuestFrameAcceptButton:GetWidth() + 5, 0)
        end
    end
    
    -- Quest complete button (progress screen)
    if showHints and QuestFrameProgressPanel:IsVisible() and DB.spacebarAccept and IsQuestCompletable() then
        if QuestFrameCompleteButton then
            CreateOffsetOverlayHintLabel(QuestFrameCompleteButton, "[SPACE]", "LEFT", QuestFrameCompleteButton:GetWidth() + 5, 0)
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

DB.hintMode = DB.hintMode == "inline" and "inline" or "overlay"
DB.overlayOffsetX = ClampOverlayOffset(tonumber(DB.overlayOffsetX) or 0)
DB.overlayOffsetY = ClampOverlayOffset(tonumber(DB.overlayOffsetY) or 0)

local optionsPanel
local optionsInlineCheck
local optionsOverlayXSlider
local optionsOverlayYSlider
local optionsSyncing = false

local function RefreshOptionsPanel()
    if not optionsPanel or not optionsPanel.initialized or not DB then
        return
    end

    optionsSyncing = true

    optionsInlineCheck:SetChecked(DB.hintMode == "inline")
    optionsOverlayXSlider:SetValue(DB.overlayOffsetX or 0)
    optionsOverlayYSlider:SetValue(DB.overlayOffsetY or 0)

    local overlayEnabled = DB.hintMode ~= "inline"
    if overlayEnabled then
        optionsOverlayXSlider:Enable()
        optionsOverlayYSlider:Enable()
        optionsOverlayXSlider:SetAlpha(1)
        optionsOverlayYSlider:SetAlpha(1)
    else
        optionsOverlayXSlider:Disable()
        optionsOverlayYSlider:Disable()
        optionsOverlayXSlider:SetAlpha(0.45)
        optionsOverlayYSlider:SetAlpha(0.45)
    end

    optionsSyncing = false
end

local function CreateOverlayOffsetSlider(parent, name, label, yOffset)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(260)
    slider:SetHeight(16)
    slider:SetPoint("TOPLEFT", 16, yOffset)
    slider:SetMinMaxValues(OVERLAY_OFFSET_MIN, OVERLAY_OFFSET_MAX)
    slider:SetValueStep(1)

    _G[name .. "Low"]:SetText(tostring(OVERLAY_OFFSET_MIN))
    _G[name .. "High"]:SetText(tostring(OVERLAY_OFFSET_MAX))
    _G[name .. "Text"]:SetText(label)

    return slider
end

local function CreateOptionsPanel()
    if optionsPanel then
        return
    end

    optionsPanel = CreateFrame("Frame", "QuestKeysOptionsPanel", UIParent)
    optionsPanel.name = "QuestKeys"

    optionsPanel:SetScript("OnShow", function(self)
        if not self.initialized then
            local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 16, -16)
            title:SetText("QuestKeys")

            local subtitle = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
            subtitle:SetText("Hint mode controls for gossip and quest greeting option labels.")

            optionsInlineCheck = CreateFrame("CheckButton", "QuestKeysInlineHintsCheck", self, "InterfaceOptionsCheckButtonTemplate")
            optionsInlineCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
            _G[optionsInlineCheck:GetName() .. "Text"]:SetText("Inline option hints (append [1]-[9] to option text)")
            optionsInlineCheck:SetScript("OnClick", function(button)
                if optionsSyncing or not DB then
                    return
                end

                DB.hintMode = button:GetChecked() and "inline" or "overlay"
                RefreshOptionsPanel()
                if IsQuestWindowOpen() then
                    UpdateKeyHints()
                end
            end)

            local modeNote = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            modeNote:SetPoint("TOPLEFT", optionsInlineCheck, "BOTTOMLEFT", 0, -6)
            modeNote:SetText("Overlay mode keeps hints separate from NPC text and is safer for multi-page gossip.")

            optionsOverlayXSlider = CreateOverlayOffsetSlider(self, "QuestKeysOverlayXOffsetSlider", "Overlay X Offset", -120)
            optionsOverlayYSlider = CreateOverlayOffsetSlider(self, "QuestKeysOverlayYOffsetSlider", "Overlay Y Offset", -180)

            optionsOverlayXSlider:SetScript("OnValueChanged", function(slider, value)
                if optionsSyncing or not DB then
                    return
                end

                local rounded = ClampOverlayOffset(math.floor(value + (value >= 0 and 0.5 or -0.5)))
                if rounded ~= value then
                    optionsSyncing = true
                    slider:SetValue(rounded)
                    optionsSyncing = false
                end

                if DB.overlayOffsetX ~= rounded then
                    DB.overlayOffsetX = rounded
                    if IsQuestWindowOpen() then
                        UpdateKeyHints()
                    end
                end
            end)

            optionsOverlayYSlider:SetScript("OnValueChanged", function(slider, value)
                if optionsSyncing or not DB then
                    return
                end

                local rounded = ClampOverlayOffset(math.floor(value + (value >= 0 and 0.5 or -0.5)))
                if rounded ~= value then
                    optionsSyncing = true
                    slider:SetValue(rounded)
                    optionsSyncing = false
                end

                if DB.overlayOffsetY ~= rounded then
                    DB.overlayOffsetY = rounded
                    if IsQuestWindowOpen() then
                        UpdateKeyHints()
                    end
                end
            end)

            local sliderNote = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            sliderNote:SetPoint("TOPLEFT", optionsOverlayYSlider, "BOTTOMLEFT", 0, -10)
            sliderNote:SetText("Offsets apply to overlay labels only.")

            self.initialized = true
        end

        RefreshOptionsPanel()
    end)

    InterfaceOptions_AddCategory(optionsPanel)
end

OpenOptionsPanel = function()
    if not optionsPanel then
        CreateOptionsPanel()
    end

    if not optionsPanel then
        return
    end

    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
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
        print("  |cffFFFF00/qk hints|r - Toggle key hints on/off")
        print("  |cffFFFF00/qk mode <overlay|inline>|r - Set option hint style")
        print("  |cffFFFF00/qk offset <x> <y>|r - Set overlay hint offsets (-30 to 30)")
        print("  |cffFFFF00/qk options|r - Open Interface Options panel")
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

    elseif msg == "options" then
        OpenOptionsPanel()

    elseif msg == "mode" then
        print("|cff0070dd[QuestKeys]|r Current hint mode:", DB.hintMode)
        print("|cff0070dd[QuestKeys]|r Usage: /qk mode overlay  or  /qk mode inline")

    elseif msg == "mode overlay" or msg == "mode inline" then
        local newMode = msg:match("mode%s+(%a+)")
        DB.hintMode = newMode == "inline" and "inline" or "overlay"
        print("|cff0070dd[QuestKeys]|r Hint mode:", DB.hintMode)
        RefreshOptionsPanel()
        if IsQuestWindowOpen() then
            UpdateKeyHints()
        end

    elseif msg:find("^offset%s+") then
        local rawX, rawY = msg:match("^offset%s+(-?%d+)%s+(-?%d+)$")
        if rawX and rawY then
            DB.overlayOffsetX = ClampOverlayOffset(tonumber(rawX) or 0)
            DB.overlayOffsetY = ClampOverlayOffset(tonumber(rawY) or 0)
            print("|cff0070dd[QuestKeys]|r Overlay offsets set to X=", DB.overlayOffsetX, "Y=", DB.overlayOffsetY)
            RefreshOptionsPanel()
            if IsQuestWindowOpen() then
                UpdateKeyHints()
            end
        else
            print("|cff0070dd[QuestKeys]|r Usage: /qk offset <x> <y>   (range -30..30)")
        end
        
    elseif msg == "status" then
        print("|cff0070dd[QuestKeys]|r Status:")
        print("  Enabled:", DB.enabled and "Yes" or "No")
        print("  Spacebar Accept:", DB.spacebarAccept and "Yes" or "No")
        print("  Number Keys:", DB.numberKeysSelect and "Yes" or "No")
        print("  ESC Decline:", DB.escDecline and "Yes" or "No")
        print("  Show Key Hints:", DB.showKeyHints and "Yes" or "No")
        print("  Hint Mode:", DB.hintMode)
        print("  Overlay Offset X:", DB.overlayOffsetX)
        print("  Overlay Offset Y:", DB.overlayOffsetY)
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
        CreateOptionsPanel()
        
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
