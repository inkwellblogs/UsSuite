-- aotr | Rayfield UI Conversion
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
	local args = { "Functions", "Settings", "Get" }
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

local familyRaritiesOptions = { "Rare", "Epic", "Legendary", "Mythical" }

if not isfolder("./THUH") then makefolder("./THUB") end
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
local StatusSection = nil

function UpdateStatus(text)
	if StatusSection then
		StatusSection.Description = "Status: " .. text
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
		local Injuries = lp.Character:FindFirstChild("Injuries")
		if Injuries then
			for i, v in Injuries:GetChildren() do
				v:Destroy()
			end
		end
		task.wait(1)
	end
end)

-- ==========================================
-- GAME LOGIC (unchanged from original)
-- ==========================================

function AutoFarm:Start()
	if self._running then return end
	if isLobby then return end
	self._running = true
	task.spawn(function()
		UpdateStatus("Waiting for mission...")
		
		local function checkReady()
			local char = lp.Character
			local playerReady = char and (char:GetAttribute("Shifter") or (char:FindFirstChild("Main") and char.Main:FindFirstChild("W")))
			local mapReady = workspace:FindFirstChild("Unclimbable") 
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
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

		local startTime = os.clock()
		while self._running and not checkReady() do
			if os.clock() - startTime > 10 then
				Window:Notify({
					Title = "TITANIC HUB",
					Content = "Still waiting for mission assets to load...",
					Duration = 5,
					Image = 4483362458,
				})
				startTime = os.clock()
			end
			task.wait(1)
		end

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
				currentChar = char
				root = hrp
				charParts = {}
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanCollide = false
						table.insert(charParts, p)
					end
				end
			end
			return true
		end

		local validNapes = {}
		local nextTitanCacheUpdate = 0
		local nextObjectiveCacheUpdate = 0
		local cachedObjectivePart = nil
		local masteryComboIndex = 1
		local lastMasteryPunch = 0

		while self._running do
			if lp:GetAttribute("Cutscene") then task.wait(); continue end

			if not checkMission() then
				UpdateStatus("Waiting for mission...")
				task.wait(1)
				continue
			end

			local slotIndex = lp:GetAttribute("Slot")
			local slotData = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]

			if not slotData then
				UpdateStatus("Waiting for data...")
				task.wait(1)
				continue
			end

			if slotData.Weapon == "Blades" then 
				getgenv().AutoFarmConfig.AttackCooldown = 0.15 
			else 
				getgenv().AutoFarmConfig.AttackCooldown = 1 
			end

			if getgenv().AutoFailsafe then
				if not self.missionStartTime then
					self.missionStartTime = os.clock()
				end
				local missionElapsedTime = os.clock() - self.missionStartTime
				if missionElapsedTime >= 900 then
					self:Stop()
					task.spawn(function() getRemote:InvokeServer("Functions", "Teleport", "Lobby") end)
					task.wait(0.5)
					TeleportService:Teleport(14916516914, lp)
					break
				end
			end

			local playerCount = workspace:GetAttribute("Player_Count") or #Players:GetPlayers()
			if getgenv().SoloOnly and playerCount > 1 then
				self:Stop()
				task.spawn(function() getRemote:InvokeServer("Functions", "Teleport", "Lobby") end)
				task.wait(0.5)
				TeleportService:Teleport(14916516914, lp)
				break
			end
			
			if not updateCharState() then task.wait(); continue end

			titansFolder = workspace:FindFirstChild("Titans") or titansFolder

			local ws_ObjectiveFolder = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective")
			local rs_ObjectiveFolder = ReplicatedStorage:FindFirstChild("Objectives")
			local mapType = workspace:GetAttribute("Type") or (mapData and mapData.Map and mapData.Map.Type)

			local isArmoredRaid = ws_ObjectiveFolder:FindFirstChild("Armored_Boss")
			local isFemaleRaid = rs_ObjectiveFolder:FindFirstChild("Defeat_Annie")
			local femaleExists = ws_ObjectiveFolder:FindFirstChild("Female_Boss")
			local attackExists = ws_ObjectiveFolder:FindFirstChild("Attack_Boss")
			local hasReinerObjective = rs_ObjectiveFolder:FindFirstChild("Defeat_Reiner")

			if isFemaleRaid and not femaleExists and not attackExists then
				task.wait()
				continue
			end

			for i = 1, #charParts do
				local p = charParts[i]
				if p and p.Parent then p.CanCollide = false end
			end

			local now = os.clock()
			local isShifted = currentChar and currentChar:GetAttribute("Shifter") or false
			
			if getgenv().MasteryFarmConfig.Enabled then
				local shiftReady = lp:GetAttribute("Bar") and lp:GetAttribute("Bar") == 100
				if not isShifted and shiftReady then
					repeat 
						getRemote:InvokeServer("S_Skills", "Usage", "999", false) 
						task.wait(1) 
					until not self._running or (lp.Character and lp.Character:GetAttribute("Shifter"))
					continue
				end
			end

			if now >= nextTitanCacheUpdate then
				nextTitanCacheUpdate = now + 0.1
				table.clear(validNapes)
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

			local rootPos = root.Position
			local referencePos = rootPos
			local objectiveFound = false

			if now >= nextObjectiveCacheUpdate then
				nextObjectiveCacheUpdate = now + 1
				cachedObjectivePart = nil
				if ws_ObjectiveFolder then
					for _, desc in ipairs(ws_ObjectiveFolder:GetDescendants()) do
						if desc:IsA("BillboardGui") and desc.Parent and desc.Parent:IsA("BasePart") then
							cachedObjectivePart = desc.Parent
							break
						end
					end
				end
			end

			if cachedObjectivePart and cachedObjectivePart.Parent then
				referencePos = cachedObjectivePart.Position
				objectiveFound = true
			end

			local useRangeLimit = objectiveFound and isArmoredRaid and not hasReinerObjective
			local closestDist, closestNape = math.huge, nil
			local closestIsBoss = false
			local bossDist, bossHitPoint = math.huge, nil
			local attackTitanFound = false
			local highestZ = -math.huge
			local isStall = mapData and mapData.Map and mapData.Map.Objective == "Stall"
			local bossIsRoaring = false

			for i = 1, #validNapes do
				local nape = validNapes[i]
				if not nape.Parent then continue end
				local titanModel = nape.Parent.Parent.Parent
				local fake = titanModel:FindFirstChild("Fake")
				if (fake and fake:FindFirstChild("Collision") and not fake.Collision.CanCollide) or (titanModel:GetAttribute("Dead")) then continue end
				local tName = titanModel.Name
				local isBoss = bossNames[tName]
				if isArmoredRaid and not hasReinerObjective and tName == "Armored_Titan" then continue end
				if isBoss and not titanModel:GetAttribute("State") then continue end
				local isRoaring = isBoss and (titanModel:GetAttribute("Attack") == "Roar" or titanModel:GetAttribute("Attack") == "Berserk_Mode")
				if tName == "Attack_Titan" then attackTitanFound = true end
				local dx = referencePos.X - nape.Position.X
				local dz = referencePos.Z - nape.Position.Z
				local d = dx*dx + dz*dz
				local adjustedDist = d
				if getgenv()._currentTargetNape == nape then
					adjustedDist = adjustedDist - 15000
				end
				if useRangeLimit then
					if d > 90000 then continue end
				end
				if isBoss then
					local hitPart = (titanModel:FindFirstChild("Marker") and titanModel.Marker.Adornee) or titanModel.Hitboxes.Hit.Nape
					if hitPart and adjustedDist < bossDist then
						bossDist = adjustedDist
						bossHitPoint = hitPart
						bossIsRoaring = isRoaring
					end
				end
				if isStall then
					if nape.Position.Z > highestZ then
						highestZ = nape.Position.Z
						closestNape = nape
					end
				elseif adjustedDist < closestDist then
					closestDist = adjustedDist
					closestNape = nape
					closestIsBoss = isBoss
				end
			end

			local targetPart = bossHitPoint or closestNape
			local targetIsRoaring = (targetPart ~= nil and targetPart == bossHitPoint) and bossIsRoaring or false
			
			if useRangeLimit and closestNape then
				targetPart = closestNape
				targetIsRoaring = false
			end

			if targetPart and #validNapes == 1 and mapType == "Missions" and (workspace:GetAttribute("Seconds") or 0) < 29 then
				targetPart = nil
			end

			getgenv()._currentTargetNape = targetPart

			if attackTitanFound then
				attackTitanSpawnTime = attackTitanSpawnTime or now
			else
				attackTitanSpawnTime = nil
			end

			local attackTitanReady = not attackTitanFound or (attackTitanSpawnTime and (now - attackTitanSpawnTime) >= 5)

			if targetPart then
				UpdateStatus(closestIsBoss and "Attacking Boss..." or "Farming Titans...")
				local currentTitanModel = targetPart
				while currentTitanModel and currentTitanModel.Parent ~= titansFolder do
					currentTitanModel = currentTitanModel.Parent
				end

				if isShifted then
					local targetHRP = currentTitanModel:FindFirstChild("HumanoidRootPart")
					local targetCFrame = targetHRP and targetHRP.CFrame or targetPart.CFrame
					root.AssemblyLinearVelocity = V3_ZERO
					root.CFrame = targetCFrame * CFrame.new(0, 0, 80)
					local mode = getgenv().MasteryFarmConfig.Mode
					local doPunch = mode == "Punching" or mode == "Both"
					local doSkills = mode == "Skill Usage" or mode == "Both"

					if not targetIsRoaring then
						if doPunch and (now - lastMasteryPunch) >= 1 then
							lastMasteryPunch = now
							postRemote:FireServer("Attacks", "Slash", true)
							postRemote:FireServer("Hitboxes", "Register", targetPart, nil, nil, masteryComboIndex) 
							masteryComboIndex = masteryComboIndex + 1
							if masteryComboIndex > 4 then masteryComboIndex = 1 end
						end

						if doSkills and slotData and slotData.Skills and slotData.Skills.Shifter and not getgenv().ShifterSkillsRunning then
							getgenv().ShifterSkillsRunning = true
							task.spawn(function()
								for _, skillId in ipairs(slotData.Skills.Shifter) do
									local idNum = tonumber(skillId)
									if idNum and idNum ~= 200 and idNum ~= 300 and idNum ~= 400 and idNum ~= 210 and idNum ~= 211 and idNum ~= 306 and idNum ~= 308 and idNum ~= 402 and idNum ~= 403 and idNum ~= 407 then
										getRemote:InvokeServer("S_Skills", "Usage", tostring(skillId), false)
									end
									task.wait(1)
								end
								getgenv().ShifterSkillsRunning = false
							end)
						end
					end
				else
					local movementMode = getgenv().AutoFarmConfig.MovementMode
					local targetPos = targetPart.Position + Vector3.new(0, getgenv().AutoFarmConfig.HeightOffset, 0)

					if movementMode == "Hover" then
						local dir = (targetPos - root.Position)
						local dist = dir.Magnitude
						if dist > 10 then
							local speed = getgenv().AutoFarmConfig.MoveSpeed
							root.AssemblyLinearVelocity = dir.Unit * math.min(speed, dist * 10)
						else
							root.AssemblyLinearVelocity = V3_ZERO
						end
					elseif movementMode == "Teleport" then
						root.CFrame = CFrame.new(targetPos)
						root.AssemblyLinearVelocity = V3_ZERO
					end

					if attackTitanReady and (now - lastAttack) >= getgenv().AutoFarmConfig.AttackCooldown then
						lastAttack = now
						if slotData.Weapon == "Blades" then
							postRemote:FireServer("Attacks", "Slash", false)
							postRemote:FireServer("Hitboxes", "Register", targetPart, nil, nil, 1)
						elseif slotData.Weapon == "Spears" then
							postRemote:FireServer("Attacks", "Throw", targetPart.Position)
						end
					end
				end
			else
				UpdateStatus("No targets found")
				root.AssemblyLinearVelocity = V3_ZERO
			end

			task.wait()
		end
	end)
