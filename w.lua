local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local INTERFACE = PlayerGui:WaitForChild("Interface")
local frame7 = INTERFACE.HUD.Main.Top["7"]
local spears = frame7:FindFirstChild("Spears")
print("Spears frame:", spears)
if spears then
    print("Spears visible:", spears.Visible)
    local label = spears:FindFirstChild("Spears")
    print("Spears label:", label)
    if label then print("Text:", label.Text) end
end
