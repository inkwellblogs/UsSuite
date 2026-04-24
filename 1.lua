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
	local args = {
		"Functions",
		"Settings",
		"Get"
	}
	lastPlayerData = getRemote:InvokeServer(unpack(args))
	lastPlayerDataTime = os.clock()	
	return lastPlayerData
end

-- Map data and plr data don't update when I call them so I only need to call them when i need them, not in a loop

local mapData = nil

local startLoadTime = os.clock()
local isLobby = game.PlaceId == 14916516914

repeat
    task.wait(1)
    mapData = getRemote:InvokeServer("Data", "Copy")
    if not mapData then
        lastPlayerData = nil -- force refresh (bypass cache)
        GetPlayerData()
    end
    -- If we're not in the lobby, we should wait longer for mapData to populate
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

local familyRaritiesOptions = {
	"Rare",
	"Epic",
	"Legendary",
	"Mythical"
}

-- Config system for persistent dropdown state
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
		local Injuries = lp.Character:FindFirstChild("Injuries")
		if Injuries then
			for i, v in Injuries:GetChildren() do
				v:Destroy()
			end
		end
		task.wait(1)
	end
end)

function AutoFarm:Start()
	if self._running then return end
	
	if isLobby then
		return
	end

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
			if os.clock() - startTime > 10 then -- Notify every 10s if still waiting
				Library:Notify({
					Title = "TITANIC HUB",
					Description = "Still waiting for mission assets to load...",
					Time = 5
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

		-- INTERFACE.ChildAdded:Connect(function(v)
		-- 	if tonumber(v.Name) then
		-- 		v:Destroy()
		-- 	end
		-- end)
		
		-- Hash map for faster O(1) lookups
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
			if lp:GetAttribute("Cutscene") then
				task.wait()
				continue
			end

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
				-- Track mission start time
				if not self.missionStartTime then
					self.missionStartTime = os.clock()
				end
				
				local missionElapsedTime = os.clock() - self.missionStartTime
				if missionElapsedTime >= 900 then  -- 15 minutes (900 seconds)
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

			-- CRITICAL: Refresh titansFolder to see new spawns
			titansFolder = workspace:FindFirstChild("Titans") or titansFolder

			-- Map and Folder Paths
			local ws_ObjectiveFolder = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective") -- contains models of for example armored_boss or like female titan
			local rs_ObjectiveFolder = ReplicatedStorage:FindFirstChild("Objectives") -- this contains the objective intvalues (displayed in gui)
			local mapType = workspace:GetAttribute("Type") or (mapData and mapData.Map and mapData.Map.Type)

			-- Armored Raid Detection
			local isArmoredRaid = ws_ObjectiveFolder:FindFirstChild("Armored_Boss")
			local isFemaleRaid = rs_ObjectiveFolder:FindFirstChild("Defeat_Annie")
			local femaleExists = ws_ObjectiveFolder:FindFirstChild("Female_Boss")
			local attackExists = ws_ObjectiveFolder:FindFirstChild("Attack_Boss")
			local hasReinerObjective = rs_ObjectiveFolder:FindFirstChild("Defeat_Reiner")

			-- Stohess Transition Pause: Only if it IS a female raid and bosses are missing
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
				table.clear(validNapes) -- Reuse memory
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

			-- Range limit logic: Only for Phase 1 of Armored Raid
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

				-- Boss Phase logic: Skip Armored Titan ONLY during Protect phase
				if isArmoredRaid and not hasReinerObjective and tName == "Armored_Titan" then continue end
		
				if isBoss and not titanModel:GetAttribute("State") then continue end
			
				local isRoaring = isBoss and (titanModel:GetAttribute("Attack") == "Roar" or titanModel:GetAttribute("Attack") == "Berserk_Mode")

				if tName == "Attack_Titan" then attackTitanFound = true end

				local dx = referencePos.X - nape.Position.X
				local dz = referencePos.Z - nape.Position.Z
				local d = dx*dx + dz*dz
				
				-- Hysteresis: Keep target lock-on
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
			
			-- Priotize clearing regular titans near objective if range limit is on
			if useRangeLimit and closestNape then
				targetPart = closestNape
				targetIsRoaring = false
			end

			
			-- Keep last titan alive for at least 29 seconds
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
				-- Traverse up to find the root Titan Model cleanly
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
					task.wait()
					continue
				end

				-- Calculate position (You can add extra height here if needed to avoid the roar hitbox)
				-- Use Titan HRP CFrame to stay in a stable position relative to the body (stops spinning)
				local titanHRP = currentTitanModel:FindFirstChild("HumanoidRootPart")
				local targetHeightPos
				if titanHRP then
					-- This puts you at the HeightOffset above, and 30 studs BEHIND the Titan
					targetHeightPos = (titanHRP.CFrame * CFrame.new(0, getgenv().AutoFarmConfig.HeightOffset, 30)).Position
				else
					targetHeightPos = targetPart.Position + Vector3.new(0, getgenv().AutoFarmConfig.HeightOffset, 0)
				end
				
				if getgenv().AutoFarmConfig.MovementMode == "Hover" then
					local dir = targetHeightPos - rootPos
					root.AssemblyLinearVelocity = dir.Magnitude > 1 and dir.Unit * getgenv().AutoFarmConfig.MoveSpeed or V3_ZERO
				else
					root.AssemblyLinearVelocity = V3_ZERO
					root.CFrame = CFrame.new(targetHeightPos)
				end

				if not attackTitanReady then task.wait() continue end

				local dx = root.Position.X - targetPart.Position.X
				local dz = root.Position.Z - targetPart.Position.Z

				if not targetIsRoaring and (dx*dx + dz*dz) <= AttackRangeSq and (now - lastAttack) >= getgenv().AutoFarmConfig.AttackCooldown then
					lastAttack = now

					if slotData.Weapon == "Blades" then
						postRemote:FireServer("Attacks", "Slash", true)
						postRemote:FireServer("Hitboxes", "Register", targetPart, math.random(625, 850))
					else
						local isBoss = bossNames[targetPart.Parent.Parent.Parent.Name]
						local text = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
						local currentAmmo, maxAmmo = string.match(text, "(%d+)%s*/%s*(%d+)")
						currentAmmo, maxAmmo = tonumber(currentAmmo), tonumber(maxAmmo)

						if currentAmmo and currentAmmo > 0 then
							task.spawn(function()
								local function getAmmo()
									local hudText = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
									return tonumber(string.match(hudText, "(%d+)"))
								end

								local beforeAmmo = getAmmo()
								getRemote:InvokeServer("Spears", "S_Fire", tostring(currentAmmo))
								local afterAmmo = getAmmo()

								-- Retry if ammo didn't decrement (anti-lag)
								if afterAmmo and beforeAmmo and afterAmmo == beforeAmmo then
									for j = maxAmmo, 1, -1 do
										local prevAmmo = getAmmo()
										getRemote:InvokeServer("Spears", "S_Fire", tostring(j))
										local newAmmo = getAmmo()
										if newAmmo and prevAmmo and newAmmo < prevAmmo then break end
									end
								end
								
								-- Bosses take more damage / rapid fire
								local loops = isBoss and 30 or 1
								for j = 1, loops do
									postRemote:FireServer("Spears", "S_Explode", targetPart.Position)
								end
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

function AutoFarm:Stop()
	self._running = false
end

local function formatTable(tbl)
	local str = ""
	for k, v in pairs(tbl) do
		str ..= string.format("%s: %s\n", k, tostring(v))
	end
	return str ~= "" and str or "None"
end

local function formatItems(tbl)
	local str = ""
	for name, qty in pairs(tbl) do
		name = string.gsub(name, "_", " ")
		str ..= string.format("[+] %s (x%s)\n", name, qty)
	end
	return str ~= "" and str or "None"
end

local data = {
	Stats = {},
	Total = {},
	Items = {},
	Special = {}
}

local path = "./THUB/aotr/games_played.txt"
if not isfile(path) then writefile(path, "0") end
local gamesPlayed = tonumber(readfile(path))

local webhook

if rewards then
	rewards:GetPropertyChangedSignal("Visible"):Connect(function()
		if not rewards.Visible then return end

	gamesPlayed = gamesPlayed + 1
		writefile("./THUB/aotr/games_played.txt", tostring(gamesPlayed))

		local gamesUntilReturn = tonumber(readfile(returnCounterPath)) or 0
		local willReturn = false

		if getgenv().AutoReturnLobby then
	gamesUntilReturn = gamesUntilReturn + 1

			if gamesUntilReturn >= 10 then
				gamesUntilReturn = 0
				willReturn = true
			end
			
			writefile(returnCounterPath, tostring(gamesUntilReturn))
			
			if willReturn then
				task.spawn(function()
					getRemote:InvokeServer("Functions", "Teleport", "Lobby")
				end)
				
				task.wait(0.5)
				TeleportService:Teleport(14916516914, lp)
				return
			end
		elseif gamesUntilReturn >= 10 then
			-- safety reset
			gamesUntilReturn = 0
			writefile(returnCounterPath, "0")
		end
		
		if not getgenv().RewardWebhook then return end
		
		-- Wait for stats to populate properly (check for non-zero or non-placeholder)
		local start = os.clock()
		local hasData
		repeat 
			task.wait(0.1)
			hasData = false
			for _, v in ipairs(statsFrame:GetChildren()) do
				if v:IsA("Frame") and v:FindFirstChild("Amount") and v.Amount.Text ~= "0" and v.Amount.Text ~= "" then
					hasData = true
					break
				end
			end
		until hasData or (os.clock() - start) > 2

		data.Stats = {}
		data.Total = {}
		data.Items = {}
		data.Special = {}

		-- Capture Stats from UI
		for i, v in ipairs(statsFrame:GetChildren()) do
			if v:IsA("Frame") and v:FindFirstChild("Stat") and v:FindFirstChild("Amount") then
				data.Stats[string.gsub(v.Name, "_", " ")] = v.Amount.Text
			end
		end

		-- Capture Items from UI
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
					if i == "Gems" or i == "Gold" then
						data.Total[i] = v
					end
				end
			end
			if slotData.Progression then
				for i, v in pairs(slotData.Progression) do
					if i == "Prestige" or i == "Level" or i == "Streak" then
						data.Total[i] = v
					end
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
							{
							name = "Information",
							value =
								"```\n" ..
								"User: " .. lp.Name .. "\n" ..
								"Games Played: " .. tostring(gamesPlayed) .. "\n" ..
								"Executor: " .. executor ..
								"\n```",
							inline = true
							},
							{
								name = "Total Stats",
								value =
									"```\n" ..
									"Level : " .. tostring(data.Total.Level or "1") .. "\n" ..
									"Gold  : " .. tostring(data.Total.Gold or "0") .. "\n" ..
									"Gems  : " .. tostring(data.Total.Gems or "0") ..
									"\n```",
								inline = true
							},
							{
								name = "Combat",
								value = "```\n" .. formatTable(data.Stats) .. "\n```",
								inline = true
							},
							{
								name = "Rewards",
								value = "```\n" .. formatItems(data.Items) .. "\n```",
								inline = true
							},
							{
								name = "Special",
								value = "```\n" .. (hasSpecial and formatItems(data.Special) or "None") .. "\n```",
								inline = true
							}
						},

						footer = {
							text = "TITANIC HUB • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
						},

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

local Blades_Critical = {
	"1","2","3","4","5","6","7","8","9","10","11","12","13",
	"14","15","16","17","18","19","20","21","22","23","24","25"
}

local Blades_Damage = {
	"1","2","3","4","5","6","7","8","9","10","11","12","13",
	"26","27","28","29","30","31","32","33","34","35","36","37"
}

local Spears_Critical = {
	"113","114","115","116","117","118","119","120",
	"121","122","123","124","125",
	"126","127","128","129","130","131","132",
	"133","134","135","136","137"
}

local Spears_Damage = {
	"113","114","115","116","117","118","119","120",
	"121","122","123","124","125",
	"138","139","140","141","142","143","144",
	"145","146","147","148","149"
}

local Defense_Health = {
	"38","39","40","41","42","43","44","45",
	"46","47","48","49","50","51","52","53","54","55","56","57"
}

local Defense_Damage_Reduction = {
	"38","39","40","41","42","43","44","45",
	"58","59","60","61","62","63","64","65","66","67","68","69"
}

local Support_Regen = {
	"70","71","72","73","74","75","76","77","78","79","80",
	"81","82","83","84","85","86","87","88","89"
}

local Support_Cooldown_Reduction = {
	"70","71","72","73","74","75","76","77","78","79","80",
	"90","91","92","93","94","95","96","97","98"
}

local Missions = {
	["Shiganshina"] = { "Skirmish", "Breach", "Random" },
	["Trost"] = { "Skirmish", "Protect", "Random" },
	["Outskirts"] = { "Skirmish", "Escort", "Random" },
	["Giant Forest"] = { "Skirmish", "Guard", "Random" },
	["Utgard"] = { "Skirmish", "Defend", "Random" },
	["Loading Docks"] = { "Skirmish", "Stall", "Random" },
	["Stohess"] = { "Skirmish", "Random" }
}

local SkillPaths = {
	Blades = { Damage = Blades_Damage, Critical = Blades_Critical },
	Spears = { Damage = Spears_Damage, Critical = Spears_Critical },
	Defense = { Health = Defense_Health, ["Damage Reduction"] = Defense_Damage_Reduction },
	Support = { Regen = Support_Regen, ["Cooldown Reduction"] = Support_Cooldown_Reduction }
}

local function GetPerkRarity(perkName)
	return PerkRarityMap[perkName]
end

local function GetPerkXP(rarity, level)
	local base = Perk_Base_XP[rarity] or 0
	return base * math.max(level, 1)
end

local function UseButton(button)
	if not button or not button.Parent then
		return false
	end

	if not button.Visible then
		return false
	end

	if GuiService.MenuIsOpen then
		vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game) 
		vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
		task.wait(0.1)
	end

	GuiService.SelectedObject = button
	task.wait(0.05)
	vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game) -- same here
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
			
			for i, v in workspace.Climbable:GetChildren() do
				v:Destroy()
			end

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

-- Auto execute: queue once when toggled on
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
		
		if skip and skip.Visible then
			UseButton(skip:FindFirstChild("Interact"))
		end
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
		-- Toggles reference set after UI loads; guard with pcall
		pcall(function()
			if Library and Library.Toggles and Library.Toggles.AutoRollToggle then
				Library.Toggles.AutoRollToggle:SetValue(false)
			end
		end)

		if familyRarity == "mythical" and getgenv().MythicalFamilyWebhook and webhook and webhook ~= "" then
			local payload = {
				content = "MYTHICAL FAMILY ROLLED! @everyone",
				embeds = {{
					title = "Family Roll Success",
					color = 0xff0000,
					fields = {
						{
							name = "Information",
							value = "```\n" ..
									"User: " .. lp.Name .. "\n" ..
									"Family: " .. tostring(familyString) .. "\n" ..
									"\n```",
							inline = true
						}
					},
					footer = {
						text = "TITANIC HUB • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
					},
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

		pcall(function()
			Library:Notify({
				Title = "TITANIC HUB",
				Description = "Target family rolled: " .. familyString,
				Time = 5,
			})
		end)
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

	if rollButton then
		UseButton(rollButton)
	end
end

-- Weapon reload system
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

		-- 1. Refill Reserves (if empty)
		if current == 0 and autoRefillEnabled then
			local refillPart = workspace:FindFirstChild("Unclimbable")
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")

			if refillPart then
				isReloading = true
				lastReloadTime = os.clock()
				pcall(function()
					postRemote:FireServer("Attacks", "Reload", refillPart)
				end)
				task.delay(1, function() isReloading = false end)
				return
			end
		end

		-- 2. Equip Blade (if missing from hand and we have reserves)
		if blade and blade.Transparency == 1 and current > 0 then
			isReloading = true
			lastReloadTime = os.clock()
			pcall(function()
				getRemote:InvokeServer("Blades", "Reload") 
			end)
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

-- Unified high-frequency polling loop
task.spawn(function()
	while true do
		pcall(handleWeaponReload)
		task.wait(0.5)
	end
end)

-- Auto Escape listener
getgenv().AutoEscape = false
postRemote.OnClientEvent:Connect(function(...)
	local args = {...}
	if getgenv().AutoEscape and args[1] == "Titans" and args[2] == "Grab_Event" then
		game:GetService("Players").LocalPlayer.PlayerGui.Interface.Buttons.Visible = not getgenv().AutoEscape
		postRemote:FireServer("Attacks", "Slash_Escape")
	end
end)

-- ==========================================
-- SIMPLE UI LIBRARY (Replacement for Obsidian)
-- ==========================================

-- Simple UI Library for Roblox
local Library = {}
local Toggles = {}
local Options = {}

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TitanicHub"
ScreenGui.Parent = game:GetService("CoreGui")

-- Create Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Create Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "TITANIC HUB"
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = MainFrame
Title.BorderSizePixel = 0

-- Create Tab Buttons Frame
local TabFrame = Instance.new("Frame")
TabFrame.Name = "TabFrame"
TabFrame.Size = UDim2.new(0, 120, 1, -30)
TabFrame.Position = UDim2.new(0, 0, 0, 30)
TabFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TabFrame.BorderSizePixel = 0
TabFrame.Parent = MainFrame

-- Create Content Frame
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -120, 1, -30)
ContentFrame.Position = UDim2.new(0, 120, 0, 30)
ContentFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ContentFrame.BorderSizePixel = 0
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

-- Create ScrollingFrame for content
local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Name = "ScrollingFrame"
ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollingFrame.Position = UDim2.new(0, 0, 0, 0)
ScrollingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ScrollingFrame.BorderSizePixel = 0
ScrollingFrame.ScrollBarThickness = 5
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.Parent = ContentFrame

-- Create UIListLayout for ScrollingFrame
local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = ScrollingFrame

local currentTab = nil
local tabs = {}

function Library:CreateTab(name, icon)
	local tabButton = Instance.new("TextButton")
	tabButton.Name = name
	tabButton.Size = UDim2.new(1, 0, 0, 30)
	tabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabButton.Text = name
	tabButton.Font = Enum.Font.SourceSans
	tabButton.TextSize = 14
	tabButton.Parent = TabFrame
	tabButton.BorderSizePixel = 0
	
	-- Add spacing between buttons
	if #TabFrame:GetChildren() > 1 then
		tabButton.Position = UDim2.new(0, 0, 0, (#TabFrame:GetChildren() - 2) * 30)
	end
	
	local tabContent = Instance.new("Frame")
	tabContent.Name = name .. "Content"
	tabContent.Size = UDim2.new(1, -10, 1, -10)
	tabContent.Position = UDim2.new(0, 5, 0, 5)
	tabContent.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	tabContent.BorderSizePixel = 0
	tabContent.Visible = false
	tabContent.Parent = ScrollingFrame
	
	local tabData = {
		Button = tabButton,
		Content = tabContent
	}
	tabs[name] = tabData
	
	tabButton.MouseButton1Click:Connect(function()
		for _, tab in pairs(tabs) do
			tab.Content.Visible = false
			tab.Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end
		tabContent.Visible = true
		tabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		currentTab = tabContent
	end)
	
	-- Select first tab by default
	if not currentTab then
		tabContent.Visible = true
		tabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		currentTab = tabContent
	end
	
	return tabContent
end

function Library:AddToggle(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local toggleFrame = Instance.new("Frame")
	toggleFrame.Name = "Toggle"
	toggleFrame.Size = UDim2.new(1, -10, 0, 30)
	toggleFrame.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	toggleFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	toggleFrame.BorderSizePixel = 0
	toggleFrame.Parent = tabContent
	
	local toggleLabel = Instance.new("TextLabel")
	toggleLabel.Text = config.Text or "Toggle"
	toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	toggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
	toggleLabel.Position = UDim2.new(0, 5, 0, 0)
	toggleLabel.TextSize = 14
	toggleLabel.Font = Enum.Font.SourceSans
	toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
	toggleLabel.BorderSizePixel = 0
	toggleLabel.Parent = toggleFrame
	
	local toggleButton = Instance.new("TextButton")
	toggleButton.Text = ""
	toggleButton.Size = UDim2.new(0, 40, 0, 20)
	toggleButton.Position = UDim2.new(1, -45, 0.5, -10)
	toggleButton.BackgroundColor3 = config.Default and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
	toggleButton.BorderSizePixel = 0
	toggleButton.Parent = toggleFrame
	
	local isToggled = config.Default or false
	
	toggleButton.MouseButton1Click:Connect(function()
		isToggled = not isToggled
		toggleButton.BackgroundColor3 = isToggled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
		if config.Callback then
			config.Callback(isToggled)
		end
	end)
	
	-- Store toggle reference
	if config.Name then
		Toggles[config.Name] = {
			Value = isToggled,
			SetValue = function(self, value)
				isToggled = value
				toggleButton.BackgroundColor3 = isToggled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
				if config.Callback then
					config.Callback(isToggled)
				end
			end
		}
	end
	
	return toggleFrame
end

function Library:AddButton(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, -10, 0, 30)
	button.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = config.Text or "Button"
	button.Font = Enum.Font.SourceSans
	button.TextSize = 14
	button.BorderSizePixel = 0
	button.Parent = tabContent
	
	button.MouseButton1Click:Connect(function()
		if config.Callback then
			config.Callback()
		end
	end)
	
	return button
end

function Library:AddDropdown(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local dropdownFrame = Instance.new("Frame")
	dropdownFrame.Name = "Dropdown"
	dropdownFrame.Size = UDim2.new(1, -10, 0, 30)
	dropdownFrame.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	dropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dropdownFrame.BorderSizePixel = 0
	dropdownFrame.Parent = tabContent
	
	local dropdownLabel = Instance.new("TextLabel")
	dropdownLabel.Text = config.Text or "Dropdown"
	dropdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	dropdownLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dropdownLabel.Size = UDim2.new(0.4, 0, 1, 0)
	dropdownLabel.Position = UDim2.new(0, 5, 0, 0)
	dropdownLabel.TextSize = 14
	dropdownLabel.Font = Enum.Font.SourceSans
	dropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
	dropdownLabel.BorderSizePixel = 0
	dropdownLabel.Parent = dropdownFrame
	
	local dropdownButton = Instance.new("TextButton")
	dropdownButton.Text = config.Values[config.Default] or "Select..."
	dropdownButton.Size = UDim2.new(0.5, -10, 1, 0)
	dropdownButton.Position = UDim2.new(0.45, 0, 0, 0)
	dropdownButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	dropdownButton.TextSize = 14
	dropdownButton.Font = Enum.Font.SourceSans
	dropdownButton.BorderSizePixel = 0
	dropdownButton.Parent = dropdownFrame
	
	local dropdownList = Instance.new("Frame")
	dropdownList.Name = "DropdownList"
	dropdownList.Size = UDim2.new(0.5, -10, 0, 0)
	dropdownList.Position = UDim2.new(0.45, 0, 1, 0)
	dropdownList.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dropdownList.BorderSizePixel = 0
	dropdownList.Visible = false
	dropdownList.ClipsDescendants = true
	dropdownList.Parent = dropdownFrame
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Parent = dropdownList
	
	local selectedValue = config.Values[config.Default] or ""
	local isOpen = false
	
	dropdownButton.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		dropdownList.Visible = isOpen
		if isOpen then
			dropdownList.Size = UDim2.new(0.5, -10, 0, #config.Values * 25)
		else
			dropdownList.Size = UDim2.new(0.5, -10, 0, 0)
		end
	end)
	
	-- Clear existing options
	for _, child in pairs(dropdownList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	for i, value in ipairs(config.Values) do
		local option = Instance.new("TextButton")
		option.Text = value
		option.Size = UDim2.new(1, 0, 0, 25)
		option.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		option.TextColor3 = Color3.fromRGB(255, 255, 255)
		option.TextSize = 14
		option.Font = Enum.Font.SourceSans
		option.BorderSizePixel = 0
		option.Parent = dropdownList
		
		option.MouseButton1Click:Connect(function()
			selectedValue = value
			dropdownButton.Text = value
			isOpen = false
			dropdownList.Visible = false
			dropdownList.Size = UDim2.new(0.5, -10, 0, 0)
			if config.Callback then
				config.Callback(value)
			end
		end)
	end
	
	-- Store option reference
	if config.Name then
		Options[config.Name] = {
			Value = selectedValue,
			SetValue = function(value)
				selectedValue = value
				dropdownButton.Text = value
				if config.Callback then
					config.Callback(value)
				end
			end
		}
	end
	
	return dropdownFrame
end

function Library:AddLabel(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -10, 0, 20)
	label.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.Text = config.Text or "Label"
	label.Font = Enum.Font.SourceSans
	label.TextSize = 12
	label.BorderSizePixel = 0
	label.Parent = tabContent
	
	return label
end

function Library:Notify(config)
	-- Simple notification
	local notification = Instance.new("TextLabel")
	notification.Text = config.Title .. ": " .. (config.Description or "")
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notification.BackgroundTransparency = 0.3
	notification.Size = UDim2.new(0, 300, 0, 50)
	notification.Position = UDim2.new(0.5, -150, 0.8, 0)
	notification.TextSize = 14
	notification.Font = Enum.Font.SourceSans
	notification.Parent = ScreenGui
	
	task.delay(config.Time or 3, function()
		notification:Destroy()
	end)
end

-- Update ScrollingFrame canvas size
task.spawn(function()
	while true do
		task.wait(0.1)
		if ScrollingFrame and ScrollingFrame.Parent then
			local contentHeight = 0
			for _, child in pairs(ScrollingFrame:GetChildren()) do
				if child:IsA("Frame") then
					local childHeight = 0
					for _, element in pairs(child:GetChildren()) do
						childHeight = childHeight + element.Size.Y.Offset + 5
					end
					contentHeight = math.max(contentHeight, childHeight + 10)
				end
			end
			ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
		end
	end
end)

-- ==========================================
-- UI SETUP (Using new library)
-- ==========================================

local Window = Library

local Tabs = {
	Main = Window:CreateTab("Main"),
	Upgrades = Window:CreateTab("Upgrades"),
	Misc = Window:CreateTab("Misc"),
	Settings = Window:CreateTab("Settings"),
}

-- Create Status Label
getgenv().CurrentStatusLabel = Window:AddLabel(Tabs.Main, {Text = "Status: Idle"})

-- Toggle for Auto Farm
Window:AddToggle(Tabs.Main, {
	Text = "Auto Farm",
	Default = false,
	Callback = function(value)
		if value then AutoFarm:Start() else AutoFarm:Stop() end
	end
})

-- Continue with all other UI elements...
-- (Due to length, I'll add the remaining UI elements in the next response)

-- The rest of the script logic remains the same-- aotr
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

-- Map data and plr data don't update when I call them so I only need to call them when i need them, not in a loop

local mapData = nil

local startLoadTime = os.clock()
local isLobby = game.PlaceId == 14916516914

repeat
    task.wait(1)
    mapData = getRemote:InvokeServer("Data", "Copy")
    if not mapData then
        lastPlayerData = nil -- force refresh (bypass cache)
        GetPlayerData()
    end
    -- If we're not in the lobby, we should wait longer for mapData to populate
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

local familyRaritiesOptions = {
	"Rare",
	"Epic",
	"Legendary",
	"Mythical"
}

-- Config system for persistent dropdown state
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
		local Injuries = lp.Character:FindFirstChild("Injuries")
		if Injuries then
			for i, v in Injuries:GetChildren() do
				v:Destroy()
			end
		end
		task.wait(1)
	end
end)

function AutoFarm:Start()
	if self._running then return end
	
	if isLobby then
		return
	end

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
			if os.clock() - startTime > 10 then -- Notify every 10s if still waiting
				Library:Notify({
					Title = "TITANIC HUB",
					Description = "Still waiting for mission assets to load...",
					Time = 5
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

		-- INTERFACE.ChildAdded:Connect(function(v)
		-- 	if tonumber(v.Name) then
		-- 		v:Destroy()
		-- 	end
		-- end)
		
		-- Hash map for faster O(1) lookups
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
			if lp:GetAttribute("Cutscene") then
				task.wait()
				continue
			end

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
				-- Track mission start time
				if not self.missionStartTime then
					self.missionStartTime = os.clock()
				end
				
				local missionElapsedTime = os.clock() - self.missionStartTime
				if missionElapsedTime >= 900 then  -- 15 minutes (900 seconds)
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

			-- CRITICAL: Refresh titansFolder to see new spawns
			titansFolder = workspace:FindFirstChild("Titans") or titansFolder

			-- Map and Folder Paths
			local ws_ObjectiveFolder = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective") -- contains models of for example armored_boss or like female titan
			local rs_ObjectiveFolder = ReplicatedStorage:FindFirstChild("Objectives") -- this contains the objective intvalues (displayed in gui)
			local mapType = workspace:GetAttribute("Type") or (mapData and mapData.Map and mapData.Map.Type)

			-- Armored Raid Detection
			local isArmoredRaid = ws_ObjectiveFolder:FindFirstChild("Armored_Boss")
			local isFemaleRaid = rs_ObjectiveFolder:FindFirstChild("Defeat_Annie")
			local femaleExists = ws_ObjectiveFolder:FindFirstChild("Female_Boss")
			local attackExists = ws_ObjectiveFolder:FindFirstChild("Attack_Boss")
			local hasReinerObjective = rs_ObjectiveFolder:FindFirstChild("Defeat_Reiner")

			-- Stohess Transition Pause: Only if it IS a female raid and bosses are missing
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
				table.clear(validNapes) -- Reuse memory
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

			-- Range limit logic: Only for Phase 1 of Armored Raid
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

				-- Boss Phase logic: Skip Armored Titan ONLY during Protect phase
				if isArmoredRaid and not hasReinerObjective and tName == "Armored_Titan" then continue end
		
				if isBoss and not titanModel:GetAttribute("State") then continue end
			
				local isRoaring = isBoss and (titanModel:GetAttribute("Attack") == "Roar" or titanModel:GetAttribute("Attack") == "Berserk_Mode")

				if tName == "Attack_Titan" then attackTitanFound = true end

				local dx = referencePos.X - nape.Position.X
				local dz = referencePos.Z - nape.Position.Z
				local d = dx*dx + dz*dz
				
				-- Hysteresis: Keep target lock-on
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
			
			-- Priotize clearing regular titans near objective if range limit is on
			if useRangeLimit and closestNape then
				targetPart = closestNape
				targetIsRoaring = false
			end

			
			-- Keep last titan alive for at least 29 seconds
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
				-- Traverse up to find the root Titan Model cleanly
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
					task.wait()
					continue
				end

				-- Calculate position (You can add extra height here if needed to avoid the roar hitbox)
				-- Use Titan HRP CFrame to stay in a stable position relative to the body (stops spinning)
				local titanHRP = currentTitanModel:FindFirstChild("HumanoidRootPart")
				local targetHeightPos
				if titanHRP then
					-- This puts you at the HeightOffset above, and 30 studs BEHIND the Titan
					targetHeightPos = (titanHRP.CFrame * CFrame.new(0, getgenv().AutoFarmConfig.HeightOffset, 30)).Position
				else
					targetHeightPos = targetPart.Position + Vector3.new(0, getgenv().AutoFarmConfig.HeightOffset, 0)
				end
				
				if getgenv().AutoFarmConfig.MovementMode == "Hover" then
					local dir = targetHeightPos - rootPos
					root.AssemblyLinearVelocity = dir.Magnitude > 1 and dir.Unit * getgenv().AutoFarmConfig.MoveSpeed or V3_ZERO
				else
					root.AssemblyLinearVelocity = V3_ZERO
					root.CFrame = CFrame.new(targetHeightPos)
				end

				if not attackTitanReady then task.wait() continue end

				local dx = root.Position.X - targetPart.Position.X
				local dz = root.Position.Z - targetPart.Position.Z

				if not targetIsRoaring and (dx*dx + dz*dz) <= AttackRangeSq and (now - lastAttack) >= getgenv().AutoFarmConfig.AttackCooldown then
					lastAttack = now

					if slotData.Weapon == "Blades" then
						postRemote:FireServer("Attacks", "Slash", true)
						postRemote:FireServer("Hitboxes", "Register", targetPart, math.random(625, 850))
					else
						local isBoss = bossNames[targetPart.Parent.Parent.Parent.Name]
						local text = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
						local currentAmmo, maxAmmo = string.match(text, "(%d+)%s*/%s*(%d+)")
						currentAmmo, maxAmmo = tonumber(currentAmmo), tonumber(maxAmmo)

						if currentAmmo and currentAmmo > 0 then
							task.spawn(function()
								local function getAmmo()
									local hudText = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
									return tonumber(string.match(hudText, "(%d+)"))
								end

								local beforeAmmo = getAmmo()
								getRemote:InvokeServer("Spears", "S_Fire", tostring(currentAmmo))
								local afterAmmo = getAmmo()

								-- Retry if ammo didn't decrement (anti-lag)
								if afterAmmo and beforeAmmo and afterAmmo == beforeAmmo then
									for j = maxAmmo, 1, -1 do
										local prevAmmo = getAmmo()
										getRemote:InvokeServer("Spears", "S_Fire", tostring(j))
										local newAmmo = getAmmo()
										if newAmmo and prevAmmo and newAmmo < prevAmmo then break end
									end
								end
								
								-- Bosses take more damage / rapid fire
								local loops = isBoss and 30 or 1
								for j = 1, loops do
									postRemote:FireServer("Spears", "S_Explode", targetPart.Position)
								end
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

function AutoFarm:Stop()
	self._running = false
end

local function formatTable(tbl)
	local str = ""
	for k, v in pairs(tbl) do
		str ..= string.format("%s: %s\n", k, tostring(v))
	end
	return str ~= "" and str or "None"
end

local function formatItems(tbl)
	local str = ""
	for name, qty in pairs(tbl) do
		name = string.gsub(name, "_", " ")
		str ..= string.format("[+] %s (x%s)\n", name, qty)
	end
	return str ~= "" and str or "None"
end

local data = {
	Stats = {},
	Total = {},
	Items = {},
	Special = {}
}

local path = "./THUB/aotr/games_played.txt"
if not isfile(path) then writefile(path, "0") end
local gamesPlayed = tonumber(readfile(path))

local webhook

if rewards then
	rewards:GetPropertyChangedSignal("Visible"):Connect(function()
		if not rewards.Visible then return end

	gamesPlayed = gamesPlayed + 1
		writefile("./THUB/aotr/games_played.txt", tostring(gamesPlayed))

		local gamesUntilReturn = tonumber(readfile(returnCounterPath)) or 0
		local willReturn = false

		if getgenv().AutoReturnLobby then
	gamesUntilReturn = gamesUntilReturn + 1

			if gamesUntilReturn >= 10 then
				gamesUntilReturn = 0
				willReturn = true
			end
			
			writefile(returnCounterPath, tostring(gamesUntilReturn))
			
			if willReturn then
				task.spawn(function()
					getRemote:InvokeServer("Functions", "Teleport", "Lobby")
				end)
				
				task.wait(0.5)
				TeleportService:Teleport(14916516914, lp)
				return
			end
		elseif gamesUntilReturn >= 10 then
			-- safety reset
			gamesUntilReturn = 0
			writefile(returnCounterPath, "0")
		end
		
		if not getgenv().RewardWebhook then return end
		
		-- Wait for stats to populate properly (check for non-zero or non-placeholder)
		local start = os.clock()
		local hasData
		repeat 
			task.wait(0.1)
			hasData = false
			for _, v in ipairs(statsFrame:GetChildren()) do
				if v:IsA("Frame") and v:FindFirstChild("Amount") and v.Amount.Text ~= "0" and v.Amount.Text ~= "" then
					hasData = true
					break
				end
			end
		until hasData or (os.clock() - start) > 2

		data.Stats = {}
		data.Total = {}
		data.Items = {}
		data.Special = {}

		-- Capture Stats from UI
		for i, v in ipairs(statsFrame:GetChildren()) do
			if v:IsA("Frame") and v:FindFirstChild("Stat") and v:FindFirstChild("Amount") then
				data.Stats[string.gsub(v.Name, "_", " ")] = v.Amount.Text
			end
		end

		-- Capture Items from UI
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
					if i == "Gems" or i == "Gold" then
						data.Total[i] = v
					end
				end
			end
			if slotData.Progression then
				for i, v in pairs(slotData.Progression) do
					if i == "Prestige" or i == "Level" or i == "Streak" then
						data.Total[i] = v
					end
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
							{
							name = "Information",
							value =
								"```\n" ..
								"User: " .. lp.Name .. "\n" ..
								"Games Played: " .. tostring(gamesPlayed) .. "\n" ..
								"Executor: " .. executor ..
								"\n```",
							inline = true
							},
							{
								name = "Total Stats",
								value =
									"```\n" ..
									"Level : " .. tostring(data.Total.Level or "1") .. "\n" ..
									"Gold  : " .. tostring(data.Total.Gold or "0") .. "\n" ..
									"Gems  : " .. tostring(data.Total.Gems or "0") ..
									"\n```",
								inline = true
							},
							{
								name = "Combat",
								value = "```\n" .. formatTable(data.Stats) .. "\n```",
								inline = true
							},
							{
								name = "Rewards",
								value = "```\n" .. formatItems(data.Items) .. "\n```",
								inline = true
							},
							{
								name = "Special",
								value = "```\n" .. (hasSpecial and formatItems(data.Special) or "None") .. "\n```",
								inline = true
							}
						},

						footer = {
							text = "TITANIC HUB • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
						},

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

local Blades_Critical = {
	"1","2","3","4","5","6","7","8","9","10","11","12","13",
	"14","15","16","17","18","19","20","21","22","23","24","25"
}

local Blades_Damage = {
	"1","2","3","4","5","6","7","8","9","10","11","12","13",
	"26","27","28","29","30","31","32","33","34","35","36","37"
}

local Spears_Critical = {
	"113","114","115","116","117","118","119","120",
	"121","122","123","124","125",
	"126","127","128","129","130","131","132",
	"133","134","135","136","137"
}

local Spears_Damage = {
	"113","114","115","116","117","118","119","120",
	"121","122","123","124","125",
	"138","139","140","141","142","143","144",
	"145","146","147","148","149"
}

local Defense_Health = {
	"38","39","40","41","42","43","44","45",
	"46","47","48","49","50","51","52","53","54","55","56","57"
}

local Defense_Damage_Reduction = {
	"38","39","40","41","42","43","44","45",
	"58","59","60","61","62","63","64","65","66","67","68","69"
}

local Support_Regen = {
	"70","71","72","73","74","75","76","77","78","79","80",
	"81","82","83","84","85","86","87","88","89"
}

local Support_Cooldown_Reduction = {
	"70","71","72","73","74","75","76","77","78","79","80",
	"90","91","92","93","94","95","96","97","98"
}

local Missions = {
	["Shiganshina"] = { "Skirmish", "Breach", "Random" },
	["Trost"] = { "Skirmish", "Protect", "Random" },
	["Outskirts"] = { "Skirmish", "Escort", "Random" },
	["Giant Forest"] = { "Skirmish", "Guard", "Random" },
	["Utgard"] = { "Skirmish", "Defend", "Random" },
	["Loading Docks"] = { "Skirmish", "Stall", "Random" },
	["Stohess"] = { "Skirmish", "Random" }
}

local SkillPaths = {
	Blades = { Damage = Blades_Damage, Critical = Blades_Critical },
	Spears = { Damage = Spears_Damage, Critical = Spears_Critical },
	Defense = { Health = Defense_Health, ["Damage Reduction"] = Defense_Damage_Reduction },
	Support = { Regen = Support_Regen, ["Cooldown Reduction"] = Support_Cooldown_Reduction }
}

local function GetPerkRarity(perkName)
	return PerkRarityMap[perkName]
end

local function GetPerkXP(rarity, level)
	local base = Perk_Base_XP[rarity] or 0
	return base * math.max(level, 1)
end

local function UseButton(button)
	if not button or not button.Parent then
		return false
	end

	if not button.Visible then
		return false
	end

	if GuiService.MenuIsOpen then
		vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game) 
		vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
		task.wait(0.1)
	end

	GuiService.SelectedObject = button
	task.wait(0.05)
	vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game) -- same here
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
			
			for i, v in workspace.Climbable:GetChildren() do
				v:Destroy()
			end

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

-- Auto execute: queue once when toggled on
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
		
		if skip and skip.Visible then
			UseButton(skip:FindFirstChild("Interact"))
		end
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
		-- Toggles reference set after UI loads; guard with pcall
		pcall(function()
			if Library and Library.Toggles and Library.Toggles.AutoRollToggle then
				Library.Toggles.AutoRollToggle:SetValue(false)
			end
		end)

		if familyRarity == "mythical" and getgenv().MythicalFamilyWebhook and webhook and webhook ~= "" then
			local payload = {
				content = "MYTHICAL FAMILY ROLLED! @everyone",
				embeds = {{
					title = "Family Roll Success",
					color = 0xff0000,
					fields = {
						{
							name = "Information",
							value = "```\n" ..
									"User: " .. lp.Name .. "\n" ..
									"Family: " .. tostring(familyString) .. "\n" ..
									"\n```",
							inline = true
						}
					},
					footer = {
						text = "TITANIC HUB • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
					},
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

		pcall(function()
			Library:Notify({
				Title = "TITANIC HUB",
				Description = "Target family rolled: " .. familyString,
				Time = 5,
			})
		end)
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

	if rollButton then
		UseButton(rollButton)
	end
end

-- Weapon reload system
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

		-- 1. Refill Reserves (if empty)
		if current == 0 and autoRefillEnabled then
			local refillPart = workspace:FindFirstChild("Unclimbable")
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")

			if refillPart then
				isReloading = true
				lastReloadTime = os.clock()
				pcall(function()
					postRemote:FireServer("Attacks", "Reload", refillPart)
				end)
				task.delay(1, function() isReloading = false end)
				return
			end
		end

		-- 2. Equip Blade (if missing from hand and we have reserves)
		if blade and blade.Transparency == 1 and current > 0 then
			isReloading = true
			lastReloadTime = os.clock()
			pcall(function()
				getRemote:InvokeServer("Blades", "Reload") 
			end)
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

-- Unified high-frequency polling loop
task.spawn(function()
	while true do
		pcall(handleWeaponReload)
		task.wait(0.5)
	end
end)

-- Auto Escape listener
getgenv().AutoEscape = false
postRemote.OnClientEvent:Connect(function(...)
	local args = {...}
	if getgenv().AutoEscape and args[1] == "Titans" and args[2] == "Grab_Event" then
		game:GetService("Players").LocalPlayer.PlayerGui.Interface.Buttons.Visible = not getgenv().AutoEscape
		postRemote:FireServer("Attacks", "Slash_Escape")
	end
end)

-- ==========================================
-- SIMPLE UI LIBRARY (Replacement for Obsidian)
-- ==========================================

-- Simple UI Library for Roblox
local Library = {}
local Toggles = {}
local Options = {}

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TitanicHub"
ScreenGui.Parent = game:GetService("CoreGui")

-- Create Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Create Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "TITANIC HUB"
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = MainFrame
Title.BorderSizePixel = 0

-- Create Tab Buttons Frame
local TabFrame = Instance.new("Frame")
TabFrame.Name = "TabFrame"
TabFrame.Size = UDim2.new(0, 120, 1, -30)
TabFrame.Position = UDim2.new(0, 0, 0, 30)
TabFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TabFrame.BorderSizePixel = 0
TabFrame.Parent = MainFrame

-- Create Content Frame
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -120, 1, -30)
ContentFrame.Position = UDim2.new(0, 120, 0, 30)
ContentFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ContentFrame.BorderSizePixel = 0
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

-- Create ScrollingFrame for content
local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Name = "ScrollingFrame"
ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollingFrame.Position = UDim2.new(0, 0, 0, 0)
ScrollingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ScrollingFrame.BorderSizePixel = 0
ScrollingFrame.ScrollBarThickness = 5
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.Parent = ContentFrame

-- Create UIListLayout for ScrollingFrame
local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = ScrollingFrame

local currentTab = nil
local tabs = {}

function Library:CreateTab(name, icon)
	local tabButton = Instance.new("TextButton")
	tabButton.Name = name
	tabButton.Size = UDim2.new(1, 0, 0, 30)
	tabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabButton.Text = name
	tabButton.Font = Enum.Font.SourceSans
	tabButton.TextSize = 14
	tabButton.Parent = TabFrame
	tabButton.BorderSizePixel = 0
	
	-- Add spacing between buttons
	if #TabFrame:GetChildren() > 1 then
		tabButton.Position = UDim2.new(0, 0, 0, (#TabFrame:GetChildren() - 2) * 30)
	end
	
	local tabContent = Instance.new("Frame")
	tabContent.Name = name .. "Content"
	tabContent.Size = UDim2.new(1, -10, 1, -10)
	tabContent.Position = UDim2.new(0, 5, 0, 5)
	tabContent.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	tabContent.BorderSizePixel = 0
	tabContent.Visible = false
	tabContent.Parent = ScrollingFrame
	
	local tabData = {
		Button = tabButton,
		Content = tabContent
	}
	tabs[name] = tabData
	
	tabButton.MouseButton1Click:Connect(function()
		for _, tab in pairs(tabs) do
			tab.Content.Visible = false
			tab.Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end
		tabContent.Visible = true
		tabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		currentTab = tabContent
	end)
	
	-- Select first tab by default
	if not currentTab then
		tabContent.Visible = true
		tabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		currentTab = tabContent
	end
	
	return tabContent
end

function Library:AddToggle(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local toggleFrame = Instance.new("Frame")
	toggleFrame.Name = "Toggle"
	toggleFrame.Size = UDim2.new(1, -10, 0, 30)
	toggleFrame.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	toggleFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	toggleFrame.BorderSizePixel = 0
	toggleFrame.Parent = tabContent
	
	local toggleLabel = Instance.new("TextLabel")
	toggleLabel.Text = config.Text or "Toggle"
	toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	toggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
	toggleLabel.Position = UDim2.new(0, 5, 0, 0)
	toggleLabel.TextSize = 14
	toggleLabel.Font = Enum.Font.SourceSans
	toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
	toggleLabel.BorderSizePixel = 0
	toggleLabel.Parent = toggleFrame
	
	local toggleButton = Instance.new("TextButton")
	toggleButton.Text = ""
	toggleButton.Size = UDim2.new(0, 40, 0, 20)
	toggleButton.Position = UDim2.new(1, -45, 0.5, -10)
	toggleButton.BackgroundColor3 = config.Default and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
	toggleButton.BorderSizePixel = 0
	toggleButton.Parent = toggleFrame
	
	local isToggled = config.Default or false
	
	toggleButton.MouseButton1Click:Connect(function()
		isToggled = not isToggled
		toggleButton.BackgroundColor3 = isToggled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
		if config.Callback then
			config.Callback(isToggled)
		end
	end)
	
	-- Store toggle reference
	if config.Name then
		Toggles[config.Name] = {
			Value = isToggled,
			SetValue = function(self, value)
				isToggled = value
				toggleButton.BackgroundColor3 = isToggled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
				if config.Callback then
					config.Callback(isToggled)
				end
			end
		}
	end
	
	return toggleFrame
end

function Library:AddButton(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, -10, 0, 30)
	button.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = config.Text or "Button"
	button.Font = Enum.Font.SourceSans
	button.TextSize = 14
	button.BorderSizePixel = 0
	button.Parent = tabContent
	
	button.MouseButton1Click:Connect(function()
		if config.Callback then
			config.Callback()
		end
	end)
	
	return button
end

function Library:AddDropdown(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local dropdownFrame = Instance.new("Frame")
	dropdownFrame.Name = "Dropdown"
	dropdownFrame.Size = UDim2.new(1, -10, 0, 30)
	dropdownFrame.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	dropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dropdownFrame.BorderSizePixel = 0
	dropdownFrame.Parent = tabContent
	
	local dropdownLabel = Instance.new("TextLabel")
	dropdownLabel.Text = config.Text or "Dropdown"
	dropdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	dropdownLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dropdownLabel.Size = UDim2.new(0.4, 0, 1, 0)
	dropdownLabel.Position = UDim2.new(0, 5, 0, 0)
	dropdownLabel.TextSize = 14
	dropdownLabel.Font = Enum.Font.SourceSans
	dropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
	dropdownLabel.BorderSizePixel = 0
	dropdownLabel.Parent = dropdownFrame
	
	local dropdownButton = Instance.new("TextButton")
	dropdownButton.Text = config.Values[config.Default] or "Select..."
	dropdownButton.Size = UDim2.new(0.5, -10, 1, 0)
	dropdownButton.Position = UDim2.new(0.45, 0, 0, 0)
	dropdownButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	dropdownButton.TextSize = 14
	dropdownButton.Font = Enum.Font.SourceSans
	dropdownButton.BorderSizePixel = 0
	dropdownButton.Parent = dropdownFrame
	
	local dropdownList = Instance.new("Frame")
	dropdownList.Name = "DropdownList"
	dropdownList.Size = UDim2.new(0.5, -10, 0, 0)
	dropdownList.Position = UDim2.new(0.45, 0, 1, 0)
	dropdownList.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dropdownList.BorderSizePixel = 0
	dropdownList.Visible = false
	dropdownList.ClipsDescendants = true
	dropdownList.Parent = dropdownFrame
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Parent = dropdownList
	
	local selectedValue = config.Values[config.Default] or ""
	local isOpen = false
	
	dropdownButton.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		dropdownList.Visible = isOpen
		if isOpen then
			dropdownList.Size = UDim2.new(0.5, -10, 0, #config.Values * 25)
		else
			dropdownList.Size = UDim2.new(0.5, -10, 0, 0)
		end
	end)
	
	-- Clear existing options
	for _, child in pairs(dropdownList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	for i, value in ipairs(config.Values) do
		local option = Instance.new("TextButton")
		option.Text = value
		option.Size = UDim2.new(1, 0, 0, 25)
		option.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		option.TextColor3 = Color3.fromRGB(255, 255, 255)
		option.TextSize = 14
		option.Font = Enum.Font.SourceSans
		option.BorderSizePixel = 0
		option.Parent = dropdownList
		
		option.MouseButton1Click:Connect(function()
			selectedValue = value
			dropdownButton.Text = value
			isOpen = false
			dropdownList.Visible = false
			dropdownList.Size = UDim2.new(0.5, -10, 0, 0)
			if config.Callback then
				config.Callback(value)
			end
		end)
	end
	
	-- Store option reference
	if config.Name then
		Options[config.Name] = {
			Value = selectedValue,
			SetValue = function(value)
				selectedValue = value
				dropdownButton.Text = value
				if config.Callback then
					config.Callback(value)
				end
			end
		}
	end
	
	return dropdownFrame
end

function Library:AddLabel(tabContent, config)
	if typeof(tabContent) == "string" then
		tabContent = tabs[tabContent] and tabs[tabContent].Content
	end
	
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -10, 0, 20)
	label.Position = UDim2.new(0, 5, 0, #tabContent:GetChildren() * 30)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.Text = config.Text or "Label"
	label.Font = Enum.Font.SourceSans
	label.TextSize = 12
	label.BorderSizePixel = 0
	label.Parent = tabContent
	
	return label
end

function Library:Notify(config)
	-- Simple notification
	local notification = Instance.new("TextLabel")
	notification.Text = config.Title .. ": " .. (config.Description or "")
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notification.BackgroundTransparency = 0.3
	notification.Size = UDim2.new(0, 300, 0, 50)
	notification.Position = UDim2.new(0.5, -150, 0.8, 0)
	notification.TextSize = 14
	notification.Font = Enum.Font.SourceSans
	notification.Parent = ScreenGui
	
	task.delay(config.Time or 3, function()
		notification:Destroy()
	end)
end

-- Update ScrollingFrame canvas size
task.spawn(function()
	while true do
		task.wait(0.1)
		if ScrollingFrame and ScrollingFrame.Parent then
			local contentHeight = 0
			for _, child in pairs(ScrollingFrame:GetChildren()) do
				if child:IsA("Frame") then
					local childHeight = 0
					for _, element in pairs(child:GetChildren()) do
						childHeight = childHeight + element.Size.Y.Offset + 5
					end
					contentHeight = math.max(contentHeight, childHeight + 10)
				end
			end
			ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
		end
	end
end)

-- ==========================================
-- UI SETUP (Using new library)
-- ==========================================

local Window = Library

local Tabs = {
	Main = Window:CreateTab("Main"),
	Upgrades = Window:CreateTab("Upgrades"),
	Misc = Window:CreateTab("Misc"),
	Settings = Window:CreateTab("Settings"),
}

-- Create Status Label
getgenv().CurrentStatusLabel = Window:AddLabel(Tabs.Main, {Text = "Status: Idle"})

-- Toggle for Auto Farm
Window:AddToggle(Tabs.Main, {
	Text = "Auto Farm",
	Default = false,
	Callback = function(value)
		if value then AutoFarm:Start() else AutoFarm:Stop() end
	end
})

-- Continue with all other UI elements...
-- (Due to length, I'll add the remaining UI elements in the next response)

-- The rest of the script logic remains the same

-- Continue from where we left off...

-- ==========================================
-- MAIN TAB : Farm Groupbox (Continued)
-- ==========================================

-- Mastery Farm Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Titan Mastery Farm",
    Default = false,
    Name = "MasteryFarmToggle",
    Callback = function(value)
        getgenv().MasteryFarmConfig.Enabled = value
        if value then
            if not getgenv().AutoFarmEnabled then
                -- Start auto farm if not already running
                getgenv().AutoFarmEnabled = true
                AutoFarm:Start()
            elseif not AutoFarm._running then
                AutoFarm:Start()
            end
        end
    end
})

-- Mastery Mode Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Punching", "Skill Usage", "Both"},
    Default = 3,
    Text = "Mastery Mode",
    Name = "MasteryModeDropdown",
    Callback = function(value)
        getgenv().MasteryFarmConfig.Mode = value
    end
})

-- Movement Mode Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Hover", "Teleport"},
    Default = 1,
    Text = "Movement Mode",
    Name = "MovementModeDropdown",
    Callback = function(value)
        getgenv().AutoFarmConfig.MovementMode = value
    end
})

-- Hover Speed Slider
local hoverSpeedSlider = Instance.new("Frame")
hoverSpeedSlider.Size = UDim2.new(1, -10, 0, 40)
hoverSpeedSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
hoverSpeedSlider.BorderSizePixel = 0
hoverSpeedSlider.Parent = Tabs.Main

local hoverSpeedLabel = Instance.new("TextLabel")
hoverSpeedLabel.Text = "Hover Speed: 400"
hoverSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hoverSpeedLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
hoverSpeedLabel.Size = UDim2.new(1, 0, 0, 20)
hoverSpeedLabel.TextSize = 14
hoverSpeedLabel.Font = Enum.Font.SourceSans
hoverSpeedLabel.BorderSizePixel = 0
hoverSpeedLabel.Parent = hoverSpeedSlider

local hoverSpeedInput = Instance.new("TextBox")
hoverSpeedInput.Text = "400"
hoverSpeedInput.Size = UDim2.new(1, -10, 0, 20)
hoverSpeedInput.Position = UDim2.new(0, 5, 0, 20)
hoverSpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
hoverSpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
hoverSpeedInput.TextSize = 14
hoverSpeedInput.Font = Enum.Font.SourceSans
hoverSpeedInput.BorderSizePixel = 0
hoverSpeedInput.Parent = hoverSpeedSlider

hoverSpeedInput.FocusLost:Connect(function()
    local value = tonumber(hoverSpeedInput.Text)
    if value and value >= 100 and value <= 500 then
        getgenv().AutoFarmConfig.MoveSpeed = value
        hoverSpeedLabel.Text = "Hover Speed: " .. value
    else
        hoverSpeedInput.Text = tostring(getgenv().AutoFarmConfig.MoveSpeed)
    end
end)

-- Float Height Slider
local floatHeightSlider = Instance.new("Frame")
floatHeightSlider.Size = UDim2.new(1, -10, 0, 40)
floatHeightSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
floatHeightSlider.BorderSizePixel = 0
floatHeightSlider.Parent = Tabs.Main

local floatHeightLabel = Instance.new("TextLabel")
floatHeightLabel.Text = "Float Height: 250"
floatHeightLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
floatHeightLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
floatHeightLabel.Size = UDim2.new(1, 0, 0, 20)
floatHeightLabel.TextSize = 14
floatHeightLabel.Font = Enum.Font.SourceSans
floatHeightLabel.BorderSizePixel = 0
floatHeightLabel.Parent = floatHeightSlider

local floatHeightInput = Instance.new("TextBox")
floatHeightInput.Text = "250"
floatHeightInput.Size = UDim2.new(1, -10, 0, 20)
floatHeightInput.Position = UDim2.new(0, 5, 0, 20)
floatHeightInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
floatHeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
floatHeightInput.TextSize = 14
floatHeightInput.Font = Enum.Font.SourceSans
floatHeightInput.BorderSizePixel = 0
floatHeightInput.Parent = floatHeightSlider

floatHeightInput.FocusLost:Connect(function()
    local value = tonumber(floatHeightInput.Text)
    if value and value >= 100 and value <= 300 then
        getgenv().AutoFarmConfig.HeightOffset = value
        floatHeightLabel.Text = "Float Height: " .. value
    else
        floatHeightInput.Text = tostring(getgenv().AutoFarmConfig.HeightOffset)
    end
end)

-- Auto Reload Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Auto Reload/Refill",
    Default = false,
    Callback = function(value)
        autoReloadEnabled = value
        autoRefillEnabled = value
    end
})

-- Auto Escape Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Auto Escape",
    Default = false,
    Callback = function(value)
        getgenv().AutoEscape = value
    end
})

-- Auto Skip Cutscenes Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Auto Skip Cutscenes",
    Default = false,
    Callback = function(value)
        getgenv().AutoSkip = value
        if value then ExecuteImmediateAutomation() end
    end
})

-- Auto Retry Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Auto Retry",
    Default = false,
    Callback = function(value)
        getgenv().AutoRetry = value
        if value then ExecuteImmediateAutomation() end
    end
})

-- Auto Open Chests Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Auto Open Chests",
    Default = false,
    Callback = function(value)
        getgenv().AutoChest = value
        if value then ExecuteImmediateAutomation() end
    end
})

-- Delete Map Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Delete Map (FPS Boost)",
    Default = DropdownConfig.DeleteMap or false,
    Callback = function(value)
        getgenv().DeleteMap = value
        DropdownConfig.DeleteMap = value
        SaveConfig(DropdownConfig)
        if value then DeleteMap() end
    end
})