end

function AutoFarm:Stop()
	self._running = false
	self.missionStartTime = nil
	UpdateStatus("Idle")
end

-- ==========================================
-- WEBHOOK / REWARD HELPERS
-- ==========================================

local webhook = ""
local gamesPlayed = 0

local function formatTable(t)
	local lines = {}
	for k, v in pairs(t) do table.insert(lines, tostring(k) .. ": " .. tostring(v)) end
	return table.concat(lines, "\n")
end

local function formatItems(t)
	local lines = {}
	for k, v in pairs(t) do table.insert(lines, tostring(k) .. " x" .. tostring(v)) end
	return table.concat(lines, "\n")
end

local function SendRewardWebhook()
	if not getgenv().RewardWebhook then return end
	gamesPlayed = gamesPlayed + 1

	task.spawn(function()
		local data = {}
		local start = os.clock()
		local hasData = false

		repeat
			task.wait(0.5)
			if statsFrame and #statsFrame:GetChildren() > 0 then
				hasData = true
				break
			end
		until hasData or (os.clock() - start) > 2

		data.Stats = {}
		data.Total = {}
		data.Items = {}
		data.Special = {}

		for i, v in ipairs(statsFrame:GetChildren()) do
			if v:IsA("Frame") and v:FindFirstChild("Stat") and v:FindFirstChild("Amount") then
				data.Stats[string.gsub(v.Name, "_", " ")] = v.Amount.Text
			end
		end

		for i, v in ipairs(itemsFrame:GetChildren()) do
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

		local currentSlot = lp:GetAttribute("Slot") or "A"
		local slotData = mapData and mapData.Slots and mapData.Slots[currentSlot]
		local executor = identifyexecutor and identifyexecutor() or "Unknown"

		if slotData then
			if slotData.Currency then
				for i, v in pairs(slotData.Currency) do
					if i == "Gems" or i == "Gold" then data.Total[i] = v end
				end
			end
			if slotData.Progression then
				for i, v in pairs(slotData.Progression) do
					if i == "Prestige" or i == "Level" or i == "Streak" then data.Total[i] = v end
				end
			end
		end

		local hasSpecial = data.Special and next(data.Special) ~= nil
		
		if webhook and webhook ~= "" then
			local payload = {
				content = hasSpecial and "MYTHICAL DROP! @everyone" or nil,
				embeds = {{
					title = "TH Rewards",
					color = hasSpecial and 0xff0000 or 0x2b2d31,
					fields = {
						{ name = "Information", value = "```\nUser: " .. lp.Name .. "\nGames Played: " .. tostring(gamesPlayed) .. "\nExecutor: " .. executor .. "\n```", inline = true },
						{ name = "Total Stats", value = "```\nLevel : " .. tostring(data.Total.Level or "1") .. "\nGold  : " .. tostring(data.Total.Gold or "0") .. "\nGems  : " .. tostring(data.Total.Gems or "0") .. "\n```", inline = true },
						{ name = "Combat", value = "```\n" .. formatTable(data.Stats) .. "\n```", inline = true },
						{ name = "Rewards", value = "```\n" .. formatItems(data.Items) .. "\n```", inline = true },
						{ name = "Special", value = "```\n" .. (hasSpecial and formatItems(data.Special) or "None") .. "\n```", inline = true }
					},
					footer = { text = "TITANIC HUB • " .. DateTime.now():FormatLocalTime("LTS", "en-us") },
					timestamp = DateTime.now():ToIsoDate()
				}}
			}

			request({
				Url = webhook,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode(payload)
			})
		end
	end)
