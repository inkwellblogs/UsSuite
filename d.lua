local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local top = PlayerGui.Interface.HUD.Main.Top
for _, v in ipairs(top:GetChildren()) do
    print(v.Name, v.ClassName)
end