-- Solo Only Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Solo Only",
    Default = false,
    Callback = function(value)
        getgenv().SoloOnly = value
    end
})

-- Auto Return to Lobby Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Auto Return to Lobby",
    Default = false,
    Callback = function(value)
        getgenv().AutoReturnLobby = value
        if not value then
            pcall(function() writefile(returnCounterPath, "0") end)
        end
    end
})

Window:AddLabel(Tabs.Main, {Text = "Failsafe tps you back to lobby after a timeout."})

-- ==========================================
-- MAIN TAB : Auto Start Section
-- ==========================================

-- Return to Lobby Button
Window:AddButton(Tabs.Main, {
    Text = "Return to Lobby",
    Callback = function()
        getRemote:InvokeServer("Functions", "Teleport", "Lobby")
        TeleportService:Teleport(14916516914, lp)
    end
})

-- Join Discord Button
Window:AddButton(Tabs.Main, {
    Text = "Join Discord",
    Callback = function()
        setclipboard("https://discord.gg/N83Tn2SkJz")
        Window:Notify({
            Title = "Discord",
            Description = "Invite link copied to clipboard!",
            Time = 5
        })
    end
})

-- Auto Start Toggle
Window:AddToggle(Tabs.Main, {
    Text = "Auto Start",
    Default = false,
    Callback = function(value)
        getgenv().AutoStart = value
        
        if value and game.PlaceId == 14916516914 then
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

                    local missionType = getgenv().StartTypeDropdownValue or "Missions"
                    local selectedDifficulty
                    local mapName
                    local objective

                    if missionType == "Missions" then
                        selectedDifficulty = getgenv().MissionDifficultyValue or "Normal"
                        mapName = getgenv().MissionMapValue or "Shiganshina"
                        objective = getgenv().MissionObjectiveValue or "Skirmish"
                    else
                        selectedDifficulty = getgenv().RaidDifficultyValue or "Hard"
                        mapName = getgenv().RaidMapValue or "Trost"
                        objective = getgenv().RaidObjectiveValue or "Skirmish"
                    end

                    local created = false

                    if selectedDifficulty == "Hardest" then
                        local diffOrder = missionType == "Raids"
                            and {"Aberrant", "Severe", "Hard"}
                            or {"Aberrant", "Severe", "Hard", "Normal", "Easy"}

                        for _, diff in ipairs(diffOrder) do
                            if not getgenv().AutoStart then break end

                            getRemote:InvokeServer("S_Missions", "Create", {
                                Difficulty = diff,
                                Type = missionType,
                                Name = mapName,
                                Objective = objective
                            })

                            if getMyMission() then
                                Window:Notify({
                                    Title = "Auto Start",
                                    Description = "Selected difficulty: " .. diff,
                                    Time = 3
                                })
                                created = true
                                break
                            end
                        end
                    else
                        getRemote:InvokeServer("S_Missions", "Create", {
                            Difficulty = selectedDifficulty,
                            Type = missionType,
                            Name = mapName,
                            Objective = objective
                        })

                        if getMyMission() then created = true end
                    end

                    if not getgenv().AutoStart then break end

                    if not created then
                        retries = retries + 1
                        local backoff = math.min(retries * 2, 20)

                        if retries >= MAX_RETRIES then
                            Window:Notify({
                                Title = "Auto Start",
                                Description = "Failed after " .. MAX_RETRIES .. " retries. Stopping.",
                                Time = 10
                            })
                            getgenv().AutoStart = false
                            break
                        end

                        Window:Notify({
                            Title = "Auto Start",
                            Description = "Failed to create. Retry " .. retries .. "/" .. MAX_RETRIES .. " in " .. backoff .. "s",
                            Time = backoff
                        })
                        task.wait(backoff)
                        continue
                    end

                    retries = 0
                    task.wait(0.5)
                    getRemote:InvokeServer("S_Missions", "Start")
                    task.wait(5)
                end
            end)
        end
    end
})

