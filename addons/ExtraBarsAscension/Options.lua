-- ExtraBarsAscension: Interface Options panel
-- Provides per-bar settings: scale, buttons, buttons per row, padding,
-- lock/unlock, visibility mode (always/mouseover/hidden), and global
-- stance suppression toggle.  Most changes apply live; page changes
-- require /reload.
local EBA = ExtraBarsAscension
local NUM_BARS = EBA_NUM_BARS
local MAX_BUTTONS = EBA_MAX_BUTTONS
local Print = EBA_Print

local FONT_FACE = "Fonts\\FRIZQT__.TTF"

---------------------------------------------------------------------------
-- Helper: create a slider with label, min/max text, and current value
---------------------------------------------------------------------------
local function CreateSlider(name, parent, label, minVal, maxVal, step, anchor, xOff, yOff, formatFunc, anchorPoint)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, anchorPoint or "BOTTOMLEFT", xOff, yOff)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetWidth(200)

    _G[name .. "Low"]:SetText(minVal)
    _G[name .. "High"]:SetText(maxVal)
    _G[name .. "Text"]:SetText(label .. ": " .. (formatFunc and formatFunc(minVal) or minVal))

    return slider
end

---------------------------------------------------------------------------
-- Helper: create a dropdown
---------------------------------------------------------------------------
local function CreateDropdown(name, parent, label, anchor, xOff, yOff, width)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOff, yOff)
    lbl:SetText(label)

    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", lbl, "RIGHT", -10, -3)
    UIDropDownMenu_SetWidth(dd, width or 120)

    return dd, lbl
end

