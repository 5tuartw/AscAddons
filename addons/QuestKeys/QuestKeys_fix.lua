-- Fix for gossip button handling
-- The issue: gossip options come BEFORE quests in the button list
-- So we need to number them correctly

local function UpdateKeyHints()
    -- In GossipFrame, buttons are ordered:
    -- 1. Gossip options (vendor, innkeeper services, etc)
    -- 2. Active quests (yellow !)  
    -- 3. Available quests (yellow ?)
    
    if GossipFrame:IsVisible() then
        local numOptions = GetNumGossipOptions()
        local numActive = GetNumGossipActiveQuests()
        local numAvailable = GetNumGossipAvailableQuests()
        
        -- Gossip options get numbers 1-N
        for i = 1, numOptions do
            local button = _G["GossipTitleButton" .. i]
            AddKeyHintToButton(button, i)
        end
        
        -- Active quests get numbers (numOptions+1) to (numOptions+numActive)
        for i = 1, numActive do
            local button = _G["GossipTitleButton" .. (numOptions + i)]
            AddKeyHintToButton(button, numOptions + i)
        end
        
        -- Available quests get numbers after that
        for i = 1, numAvailable do
            local button = _G["GossipTitleButton" .. (numOptions + numActive + i)]
            AddKeyHintToButton(button, numOptions + numActive + i)
        end
    end
end

-- And HandleNumberKey needs to match:
local function HandleNumberKey(num)
    if GossipFrame:IsVisible() then
        local numOptions = GetNumGossipOptions()
        local numActive = GetNumGossipActiveQuests()
        
        if num <= numOptions then
            -- It's a gossip option
            SelectGossipOption(num)
        elseif num <= numOptions + numActive then
            -- It's an active quest
            SelectGossipActiveQuest(num - numOptions)
        else
            -- It's an available quest
            SelectGossipAvailableQuest(num - numOptions - numActive)
        end
    end
end
