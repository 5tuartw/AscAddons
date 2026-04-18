AscensionPromptSquelcher = AscensionPromptSquelcher or {}

local APS = AscensionPromptSquelcher
local addonFrame = CreateFrame("Frame")

APS.version = "1.0.0"
APS.defaults = {
    autoLootBind = true,
    autoLootRollBind = true,
    autoDisenchantRoll = true,
    autoDestroyItems = true,
    autoDeleteRareItems = true,
    autoCollectAppearance = true,
    autoAbandonQuestPrompt = false,
}

APS.appearanceHookInstalled = false
APS.popupHookInstalled = false
APS.pendingDisenchantConfirm = 0

local DISENCHANT_CONFIRM_TEXT_PATTERNS = {
    "disenchant",
    "destroy the item",
    "destroy the object",
}

local function CopyDefaults(source, destination)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

local function ToBoolean(value)
    return value and true or false
end

function APS:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99APS|r: " .. message)
end

function APS:InitializeDB()
    if type(AscensionPromptSquelcherDB) ~= "table" then
        AscensionPromptSquelcherDB = {}
    end

    self.db = AscensionPromptSquelcherDB
    CopyDefaults(self.defaults, self.db)
end

function APS:IsRareQuality(itemQuality)
    return (tonumber(itemQuality) or 0) >= 3
end

function APS:ShouldAutoDelete(itemQuality)
    if self:IsRareQuality(itemQuality) then
        return ToBoolean(self.db.autoDeleteRareItems)
    end

    return ToBoolean(self.db.autoDestroyItems)
end

function APS:HidePopupByWhich(which)
    if not which then
        return
    end

    for index = 1, STATICPOPUP_NUMDIALOGS do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() and popup.which == which then
            popup:Hide()
        end
    end
end

function APS:HideDeletePopups()
    self:HidePopupByWhich("DELETE_ITEM")
    self:HidePopupByWhich("DELETE_GOOD_ITEM")
end

function APS:ClickPopupButton1(which)
    if not which then
        return false
    end

    for index = 1, STATICPOPUP_NUMDIALOGS do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() and popup.which == which then
            local button = _G[popup:GetName() .. "Button1"]
            if button and button:IsShown() and button:IsEnabled() then
                button:Click()
                return true
            end
        end
    end

    return false
end

function APS:PopupTextMatches(text, patterns)
    if type(text) ~= "string" then
        return false
    end

    local normalizedText = string.lower(text)
    for _, pattern in ipairs(patterns) do
        if string.find(normalizedText, pattern, 1, true) then
            return true
        end
    end

    return false
end

function APS:ClickPopupByMatcher(matcher)
    if type(matcher) ~= "function" then
        return false
    end

    for index = 1, STATICPOPUP_NUMDIALOGS do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() and matcher(popup) then
            local button = _G[popup:GetName() .. "Button1"]
            if button and button:IsShown() and button:IsEnabled() then
                button:Click()
                return true
            end
        end
    end

    return false
end

function APS:ConfirmAppearancePopup()
    if not self.db or not self.db.autoCollectAppearance then
        return false
    end

    return self:ClickPopupButton1("CONFIRM_COLLECT_APPEARANCE")
end

function APS:ConfirmAbandonQuestPopup()
    if not self.db or not self.db.autoAbandonQuestPrompt then
        return false
    end

    if self:ClickPopupButton1("ABANDON_QUEST") then
        return true
    end

    if self:ClickPopupButton1("ABANDON_QUEST_WITH_ITEMS") then
        return true
    end

    return self:ClickPopupByMatcher(function(popup)
        if popup.which == "ABANDON_QUEST" or popup.which == "ABANDON_QUEST_WITH_ITEMS" then
            return true
        end

        local text = popup.text and popup.text.GetText and popup.text:GetText()
        if type(text) ~= "string" then
            return false
        end

        text = string.lower(text)
        return string.find(text, "abandon", 1, true) and string.find(text, "quest", 1, true)
    end)
end