end

-- ==========================================
-- PERKS / TALENTS / SKILL PATHS DATA
-- ==========================================

local Perks = {
	Legendary = {
		"Peerless Commander","Indefatigable","Tyrant's Stare","Invincible","Eviscerate",
		"Font of Vitality","Flame Rhapsody","Robust","Sixth Sense","Gear Master",
		"Carnifex","Munitions Master","Sanctified","Wind Rhapsody","Peerless Constitution",
		"Exhumation","Warchief","Peerless Focus","Perfect Form","Courage Catalyst",
		"Aegis","Unparalleled Strength","Perfect Soul"
	},
	Common = {
		"Cripple","Lucky","Enhanced Metabolism","First Aid","Mighty",
		"Fortitude","Hollow","Gear Beginner","Enduring"
	},
	Epic = {
		"Munitions Expert","Gear Expert","Butcher","Resilient","Speedy",
		"Reckless Abandon","Focus","Stalwart Durability","Adrenaline","Safeguard",
		"Warrior","Solo","Mutilate","Trauma Battery","Hardy",
		"Unbreakable","Siphoning","Flawed Release","Luminous","Peerless Strength"
	},
	Rare = {
		"Blessed","Gear Intermediate","Unyielding","Fully Stocked","Forceful",
		"Lightweight","Protection","Mangle","Experimental Shells","Critical Hunter",
		"Tough","Heightened Vitality"
	},
	Secret = {
		"Everlasting Flame","Heavenly Restriction","Adaptation","Maximum Firepower",
		"Soulfeed","Kengo","Black Flash","Font of Inspiration","Explosive Fortune",
		"Immortal","Art of War","Tatsujin","Founder's Blessing"
	}
}

local PerkRarityMap = {}
for rarity, names in pairs(Perks) do
	for _, name in pairs(names) do PerkRarityMap[name] = rarity end
end

local Talents = {
	"Blitzblade","Crescendo","Swiftshot","Surgeshot","Guardian","Deflectra",
	"Mendmaster","Cooldown Blitz","Stalwart","Stormcharged","Aegisurge","Riposte",
	"Lifefeed","Vitalize","Gem Fiend","Luck Boost","EXP Boost","Gold Boost",
	"Furyforge","Quakestrike","Assassin","Amputation","Steel Frame","Resilience",
	"Vengeflare","Flashstep","Omnirange","Tactician","Gambler","Overslash",
	"Afterimages","Necromantic","Thanatophobia","Apotheosis","Bloodthief"
}

local Perk_Level_XP = {
	Common    = {50, 100, 150, 200, 250, 300, 350, 400, 450, 500},
	Rare      = {125, 250, 375, 500, 625, 750, 875, 1000, 1125, 1250},
	Epic      = {250, 500, 750, 1000, 1250, 1500, 1750, 2000, 2250, 2500},
	Legendary = {500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000},
	Secret    = {2000, 4000, 6000, 8000, 10000, 12000, 14000, 16000, 18000, 20000},
}

local Perk_Base_XP = {
	Common    = 100,
	Rare      = 250,
	Epic      = 625,
	Legendary = 2500,
	Secret    = 10000,
}

local Blades_Critical  = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25"}
local Blades_Damage    = {"1","2","3","4","5","6","7","8","9","10","11","12","13","26","27","28","29","30","31","32","33","34","35","36","37"}
local Spears_Critical  = {"113","114","115","116","117","118","119","120","121","122","123","124","125","126","127","128","129","130","131","132","133","134","135","136","137"}
local Spears_Damage    = {"113","114","115","116","117","118","119","120","121","122","123","124","125","138","139","140","141","142","143","144","145","146","147","148","149"}
local Defense_Health   = {"38","39","40","41","42","43","44","45","46","47","48","49","50","51","52","53","54","55","56","57"}
local Defense_DmgRed   = {"38","39","40","41","42","43","44","45","58","59","60","61","62","63","64","65","66","67","68","69"}
local Support_Regen    = {"70","71","72","73","74","75","76","77","78","79","80","81","82","83","84","85","86","87","88","89"}
local Support_CDR      = {"70","71","72","73","74","75","76","77","78","79","80","90","91","92","93","94","95","96","97","98"}

local Missions = {
	["Shiganshina"] = { "Skirmish", "Breach", "Random" },
	["Trost"]       = { "Skirmish", "Protect", "Random" },
	["Outskirts"]   = { "Skirmish", "Escort", "Random" },
	["Giant Forest"]= { "Skirmish", "Guard", "Random" },
	["Utgard"]      = { "Skirmish", "Defend", "Random" },
	["Loading Docks"]={ "Skirmish", "Stall", "Random" },
	["Stohess"]     = { "Skirmish", "Random" }
}

local SkillPaths = {
	Blades  = { Damage = Blades_Damage, Critical = Blades_Critical },
	Spears  = { Damage = Spears_Damage, Critical = Spears_Critical },
	Defense = { Health = Defense_Health, ["Damage Reduction"] = Defense_DmgRed },
	Support = { Regen = Support_Regen,   ["Cooldown Reduction"] = Support_CDR }
}

local function GetPerkRarity(perkName)
	return PerkRarityMap[perkName]
end

local function GetPerkXP(rarity, level)
	local base = Perk_Base_XP[rarity] or 0
	return base * math.max(level, 1)
end

local function UseButton(button)
	if not button or not button.Parent then return false end
	if not button.Visible then return false end
	if GuiService.MenuIsOpen then
		vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game) 
		vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
		task.wait(0.1)
	end
	GuiService.SelectedObject = button
	task.wait(0.05)
	vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
	return true
end

local _deleteMapRunning = false
local function DeleteMap()
	if _deleteMapRunning or not getgenv().DeleteMap or not workspace:FindFirstChild("Climbable") or mapData.Map.Type == "Raids" then return end
	task.spawn(function()
		_deleteMapRunning = true
		while getgenv().DeleteMap do
			if not workspace:FindFirstChild("Climbable") or mapData.Map.Type == "Raids" then break end
			for i, v in workspace.Climbable:GetChildren() do v:Destroy() end
			for i, v in workspace.Unclimbable:GetChildren() do
				if v.Name ~= "Reloads" and v.Name ~= "Objective" and v.Name ~= "Cutscene" then
					v:Destroy()
				end
			end
			task.wait(3)
		end
		_deleteMapRunning = false
	end)
end

local function setupAutoExecute()
	if getgenv().AutoExecute and not getgenv().AutoExec then
		getgenv().AutoExec = true
		queue_on_teleport([[
			repeat task.wait() until game:IsLoaded()
			task.wait(5)
			loadstring(game:HttpGet("https://pastebin.com/raw/h8xaGeG4", true))()
		]])
	end
end

