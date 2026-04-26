-- DEBUG: Mission ke andar check karo
print("===== MISSION DEBUG =====")
print("PlaceId:", game.PlaceId)

-- Check Workspace in mission
print("\n--- Workspace ---")
for _, child in ipairs(workspace:GetChildren()) do
    print("Workspace Child:", child.Name)
end

-- Check Unclimbable
local unclimbable = workspace:FindFirstChild("Unclimbable")
if unclimbable then
    print("\n--- Unclimbable Children ---")
    for _, child in ipairs(unclimbable:GetChildren()) do
        print("  ", child.Name)
        
        -- Check Reloads
        if child.Name == "Reloads" then
            print("\n  --- Reloads Children ---")
            for _, reloadChild in ipairs(child:GetChildren()) do
                print("    ", reloadChild.Name)
                if reloadChild.Name == "GasTanks" then
                    for _, tank in ipairs(reloadChild:GetChildren()) do
                        print("      Tank:", tank.Name, tank.ClassName)
                    end
                end
            end
        end
        
        -- Check Objective
        if child.Name == "Objective" then
            print("\n  --- Objective Children ---")
            for _, obj in ipairs(child:GetChildren()) do
                print("    ", obj.Name)
            end
        end
    end
else
    print("Unclimbable: NOT FOUND")
end

-- Check Titans
local titans = workspace:FindFirstChild("Titans")
if titans then
    print("\n--- Titans (First 5) ---")
    local count = 0
    for _, titan in ipairs(titans:GetChildren()) do
        if count < 5 then
            print("  Titan:", titan.Name)
            -- Check key parts
            if titan:FindFirstChild("Fake") then print("    Has Fake") end
            if titan:FindFirstChild("Hitboxes") then print("    Has Hitboxes") end
            if titan:FindFirstChild("HumanoidRootPart") then print("    Has HRP") end
            count = count + 1
        end
    end
    print("  Total Titans:", #titans:GetChildren())
else
    print("Titans folder: NOT FOUND")
end

-- Check workspace attributes
print("\n--- Workspace Attributes ---")
pcall(function()
    print("  Type:", workspace:GetAttribute("Type"))
    print("  Finalised:", workspace:GetAttribute("Finalised"))
    print("  Player_Count:", workspace:GetAttribute("Player_Count"))
    print("  Seconds:", workspace:GetAttribute("Seconds"))
end)

-- Check Player attributes
print("\n--- Player Attributes ---")
pcall(function()
    print("  Slot:", lp:GetAttribute("Slot"))
    print("  Cutscene:", lp:GetAttribute("Cutscene"))
    print("  Shifter:", lp.Character and lp.Character:GetAttribute("Shifter"))
    print("  Bar:", lp:GetAttribute("Bar"))
end)

-- Check Interface in game
local PlayerGui = lp:WaitForChild("PlayerGui", 5)
if PlayerGui then
    local interface = PlayerGui:FindFirstChild("Interface")
    if interface then
        print("\n--- Interface Elements ---")
        for _, child in ipairs(interface:GetChildren()) do
            print("  ", child.Name, "| Visible:", child:GetAttribute("Visible") or "N/A")
        end
    end
end

print("\n===== MISSION DEBUG END =====")
