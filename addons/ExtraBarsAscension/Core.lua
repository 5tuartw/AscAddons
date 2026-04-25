-- ExtraBarsAscension: 3 additional action bars for the default UI
-- Action page per bar is configurable to avoid stance/form conflicts
-- Fully standalone - no UI replacement addon required
local ADDON_NAME = "ExtraBarsAscension"

-- Addon namespace
local EBA = CreateFrame("Frame")
EBA.bars = {}
EBA.movers = {}
EBA.unlocked = false

-- Number of extra bars
local NUM_BARS = 3
local MAX_BUTTONS = 12

-- Visual defaults
local DEFAULT_BUTTON_SIZE = 36
local DEFAULT_BUTTON_SPACE = 4

---------------------------------------------------------------------------
-- Default page assignments
-- With stance suppression enabled (default), BonusActionBarFrame's event
-- handler is hooked to filter out bonusbar offsets 2 and 4, freeing pages
-- 8 and 10.  Offsets 1 (page 7) and 3 (page 9) still swap the main bar.
-- Page 2 is free because almost nobody uses the default UI's bar paging.
-- See StanceSuppress.lua for details.
--
-- Bonusbar mapping (default UI without suppression):
--   bonusbar:1 → page 7  (Cat / Stealth / Battle)       ← allowed
--   bonusbar:2 → page 8  (Tree / Shadow Dance / Def)    ← suppressed
--   bonusbar:3 → page 9  (Bear / Berserker)             ← allowed
--   bonusbar:4 → page 10 (Moonkin)                      ← suppressed
---------------------------------------------------------------------------
local DEFAULT_PAGES = { 2, 10, 8 }

---------------------------------------------------------------------------
-- AceDB-3.0 default profile
---------------------------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        bars = {},
        positions = {},
        locked = true,
        suppressStanceBars = true,
        buttonStyle = "minimal",
    }
}
for i = 1, NUM_BARS do
    DB_DEFAULTS.profile.bars[i] = {
        enabled = true,
        buttons = 12,
        buttonsPerRow = 12,
        buttonSize = DEFAULT_BUTTON_SIZE,
        buttonSpace = DEFAULT_BUTTON_SPACE,
        page = DEFAULT_PAGES[i],
        visibility = "always",
        fadeAlpha = 0,
        scale = 1,
        showGrid = true,
        showHotkey = true,
        showMacro = true,
    }
end

---------------------------------------------------------------------------
-- Print helper
---------------------------------------------------------------------------
local function Print(...)
    print("|cff33bbffEBA|r:", ...)
end

