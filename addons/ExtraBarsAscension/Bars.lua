-- ExtraBarsAscension: Bar creation, styling, movers, and visibility
-- Fully standalone - uses only standard 3.3.5 WoW API
local EBA = ExtraBarsAscension
local NUM_BARS = EBA_NUM_BARS
local MAX_BUTTONS = EBA_MAX_BUTTONS
local Print = EBA_Print

-- Locals
local _G = _G
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local unpack = unpack
local math_ceil = math.ceil
local math_min = math.min

-- Mouseover check interval (seconds)
local MOUSEOVER_UPDATE_INTERVAL = 0.1

---------------------------------------------------------------------------
-- Visual constants (self-contained, no external addon dependency)
---------------------------------------------------------------------------
local FONT_FACE = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE = 11
local FONT_STYLE = "OUTLINE"

local BACKDROP_COLOR = { 0.1, 0.1, 0.1, 0.8 }
local BORDER_COLOR = { 0.3, 0.3, 0.3, 1 }
local MOVER_BORDER_COLOR = { 0.18, 0.71, 1, 1 }

-- Standard Blizzard backdrop for buttons and movers
local BUTTON_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Icon texture coords (slight crop to remove border artifacts)
local TEX_COORDS = { 0.08, 0.92, 0.08, 0.92 }

-- Class color for mover highlight
local _, playerClass = UnitClass("player")
local classColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or { r = 1, g = 1, b = 1 }

---------------------------------------------------------------------------
-- Default bar positions (center screen, stacked vertically)
---------------------------------------------------------------------------
local DEFAULT_POSITIONS = {
    [1] = { "CENTER", "UIParent", "CENTER", 0, -220 },
    [2] = { "CENTER", "UIParent", "CENTER", 0, -265 },
    [3] = { "CENTER", "UIParent", "CENTER", 0, -310 },
}

---------------------------------------------------------------------------
-- Style a single action button
-- Uses standard ActionButtonTemplate elements.
-- "minimal" style: 1px border backdrop, cropped icon, hidden NormalTexture
-- "blizzard" style: default Blizzard NormalTexture, no custom backdrop
---------------------------------------------------------------------------
local function StyleActionButton(button, size, barIndex)
    local name = button:GetName()
    local icon = _G[name .. "Icon"]
    local count = _G[name .. "Count"]
    local flash = _G[name .. "Flash"]
    local hotkey = _G[name .. "HotKey"]
    local macroName = _G[name .. "Name"]
    local normal = _G[name .. "NormalTexture"]
    local float = _G[name .. "FloatingBG"]
    local cooldown = _G[name .. "Cooldown"]
    local cfg = EBA.db.profile.bars[barIndex]
    local style = EBA.db.profile.buttonStyle or "minimal"

    -- Mark as EBA button for hooks
    button.ebaBarIndex = barIndex

    -- Remove flash texture for all styles
    if flash then flash:SetTexture("") end

    -- Hide FloatingBG for all styles
    if float then float:Hide() end

    -- Size the button
    button:SetSize(size, size)

    if style == "blizzard" then
        -- Blizzard style: show NormalTexture, no custom backdrop
        if button.ebBackdrop then
            button:SetBackdrop(nil)
            button.ebBackdrop = false
        end

        -- Let NormalTexture show with proper scaling
        if normal then
            local ntSize = size * 66 / 36
            normal:ClearAllPoints()
            normal:SetPoint("CENTER", button, "CENTER", 0, -1)
            normal:SetWidth(ntSize)
            normal:SetHeight(ntSize)
            normal:SetAlpha(1)
        end

        -- Standard icon (no custom cropping)
        if icon then
            icon:SetTexCoord(0, 1, 0, 1)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        end

        -- Cooldown frame fills button
        if cooldown then
            cooldown:ClearAllPoints()
            cooldown:SetAllPoints(button)
        end
    else
        -- Minimal style (1px border)
        button:SetNormalTexture("")

        if not button.ebBackdrop then
            button:SetBackdrop(BUTTON_BACKDROP)
            button:SetBackdropColor(unpack(BACKDROP_COLOR))
            button:SetBackdropBorderColor(unpack(BORDER_COLOR))
            button.ebBackdrop = true
        end

        -- Crop and position the icon inside the 1px border
        if icon then
            icon:SetTexCoord(unpack(TEX_COORDS))
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        end

        -- Cooldown frame sized to match icon
        if cooldown then
            cooldown:ClearAllPoints()
            cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        end

        -- Flatten the normal texture so it doesn't override our look
        if normal then
            normal:ClearAllPoints()
            normal:SetPoint("TOPLEFT")
            normal:SetPoint("BOTTOMRIGHT")
            normal:SetAlpha(0)
        end
    end

    -- Count text (bottom-right, e.g. stack count)
    if count then
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", 0, 2)
        count:SetFont(FONT_FACE, FONT_SIZE, FONT_STYLE)
    end

    -- Hotkey text (top-right)
    if hotkey then
        if cfg.showHotkey then
            hotkey:ClearAllPoints()
            hotkey:SetPoint("TOPRIGHT", 0, -2)
            hotkey:SetFont(FONT_FACE, FONT_SIZE - 1, FONT_STYLE)
        else
            hotkey:SetText("")
            hotkey:Hide()
        end
    end

    -- Macro name text (bottom-center)
    if macroName then
        if cfg.showMacro then
            macroName:SetFont(FONT_FACE, FONT_SIZE - 2, FONT_STYLE)
            macroName:ClearAllPoints()
            macroName:SetPoint("BOTTOM", 1, 1)
            macroName:SetVertexColor(1, 0.82, 0, 1)
        else
            macroName:SetText("")
            macroName:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Calculate bar dimensions