-- Start Type Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Missions", "Raids"},
    Default = 1,
    Text = "Start Type",
    Name = "StartTypeDropdown",
    Callback = function(value)
        getgenv().StartTypeDropdownValue = value
    end
})

-- Mission Map Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"},
    Default = 1,
    Text = "Mission Map",
    Name = "MissionMapDropdown",
    Callback = function(value)
        getgenv().MissionMapValue = value
    end
})

-- Mission Objective Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Skirmish", "Breach", "Random"},
    Default = 1,
    Text = "Mission Objective",
    Name = "MissionObjectiveDropdown",
    Callback = function(value)
        getgenv().MissionObjectiveValue = value
    end
})

-- Mission Difficulty Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
    Default = 2,
    Text = "Mission Difficulty",
    Name = "MissionDifficultyDropdown",
    Callback = function(value)
        getgenv().MissionDifficultyValue = value
    end
})

-- Raid Map Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Trost","Shiganshina","Stohess"},
    Default = 1,
    Text = "Raid Map",
    Name = "RaidMapDropdown",
    Callback = function(value)
        getgenv().RaidMapValue = value
    end
})

-- Raid Objective Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Skirmish", "Protect", "Random"},
    Default = 1,
    Text = "Raid Objective",
    Name = "RaidObjectiveDropdown",
    Callback = function(value)
        getgenv().RaidObjectiveValue = value
    end
})