local function ExecuteImmediateAutomation()
	if getgenv().AutoSkip then
		local skip = INTERFACE:FindFirstChild("Skip")
		if skip and skip.Visible then task.wait(1) end
		if skip and skip.Visible then UseButton(skip:FindFirstChild("Interact")) end
	end

	if getgenv().AutoChest then
		local chests = INTERFACE:FindFirstChild("Chests")
		if chests and chests.Visible then
			local free = chests:FindFirstChild("Free")
			local premium = chests:FindFirstChild("Premium")
			local finish = chests:FindFirstChild("Finish")
			if free and free.Visible then
				UseButton(free)
				task.wait(0.5)
			elseif premium and premium.Visible and premium:FindFirstChild("Title") and not string.find(premium.Title.Text, "(0)") and getgenv().OpenSecondChest then
				UseButton(premium)
				task.wait(0.5)
			elseif finish and finish.Visible then
				UseButton(finish)
			end
		end
	end

	if getgenv().AutoRetry then
		local rewardsGui = INTERFACE:FindFirstChild("Rewards")
		if rewardsGui and rewardsGui.Visible then
			local retryBtn = rewardsGui:FindFirstChild("Main")
				and rewardsGui.Main:FindFirstChild("Info")
				and rewardsGui.Main.Info:FindFirstChild("Main")
				and rewardsGui.Main.Info.Main:FindFirstChild("Buttons")
				and rewardsGui.Main.Info.Main.Buttons:FindFirstChild("Retry")
			if retryBtn then UseButton(retryBtn) end
		end
	end
end

local function roll(targets, rarities)
	if not PlayerGui.Interface.Customisation.Visible then return end
	local familyString = PlayerGui.Interface.Customisation.Family.Family.Title.Text
	local familyName = targets and string.lower(string.split(familyString, " ")[1]) or nil
	local familyRarity = string.lower(string.match(familyString, "%((.-)%)") or "")

	local stopRolling = false
	if targets and familyName and table.find(targets, familyName) then stopRolling = true end
	if rarities and table.find(rarities, familyRarity) then stopRolling = true end
	if familyRarity == "mythical" then stopRolling = true end

	if stopRolling then
		getgenv().AutoRoll = false
		pcall(function()
			if Window then
				Window:Notify({ Title = "TITANIC HUB", Content = "Target family rolled: " .. familyString, Duration = 5, Image = 4483362458 })
			end
		end)

		if familyRarity == "mythical" and getgenv().MythicalFamilyWebhook and webhook and webhook ~= "" then
			local payload = {
				content = "MYTHICAL FAMILY ROLLED! @everyone",
				embeds = {{
					title = "Family Roll Success",
					color = 0xff0000,
					fields = {{ name = "Information", value = "```\nUser: " .. lp.Name .. "\nFamily: " .. tostring(familyString) .. "\n```", inline = true }},
					footer = { text = "TITANIC HUB • " .. DateTime.now():FormatLocalTime("LTS", "en-us") },
					timestamp = DateTime.now():ToIsoDate()
				}}
			}
			request({ Url = webhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) })
		end
		return
	end

	if PlayerGui.Interface.Warning.Prompt.Visible then
		UseButton(PlayerGui.Interface.Warning.Prompt.Main.Yes)
		task.wait(0.5)
	end

	if familyFrame and not familyFrame.Visible then
		UseButton(PlayerGui.Interface.Customisation.Categories.Family.Interact)
		task.wait(1)
	end

	if rollButton then UseButton(rollButton) end
end

local lastReloadTime = 0
local autoReloadEnabled = false
local autoRefillEnabled = false
local isReloading = false

local function getBladeCount()
	if not INTERFACE:FindFirstChild("HUD") then return end
	local text = PlayerGui.Interface.HUD.Main.Top.Blades.Sets.Text
	return tonumber(text:match("(%d+)%s*/"))
end

local function handleWeaponReload()
	if not autoReloadEnabled then return end
	if isReloading then return end
	if os.clock() - lastReloadTime < getgenv().AutoFarmConfig.ReloadCooldown then return end
	local slotIndex = lp:GetAttribute("Slot")
	local slot = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]
	if not slot then return end
	local weaponType = slot.Weapon
	if weaponType == "Blades" then
		local char = lp.Character
		local rig = char and char:FindFirstChild("Rig_" .. lp.Name)
		local blade = rig and rig:FindFirstChild("LeftHand") and rig.LeftHand:FindFirstChild("Blade_1")
		local current = getBladeCount() or 0
		if current == 0 and autoRefillEnabled then
			local refillPart = workspace:FindFirstChild("Unclimbable")
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
			if refillPart then
				isReloading = true
				lastReloadTime = os.clock()
				pcall(function() postRemote:FireServer("Attacks", "Reload", refillPart) end)
				task.delay(1, function() isReloading = false end)
				return
			end
		end
		if blade and blade.Transparency == 1 and current > 0 then
			isReloading = true
			lastReloadTime = os.clock()
			pcall(function() getRemote:InvokeServer("Blades", "Reload") end)
			task.delay(0.5, function() isReloading = false end)
			return
		end
	elseif weaponType == "Spears" then
		local HUD = INTERFACE:FindFirstChild("HUD")
		if not HUD then return end
		local spearCount = tonumber(HUD.Main.Top.Spears.Spears.Text:match("(%d+)%s*/")) or 0
		if spearCount == 0 and autoRefillEnabled then
			local refillPart = workspace:FindFirstChild("Unclimbable")
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
			if refillPart then
				isReloading = true
				lastReloadTime = os.clock()
				postRemote:FireServer("Attacks", "Reload", refillPart)
				task.delay(1, function() isReloading = false end)
			end
		end
	end
end

task.spawn(function()
	while true do
		pcall(handleWeaponReload)
		task.wait(0.5)
	end
end)

getgenv().AutoEscape = false
postRemote.OnClientEvent:Connect(function(...)
	local args = {...}
	if getgenv().AutoEscape and args[1] == "Titans" and args[2] == "Grab_Event" then
		game:GetService("Players").LocalPlayer.PlayerGui.Interface.Buttons.Visible = not getgenv().AutoEscape
		postRemote:FireServer("Attacks", "Slash_Escape")
	end
end)

-- ==========================================
-- RAYFIELD UI LIBRARY LOAD
-- ==========================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "TITANIC HUB | AOT:R",
	Icon = 0,
	LoadingTitle = "TITANIC HUB",
	LoadingSubtitle = "AOT:R | Free",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "THUB_aotr",
		FileName = "TitanicHub"
	},
	Discord = {
		Enabled = true,
		Invite = "Cczp9ZWxvY",
		RememberJoins = true
	},
	KeySystem = false
})

-- ==========================================
-- TAB : MAIN
-- ==========================================

local MainTab = Window:CreateTab("Main", 4483362458)

local FarmSection = MainTab:CreateSection("Farm")

StatusSection = MainTab:CreateLabel("Status: Idle")

MainTab:CreateToggle({
	Name = "Auto Farm",
	CurrentValue = false,
	Flag = "AutoKillToggle",
	Callback = function(val)
		if val then AutoFarm:Start() else AutoFarm:Stop() end
	end,
})

MainTab:CreateToggle({
	Name = "Titan Mastery Farm",
	CurrentValue = false,
	Flag = "MasteryFarmToggle",
	Callback = function(val)
		getgenv().MasteryFarmConfig.Enabled = val
		if val then
			if not getgenv().AutoFarmConfig._farmRunning then
				AutoFarm:Start()
			end
		end
	end,
})

MainTab:CreateDropdown({
	Name = "Mastery Mode",
	Options = {"Punching", "Skill Usage", "Both"},
	CurrentOption = {"Both"},
	MultipleOptions = false,
	Flag = "MasteryModeDropdown",
	Callback = function(val)
		getgenv().MasteryFarmConfig.Mode = val
	end,
})