function APS:ConfirmDisenchantRollPopup()
    if not self.db or not self.db.autoDisenchantRoll then
        return false
    end

    if self:ClickPopupButton1("CONFIRM_DISENCHANT_ROLL") then
        return true
    end

    return self:ClickPopupByMatcher(function(popup)
        if popup.which == "CONFIRM_DISENCHANT_ROLL" then
            return true
        end

        if GetTime() > (APS.pendingDisenchantConfirm or 0) then
            return false
        end

        local text = popup.text and popup.text.GetText and popup.text:GetText()
        return APS:PopupTextMatches(text, DISENCHANT_CONFIRM_TEXT_PATTERNS)
    end)
end

function APS:InstallPopupHook()
    if self.popupHookInstalled then
        return
    end

    hooksecurefunc("StaticPopup_Show", function(which)
        if not APS.db then
            return
        end

        if which == "CONFIRM_COLLECT_APPEARANCE" and APS.db.autoCollectAppearance then
            C_Timer.After(0.05, function()
                APS:ConfirmAppearancePopup()
            end)
            return
        end

        if APS.db.autoAbandonQuestPrompt and (which == "ABANDON_QUEST" or which == "ABANDON_QUEST_WITH_ITEMS") then
            C_Timer.After(0.05, function()
                APS:ConfirmAbandonQuestPopup()
            end)
            return
        end

        if not APS.db.autoDisenchantRoll then
            return
        end

        C_Timer.After(0.05, function()
            APS:ConfirmDisenchantRollPopup()
        end)
    end)

    self.popupHookInstalled = true
    self.appearanceHookInstalled = true
end

function APS:ConfirmLootBind(slot)
    if not self.db.autoLootBind or type(slot) ~= "number" then
        return
    end

    ConfirmLootSlot(slot)
    self:HidePopupByWhich("LOOT_BIND")

    C_Timer.After(0.01, function()
        LootSlot(slot)
    end)
end

function APS:ConfirmLootRollBind(id, rollType)
    if not self.db.autoLootRollBind then
        return
    end

    if type(id) ~= "number" or type(rollType) ~= "number" then
        return
    end

    ConfirmLootRoll(id, rollType)
    self:HidePopupByWhich("CONFIRM_LOOT_ROLL")
end

function APS:HandleDisenchantRollConfirm()
    if not self.db.autoDisenchantRoll then
        return
    end

    self.pendingDisenchantConfirm = GetTime() + 1.5

    C_Timer.After(0.01, function()
        APS:ConfirmDisenchantRollPopup()
    end)
end

function APS:ConfirmDelete(itemQuality)
    if not self:ShouldAutoDelete(itemQuality) then
        return
    end

    if CursorHasItem and CursorHasItem() then
        DeleteCursorItem()
        self:HideDeletePopups()
    end
end

function APS:OpenOptions()
    if not self.optionsPanel then
        return
    end

    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
end

function APS:GetStatusLine(settingKey)
    return self.db[settingKey] and "enabled" or "disabled"
end

function APS:PrintStatus()
    self:Print("Bind-on-pickup loot: " .. self:GetStatusLine("autoLootBind"))
    self:Print("Bind-on-pickup roll prompts: " .. self:GetStatusLine("autoLootRollBind"))
    self:Print("Disenchant roll prompts: " .. self:GetStatusLine("autoDisenchantRoll"))
    self:Print("Destroy item prompts: " .. self:GetStatusLine("autoDestroyItems"))
    self:Print("Rare item delete prompts: " .. self:GetStatusLine("autoDeleteRareItems"))
    self:Print("Appearance collection prompts: " .. self:GetStatusLine("autoCollectAppearance"))
    self:Print("Abandon quest prompts: " .. self:GetStatusLine("autoAbandonQuestPrompt"))
end

function APS:SetToggle(settingKey, value, label)
    self.db[settingKey] = value
    self:RefreshOptions()
    self:Print(label .. ": " .. self:GetStatusLine(settingKey))
end

function APS:ToggleSetting(settingKey, label)
    self:SetToggle(settingKey, not self.db[settingKey], label)
end

