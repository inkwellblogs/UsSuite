-- aotr
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
	lastPlayerData = getRemote:InvokeServer("Functions", "Settings", "Get")
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

if mapData and mapData.Map.Type == "Raids" then
    repeat task.wait() until workspace:GetAttribute("Finalised")
end

local function checkMission()
	if workspace:GetAttribute("Type") then return true end
    mapData = getRemote:InvokeServer("Data", "Copy")
    return mapData ~= nil and mapData.Map ~= nil and mapData.Slots ~= nil
end

-- Config
if not isfolder("./THUB") then makefolder("./THUB") end
if not isfolder("./THUB/aotr") then makefolder("./THUB/aotr") end
local ConfigFile = "./THUB/aotr/dropdown_config.json"
local returnCounterPath = "./THUB/aotr/return_lobby_counter.txt"
local HttpService = game:GetService("HttpService")

local function LoadConfig()
	if not isfile(ConfigFile) then return { Missions = {}, Raids = {}, DeleteMap = false } end
	local success, config = pcall(HttpService.JSONDecode, HttpService, readfile(ConfigFile))
	return success and config or { Missions = {}, Raids = {}, DeleteMap = false }
end
local function SaveConfig(config) pcall(writefile, ConfigFile, HttpService:JSONEncode(config)) end

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

-- Status
getgenv().CurrentStatusLabel = nil
function UpdateStatus(text)
	if getgenv().CurrentStatusLabel then 
		pcall(function() getgenv().CurrentStatusLabel:Set("Status: " .. text) end)
	end
end

-- AutoFarm
local AutoFarm = {}
AutoFarm._running = false
getgenv().AutoFarmConfig = {AttackCooldown = 1, ReloadCooldown = 1, AttackRange = 150, MoveSpeed = 400, HeightOffset = 250, MovementMode = "Hover"}
getgenv().MasteryFarmConfig = {Enabled = false, Mode = "Both"}

-- Injury remover
task.spawn(function()
	while true do
		local Injuries = lp.Character and lp.Character:FindFirstChild("Injuries")
		if Injuries then for _, v in Injuries:GetChildren() do v:Destroy() end end
		task.wait(1)
	end
end)

-- Find Refill - UPDATED PATH
local function findRefillPart()
	local unclimbable = workspace:FindFirstChild("Unclimbable")
	if unclimbable then
		local props = unclimbable:FindFirstChild("Props")
		if props then
			local hq = props:FindFirstChild("HQ")
			if hq then
				for _, child in ipairs(hq:GetChildren()) do
					if child.Name == "GasTanks" and child:IsA("Model") then
						local refill = child:FindFirstChild("Refill")
						if refill and refill:IsA("BasePart") then
							return refill
						end
					end
				end
			end
		end
	end
	return nil
end