MainTab:CreateDropdown({
	Name = "Movement Mode",
	Options = {"Hover", "Teleport"},
	CurrentOption = {"Hover"},
	MultipleOptions = false,
	Flag = "MovementModeDropdown",
	Callback = function(val)
		getgenv().AutoFarmConfig.MovementMode = val
	end,
})

MainTab:CreateDropdown({
	Name = "Farm Options",
	Options = {"Auto Execute", "Failsafe", "Open Second Chest"},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "FarmOptionsDropdown",
	Callback = function(vals)
		local function has(v) for _, x in ipairs(vals) do if x == v then return true end end return false end
		getgenv().AutoFailsafe = has("Failsafe")
		getgenv().AutoExecute = has("Auto Execute")
		getgenv().OpenSecondChest = has("Open Second Chest")
		if getgenv().AutoExecute then setupAutoExecute() end
	end,
})

MainTab:CreateSlider({
	Name = "Hover Speed",
	Range = {100, 500},
	Increment = 1,
	Suffix = "",
	CurrentValue = 400,
	Flag = "HoverSpeedSlider",
	Callback = function(val)
		getgenv().AutoFarmConfig.MoveSpeed = val
	end,
})

MainTab:CreateSlider({
	Name = "Float Height",
	Range = {100, 300},
	Increment = 1,
	Suffix = "",
	CurrentValue = 250,
	Flag = "FloatHeightSlider",
	Callback = function(val)
		getgenv().AutoFarmConfig.HeightOffset = val
	end,
})

MainTab:CreateToggle({
	Name = "Auto Reload/Refill",
	CurrentValue = false,
	Flag = "AutoReloadToggle",
	Callback = function(val)
		autoReloadEnabled = val
		autoRefillEnabled = val
	end,
})

MainTab:CreateToggle({
	Name = "Auto Escape",
	CurrentValue = false,
	Flag = "AutoEscapeToggle",
	Callback = function(val)
		getgenv().AutoEscape = val
	end,
})

MainTab:CreateToggle({
	Name = "Auto Skip Cutscenes",
	CurrentValue = false,
	Flag = "AutoSkipToggle",
	Callback = function(val)
		getgenv().AutoSkip = val
		if val then ExecuteImmediateAutomation() end
	end,
})

MainTab:CreateToggle({
	Name = "Auto Retry",
	CurrentValue = false,
	Flag = "AutoRetryToggle",
	Callback = function(val)
		getgenv().AutoRetry = val
		if val then ExecuteImmediateAutomation() end
	end,
})

MainTab:CreateToggle({
	Name = "Auto Open Chests",
	CurrentValue = false,
	Flag = "AutoChestToggle",
	Callback = function(val)
		getgenv().AutoChest = val
		if val then ExecuteImmediateAutomation() end
	end,
})

MainTab:CreateToggle({
	Name = "Delete Map (FPS Boost)",
	CurrentValue = DropdownConfig.DeleteMap or false,
	Flag = "DeleteMapToggle",
	Callback = function(val)
		getgenv().DeleteMap = val
		DropdownConfig.DeleteMap = val
		SaveConfig(DropdownConfig)
		if val then DeleteMap() end
	end,
})

MainTab:CreateToggle({
	Name = "Solo Only",
	CurrentValue = false,
	Flag = "SoloOnlyToggle",
	Callback = function(val)
		getgenv().SoloOnly = val
	end,
})

MainTab:CreateToggle({
	Name = "Auto Return to Lobby",
	CurrentValue = false,
	Flag = "AutoReturnLobbyToggle",
	Callback = function(val)
		getgenv().AutoReturnLobby = val
		if not val then pcall(function() writefile(returnCounterPath, "0") end) end
	end,
})

MainTab:CreateLabel("Failsafe teleports you back to lobby after timeout.")

-- Auto Start Section

local AutoStartSection = MainTab:CreateSection("Auto Start")

MainTab:CreateButton({
	Name = "Return to Lobby",
	Callback = function()
		getRemote:InvokeServer("Functions", "Teleport", "Lobby")
		TeleportService:Teleport(14916516914, lp)
	end,
})

MainTab:CreateButton({
	Name = "Join Discord",
	Callback = function()
		setclipboard("https://discord.gg/Cczp9ZWxvY")
		Window:Notify({
			Title = "Discord",
			Content = "Invite link copied to clipboard!",
			Duration = 5,
			Image = 4483362458,
		})
	end,
})

MainTab:CreateToggle({
	Name = "Auto Start",
	CurrentValue = false,
	Flag = "AutoStartToggle",
	Callback = function(val)
		getgenv().AutoStart = val
		if val and game.PlaceId == 14916516914 then
			task.spawn(function()
				local MAX_RETRIES = 10
				local retries = 0

				local function getMyMission()
					local start = os.clock()
					while (os.clock() - start) < 2 do
						for _, mission in next, ReplicatedStorage.Missions:GetChildren() do
							if mission:FindFirstChild("Leader") and mission.Leader.Value == lp.Name then
								return mission
							end
						end
						task.wait(0.1)
					end
					return nil
				end

				while getgenv().AutoStart do
					for _, mission in next, ReplicatedStorage.Missions:GetChildren() do
						if mission:FindFirstChild("Leader") and mission.Leader.Value == lp.Name then
							getRemote:InvokeServer("S_Missions", "Leave")
						end
					end

					-- Read current dropdown values from flags
					local missionType = Rayfield.Flags["StartTypeDropdown"] and Rayfield.Flags["StartTypeDropdown"].CurrentOption[1] or "Missions"
					local selectedDifficulty, mapName, objective

					if missionType == "Missions" then
						selectedDifficulty = Rayfield.Flags["MissionDifficultyDropdown"] and Rayfield.Flags["MissionDifficultyDropdown"].CurrentOption[1] or "Normal"
						mapName = Rayfield.Flags["MissionMapDropdown"] and Rayfield.Flags["MissionMapDropdown"].CurrentOption[1] or "Shiganshina"
						objective = Rayfield.Flags["MissionObjectiveDropdown"] and Rayfield.Flags["MissionObjectiveDropdown"].CurrentOption[1] or "Skirmish"
					else
						selectedDifficulty = Rayfield.Flags["RaidDifficultyDropdown"] and Rayfield.Flags["RaidDifficultyDropdown"].CurrentOption[1] or "Hard"
						mapName = Rayfield.Flags["RaidMapDropdown"] and Rayfield.Flags["RaidMapDropdown"].CurrentOption[1] or "Trost"
						objective = Rayfield.Flags["RaidObjectiveDropdown"] and Rayfield.Flags["RaidObjectiveDropdown"].CurrentOption[1] or "Skirmish"
					end

					local created = false

					if selectedDifficulty == "Hardest" then
						local diffOrder = missionType == "Raids"
							and {"Aberrant", "Severe", "Hard"}
							or {"Aberrant", "Severe", "Hard", "Normal", "Easy"}
						for _, diff in ipairs(diffOrder) do
							if not getgenv().AutoStart then break end
							getRemote:InvokeServer("S_Missions", "Create", { Difficulty = diff, Type = missionType, Name = mapName, Objective = objective })
							if getMyMission() then
								Window:Notify({ Title = "Auto Start", Content = "Selected difficulty: " .. diff, Duration = 3, Image = 4483362458 })
								created = true
								break
							end
						end
					else
						getRemote:InvokeServer("S_Missions", "Create", { Difficulty = selectedDifficulty, Type = missionType, Name = mapName, Objective = objective })
						if getMyMission() then created = true end
					end

					if not getgenv().AutoStart then break end

					if not created then
						retries = retries + 1
						local backoff = math.min(retries * 2, 20)
						if retries >= MAX_RETRIES then
							Window:Notify({ Title = "Auto Start", Content = "Failed after " .. MAX_RETRIES .. " retries. Stopping.", Duration = 10, Image = 4483362458 })
							getgenv().AutoStart = false
							break
						end
						Window:Notify({ Title = "Auto Start", Content = "Failed. Retry " .. retries .. "/" .. MAX_RETRIES .. " in " .. backoff .. "s", Duration = backoff, Image = 4483362458 })
						task.wait(backoff)
						continue
					end

					retries = 0

					-- Modifiers
					local modFlags = Rayfield.Flags["ModifiersDropdown"]
					if modFlags and modFlags.CurrentOption then
						for _, modifier in ipairs(modFlags.CurrentOption) do
							getRemote:InvokeServer("S_Missions", "Modify", modifier)
						end
					end

					task.wait(0.5)
					getRemote:InvokeServer("S_Missions", "Start")
					task.wait(5)
				end
			end)
		end
	end,
})

