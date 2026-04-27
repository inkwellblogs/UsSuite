local postRemote = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("POST")
local refill = workspace.Unclimbable.Props.HQ.GasTank.Refill
print("Refill part:", refill)
postRemote:FireServer("Attacks", "Reload", refill)
print("Fired!")
