repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local lp = Players.LocalPlayer 

repeat task.wait() until lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes")
local getRemote = remotesFolder:WaitForChild("GET")
local postRemote = remotesFolder:WaitForChild("POST")
local vim = game:GetService("VirtualInputManager")
local INTERFACE = PlayerGui:WaitForChild("Interface")
local rewards = INTERFACE:FindFirstChild("Rewards")
local statsFrame = rewards and rewards.Main.Info.Main.Stats or nil
local itemsFrame = rewards and rewards.Main.Info.Main.Items or nil
local customisation = INTERFACE:FindFirstChild("Customisation") or nil
local familyFrame = customisation and customisation:FindFirstChild("Family") or nil
local rollButton = familyFrame and familyFrame.Buttons_2.Roll or nil

local V3_ZERO = Vector3.new(0, 0, 0)

local lastPlayerData, lastPlayerDataTime = nil, 0
local function GetPlayerData()
	if os.clock() - lastPlayerDataTime < 0.5 and lastPlayerData then return lastPlayerData end
	local args = {
		"Functions",
		"Settings",
		"Get"
	}
	lastPlayerData = getRemote:InvokeServer(unpack(args))
	lastPlayerDataTime = os.clock()	
	return lastPlayerData
end

local mapData = nil
local startLoadTime = os.clock()
local isLobby = game.PlaceId == 14916516914

repeat
    task.wait(1)
    mapData = getRemote:InvokeServer("Data", "Copy")
    if not mapData then
        lastPlayerData = nil 
        GetPlayerData()
    end
until mapData ~= nil or (lastPlayerData ~= nil and (isLobby or os.clock() - startLoadTime > 15))

if mapData then
	if mapData.Map.Type == "Raids" then
		repeat task.wait() until workspace:GetAttribute("Finalised")
	end
end

local function checkMission()
	local activeType = workspace:GetAttribute("Type")
	if activeType then return true end
    mapData = getRemote:InvokeServer("Data", "Copy")
    return mapData ~= nil and mapData.Map ~= nil and mapData.Slots ~= nil
end

local familyRaritiesOptions = {"Rare", "Epic", "Legendary", "Mythical"}

if not isfolder("./THUB") then makefolder("./THUB") end
if not isfolder("./THUB/aotr") then makefolder("./THUB/aotr") end

local ConfigFile = "./THUB/aotr/dropdown_config.json"
local returnCounterPath = "./THUB/aotr/return_lobby_counter.txt"
local HttpService = game:GetService("HttpService")

local function LoadConfig()
	if not isfile(ConfigFile) then
		return { Missions = {}, Raids = {}, DeleteMap = false }
	end
	local success, config = pcall(HttpService.JSONDecode, HttpService, readfile(ConfigFile))
	return success and config or { Missions = {}, Raids = {}, DeleteMap = false }
end

local function SaveConfig(config)
	pcall(writefile, ConfigFile, HttpService:JSONEncode(config))
end

local DropdownConfig = LoadConfig()
getgenv().AutoExec = false
getgenv().AutoRoll = false
getgenv().AutoSlot = false
getgenv().AutoUpgrade = false
getgenv().AutoPerk = false
getgenv().AutoSkillTree = false
getgenv().AutoStart = false
getgenv().AutoChest = false
getgenv().AutoRetry = false
getgenv().AutoSkip = false
getgenv().AutoPrestige = false
getgenv().AutoFailsafe = false
getgenv().AutoExecute = false
getgenv().RewardWebhook = false
getgenv().MythicalFamilyWebhook = false
getgenv().AutoReturnLobby = false
getgenv().OpenSecondChest = false
getgenv().DeleteMap = DropdownConfig.DeleteMap or false
if not isfile(returnCounterPath) then writefile(returnCounterPath, "0") end

getgenv().CurrentStatusLabel = nil
function UpdateStatus(text)
	if getgenv().CurrentStatusLabel then 
		getgenv().CurrentStatusLabel:SetText("Status: " .. text) 
	end
end

local AutoFarm = {}
AutoFarm._running = false

getgenv().AutoFarmConfig = {
	AttackCooldown = 1,
	ReloadCooldown = 1,
	AttackRange = 150,
	MoveSpeed = 400,
	HeightOffset = 250,
	MovementMode = "Hover",
}

getgenv().MasteryFarmConfig = {
	Enabled = false,
	Mode = "Both",
}

task.spawn(function()
	while true do
		local Injuries = lp.Character and lp.Character:FindFirstChild("Injuries")
		if Injuries then
			for i, v in Injuries:GetChildren() do
				v:Destroy()
			end
		end
		task.wait(1)
	end
end)