MainTab:CreateDropdown({
	Name = "Type",
	Options = {"Missions", "Raids"},
	CurrentOption = {DropdownConfig._lastType or "Missions"},
	MultipleOptions = false,
	Flag = "StartTypeDropdown",
	Callback = function(val)
		DropdownConfig._lastType = val
		SaveConfig(DropdownConfig)
	end,
})

-- Mission dropdowns
MainTab:CreateDropdown({
	Name = "Mission Map",
	Options = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"},
	CurrentOption = {DropdownConfig.Missions and DropdownConfig.Missions.map or "Shiganshina"},
	MultipleOptions = false,
	Flag = "MissionMapDropdown",
	Callback = function(val)
		DropdownConfig.Missions = DropdownConfig.Missions or {}
		DropdownConfig.Missions.map = val
		SaveConfig(DropdownConfig)
	end,
})

MainTab:CreateDropdown({
	Name = "Mission Objective",
	Options = Missions[DropdownConfig.Missions and DropdownConfig.Missions.map or "Shiganshina"] or {"Skirmish","Breach","Random"},
	CurrentOption = {DropdownConfig.Missions and DropdownConfig.Missions.objective or "Skirmish"},
	MultipleOptions = false,
	Flag = "MissionObjectiveDropdown",
	Callback = function(val)
		DropdownConfig.Missions = DropdownConfig.Missions or {}
		DropdownConfig.Missions.objective = val
		SaveConfig(DropdownConfig)
	end,
})

MainTab:CreateDropdown({
	Name = "Mission Difficulty",
	Options = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
	CurrentOption = {DropdownConfig.Missions and DropdownConfig.Missions.difficulty or "Normal"},
	MultipleOptions = false,
	Flag = "MissionDifficultyDropdown",
	Callback = function(val)
		DropdownConfig.Missions = DropdownConfig.Missions or {}
		DropdownConfig.Missions.difficulty = val
		SaveConfig(DropdownConfig)
	end,
})

-- Raid dropdowns
MainTab:CreateDropdown({
	Name = "Raid Map",
	Options = {"Trost","Shiganshina","Stohess"},
	CurrentOption = {DropdownConfig.Raids and DropdownConfig.Raids.map or "Trost"},
	MultipleOptions = false,
	Flag = "RaidMapDropdown",
	Callback = function(val)
		DropdownConfig.Raids = DropdownConfig.Raids or {}
		DropdownConfig.Raids.map = val
		SaveConfig(DropdownConfig)
	end,
})

MainTab:CreateDropdown({
	Name = "Raid Objective",
	Options = Missions[DropdownConfig.Raids and DropdownConfig.Raids.map or "Trost"] or {"Skirmish","Protect","Random"},
	CurrentOption = {DropdownConfig.Raids and DropdownConfig.Raids.objective or "Skirmish"},
	MultipleOptions = false,
	Flag = "RaidObjectiveDropdown",
	Callback = function(val)
		DropdownConfig.Raids = DropdownConfig.Raids or {}
		DropdownConfig.Raids.objective = val
		SaveConfig(DropdownConfig)
	end,
})

MainTab:CreateDropdown({
	Name = "Raid Difficulty",
	Options = {"Hard","Severe","Aberrant","Hardest"},
	CurrentOption = {DropdownConfig.Raids and DropdownConfig.Raids.difficulty or "Hard"},
	MultipleOptions = false,
	Flag = "RaidDifficultyDropdown",
	Callback = function(val)
		DropdownConfig.Raids = DropdownConfig.Raids or {}
		DropdownConfig.Raids.difficulty = val
		SaveConfig(DropdownConfig)
	end,
})

MainTab:CreateLabel("Trost: Attack Titan | Shiganshina: Armored Titan | Stohess: Female Titan")