---------------------------------------------------------------------------
local function GetBarDimensions(barIndex)
    local cfg = EBA.db.profile.bars[barIndex]
    local size = EBA:GetButtonSize(barIndex)
    local space = EBA:GetButtonSpace(barIndex)
    local numButtons = cfg.buttons
    local perRow = cfg.buttonsPerRow

    local cols = math_min(numButtons, perRow)
    local rows = math_ceil(numButtons / perRow)

    local width = cols * size + (cols - 1) * space
    local height = rows * size + (rows - 1) * space

    return width, height, cols, rows, size, space
end

---------------------------------------------------------------------------
-- Layout buttons within a bar
---------------------------------------------------------------------------
local function LayoutButtons(barIndex)
    local barData = EBA.bars[barIndex]
    if not barData then return end

    if InCombatLockdown() then
        EBA.pendingBarLayouts = EBA.pendingBarLayouts or {}
        EBA.pendingBarLayouts[barIndex] = true
        return
    end

    local cfg = EBA.db.profile.bars[barIndex]
    local size = EBA:GetButtonSize(barIndex)
    local space = EBA:GetButtonSpace(barIndex)
    local perRow = cfg.buttonsPerRow
    local numButtons = cfg.buttons
    local frame = barData.frame

    -- Resize bar frame
    local w, h = GetBarDimensions(barIndex)
    frame:SetSize(w, h)

    -- Position each button
    for i = 1, MAX_BUTTONS do
        local button = barData.buttons[i]
        if i <= numButtons then
            button:ClearAllPoints()
            button:SetSize(size, size)

            local row = math_ceil(i / perRow) - 1
            local col = (i - 1) % perRow

            button:SetPoint(
                "TOPLEFT", frame, "TOPLEFT",
                col * (size + space),
                -row * (size + space)
            )
            button:Show()
        else
            button:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Live refresh: relayout + restyle a bar (called from Options panel)
---------------------------------------------------------------------------
function EBA:RefreshBarLayout(barIndex)
    if InCombatLockdown() then
        self.pendingBarLayouts = self.pendingBarLayouts or {}
        self.pendingBarLayouts[barIndex] = true
        return
    end

    local barData = self.bars[barIndex]
    if not barData then return end
    local cfg = EBA.db.profile.bars[barIndex]
    local size = self:GetButtonSize(barIndex)
    LayoutButtons(barIndex)
    for i = 1, MAX_BUTTONS do
        local button = barData.buttons[i]
        if button and i <= cfg.buttons then
            StyleActionButton(button, size, barIndex)
        end
    end
    -- Re-sync mover if visible
    local mover = self.movers[barIndex]
    if mover and mover:IsShown() then
        mover:SetAllPoints(barData.frame)
    end
end

function EBA:ApplyBarPosition(barIndex)
    local barData = self.bars[barIndex]
    if not barData then
        return
    end

    local frame = barData.frame
    local barName = frame:GetName()
    local pos = self.db.profile.positions[barName] or DEFAULT_POSITIONS[barIndex]
    if type(pos) ~= "table" then
        return
    end

    local point = pos[1] or "CENTER"
    local relativeTo = _G[pos[2]] or UIParent
    local relativePoint = pos[3] or "CENTER"
    local x = tonumber(pos[4]) or 0
    local y = tonumber(pos[5]) or 0

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, x, y)

    local mover = self.movers[barIndex]
    if mover and mover:IsShown() then
        mover:SetAllPoints(frame)
    end
end