-- AutoFarm Start
function AutoFarm:Start()
	if self._running or isLobby then return end
	self._running = true
	self.missionStartTime = nil
	
	task.spawn(function()
		UpdateStatus("Waiting for mission...")
		
		local function checkReady()
			local char = lp.Character
			if not char then return false end
			local playerReady = char:GetAttribute("Shifter") or (char:FindFirstChild("Main") and char.Main:FindFirstChild("W"))
			local mapReady = findRefillPart() ~= nil
			local titans = workspace:FindFirstChild("Titans")
			local titansReady = false
			if titans then
				for _, v in ipairs(titans:GetChildren()) do
					if v:FindFirstChild("Fake") and v.Fake:FindFirstChild("Head") and v.Fake.Head:FindFirstChild("Header") then
						titansReady = true
						break
					end
				end
			end
			return playerReady and mapReady and titansReady
		end

		local notifyTime = os.clock()
		while self._running and not checkReady() do
			if os.clock() - notifyTime > 10 then
				Rayfield:Notify({Title = "TITANIC HUB", Content = "Waiting for mission assets...", Duration = 5, Image = 4483362458})
				notifyTime = os.clock()
			end
			task.wait(1)
		end

		if not self._running then return end
		UpdateStatus("Farming")

		local titansFolder = workspace:FindFirstChild("Titans")
		local lastAttack = 0
		local currentChar, root, charParts = nil, nil, {}
		local AttackRangeSq = getgenv().AutoFarmConfig.AttackRange ^ 2
		local validNapes = {}
		local nextCacheUpdate = 0
		local masteryComboIndex = 1
		local lastMasteryPunch = 0

		local function updateCharState()
			local char = lp.Character
			if not char then return false end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end
			if char ~= currentChar then
				currentChar = char
				root = hrp
				charParts = {}
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false; table.insert(charParts, p) end
				end
			end
			return true
		end

		while self._running do
			if lp:GetAttribute("Cutscene") then task.wait(); continue end
			if not checkMission() then UpdateStatus("Waiting for mission..."); task.wait(1); continue end

			local slotIndex = lp:GetAttribute("Slot")
			local slotData = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]
			if not slotData then UpdateStatus("Waiting for data..."); task.wait(1); continue end

			getgenv().AutoFarmConfig.AttackCooldown = (slotData.Weapon == "Blades") and 0.15 or 1

			-- Failsafe
			if getgenv().AutoFailsafe then
				self.missionStartTime = self.missionStartTime or os.clock()
				if os.clock() - self.missionStartTime >= 900 then
					self:Stop()
					task.spawn(function() getRemote:InvokeServer("Functions", "Teleport", "Lobby") end)
					task.wait(0.5)
					TeleportService:Teleport(14916516914, lp)
					break
				end
			end

			-- Solo Only
			if getgenv().SoloOnly and (workspace:GetAttribute("Player_Count") or #Players:GetPlayers()) > 1 then
				self:Stop()
				task.spawn(function() getRemote:InvokeServer("Functions", "Teleport", "Lobby") end)
				task.wait(0.5)
				TeleportService:Teleport(14916516914, lp)
				break
			end

			if not updateCharState() then task.wait(); continue end

			-- Cache napes
			local now = os.clock()
			if now >= nextCacheUpdate then
				nextCacheUpdate = now + 0.1
				table.clear(validNapes)
				if titansFolder then
					for _, v in ipairs(titansFolder:GetChildren()) do
						if v:GetAttribute("Killed") then continue end
						local hit = v:FindFirstChild("Hitboxes") and v.Hitboxes:FindFirstChild("Hit")
						if hit then
							local fake = v:FindFirstChild("Fake")
							if fake and fake:FindFirstChild("Collision") and not fake.Collision.CanCollide then continue end
							local nape = hit:FindFirstChild("Nape")
							if nape then table.insert(validNapes, nape) end
						end
					end
				end
			end

			-- Movement
			for _, p in ipairs(charParts) do if p and p.Parent then p.CanCollide = false end end

			local isShifted = currentChar:GetAttribute("Shifter")
			if getgenv().MasteryFarmConfig.Enabled and not isShifted and lp:GetAttribute("Bar") == 100 then
				repeat getRemote:InvokeServer("S_Skills", "Usage", "999", false); task.wait(1)
				until not self._running or (lp.Character and lp.Character:GetAttribute("Shifter"))
				continue
			end

			-- Find closest nape
			local closestDist, closestNape = math.huge, nil
			local rootPos = root.Position
			for _, nape in ipairs(validNapes) do
				if not nape.Parent then continue end
				local d = (rootPos - nape.Position).Magnitude
				if d < closestDist then closestDist = d; closestNape = nape end
			end

			if closestNape then
				UpdateStatus("Farming Titans...")
				local titanModel = closestNape
				while titanModel and titanModel.Parent ~= titansFolder do titanModel = titanModel.Parent end

				if isShifted and titanModel then
					local targetHRP = titanModel:FindFirstChild("HumanoidRootPart")
					if targetHRP then
						root.AssemblyLinearVelocity = V3_ZERO
						root.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 80)
						
						if getgenv().MasteryFarmConfig.Mode ~= "Skill Usage" and (now - lastMasteryPunch) >= 1 then
							lastMasteryPunch = now
							postRemote:FireServer("Attacks", "Slash", true)
							postRemote:FireServer("Hitboxes", "Register", closestNape, nil, nil, masteryComboIndex)
							masteryComboIndex = (masteryComboIndex % 4) + 1
						end
					end
					task.wait(); continue
				end

				-- Normal movement
				local targetPos = closestNape.Position + Vector3.new(0, getgenv().AutoFarmConfig.HeightOffset, 30)
				if getgenv().AutoFarmConfig.MovementMode == "Hover" then
					local dir = targetPos - rootPos
					root.AssemblyLinearVelocity = dir.Magnitude > 1 and dir.Unit * getgenv().AutoFarmConfig.MoveSpeed or V3_ZERO
				else
					root.AssemblyLinearVelocity = V3_ZERO
					root.CFrame = CFrame.new(targetPos)
				end

				-- Attack
				local dx, dz = rootPos.X - closestNape.Position.X, rootPos.Z - closestNape.Position.Z
				if (dx*dx + dz*dz) <= AttackRangeSq and (now - lastAttack) >= getgenv().AutoFarmConfig.AttackCooldown then
					lastAttack = now
					if slotData.Weapon == "Blades" then
						postRemote:FireServer("Attacks", "Slash", true)
						postRemote:FireServer("Hitboxes", "Register", closestNape, math.random(625, 850))
					else
						local text = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
						local currentAmmo = tonumber(string.match(text, "(%d+)%s*/"))
						if currentAmmo and currentAmmo > 0 then
							task.spawn(function()
								getRemote:InvokeServer("Spears", "S_Fire", tostring(currentAmmo))
								for j = 1, 3 do postRemote:FireServer("Spears", "S_Explode", closestNape.Position) end
							end)
						end
					end
				end
			else
				root.AssemblyLinearVelocity = V3_ZERO
			end
			task.wait()
		end
	end)