-- Raid Difficulty Dropdown
Window:AddDropdown(Tabs.Main, {
    Values = {"Hard","Severe","Aberrant","Hardest"},
    Default = 1,
    Text = "Raid Difficulty",
    Name = "RaidDifficultyDropdown",
    Callback = function(value)
        getgenv().RaidDifficultyValue = value
    end
})

Window:AddLabel(Tabs.Main, {Text = "Trost: Attack Titan | Shiganshina: Armored Titan | Stohess: Female Titan"})

-- ==========================================
-- UPGRADES TAB
-- ==========================================

-- Upgrade Gear Toggle
Window:AddToggle(Tabs.Upgrades, {
    Text = "Upgrade Gear",
    Default = false,
    Callback = function(value)
        getgenv().AutoUpgrade = value
        if value then
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
                            Window:Notify({
                                Title = "Upgraded " .. string.gsub(upg, "_", " "),
                                Description = "Level " .. tostring(lvl),
                                Time = 1.5
                            })
                            task.wait(0.3)
                        end
                    end

                    task.wait(0.5)
                end
            end)
        end
    end
})

-- Enhance Perks Toggle
Window:AddToggle(Tabs.Upgrades, {
    Text = "Enhance Perks",
    Default = false,
    Callback = function(value)
        getgenv().AutoPerk = value
        if value then
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
                for id, val in pairs(slot.Perks.Storage) do storagePerks[id] = val end

                local perkSlot = getgenv().PerkSlotValue or "Body"
                local equippedPerkId = slot.Perks.Equipped[perkSlot]
                if not equippedPerkId then
                    Window:Notify({ Title = "Auto Perk", Description = "No perk equipped in " .. tostring(perkSlot) .. " slot.", Time = 3 })
                    getgenv().AutoPerk = false
                    return
                end

                local perkData = storagePerks[equippedPerkId]
                if not perkData then
                    Window:Notify({ Title = "Auto Perk", Description = "Equipped perk data not found.", Time = 3 })
                    getgenv().AutoPerk = false
                    return
                end

                local perkName = perkData.Name
                local rarity = GetPerkRarity(perkName)
                local currentLevel = perkData.Level or 0
                local currentXP = perkData.XP or 0

                while getgenv().AutoPerk do
                    if currentLevel >= 10 then
                        Window:Notify({ Title = "Auto Perk", Description = perkName .. " is already Level 10!", Time = 3 })
                        break
                    end

                    local validPerks = {}
                    local totalXPGain = 0

                    for perkId, tbl in pairs(storagePerks) do
                        local r = GetPerkRarity(tbl.Name)
                        if perkId ~= equippedPerkId and r then
                            table.insert(validPerks, perkId)
                            totalXPGain = totalXPGain + GetPerkXP(r, math.max(tbl.Level or 0, 1))
                            if #validPerks >= 5 then break end
                        end
                    end

                    if #validPerks == 0 then
                        Window:Notify({ Title = "Auto Perk", Description = "No more food perks found.", Time = 3 })
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

                        Window:Notify({
                            Title = "Enhanced: " .. perkName,
                            Description = "Level " .. tostring(currentLevel) .. " (+" .. totalXPGain .. " XP)",
                            Time = 1
                        })
                    end

                    task.wait(0.5)
                end

                getgenv().AutoPerk = false
            end)
        end
    end
})

