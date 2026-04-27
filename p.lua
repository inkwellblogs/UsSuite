local lp = game:GetService("Players").LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")
local postRemote = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("POST")
local getRemote = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

local frame7 = PlayerGui.Interface.HUD.Main.Top["7"]
local text = frame7.Spears.Spears.Text
local currentAmmo = tonumber(string.match(text, "(%d+)"))
print("Current ammo:", currentAmmo)

getRemote:InvokeServer("Spears", "S_Fire", tostring(currentAmmo))
print("Fired!")