end

function AutoFarm:Stop() self._running = false end

-- Webhook system
local data = {Stats = {}, Total = {}, Items = {}, Special = {}}
local path = "./THUB/aotr/games_played.txt"
if not isfile(path) then writefile(path, "0") end
local gamesPlayed = tonumber(readfile(path))
local webhook

if rewards then
	rewards:GetPropertyChangedSignal("Visible"):Connect(function()
		if not rewards.Visible then return end
		gamesPlayed += 1
		writefile("./THUB/aotr/games_played.txt", tostring(gamesPlayed))

		local gamesUntilReturn = tonumber(readfile(returnCounterPath)) or 0
		if getgenv().AutoReturnLobby then
			gamesUntilReturn += 1
			if gamesUntilReturn >= 10 then
				gamesUntilReturn = 0
				writefile(returnCounterPath, "0")
				task.spawn(function() getRemote:InvokeServer("Functions", "Teleport", "Lobby") end)
				task.wait(0.5)
				TeleportService:Teleport(14916516914, lp)
				return
			end
			writefile(returnCounterPath, tostring(gamesUntilReturn))
		end

		if not getgenv().RewardWebhook or not webhook or webhook == "" then return end
		
		task.wait(1)
		data.Stats = {}; data.Items = {}; data.Special = {}
		
		if statsFrame then
			for _, v in ipairs(statsFrame:GetChildren()) do
				if v:IsA("Frame") and v:FindFirstChild("Amount") then
					data.Stats[string.gsub(v.Name, "_", " ")] = v.Amount.Text
				end
			end
		end
		if itemsFrame then
			for _, v in ipairs(itemsFrame:GetChildren()) do
				if v:IsA("Frame") and v:FindFirstChild("Main") then
					local inner = v.Main:FindFirstChild("Inner")
					if inner then
						data.Items[v.Name] = inner.Quantity.Text
						if inner:FindFirstChild("Rarity") and inner.Rarity.BackgroundColor3 == Color3.fromRGB(255, 0, 0) then
							data.Special[v.Name] = inner.Quantity.Text
						end
					end
				end
			end
		end

		local hasSpecial = next(data.Special) ~= nil
		local function formatTbl(t) local s = ""; for k,v in pairs(t) do s ..= k..": "..v.."\n" end; return s end
		local function formatItm(t) local s = ""; for k,v in pairs(t) do s ..= "[+] "..string.gsub(k,"_"," ").." (x"..v..")\n" end; return s end

		local payload = {
			content = hasSpecial and "MYTHICAL DROP! @everyone" or nil,
			embeds = {{
				title = "TH Rewards", color = hasSpecial and 0xff0000 or 0x2b2d31,
				fields = {
					{name = "Info", value = "```\nUser: "..lp.Name.."\nGames: "..gamesPlayed.."\n```", inline = true},
					{name = "Combat", value = "```\n"..formatTbl(data.Stats).."```", inline = true},
					{name = "Rewards", value = "```\n"..formatItm(data.Items).."```", inline = true},
					{name = "Special", value = "```\n"..(hasSpecial and formatItm(data.Special) or "None").."```", inline = true}
				},
				footer = {text = "TITANIC HUB"}, timestamp = DateTime.now():ToIsoDate()
			}}
		}
		request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)})
	end)