---------------------------------------------------------------------------
-- Initialize database via AceDB-3.0
-- Migrates old SavedVariablesPerCharacter data on first run
---------------------------------------------------------------------------
local function InitDB()
    EBA.db = LibStub("AceDB-3.0"):New("ExtraBarsADB", DB_DEFAULTS, true)

    -- One-time migration from old per-character ExtraBarsDB
    if type(ExtraBarsDB) == "table" and ExtraBarsDB.bars then
        local p = EBA.db.profile
        for i, barCfg in pairs(ExtraBarsDB.bars) do
            if type(barCfg) == "table" and p.bars[i] then
                for k, v in pairs(barCfg) do
                    p.bars[i][k] = v
                end
            end
        end
        if ExtraBarsDB.positions then
            for k, v in pairs(ExtraBarsDB.positions) do
                p.positions[k] = v
            end
        end
        if ExtraBarsDB.locked ~= nil then p.locked = ExtraBarsDB.locked end
        if ExtraBarsDB.suppressStanceBars ~= nil then p.suppressStanceBars = ExtraBarsDB.suppressStanceBars end

        -- Wipe old per-char data (mark migrated so it doesn't re-trigger)
        wipe(ExtraBarsDB)
        ExtraBarsDB._migrated = true
        Print("Settings migrated to new profile system.")
    end

    -- Profile change callbacks
    EBA.db.RegisterCallback(EBA, "OnProfileChanged", "OnProfileChanged")
    EBA.db.RegisterCallback(EBA, "OnProfileCopied", "OnProfileChanged")
    EBA.db.RegisterCallback(EBA, "OnProfileReset", "OnProfileChanged")
end

---------------------------------------------------------------------------
-- Profile change handler
---------------------------------------------------------------------------
function EBA:OnProfileChanged()
    if InCombatLockdown() then
        self.pendingProfileRefresh = true
        Print("Profile changed in combat. Deferring bar refresh until combat ends.")
        return
    end

    Print("Profile changed. Reapplying bar layout and positions now.")
    for i = 1, NUM_BARS do
        if self.bars[i] then
            self:RefreshBarLayout(i)
            self:ApplyBarPosition(i)
            self:ApplyVisibility(i)

            local cfg = self.db.profile.bars[i]
            if cfg and cfg.scale then
                self.bars[i].frame:SetScale(cfg.scale)
            end
        end
    end

    Print("Some settings (action pages/stance suppression) may still require |cff00ff00/reload|r.")
end

---------------------------------------------------------------------------
-- Config helpers
---------------------------------------------------------------------------
function EBA:GetButtonSize(barIndex)
    local cfg = self.db.profile.bars[barIndex]
    return (cfg.buttonSize and cfg.buttonSize > 0) and cfg.buttonSize or DEFAULT_BUTTON_SIZE
end

function EBA:GetButtonSpace(barIndex)
    local cfg = self.db.profile.bars[barIndex]
    return (cfg.buttonSpace and cfg.buttonSpace >= 0) and cfg.buttonSpace or DEFAULT_BUTTON_SPACE
end

function EBA:GetActionOffset(barIndex)
    local cfg = self.db.profile.bars[barIndex]
    local page = (cfg.page and cfg.page >= 1 and cfg.page <= 10) and cfg.page or (6 + barIndex)
    return (page - 1) * 12
end

---------------------------------------------------------------------------
-- Slash command handler
---------------------------------------------------------------------------
local function SlashHandler(msg)
    if not msg or msg == "" then msg = "help" end
    local args = {}
    for word in msg:gmatch("%S+") do
        args[#args + 1] = word:lower()
    end
    local cmd = args[1]

    if cmd == "help" then
        Print("Commands:")
        Print("  /eba config - Open settings panel")
        Print("  /eba toggle <1-3> - Enable/disable a bar")
        Print("  /eba page <1-3> <1-10> - Set action page (see /eba pages)")
        Print("  /eba suppress - Toggle stance bar suppression")
        Print("  /eba buttons <1-3> <1-12> - Set number of buttons")
        Print("  /eba perrow <1-3> <1-12> - Set buttons per row")
        Print("  /eba size <1-3> <pixels> - Button size (16-64)")
        Print("  /eba spacing <1-3> <pixels> - Button spacing (0-20)")
        Print("  /eba scale <1-3> <50-200> - Scale percentage")
        Print("  /eba vis <1-3> <always|mouseover|hidden> - Visibility mode")
        Print("  /eba alpha <1-3> <0-1> - Fade-out alpha for mouseover mode")
        Print("  /eba grid <1-3> - Toggle show empty slots")
        Print("  /eba hotkey <1-3> - Toggle keybind text")
        Print("  /eba macro <1-3> - Toggle macro name text")
        Print("  /eba unlock - Unlock bars for repositioning")
        Print("  /eba lock - Lock bar positions")
        Print("  /eba pages - Show action page reference")
        Print("  /eba reset - Reset all settings to defaults")
        Print("  /eba status - Show current settings")
        Print("  /eba profile - Show current profile name")
        return
    end

    if cmd == "config" or cmd == "options" or cmd == "settings" then
        EBA:OpenOptions()
        return
    end

    if cmd == "profile" then
        Print("Current profile: |cffffd100" .. EBA.db:GetCurrentProfile() .. "|r")
        return
    end

    if cmd == "unlock" then
        if InCombatLockdown() then Print("|cffff0000Cannot unlock in combat.|r") return end
        EBA:UnlockBars()
        return
    end

    if cmd == "lock" then
        EBA:LockBars()
        return
    end

    if cmd == "reset" then
        EBA.db:ResetProfile()
        Print("Settings reset to defaults.")
        return
    end

    if cmd == "suppress" then
        EBA.db.profile.suppressStanceBars = not EBA.db.profile.suppressStanceBars
        local state = EBA.db.profile.suppressStanceBars and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        Print("Stance bar suppression " .. state .. ". /reload to apply.")
        if EBA.db.profile.suppressStanceBars then
            Print("BonusActionBarFrame will be hidden; main bar stays on page 1 in all forms.")
        else
            Print("Default stance/form bar swapping restored. Pages used by stances may conflict.")
        end
        return
    end

    if cmd == "status" then
        for i = 1, NUM_BARS do
            local cfg = EBA.db.profile.bars[i]
            local page = cfg.page or (6 + i)
            local scaleStr = floor((cfg.scale or 1) * 100) .. "%%"
            Print(string.format(
                "Bar %d: %s | page=%d (actions %d-%d) | buttons=%d perrow=%d | size=%dpx spacing=%dpx | scale=%s | vis=%s alpha=%.1f",
                i,
                cfg.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r",
                page, (page - 1) * 12 + 1, page * 12,
                cfg.buttons, cfg.buttonsPerRow,
                cfg.buttonSize, cfg.buttonSpace,
                scaleStr,
                cfg.visibility, cfg.fadeAlpha
            ))
        end
        return
    end

    if cmd == "pages" then
        Print("Action page reference (10 pages x 12 slots = 120 total):")
        Print("  Page 1: Main action bar")
        Print("  Page 2: Main bar page 2 (default UI Shift+arrows)")
        Print("  Page 3: Right bar 1 (MultiBarRight)")
        Print("  Page 4: Right bar 2 (MultiBarLeft)")
        Print("  Page 5: Bottom right bar (MultiBarBottomRight)")
        Print("  Page 6: Bottom left bar (MultiBarBottomLeft)")
        Print("|cffff9900Stance/form pages:|r")
        Print("  Page 7: Stance 1 (Cat Form / Stealth / Battle Stance)")
        Print("  Page 8: Stance 2 (Tree of Life / Shadow Dance / Defensive)")
        Print("  Page 9: Stance 3 (Bear Form / Berserker Stance)")
        Print("  Page 10: Stance 4 (Moonkin Form)")
        local suppress = EBA.db.profile.suppressStanceBars
        if suppress then
            Print("|cff00ff00Stance suppression ON|r - BonusActionBar hidden, all pages free.")
        else
            Print("|cffff0000Stance suppression OFF|r - form/stance pages may conflict.")
        end
        Print("Current: Bar 1=page " .. (EBA.db.profile.bars[1].page or 2) ..
               ", Bar 2=page " .. (EBA.db.profile.bars[2].page or 10) ..
               ", Bar 3=page " .. (EBA.db.profile.bars[3].page or 8))
        return
    end

    -- Commands that require a bar index
    local barIndex = tonumber(args[2])
    if not barIndex or barIndex < 1 or barIndex > NUM_BARS then
        Print("Please specify a bar number (1-" .. NUM_BARS .. ").")
        return
    end

    if cmd == "toggle" then
        EBA.db.profile.bars[barIndex].enabled = not EBA.db.profile.bars[barIndex].enabled
        local state = EBA.db.profile.bars[barIndex].enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
        Print("Bar " .. barIndex .. " " .. state .. ". /reload to apply.")
        return
    end

    if cmd == "page" then
        local p = tonumber(args[3])
        if not p or p < 1 or p > 10 then
            Print("Page must be 1-10. Type /eba pages for reference.")
            return
        end
        -- Warn if page conflicts with another EBA bar
        for i = 1, NUM_BARS do
            if i ~= barIndex and EBA.db.profile.bars[i].page == p and EBA.db.profile.bars[i].enabled then
                Print("|cffff9900Warning:|r Bar " .. i .. " is also using page " .. p .. ".")
            end
        end
        EBA.db.profile.bars[barIndex].page = p
        Print("Bar " .. barIndex .. " set to action page " .. p ..
              " (actions " .. ((p - 1) * 12 + 1) .. "-" .. (p * 12) .. "). /reload to apply.")
        return
    end

    if cmd == "grid" then
        EBA.db.profile.bars[barIndex].showGrid = not EBA.db.profile.bars[barIndex].showGrid
        local state = EBA.db.profile.bars[barIndex].showGrid and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        Print("Bar " .. barIndex .. " grid " .. state .. ". /reload to apply.")
        return
    end

    if cmd == "hotkey" then
        EBA.db.profile.bars[barIndex].showHotkey = not EBA.db.profile.bars[barIndex].showHotkey
        local state = EBA.db.profile.bars[barIndex].showHotkey and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        Print("Bar " .. barIndex .. " hotkeys " .. state .. ". /reload to apply.")
        return
    end

    if cmd == "macro" then
        EBA.db.profile.bars[barIndex].showMacro = not EBA.db.profile.bars[barIndex].showMacro
        local state = EBA.db.profile.bars[barIndex].showMacro and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        Print("Bar " .. barIndex .. " macro names " .. state .. ". /reload to apply.")
        return
    end

    local value = args[3]

    if cmd == "buttons" then
        local n = tonumber(value)
        if not n or n < 1 or n > MAX_BUTTONS then
            Print("Buttons must be 1-" .. MAX_BUTTONS .. ".")
            return
        end
        EBA.db.profile.bars[barIndex].buttons = n
        Print("Bar " .. barIndex .. " buttons set to " .. n .. ". /reload to apply.")
        return
    end

    if cmd == "perrow" then
        local n = tonumber(value)
        if not n or n < 1 or n > MAX_BUTTONS then
            Print("Buttons per row must be 1-" .. MAX_BUTTONS .. ".")
            return
        end
        EBA.db.profile.bars[barIndex].buttonsPerRow = n
        Print("Bar " .. barIndex .. " buttons per row set to " .. n .. ". /reload to apply.")
        return
    end

    if cmd == "size" then
        local n = tonumber(value)
        if not n or n < 16 or n > 64 then
            Print("Size must be 16-64.")
            return
        end
        EBA.db.profile.bars[barIndex].buttonSize = n
        Print("Bar " .. barIndex .. " size set to " .. n .. "px. /reload to apply.")
        return
    end

    if cmd == "spacing" then
        local n = tonumber(value)
        if not n or n < 0 or n > 20 then
            Print("Spacing must be 0-20.")
            return
        end
        EBA.db.profile.bars[barIndex].buttonSpace = n
        Print("Bar " .. barIndex .. " spacing set to " .. n .. "px. /reload to apply.")
        return
    end

    if cmd == "scale" then
        local n = tonumber(value)
        if not n or n < 50 or n > 200 then
            Print("Scale must be 50-200 (percentage).")
            return
        end
        EBA.db.profile.bars[barIndex].scale = n / 100
        local barData = EBA.bars[barIndex]
        if barData then
            barData.frame:SetScale(n / 100)
        end
        Print("Bar " .. barIndex .. " scale set to " .. n .. "%.")
        return
    end

    if cmd == "vis" then
        if value ~= "always" and value ~= "mouseover" and value ~= "hidden" then
            Print("Visibility must be 'always', 'mouseover', or 'hidden'.")
            return
        end
        EBA.db.profile.bars[barIndex].visibility = value
        EBA:ApplyVisibility(barIndex)
        Print("Bar " .. barIndex .. " visibility set to " .. value .. ".")
        return
    end

    if cmd == "alpha" then
        local n = tonumber(value)
        if not n or n < 0 or n > 1 then
            Print("Alpha must be 0-1.")
            return
        end
        EBA.db.profile.bars[barIndex].fadeAlpha = n
        EBA:ApplyVisibility(barIndex)
        Print("Bar " .. barIndex .. " fade alpha set to " .. n .. ".")
        return
    end

    Print("Unknown command. Type /eba help.")
end

SLASH_EXTRABARSASCENSION1 = "/eba"
SLASH_EXTRABARSASCENSION2 = "/extrabars"
SlashCmdList["EXTRABARSASCENSION"] = SlashHandler

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------
EBA:RegisterEvent("ADDON_LOADED")
EBA:RegisterEvent("PLAYER_LOGIN")
EBA:RegisterEvent("PLAYER_REGEN_ENABLED")
EBA:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        self:ApplyStanceSuppression()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.pendingProfileRefresh then
            self.pendingProfileRefresh = nil
            self:OnProfileChanged()
        end

        if self.pendingBarLayouts then
            local pending = self.pendingBarLayouts
            self.pendingBarLayouts = nil
            for barIndex in pairs(pending) do
                self:RefreshBarLayout(barIndex)
            end
        end
    end
end)

-- Expose to Bars.lua
_G.ExtraBarsAscension = EBA
_G.EBA_NUM_BARS = NUM_BARS
_G.EBA_MAX_BUTTONS = MAX_BUTTONS
_G.EBA_Print = Print
