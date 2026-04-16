-- ME Stats: UI and Statistics Display
local addonName = "MEStats"
local ME = _G[addonName]

-- Bit operations (3.3.5 compatible)
local bitBand = (_G.bit and _G.bit.band) or (_G.bit32 and _G.bit32.band)

-- Class masks for Ascension
local CLASS_MASKS = {
    ALL = 0,
    WARRIOR = 0x0001,
    PALADIN = 0x0002,
    HUNTER = 0x0004,
    ROGUE = 0x0008,
    PRIEST = 0x0010,
    DEATHKNIGHT = 0x0020,
    SHAMAN = 0x0040,
    MAGE = 0x0080,
    WARLOCK = 0x0100,
    DRUID = 0x0400,
}

-- Class display names
local CLASS_DISPLAY = setmetatable({
    ALL = "All",
}, {
    __index = function(t, token)
        if not token then return nil end
        local loc = (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[token])
                  or (_G.LOCALIZED_CLASS_NAMES_FEMALE and _G.LOCALIZED_CLASS_NAMES_FEMALE[token])
        if loc then
            rawset(t, token, loc)
            return loc
        end
        return token
    end
})

-- Normalize class token
local function normalizeClassToken(value)
    if not value then return nil end
    local token = tostring(value):upper()
    token = token:gsub("%s+", "")
    token = token:gsub("^REBORN", "")
    if token == "ALL" or token == "ANY" then return "ALL" end
    if CLASS_MASKS[token] then return token end
    return nil
end

-- Extract class information from enchant info
local function extractClasses(info)
    local classes = {}
    local function add(token)
        token = normalizeClassToken(token)
        if token then classes[token] = true end
    end
    
    if type(info) ~= "table" then
        classes.ALL = true
        return classes
    end
    
    -- Check various class requirement fields
    if type(info.ClassRequirements) == "table" then
        for _, req in ipairs(info.ClassRequirements) do
            if type(req) == "table" then
                if req.ClassType then add(req.ClassType) end
                if type(req.ClassTypes) == "table" then
                    for _, ct in ipairs(req.ClassTypes) do add(ct) end
                end
            end
        end
    end
    
    if type(info.ClassType) == "string" then add(info.ClassType) end
    if type(info.ClassTypes) == "table" then
        for _, ct in ipairs(info.ClassTypes) do add(ct) end
    end
    
    if info.ClassMask and bitBand then
        for token, mask in pairs(CLASS_MASKS) do
            if mask ~= 0 and bitBand(info.ClassMask, mask) ~= 0 then
                classes[token] = true
            end
        end
        if next(classes) == nil and info.ClassMask == 0 then
            classes.ALL = true
        end
    end
    
    if type(info.ClassRestriction) == "string" then
        for part in info.ClassRestriction:gmatch("[^,]+") do add(part) end
    elseif type(info.ClassRestriction) == "table" then
        for _, part in ipairs(info.ClassRestriction) do add(part) end
    end
    
    if type(info.Class) == "string" then add(info.Class) end
    
    if not next(classes) then classes.ALL = true end
    return classes
end

-- Add class tally to snapshot
local function addClassTally(snapshot, token, isKnown)
    snapshot.byClass[token] = snapshot.byClass[token] or { total = 0, known = 0 }
    snapshot.byClass[token].total = snapshot.byClass[token].total + 1
    if isKnown then snapshot.byClass[token].known = snapshot.byClass[token].known + 1 end
    snapshot.classTokens = snapshot.classTokens or {}
    snapshot.classTokens[token] = true
end

