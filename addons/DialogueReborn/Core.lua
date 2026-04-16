DialogueReborn = DialogueReborn or {}

local DR = DialogueReborn
local eventFrame = CreateFrame("Frame")

DR.version = "0.1.0"
DR.defaults = {
    enabled = true,
    dimScreen = true,
    hideActionBars = true,
    hideMinimap = true,
    hideChat = true,
    hideBuffs = true,
    enableKeybinds = true,
}

DR.currentMode = nil
DR.currentCloseAction = nil
DR.frameStates = {}
DR.suppressedFrames = {}

local function CopyDefaults(source, destination)
    for key, value in pairs(source) do
        if destination[key] == nil then
            if type(value) == "table" then
                destination[key] = {}
                CopyDefaults(value, destination[key])
            else
                destination[key] = value
            end
        elseif type(value) == "table" and type(destination[key]) == "table" then
            CopyDefaults(value, destination[key])
        end
    end
end

local function SafeTrim(text)
    if type(text) ~= "string" then
        return ""
    end

    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function NormalizeBodyText(...)
    local parts = {}

    for i = 1, select("#", ...) do
        local value = SafeTrim(select(i, ...))
        if value ~= "" then
            table.insert(parts, value)
        end
    end

    return table.concat(parts, "\n\n")
end

function DR:Debug(...)
    if self.db and self.db.debugMode then
        local parts = {}
        for index = 1, select("#", ...) do
            parts[index] = tostring(select(index, ...))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffc8a24aDialogueReborn|r: " .. table.concat(parts, " "))
    end
end

function DR:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffc8a24aDialogueReborn|r: " .. message)
end

