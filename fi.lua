local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local top = PlayerGui.Interface.HUD.Main.Top
for _, frame in ipairs(top:GetChildren()) do
    if frame:IsA("Frame") then
        for _, child in ipairs(frame:GetChildren()) do
            print(frame.Name, "->", child.Name, child.ClassName, pcall(function() return child.Text end))
        end
    end
end