end

-- Reload system
local lastReloadTime, autoReloadEnabled, autoRefillEnabled, isReloading = 0, false, false, false

local function handleWeaponReload()
	if not autoReloadEnabled or isReloading or os.clock() - lastReloadTime < 0.5 then return end
	local slotIndex = lp:GetAttribute("Slot")
	local slot = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]
	if not slot then return end
	
	local refillPart = findRefillPart()
	
	if slot.Weapon == "Blades" then
		local text = PlayerGui.Interface.HUD.Main.Top.Blades.Sets.Text
		local current = tonumber(text:match("(%d+)%s*/"))
		if current and current == 0 and refillPart then
			isReloading = true; lastReloadTime = os.clock()
			pcall(function() postRemote:FireServer("Attacks", "Reload", refillPart) end)
			task.delay(0.8, function() isReloading = false end)
		end
	elseif slot.Weapon == "Spears" then
		local text = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
		local current = tonumber(text:match("(%d+)%s*/"))
		if current and current == 0 and refillPart then
			isReloading = true; lastReloadTime = os.clock()
			pcall(function() postRemote:FireServer("Attacks", "Reload", refillPart) end)
			task.delay(0.8, function() isReloading = false end)
		end
	end
end

task.spawn(function() while true do pcall(handleWeaponReload); task.wait(0.1) end end)

-- Auto Escape
getgenv().AutoEscape = false
postRemote.OnClientEvent:Connect(function(...)
	if getgenv().AutoEscape and ... == "Titans" and select(2, ...) == "Grab_Event" then
		lp.PlayerGui.Interface.Buttons.Visible = false
		postRemote:FireServer("Attacks", "Slash_Escape")
	end
end)

-- Quick functions
local function UseButton(button)
	if not button or not button.Parent or not button.Visible then return false end
	if GuiService.MenuIsOpen then vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game); vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game); task.wait(0.1) end
	GuiService.SelectedObject = button; task.wait(0.05)
	vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game); vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
	return true
end

local function ExecuteImmediateAutomation()
	if getgenv().AutoSkip then
		local skip = INTERFACE:FindFirstChild("Skip")
		if skip and skip.Visible then UseButton(skip:FindFirstChild("Interact")) end
	end
	if getgenv().AutoChest then
		local chests = INTERFACE:FindFirstChild("Chests")
		if chests and chests.Visible then
			local free = chests:FindFirstChild("Free")
			local premium = chests:FindFirstChild("Premium")
			local finish = chests:FindFirstChild("Finish")
			if free and free.Visible then UseButton(free)
			elseif premium and premium.Visible and getgenv().OpenSecondChest then UseButton(premium)
			elseif finish and finish.Visible then UseButton(finish) end
		end
	end
	if getgenv().AutoRetry then
		local rewardsGui = INTERFACE:FindFirstChild("Rewards")
		if rewardsGui and rewardsGui.Visible then
			local retryBtn = rewardsGui.Main.Info.Main.Buttons:FindFirstChild("Retry")
			if retryBtn then UseButton(retryBtn) end
		end
	end
end