MainTab:CreateDropdown({
	Name = "Modifiers",
	Options = {"No Perks","No Skills","No Talents","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "ModifiersDropdown",
	Callback = function(val) end,
})

-- ==========================================
-- TAB : UPGRADES
-- ==========================================

local UpgradesTab = Window:CreateTab("Upgrades", 4483362458)

local UpgradesSection = UpgradesTab:CreateSection("Upgrades")

UpgradesTab:CreateToggle({
	Name = "Upgrade Gear",
	CurrentValue = false,
	Flag = "AutoUpgradeToggle",
	Callback = function(val)
		getgenv().AutoUpgrade = val
		if val then
			if game.PlaceId ~= 14916516914 then return end
			task.spawn(function()
				local plrData = GetPlayerData()
				if not plrData or not plrData.Slots then task.wait(1) return end
				while getgenv().AutoUpgrade do
					local slotIndex = lp:GetAttribute("Slot")
					if not slotIndex or not plrData.Slots[slotIndex] then task.wait(1) continue end
					local weapon = plrData.Slots[slotIndex].Weapon
					local upgrades = plrData.Slots[slotIndex].Upgrades[weapon]
					for upg, lvl in next, upgrades do
						if getRemote:InvokeServer("S_Equipment", "Upgrade", upg) then
							Window:Notify({ Title = "Upgraded " .. string.gsub(upg, "_", " "), Content = "Level " .. tostring(lvl), Duration = 1, Image = 4483362458 })
							task.wait(0.3)
						end
					end
					task.wait(0.5)
				end
			end)
		end
	end,
})

UpgradesTab:CreateToggle({
	Name = "Enhance Perks",
	CurrentValue = false,
	Flag = "AutoEnhanceToggle",
	Callback = function(val)
		getgenv().AutoPerk = val
		if val then
			if game.PlaceId ~= 14916516914 then return end
			task.spawn(function()
				local plrData = GetPlayerData()
				if not plrData or not plrData.Slots then return end
				local slotIndex = lp:GetAttribute("Slot")
				if not slotIndex or not plrData.Slots[slotIndex] then
					getgenv().AutoPerk = false
					return
				end

				local slot = plrData.Slots[slotIndex]
				local storagePerks = {}
				for id, v in pairs(slot.Perks.Storage) do storagePerks[id] = v end

				local perkSlotVal = Rayfield.Flags["PerkSlotDropdown"] and Rayfield.Flags["PerkSlotDropdown"].CurrentOption[1] or "Body"
				local equippedPerkId = slot.Perks.Equipped[perkSlotVal]
				if not equippedPerkId then
					Window:Notify({ Title = "Auto Perk", Content = "No perk equipped in " .. tostring(perkSlotVal) .. " slot.", Duration = 3, Image = 4483362458 })
					getgenv().AutoPerk = false
					return
				end

				local perkData = storagePerks[equippedPerkId]
				if not perkData then
					Window:Notify({ Title = "Auto Perk", Content = "Equipped perk data not found.", Duration = 3, Image = 4483362458 })
					getgenv().AutoPerk = false
					return
				end

				local perkName = perkData.Name
				local rarity = GetPerkRarity(perkName)
				local currentLevel = perkData.Level or 0
				local currentXP = perkData.XP or 0

				while getgenv().AutoPerk do
					if currentLevel >= 10 then
						Window:Notify({ Title = "Auto Perk", Content = perkName .. " is already Level 10!", Duration = 3, Image = 4483362458 })
						break
					end

					local selectedRarFlags = Rayfield.Flags["SelectPerksDropdown"]
					local rarityPerks = {}
					if selectedRarFlags and selectedRarFlags.CurrentOption then
						for _, r in ipairs(selectedRarFlags.CurrentOption) do rarityPerks[r] = true end
					end

					local validPerks = {}
					local totalXPGain = 0

					for perkId, tbl in pairs(storagePerks) do
						local r = GetPerkRarity(tbl.Name)
						if perkId ~= equippedPerkId and rarityPerks[r] then
							table.insert(validPerks, perkId)
							totalXPGain = totalXPGain + GetPerkXP(r, math.max(tbl.Level or 0, 1))
							if #validPerks >= 5 then break end
						end
					end

					if #validPerks == 0 then
						Window:Notify({ Title = "Auto Perk", Content = "No more food perks found.", Duration = 3, Image = 4483362458 })
						break
					end

					if getRemote:InvokeServer("S_Equipment", "Enhance", equippedPerkId, validPerks) then
						for _, id in ipairs(validPerks) do storagePerks[id] = nil end
						currentXP = currentXP + totalXPGain
						while currentLevel < 10 do
							local thresholds = Perk_Level_XP[rarity]
							if not thresholds then break end
							local needed = thresholds[currentLevel + 1]
							if not needed or currentXP < needed then break end
							currentXP = currentXP - needed
							currentLevel = currentLevel + 1
						end
						Window:Notify({ Title = "Enhanced: " .. perkName, Content = "Level " .. tostring(currentLevel) .. " (+" .. totalXPGain .. " XP)", Duration = 1, Image = 4483362458 })
					end
					task.wait(0.5)
				end

				getgenv().AutoPerk = false
			end)
		end
	end,
})

UpgradesTab:CreateDropdown({
	Name = "Perk Slot",
	Options = {"Defense", "Support", "Family", "Extra", "Offense", "Body"},
	CurrentOption = {"Body"},
	MultipleOptions = false,
	Flag = "PerkSlotDropdown",
	Callback = function(val) end,
})

UpgradesTab:CreateDropdown({
	Name = "Perks to use (Food)",
	Options = {"Common", "Rare", "Epic", "Legendary"},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "SelectPerksDropdown",
	Callback = function(val) end,
})

UpgradesTab:CreateLabel("Default perk slot is Body")

-- Skill Tree Section

local SkillTreeSection = UpgradesTab:CreateSection("Skill Tree")

UpgradesTab:CreateToggle({
	Name = "Auto Skill Tree",
	CurrentValue = false,
	Flag = "AutoSkillTree",
	Callback = function(val)
		getgenv().AutoSkillTree = val
		local plrData = GetPlayerData()
		if val then
			if game.PlaceId ~= 14916516914 then return end
			if not plrData or not plrData.Slots then return end
			task.spawn(function()
				while getgenv().AutoSkillTree do
					local slotIndex = lp:GetAttribute("Slot")
					if not slotIndex or not plrData.Slots[slotIndex] then task.wait(1) continue end
					local weapon = plrData.Slots[slotIndex].Weapon

					local middle = Rayfield.Flags["MiddlePathDropdown"] and Rayfield.Flags["MiddlePathDropdown"].CurrentOption[1] or "Critical"
					local left   = Rayfield.Flags["LeftPathDropdown"]   and Rayfield.Flags["LeftPathDropdown"].CurrentOption[1]   or "Cooldown Reduction"
					local right  = Rayfield.Flags["RightPathDropdown"]  and Rayfield.Flags["RightPathDropdown"].CurrentOption[1]  or "Health"

					local middlePath = SkillPaths[weapon] and SkillPaths[weapon][middle]
					local leftPath   = SkillPaths.Support[left]
					local rightPath  = SkillPaths.Defense[right]

					local p1 = Rayfield.Flags["Priority1Dropdown"] and Rayfield.Flags["Priority1Dropdown"].CurrentOption[1] or "Middle"
					local p2 = Rayfield.Flags["Priority2Dropdown"] and Rayfield.Flags["Priority2Dropdown"].CurrentOption[1] or "Left"
					local p3 = Rayfield.Flags["Priority3Dropdown"] and Rayfield.Flags["Priority3Dropdown"].CurrentOption[1] or "None"

					local pathMap = { Left = leftPath, Middle = middlePath, Right = rightPath }
					local paths = {}
					local used = {}

					local function addPath(p)
						if p ~= "None" and not used[p] and pathMap[p] then
							table.insert(paths, pathMap[p])
							used[p] = true
						end
					end

					addPath(p1); addPath(p2); addPath(p3)

					for _, path in ipairs(paths) do
						if path then
							for _, skillId in ipairs(path) do
								if table.find(plrData.Slots[slotIndex].Skills.Unlocked, skillId) then continue end
								local success = getRemote:InvokeServer("S_Equipment", "Unlock", {skillId})
								if success then
									Window:Notify({ Title = "Unlocked Skill", Content = "ID: " .. skillId, Duration = 1, Image = 4483362458 })
								end
							end
						end
					end
					task.wait()
				end
			end)
		end
	end,
})

UpgradesTab:CreateDropdown({
	Name = "Middle Path",
	Options = {"Damage", "Critical"},
	CurrentOption = {"Critical"},
	MultipleOptions = false,
	Flag = "MiddlePathDropdown",
	Callback = function(val) end,
})

UpgradesTab:CreateDropdown({
	Name = "Left Path",
	Options = {"Regen", "Cooldown Reduction"},
	CurrentOption = {"Cooldown Reduction"},
	MultipleOptions = false,
	Flag = "LeftPathDropdown",
	Callback = function(val) end,
})

UpgradesTab:CreateDropdown({
	Name = "Right Path",
	Options = {"Health", "Damage Reduction"},
	CurrentOption = {"Health"},
	MultipleOptions = false,
	Flag = "RightPathDropdown",
	Callback = function(val) end,
})

UpgradesTab:CreateDropdown({
	Name = "Priority 1",
	Options = {"Left", "Middle", "Right", "None"},
	CurrentOption = {"Middle"},
	MultipleOptions = false,
	Flag = "Priority1Dropdown",
	Callback = function(val) end,
})

UpgradesTab:CreateDropdown({
	Name = "Priority 2",
	Options = {"Left", "Middle", "Right", "None"},
	CurrentOption = {"Left"},
	MultipleOptions = false,
	Flag = "Priority2Dropdown",
	Callback = function(val) end,
})

UpgradesTab:CreateDropdown({
	Name = "Priority 3",
	Options = {"Left", "Middle", "Right", "None"},
	CurrentOption = {"None"},
	MultipleOptions = false,
	Flag = "Priority3Dropdown",
	Callback = function(val) end,
})

-- ==========================================
-- TAB : MISC
-- ==========================================

local MiscTab = Window:CreateTab("Misc", 4483362458)

local SlotSection = MiscTab:CreateSection("Slot")

MiscTab:CreateToggle({
	Name = "Auto Select Slot",
	CurrentValue = false,
	Flag = "AutoSelectSlot",
	Callback = function(val)
		getgenv().AutoSlot = val
		if val and not lp:GetAttribute("Slot") then
			local selectedSlot = Rayfield.Flags["SelectSlotDropdown"] and Rayfield.Flags["SelectSlotDropdown"].CurrentOption[1] or "Slot A"
			local args = { "Functions", "Select", string.sub(selectedSlot, -1) }
			task.spawn(function()
				repeat
					getRemote:InvokeServer(unpack(args))
					task.wait(1)
				until lp:GetAttribute("Slot") or not getgenv().AutoSlot
				getRemote:InvokeServer("Functions", "Teleport", "Lobby")
			end)
		end
	end,
})

MiscTab:CreateDropdown({
	Name = "Select Slot",
	Options = {"Slot A", "Slot B", "Slot C"},
	CurrentOption = {"Slot A"},
	MultipleOptions = false,
	Flag = "SelectSlotDropdown",
	Callback = function(val) end,
})

MiscTab:CreateToggle({
	Name = "Auto Prestige",
	CurrentValue = false,
	Flag = "AutoPrestigeToggle",
	Callback = function(val)
		getgenv().AutoPrestige = val
		if val then
			if game.PlaceId ~= 14916516914 then return end
			task.spawn(function()
				local pData = GetPlayerData()
				if not pData or not pData.Slots then return end
				local slotIdx = lp:GetAttribute("Slot")
				if not slotIdx or not pData.Slots[slotIdx] then return end
				local gold = pData.Slots[slotIdx].Currency.Gold
				local boostVal = Rayfield.Flags["SelectBoostDropdown"] and Rayfield.Flags["SelectBoostDropdown"].CurrentOption[1] or "Luck Boost"
				local prestigeGold = (Rayfield.Flags["PrestigeGoldSlider"] and Rayfield.Flags["PrestigeGoldSlider"].Value or 0) * 1000000
				if gold < prestigeGold then return end
				while getgenv().AutoPrestige do
					for _, Memory in ipairs(Talents) do
						if not getgenv().AutoPrestige then break end
						local success = getRemote:InvokeServer("S_Equipment", "Prestige", {Boosts = boostVal, Talents = Memory})
						if success then
							Window:Notify({ Title = "Successfully Prestiged", Content = "Prestiged with " .. boostVal .. " and " .. Memory, Duration = 5, Image = 4483362458 })
							break
						end
						task.wait(0.1)
					end
					task.wait(1)
				end
			end)
		end
	end,
})

MiscTab:CreateDropdown({
	Name = "Select Boost",
	Options = {"Luck Boost", "EXP Boost", "Gold Boost"},
	CurrentOption = {"Luck Boost"},
	MultipleOptions = false,
	Flag = "SelectBoostDropdown",
	Callback = function(val) end,
})

MiscTab:CreateSlider({
	Name = "Prestige Gold (in millions)",
	Range = {0, 100},
	Increment = 1,
	Suffix = "M",
	CurrentValue = 0,
	Flag = "PrestigeGoldSlider",
	Callback = function(val) end,
})

-- Family Roll Section

local FamilySection = MiscTab:CreateSection("Family Roll")

MiscTab:CreateToggle({
	Name = "Auto Roll",
	CurrentValue = false,
	Flag = "AutoRollToggle",
	Callback = function(val)
		getgenv().AutoRoll = val
		if val then
			if game.PlaceId ~= 13379208636 then
				Window:Notify({ Title = "TITANIC HUB", Content = "You must be in the lobby to use family roll features.", Duration = 3, Image = 4483362458 })
				return
			end
			task.spawn(function()
				while getgenv().AutoRoll do
					local familyInputFlag = Rayfield.Flags["SelectFamily"]
					local rarityFlag = Rayfield.Flags["SelectFamilyRarity"]
					local text = familyInputFlag and familyInputFlag.Value or ""
					local targets = nil
					if text and text ~= "" then
						text = string.lower(text)
						targets = string.split(text, ",")
					end
					local rarities = nil
					if rarityFlag and rarityFlag.CurrentOption then
						rarities = {}
						for _, r in ipairs(rarityFlag.CurrentOption) do
							table.insert(rarities, string.lower(r))
						end
					end
					roll(targets, rarities)
					task.wait(0.25)
				end
			end)
		end
	end,
})

MiscTab:CreateInput({
	Name = "Select Families",
	CurrentValue = "",
	PlaceholderText = "Fritz,Yeager,etc.",
	RemoveTextAfterFocusLost = false,
	Flag = "SelectFamily",
	Callback = function(val)
		if val ~= "" then
			Window:Notify({ Title = "TITANIC HUB", Content = "Families selected: " .. val, Duration = 2, Image = 4483362458 })
		end
	end,
})

MiscTab:CreateDropdown({
	Name = "Stop At (Rarity)",
	Options = familyRaritiesOptions,
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "SelectFamilyRarity",
	Callback = function(val) end,
})

MiscTab:CreateLabel("Mythical families won't be rolled. Separate families with commas & no spaces (Fritz,Yeager)")

-- ==========================================
-- TAB : SETTINGS
-- ==========================================

local SettingsTab = Window:CreateTab("Settings", 4483362458)

local WebhookSection = SettingsTab:CreateSection("Webhook")

SettingsTab:CreateToggle({
	Name = "Reward Webhook",
	CurrentValue = false,
	Flag = "ToggleRewardWebhook",
	Callback = function(val)
		getgenv().RewardWebhook = val
	end,
})

SettingsTab:CreateToggle({
	Name = "Mythical Family Webhook",
	CurrentValue = false,
	Flag = "ToggleMythicalFamilyWebhook",
	Callback = function(val)
		getgenv().MythicalFamilyWebhook = val
	end,
})

SettingsTab:CreateInput({
	Name = "Webhook URL",
	CurrentValue = "",
	PlaceholderText = "https://discord.com/api/webhooks/...",
	RemoveTextAfterFocusLost = false,
	Flag = "WebhookUrl",
	Callback = function(val)
		webhook = val
	end,
})

local UISection = SettingsTab:CreateSection("UI")

SettingsTab:CreateToggle({
	Name = "Disable 3D Rendering (FPS Boost)",
	CurrentValue = false,
	Flag = "Disable3DRendering",
	Callback = function(val)
		RunService:Set3dRenderingEnabled(not val)
	end,
})

SettingsTab:CreateKeybind({
	Name = "Menu Toggle Keybind",
	CurrentKeybind = "RightControl",
	HoldToInteract = false,
	Flag = "MenuKeybind",
	Callback = function(keybind)
		-- Rayfield handles toggle internally via keybind system
	end,
})

-- ==========================================
-- ANTI-AFK
-- ==========================================

local virtualUser = game:GetService("VirtualUser")
lp.Idled:Connect(function()
	virtualUser:CaptureController()
	virtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- MAIN AUTOMATION LOOP
-- ==========================================

task.spawn(function()
	while true do
		local success, err = pcall(ExecuteImmediateAutomation)
		task.wait(0.5)
	end
end)

-- Auto delete map on load if saved
task.spawn(function()
	task.wait(0.5)
	if getgenv().DeleteMap then DeleteMap() end
end)