-- Perk Slot Dropdown
Window:AddDropdown(Tabs.Upgrades, {
    Values = {"Defense", "Support", "Family", "Extra", "Offense", "Body"},
    Default = 6,
    Text = "Perk Slot",
    Name = "PerkSlotDropdown",
    Callback = function(value)
        getgenv().PerkSlotValue = value
    end
})

Window:AddLabel(Tabs.Upgrades, {Text = "Default perk slot is Body"})

-- Auto Skill Tree Toggle
Window:AddToggle(Tabs.Upgrades, {
    Text = "Auto Skill Tree",
    Default = false,
    Callback = function(value)
        getgenv().AutoSkillTree = value
        local plrData = GetPlayerData()

        if value then
            if game.PlaceId ~= 14916516914 then return end
            if not plrData or not plrData.Slots then return end
            task.spawn(function()
                while getgenv().AutoSkillTree do
                    local slotIndex = lp:GetAttribute("Slot")
                    if not slotIndex or not plrData.Slots[slotIndex] then task.wait(1) continue end
                    local weapon = plrData.Slots[slotIndex].Weapon

                    local middle = getgenv().MiddlePathValue or "Critical"
                    local left = getgenv().LeftPathValue or "Cooldown Reduction"
                    local right = getgenv().RightPathValue or "Damage Reduction"

                    local middlePath = SkillPaths[weapon] and SkillPaths[weapon][middle]
                    local leftPath = SkillPaths.Support[left]
                    local rightPath = SkillPaths.Defense[right]

                    local paths = {}
                    local used = {}

                    local function addPath(p)
                        if not used[p] then
                            if p == "Left" and leftPath then
                                table.insert(paths, leftPath)
                            elseif p == "Middle" and middlePath then
                                table.insert(paths, middlePath)
                            elseif p == "Right" and rightPath then
                                table.insert(paths, rightPath)
                            end
                            used[p] = true
                        end
                    end

                    addPath(getgenv().Priority1Value or "Middle")
                    addPath(getgenv().Priority2Value or "Left")
                    addPath(getgenv().Priority3Value or "Right")

                    for _, path in ipairs(paths) do
                        if path then
                            for _, skillId in ipairs(path) do
                                if table.find(plrData.Slots[slotIndex].Skills.Unlocked, skillId) then continue end
                                local success = getRemote:InvokeServer("S_Equipment", "Unlock", {skillId})
                                if success then
                                    Window:Notify({
                                        Title = "Unlocked Skill",
                                        Description = "ID: " .. skillId,
                                        Time = 1
                                    })
                                end
                            end
                        end
                    end
                    task.wait()
                end
            end)
        end
    end
})