---------------------------------------------------------------------------
-- Create a single extra bar
---------------------------------------------------------------------------
local function CreateBar(barIndex)
    local cfg = EBA.db.profile.bars[barIndex]
    if not cfg.enabled then return end

    local w, h = GetBarDimensions(barIndex)
    local barName = "EBABar" .. barIndex
    local size = EBA:GetButtonSize(barIndex)

    -- Bar container frame
    local frame = CreateFrame("Frame", barName, UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(w, h)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)

    -- Restore saved position or use default
    local pos = EBA.db.profile.positions[barName]
    if not pos then
        pos = DEFAULT_POSITIONS[barIndex]
    end
    frame:SetPoint(pos[1], _G[pos[2]] or UIParent, pos[3], pos[4], pos[5])

    -- Store bar data
    local barData = {
        frame = frame,
        buttons = {},
        index = barIndex,
    }

    -- Create action buttons using configurable page offset
    local offset = EBA:GetActionOffset(barIndex)
    local page = offset / 12 + 1
    for i = 1, MAX_BUTTONS do
        local actionID = offset + i
        local buttonName = barName .. "Button" .. i

        local button = CreateFrame("CheckButton", buttonName, frame, "ActionBarButtonTemplate")

        -- Override attributes set by ActionButton_OnLoad:
        -- useparent-actionpage=true would inherit parent's actionpage;
        -- clearing it and setting our own prevents the fallback to
        -- GetActionBarPage() in ActionButton_CalculateAction.
        button:SetAttribute("useparent-actionpage", nil)
        button:SetAttribute("useparent-unit", nil)
        button:SetAttribute("actionpage", page)
        button:SetAttribute("action", actionID)
        button.action = actionID
        button:SetID(i)

        -- ActionBarButtonTemplate includes native OnDragStart/OnReceiveDrag
        -- scripts that use self.action, so no WrapScript needed.

        -- Show grid for empty slots if configured
        if cfg.showGrid then
            button:SetAttribute("showgrid", 1)
            ActionButton_ShowGrid(button)
        end

        -- Style the button
        StyleActionButton(button, size, barIndex)

        barData.buttons[i] = button
    end

    EBA.bars[barIndex] = barData

    -- Layout buttons
    LayoutButtons(barIndex)

    -- Set bar index for mouseover system
    frame.ebaBarIndex = barIndex

    -- Apply scale
    if cfg.scale and cfg.scale ~= 1 then
        frame:SetScale(cfg.scale)
    end

    -- Apply visibility mode
    EBA:ApplyVisibility(barIndex)

    return barData
end

---------------------------------------------------------------------------
-- Mouseover visibility using OnUpdate + MouseIsOver
---------------------------------------------------------------------------
local function MouseoverOnUpdate(self, elapsed)
    self.ebaMouseTimer = (self.ebaMouseTimer or 0) + elapsed
    if self.ebaMouseTimer < MOUSEOVER_UPDATE_INTERVAL then return end
    self.ebaMouseTimer = 0

    local barIndex = self.ebaBarIndex
    if not barIndex then return end
    if EBA.unlocked then
        self:SetAlpha(1)
        return
    end

    if MouseIsOver(self) then
        self:SetAlpha(1)
    else
        local cfg = EBA.db.profile.bars[barIndex]
        self:SetAlpha(cfg.fadeAlpha)
    end
end

function EBA:ApplyVisibility(barIndex)
    local barData = self.bars[barIndex]
    if not barData then return end

    local cfg = EBA.db.profile.bars[barIndex]
    local frame = barData.frame

    if cfg.visibility == "hidden" then
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        frame:SetScript("OnUpdate", nil)
    elseif cfg.visibility == "mouseover" then
        frame:EnableMouse(true)
        frame:SetAlpha(cfg.fadeAlpha)
        frame:SetScript("OnUpdate", MouseoverOnUpdate)
    else -- "always"
        frame:EnableMouse(true)
        frame:SetAlpha(1)
        frame:SetScript("OnUpdate", nil)
    end
end

---------------------------------------------------------------------------
-- Mover system (self-contained, no external dependency)
---------------------------------------------------------------------------
local function CreateMover(barIndex)
    local barData = EBA.bars[barIndex]
    if not barData then return end
    if EBA.movers[barIndex] then return EBA.movers[barIndex] end

    local frame = barData.frame

    local mover = CreateFrame("Frame", "EBABarMover" .. barIndex, UIParent)
    mover:SetBackdrop(BUTTON_BACKDROP)
    mover:SetBackdropColor(unpack(BACKDROP_COLOR))
    mover:SetBackdropBorderColor(unpack(MOVER_BORDER_COLOR))
    mover:SetAllPoints(frame)
    mover:SetFrameStrata("TOOLTIP")
    mover:EnableMouse(true)
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")

    mover:SetScript("OnDragStart", function(self)
        local bar = EBA.bars[barIndex].frame
        bar:SetMovable(true)
        bar:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        local bar = EBA.bars[barIndex].frame
        bar:StopMovingOrSizing()
        bar:SetMovable(false)

        -- Save position
        local ap, _, rp, x, y = bar:GetPoint()
        local barName = bar:GetName()
        EBA.db.profile.positions[barName] = { ap, "UIParent", rp, x, y }
    end)

    mover:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b)
    end)

    mover:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(MOVER_BORDER_COLOR))
    end)

    -- Label
    local label = mover:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT_FACE, FONT_SIZE, FONT_STYLE)
    label:SetPoint("CENTER")
    label:SetTextColor(1, 1, 1)
    label:SetText("Extra Bar " .. barIndex)

    mover:Hide()
    EBA.movers[barIndex] = mover
    return mover
