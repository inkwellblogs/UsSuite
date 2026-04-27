local postRemote = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("POST")
local refill = workspace.Unclimbable:FindFirstChild("Refill", true)
print("Refill found:", refill)
if refill then
    postRemote:FireServer("Attacks", "Reload", refill)
    print("Fired!")
end