function DR:Delay(delaySeconds, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delaySeconds, callback)
        return
    end

    local timer = CreateFrame("Frame")
    local remaining = delaySeconds
    timer:SetScript("OnUpdate", function(self, elapsed)
        remaining = remaining - elapsed
        if remaining <= 0 then
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
end

function DR:InitializeDB()
    if type(DialogueRebornDB) ~= "table" then
        DialogueRebornDB = {}
    end

    self.db = DialogueRebornDB
    CopyDefaults(self.defaults, self.db)
end

function DR:GetNPCName()
    local name = UnitName("npc")
    if not name then
        name = UnitName("target")
    end
    return name or "Dialogue"
end

local function SortButtonsByPosition(leftButton, rightButton)
    local leftTop = leftButton:GetTop() or 0
    local rightTop = rightButton:GetTop() or 0

    if math.abs(leftTop - rightTop) > 2 then
        return leftTop > rightTop
    end

    return (leftButton:GetLeft() or 0) < (rightButton:GetLeft() or 0)
end

function DR:CollectVisibleButtons(prefix, maxButtons)
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

function DR:BuildChoiceDataFromButtons(prefix, maxButtons)
    local buttons = self:CollectVisibleButtons(prefix, maxButtons)
    local choices = {}

    for index, button in ipairs(buttons) do
        local text = SafeTrim(button:GetText())
        if text ~= "" then
            table.insert(choices, {
                text = text,
                button = button,
                hotkey = index <= 9 and tostring(index) or nil,
            })
        end
    end

    return choices
end

function DR:MakeButtonAction(button)
    return function()
        if button and button:IsVisible() and button:IsEnabled() and button.Click then
            button:Click()
        elseif button and button:IsVisible() and button:IsEnabled() then
            local onClick = button:GetScript("OnClick")
            if onClick then
                onClick(button, "LeftButton")
            end
        end
    end
end

function DR:BuildRewardChoices()
    local rewards = {}
    local numChoices = GetNumQuestChoices() or 0

    for index = 1, numChoices do
        local name, texture, numItems, quality = GetQuestItemInfo("choice", index)
        if name then
            table.insert(rewards, {
                index = index,
                text = name,
                subtitle = numItems and numItems > 1 and ("x" .. numItems) or nil,
                icon = texture,
                quality = quality,
                link = GetQuestItemLink("choice", index),
                hotkey = index <= 9 and tostring(index) or nil,
                action = function()
                    GetQuestReward(index)
                end,
            })
        end
    end

    return rewards
end

function DR:BuildRewardSummary()
    local parts = {}
    local money = GetRewardMoney and GetRewardMoney() or 0
    local xp = GetRewardXP and GetRewardXP() or 0
    local numRewards = GetNumQuestRewards and GetNumQuestRewards() or 0

    if xp and xp > 0 then
        table.insert(parts, tostring(xp) .. " XP")
    end

    if money and money > 0 and GetCoinTextureString then
        table.insert(parts, GetCoinTextureString(money))
    elseif money and money > 0 then
        table.insert(parts, tostring(money) .. " copper")
    end

    if numRewards and numRewards > 0 then
        local fixedRewardNames = {}
        for index = 1, numRewards do
            local name = GetQuestItemInfo("reward", index)
            if name then
                table.insert(fixedRewardNames, name)
            end
        end

        if #fixedRewardNames > 0 then
            table.insert(parts, "Also receives: " .. table.concat(fixedRewardNames, ", "))
        end
    end

    return table.concat(parts, "   ")
end

function DR:GetSuppressedFrames()
    local frames = {
        { frame = QuestFrame, hide = false },
        { frame = GossipFrame, hide = false },
    }

    if self.db.hideActionBars then
        table.insert(frames, { frame = MainMenuBar, hide = false })
        table.insert(frames, { frame = MultiBarBottomLeft, hide = false })
        table.insert(frames, { frame = MultiBarBottomRight, hide = false })
        table.insert(frames, { frame = MultiBarLeft, hide = false })
        table.insert(frames, { frame = MultiBarRight, hide = false })
        table.insert(frames, { frame = MainMenuBarArtFrame, hide = false })
    end

    if self.db.hideMinimap then
        table.insert(frames, { frame = MinimapCluster, hide = false })
    end

    if self.db.hideChat then
        table.insert(frames, { frame = ChatFrame1, hide = false })
        table.insert(frames, { frame = ChatFrame2, hide = false })
        table.insert(frames, { frame = QuickButtonFrame, hide = false })
        table.insert(frames, { frame = GeneralDockManager, hide = false })
    end

    if self.db.hideBuffs then
        table.insert(frames, { frame = BuffFrame, hide = false })
        table.insert(frames, { frame = TemporaryEnchantFrame, hide = false })
    end

    return frames
end

function DR:CaptureFrameState(frame, hide)
    if not frame or self.frameStates[frame] then
        return
    end

    local state = {
        alpha = frame:GetAlpha(),
        shown = frame:IsShown(),
        strata = frame:GetFrameStrata(),
        hide = hide,
    }

    if frame.IsMouseEnabled then
        state.mouseEnabled = frame:IsMouseEnabled()
    end

    self.frameStates[frame] = state
end

function DR:SuppressFrame(frame, hide)
    if not frame then
        return
    end

    self:CaptureFrameState(frame, hide)
    frame:SetAlpha(0)
    frame:SetFrameStrata("BACKGROUND")
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if hide and frame.Hide then
        frame:Hide()
    end
end

function DR:RestoreSuppressedFrames()
    for frame, state in pairs(self.frameStates) do
        if frame then
            frame:SetAlpha(state.alpha or 1)
            if frame.SetFrameStrata and state.strata then
                frame:SetFrameStrata(state.strata)
            end
            if frame.EnableMouse and state.mouseEnabled ~= nil then
                frame:EnableMouse(state.mouseEnabled)
            end
            if state.hide and state.shown and frame.Show then
                frame:Show()
            end
        end
    end

    wipe(self.frameStates)
end

function DR:ApplyImmersion()
    if not self.db.enabled then
        return
    end

    for _, info in ipairs(self:GetSuppressedFrames()) do
        self:SuppressFrame(info.frame, info.hide)
    end

    if self.ui and self.ui.overlay then
        if self.db.dimScreen then
            self.ui.overlay:Show()
        else
            self.ui.overlay:Hide()
        end
    end
end

function DR:RestoreImmersion()
    if self.ui and self.ui.overlay then
        self.ui.overlay:Hide()
    end

    self:RestoreSuppressedFrames()
end

function DR:CloseCurrentInteraction()
    if self.currentCloseAction then
        self.currentCloseAction()
        return
    end

    if GossipFrame and GossipFrame:IsVisible() then
        CloseGossip()
    elseif QuestFrame and QuestFrame:IsVisible() then
        CloseQuest()
    end
end

function DR:BuildGossipState()
    local choices = self:BuildChoiceDataFromButtons("GossipTitleButton", 32)
    local preparedChoices = {}

    for index, choice in ipairs(choices) do
        preparedChoices[index] = {
            text = choice.text,
            hotkey = choice.hotkey,
            action = self:MakeButtonAction(choice.button),
        }
    end

    return {
        mode = "gossip",
        title = self:GetNPCName(),
        subtitle = "Conversation",
        body = NormalizeBodyText(GetGossipText()),
        choices = preparedChoices,
        primaryText = preparedChoices[1] and "Continue" or nil,
        primaryAction = preparedChoices[1] and preparedChoices[1].action or nil,
        closeText = "Goodbye",
        closeAction = CloseGossip,
    }
end

function DR:BuildGreetingState()
    local choices = self:BuildChoiceDataFromButtons("QuestTitleButton", 32)
    local preparedChoices = {}

    for index, choice in ipairs(choices) do
        preparedChoices[index] = {
            text = choice.text,
            hotkey = choice.hotkey,
            action = self:MakeButtonAction(choice.button),
        }
    end

    return {
        mode = "greeting",
        title = self:GetNPCName(),
        subtitle = "Quests",
        body = NormalizeBodyText(GetGreetingText()),
        choices = preparedChoices,
        primaryText = preparedChoices[1] and "Continue" or nil,
        primaryAction = preparedChoices[1] and preparedChoices[1].action or nil,
        closeText = "Later",
        closeAction = CloseQuest,
    }
end

function DR:BuildDetailState()
    return {
        mode = "detail",
        title = GetTitleText() or self:GetNPCName(),
        subtitle = "Quest Offer",
        body = NormalizeBodyText(GetQuestText(), GetObjectiveText and GetObjectiveText() or nil),
        primaryText = "Accept Quest",
        primaryAction = AcceptQuest,
        closeText = "Decline",
        closeAction = DeclineQuest,
    }
end

function DR:BuildProgressState()
    local isCompletable = IsQuestCompletable and IsQuestCompletable()

    return {
        mode = "progress",
        title = GetTitleText() or self:GetNPCName(),
        subtitle = isCompletable and "Ready To Turn In" or "Quest Progress",
        body = NormalizeBodyText(GetProgressText()),
        primaryText = isCompletable and "Continue" or nil,
        primaryAction = isCompletable and CompleteQuest or nil,
        closeText = isCompletable and "Not Yet" or "Close",
        closeAction = CloseQuest,
    }
end

function DR:BuildCompleteState()
    local rewardChoices = self:BuildRewardChoices()
    local rewardSummary = self:BuildRewardSummary()
    local numChoices = #rewardChoices
    local body = NormalizeBodyText(GetRewardText(), rewardSummary)

    return {
        mode = "complete",
        title = GetTitleText() or self:GetNPCName(),
        subtitle = numChoices > 1 and "Choose Your Reward" or "Quest Complete",
        body = body,
        rewardChoices = rewardChoices,
        primaryText = numChoices <= 1 and "Receive Rewards" or nil,
        primaryAction = numChoices <= 1 and function()
            GetQuestReward(1)
        end or nil,
        closeText = "Later",
        closeAction = CloseQuest,
    }
end

function DR:RenderState(state)
    if not self.db.enabled then
        return
    end

    local ok, errorMessage = pcall(function()
        self.currentMode = state.mode
        self.currentCloseAction = state.closeAction
        self:ApplyImmersion()
        self:ShowState(state)
    end)

    if not ok then
        self:RestoreImmersion()
        self.currentMode = nil
        self.currentCloseAction = nil
        self:Print("Render failed: " .. tostring(errorMessage))
    end
end

function DR:RefreshFromMode(mode)
    if not self.db.enabled then
        return
    end

    if mode == "gossip" then
        self:RenderState(self:BuildGossipState())
    elseif mode == "greeting" then
        self:RenderState(self:BuildGreetingState())
    elseif mode == "detail" then
        self:RenderState(self:BuildDetailState())
    elseif mode == "progress" then
        self:RenderState(self:BuildProgressState())
    elseif mode == "complete" then
        self:RenderState(self:BuildCompleteState())
    end
end

function DR:ScheduleRender(mode)
    self:Delay(0.05, function()
        if not DR.db or not DR.db.enabled then
            return
        end

        DR:RefreshFromMode(mode)
    end)
end

function DR:HideDialogue()
    self.currentMode = nil
    self.currentCloseAction = nil
    self:HideState()
    self:RestoreImmersion()
end

function DR:RefreshOptions()
    if not self.optionsControls then
        return
    end

    self.optionsControls.enabled:SetChecked(self.db.enabled)
    self.optionsControls.dimScreen:SetChecked(self.db.dimScreen)
    self.optionsControls.hideActionBars:SetChecked(self.db.hideActionBars)
    self.optionsControls.hideMinimap:SetChecked(self.db.hideMinimap)
    self.optionsControls.hideChat:SetChecked(self.db.hideChat)
    self.optionsControls.hideBuffs:SetChecked(self.db.hideBuffs)
    self.optionsControls.enableKeybinds:SetChecked(self.db.enableKeybinds)
end

function DR:HandleSlashCommand(message)
    local command = string.lower(SafeTrim(message or ""))

    if command == "" or command == "config" or command == "options" then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        return
    end

    if command == "toggle" then
        self.db.enabled = not self.db.enabled
        if not self.db.enabled then
            self:HideDialogue()
        end
        self:RefreshOptions()
        self:Print("Addon " .. (self.db.enabled and "enabled" or "disabled"))
        return
    end

    self:Print("Usage: /dr options | /dr toggle")
end

function DR:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= "DialogueReborn" then
            return
        end

        self:InitializeDB()
        self:CreateUI()
        self:CreateOptionsPanel()
        self:RefreshOptions()
        return
    end

    if not self.db or not self.db.enabled then
        if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
            self:HideDialogue()
        end
        return
    end

    if event == "GOSSIP_SHOW" then
        self:ScheduleRender("gossip")
    elseif event == "QUEST_GREETING" then
        self:ScheduleRender("greeting")
    elseif event == "QUEST_DETAIL" then
        self:ScheduleRender("detail")
    elseif event == "QUEST_PROGRESS" then
        self:ScheduleRender("progress")
    elseif event == "QUEST_COMPLETE" then
        self:ScheduleRender("complete")
    elseif event == "QUEST_ACCEPTED" then
        if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
            self:ScheduleRender("greeting")
        end
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
        self:HideDialogue()
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")
eventFrame:RegisterEvent("QUEST_GREETING")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_PROGRESS")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("QUEST_FINISHED")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    DR:OnEvent(event, ...)
end)

SLASH_DIALOGUEREBORN1 = "/dialoguereborn"
SLASH_DIALOGUEREBORN2 = "/dr"
SlashCmdList["DIALOGUEREBORN"] = function(message)
    DR:HandleSlashCommand(message)
end