-- Delete Map
local _deleteMapRunning = false
local function DeleteMap()
	if _deleteMapRunning or not getgenv().DeleteMap or not workspace:FindFirstChild("Climbable") or (mapData and mapData.Map.Type == "Raids") then return end
	task.spawn(function()
		_deleteMapRunning = true
		while getgenv().DeleteMap do
			if not workspace:FindFirstChild("Climbable") or (mapData and mapData.Map.Type == "Raids") then break end
			for _, v in workspace.Climbable:GetChildren() do v:Destroy() end
			local unclimbable = workspace:FindFirstChild("Unclimbable")
			if unclimbable then for _, v in unclimbable:GetChildren() do if v.Name ~= "Props" and v.Name ~= "Objective" and v.Name ~= "Cutscene" then v:Destroy() end end end
			task.wait(3)
		end
		_deleteMapRunning = false
	end)
end

-- ================ RAYFIELD UI ================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "TITANIC HUB", Icon = 4483362458, LoadingTitle = "TITANIC HUB", LoadingSubtitle = "by TH Team",
	Theme = "Default", DisableRayfieldPrompts = true,
	ConfigurationSaving = {Enabled = true, FolderName = "THUB/aotr", FileName = "rayfield_config"},
	Discord = {Enabled = true, Invite = "N83Tn2SkJz", RememberJoins = true},
	KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)
local UpgradesTab = Window:CreateTab("Upgrades", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)
local TSQuestTab = Window:CreateTab("TS Quest", 4483362458)

-- MAIN TAB - Farming
MainTab:CreateSection("Farming")
getgenv().CurrentStatusLabel = MainTab:CreateLabel("Status: Idle")

local AutoKillToggle = MainTab:CreateToggle({
	Name = "Auto Farm", CurrentValue = false, Flag = "AutoKillToggle",
	Callback = function(v) if v then AutoFarm:Start() else AutoFarm:Stop() end end,
})

MainTab:CreateToggle({
	Name = "Titan Mastery Farm", CurrentValue = false, Flag = "MasteryFarmToggle",
	Callback = function(v) getgenv().MasteryFarmConfig.Enabled = v; if v and not AutoFarm._running then AutoFarm:Start() end end,
})

MainTab:CreateDropdown({Name = "Mastery Mode", Options = {"Punching", "Skill Usage", "Both"}, CurrentOption = "Both", Flag = "MasteryModeDropdown", Callback = function(o) getgenv().MasteryFarmConfig.Mode = o end})
MainTab:CreateDropdown({Name = "Movement Mode", Options = {"Hover", "Teleport"}, CurrentOption = "Hover", Flag = "MovementModeDropdown", Callback = function(o) getgenv().AutoFarmConfig.MovementMode = o end})
MainTab:CreateSlider({Name = "Hover Speed", Range = {100, 500}, Increment = 1, CurrentValue = 400, Flag = "HoverSpeedSlider", Callback = function(v) getgenv().AutoFarmConfig.MoveSpeed = v end})
MainTab:CreateSlider({Name = "Float Height", Range = {100, 300}, Increment = 1, CurrentValue = 250, Flag = "FloatHeightSlider", Callback = function(v) getgenv().AutoFarmConfig.HeightOffset = v end})

MainTab:CreateDropdown({
	Name = "Farm Options", Options = {"Auto Execute", "Failsafe", "Open Second Chest"}, CurrentOption = {}, MultipleOptions = true, Flag = "FarmOptionsDropdown",
	Callback = function(o)
		local opts = {}; for _, v in ipairs(o) do opts[v] = true end
		getgenv().AutoFailsafe = opts["Failsafe"] or false
		getgenv().AutoExecute = opts["Auto Execute"] or false
		getgenv().OpenSecondChest = opts["Open Second Chest"] or false
		if getgenv().AutoExecute and not getgenv().AutoExec then getgenv().AutoExec = true; queue_on_teleport([[repeat task.wait() until game:IsLoaded() task.wait(5) loadstring(game:HttpGet("https://pastebin.com/raw/h8xaGeG4", true))()]]) end
	end,
})