function AutoFarm:Start()
	if self._running or isLobby then return end
	self._running = true
	task.spawn(function()
		UpdateStatus("Waiting for mission...")
		local function checkReady()
			local char = lp.Character
			local playerReady = char and (char:GetAttribute("Shifter") or (char:FindFirstChild("Main") and char.Main:FindFirstChild("W")))
			local mapReady = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Reloads")
			local titans = workspace:FindFirstChild("Titans")
			local titansReady = false
			if titans then
				for _, v in ipairs(titans:GetChildren()) do
					if v:FindFirstChild("Fake") then titansReady = true break end
				end
			end
			return playerReady and mapReady and titansReady
		end

		while self._running and not checkReady() do task.wait(1) end
		if not self._running then return end
		UpdateStatus("Farming")

		local titansFolder = workspace:FindFirstChild("Titans")
		local lastAttack = 0
		local currentChar, root, charParts = nil, nil, {}
		local bossNames = {Attack_Titan = true, Armored_Titan = true, Female_Titan = true}
		local attackTitanSpawnTime = nil
		local AttackRangeSq = getgenv().AutoFarmConfig.AttackRange * getgenv().AutoFarmConfig.AttackRange

		local function updateCharState()
			local char = lp.Character
			if not char then return false end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end
			if char ~= currentChar then
				currentChar, root, charParts = char, hrp, {}
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false table.insert(charParts, p) end
				end
			end
			return true
		end

		local validNapes, nextTitanCacheUpdate, nextObjectiveCacheUpdate, cachedObjectivePart = {}, 0, 0, nil
		local masteryComboIndex, lastMasteryPunch = 1, 0

		while self._running do
			if lp:GetAttribute("Cutscene") then task.wait() continue end
			if not checkMission() then UpdateStatus("Waiting for mission...") task.wait(1) continue end

			local slotIndex = lp:GetAttribute("Slot")
			local slotData = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]
			if not slotData then task.wait(1) continue end

			slotData.Weapon = slotData.Weapon or "Blades"
			getgenv().AutoFarmConfig.AttackCooldown = (slotData.Weapon == "Blades") and 0.15 or 1

			if not updateCharState() then task.wait() continue end
			titansFolder = workspace:FindFirstChild("Titans") or titansFolder
			
			local now = os.clock()
			if now >= nextTitanCacheUpdate then
				nextTitanCacheUpdate = now + 0.1
				table.clear(validNapes)
				for _, v in ipairs(titansFolder:GetChildren()) do
					if not v:GetAttribute("Killed") then
						local nape = v:FindFirstChild("Hitboxes") and v.Hitboxes:FindFirstChild("Hit") and v.Hitboxes.Hit:FindFirstChild("Nape")
						if nape then table.insert(validNapes, nape) end
					end
				end
			end

			local targetPart = validNapes[1] -- Simplified targeting for completion
			if targetPart then
				local titanHRP = targetPart.Parent.Parent.Parent:FindFirstChild("HumanoidRootPart")
				local targetHeightPos = titanHRP and (titanHRP.CFrame * CFrame.new(0, getgenv().AutoFarmConfig.HeightOffset, 30)).Position or targetPart.Position + Vector3.new(0, 250, 0)
				
				if getgenv().AutoFarmConfig.MovementMode == "Hover" then
					local dir = targetHeightPos - root.Position
					root.AssemblyLinearVelocity = dir.Magnitude > 1 and dir.Unit * getgenv().AutoFarmConfig.MoveSpeed or V3_ZERO
				else
					root.CFrame = CFrame.new(targetHeightPos)
				end

				if (root.Position - targetPart.Position).Magnitude <= getgenv().AutoFarmConfig.AttackRange and (now - lastAttack) >= getgenv().AutoFarmConfig.AttackCooldown then
					lastAttack = now
					postRemote:FireServer("Attacks", "Slash", true)
					postRemote:FireServer("Hitboxes", "Register", targetPart, math.random(625, 850))
				end
			end
			task.wait()
		end
	end)
end

function AutoFarm:Stop() self._running = false end

-- [UI Initialization & Event Listeners]
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({ Title = "TITANIC HUB | AOT:R", Center = true, AutoShow = true })
local Tabs = { Main = Window:AddTab("Main"), Misc = Window:AddTab("Misc") }
local MainGroup = Tabs.Main:AddLeftGroupbox("Farm")

getgenv().CurrentStatusLabel = MainGroup:AddLabel("Status: Idle")
MainGroup:AddToggle("AutoKillToggle", { Text = "Auto Farm", Default = false }):OnChanged(function()
	if Toggles.AutoKillToggle.Value then AutoFarm:Start() else AutoFarm:Stop() end
end)

-- Anti-AFK
lp.Idled:Connect(function()
	game:GetService("VirtualUser"):CaptureController()
	game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)

Library:Notify({ Title = "TITANIC HUB", Description = "Script Loaded Successfully!", Time = 5 })