-- Middle Path Dropdown
Window:AddDropdown(Tabs.Upgrades, {
    Values = {"Damage", "Critical"},
    Default = 2,
    Text = "Middle Path",
    Name = "MiddlePathDropdown",
    Callback = function(value)
        getgenv().MiddlePathValue = value
    end
})

-- Left Path Dropdown
Window:AddDropdown(Tabs.Upgrades, {
    Values = {"Regen", "Cooldown Reduction"},
    Default = 2,
    Text = "Left Path",
    Name = "LeftPathDropdown",
    Callback = function(value)
        getgenv().LeftPathValue = value
    end
})

-- Right Path Dropdown
Window:AddDropdown(Tabs.Upgrades, {
    Values = {"Health", "Damage Reduction"},
    Default = 2,
    Text = "Right Path",
    Name = "RightPathDropdown",
    Callback = function(value)
        getgenv().RightPathValue = value
    end
})

-- Priority Dropdowns
Window:AddDropdown(Tabs.Upgrades, {
    Values = {"Left", "Middle", "Right", "None"},
    Default = 2,
    Text = "Priority 1",
    Name = "Priority1Dropdown",
    Callback = function(value)
        getgenv().Priority1Value = value
    end
})

Window:AddDropdown(Tabs.Upgrades, {
    Values = {"Left", "Middle", "Right", "None"},
    Default = 1,
    Text = "Priority 2",
    Name = "Priority2Dropdown",
    Callback = function(value)
        getgenv().Priority2Value = value
    end
})

