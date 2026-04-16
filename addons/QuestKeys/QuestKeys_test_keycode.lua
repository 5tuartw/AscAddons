-- Simple test to verify IsKeyDown works
local frame = CreateFrame("Frame")
local lastSpace = false
local lastOne = false

frame:SetScript("OnUpdate", function()
    -- Test spacebar (key code 57)
    if IsKeyDown(57) then
        if not lastSpace then
            print("|cffFF0000SPACE KEY DETECTED (code 57)|r")
            lastSpace = true
        end
    else
        lastSpace = false
    end
    
    -- Test 1 key (key code 2)
    if IsKeyDown(2) then
        if not lastOne then
            print("|cffFF00FF1 KEY DETECTED (code 2)|r")
            lastOne = true
        end
    else
        lastOne = false
    end
end)

print("|cff00ff00KeyCode Test loaded - Press Space or 1 anywhere|r")
