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
-- WIND UI LIBRARY LOAD
-- ==========================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/main_example.lua"))()

local Window = Library:CreateWindow({
	Title = "TITANIC HUB",
	Subtitle = "AOT:R | Free",
	Size = UDim2.fromOffset(580, 460),
	Center = true,
	Resizable = true,
	AutoShow = true,
	ShowCustomCursor = true,
})

local Tabs = {
	Main = Window:AddTab("Main", "house"),
	Upgrades = Window:AddTab("Upgrades", "trending-up"),
	Misc = Window:AddTab("Misc", "boxes"),
	Settings = Window:AddTab("Settings", "settings"),
}

local MainGroup = Tabs.Main:AddLeftGroupbox("Farm")
local AutoStartGroup = Tabs.Main:AddRightGroupbox("Auto Start")

local UpgradesGroup = Tabs.Upgrades:AddLeftGroupbox("Upgrades")
local SkillTreeGroup = Tabs.Upgrades:AddRightGroupbox("Skill Tree")

local SlotGroup = Tabs.Misc:AddLeftGroupbox("Slot")
local FamilyRollGroup = Tabs.Misc:AddRightGroupbox("Family Roll")

local WebhookGroup = Tabs.Misc:AddLeftGroupbox("Webhook")
local SettingsGroup = Tabs.Misc:AddRightGroupbox("Settings")

-- ==========================================
-- MAIN TAB : Farm Groupbox
-- ==========================================
getgenv().CurrentStatusLabel = MainGroup:AddLabel("Status: Idle")

MainGroup:AddToggle("AutoKillToggle", {
	Text = "Auto Farm",
	Default = false,
})
Library.Toggles.AutoKillToggle:OnChanged(function()
	if Library.Toggles.AutoKillToggle.Value then AutoFarm:Start() else AutoFarm:Stop() end
end)

MainGroup:AddToggle("MasteryFarmToggle", {
	Text = "Titan Mastery Farm",
	Default = false,
})
Library.Toggles.MasteryFarmToggle:OnChanged(function()
	getgenv().MasteryFarmConfig.Enabled = Library.Toggles.MasteryFarmToggle.Value
	if Library.Toggles.MasteryFarmToggle.Value then
		if not Library.Toggles.AutoKillToggle.Value then
			Library.Toggles.AutoKillToggle:SetValue(true)
		elseif not AutoFarm._running then
			AutoFarm:Start()
		end
	end
end)

MainGroup:AddDropdown("MasteryModeDropdown", {
	Values = {"Punching", "Skill Usage", "Both"},
	Default = "Both",
	Multi = false,
	Text = "Mastery Mode",
})
Library.Options.MasteryModeDropdown:OnChanged(function()
	getgenv().MasteryFarmConfig.Mode = Library.Options.MasteryModeDropdown.Value
end)

MainGroup:AddDropdown("MovementModeDropdown", {
	Values = {"Hover", "Teleport"},
	Default = "Hover",
	Multi = false,
	Text = "Movement Mode",
})
Library.Options.MovementModeDropdown:OnChanged(function()
	getgenv().AutoFarmConfig.MovementMode = Library.Options.MovementModeDropdown.Value
end)

MainGroup:AddDropdown("FarmOptionsDropdown", {
	Values = {"Auto Execute", "Failsafe", "Open Second Chest"},
	Default = {},
	Multi = true,
	Text = "Farm Options",
})
Library.Options.FarmOptionsDropdown:OnChanged(function()
	local vals = Library.Options.FarmOptionsDropdown.Value
	getgenv().AutoFailsafe = vals["Failsafe"] or false
	getgenv().AutoExecute = vals["Auto Execute"] or false
	getgenv().OpenSecondChest = vals["Open Second Chest"] or false
	if getgenv().AutoExecute then setupAutoExecute() end
end)

MainGroup:AddSlider("HoverSpeedSlider", {
	Text = "Hover Speed",
	Default = 400,
	Min = 100,
	Max = 500,
	Rounding = 0,
})
Library.Options.HoverSpeedSlider:OnChanged(function()
	getgenv().AutoFarmConfig.MoveSpeed = Library.Options.HoverSpeedSlider.Value
end)


