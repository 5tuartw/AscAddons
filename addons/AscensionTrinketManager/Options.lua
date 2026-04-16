-- Ascension Trinket Manager - Options Panel
-- Interface options configuration

function ATM:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "ATM_OptionsPanel", UIParent)
    panel.name = "Ascension Trinket Manager"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension Trinket Manager")
    
    -- Version
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Version " .. ATM.version)
    version:SetTextColor(0.5, 0.5, 0.5)
    
    -- Show buttons checkbox
    local showButtonsCheck = CreateFrame("CheckButton", "ATM_ShowButtonsCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    showButtonsCheck:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -20)
    _G[showButtonsCheck:GetName() .. "Text"]:SetText("Show trinket buttons")
    showButtonsCheck:SetChecked(ATM.db.showButtons)
    showButtonsCheck:SetScript("OnClick", function(self)
        ATM.db.showButtons = self:GetChecked()
        if ATM.db.showButtons then
            ATM.container:Show()
        else
            ATM.container:Hide()
        end
    end)
    
    -- Auto-Carrot checkbox
    local autoCarrotCheck = CreateFrame("CheckButton", "ATM_AutoCarrotCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    autoCarrotCheck:SetPoint("TOPLEFT", showButtonsCheck, "BOTTOMLEFT", 0, -8)
    _G[autoCarrotCheck:GetName() .. "Text"]:SetText("Auto-equip Stick on a Carrot when mounting")
    autoCarrotCheck:SetChecked(ATM.db.autoCarrot)
    autoCarrotCheck:SetScript("OnClick", function(self)
        ATM.db.autoCarrot = self:GetChecked()
        -- Enable/disable carrot options
        if ATM.db.autoCarrot then
            ATM_CarrotSlotDropdown:Enable()
            ATM_CarrotSlotDropdownText:SetTextColor(1, 1, 1)
            ATM_CarrotInstanceCheck:Enable()
            _G["ATM_CarrotInstanceCheckText"]:SetTextColor(1, 1, 1)
            ATM_CarrotBGCheck:Enable()
            _G["ATM_CarrotBGCheckText"]:SetTextColor(1, 1, 1)
        else
            ATM_CarrotSlotDropdown:Disable()
            ATM_CarrotSlotDropdownText:SetTextColor(0.5, 0.5, 0.5)
            ATM_CarrotInstanceCheck:Disable()
            _G["ATM_CarrotInstanceCheckText"]:SetTextColor(0.5, 0.5, 0.5)
            ATM_CarrotBGCheck:Disable()
            _G["ATM_CarrotBGCheckText"]:SetTextColor(0.5, 0.5, 0.5)
        end
    end)
    
    -- Carrot slot dropdown label
    local carrotSlotLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    carrotSlotLabel:SetPoint("TOPLEFT", autoCarrotCheck, "BOTTOMLEFT", 20, -10)
    carrotSlotLabel:SetText("Carrot trinket slot:")
    
    -- Carrot slot dropdown
    local carrotSlotDropdown = CreateFrame("Frame", "ATM_CarrotSlotDropdown", panel, "UIDropDownMenuTemplate")
    carrotSlotDropdown:SetPoint("LEFT", carrotSlotLabel, "RIGHT", -10, -3)
    
    UIDropDownMenu_SetWidth(carrotSlotDropdown, 120)
    UIDropDownMenu_Initialize(carrotSlotDropdown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        
        -- Trinket slot 1 (top)
        info.text = "Trinket 1 (Top)"
        info.value = 13
        info.func = function()
            ATM.db.carrotSlot = 13
            UIDropDownMenu_SetSelectedValue(carrotSlotDropdown, 13)
        end
        info.checked = (ATM.db.carrotSlot == 13)
        UIDropDownMenu_AddButton(info)
        
        -- Trinket slot 2 (bottom)
        info.text = "Trinket 2 (Bottom)"
        info.value = 14
        info.func = function()
            ATM.db.carrotSlot = 14
            UIDropDownMenu_SetSelectedValue(carrotSlotDropdown, 14)
        end
        info.checked = (ATM.db.carrotSlot == 14)
        UIDropDownMenu_AddButton(info)
    end)
    
    UIDropDownMenu_SetSelectedValue(carrotSlotDropdown, ATM.db.carrotSlot)
    
    -- Instance checkbox
    local carrotInstanceCheck = CreateFrame("CheckButton", "ATM_CarrotInstanceCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    carrotInstanceCheck:SetPoint("TOPLEFT", carrotSlotLabel, "BOTTOMLEFT", 0, -10)
    _G[carrotInstanceCheck:GetName() .. "Text"]:SetText("Enable in Instances (dungeons/raids)")
    carrotInstanceCheck:SetChecked(ATM.db.carrotInInstance)
    carrotInstanceCheck:SetScript("OnClick", function(self)
        ATM.db.carrotInInstance = self:GetChecked()
    end)
    
    -- Battleground checkbox
    local carrotBGCheck = CreateFrame("CheckButton", "ATM_CarrotBGCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    carrotBGCheck:SetPoint("TOPLEFT", carrotInstanceCheck, "BOTTOMLEFT", 0, -8)
    _G[carrotBGCheck:GetName() .. "Text"]:SetText("Enable in Battlegrounds")
    carrotBGCheck:SetChecked(ATM.db.carrotInBattleground)
    carrotBGCheck:SetScript("OnClick", function(self)
        ATM.db.carrotInBattleground = self:GetChecked()
    end)
    
    -- Initialize state of checkboxes based on autoCarrot
    if not ATM.db.autoCarrot then
        carrotInstanceCheck:Disable()
        _G["ATM_CarrotInstanceCheckText"]:SetTextColor(0.5, 0.5, 0.5)
        carrotBGCheck:Disable()
        _G["ATM_CarrotBGCheckText"]:SetTextColor(0.5, 0.5, 0.5)
    end
    
    -- Scale slider
    local scaleSlider = CreateFrame("Slider", "ATM_ScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", carrotBGCheck, "BOTTOMLEFT", -20, -20)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValue(ATM.db.scale)
    scaleSlider:SetValueStep(0.1)
    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    _G[scaleSlider:GetName() .. "Text"]:SetText("Scale: " .. floor(ATM.db.scale * 100) .. "%")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        ATM.db.scale = value
        _G[self:GetName() .. "Text"]:SetText("Scale: " .. floor(value * 100) .. "%")
        if ATM.container then
            ATM.container:SetScale(value)
        end
    end)
    
    -- Orientation dropdown label
    local orientationLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    orientationLabel:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 20, -30)
    orientationLabel:SetText("Orientation:")
    
    -- Orientation dropdown
    local orientationDropdown = CreateFrame("Frame", "ATM_OrientationDropdown", panel, "UIDropDownMenuTemplate")
    orientationDropdown:SetPoint("LEFT", orientationLabel, "RIGHT", -10, -3)
    
    UIDropDownMenu_SetWidth(orientationDropdown, 120)
    UIDropDownMenu_Initialize(orientationDropdown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = "Horizontal"
        info.value = "horizontal"
        info.func = function()
            ATM.db.orientation = "horizontal"
            UIDropDownMenu_SetSelectedValue(orientationDropdown, "horizontal")
            ATM:UpdateLayout()
        end
        info.checked = (ATM.db.orientation == "horizontal")
        UIDropDownMenu_AddButton(info)
        
        info.text = "Vertical"
        info.value = "vertical"
        info.func = function()
            ATM.db.orientation = "vertical"
            UIDropDownMenu_SetSelectedValue(orientationDropdown, "vertical")
            ATM:UpdateLayout()
        end
        info.checked = (ATM.db.orientation == "vertical")
        UIDropDownMenu_AddButton(info)
    end)
    
    UIDropDownMenu_SetSelectedValue(orientationDropdown, ATM.db.orientation)
    
    -- Expand direction label
    local expandDirLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    expandDirLabel:SetPoint("TOPLEFT", orientationLabel, "BOTTOMLEFT", 0, -40)
    expandDirLabel:SetText("Expand direction:")
    
    -- Expand direction dropdown
    local expandDirDropdown = CreateFrame("Frame", "ATM_ExpandDirDropdown", panel, "UIDropDownMenuTemplate")
    expandDirDropdown:SetPoint("LEFT", expandDirLabel, "RIGHT", -10, -3)
    
    UIDropDownMenu_SetWidth(expandDirDropdown, 120)
    
    local function UpdateExpandDirDropdown()
        UIDropDownMenu_Initialize(expandDirDropdown, function(self)
            local info = UIDropDownMenu_CreateInfo()
            
            if ATM.db.orientation == "horizontal" then
                info.text = "Up"
                info.value = "up"
                info.func = function()
                    ATM.db.expandDirectionHorizontal = "up"
                    UIDropDownMenu_SetSelectedValue(expandDirDropdown, "up")
                    ATM:UpdateLayout()
                end
                info.checked = (ATM.db.expandDirectionHorizontal == "up")
                UIDropDownMenu_AddButton(info)
                
                info.text = "Down"
                info.value = "down"
                info.func = function()
                    ATM.db.expandDirectionHorizontal = "down"
                    UIDropDownMenu_SetSelectedValue(expandDirDropdown, "down")
                    ATM:UpdateLayout()
                end
                info.checked = (ATM.db.expandDirectionHorizontal == "down")
                UIDropDownMenu_AddButton(info)
            else  -- vertical
                info.text = "Left"
                info.value = "left"
                info.func = function()
                    ATM.db.expandDirectionVertical = "left"
                    UIDropDownMenu_SetSelectedValue(expandDirDropdown, "left")
                    ATM:UpdateLayout()
                end
                info.checked = (ATM.db.expandDirectionVertical == "left")
                UIDropDownMenu_AddButton(info)
                
                info.text = "Right"
                info.value = "right"
                info.func = function()
                    ATM.db.expandDirectionVertical = "right"
                    UIDropDownMenu_SetSelectedValue(expandDirDropdown, "right")
                    ATM:UpdateLayout()
                end
                info.checked = (ATM.db.expandDirectionVertical == "right")
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        local currentDir = ATM.db.orientation == "horizontal" and ATM.db.expandDirectionHorizontal or ATM.db.expandDirectionVertical
        UIDropDownMenu_SetSelectedValue(expandDirDropdown, currentDir)
    end
    
    UpdateExpandDirDropdown()
    
    -- Update orientation dropdown to refresh expand direction when changed
    UIDropDownMenu_Initialize(orientationDropdown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = "Horizontal"
        info.value = "horizontal"
        info.func = function()
            ATM.db.orientation = "horizontal"
            UIDropDownMenu_SetSelectedValue(orientationDropdown, "horizontal")
            ATM:UpdateLayout()
            UpdateExpandDirDropdown()
        end
        info.checked = (ATM.db.orientation == "horizontal")
        UIDropDownMenu_AddButton(info)
        
        info.text = "Vertical"
        info.value = "vertical"
        info.func = function()
            ATM.db.orientation = "vertical"
            UIDropDownMenu_SetSelectedValue(orientationDropdown, "vertical")
            ATM:UpdateLayout()
            UpdateExpandDirDropdown()
        end
        info.checked = (ATM.db.orientation == "vertical")
        UIDropDownMenu_AddButton(info)
    end)
    
    -- Instructions
    local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", expandDirLabel, "BOTTOMLEFT", 0, -40)
    instructions:SetText("|cffffffffMovement:|r Hold Shift and drag the trinket buttons to reposition")
    instructions:SetJustifyH("LEFT")
    
    -- Reset button
    local resetButton = CreateFrame("Button", "ATM_ResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 25)
    resetButton:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -20)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        -- Confirmation dialog
        StaticPopupDialogs["ATM_RESET_CONFIRM"] = {
            text = "Reset all Ascension Trinket Manager settings to defaults?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                ATM:ResetToDefaults()
                -- Refresh the options panel
                InterfaceOptionsFrame:Hide()
                InterfaceOptionsFrame_OpenToCategory(ATM.optionsPanel)
                InterfaceOptionsFrame_OpenToCategory(ATM.optionsPanel)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("ATM_RESET_CONFIRM")
    end)
    
    -- Register panel
    InterfaceOptions_AddCategory(panel)
    
    ATM.optionsPanel = panel
end
