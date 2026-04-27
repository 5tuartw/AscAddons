local APS = AscensionPromptSquelcher

function APS:CreateOptionsPanel()
    if self.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "APS_OptionsPanel", UIParent)
    panel.name = "Ascension Prompt Squelcher"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension Prompt Squelcher")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Version " .. self.version)
    version:SetTextColor(0.5, 0.5, 0.5)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -16)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText("Automatically confirms selected 3.3.5 Ascension prompts so looting and item cleanup are less disruptive.")

    local lootCheckbox = CreateFrame("CheckButton", "APS_LootCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    lootCheckbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
    _G[lootCheckbox:GetName() .. "Text"]:SetText("Auto-confirm bind-on-pickup loot prompts")
    lootCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("autoLootBind", button:GetChecked(), "Bind-on-pickup loot")
    end)

    local rollCheckbox = CreateFrame("CheckButton", "APS_RollCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    rollCheckbox:SetPoint("TOPLEFT", lootCheckbox, "BOTTOMLEFT", 0, -8)
    _G[rollCheckbox:GetName() .. "Text"]:SetText("Auto-confirm bind-on-pickup loot roll prompts")
    rollCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("autoLootRollBind", button:GetChecked(), "Bind-on-pickup roll prompts")
    end)

    local disenchantCheckbox = CreateFrame("CheckButton", "APS_DisenchantCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    disenchantCheckbox:SetPoint("TOPLEFT", rollCheckbox, "BOTTOMLEFT", 0, -8)
    _G[disenchantCheckbox:GetName() .. "Text"]:SetText("Auto-confirm disenchant loot roll prompts")
    disenchantCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("autoDisenchantRoll", button:GetChecked(), "Disenchant roll prompts")
    end)

    local clickDeleteCheckbox = CreateFrame("CheckButton", "APS_ClickDeleteCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    clickDeleteCheckbox:SetPoint("TOPLEFT", disenchantCheckbox, "BOTTOMLEFT", 0, -8)
    _G[clickDeleteCheckbox:GetName() .. "Text"]:SetText("Allow Shift+Alt+RightClick to delete bag items")
    clickDeleteCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("shiftAltClickDelete", button:GetChecked(), "Shift+Alt+RightClick delete")
    end)

    local destroyCheckbox = CreateFrame("CheckButton", "APS_DestroyCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    destroyCheckbox:SetPoint("TOPLEFT", clickDeleteCheckbox, "BOTTOMLEFT", 0, -8)
    _G[destroyCheckbox:GetName() .. "Text"]:SetText("Auto-confirm destroy item prompts")
    destroyCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("autoDestroyItems", button:GetChecked(), "Destroy item prompts")
    end)

    local rareCheckbox = CreateFrame("CheckButton", "APS_RareCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    rareCheckbox:SetPoint("TOPLEFT", destroyCheckbox, "BOTTOMLEFT", 0, -8)
    _G[rareCheckbox:GetName() .. "Text"]:SetText("Auto-confirm rare or better item deletion prompts")
    rareCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("autoDeleteRareItems", button:GetChecked(), "Rare item delete prompts")
    end)

    local appearanceCheckbox = CreateFrame("CheckButton", "APS_AppearanceCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    appearanceCheckbox:SetPoint("TOPLEFT", rareCheckbox, "BOTTOMLEFT", 0, -8)
    _G[appearanceCheckbox:GetName() .. "Text"]:SetText("Auto-confirm appearance collection prompts")
    appearanceCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("autoCollectAppearance", button:GetChecked(), "Appearance collection prompts")
    end)

    local abandonCheckbox = CreateFrame("CheckButton", "APS_AbandonCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    abandonCheckbox:SetPoint("TOPLEFT", appearanceCheckbox, "BOTTOMLEFT", 0, -8)
    _G[abandonCheckbox:GetName() .. "Text"]:SetText("Auto-confirm abandon quest prompts")
    abandonCheckbox:SetScript("OnClick", function(button)
        APS:SetToggle("autoAbandonQuestPrompt", button:GetChecked(), "Abandon quest prompts")
    end)

    local warning = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    warning:SetPoint("TOPLEFT", abandonCheckbox, "BOTTOMLEFT", 0, -20)
    warning:SetWidth(560)
    warning:SetJustifyH("LEFT")
    warning:SetText("|cffff8080Warning:|r rare-item deletion bypasses the usual extra confirmation. Disable that toggle if you want the client to keep asking before deleting blue, purple, or better items.")

    local commands = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    commands:SetPoint("TOPLEFT", warning, "BOTTOMLEFT", 0, -20)
    commands:SetWidth(560)
    commands:SetJustifyH("LEFT")
    commands:SetText("Slash commands: /aps status, /aps loot on|off|toggle, /aps roll on|off|toggle, /aps disenchant on|off|toggle, /aps clickdelete on|off|toggle, /aps destroy on|off|toggle, /aps rare on|off|toggle, /aps appearance on|off|toggle, /aps abandon on|off|toggle")

    InterfaceOptions_AddCategory(panel)

    self.optionsPanel = panel
    self.optionsControls = {
        lootCheckbox = lootCheckbox,
        rollCheckbox = rollCheckbox,
        disenchantCheckbox = disenchantCheckbox,
        clickDeleteCheckbox = clickDeleteCheckbox,
        destroyCheckbox = destroyCheckbox,
        rareCheckbox = rareCheckbox,
        appearanceCheckbox = appearanceCheckbox,
        abandonCheckbox = abandonCheckbox,
    }
end