---------------------------------------------------------------------------
-- Build per-bar settings subpanel
---------------------------------------------------------------------------
local function CreateBarPanel(barIndex, parentName)
    local panel = CreateFrame("Frame", "EBA_BarPanel" .. barIndex, UIParent)
    panel.name = "Bar " .. barIndex
    panel.parent = parentName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Bar " .. barIndex .. " Settings")

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    note:SetText("|cff888888Some changes (marked *) require /reload to apply.|r")

    -----------------------------------------------------------------------
    -- Enable checkbox
    -----------------------------------------------------------------------
    local enableCheck = CreateFrame("CheckButton", "EBA_Bar" .. barIndex .. "_EnableCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
    _G[enableCheck:GetName() .. "Text"]:SetText("Enable bar *")

    -----------------------------------------------------------------------
    -- Action page dropdown
    -----------------------------------------------------------------------
    local pageDropdown, pageLabel = CreateDropdown(
        "EBA_Bar" .. barIndex .. "_PageDropdown", panel,
        "Action page *:", enableCheck, 0, -12, 80)

    -----------------------------------------------------------------------
    -- Sliders: two-column layout
    -- Row 1: Scale (left) & Size (right)
    -- Row 2: Padding (left) & Alpha (right)
    -- Row 3: Buttons (left) & Buttons per row (right)
    -----------------------------------------------------------------------
    local scaleSlider = CreateSlider(
        "EBA_Bar" .. barIndex .. "_ScaleSlider", panel,
        "Scale", 50, 200, 5, pageLabel, 0, -36,
        function(v) return v .. "%" end)

    local sizeSlider = CreateSlider(
        "EBA_Bar" .. barIndex .. "_SizeSlider", panel,
        "Button size", 16, 64, 1, scaleSlider, 230, 0,
        function(v) return v .. "px" end, "TOPLEFT")

    local paddingSlider = CreateSlider(
        "EBA_Bar" .. barIndex .. "_PaddingSlider", panel,
        "Padding", 0, 20, 1, scaleSlider, 0, -36,
        function(v) return v .. "px" end)

    local alphaSlider = CreateSlider(
        "EBA_Bar" .. barIndex .. "_AlphaSlider", panel,
        "Fade alpha", 0, 100, 5, paddingSlider, 230, 0,
        function(v) return v .. "%" end, "TOPLEFT")

    local buttonsSlider = CreateSlider(
        "EBA_Bar" .. barIndex .. "_ButtonsSlider", panel,
        "Buttons", 1, MAX_BUTTONS, 1, paddingSlider, 0, -36,
        function(v) return tostring(v) end)

    local perRowSlider = CreateSlider(
        "EBA_Bar" .. barIndex .. "_PerRowSlider", panel,
        "Buttons per row", 1, MAX_BUTTONS, 1, buttonsSlider, 230, 0,
        function(v) return tostring(v) end, "TOPLEFT")

    -----------------------------------------------------------------------
    -- Visibility dropdown
    -----------------------------------------------------------------------
    local visDropdown, visLabel = CreateDropdown(
        "EBA_Bar" .. barIndex .. "_VisDropdown", panel,
        "Visibility:", buttonsSlider, 0, -36, 140)

    -----------------------------------------------------------------------
    -- Hotkey / Macro / Grid checkboxes
    -----------------------------------------------------------------------
    local hotkeyCheck = CreateFrame("CheckButton", "EBA_Bar" .. barIndex .. "_HotkeyCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    hotkeyCheck:SetPoint("TOPLEFT", visLabel, "BOTTOMLEFT", 0, -16)
    _G[hotkeyCheck:GetName() .. "Text"]:SetText("Show keybind text *")

    local macroCheck = CreateFrame("CheckButton", "EBA_Bar" .. barIndex .. "_MacroCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    macroCheck:SetPoint("TOPLEFT", hotkeyCheck, "BOTTOMLEFT", 0, -4)
    _G[macroCheck:GetName() .. "Text"]:SetText("Show macro name *")

    local gridCheck = CreateFrame("CheckButton", "EBA_Bar" .. barIndex .. "_GridCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    gridCheck:SetPoint("TOPLEFT", macroCheck, "BOTTOMLEFT", 0, -4)
    _G[gridCheck:GetName() .. "Text"]:SetText("Show empty buttons")

    -----------------------------------------------------------------------
    -- Wire up controls when panel is shown (so DB values are current)
    -----------------------------------------------------------------------
    panel:SetScript("OnShow", function()
        local cfg = EBA.db.profile.bars[barIndex]
        if not cfg then return end

        -- Enable
        enableCheck:SetChecked(cfg.enabled)

        -- Page dropdown
        UIDropDownMenu_Initialize(pageDropdown, function()
            for p = 1, 10 do
                local info = UIDropDownMenu_CreateInfo()
                info.text = "Page " .. p
                info.value = p
                info.func = function()
                    cfg.page = p
                    UIDropDownMenu_SetSelectedValue(pageDropdown, p)
                end
                info.checked = (cfg.page == p)
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedValue(pageDropdown, cfg.page)

        -- Scale (stored as 1.0 = 100%, slider shows 50-200)
        local scalePercent = (cfg.scale or 1) * 100
        scaleSlider:SetValue(scalePercent)
        _G[scaleSlider:GetName() .. "Text"]:SetText("Scale: " .. floor(scalePercent) .. "%")

        -- Buttons
        buttonsSlider:SetValue(cfg.buttons)
        _G[buttonsSlider:GetName() .. "Text"]:SetText("Buttons: " .. cfg.buttons)

        -- Buttons per row
        perRowSlider:SetValue(cfg.buttonsPerRow)
        _G[perRowSlider:GetName() .. "Text"]:SetText("Buttons per row: " .. cfg.buttonsPerRow)

        -- Button size
        sizeSlider:SetValue(cfg.buttonSize)
        _G[sizeSlider:GetName() .. "Text"]:SetText("Button size: " .. cfg.buttonSize .. "px")

        -- Padding
        paddingSlider:SetValue(cfg.buttonSpace)
        _G[paddingSlider:GetName() .. "Text"]:SetText("Padding: " .. cfg.buttonSpace .. "px")

        -- Alpha (stored as 0-1, slider shows 0-100)
        local alphaPct = (cfg.fadeAlpha or 0) * 100
        alphaSlider:SetValue(alphaPct)
        _G[alphaSlider:GetName() .. "Text"]:SetText("Fade alpha: " .. floor(alphaPct) .. "%")

        -- Visibility dropdown
        UIDropDownMenu_Initialize(visDropdown, function()
            local modes = {
                { text = "Always show",       value = "always" },
                { text = "Show on mouseover", value = "mouseover" },
                { text = "Always hide",       value = "hidden" },
            }
            for _, m in ipairs(modes) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = m.text
                info.value = m.value
                info.func = function()
                    cfg.visibility = m.value
                    UIDropDownMenu_SetSelectedValue(visDropdown, m.value)
                    EBA:ApplyVisibility(barIndex)
                end
                info.checked = (cfg.visibility == m.value)
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedValue(visDropdown, cfg.visibility)

        -- Checkboxes
        hotkeyCheck:SetChecked(cfg.showHotkey)
        macroCheck:SetChecked(cfg.showMacro)
        gridCheck:SetChecked(cfg.showGrid)
    end)

    -----------------------------------------------------------------------
    -- OnValueChanged / OnClick handlers
    -----------------------------------------------------------------------
    enableCheck:SetScript("OnClick", function(self)
        EBA.db.profile.bars[barIndex].enabled = self:GetChecked() and true or false
    end)

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = floor(value / 5 + 0.5) * 5  -- snap to step
        local cfg = EBA.db.profile.bars[barIndex]
        cfg.scale = value / 100
        _G[self:GetName() .. "Text"]:SetText("Scale: " .. value .. "%")
        local barData = EBA.bars[barIndex]
        if barData then
            barData.frame:SetScale(cfg.scale)
        end
    end)

    buttonsSlider:SetScript("OnValueChanged", function(self, value)
        value = floor(value + 0.5)
        local cfg = EBA.db.profile.bars[barIndex]
        cfg.buttons = value
        _G[self:GetName() .. "Text"]:SetText("Buttons: " .. value)
        EBA:RefreshBarLayout(barIndex)
    end)

    perRowSlider:SetScript("OnValueChanged", function(self, value)
        value = floor(value + 0.5)
        local cfg = EBA.db.profile.bars[barIndex]
        cfg.buttonsPerRow = value
        _G[self:GetName() .. "Text"]:SetText("Buttons per row: " .. value)
        EBA:RefreshBarLayout(barIndex)
    end)

    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = floor(value + 0.5)
        local cfg = EBA.db.profile.bars[barIndex]
        cfg.buttonSize = value
        _G[self:GetName() .. "Text"]:SetText("Button size: " .. value .. "px")
        EBA:RefreshBarLayout(barIndex)
    end)

    paddingSlider:SetScript("OnValueChanged", function(self, value)
        value = floor(value + 0.5)
        local cfg = EBA.db.profile.bars[barIndex]
        cfg.buttonSpace = value
        _G[self:GetName() .. "Text"]:SetText("Padding: " .. value .. "px")
        EBA:RefreshBarLayout(barIndex)
    end)

    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = floor(value / 5 + 0.5) * 5  -- snap to step
        local cfg = EBA.db.profile.bars[barIndex]
        cfg.fadeAlpha = value / 100
        _G[self:GetName() .. "Text"]:SetText("Fade alpha: " .. floor(value) .. "%")
        EBA:ApplyVisibility(barIndex)
    end)

    hotkeyCheck:SetScript("OnClick", function(self)
        EBA.db.profile.bars[barIndex].showHotkey = self:GetChecked() and true or false
    end)

    macroCheck:SetScript("OnClick", function(self)
        EBA.db.profile.bars[barIndex].showMacro = self:GetChecked() and true or false
    end)

    gridCheck:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        EBA.db.profile.bars[barIndex].showGrid = val

        if InCombatLockdown() then
            Print("Grid changes will apply after combat.")
            return
        end

        local barData = EBA.bars[barIndex]
        if barData then
            for j = 1, MAX_BUTTONS do
                local btn = barData.buttons[j]
                if btn then
                    if val then
                        btn:SetAttribute("showgrid", 1)
                        ActionButton_ShowGrid(btn)
                    else
                        btn:SetAttribute("showgrid", 0)
                        ActionButton_Update(btn)
                    end
                end
            end
        end
    end)

    InterfaceOptions_AddCategory(panel)
    return panel
end

---------------------------------------------------------------------------
-- Build profile management subpanel
---------------------------------------------------------------------------
local function CreateProfilePanel(parentName)
    local panel = CreateFrame("Frame", "EBA_ProfilePanel", UIParent)
    panel.name = "Profiles"
    panel.parent = parentName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Profiles")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("You can change the active database profile, so you can have " ..
        "different settings for every character. Most profile changes " ..
        "require |cff00ff00/reload|r to fully apply.")

    -- Current profile display
    local currentLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    currentLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    currentLabel:SetText("Current Profile:")

    local currentValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    currentValue:SetPoint("LEFT", currentLabel, "RIGHT", 8, 0)

    -----------------------------------------------------------------------
    -- New profile editbox + button
    -----------------------------------------------------------------------
    local newLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    newLabel:SetPoint("TOPLEFT", currentLabel, "BOTTOMLEFT", 0, -20)
    newLabel:SetText("Create new profile:")

    local newBox = CreateFrame("EditBox", "EBA_NewProfileBox", panel, "InputBoxTemplate")
    newBox:SetPoint("LEFT", newLabel, "RIGHT", 12, 0)
    newBox:SetSize(160, 20)
    newBox:SetAutoFocus(false)

    local newBtn = CreateFrame("Button", "EBA_NewProfileBtn", panel, "UIPanelButtonTemplate")
    newBtn:SetPoint("LEFT", newBox, "RIGHT", 4, 0)
    newBtn:SetSize(80, 22)
    newBtn:SetText("Create")
    newBtn:SetScript("OnClick", function()
        local name = newBox:GetText()
        if name and strtrim(name) ~= "" then
            EBA.db:SetProfile(strtrim(name))
            newBox:SetText("")
            newBox:ClearFocus()
            currentValue:SetText("|cffffd100" .. EBA.db:GetCurrentProfile() .. "|r")
        end
    end)
    newBox:SetScript("OnEnterPressed", function()
        newBtn:Click()
    end)

    -----------------------------------------------------------------------
    -- Existing Profiles dropdown (switch to)
    -----------------------------------------------------------------------
    local chooseLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chooseLabel:SetPoint("TOPLEFT", newLabel, "BOTTOMLEFT", 0, -24)
    chooseLabel:SetText("Switch to profile:")

    local chooseDropdown = CreateFrame("Frame", "EBA_ProfileChooseDD", panel, "UIDropDownMenuTemplate")
    chooseDropdown:SetPoint("LEFT", chooseLabel, "RIGHT", -10, -3)
    UIDropDownMenu_SetWidth(chooseDropdown, 160)

    -----------------------------------------------------------------------
    -- Copy From dropdown
    -----------------------------------------------------------------------
    local copyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    copyLabel:SetPoint("TOPLEFT", chooseLabel, "BOTTOMLEFT", 0, -24)
    copyLabel:SetText("Copy settings from:")

    local copyDropdown = CreateFrame("Frame", "EBA_ProfileCopyDD", panel, "UIDropDownMenuTemplate")
    copyDropdown:SetPoint("LEFT", copyLabel, "RIGHT", -10, -3)
    UIDropDownMenu_SetWidth(copyDropdown, 160)

    -----------------------------------------------------------------------
    -- Delete dropdown
    -----------------------------------------------------------------------
    local deleteLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    deleteLabel:SetPoint("TOPLEFT", copyLabel, "BOTTOMLEFT", 0, -24)
    deleteLabel:SetText("Delete profile:")

    local deleteDropdown = CreateFrame("Frame", "EBA_ProfileDeleteDD", panel, "UIDropDownMenuTemplate")
    deleteDropdown:SetPoint("LEFT", deleteLabel, "RIGHT", -10, -3)
    UIDropDownMenu_SetWidth(deleteDropdown, 160)

    -----------------------------------------------------------------------
    -- Reset button
    -----------------------------------------------------------------------
    local resetBtn = CreateFrame("Button", "EBA_ProfileResetBtn", panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", deleteLabel, "BOTTOMLEFT", 0, -24)
    resetBtn:SetSize(140, 22)
    resetBtn:SetText("Reset Profile")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("EBA_CONFIRM_RESET_PROFILE")
    end)

    local resetDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    resetDesc:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    resetDesc:SetWidth(340)
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetText("|cff888888Reset the current profile back to default values.|r")

    -- Confirmation dialog
    StaticPopupDialogs["EBA_CONFIRM_RESET_PROFILE"] = {
        text = "Are you sure you want to reset the current profile to defaults?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            EBA.db:ResetProfile()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -----------------------------------------------------------------------
    -- Populate on show
    -----------------------------------------------------------------------
    panel:SetScript("OnShow", function()
        currentValue:SetText("|cffffd100" .. EBA.db:GetCurrentProfile() .. "|r")

        -- Switch profile dropdown
        UIDropDownMenu_Initialize(chooseDropdown, function()
            local profiles = EBA.db:GetProfiles()
            local current = EBA.db:GetCurrentProfile()
            for _, name in pairs(profiles) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = name
                info.func = function()
                    EBA.db:SetProfile(name)
                    UIDropDownMenu_SetSelectedValue(chooseDropdown, name)
                    currentValue:SetText("|cffffd100" .. name .. "|r")
                end
                info.checked = (name == current)
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedValue(chooseDropdown, EBA.db:GetCurrentProfile())

        -- Copy from dropdown
        UIDropDownMenu_Initialize(copyDropdown, function()
            local profiles = EBA.db:GetProfiles()
            local current = EBA.db:GetCurrentProfile()
            for _, name in pairs(profiles) do
                if name ~= current then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = name
                    info.value = name
                    info.func = function()
                        EBA.db:CopyProfile(name)
                        UIDropDownMenu_SetSelectedValue(copyDropdown, name)
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end)

        -- Delete dropdown (only non-current profiles)
        UIDropDownMenu_Initialize(deleteDropdown, function()
            local profiles = EBA.db:GetProfiles()
            local current = EBA.db:GetCurrentProfile()
            for _, name in pairs(profiles) do
                if name ~= current then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = name
                    info.value = name
                    info.func = function()
                        EBA.db:DeleteProfile(name)
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end)
    end)

    InterfaceOptions_AddCategory(panel)
    return panel
end

---------------------------------------------------------------------------
-- Main options panel
---------------------------------------------------------------------------
function EBA:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "EBA_OptionsPanel", UIParent)
    panel.name = "Extra Bars Ascension"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Extra Bars Ascension")

    -- Version
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version 2.2.1")
    version:SetTextColor(0.5, 0.5, 0.5)

    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -12)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Configure each bar using the sub-panels on the left. Settings marked with * require /reload to take effect.")

    -----------------------------------------------------------------------
    -- Lock / Unlock buttons
    -----------------------------------------------------------------------
    local lockBtn = CreateFrame("Button", "EBA_LockButton", panel, "UIPanelButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    lockBtn:SetSize(120, 22)
    lockBtn:SetText("Lock Bars")
    lockBtn:SetScript("OnClick", function()
        EBA:LockBars()
    end)

    local unlockBtn = CreateFrame("Button", "EBA_UnlockButton", panel, "UIPanelButtonTemplate")
    unlockBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)
    unlockBtn:SetSize(120, 22)
    unlockBtn:SetText("Unlock Bars")
    unlockBtn:SetScript("OnClick", function()
        EBA:UnlockBars()
    end)

    -----------------------------------------------------------------------
    -- Stance suppression checkbox
    -----------------------------------------------------------------------
    local suppressCheck = CreateFrame("CheckButton", "EBA_SuppressCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    suppressCheck:SetPoint("TOPLEFT", lockBtn, "BOTTOMLEFT", 0, -16)
    _G[suppressCheck:GetName() .. "Text"]:SetText("Suppress stance bar switching for pages claimed by EBA *")

    -----------------------------------------------------------------------
    -- Suppress info text
    -----------------------------------------------------------------------
    local suppressInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    suppressInfo:SetPoint("TOPLEFT", suppressCheck, "BOTTOMLEFT", 24, -2)
    suppressInfo:SetWidth(470)
    suppressInfo:SetJustifyH("LEFT")
    suppressInfo:SetText("|cff888888When enabled, prevents the default UI from overriding your extra bars " ..
        "when entering stances/forms that use the same action pages. " ..
        "Battle/Cat/Bear stances still swap the main bar normally.|r")

    -----------------------------------------------------------------------
    -- Button style dropdown (global)
    -----------------------------------------------------------------------
    local styleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", suppressInfo, "BOTTOMLEFT", -24, -16)
    styleLabel:SetText("Button border style:")

    local styleDropdown = CreateFrame("Frame", "EBA_ButtonStyleDD", panel, "UIDropDownMenuTemplate")
    styleDropdown:SetPoint("LEFT", styleLabel, "RIGHT", -10, -3)
    UIDropDownMenu_SetWidth(styleDropdown, 160)

    local styleInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    styleInfo:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -4)
    styleInfo:SetWidth(470)
    styleInfo:SetJustifyH("LEFT")
    styleInfo:SetText("|cff888888Minimal: thin 1px border, ideal with custom UI addons. " ..
        "Blizzard: classic rounded button frame.|r")

    -----------------------------------------------------------------------
    -- Status text (per-bar summary)
    -----------------------------------------------------------------------
    local statusHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", styleInfo, "BOTTOMLEFT", 0, -16)
    statusHeader:SetText("Current Configuration:")

    local statusTexts = {}
    for i = 1, NUM_BARS do
        local st = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        if i == 1 then
            st:SetPoint("TOPLEFT", statusHeader, "BOTTOMLEFT", 4, -6)
        else
            st:SetPoint("TOPLEFT", statusTexts[i - 1], "BOTTOMLEFT", 0, -4)
        end
        st:SetWidth(480)
        st:SetJustifyH("LEFT")
        statusTexts[i] = st
    end

    -----------------------------------------------------------------------
    -- Refresh on show
    -----------------------------------------------------------------------
    panel:SetScript("OnShow", function()
        suppressCheck:SetChecked(EBA.db.profile.suppressStanceBars)

        -- Button style dropdown
        UIDropDownMenu_Initialize(styleDropdown, function()
            local styles = {
                { text = "Minimal (1px border)", value = "minimal" },
                { text = "Blizzard (classic)", value = "blizzard" },
            }
            for _, s in ipairs(styles) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = s.text
                info.value = s.value
                info.func = function()
                    EBA.db.profile.buttonStyle = s.value
                    UIDropDownMenu_SetSelectedValue(styleDropdown, s.value)
                    EBA:ApplyButtonStyle()
                end
                info.checked = ((EBA.db.profile.buttonStyle or "minimal") == s.value)
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedValue(styleDropdown, EBA.db.profile.buttonStyle or "minimal")

        for i = 1, NUM_BARS do
            local cfg = EBA.db.profile.bars[i]
            local page = cfg.page or (6 + i)
            local scaleStr = floor((cfg.scale or 1) * 100) .. "%"
            statusTexts[i]:SetText(string.format(
                "Bar %d:  %s  |  Page %d  |  %d buttons (%d/row)  |  Size %dpx  |  Pad %dpx  |  Scale %s  |  Vis: %s",
                i,
                cfg.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r",
                page, cfg.buttons, cfg.buttonsPerRow,
                cfg.buttonSize, cfg.buttonSpace,
                scaleStr,
                cfg.visibility
            ))
        end
    end)

    suppressCheck:SetScript("OnClick", function(self)
        EBA.db.profile.suppressStanceBars = self:GetChecked() and true or false
    end)

    InterfaceOptions_AddCategory(panel)

    -- Create per-bar sub-panels
    for i = 1, NUM_BARS do
        CreateBarPanel(i, panel.name)
    end

    -- Create profile management sub-panel
    CreateProfilePanel(panel.name)
end

---------------------------------------------------------------------------
-- Build options on PLAYER_LOGIN (after DB is initialized)
---------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    EBA:CreateOptionsPanel()
    self:UnregisterEvent(event)
    self:SetScript("OnEvent", nil)
end)

-- Open options from /eba config
function EBA:OpenOptions()
    InterfaceOptionsFrame_OpenToCategory("Extra Bars Ascension")
    InterfaceOptionsFrame_OpenToCategory("Extra Bars Ascension")
end
