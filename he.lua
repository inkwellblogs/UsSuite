local top7 = game:GetService("Players").LocalPlayer.PlayerGui.Interface.HUD.Main.Top["7"]
for _, frame in ipairs(top7:GetChildren()) do
    if frame:IsA("Frame") then
        print("Frame:", frame.Name)
        for _, child in ipairs(frame:GetChildren()) do
            local ok, text = pcall(function() return child.Text end)
            print("  ->", child.Name, child.ClassName, ok and text or "")
        end
    end
end
