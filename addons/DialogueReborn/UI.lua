local DR = DialogueReborn

local function SetFont(target, path, size, flags)
    target:SetFont(path, size, flags or "")
end

local function CreateBackdropFrame(name, parent, frameType)
    local frame = CreateFrame(frameType or "Frame", name, parent)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    return frame
end

local function CreateTextButton(name, parent)
    local button = CreateBackdropFrame(name, parent, "Button")
    button:SetHeight(40)
    button:SetWidth(620)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdropColor(0.12, 0.09, 0.05, 0.94)
    button:SetBackdropBorderColor(0.55, 0.42, 0.20, 0.92)

    button.label = button:CreateFontString(nil, "ARTWORK")
    button.label:SetPoint("LEFT", 14, 0)
    button.label:SetPoint("RIGHT", -14, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetJustifyV("MIDDLE")
    SetFont(button.label, "Fonts\\FRIZQT__.TTF", 15)
    button.label:SetTextColor(0.97, 0.93, 0.86)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.17, 0.12, 0.06, 0.98)
        self:SetBackdropBorderColor(0.82, 0.66, 0.30, 1)
    end)

    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.09, 0.05, 0.94)
        self:SetBackdropBorderColor(0.55, 0.42, 0.20, 0.92)
    end)

    button:SetScript("OnClick", function(self)
        if self.action then
            self.action()
        end
    end)

    return button
end

local function CreateFooterButton(name, parent)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetHeight(28)
    button:SetWidth(170)
    button:RegisterForClicks("LeftButtonUp")

    button:SetScript("OnClick", function(self)
        if self.action then
            self.action()
        end
    end)

    return button
end

local function CreateRewardButton(name, parent)
    local button = CreateBackdropFrame(name, parent, "Button")
    button:SetSize(128, 146)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdropColor(0.12, 0.09, 0.05, 0.92)
    button:SetBackdropBorderColor(0.55, 0.42, 0.20, 0.92)

    button.iconBackground = button:CreateTexture(nil, "BACKGROUND")
    button.iconBackground:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    button.iconBackground:SetVertexColor(0.05, 0.04, 0.03, 0.92)
    button.iconBackground:SetPoint("TOPLEFT", 17, -18)
    button.iconBackground:SetPoint("TOPRIGHT", -17, -18)
    button.iconBackground:SetHeight(66)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 18, -19)
    button.icon:SetSize(64, 64)

    button.name = button:CreateFontString(nil, "ARTWORK")
    button.name:SetPoint("TOPLEFT", button.icon, "BOTTOMLEFT", -2, -12)
    button.name:SetPoint("TOPRIGHT", -14, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetJustifyV("TOP")
    button.name:SetSpacing(3)
    SetFont(button.name, "Fonts\\FRIZQT__.TTF", 12)
    button.name:SetTextColor(0.90, 0.86, 0.78)

    button.count = button:CreateFontString(nil, "OVERLAY")
    button.count:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -2, 3)
    SetFont(button.count, "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    button.count:SetTextColor(1, 0.95, 0.75)

    button.hotkey = button:CreateFontString(nil, "OVERLAY")
    button.hotkey:SetPoint("TOPLEFT", 8, -8)
    SetFont(button.hotkey, "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    button.hotkey:SetTextColor(0.94, 0.89, 0.72)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.17, 0.12, 0.06, 0.98)
        self:SetBackdropBorderColor(0.82, 0.66, 0.30, 1)
        if self.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.09, 0.05, 0.92)
        self:SetBackdropBorderColor(0.55, 0.42, 0.20, 0.92)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self)
        if self.action then
            self.action()
        end
    end)

    return button
end

function DR:ClearBindings()
    if self.ui and self.ui.bindingOwner then
        ClearOverrideBindings(self.ui.bindingOwner)
    end
end