MainGroup:AddSlider("FloatHeightSlider", {

	Text = "Float Height",
	Default = 250,
	Min = 100,
	Max = 300,
	Rounding = 0,
})
Library.Options.FloatHeightSlider:OnChanged(function()
	getgenv().AutoFarmConfig.HeightOffset = Library.Options.FloatHeightSlider.Value
end)


MainGroup:AddToggle("AutoReloadToggle", {
	Text = "Auto Reload/Refill",
	Default = false,
})
Library.Toggles.AutoReloadToggle:OnChanged(function()
	autoReloadEnabled = Library.Toggles.AutoReloadToggle.Value
	autoRefillEnabled = Library.Toggles.AutoReloadToggle.Value
end)

MainGroup:AddToggle("AutoEscapeToggle", {
	Text = "Auto Escape",
	Default = false,
})
Library.Toggles.AutoEscapeToggle:OnChanged(function()
	getgenv().AutoEscape = Library.Toggles.AutoEscapeToggle.Value
end)

MainGroup:AddToggle("AutoSkipToggle", {
	Text = "Auto Skip Cutscenes",
	Default = false,
})
Library.Toggles.AutoSkipToggle:OnChanged(function()
	getgenv().AutoSkip = Library.Toggles.AutoSkipToggle.Value
	if getgenv().AutoSkip then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("AutoRetryToggle", {
	Text = "Auto Retry",
	Default = false,
})
Library.Toggles.AutoRetryToggle:OnChanged(function()
	getgenv().AutoRetry = Library.Toggles.AutoRetryToggle.Value
	if getgenv().AutoRetry then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("AutoChestToggle", {
	Text = "Auto Open Chests",
	Default = false,
})
Library.Toggles.AutoChestToggle:OnChanged(function()
	getgenv().AutoChest = Library.Toggles.AutoChestToggle.Value
	if getgenv().AutoChest then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("DeleteMapToggle", {
	Text = "Delete Map (FPS Boost)",
	Default = DropdownConfig.DeleteMap or false,
})
Library.Toggles.DeleteMapToggle:OnChanged(function()
	getgenv().DeleteMap = Library.Toggles.DeleteMapToggle.Value
	DropdownConfig.DeleteMap = getgenv().DeleteMap
	SaveConfig(DropdownConfig)
	if getgenv().DeleteMap then DeleteMap() end
end)
MainGroup:AddToggle("SoloOnlyToggle", {
	Text = "Solo Only",
	Default = false,
})
Library.Toggles.SoloOnlyToggle:OnChanged(function()
	getgenv().SoloOnly = Library.Toggles.SoloOnlyToggle.Value
end)

MainGroup:AddToggle("AutoReturnLobbyToggle", {
	Text = "Auto Return to Lobby",
	Default = false,
})
Library.Toggles.AutoReturnLobbyToggle:OnChanged(function()
	getgenv().AutoReturnLobby = Library.Toggles.AutoReturnLobbyToggle.Value
	if not getgenv().AutoReturnLobby then
		pcall(function() writefile(returnCounterPath, "0") end)
	end
end)

MainGroup:AddLabel("Failsafe tps you back to lobby\nafter a timeout.")

-- ==========================================
-- MAIN TAB : Auto Start Groupbox
-- ==========================================

AutoStartGroup:AddButton({
	Text = "Return to Lobby",
	Func = function()
		getRemote:InvokeServer("Functions", "Teleport", "Lobby")
		TeleportService:Teleport(14916516914, lp)
	end,
})

AutoStartGroup:AddButton({
	Text = "Join Discord",
	Func = function()
		setclipboard("https://discord.gg/N83Tn2SkJz")
		Library:Notify({
			Title = "Discord",
			Description = "Invite link copied to clipboard!",
			Time = 5
		})
	end,
})

AutoStartGroup:AddToggle("AutoStartToggle", {
	Text = "Auto Start",
	Default = false,
})
Library.Toggles.AutoStartToggle:OnChanged(function()
	getgenv().AutoStart = Library.Toggles.AutoStartToggle.Value

	if getgenv().AutoStart and game.PlaceId == 14916516914 then
		task.spawn(function()
			local MAX_RETRIES = 10
			local retries = 0

			local function getMyMission()
				local start = os.clock()
				while (os.clock() - start) < 2 do -- 2 second timeout for replication
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

				local missionType = Library.Options.StartTypeDropdown.Value
				local selectedDifficulty
				local mapName
				local objective

				if missionType == "Missions" then
					selectedDifficulty = Library.Options.MissionDifficultyDropdown.Value
					mapName = Library.Options.MissionMapDropdown.Value
					objective = Library.Options.MissionObjectiveDropdown.Value
				else
					selectedDifficulty = Library.Options.RaidDifficultyDropdown.Value
					mapName = Library.Options.RaidMapDropdown.Value
					objective = Library.Options.RaidObjectiveDropdown.Value
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
							Library:Notify({
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
						Library:Notify({
							Title = "Auto Start",
							Description = "Failed after " .. MAX_RETRIES .. " retries. Stopping.",
							Time = 10
						})
						getgenv().AutoStart = false
						Library.Toggles.AutoStartToggle:SetValue(false)
						break
					end

					Library:Notify({
						Title = "Auto Start",
						Description = "Failed to create. Retry " .. retries .. "/" .. MAX_RETRIES .. " in " .. backoff .. "s",
						Time = backoff
					})
					task.wait(backoff)
					continue
				end

				retries = 0

				local activeMods = {}
				if Library.Options.ModifiersDropdown.Value then
					for modName, isActive in pairs(Library.Options.ModifiersDropdown.Value) do
						if isActive then table.insert(activeMods, modName) end
					end
				end

				if #activeMods > 0 then
					for _, modifier in ipairs(activeMods) do
						getRemote:InvokeServer("S_Missions", "Modify", modifier)
					end
				end

				task.wait(0.5)
				getRemote:InvokeServer("S_Missions", "Start")

				task.wait(5)
			end
		end)
	end
end)

AutoStartGroup:AddDropdown("StartTypeDropdown", {
	Values = {"Missions", "Raids"},
	Default = DropdownConfig._lastType or "Missions",
	Multi = false,
	Text = "Type",
})
Library.Options.StartTypeDropdown:OnChanged(function()
	local Value = Library.Options.StartTypeDropdown.Value
	if not Value then return end
	
	DropdownConfig._lastType = Value
	SaveConfig(DropdownConfig)

	local isMission = Value == "Missions"
	Library.Options.MissionMapDropdown:SetVisible(isMission)
	Library.Options.MissionObjectiveDropdown:SetVisible(isMission)
	Library.Options.MissionDifficultyDropdown:SetVisible(isMission)

	Library.Options.RaidMapDropdown:SetVisible(not isMission)
	Library.Options.RaidObjectiveDropdown:SetVisible(not isMission)
	Library.Options.RaidDifficultyDropdown:SetVisible(not isMission)
end)

AutoStartGroup:AddDropdown("MissionMapDropdown", {
	Values = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"},
	Default = DropdownConfig.Missions and DropdownConfig.Missions.map or "Shiganshina",
	Multi = false,
	Text = "Mission Map",
})
Library.Options.MissionMapDropdown:OnChanged(function()
	local Value = Library.Options.MissionMapDropdown.Value
	if not Value then return end
	Library.Options.MissionObjectiveDropdown:SetValues(Missions[Value] or {})
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.map = Value
	SaveConfig(DropdownConfig)
end)

local initMissionMap = DropdownConfig.Missions and DropdownConfig.Missions.map or "Shiganshina"
local initMissionObjVals = Missions[initMissionMap] or {}
local initMissionObjDef = DropdownConfig.Missions and DropdownConfig.Missions.objective or initMissionObjVals[1]

AutoStartGroup:AddDropdown("MissionObjectiveDropdown", {
	Values = initMissionObjVals,
	Default = initMissionObjDef,
	Multi = false,
	Text = "Mission Objective",
})
Library.Options.MissionObjectiveDropdown:OnChanged(function()
	local Value = Library.Options.MissionObjectiveDropdown.Value
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.objective = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDropdown("MissionDifficultyDropdown", {
	Values = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
	Default = DropdownConfig.Missions and DropdownConfig.Missions.difficulty or "Normal",
	Multi = false,
	Text = "Mission Difficulty",
})
Library.Options.MissionDifficultyDropdown:OnChanged(function()
	local Value = Library.Options.MissionDifficultyDropdown.Value
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.difficulty = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDivider()

AutoStartGroup:AddDropdown("RaidMapDropdown", {
	Values = {"Trost","Shiganshina","Stohess"},
	Default = DropdownConfig.Raids and DropdownConfig.Raids.map or "Trost",
	Multi = false,
	Text = "Raid Map",
})
Library.Options.RaidMapDropdown:OnChanged(function()
	local Value = Library.Options.RaidMapDropdown.Value
	if not Value then return end
	Library.Options.RaidObjectiveDropdown:SetValues(Missions[Value] or {})
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.map = Value
	SaveConfig(DropdownConfig)
end)

local initRaidMap = DropdownConfig.Raids and DropdownConfig.Raids.map or "Trost"
local initRaidObjVals = Missions[initRaidMap] or {}
local initRaidObjDef = DropdownConfig.Raids and DropdownConfig.Raids.objective or initRaidObjVals[1]

AutoStartGroup:AddDropdown("RaidObjectiveDropdown", {
	Values = initRaidObjVals,
	Default = initRaidObjDef,
	Multi = false,
	Text = "Raid Objective",
})
Library.Options.RaidObjectiveDropdown:OnChanged(function()
	local Value = Library.Options.RaidObjectiveDropdown.Value
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.objective = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDropdown("RaidDifficultyDropdown", {
	Values = {"Hard","Severe","Aberrant","Hardest"},
	Default = DropdownConfig.Raids and DropdownConfig.Raids.difficulty or "Hard",
	Multi = false,
	Text = "Raid Difficulty",
})
Library.Options.RaidDifficultyDropdown:OnChanged(function()
	local Value = Library.Options.RaidDifficultyDropdown.Value
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.difficulty = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddLabel("Trost: Attack Titan\nShiganshina: Armored Titan\nStohess: Female Titan", true)

AutoStartGroup:AddDivider()

AutoStartGroup:AddDropdown("ModifiersDropdown", {
	Values = {"No Perks","No Skills","No Talents","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"},
	Default = {},
	Multi = true,
	Text = "Modifiers",
})

-- Trigger type initialization
task.defer(function()
	task.wait(0.2)
	local savedType = DropdownConfig._lastType or "Missions"
	Library.Options.StartTypeDropdown:SetValue(savedType)
end)

-- ==========================================
-- UPGRADES TAB : Upgrades Groupbox
-- ==========================================

UpgradesGroup:AddToggle("AutoUpgradeToggle", {
	Text = "Upgrade Gear",
	Default = false,
})
Library.Toggles.AutoUpgradeToggle:OnChanged(function()
	getgenv().AutoUpgrade = Library.Toggles.AutoUpgradeToggle.Value
	if getgenv().AutoUpgrade then
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
						Library:Notify({
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
end)

UpgradesGroup:AddToggle("AutoEnhanceToggle", {
	Text = "Enhance Perks",
	Default = false,
})
Library.Toggles.AutoEnhanceToggle:OnChanged(function()
	getgenv().AutoPerk = Library.Toggles.AutoEnhanceToggle.Value
	if getgenv().AutoPerk then
		if game.PlaceId ~= 14916516914 then return end
		task.spawn(function()
			local plrData = GetPlayerData()
			if not plrData or not plrData.Slots then return end
			local slotIndex = lp:GetAttribute("Slot")
			if not slotIndex or not plrData.Slots[slotIndex] then
				getgenv().AutoPerk = false
				Library.Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local slot = plrData.Slots[slotIndex]
			local storagePerks = {}
			for id, val in pairs(slot.Perks.Storage) do storagePerks[id] = val end

			local perkSlot = Library.Options.PerkSlotDropdown.Value
			local equippedPerkId = slot.Perks.Equipped[perkSlot]
			if not equippedPerkId then
				Library:Notify({ Title = "Auto Perk", Description = "No perk equipped in " .. tostring(perkSlot) .. " slot.", Time = 3 })
				getgenv().AutoPerk = false
				Library.Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local perkData = storagePerks[equippedPerkId]
			if not perkData then
				Library:Notify({ Title = "Auto Perk", Description = "Equipped perk data not found.", Time = 3 })
				getgenv().AutoPerk = false
				Library.Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local perkName = perkData.Name
			local rarity = GetPerkRarity(perkName)
			local currentLevel = perkData.Level or 0
			local currentXP = perkData.XP or 0

			while getgenv().AutoPerk do
				if currentLevel >= 10 then
					Library:Notify({ Title = "Auto Perk", Description = perkName .. " is already Level 10!", Time = 3 })
					break
				end

				local selectedRarities = Library.Options.SelectPerksDropdown.Value
				local rarityPerks = {}
				if selectedRarities then
					for r, isActive in pairs(selectedRarities) do
						if isActive then rarityPerks[r] = true end
					end
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
					Library:Notify({ Title = "Auto Perk", Description = "No more food perks found.", Time = 3 })
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

					Library:Notify({
						Title = "Enhanced: " .. perkName,
						Description = "Level " .. tostring(currentLevel) .. " (+" .. totalXPGain .. " XP)",
						Time = 1
					})
				else
					continue
				end

				task.wait(0.5)
			end

			getgenv().AutoPerk = false
			Library.Toggles.AutoEnhanceToggle:SetValue(false)
		end)
	end
end)

UpgradesGroup:AddDropdown("PerkSlotDropdown", {
	Values = {"Defense", "Support", "Family", "Extra", "Offense", "Body"},
	Default = "Body",
	Multi = false,
	Text = "Perk Slot",
})

UpgradesGroup:AddDropdown("SelectPerksDropdown", {
	Values = {"Common", "Rare", "Epic", "Legendary"},
	Default = {},
	Multi = true,
	Text = "Perks to use (Food)",
})

UpgradesGroup:AddLabel("Default perk slot is Body")

-- ==========================================
-- UPGRADES TAB : Skill Tree Groupbox
-- ==========================================

SkillTreeGroup:AddToggle("AutoSkillTree", {
	Text = "Auto Skill Tree",
	Default = false,
})
Library.Toggles.AutoSkillTree:OnChanged(function()
	getgenv().AutoSkillTree = Library.Toggles.AutoSkillTree.Value
	local plrData = GetPlayerData()

	if getgenv().AutoSkillTree then
		if game.PlaceId ~= 14916516914 then return end
		if not plrData or not plrData.Slots then return end
		task.spawn(function()
			while getgenv().AutoSkillTree do
				local slotIndex = lp:GetAttribute("Slot")
				if not slotIndex or not plrData.Slots[slotIndex] then task.wait(1) continue end
				local weapon = plrData.Slots[slotIndex].Weapon

				local middle = Library.Options.MiddlePathDropdown.Value
				local left = Library.Options.LeftPathDropdown.Value
				local right = Library.Options.RightPathDropdown.Value

				local middlePath = SkillPaths[weapon] and SkillPaths[weapon][middle]
				local leftPath = SkillPaths.Support[left]
				local rightPath = SkillPaths.Defense[right]

				local p1 = Library.Options.Priority1Dropdown.Value or "Middle"
				local p2 = Library.Options.Priority2Dropdown.Value or "Left"
				local p3 = Library.Options.Priority3Dropdown.Value or "None"

				local pathMap = { Left = leftPath, Middle = middlePath, Right = rightPath }
				local paths = {}
				local used = {}

				local function addPath(p)
					if not used[p] and pathMap[p] then
						table.insert(paths, pathMap[p])
						used[p] = true
					end
				end

				addPath(p1)
				addPath(p2)
				addPath(p3)

				for _, path in ipairs(paths) do
					if path then
						for _, skillId in ipairs(path) do
							if table.find(plrData.Slots[slotIndex].Skills.Unlocked, skillId) then continue end
							local success = getRemote:InvokeServer("S_Equipment", "Unlock", {skillId})
							if success then
								Library:Notify({
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
end)

SkillTreeGroup:AddDropdown("MiddlePathDropdown", {
	Values = {"Damage", "Critical"},
	Default = "Critical",
	Multi = false,
	Text = "Middle Path",
})

SkillTreeGroup:AddDropdown("LeftPathDropdown", {
	Values = {"Regen", "Cooldown Reduction"},
	Default = "Cooldown Reduction",
	Multi = false,
	Text = "Left Path",
})

SkillTreeGroup:AddDropdown("RightPathDropdown", {
	Values = {"Health", "Damage Reduction"},
	Default = "Damage Reduction",
	Multi = false,
	Text = "Right Path",
})

SkillTreeGroup:AddDropdown("Priority1Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = "Middle",
	Multi = false,
	Text = "Priority 1",
})

SkillTreeGroup:AddDropdown("Priority2Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = "Left",
	Multi = false,
	Text = "Priority 2",
})

SkillTreeGroup:AddDropdown("Priority3Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = "None",
	Multi = false,
	Text = "Priority 3",
})

-- ==========================================
-- MISC TAB : Slot Groupbox
-- ==========================================

SlotGroup:AddToggle("AutoSelectSlot", {
	Text = "Auto Select Slot",
	Default = false,
})
Library.Toggles.AutoSelectSlot:OnChanged(function()
	getgenv().AutoSlot = Library.Toggles.AutoSelectSlot.Value
	if getgenv().AutoSlot and not lp:GetAttribute("Slot") then
		local selectedSlot = Library.Options.SelectSlotDropdown.Value
		local args = { "Functions", "Select", string.sub(selectedSlot, -1) }
		task.spawn(function()
			repeat
				getRemote:InvokeServer(unpack(args))
				task.wait(1)
			until lp:GetAttribute("Slot") or not getgenv().AutoSlot

			getRemote:InvokeServer("Functions", "Teleport", "Lobby")
		end)
	end
end)

SlotGroup:AddDropdown("SelectSlotDropdown", {
	Values = {"Slot A", "Slot B", "Slot C"},
	Default = "Slot A",
	Multi = false,
	Text = "Select Slot",
})

SlotGroup:AddToggle("AutoPrestigeToggle", {
	Text = "Auto Prestige",
	Default = false,
})
Library.Toggles.AutoPrestigeToggle:OnChanged(function()
	getgenv().AutoPrestige = Library.Toggles.AutoPrestigeToggle.Value
	if getgenv().AutoPrestige then
		if game.PlaceId ~= 14916516914 then return end
		task.spawn(function()
			local pData = GetPlayerData()
			if not pData or not pData.Slots then return end
			local slotIdx = lp:GetAttribute("Slot")
			if not slotIdx or not pData.Slots[slotIdx] then return end
			local gold = pData.Slots[slotIdx].Currency.Gold
			local requiredGold = Library.Options.PrestigeGoldSlider.Value * 1000000

			if gold < requiredGold then return end

			while getgenv().AutoPrestige do
				for _, Memory in ipairs(Talents) do
					if not getgenv().AutoPrestige then break end
					local success = getRemote:InvokeServer("S_Equipment", "Prestige", {Boosts = Library.Options.SelectBoostDropdown.Value, Talents = Memory})
					if success then
						Library:Notify({
							Title = "Successfully Prestiged",
							Description = "Prestiged with " .. Library.Options.SelectBoostDropdown.Value .. " and " .. Memory,
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
end)

SlotGroup:AddDropdown("SelectBoostDropdown", {
	Values = {"Luck Boost", "EXP Boost", "Gold Boost"},
	Default = "Luck Boost",
	Multi = false,
	Text = "Select Boost",
})

SlotGroup:AddSlider("PrestigeGoldSlider", {
	Text = "Prestige Gold (in millions)",
	Default = 0,
	Min = 0,
	Max = 100,
	Rounding = 0,
})

-- ==========================================
-- MISC TAB : Family Roll Groupbox
-- ==========================================

FamilyRollGroup:AddToggle("AutoRollToggle", {
	Text = "Auto Roll",
	Default = false,
})
Library.Toggles.AutoRollToggle:OnChanged(function()
	getgenv().AutoRoll = Library.Toggles.AutoRollToggle.Value
	if getgenv().AutoRoll then
		if game.PlaceId ~= 13379208636 then
			Library:Notify({
				Title = "TITANIC HUB",
				Description = "You must be in the lobby to use family roll features.",
				Time = 3
			})
			return
		end
		task.spawn(function()
			while getgenv().AutoRoll do
				local targets, rarities

				local text = Library.Options.SelectFamily.Value
				if text and text ~= "" then
					text = string.lower(text)
					targets = string.split(text, ",")
				end

				local raritySelected = Library.Options.SelectFamilyRarity.Value
				if raritySelected then
					rarities = {}
					for rarityName, isEnabled in pairs(raritySelected) do
						if isEnabled then
							table.insert(rarities, string.lower(rarityName))
						end
					end
				end
				
				roll(targets, rarities)
				task.wait(0.25)
			end
		end)
	end
end)

FamilyRollGroup:AddInput("SelectFamily", {
	Default = "",
	Text = "Select Families",
	Placeholder = "Fritz,Yeager,etc.",
})
Library.Options.SelectFamily:OnChanged(function()
	if Library.Options.SelectFamily.Value ~= "" then
		Library:Notify({
			Title = "TITANIC HUB",
			Description = "Families selected: " .. Library.Options.SelectFamily.Value,
			Time = 2
		})
	end
end)

FamilyRollGroup:AddDropdown("SelectFamilyRarity", {
	Values = familyRaritiesOptions,
	Default = {},
	Multi = true,
	Text = "Stop At",
})

FamilyRollGroup:AddLabel("Mythical families won't be rolled\nSeparate families with commas & no spaces (Fritz,Yeager)", true)

-- ==========================================
-- SETTINGS TAB : Webhook & UI Groupbox
-- ==========================================

WebhookGroup:AddToggle("ToggleRewardWebhook", {
	Text = "Reward Webhook",
	Default = false,
})
Library.Toggles.ToggleRewardWebhook:OnChanged(function()
	getgenv().RewardWebhook = Library.Toggles.ToggleRewardWebhook.Value
end)

WebhookGroup:AddToggle("ToggleMythicalFamilyWebhook", {
	Text = "Mythical Family Webhook",
	Default = false,
})
Library.Toggles.ToggleMythicalFamilyWebhook:OnChanged(function()
	getgenv().MythicalFamilyWebhook = Library.Toggles.ToggleMythicalFamilyWebhook.Value
end)

WebhookGroup:AddInput("WebhookUrl", {
	Default = "",
	Text = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
})
Library.Options.WebhookUrl:OnChanged(function()
	webhook = Library.Options.WebhookUrl.Value
end)

SettingsGroup:AddToggle("AutoHideToggle", {
	Text = "Auto Hide GUI",
	Default = false,
})

SettingsGroup:AddToggle("Disable3DRendering", {
	Text = "Disable 3D Rendering (FPS Boost)",
	Default = false,
})
Library.Toggles.Disable3DRendering:OnChanged(function()
	RunService:Set3dRenderingEnabled(not Library.Toggles.Disable3DRendering.Value)
end)

SettingsGroup:AddLabel("Menu toggle"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Library.Options.MenuKeybind

-- Auto Hide Logic
task.spawn(function()
	task.wait(0.5) -- Wait for config load
	if getgenv().DeleteMap then DeleteMap() end
	if Library.Toggles.AutoHideToggle.Value then
		Library:Close()
		Library:Notify({
			Title = "TITANIC HUB",
			Description = "Auto Hid GUI",
			Time = 2
		})
	end
end)

Library:OnUnload(function()
	Library.Unloaded = true
end)

task.spawn(function()
	while not Library.Unloaded do
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