Window:AddDropdown(Tabs.Upgrades, {
    Values = {"Left", "Middle", "Right", "None"},
    Default = 4,
    Text = "Priority 3",
    Name = "Priority3Dropdown",
    Callback = function(value)
        getgenv().Priority3Value = value
    end
})

-- ==========================================
-- MISC TAB
-- ==========================================

-- Auto Select Slot Toggle
Window:AddToggle(Tabs.Misc, {
    Text = "Auto Select Slot",
    Default = false,
    Callback = function(value)
        getgenv().AutoSlot = value
        if value and not lp:GetAttribute("Slot") then
            local selectedSlot = getgenv().SelectSlotValue or "Slot A"
            local args = { "Functions", "Select", string.sub(selectedSlot, -1) }
            task.spawn(function()
                repeat
                    getRemote:InvokeServer(unpack(args))
                    task.wait(1)
                until lp:GetAttribute("Slot") or not getgenv().AutoSlot

                getRemote:InvokeServer("Functions", "Teleport", "Lobby")
            end)
        end
    end
})

-- Select Slot Dropdown
Window:AddDropdown(Tabs.Misc, {
    Values = {"Slot A", "Slot B", "Slot C"},
    Default = 1,
    Text = "Select Slot",
    Name = "SelectSlotDropdown",
    Callback = function(value)
        getgenv().SelectSlotValue = value
    end
})