MainTab:CreateToggle({Name = "Auto Reload/Refill", CurrentValue = false, Flag = "AutoReloadToggle", Callback = function(v) autoReloadEnabled = v; autoRefillEnabled = v end})
MainTab:CreateToggle({Name = "Auto Escape", CurrentValue = false, Flag = "AutoEscapeToggle", Callback = function(v) getgenv().AutoEscape = v end})
MainTab:CreateToggle({Name = "Auto Skip Cutscenes", CurrentValue = false, Flag = "AutoSkipToggle", Callback = function(v) getgenv().AutoSkip = v; if v then ExecuteImmediateAutomation() end end})
MainTab:CreateToggle({Name = "Auto Retry", CurrentValue = false, Flag = "AutoRetryToggle", Callback = function(v) getgenv().AutoRetry = v; if v then ExecuteImmediateAutomation() end end})
MainTab:CreateToggle({Name = "Auto Open Chests", CurrentValue = false, Flag = "AutoChestToggle", Callback = function(v) getgenv().AutoChest = v; if v then ExecuteImmediateAutomation() end end})
MainTab:CreateToggle({Name = "Delete Map (FPS Boost)", CurrentValue = DropdownConfig.DeleteMap or false, Flag = "DeleteMapToggle", Callback = function(v) getgenv().DeleteMap = v; DropdownConfig.DeleteMap = v; SaveConfig(DropdownConfig); if v then DeleteMap() end end})
MainTab:CreateToggle({Name = "Solo Only", CurrentValue = false, Flag = "SoloOnlyToggle", Callback = function(v) getgenv().SoloOnly = v end})
MainTab:CreateToggle({Name = "Auto Return to Lobby", CurrentValue = false, Flag = "AutoReturnLobbyToggle", Callback = function(v) getgenv().AutoReturnLobby = v; if not v then pcall(function() writefile(returnCounterPath, "0") end) end end})
MainTab:CreateLabel("Failsafe tps you back to lobby after 15 min timeout.")

-- MAIN TAB - Auto Start
MainTab:CreateSection("Auto Start")
MainTab:CreateButton({Name = "Return to Lobby", Callback = function() getRemote:InvokeServer("Functions", "Teleport", "Lobby"); TeleportService:Teleport(14916516914, lp) end})
MainTab:CreateButton({Name = "Join Discord", Callback = function() setclipboard("https://discord.gg/N83Tn2SkJz"); Rayfield:Notify({Title = "Discord", Content = "Invite copied!", Duration = 5, Image = 4483362458}) end})

MainTab:CreateToggle({Name = "Auto Start", CurrentValue = false, Flag = "AutoStartToggle", Callback = function(v)
	getgenv().AutoStart = v
	if v and game.PlaceId == 14916516914 then
		task.spawn(function()
			local retries = 0
			local function getMyMission()
				for _, m in next, ReplicatedStorage.Missions:GetChildren() do if m:FindFirstChild("Leader") and m.Leader.Value == lp.Name then return m end end
				return nil
			end
			while getgenv().AutoStart do
				for _, m in next, ReplicatedStorage.Missions:GetChildren() do if m:FindFirstChild("Leader") and m.Leader.Value == lp.Name then getRemote:InvokeServer("S_Missions", "Leave") end end
				local missionType = Rayfield.Flags.StartTypeDropdown.CurrentOption
				local diff, map, obj
				if missionType == "Missions" then diff = Rayfield.Flags.MissionDifficultyDropdown.CurrentOption; map = Rayfield.Flags.MissionMapDropdown.CurrentOption; obj = Rayfield.Flags.MissionObjectiveDropdown.CurrentOption
				else diff = Rayfield.Flags.RaidDifficultyDropdown.CurrentOption; map = Rayfield.Flags.RaidMapDropdown.CurrentOption; obj = Rayfield.Flags.RaidObjectiveDropdown.CurrentOption end
				
				local created = false
				if diff == "Hardest" then
					local order = missionType == "Raids" and {"Aberrant", "Severe", "Hard"} or {"Aberrant", "Severe", "Hard", "Normal", "Easy"}
					for _, d in ipairs(order) do
						if not getgenv().AutoStart then break end
						getRemote:InvokeServer("S_Missions", "Create", {Difficulty = d, Type = missionType, Name = map, Objective = obj})
						if getMyMission() then created = true; Rayfield:Notify({Title = "Auto Start", Content = "Created: "..d, Duration = 3, Image = 4483362458}); break end
					end
				else getRemote:InvokeServer("S_Missions", "Create", {Difficulty = diff, Type = missionType, Name = map, Objective = obj}); created = getMyMission() ~= nil end
				
				if not getgenv().AutoStart then break end
				if not created then retries += 1; task.wait(math.min(retries * 2, 20)); continue end
				retries = 0
				for _, mod in ipairs(Rayfield.Flags.ModifiersDropdown.CurrentOption) do getRemote:InvokeServer("S_Missions", "Modify", mod) end
				task.wait(0.5); getRemote:InvokeServer("S_Missions", "Start"); task.wait(5)
			end
		end)
	end
end})

