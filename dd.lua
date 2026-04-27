local lp = game:GetService("Players").LocalPlayer
print("Character:", lp.Character)
print("HRP:", lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"))
print("PlaceId:", game.PlaceId)