-- Auto Prestige Toggle
Window:AddToggle(Tabs.Misc, {
    Text = "Auto Prestige",
    Default = false,
    Callback = function(value)
        getgenv().AutoPrestige = value
        if value then
            if game.PlaceId ~= 14916516914 then return end
            task.spawn(function()
                local pData = GetPlayerData()
                if not pData or not pData.Slots then return end
                local slotIdx = lp:GetAttribute("Slot")
                if not slotIdx or not pData.Slots[slotIdx] then return end
                local gold = pData.Slots[slotIdx].Currency.Gold
                local requiredGold = (getgenv().PrestigeGoldValue or 0) * 1000000

                if gold < requiredGold then return end

                while getgenv().AutoPrestige do
                    for _, Memory in ipairs(Talents) do
                        if not getgenv().AutoPrestige then break end
                        local success = getRemote:InvokeServer("S_Equipment", "Prestige", {Boosts = getgenv().SelectBoostValue or "Luck Boost", Talents = Memory})
                        if success then
                            Window:Notify({
                                Title = "Successfully Prestiged",
                                Description = "Prestiged with " .. (getgenv().SelectBoostValue or "Luck Boost") .. " and " .. Memory,
                                Time = 5
                            })
                            break
                        end
                        task.wait(0.1)
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

-- Select Boost Dropdown
Window:AddDropdown(Tabs.Misc, {
    Values = {"Luck Boost", "EXP Boost", "Gold Boost"},
    Default = 1,
    Text = "Select Boost",
    Name = "SelectBoostDropdown",
    Callback = function(value)
        getgenv().SelectBoostValue = value
    end
})

-- Prestige Gold Slider
local prestigeGoldFrame = Instance.new("Frame")
prestigeGoldFrame.Size = UDim2.new(1, -10, 0, 40)
prestigeGoldFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
prestigeGoldFrame.BorderSizePixel = 0
prestigeGoldFrame.Parent = Tabs.Misc

local prestigeGoldLabel = Instance.new("TextLabel")
prestigeGoldLabel.Text = "Prestige Gold (Millions): 0"
prestigeGoldLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
prestigeGoldLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
prestigeGoldLabel.Size = UDim2.new(1, 0, 0, 20)
prestigeGoldLabel.TextSize = 14
prestigeGoldLabel.Font = Enum.Font.SourceSans
prestigeGoldLabel.BorderSizePixel = 0
prestigeGoldLabel.Parent = prestigeGoldFrame

local prestigeGoldInput = Instance.new("TextBox")
prestigeGoldInput.Text = "0"
prestigeGoldInput.Size = UDim2.new(1, -10, 0, 20)
prestigeGoldInput.Position = UDim2.new(0, 5, 0, 20)
prestigeGoldInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
prestigeGoldInput.TextColor3 = Color3.fromRGB(255, 255, 255)
prestigeGoldInput.TextSize = 14
prestigeGoldInput.Font = Enum.Font.SourceSans
prestigeGoldInput.BorderSizePixel = 0
prestigeGoldInput.Parent = prestigeGoldFrame

prestigeGoldInput.FocusLost:Connect(function()
    local value = tonumber(prestigeGoldInput.Text)
    if value and value >= 0 and value <= 100 then
        getgenv().PrestigeGoldValue = value
        prestigeGoldLabel.Text = "Prestige Gold (Millions): " .. value
    else
        prestigeGoldInput.Text = tostring(getgenv().PrestigeGoldValue or 0)
    end
end)

-- Auto Roll Toggle
Window:AddToggle(Tabs.Misc, {
    Text = "Auto Roll",
    Default = false,
    Callback = function(value)
        getgenv().AutoRoll = value
        if value then
            if game.PlaceId ~= 13379208636 then
                Window:Notify({
                    Title = "TITANIC HUB",
                    Description = "You must be in the lobby to use family roll features.",
                    Time = 3
                })
                return
            end
            task.spawn(function()
                while getgenv().AutoRoll do
                    local targets = nil
                    local rarities = nil

                    local familyText = getgenv().SelectFamilyValue
                    if familyText and familyText ~= "" then
                        targets = string.split(string.lower(familyText), ",")
                    end

                    -- Roll the family
                    roll(targets, rarities)
                    task.wait(0.25)
                end
            end)
        end
    end
})

-- Family Input
local familyInputFrame = Instance.new("Frame")
familyInputFrame.Size = UDim2.new(1, -10, 0, 40)
familyInputFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
familyInputFrame.BorderSizePixel = 0
familyInputFrame.Parent = Tabs.Misc

local familyInputLabel = Instance.new("TextLabel")
familyInputLabel.Text = "Select Families"
familyInputLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
familyInputLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
familyInputLabel.Size = UDim2.new(1, 0, 0, 20)
familyInputLabel.TextSize = 14
familyInputLabel.Font = Enum.Font.SourceSans
familyInputLabel.BorderSizePixel = 0
familyInputLabel.Parent = familyInputFrame

local familyInput = Instance.new("TextBox")
familyInput.Text = ""
familyInput.PlaceholderText = "Fritz,Yeager,etc."
familyInput.Size = UDim2.new(1, -10, 0, 20)
familyInput.Position = UDim2.new(0, 5, 0, 20)
familyInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
familyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
familyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
familyInput.TextSize = 14
familyInput.Font = Enum.Font.SourceSans
familyInput.BorderSizePixel = 0
familyInput.Parent = familyInputFrame

familyInput.FocusLost:Connect(function()
    getgenv().SelectFamilyValue = familyInput.Text
    if familyInput.Text ~= "" then
        Window:Notify({
            Title = "TITANIC HUB",
            Description = "Families selected: " .. familyInput.Text,
            Time = 2
        })
    end
end)

Window:AddLabel(Tabs.Misc, {Text = "Mythical families won't be rolled | Separate families with commas & no spaces (Fritz,Yeager)"})

-- ==========================================
-- SETTINGS TAB
-- ==========================================

-- Webhook URL Input
local webhookInputFrame = Instance.new("Frame")
webhookInputFrame.Size = UDim2.new(1, -10, 0, 40)
webhookInputFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
webhookInputFrame.BorderSizePixel = 0
webhookInputFrame.Parent = Tabs.Settings

local webhookInputLabel = Instance.new("TextLabel")
webhookInputLabel.Text = "Webhook URL"
webhookInputLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
webhookInputLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
webhookInputLabel.Size = UDim2.new(1, 0, 0, 20)
webhookInputLabel.TextSize = 14
webhookInputLabel.Font = Enum.Font.SourceSans
webhookInputLabel.BorderSizePixel = 0
webhookInputLabel.Parent = webhookInputFrame

local webhookInput = Instance.new("TextBox")
webhookInput.Text = ""
webhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
webhookInput.Size = UDim2.new(1, -10, 0, 20)
webhookInput.Position = UDim2.new(0, 5, 0, 20)
webhookInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
webhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
webhookInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
webhookInput.TextSize = 14
webhookInput.Font = Enum.Font.SourceSans
webhookInput.BorderSizePixel = 0
webhookInput.Parent = webhookInputFrame

webhookInput.FocusLost:Connect(function()
    webhook = webhookInput.Text
end)

-- Reward Webhook Toggle
Window:AddToggle(Tabs.Settings, {
    Text = "Reward Webhook",
    Default = false,
    Callback = function(value)
        getgenv().RewardWebhook = value
    end
})

-- Mythical Family Webhook Toggle
Window:AddToggle(Tabs.Settings, {
    Text = "Mythical Family Webhook",
    Default = false,
    Callback = function(value)
        getgenv().MythicalFamilyWebhook = value
    end
})

-- Disable 3D Rendering Toggle
Window:AddToggle(Tabs.Settings, {
    Text = "Disable 3D Rendering (FPS Boost)",
    Default = false,
    Callback = function(value)
        RunService:Set3dRenderingEnabled(not value)
    end
})

-- ==========================================
-- CLEANUP AND FINAL SETUP
-- ==========================================

-- Auto execution loop
task.spawn(function()
    while true do
        local success, err = pcall(ExecuteImmediateAutomation)
        task.wait(0.5)
    end
end)

-- Anti-AFK
local virtualUser = game:GetService("VirtualUser")
lp.Idled:Connect(function()
    virtualUser:CaptureController()
    virtualUser:ClickButton2(Vector2.new())
end)

-- Auto Hide Logic (if previously enabled)
task.spawn(function()
    task.wait(0.5)
    if getgenv().DeleteMap then DeleteMap() end
    
    -- Check if we should auto-hide
    local autoHideEnabled = getgenv().AutoHideGUI
    if autoHideEnabled then
        MainFrame.Visible = false
        Window:Notify({
            Title = "TITANIC HUB",
            Description = "Auto Hid GUI - Press RightControl to toggle",
            Time = 2
        })
    end
    
    -- Toggle GUI visibility with RightControl
    game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightControl then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)
end)

-- Add close button
local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -30, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 18
closeButton.Font = Enum.Font.SourceSansBold
closeButton.BorderSizePixel = 0
closeButton.Parent = MainFrame

closeButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Make sure the script works with the original Library references
Library.Toggles = Toggles
Library.Options = Options

-- Initialize default values
getgenv().StartTypeDropdownValue = "Missions"
getgenv().MissionMapValue = "Shiganshina"
getgenv().MissionObjectiveValue = "Skirmish"
getgenv().MissionDifficultyValue = "Normal"
getgenv().RaidMapValue = "Trost"
getgenv().RaidObjectiveValue = "Skirmish"
getgenv().RaidDifficultyValue = "Hard"
getgenv().PerkSlotValue = "Body"
getgenv().MiddlePathValue = "Critical"
getgenv().LeftPathValue = "Cooldown Reduction"
getgenv().RightPathValue = "Damage Reduction"
getgenv().Priority1Value = "Middle"
getgenv().Priority2Value = "Left"
getgenv().Priority3Value = "None"
getgenv().SelectSlotValue = "Slot A"
getgenv().SelectBoostValue = "Luck Boost"
getgenv().PrestigeGoldValue = 0
getgenv().AutoFarmEnabled = false
getgenv().AutoHideGUI = false

print("TITANIC HUB loaded successfully!")
Window:Notify({
    Title = "TITANIC HUB",
    Description = "Loaded successfully! Press RightControl to toggle GUI.",
    Time = 5
})
