local DR = DialogueReborn

local function CreateCheckbox(name, parent, label, anchor, relativeTo, xOffset, yOffset, onClick)
    local checkbox = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint(anchor, relativeTo, anchor, xOffset, yOffset)
    _G[name .. "Text"]:SetText(label)
    checkbox:SetScript("OnClick", onClick)
    return checkbox
end

function DR:CreateOptionsPanel()
    if self.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "DialogueRebornOptionsPanel", UIParent)
    panel.name = "Dialogue Reborn"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Dialogue Reborn")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Version " .. self.version)
    version:SetTextColor(0.5, 0.5, 0.5)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -18)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText("DialogueUI-inspired immersive quest and gossip presentation for Ascension 3.3.5. This addon replaces Blizzard's visible dialogue panels with its own custom frame and optionally fades the rest of the UI while NPC conversations are open.")

    local enabled = CreateCheckbox(
        "DialogueRebornEnabledCheck",
        panel,
        "Enable Dialogue Reborn",
        "TOPLEFT",
        description,
        0,
        -28,
        function(button)
            DR.db.enabled = button:GetChecked()
            if not DR.db.enabled then
                DR:HideDialogue()
            end
        end
    )

    local dimScreen = CreateCheckbox(
        "DialogueRebornDimScreenCheck",
        panel,
        "Darken the screen while dialogue is open",
        "TOPLEFT",
        enabled,
        0,
        -28,
        function(button)
            DR.db.dimScreen = button:GetChecked()
        end
    )

    local hideActionBars = CreateCheckbox(
        "DialogueRebornHideActionBarsCheck",
        panel,
        "Fade action bars during dialogue",
        "TOPLEFT",
        dimScreen,
        0,
        -28,
        function(button)
            DR.db.hideActionBars = button:GetChecked()
        end
    )

    local hideMinimap = CreateCheckbox(
        "DialogueRebornHideMinimapCheck",
        panel,
        "Fade minimap during dialogue",
        "TOPLEFT",
        hideActionBars,
        0,
        -28,
        function(button)
            DR.db.hideMinimap = button:GetChecked()
        end
    )

    local hideChat = CreateCheckbox(
        "DialogueRebornHideChatCheck",
        panel,
        "Fade chat frames during dialogue",
        "TOPLEFT",
        hideMinimap,
        0,
        -28,
        function(button)
            DR.db.hideChat = button:GetChecked()
        end
    )

    local hideBuffs = CreateCheckbox(
        "DialogueRebornHideBuffsCheck",
        panel,
        "Fade buffs during dialogue",
        "TOPLEFT",
        hideChat,
        0,
        -28,
        function(button)
            DR.db.hideBuffs = button:GetChecked()
        end
    )

    local enableKeybinds = CreateCheckbox(
        "DialogueRebornEnableKeybindsCheck",
        panel,
        "Enable built-in keyboard shortcuts",
        "TOPLEFT",
        hideBuffs,
        0,
        -28,
        function(button)
            DR.db.enableKeybinds = button:GetChecked()
        end
    )

    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", enableKeybinds, "BOTTOMLEFT", 0, -26)
    help:SetWidth(560)
    help:SetJustifyH("LEFT")
    help:SetText("Shortcuts while the Dialogue Reborn frame is open: [SPACE] primary action, [1]-[9] visible options or reward choices, [ESC] close or decline.")

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)
    note:SetWidth(560)
    note:SetJustifyH("LEFT")
    note:SetText("If you keep QuestKeys enabled as well, Dialogue Reborn's own override bindings should take priority while its custom frame is visible.")

    InterfaceOptions_AddCategory(panel)

    self.optionsPanel = panel
    self.optionsControls = {
        enabled = enabled,
        dimScreen = dimScreen,
        hideActionBars = hideActionBars,
        hideMinimap = hideMinimap,
        hideChat = hideChat,
        hideBuffs = hideBuffs,
        enableKeybinds = enableKeybinds,
    }
end