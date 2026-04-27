local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local INTERFACE = PlayerGui:WaitForChild("Interface")
local HUD = INTERFACE:FindFirstChild("HUD")
print("HUD:", HUD)

local top = HUD and HUD:FindFirstChild("Main") and HUD.Main:FindFirstChild("Top")
print("Top:", top)

-- Blades
local bladesFrame = top and top:FindFirstChild("Blades")
print("Blades frame:", bladesFrame)
if bladesFrame then
    for _, v in ipairs(bladesFrame:GetChildren()) do
        print("  Blades child:", v.Name, v.ClassName, pcall(function() return v.Text end))
    end
end

-- Spears
local spearsFrame = top and top:FindFirstChild("Spears")
print("Spears frame:", spearsFrame)
if spearsFrame then
    for _, v in ipairs(spearsFrame:GetChildren()) do
        print("  Spears child:", v.Name, v.ClassName, pcall(function() return v.Text end))
    end
end