function DR:RefreshBindings(primaryButton, closeButton, optionButtons)
    self:ClearBindings()

    if not self.db.enableKeybinds then
        return
    end

    if primaryButton and primaryButton:IsShown() and primaryButton:GetName() then
        SetOverrideBindingClick(self.ui.bindingOwner, true, "SPACE", primaryButton:GetName())
    end

    if closeButton and closeButton:IsShown() and closeButton:GetName() then
        SetOverrideBindingClick(self.ui.bindingOwner, true, "ESCAPE", closeButton:GetName())
    end

    for index, button in ipairs(optionButtons) do
        if index <= 9 and button:IsShown() and button:GetName() then
            SetOverrideBindingClick(self.ui.bindingOwner, true, tostring(index), button:GetName())
        end
    end
end

function DR:UpdatePortrait()
    if not self.ui or not self.ui.portrait then
        return
    end

    if UnitExists("npc") then
        SetPortraitTexture(self.ui.portrait, "npc")
    elseif UnitExists("target") then
        SetPortraitTexture(self.ui.portrait, "target")
    else
        self.ui.portrait:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    end
end

function DR:CreateUI()
    if self.ui then
        return
    end

    local overlay = CreateFrame("Frame", "DialogueRebornOverlay", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:EnableMouse(true)
    overlay:Hide()

    overlay.texture = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.texture:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    overlay.texture:SetAllPoints(overlay)
    overlay.texture:SetVertexColor(0, 0, 0, 0.60)

    local shell = CreateBackdropFrame("DialogueRebornShell", UIParent)
    shell:SetFrameStrata("FULLSCREEN_DIALOG")
    shell:SetClampedToScreen(true)
    shell:EnableMouse(true)
    shell:SetBackdropColor(0, 0, 0, 0)
    shell:SetBackdropBorderColor(0, 0, 0, 0)
    shell:SetPoint("CENTER", 0, -18)
    shell:SetSize(math.min(980, UIParent:GetWidth() * 0.72), math.min(620, UIParent:GetHeight() * 0.72))
    shell:Hide()

    shell.background = shell:CreateTexture(nil, "BACKGROUND")
    shell.background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    shell.background:SetAllPoints(shell)
    shell.background:SetVertexColor(0.08, 0.06, 0.04, 0.95)

    shell.borderTop = shell:CreateTexture(nil, "BORDER")
    shell.borderTop:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    shell.borderTop:SetPoint("TOPLEFT", -16, 16)
    shell.borderTop:SetPoint("TOPRIGHT", 16, 16)
    shell.borderTop:SetHeight(16)

    shell.borderBottom = shell:CreateTexture(nil, "BORDER")
    shell.borderBottom:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    shell.borderBottom:SetTexCoord(0, 1, 1, 0)
    shell.borderBottom:SetPoint("BOTTOMLEFT", -16, -16)
    shell.borderBottom:SetPoint("BOTTOMRIGHT", 16, -16)
    shell.borderBottom:SetHeight(16)

    shell.bindingOwner = shell

    shell.header = shell:CreateTexture(nil, "ARTWORK")
    shell.header:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    shell.header:SetVertexColor(0.20, 0.13, 0.07, 0.98)
    shell.header:SetPoint("TOPLEFT", 12, -12)
    shell.header:SetPoint("TOPRIGHT", -12, -12)
    shell.header:SetHeight(70)

    shell.headerGlow = shell:CreateTexture(nil, "OVERLAY")
    shell.headerGlow:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    shell.headerGlow:SetVertexColor(0.88, 0.72, 0.34, 0.12)
    shell.headerGlow:SetPoint("TOPLEFT", shell.header, "BOTTOMLEFT", 0, 0)
    shell.headerGlow:SetPoint("TOPRIGHT", shell.header, "BOTTOMRIGHT", 0, 0)
    shell.headerGlow:SetHeight(2)

    shell.title = shell:CreateFontString(nil, "ARTWORK")
    shell.title:SetPoint("TOPLEFT", 118, -24)
    shell.title:SetPoint("TOPRIGHT", -30, -24)
    shell.title:SetJustifyH("LEFT")
    SetFont(shell.title, "Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    shell.title:SetTextColor(0.98, 0.92, 0.74)

    shell.subtitle = shell:CreateFontString(nil, "ARTWORK")
    shell.subtitle:SetPoint("TOPLEFT", shell.title, "BOTTOMLEFT", 0, -6)
    shell.subtitle:SetPoint("TOPRIGHT", -30, 0)
    shell.subtitle:SetJustifyH("LEFT")
    SetFont(shell.subtitle, "Fonts\\FRIZQT__.TTF", 13)
    shell.subtitle:SetTextColor(0.78, 0.65, 0.40)

    shell.portraitFrame = CreateBackdropFrame("DialogueRebornPortraitFrame", shell)
    shell.portraitFrame:SetSize(74, 74)
    shell.portraitFrame:SetPoint("TOPLEFT", 24, -18)
    shell.portraitFrame:SetBackdropColor(0.10, 0.08, 0.05, 0.95)
    shell.portraitFrame:SetBackdropBorderColor(0.62, 0.48, 0.23, 0.95)

    shell.portrait = shell.portraitFrame:CreateTexture(nil, "ARTWORK")
    shell.portrait:SetPoint("TOPLEFT", 6, -6)
    shell.portrait:SetPoint("BOTTOMRIGHT", -6, 6)

    shell.bodyInset = CreateBackdropFrame("DialogueRebornBodyInset", shell)
    shell.bodyInset:SetPoint("TOPLEFT", 24, -106)
    shell.bodyInset:SetPoint("BOTTOMRIGHT", -24, 122)
    shell.bodyInset:SetBackdropColor(0.93, 0.86, 0.72, 0.96)
    shell.bodyInset:SetBackdropBorderColor(0.55, 0.40, 0.17, 0.90)

    shell.bodyInsetTop = shell.bodyInset:CreateTexture(nil, "OVERLAY")
    shell.bodyInsetTop:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    shell.bodyInsetTop:SetVertexColor(1, 1, 1, 0.10)
    shell.bodyInsetTop:SetPoint("TOPLEFT", 8, -8)
    shell.bodyInsetTop:SetPoint("TOPRIGHT", -8, -8)
    shell.bodyInsetTop:SetHeight(1)

    shell.scrollFrame = CreateFrame("ScrollFrame", "DialogueRebornScrollFrame", shell.bodyInset)
    shell.scrollFrame:SetPoint("TOPLEFT", 18, -18)
    shell.scrollFrame:SetPoint("BOTTOMRIGHT", -18, 18)
    shell.scrollFrame:EnableMouseWheel(true)

    shell.scrollChild = CreateFrame("Frame", nil, shell.scrollFrame)
    shell.scrollChild:SetWidth(shell.bodyInset:GetWidth() - 40)
    shell.scrollChild:SetHeight(1)
    shell.scrollFrame:SetScrollChild(shell.scrollChild)

    shell.bodyText = shell.scrollChild:CreateFontString(nil, "ARTWORK")
    shell.bodyText:SetPoint("TOPLEFT", 0, 0)
    shell.bodyText:SetPoint("TOPRIGHT", 0, 0)
    shell.bodyText:SetJustifyH("LEFT")
    shell.bodyText:SetJustifyV("TOP")
    shell.bodyText:SetSpacing(7)
    shell.bodyText:SetTextColor(0.20, 0.14, 0.08)
    SetFont(shell.bodyText, "Fonts\\FRIZQT__.TTF", 15)

    shell.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local step = 36
        self:SetVerticalScroll(math.max(0, current - (delta * step)))
    end)

    shell.choiceContainer = CreateFrame("Frame", "DialogueRebornChoiceContainer", shell)
    shell.choiceContainer:SetPoint("BOTTOM", shell, "BOTTOM", 0, 132)
    shell.choiceContainer:SetWidth(620)
    shell.choiceContainer:SetHeight(220)

    shell.rewardContainer = CreateFrame("Frame", "DialogueRebornRewardContainer", shell)
    shell.rewardContainer:SetPoint("BOTTOMLEFT", 24, 132)
    shell.rewardContainer:SetPoint("BOTTOMRIGHT", -24, 132)
    shell.rewardContainer:SetHeight(160)

    shell.primaryButton = CreateFooterButton("DialogueRebornPrimaryButton", shell)
    shell.primaryButton:SetPoint("BOTTOMRIGHT", -196, 42)

    shell.closeButton = CreateFooterButton("DialogueRebornCloseButton", shell)
    shell.closeButton:SetPoint("LEFT", shell.primaryButton, "RIGHT", 12, 0)

    shell.choiceButtons = {}
    for index = 1, 12 do
        local button = CreateTextButton("DialogueRebornOptionButton" .. index, shell.choiceContainer)
        button:SetPoint("TOP", shell.choiceContainer, "TOP", 0, -((index - 1) * 46))
        button:Hide()
        shell.choiceButtons[index] = button
    end

    shell.rewardButtons = {}
    for index = 1, 6 do
        local button = CreateRewardButton("DialogueRebornRewardButton" .. index, shell.rewardContainer)
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        button:SetPoint("TOPLEFT", column * 170, -(row * 160))
        button:Hide()
        shell.rewardButtons[index] = button
    end

    shell:SetScript("OnHide", function()
        DR:ClearBindings()
    end)

    self.ui = shell
    self.ui.overlay = overlay
    self.ui.bindingOwner = shell.bindingOwner
    self.ui.portrait = shell.portrait
end

function DR:HideState()
    if not self.ui then
        return
    end

    self:ClearBindings()
    self.ui:Hide()
end

function DR:ShowState(state)
    local ui = self.ui
    if not ui then
        return
    end

    ui:Show()
    self:UpdatePortrait()
    ui.scrollChild:SetWidth(math.max(120, ui.bodyInset:GetWidth() - 40))

    ui.title:SetText(state.title or "Dialogue")
    ui.subtitle:SetText(state.subtitle or "")
    ui.bodyText:SetText(state.body or "")
    ui.scrollChild:SetHeight(math.max(1, ui.bodyText:GetStringHeight() + 12))
    ui.scrollFrame:SetVerticalScroll(0)

    local activeButtons = {}

    for _, button in ipairs(ui.choiceButtons) do
        button.action = nil
        button:Hide()
    end

    for _, button in ipairs(ui.rewardButtons) do
        button.action = nil
        button.link = nil
        button:Hide()
    end

    ui.choiceContainer:Hide()
    ui.rewardContainer:Hide()

    if state.rewardChoices and #state.rewardChoices > 0 then
        ui.rewardContainer:Show()
        for index, reward in ipairs(state.rewardChoices) do
            local button = ui.rewardButtons[index]
            if button then
                button.name:SetText(reward.text or "")
                button.icon:SetTexture(reward.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                button.count:SetText(reward.subtitle or "")
                button.hotkey:SetText(reward.hotkey and ("[" .. reward.hotkey .. "]") or "")
                button.link = reward.link
                button.action = reward.action
                button:Show()
                table.insert(activeButtons, button)
            end
        end
    elseif state.choices and #state.choices > 0 then
        ui.choiceContainer:Show()
        for index, choice in ipairs(state.choices) do
            local button = ui.choiceButtons[index]
            if button then
                local hotkey = choice.hotkey and ("[" .. choice.hotkey .. "] ") or ""
                button.label:SetText(hotkey .. (choice.text or ""))
                button.action = choice.action
                button:Show()
                table.insert(activeButtons, button)
            end
        end
    end

    if state.primaryText and state.primaryAction then
        ui.primaryButton:SetText((state.primaryText or "") .. " [SPC]")
        ui.primaryButton.action = state.primaryAction
        ui.primaryButton:Show()
    else
        ui.primaryButton.action = nil
        ui.primaryButton:Hide()
    end

    ui.closeButton:SetText((state.closeText or "Close") .. " [ESC]")
    ui.closeButton.action = state.closeAction or function()
        DR:HideState()
    end
    ui.closeButton:Show()

    self:RefreshBindings(ui.primaryButton, ui.closeButton, activeButtons)
end