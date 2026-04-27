local lp = game:GetService("Players").LocalPlayer
print("Slot:", lp:GetAttribute("Slot"))

local getRemote = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
local liveData = getRemote:InvokeServer("Data", "Copy")
print("LiveData:", liveData)
if liveData and liveData.Slots then
    local slot = liveData.Slots[lp:GetAttribute("Slot")]
    print("Slot data:", slot)
    if slot then print("Weapon:", slot.Weapon) end
end