end

function EBA:UnlockBars()
    if InCombatLockdown() then
        Print("|cffff0000Cannot unlock in combat.|r")
        return
    end
    self.unlocked = true
    EBA.db.profile.locked = false

    for i = 1, NUM_BARS do
        if self.bars[i] then
            self.bars[i].frame:SetAlpha(1)

            local mover = CreateMover(i)
            if mover then mover:Show() end
        end
    end
    Print("Bars unlocked. Drag to reposition. Type |cff00ff00/eba lock|r when done.")
end

function EBA:LockBars()
    self.unlocked = false
    EBA.db.profile.locked = true

    for i = 1, NUM_BARS do
        if self.movers[i] then
            self.movers[i]:Hide()
        end
        if self.bars[i] then
            self:ApplyVisibility(i)
        end
    end
    Print("Bars locked.")
end

---------------------------------------------------------------------------
-- Initialization - create bars after login
---------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        for i = 1, NUM_BARS do
            local cfg = EBA.db.profile.bars[i]
            if cfg and cfg.enabled then
                CreateBar(i)
            end
        end

        -- Force update all buttons after a short delay to ensure
        -- action data is cached by the client
        local updateFrame = CreateFrame("Frame")
        local elapsed = 0
        updateFrame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed > 0.5 then
                for i = 1, NUM_BARS do
                    local barData = EBA.bars[i]
                    if barData then
                        for j = 1, EBA.db.profile.bars[i].buttons do
                            local btn = barData.buttons[j]
                            if btn and btn:IsShown() then
                                ActionButton_Update(btn)
                            end
                        end
                    end
                end
                self:SetScript("OnUpdate", nil)
            end
        end)

        self:UnregisterEvent(event)
    end
end)

---------------------------------------------------------------------------
-- Hide stack count of "1" on EBA buttons (items that don't meaningfully stack)
---------------------------------------------------------------------------
hooksecurefunc("ActionButton_UpdateCount", function(self)
    if InCombatLockdown() then return end
    local name = self:GetName()
    if not name or not name:match("^EBABar") then return end
    local count = _G[name .. "Count"]
    if count and count:GetText() == "1" then
        count:SetText("")
    end
end)

---------------------------------------------------------------------------
-- Hook ActionButton_Update to re-apply styling after Blizzard resets it.
-- ActionButton_Update calls SetNormalTexture() which undoes our styling:
--   populated slots: SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
--   empty slots:     SetNormalTexture("Interface\\Buttons\\UI-Quickslot")
-- This hook re-hides the texture (minimal) or re-sizes it (blizzard).
---------------------------------------------------------------------------
hooksecurefunc("ActionButton_Update", function(self)
    if InCombatLockdown() then return end
    local name = self:GetName()
    if not name or not name:match("^EBABar") then return end

    local style = EBA.db.profile.buttonStyle or "minimal"
    local normal = _G[name .. "NormalTexture"]

    if style == "minimal" then
        -- Re-hide the Blizzard NormalTexture
        if normal then
            self:SetNormalTexture("")
            normal:SetAlpha(0)
        end
    else
        -- Blizzard style: ensure NormalTexture is properly sized
        if normal then
            local barIndex = self.ebaBarIndex
            local size = barIndex and EBA:GetButtonSize(barIndex) or 36
            local ntSize = size * 66 / 36
            normal:ClearAllPoints()
            normal:SetPoint("CENTER", self, "CENTER", 0, -1)
            normal:SetWidth(ntSize)
            normal:SetHeight(ntSize)
            normal:SetAlpha(1)
        end
    end
end)

---------------------------------------------------------------------------
-- Re-style all buttons (called when button style changes live)
---------------------------------------------------------------------------
function EBA:ApplyButtonStyle()
    if InCombatLockdown() then return end

    for i = 1, NUM_BARS do
        local barData = self.bars[i]
        if barData then
            local cfg = self.db.profile.bars[i]
            local size = self:GetButtonSize(i)
            for j = 1, MAX_BUTTONS do
                local btn = barData.buttons[j]
                if btn and j <= cfg.buttons then
                    StyleActionButton(btn, size, i)
                    ActionButton_Update(btn)
                end
            end
        end
    end
end
