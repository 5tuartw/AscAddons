-- ExtraBarsAscension: Selective stance/form bar suppression
-- Uses a SecureHandlerStateTemplate proxy to show/hide BonusActionBarFrame
-- during combat via restricted-environment Lua (taint-free).
--
-- Key insight from Bartender4: all combat-time frame manipulation must
-- happen through restricted-environment code (SecureHandler snippets),
-- NOT through addon Lua.  Previous approaches all failed because they
-- tried to call Show()/Hide() on frames from tainted addon execution:
--   1) Global function replacement → taint
--   2) Event interception → addon-context Show/Hide blocked
--   3) RegisterStateDriver directly on BonusActionBarFrame → Frame is
--      not a SecureHandler, so the visibility driver runs in tainted context
--
-- Current approach: A SecureHandlerStateTemplate proxy frame with a
-- [bonusbar:N] state driver.  The _onstate handler runs in restricted
-- environment (always secure) and calls Show()/Hide() on BonusActionBarFrame
-- via SetFrameRef.  This is the same pattern Bartender4 uses.
--
-- Bonusbar offset mapping (offset → page):
--   bonusbar:1 → page 7  (Cat Form / Stealth / Battle Stance)
--   bonusbar:2 → page 8  (Tree of Life / Shadow Dance / Defensive Stance)
--   bonusbar:3 → page 9  (Bear Form / Berserker Stance)
--   bonusbar:4 → page 10 (Moonkin Form)
--   bonusbar:5 → page 11 (Vehicle UI)
--
-- Default EBA bars claim pages 8 and 10 → bonusbar offsets 2 and 4.
-- Offsets 1, 3, 5 are allowed through (cat/bear/battle/berserker/vehicle).
--
-- Result per class (with suppression ON):
--   Warrior:  Battle(7) and Berserker(9) swap main bar; Defensive(8) suppressed
--   Druid:    Cat(7) and Bear(9) swap main bar; Tree(8) and Moonkin(10) suppressed
--   Rogue:    Stealth(7) swaps main bar; Shadow Dance(8) suppressed
--   Others:   No stances to suppress

local EBA = ExtraBarsAscension

-- Saved reference to Blizzard's OnUpdate animation script
local savedOnUpdate = nil

---------------------------------------------------------------------------
-- Build a lookup of suppressed bonusbar offsets from current EBA bar config
-- Pages 7-10 map to bonusbar offsets 1-4
---------------------------------------------------------------------------
local function BuildSuppressedOffsets()
    local suppressed = {}
    if not EBA.db or not EBA.db.profile.bars then return suppressed end
    for i = 1, EBA_NUM_BARS do
        local cfg = EBA.db.profile.bars[i]
        if cfg and cfg.enabled and cfg.page then
            local offset = cfg.page - 6  -- page 7→1, 8→2, 9→3, 10→4
            if offset >= 1 and offset <= 4 then
                suppressed[offset] = true
            end
        end
    end
    return suppressed
end

---------------------------------------------------------------------------
-- Apply or remove selective stance suppression
--
-- Creates a SecureHandlerStateTemplate proxy frame that:
-- 1. Has a [bonusbar:N] state driver evaluating which stance is active
-- 2. Runs _onstate-stance in restricted Lua (secure) to Show/Hide
--    BonusActionBarFrame via SetFrameRef
-- 3. Works during combat because restricted environment is always secure
---------------------------------------------------------------------------
function EBA:ApplyStanceSuppression()
    if not EBA.db or not EBA.db.profile.suppressStanceBars then return end

    local suppressed = BuildSuppressedOffsets()
    if not next(suppressed) then return end  -- nothing to suppress

    -- Disable Blizzard's event handler and animation to prevent conflicts
    BonusActionBarFrame:UnregisterEvent("UPDATE_BONUS_ACTIONBAR")

    if not savedOnUpdate then
        savedOnUpdate = BonusActionBarFrame:GetScript("OnUpdate")
    end
    BonusActionBarFrame:SetScript("OnUpdate", nil)

    -- Snap BonusActionBarFrame to its "top" (overlay) position so it
    -- appears correctly when shown (no slide animation).
    -- Blizzard's default anchor is BOTTOMLEFT of MainMenuBarArtFrame.
    BonusActionBarFrame:ClearAllPoints()
    BonusActionBarFrame:SetPoint("BOTTOMLEFT", MainMenuBarArtFrame, "BOTTOMLEFT", 3, 0)
    BonusActionBarFrame.state = "top"
    BonusActionBarFrame.mode = "none"
    BonusActionBarFrame.completed = 1

    -- Create the secure proxy frame (once)
    if not EBA.stanceProxy then
        EBA.stanceProxy = CreateFrame("Frame", "EBAStanceProxy", UIParent,
            "SecureHandlerStateTemplate")

        -- Give the proxy a reference to BonusActionBarFrame
        EBA.stanceProxy:SetFrameRef("bonus", BonusActionBarFrame)

        -- Restricted-environment handler: runs securely during combat
        -- newstate is "show" or "hide" based on the state driver
        EBA.stanceProxy:SetAttribute("_onstate-stance", [[
            local bonus = self:GetFrameRef("bonus")
            if newstate == "show" then
                bonus:Show()
            else
                bonus:Hide()
            end
        ]])
    end

    -- Build the state driver condition string:
    --   suppressed offsets → "hide"
    --   allowed offsets    → "show"
    --   no bonusbar active → "hide" (default)
    local parts = {}
    for offset = 1, 5 do
        if suppressed[offset] then
            parts[#parts + 1] = "[bonusbar:" .. offset .. "] hide"
        else
            parts[#parts + 1] = "[bonusbar:" .. offset .. "] show"
        end
    end
    parts[#parts + 1] = "hide"  -- no stance active (default)

    -- Register the state driver on the PROXY (a proper SecureHandler)
    RegisterStateDriver(EBA.stanceProxy, "stance",
        table.concat(parts, "; "))

    -- If currently in a suppressed stance, hide now
    local offset = GetBonusBarOffset()
    if offset > 0 and suppressed[offset] then
        BonusActionBarFrame:Hide()
    elseif offset > 0 then
        BonusActionBarFrame:Show()
    else
        BonusActionBarFrame:Hide()
    end
end

function EBA:RemoveStanceSuppression()
    -- Remove the state driver from the proxy
    if EBA.stanceProxy then
        UnregisterStateDriver(EBA.stanceProxy, "stance")
    end

    -- Restore Blizzard's slide animation
    if savedOnUpdate then
        BonusActionBarFrame:SetScript("OnUpdate", savedOnUpdate)
    end

    -- Give the event back to Blizzard's handler
    BonusActionBarFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")

    -- Reset animation state and sync to current stance
    BonusActionBarFrame.state = "bottom"
    BonusActionBarFrame.mode = "none"
    BonusActionBarFrame.completed = 1

    if GetBonusBarOffset() > 0 then
        ShowBonusActionBar()
    else
        HideBonusActionBar()
    end
end