-- Convert class set to sorted array
local function classSetToArray(set)
    local arr = {}
    for token in pairs(set) do arr[#arr+1] = token end
    table.sort(arr, function(a,b)
        if a == b then return false end
        if a == "ALL" then return true end
        if b == "ALL" then return false end
        local an = CLASS_DISPLAY[a] or a
        local bn = CLASS_DISPLAY[b] or b
        return an < bn
    end)
    return arr
end

-- Add quality/class cell to grid
local function addQualityClassCell(snapshot, quality, token, isKnown)
    snapshot.grid = snapshot.grid or {}
    snapshot.grid[quality] = snapshot.grid[quality] or {}
    local cell = snapshot.grid[quality][token]
    if not cell then
        cell = { total = 0, known = 0 }
        snapshot.grid[quality][token] = cell
    end
    cell.total = cell.total + 1
    if isKnown then cell.known = cell.known + 1 end
end

-- Build class columns for table
local function buildClassColumns(snapshot)
    local columns = { "ALL" }
    local extras = {}
    if snapshot and snapshot.classTokens then
        for token in pairs(snapshot.classTokens) do
            if token ~= "ALL" then
                extras[#extras+1] = token
            end
        end
    end
    table.sort(extras, function(a,b)
        local an = CLASS_DISPLAY[a] or a
        local bn = CLASS_DISPLAY[b] or b
        return an < bn
    end)
    for _, token in ipairs(extras) do columns[#columns+1] = token end
    return columns
end

-- Map completion percent to item-quality-like colors
function ME:ColorForPercent(pct)
    if pct >= 100 then return 0.90, 0.80, 0.50 end          -- pale gold (matching border)
    if pct >= 90 then return 1.0, 0.51, 0.0 end             -- legendary orange
    if pct >= 75 then return 0.64, 0.21, 0.93 end           -- epic purple
    if pct >= 50 then return 0.0, 0.44, 0.87 end            -- rare blue
    if pct >= 25 then return 0.12, 0.89, 0.16 end           -- uncommon green
    if pct > 0 then return 1.0, 1.0, 1.0 end                -- common white
    return 0.62, 0.62, 0.62                                  -- poor grey
end

-- Create main frame
function ME:CreateMainFrame()
    local BackdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    
    local frame = CreateFrame("Frame", "MEStatsFrame", UIParent, BackdropTemplate)
    frame:SetSize(800, 213)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("ME Stats")
    
    -- Close button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    
    -- Summary text
    local summaryText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    summaryText:SetPoint("TOP", 0, -45)
    summaryText:SetWidth(760)
    summaryText:SetJustifyH("CENTER")
    summaryText:SetText("Loading...")
    self.summaryText = summaryText
    
    -- Percentage mode checkbox (moved next to close button)
    local percentMode = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    percentMode:SetPoint("TOPRIGHT", close, "BOTTOMLEFT", 8, 3)
    local percentLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    percentLabel:SetPoint("RIGHT", percentMode, "LEFT", 0, 0)
    percentLabel:SetText("%")
    percentMode:SetChecked(self.db.percentMode or false)
    percentMode:SetScript("OnClick", function(btn)
        ME.db.percentMode = btn:GetChecked() and true or false
        if ME.snapshot then ME:UpdateTable(ME.snapshot) end
    end)
    
    -- Tooltip for percentage label showing color key
    local tooltipFrame = CreateFrame("Frame", nil, frame)
    tooltipFrame:SetAllPoints(percentLabel)
    tooltipFrame:EnableMouse(true)
    tooltipFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("100%", 0.90, 0.80, 0.50, false)
        GameTooltip:AddLine("90-99%", 1.0, 0.51, 0.0, false)
        GameTooltip:AddLine("75-89%", 0.64, 0.21, 0.93, false)
        GameTooltip:AddLine("50-74%", 0.0, 0.44, 0.87, false)
        GameTooltip:AddLine("25-49%", 0.12, 0.89, 0.16, false)
        GameTooltip:AddLine("1-24%", 1.0, 1.0, 1.0, false)
        GameTooltip:AddLine("0%", 0.62, 0.62, 0.62, false)
        GameTooltip:Show()
    end)
    tooltipFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    self.percentMode = percentMode
    
    -- Table frame (moved up)
    local tableFrame = CreateFrame("Frame", nil, frame, BackdropTemplate)
    tableFrame:SetPoint("TOPLEFT", 20, -70)
    tableFrame:SetSize(760, 123)
    tableFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tableFrame:SetBackdropColor(0.02, 0.02, 0.02, 0.9)
    self.tableFrame = tableFrame
    self.tableHeaders = {}
    self.tableRows = {}
    
    self.mainFrame = frame
    frame:Hide()
end

-- Refresh mystic data from API
function ME:RefreshMysticData()
    local api = _G.C_MysticEnchant
    if not api then
        if self.summaryText then
            self.summaryText:SetText("Mystic API not available on this client.")
        end
        return
    end
    
    -- Aggregate data
    local pageSize = 250
    local page = 1
    local snapshot = {
        total = 0,
        known = 0,
        byQuality = {},
        byClass = {},
        entries = {},
        grid = {},
        classTokens = {}
    }
    
    while true do
        local ok, list = pcall(api.QueryEnchants, pageSize, page, "", {})
        if not ok or type(list) ~= 'table' or #list == 0 then break end
        
        for _, e in ipairs(list) do
            snapshot.total = snapshot.total + 1
            local entry = snapshot.entries[e.SpellID] or {}
            entry.known = e.Known and true or false
            entry.quality = e.Quality
            entry.name = e.SpellName
            snapshot.entries[e.SpellID] = entry
            
            snapshot.byQuality[e.Quality] = snapshot.byQuality[e.Quality] or { total=0, known=0 }
            snapshot.byQuality[e.Quality].total = snapshot.byQuality[e.Quality].total + 1
            if e.Known then
                snapshot.byQuality[e.Quality].known = snapshot.byQuality[e.Quality].known + 1
                snapshot.known = snapshot.known + 1
            end
            
            -- Get detailed info for class requirements
            local ok2, info = pcall(api.GetEnchantInfoBySpell, e.SpellID)
            if ok2 and type(info) == "table" then
                entry.classMask = info.ClassMask
                entry.spec = info.Spec
                entry.classRequirements = info.ClassRequirements
                entry.requireLevel = info.RequireLevel or info.RequirementLevel
            else
                entry.classMask = nil
                entry.spec = nil
                entry.classRequirements = nil
                entry.requireLevel = nil
            end
            
            local classSet = extractClasses(ok2 and info)
            local arr = classSetToArray(classSet)
            entry.classes = arr
            local hasAll = false
            for _, token in ipairs(arr) do
                addClassTally(snapshot, token, e.Known)
                addQualityClassCell(snapshot, e.Quality, token, e.Known)
                if token == "ALL" then hasAll = true end
            end
            if not hasAll then
                addClassTally(snapshot, "ALL", e.Known)
                addQualityClassCell(snapshot, e.Quality, "ALL", e.Known)
            end
        end
        
        if #list < pageSize then break end
        page = page + 1
    end
    
    self.snapshot = snapshot
    
    -- Update UI
    if self.summaryText then
        local pct = snapshot.total > 0 and (snapshot.known / snapshot.total * 100) or 0
        self.summaryText:SetText(string.format(
            "Total Collected: %d / %d (%.1f%%)",
            snapshot.known, snapshot.total, pct
        ))
    end
    
    self:UpdateTable(snapshot)
end

-- Update statistics table
function ME:UpdateTable(snapshot)
    if not self.tableFrame then return end
    snapshot = snapshot or self.snapshot
    if not snapshot then return end
    
    local frame = self.tableFrame
    local totalWidth = frame:GetWidth() or 760
    local labelWidth = 90
    local dataWidth = math.max(totalWidth - labelWidth, 120)
    local columns = buildClassColumns(snapshot)
    local columnCount = #columns
    
    -- Adjust column widths: make "All" wider
    local allColWidth = 80
    local otherColWidth = (dataWidth - allColWidth) / math.max(columnCount - 1, 1)
    
    local headerHeight = 20
    local rowHeight = 20
    local percentMode = self.db.percentMode or false
    
    -- Quality header
    frame.qualityHeader = frame.qualityHeader or frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    local qHeader = frame.qualityHeader
    qHeader:ClearAllPoints()
    qHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
    qHeader:SetWidth(labelWidth - 6)
    qHeader:SetJustifyH("LEFT")
    qHeader:SetText("Quality")
    qHeader:Show()
    
    -- Column headers
    self.tableHeaders = self.tableHeaders or {}
    local headers = self.tableHeaders
    
    for i = 1, columnCount do
        local token = columns[i]
        local header = headers[i]
        if not header then
            header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            headers[i] = header
        end
        
        local colWidth = (token == "ALL") and allColWidth or otherColWidth
        local xOffset = labelWidth + ((token == "ALL") and 0 or (allColWidth + (i-2)*otherColWidth))
        
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset + 6, -4)
        header:SetWidth(colWidth - 12)
        header:SetJustifyH("CENTER")
        header:SetText(CLASS_DISPLAY[token] or token)
        header:Show()
    end
    
    -- Hide unused headers
    for i = columnCount + 1, #headers do
        if headers[i] then headers[i]:Hide() end
    end
    
    -- Quality order
    local qualityOrder = {
        "RE_QUALITY_RARE",
        "RE_QUALITY_EPIC",
        "RE_QUALITY_LEGENDARY",
        "RE_QUALITY_ARTIFACT",
    }
    local qualityLabels = {
        ["RE_QUALITY_RARE"] = "Rare",
        ["RE_QUALITY_EPIC"] = "Epic",
        ["RE_QUALITY_LEGENDARY"] = "Legendary",
        ["RE_QUALITY_ARTIFACT"] = "Artifact",
        ["RE_QUALITY_COMMON"] = "Common",
        ["RE_QUALITY_UNCOMMON"] = "Uncommon",
    }
    
    -- Add any extra qualities found in data
    local extraQualities = {}
    local indexed = {}
    for idx, quality in ipairs(qualityOrder) do indexed[quality] = idx end
    for quality in pairs(snapshot.byQuality or {}) do
        if not indexed[quality] then extraQualities[#extraQualities+1] = quality end
    end
    table.sort(extraQualities)
    for _, quality in ipairs(extraQualities) do qualityOrder[#qualityOrder+1] = quality end
    
    self.tableRows = self.tableRows or {}
    local rows = self.tableRows
    local rowIndex = 0
    
    -- Total row
    do
        rowIndex = rowIndex + 1
        local row = rows[rowIndex]
        if not row then
            row = { cells = {} }
            row.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            rows[rowIndex] = row
        end
        local yOffset = -headerHeight - (rowIndex-1)*rowHeight - 4
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, yOffset)
        row.label:SetWidth(labelWidth - 6)
        row.label:SetJustifyH("LEFT")
        row.label:SetText("Total")
        row.label:Show()
        
        for col = 1, columnCount do
            local token = columns[col]
            local cdata = snapshot.byClass[token]
            local text
            if percentMode and cdata and cdata.total > 0 then
                local pct = (cdata.known / cdata.total) * 100
                text = string.format("%.1f%%", pct)
            else
                text = cdata and string.format("%d / %d", cdata.known, cdata.total) or "-"
            end
            local cell = row.cells[col]
            if not cell then
                cell = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.cells[col] = cell
            end
            local colWidth = (token == "ALL") and allColWidth or otherColWidth
            local xOffset = labelWidth + ((token == "ALL") and 0 or (allColWidth + (col-2)*otherColWidth))
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset + 6, yOffset)
            cell:SetWidth(colWidth - 12)
            cell:SetJustifyH("CENTER")
            cell:SetText(text)
            -- Always use color
            if cdata and cdata.total > 0 then
                local pct = (cdata.known / cdata.total) * 100
                local r,g,b = self:ColorForPercent(pct)
                cell:SetTextColor(r,g,b)
            else
                cell:SetTextColor(1,0.82,0)
            end
            cell:Show()
        end
        for i = columnCount + 1, #row.cells do
            if row.cells[i] then row.cells[i]:Hide() end
        end
    end
    
    -- Quality rows
    for _, quality in ipairs(qualityOrder) do
        local qdata = snapshot.byQuality[quality]
        if qdata then
            rowIndex = rowIndex + 1
            local row = rows[rowIndex]
            if not row then
                row = { cells = {} }
                row.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                rows[rowIndex] = row
            end
            local yOffset = -headerHeight - (rowIndex-1)*rowHeight - 4
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, yOffset)
            row.label:SetWidth(labelWidth - 6)
            row.label:SetJustifyH("LEFT")
            row.label:SetText(qualityLabels[quality] or tostring(quality))
            row.label:Show()
            
            for col = 1, columnCount do
                local token = columns[col]
                local cellData = snapshot.grid[quality] and snapshot.grid[quality][token]
                local text
                if percentMode and cellData and cellData.total > 0 then
                    local pct = (cellData.known / cellData.total) * 100
                    text = string.format("%.1f%%", pct)
                else
                    text = cellData and string.format("%d / %d", cellData.known, cellData.total) or "-"
                end
                local cell = row.cells[col]
                if not cell then
                    cell = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                    row.cells[col] = cell
                end
                local colWidth = (token == "ALL") and allColWidth or otherColWidth
                local xOffset = labelWidth + ((token == "ALL") and 0 or (allColWidth + (col-2)*otherColWidth))
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset + 6, yOffset)
                cell:SetWidth(colWidth - 12)
                cell:SetJustifyH("CENTER")
                cell:SetText(text)
                -- Always use color
                if cellData and cellData.total > 0 then
                    local pct = (cellData.known / cellData.total) * 100
                    local r,g,b = self:ColorForPercent(pct)
                    cell:SetTextColor(r,g,b)
                else
                    cell:SetTextColor(1,0.82,0)
                end
                cell:Show()
            end
            for i = columnCount + 1, #row.cells do
                if row.cells[i] then row.cells[i]:Hide() end
            end
        end
    end
    
    -- Hide unused rows
    for i = rowIndex + 1, #rows do
        local row = rows[i]
        if row and row.label then row.label:Hide() end
        if row and row.cells then
            for _, cell in ipairs(row.cells) do cell:Hide() end
        end
    end
    
    -- Empty state
    if rowIndex == 0 then
        frame.emptyLabel = frame.emptyLabel or frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        local empty = frame.emptyLabel
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -headerHeight)
        empty:SetWidth(totalWidth - 12)
        empty:SetJustifyH("LEFT")
        empty:SetText("Loading mystic enchant data...")
        empty:Show()
    elseif frame.emptyLabel then
        frame.emptyLabel:Hide()
    end
end