function APS:HandleSlashCommand(message)
    local command, state = string.match(string.lower(message or ""), "^(%S*)%s*(%S*)$")

    if command == "" or command == "config" or command == "options" then
        self:OpenOptions()
        return
    end

    if command == "status" then
        self:PrintStatus()
        return
    end

    local mapping = {
        loot = { key = "autoLootBind", label = "Bind-on-pickup loot" },
        roll = { key = "autoLootRollBind", label = "Bind-on-pickup roll prompts" },
        disenchant = { key = "autoDisenchantRoll", label = "Disenchant roll prompts" },
        destroy = { key = "autoDestroyItems", label = "Destroy item prompts" },
        rare = { key = "autoDeleteRareItems", label = "Rare item delete prompts" },
        appearance = { key = "autoCollectAppearance", label = "Appearance collection prompts" },
        abandon = { key = "autoAbandonQuestPrompt", label = "Abandon quest prompts" },
    }

    local entry = mapping[command]
    if not entry then
        self:Print("Usage: /aps status | /aps options | /aps loot on|off|toggle | /aps roll on|off|toggle | /aps disenchant on|off|toggle | /aps destroy on|off|toggle | /aps rare on|off|toggle | /aps appearance on|off|toggle | /aps abandon on|off|toggle")
        return
    end

    if state == "on" then
        self:SetToggle(entry.key, true, entry.label)
    elseif state == "off" then
        self:SetToggle(entry.key, false, entry.label)
    else
        self:ToggleSetting(entry.key, entry.label)
    end
end

function APS:RefreshOptions()
    if self.optionsControls then
        if self.optionsControls.lootCheckbox then
            self.optionsControls.lootCheckbox:SetChecked(self.db.autoLootBind)
        end
        if self.optionsControls.rollCheckbox then
            self.optionsControls.rollCheckbox:SetChecked(self.db.autoLootRollBind)
        end
        if self.optionsControls.disenchantCheckbox then
            self.optionsControls.disenchantCheckbox:SetChecked(self.db.autoDisenchantRoll)
        end
        if self.optionsControls.destroyCheckbox then
            self.optionsControls.destroyCheckbox:SetChecked(self.db.autoDestroyItems)
        end
        if self.optionsControls.rareCheckbox then
            self.optionsControls.rareCheckbox:SetChecked(self.db.autoDeleteRareItems)
        end
        if self.optionsControls.appearanceCheckbox then
            self.optionsControls.appearanceCheckbox:SetChecked(self.db.autoCollectAppearance)
        end
        if self.optionsControls.abandonCheckbox then
            self.optionsControls.abandonCheckbox:SetChecked(self.db.autoAbandonQuestPrompt)
        end
    end
end

function APS:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= "AscensionPromptSquelcher" then
            return
        end

        self:InitializeDB()
        self:InstallPopupHook()
        self:CreateOptionsPanel()
        self:RefreshOptions()
        return
    end

    if not self.db then
        return
    end

    if event == "LOOT_BIND_CONFIRM" then
        local slot = ...
        self:ConfirmLootBind(slot)
    elseif event == "CONFIRM_LOOT_ROLL" then
        local id, rollType = ...
        self:ConfirmLootRollBind(id, rollType)
    elseif event == "CONFIRM_DISENCHANT_ROLL" then
        self:HandleDisenchantRollConfirm()
    elseif event == "DELETE_ITEM_CONFIRM" then
        local _, itemQuality = ...
        self:ConfirmDelete(itemQuality)
    end
end

addonFrame:SetScript("OnEvent", function(_, event, ...)
    APS:OnEvent(event, ...)
end)

addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:RegisterEvent("LOOT_BIND_CONFIRM")
addonFrame:RegisterEvent("CONFIRM_LOOT_ROLL")
addonFrame:RegisterEvent("CONFIRM_DISENCHANT_ROLL")
addonFrame:RegisterEvent("DELETE_ITEM_CONFIRM")

SLASH_ASCENSIONPROMPTSQUELCHER1 = "/aps"
SLASH_ASCENSIONPROMPTSQUELCHER2 = "/promptsquelcher"
SlashCmdList["ASCENSIONPROMPTSQUELCHER"] = function(message)
    APS:HandleSlashCommand(message)
end