MainTab:CreateDropdown({Name = "Type", Options = {"Missions", "Raids"}, CurrentOption = "Missions", Flag = "StartTypeDropdown", Callback = function(o) DropdownConfig._lastType = o; SaveConfig(DropdownConfig) end})
MainTab:CreateDropdown({Name = "Mission Map", Options = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"}, CurrentOption = "Shiganshina", Flag = "MissionMapDropdown"})
MainTab:CreateDropdown({Name = "Mission Objective", Options = {"Skirmish", "Breach", "Random"}, CurrentOption = "Skirmish", Flag = "MissionObjectiveDropdown"})
MainTab:CreateDropdown({Name = "Mission Difficulty", Options = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"}, CurrentOption = "Normal", Flag = "MissionDifficultyDropdown"})
MainTab:CreateDivider()
MainTab:CreateDropdown({Name = "Raid Map", Options = {"Trost","Shiganshina","Stohess"}, CurrentOption = "Trost", Flag = "RaidMapDropdown"})
MainTab:CreateDropdown({Name = "Raid Objective", Options = {"Skirmish", "Protect", "Random"}, CurrentOption = "Skirmish", Flag = "RaidObjectiveDropdown"})
MainTab:CreateDropdown({Name = "Raid Difficulty", Options = {"Hard","Severe","Aberrant","Hardest"}, CurrentOption = "Hard", Flag = "RaidDifficultyDropdown"})
MainTab:CreateLabel("Trost: Attack | Shiganshina: Armored | Stohess: Female")
MainTab:CreateDivider()
MainTab:CreateDropdown({Name = "Modifiers", Options = {"No Perks","No Skills","No Talents","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"}, CurrentOption = {}, MultipleOptions = true, Flag = "ModifiersDropdown"})

-- UPGRADES TAB
UpgradesTab:CreateSection("Gear & Perks")
UpgradesTab:CreateToggle({Name = "Upgrade Gear", CurrentValue = false, Callback = function(v) getgenv().AutoUpgrade = v end})
UpgradesTab:CreateToggle({Name = "Enhance Perks", CurrentValue = false, Callback = function(v) getgenv().AutoPerk = v end})
UpgradesTab:CreateDropdown({Name = "Perk Slot", Options = {"Defense","Support","Family","Extra","Offense","Body"}, CurrentOption = "Body", Flag = "PerkSlotDropdown"})
UpgradesTab:CreateDropdown({Name = "Food Perks", Options = {"Common","Rare","Epic","Legendary"}, CurrentOption = {}, MultipleOptions = true, Flag = "SelectPerksDropdown"})

UpgradesTab:CreateSection("Skill Tree")
UpgradesTab:CreateToggle({Name = "Auto Skill Tree", CurrentValue = false, Callback = function(v) getgenv().AutoSkillTree = v end})
UpgradesTab:CreateDropdown({Name = "Middle Path", Options = {"Damage","Critical"}, CurrentOption = "Critical", Flag = "MiddlePathDropdown"})
UpgradesTab:CreateDropdown({Name = "Left Path", Options = {"Regen","Cooldown Reduction"}, CurrentOption = "Cooldown Reduction", Flag = "LeftPathDropdown"})
UpgradesTab:CreateDropdown({Name = "Right Path", Options = {"Health","Damage Reduction"}, CurrentOption = "Damage Reduction", Flag = "RightPathDropdown"})
UpgradesTab:CreateDropdown({Name = "Priority 1", Options = {"Left","Middle","Right","None"}, CurrentOption = "Middle", Flag = "Priority1Dropdown"})
UpgradesTab:CreateDropdown({Name = "Priority 2", Options = {"Left","Middle","Right","None"}, CurrentOption = "Left", Flag = "Priority2Dropdown"})
UpgradesTab:CreateDropdown({Name = "Priority 3", Options = {"Left","Middle","Right","None"}, CurrentOption = "None", Flag = "Priority3Dropdown"})

-- MISC TAB
MiscTab:CreateSection("Slot Management")
MiscTab:CreateToggle({Name = "Auto Select Slot", CurrentValue = false, Callback = function(v) getgenv().AutoSlot = v end})
MiscTab:CreateDropdown({Name = "Select Slot", Options = {"Slot A","Slot B","Slot C"}, CurrentOption = "Slot A", Flag = "SelectSlotDropdown"})
MiscTab:CreateToggle({Name = "Auto Prestige", CurrentValue = false, Callback = function(v) getgenv().AutoPrestige = v end})
MiscTab:CreateDropdown({Name = "Select Boost", Options = {"Luck Boost","EXP Boost","Gold Boost"}, CurrentOption = "Luck Boost", Flag = "SelectBoostDropdown"})
MiscTab:CreateSlider({Name = "Prestige Gold (M)", Range = {0, 100}, Increment = 1, CurrentValue = 0, Flag = "PrestigeGoldSlider"})

MiscTab:CreateSection("Family Roll")
MiscTab:CreateToggle({Name = "Auto Roll", CurrentValue = false, Callback = function(v) getgenv().AutoRoll = v end})
MiscTab:CreateInput({Name = "Select Families", CurrentValue = "", PlaceholderText = "Fritz,Yeager", RemoveTextAfterFocusLost = false, Flag = "SelectFamily"})
MiscTab:CreateDropdown({Name = "Stop At", Options = {"Rare","Epic","Legendary","Mythical"}, CurrentOption = {}, MultipleOptions = true, Flag = "SelectFamilyRarity"})
MiscTab:CreateLabel("Mythical won't be rolled. Comma separated, no spaces.")

-- SETTINGS TAB
SettingsTab:CreateSection("Webhooks")
SettingsTab:CreateToggle({Name = "Reward Webhook", CurrentValue = false, Callback = function(v) getgenv().RewardWebhook = v end})
SettingsTab:CreateToggle({Name = "Mythical Family Webhook", CurrentValue = false, Callback = function(v) getgenv().MythicalFamilyWebhook = v end})
SettingsTab:CreateInput({Name = "Webhook URL", CurrentValue = "", PlaceholderText = "https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost = false, Flag = "WebhookUrl", Callback = function(t) webhook = t end})

SettingsTab:CreateSection("UI Settings")
SettingsTab:CreateToggle({Name = "Disable 3D Rendering", CurrentValue = false, Callback = function(v) RunService:Set3dRenderingEnabled(not v) end})
SettingsTab:CreateKeybind({Name = "Toggle UI", CurrentKeybind = "RightControl", HoldToInteract = false, Flag = "MenuKeybind"})

-- TS QUEST TAB
TSQuestTab:CreateSection("Titan Shifting Quest")
TSQuestTab:CreateLabel("🔜 COMING SOON")
TSQuestTab:CreateLabel("TS Quest features are under development.")
TSQuestTab:CreateLabel("Stay tuned for updates!")
TSQuestTab:CreateLabel("")
TSQuestTab:CreateLabel("Planned Features:")
TSQuestTab:CreateLabel("• Auto Complete TS Quests")
TSQuestTab:CreateLabel("• Shift Progress Tracker")
TSQuestTab:CreateLabel("• Quest Requirements Checker")
TSQuestTab:CreateLabel("• Auto Kill Titans for Progress")

-- Anti-AFK
local virtualUser = game:GetService("VirtualUser")
lp.Idled:Connect(function() virtualUser:CaptureController(); virtualUser:ClickButton2(Vector2.new()) end)

-- Initialization
task.spawn(function() task.wait(0.5); if getgenv().DeleteMap then DeleteMap() end end)
task.spawn(function() while true do pcall(ExecuteImmediateAutomation); task.wait(0.5) end end)

Rayfield:LoadConfiguration()
