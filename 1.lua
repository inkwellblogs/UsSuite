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
if not isfolder("./UsSuite") then makefolder("./UsSuite") end
if not isfolder("./UsSuite/aotr") then makefolder("./UsSuite/aotr") end

local ConfigFile = "./UsSuite/aotr/dropdown_config.json"
local returnCounterPath = "./UsSuite/aotr/return_lobby_counter.txt"
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
					Title = "Us Suite",
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

local path = "./UsSuite/aotr/games_played.txt"
if not isfile(path) then writefile(path, "0") end
local gamesPlayed = tonumber(readfile(path))

local webhook

if rewards then
	rewards:GetPropertyChangedSignal("Visible"):Connect(function()
		if not rewards.Visible then return end

	gamesPlayed = gamesPlayed + 1
		writefile("./UsSuite/aotr/games_played.txt", tostring(gamesPlayed))

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
						title = "Us Rewards",
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
							text = "Us Suite • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
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
						text = "Us Suite • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
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
				Title = "Us Suite",
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


-- ============================================================
--   TITANIC HUB  |  by ZEKE
--   Custom ScreenGui  —  replaces Obsidian UI Library
-- ============================================================

local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

-- ── Colour palette ──────────────────────────────────────────
local C = {
    BG0    = Color3.fromRGB(10,  11,  18),
    BG1    = Color3.fromRGB(15,  17,  28),
    BG2    = Color3.fromRGB(20,  23,  38),
    BG3    = Color3.fromRGB(26,  30,  50),
    BG4    = Color3.fromRGB(32,  37,  62),
    ACC    = Color3.fromRGB(108, 60,  255),
    ACC2   = Color3.fromRGB(139, 92,  246),
    ACC3   = Color3.fromRGB(167,139,  250),
    GREEN  = Color3.fromRGB(0,  200, 150),
    GOLD   = Color3.fromRGB(245,158,  11),
    CYAN   = Color3.fromRGB(34, 211, 238),
    RED    = Color3.fromRGB(239, 68,  68),
    WHITE  = Color3.fromRGB(226,232, 240),
    MUTED  = Color3.fromRGB(148,163, 184),
    DIM    = Color3.fromRGB(100,116, 139),
    BOR    = Color3.fromRGB(42,  47,  70),
    BOR2   = Color3.fromRGB(58,  63,  92),
}

-- ── Helpers ─────────────────────────────────────────────────
local function New(cls, p)
    local o = Instance.new(cls)
    for k,v in pairs(p) do
        if k ~= "Parent" then o[k]=v end
    end
    if p.Parent then o.Parent = p.Parent end
    return o
end
local function Corner(r,par)  New("UICorner",{CornerRadius=UDim.new(0,r),Parent=par}) end
local function Stroke(c,t,par) New("UIStroke",{Color=c,Thickness=t,Parent=par}) end
local function Pad(t,r,b,l,par)
    New("UIPadding",{PaddingTop=UDim.new(0,t),PaddingRight=UDim.new(0,r),
        PaddingBottom=UDim.new(0,b),PaddingLeft=UDim.new(0,l),Parent=par})
end
local function List(dir,gap,par)
    New("UIListLayout",{FillDirection=dir,SortOrder=Enum.SortOrder.LayoutOrder,
        Padding=UDim.new(0,gap),Parent=par})
end
local TI = TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local function Tw(o,props) TweenService:Create(o,TI,props):Play() end

-- ── Remove old GUI if re-injected ───────────────────────────
if PlayerGui:FindFirstChild("TitanicHub") then
    PlayerGui.TitanicHub:Destroy()
end

-- ── Root ────────────────────────────────────────────────────
local Screen = New("ScreenGui",{
    Name="TitanicHub", ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    Parent=PlayerGui,
})

-- ── Window 1120 × 650 ───────────────────────────────────────
local WW,WH = 1120,650
local Win = New("Frame",{
    Size=UDim2.new(0,WW,0,WH),
    Position=UDim2.new(.5,-WW/2,.5,-WH/2),
    BackgroundColor3=C.BG0, BorderSizePixel=0, Parent=Screen,
})
Corner(12,Win) Stroke(C.BOR,1,Win)

-- drag
do
    local drag,ds,sp=false
    local db=New("Frame",{Size=UDim2.new(1,0,0,38),BackgroundTransparency=1,ZIndex=20,Parent=Win})
    db.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true ds=i.Position sp=Win.Position end end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            Win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end

-- ── Top bar ─────────────────────────────────────────────────
local TopBar = New("Frame",{
    Size=UDim2.new(1,0,0,38), BackgroundColor3=C.BG1,
    BorderSizePixel=0, ZIndex=5, Parent=Win,
})
Corner(12,TopBar)
New("Frame",{Size=UDim2.new(1,0,0,12),Position=UDim2.new(0,0,1,-12),
    BackgroundColor3=C.BG1,BorderSizePixel=0,Parent=TopBar})

New("TextLabel",{Text="  ⚓  TITANIC HUB",Font=Enum.Font.GothamBold,
    TextSize=14,TextColor3=C.WHITE,BackgroundTransparency=1,
    Size=UDim2.new(0,300,1,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=TopBar})
New("TextLabel",{Text="AOTR Script  |  by ZEKE",Font=Enum.Font.Gotham,
    TextSize=11,TextColor3=C.DIM,BackgroundTransparency=1,
    Size=UDim2.new(0,240,1,0),Position=UDim2.new(0,240,0,0),
    TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=TopBar})

-- window control buttons
local BtnHolder=New("Frame",{Size=UDim2.new(0,90,0,22),
    Position=UDim2.new(1,-96,0,8),BackgroundTransparency=1,ZIndex=6,Parent=TopBar})
List(Enum.FillDirection.Horizontal,4,BtnHolder)
for _,cfg in ipairs({{"─",C.DIM},{"□",C.DIM},{"✕",C.RED}}) do
    local b=New("TextButton",{Text=cfg[1],Font=Enum.Font.GothamBold,TextSize=13,
        TextColor3=cfg[2],Size=UDim2.new(0,26,0,22),
        BackgroundColor3=C.BG3,BorderSizePixel=0,AutoButtonColor=false,ZIndex=7,Parent=BtnHolder})
    Corner(5,b)
    b.MouseEnter:Connect(function() Tw(b,{BackgroundColor3=C.BG4}) end)
    b.MouseLeave:Connect(function() Tw(b,{BackgroundColor3=C.BG3}) end)
    if cfg[1]=="✕" then b.MouseButton1Click:Connect(function() Screen:Destroy() end) end
end

-- ============================================================
--  SIDEBAR  220px
-- ============================================================
local SB = New("Frame",{
    Name="Sidebar",Size=UDim2.new(0,220,1,-38),
    Position=UDim2.new(0,0,0,38),
    BackgroundColor3=C.BG1,BorderSizePixel=0,Parent=Win,
})
New("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,-1,0,0),
    BackgroundColor3=C.BOR,BorderSizePixel=0,Parent=SB})

-- brand
local Brand=New("Frame",{Size=UDim2.new(1,0,0,82),BackgroundTransparency=1,Parent=SB})
Pad(14,14,0,14,Brand)
local Icon=New("Frame",{Size=UDim2.new(0,38,0,38),BackgroundColor3=C.ACC,BorderSizePixel=0,Parent=Brand})
Corner(9,Icon)
New("TextLabel",{Text="⚓",Font=Enum.Font.GothamBold,TextSize=20,TextColor3=C.WHITE,
    BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),
    TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,Parent=Icon})
New("TextLabel",{Text="TITANIC HUB",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.WHITE,
    BackgroundTransparency=1,Position=UDim2.new(0,48,0,3),Size=UDim2.new(1,-48,0,16),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=Brand})
New("TextLabel",{Text="AOTR Script",Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.DIM,
    BackgroundTransparency=1,Position=UDim2.new(0,48,0,21),Size=UDim2.new(1,-48,0,14),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=Brand})
New("TextLabel",{Text="by ZEKE",Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.ACC3,
    BackgroundTransparency=1,Position=UDim2.new(0,48,0,37),Size=UDim2.new(1,-48,0,14),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=Brand})
New("Frame",{Size=UDim2.new(1,-24,0,1),Position=UDim2.new(0,12,0,83),
    BackgroundColor3=C.BOR,BorderSizePixel=0,Parent=SB})

-- nav list
local NavScroll=New("ScrollingFrame",{
    Size=UDim2.new(1,0,1,-178),Position=UDim2.new(0,0,0,85),
    BackgroundTransparency=1,ScrollBarThickness=0,
    CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
    Parent=SB,
})
Pad(4,8,4,8,NavScroll)
List(Enum.FillDirection.Vertical,2,NavScroll)

local NAV_ITEMS={
    {icon="🏠",label="Home",       tab="Main"},
    {icon="⚙️",label="Main",       tab="Main"},
    {icon="🤖",label="Auto Farm",  tab="Main"},
    {icon="⚔️",label="Combat",     tab="Main"},
    {icon="📊",label="Stats",      tab="Main"},
    {icon="📍",label="Teleport",   tab="Misc"},
    {icon="🔧",label="Misc",       tab="Misc"},
    {icon="⚙", label="Settings",  tab="Settings"},
    {icon="🔑",label="Key System", tab="Settings"},
    {icon="💬",label="Discord",    tab="Main"},
}

local activeNavBtn=nil
local PageFrames={}  -- filled below
local function switchNav(btn,bar,lbl,targetTab)
    if activeNavBtn and activeNavBtn~=btn then
        local ob=activeNavBtn
        Tw(ob.btn,{BackgroundTransparency=1})
        Tw(ob.bar,{BackgroundTransparency=1})
        ob.lbl.Font=Enum.Font.Gotham
        ob.lbl.TextColor3=C.MUTED
    end
    activeNavBtn={btn=btn,bar=bar,lbl=lbl}
    Tw(btn,{BackgroundTransparency=0.75,BackgroundColor3=C.ACC})
    Tw(bar,{BackgroundTransparency=0})
    lbl.Font=Enum.Font.GothamBold
    lbl.TextColor3=C.WHITE
    -- show matching page
    for name,frame in pairs(PageFrames) do
        frame.Visible = (name==targetTab)
    end
end

for i,item in ipairs(NAV_ITEMS) do
    local row=New("TextButton",{
        Text="",Size=UDim2.new(1,0,0,36),
        BackgroundColor3=C.ACC,BackgroundTransparency=1,
        BorderSizePixel=0,AutoButtonColor=false,LayoutOrder=i,Parent=NavScroll,
    })
    Corner(6,row)
    local bar=New("Frame",{Size=UDim2.new(0,3,0.7,0),Position=UDim2.new(0,0,0.15,0),
        BackgroundColor3=C.ACC2,BackgroundTransparency=1,BorderSizePixel=0,Parent=row})
    Corner(2,bar)
    local lbl=New("TextLabel",{Text=item.icon.."  "..item.label,
        Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.MUTED,
        BackgroundTransparency=1,Size=UDim2.new(1,-12,1,0),
        Position=UDim2.new(0,10,0,0),TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    row.MouseEnter:Connect(function()
        if activeNavBtn and activeNavBtn.btn~=row then
            Tw(row,{BackgroundTransparency=0.88}) end end)
    row.MouseLeave:Connect(function()
        if activeNavBtn and activeNavBtn.btn~=row then
            Tw(row,{BackgroundTransparency=1}) end end)
    row.MouseButton1Click:Connect(function() switchNav(row,bar,lbl,item.tab) end)
    if i==1 then
        -- activate Home by default (deferred below after PageFrames built)
        task.defer(function() switchNav(row,bar,lbl,item.tab) end)
    end
end

-- User Panel (bottom sidebar)
New("Frame",{Size=UDim2.new(1,-24,0,1),Position=UDim2.new(0,12,1,-96),
    BackgroundColor3=C.BOR,BorderSizePixel=0,Parent=SB})
local UP=New("Frame",{Size=UDim2.new(1,0,0,92),Position=UDim2.new(0,0,1,-94),
    BackgroundTransparency=1,Parent=SB})
Pad(10,12,0,12,UP)
local Av=New("Frame",{Size=UDim2.new(0,36,0,36),BackgroundColor3=C.ACC,BorderSizePixel=0,Parent=UP})
Corner(18,Av)
New("TextLabel",{Text="Z",Font=Enum.Font.GothamBold,TextSize=16,TextColor3=C.WHITE,
    BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),
    TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,Parent=Av})
New("TextLabel",{Text="Welcome,",Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.DIM,
    BackgroundTransparency=1,Position=UDim2.new(0,46,0,0),Size=UDim2.new(1,-46,0,14),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=UP})
New("TextLabel",{Text="User#ZEKE",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.WHITE,
    BackgroundTransparency=1,Position=UDim2.new(0,46,0,14),Size=UDim2.new(1,-46,0,16),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=UP})
local PB=New("Frame",{Size=UDim2.new(0,60,0,16),Position=UDim2.new(0,46,0,32),
    BackgroundColor3=C.GOLD,BorderSizePixel=0,Parent=UP})
Corner(4,PB)
New("TextLabel",{Text="PREMIUM",Font=Enum.Font.GothamBold,TextSize=9,
    TextColor3=Color3.new(0,0,0),BackgroundTransparency=1,
    Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center,Parent=PB})
local GDot=New("Frame",{Size=UDim2.new(0,7,0,7),Position=UDim2.new(0,0,0,5),
    BackgroundColor3=C.GREEN,BorderSizePixel=0,Parent=New("Frame",{
        Size=UDim2.new(1,-24,0,16),Position=UDim2.new(0,12,0,54),
        BackgroundTransparency=1,Parent=UP})})
Corner(4,GDot)
New("TextLabel",{Text="Online",Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.DIM,
    BackgroundTransparency=1,Position=UDim2.new(0,12,0,-1),Size=UDim2.new(1,-12,1,0),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=GDot.Parent})
New("TextLabel",{Text="TitanicHub v1.0.0  ·  Always Undetected",
    Font=Enum.Font.Gotham,TextSize=9,TextColor3=C.DIM,BackgroundTransparency=1,
    Position=UDim2.new(0,12,0,70),Size=UDim2.new(1,-24,0,14),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=UP})

-- ============================================================
--  CONTENT AREA
-- ============================================================
local Content=New("Frame",{
    Size=UDim2.new(1,-220,1,-38),
    Position=UDim2.new(0,220,0,38),
    BackgroundColor3=C.BG0,BorderSizePixel=0,Parent=Win,
})

-- ── Shared widget builders ───────────────────────────────────
local function Panel(parent,x,y,w,h)
    local f=New("Frame",{Size=UDim2.new(0,w,0,h),Position=UDim2.new(0,x,0,y),
        BackgroundColor3=C.BG2,BorderSizePixel=0,Parent=parent})
    Corner(8,f) Stroke(C.BOR,1,f)
    return f
end
local function PanelHeader(parent,iconTxt,titleTxt)
    local hdr=New("Frame",{Size=UDim2.new(1,-24,0,28),Position=UDim2.new(0,12,0,10),
        BackgroundTransparency=1,Parent=parent})
    New("TextLabel",{Text=iconTxt,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.ACC2,
        BackgroundTransparency=1,Size=UDim2.new(0,22,1,0),
        TextXAlignment=Enum.TextXAlignment.Center,Parent=hdr})
    New("TextLabel",{Text=titleTxt,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.WHITE,
        BackgroundTransparency=1,Position=UDim2.new(0,26,0,0),Size=UDim2.new(1,-26,1,0),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=hdr})
    New("Frame",{Size=UDim2.new(1,-24,0,1),Position=UDim2.new(0,12,0,40),
        BackgroundColor3=C.BOR,BorderSizePixel=0,Parent=parent})
    return hdr
end

-- Toggle builder → returns a function to read value
local function MakeToggle(parent,yPos,labelTxt,default)
    local row=New("Frame",{Size=UDim2.new(1,-24,0,28),Position=UDim2.new(0,12,0,yPos),
        BackgroundTransparency=1,Parent=parent})
    New("TextLabel",{Text=labelTxt,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.MUTED,
        BackgroundTransparency=1,Size=UDim2.new(1,-46,1,0),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    local track=New("Frame",{Size=UDim2.new(0,34,0,18),
        Position=UDim2.new(1,-34,0.5,-9),
        BackgroundColor3=default and C.ACC or C.BG4,
        BorderSizePixel=0,Parent=row})
    Corner(9,track) Stroke(C.BOR2,1,track)
    local thumb=New("Frame",{
        Size=UDim2.new(0,12,0,12),
        Position=default and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6),
        BackgroundColor3=default and C.WHITE or C.DIM,
        BorderSizePixel=0,Parent=track})
    Corner(6,thumb)
    local val=default or false
    local btn=New("TextButton",{Text="",Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1,Parent=track})
    btn.MouseButton1Click:Connect(function()
        val=not val
        Tw(track,{BackgroundColor3=val and C.ACC or C.BG4})
        Tw(thumb,{Position=val and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6),
            BackgroundColor3=val and C.WHITE or C.DIM})
    end)
    return function() return val end, function(v)
        val=v
        Tw(track,{BackgroundColor3=val and C.ACC or C.BG4})
        Tw(thumb,{Position=val and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6),
            BackgroundColor3=val and C.WHITE or C.DIM})
    end
end

-- Slider builder → returns getter
local function MakeSlider(parent,yPos,labelTxt,minV,maxV,default)
    local row=New("Frame",{Size=UDim2.new(1,-24,0,38),Position=UDim2.new(0,12,0,yPos),
        BackgroundTransparency=1,Parent=parent})
    New("TextLabel",{Text=labelTxt,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.MUTED,
        BackgroundTransparency=1,Size=UDim2.new(0.7,0,0,16),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    local valLbl=New("TextLabel",{Text=tostring(default),Font=Enum.Font.GothamBold,
        TextSize=12,TextColor3=C.WHITE,BackgroundTransparency=1,
        Size=UDim2.new(0.3,0,0,16),TextXAlignment=Enum.TextXAlignment.Right,Parent=row})
    local track=New("Frame",{Size=UDim2.new(1,0,0,4),Position=UDim2.new(0,0,0,22),
        BackgroundColor3=C.BG4,BorderSizePixel=0,Parent=row})
    Corner(2,track)
    local pct=(default-minV)/(maxV-minV)
    local fill=New("Frame",{Size=UDim2.new(pct,0,1,0),BackgroundColor3=C.ACC2,
        BorderSizePixel=0,Parent=track})
    Corner(2,fill)
    local thumb=New("Frame",{Size=UDim2.new(0,14,0,14),
        Position=UDim2.new(pct,-7,0.5,-7),
        BackgroundColor3=C.ACC2,BorderSizePixel=0,Parent=track})
    Corner(7,thumb)
    local val=default
    local dragging=false
    local db=New("TextButton",{Text="",Size=UDim2.new(1,28,1,20),
        Position=UDim2.new(0,-14,0,-8),BackgroundTransparency=1,Parent=track})
    db.MouseButton1Down:Connect(function() dragging=true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local abs=track.AbsolutePosition
            local sz=track.AbsoluteSize
            local rel=math.clamp((i.Position.X-abs.X)/sz.X,0,1)
            val=math.floor(minV+(maxV-minV)*rel)
            valLbl.Text=tostring(val)
            fill.Size=UDim2.new(rel,0,1,0)
            thumb.Position=UDim2.new(rel,-7,0.5,-7)
        end end)
    return function() return val end
end

-- Dropdown builder
local function MakeDropdown(parent,yPos,labelTxt,values,default)
    local row=New("Frame",{Size=UDim2.new(1,-24,0,50),Position=UDim2.new(0,12,0,yPos),
        BackgroundTransparency=1,Parent=parent})
    New("TextLabel",{Text=labelTxt,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.MUTED,
        BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    local box=New("Frame",{Size=UDim2.new(1,0,0,28),Position=UDim2.new(0,0,0,18),
        BackgroundColor3=C.BG4,BorderSizePixel=0,Parent=row})
    Corner(6,box) Stroke(C.BOR2,1,box)
    local sel=default or (values[1] or "")
    local selLbl=New("TextLabel",{Text=sel,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.WHITE,
        BackgroundTransparency=1,Size=UDim2.new(1,-30,1,0),
        Position=UDim2.new(0,8,0,0),TextXAlignment=Enum.TextXAlignment.Left,Parent=box})
    New("TextLabel",{Text="▾",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.ACC2,
        BackgroundTransparency=1,Size=UDim2.new(0,20,1,0),
        Position=UDim2.new(1,-24,0,0),TextXAlignment=Enum.TextXAlignment.Center,Parent=box})
    -- dropdown list
    local list=New("Frame",{Size=UDim2.new(1,0,0,#values*26+4),
        Position=UDim2.new(0,0,1,2),BackgroundColor3=C.BG3,
        BorderSizePixel=0,Visible=false,ZIndex=20,Parent=box})
    Corner(6,list) Stroke(C.BOR2,1,list)
    Pad(2,0,2,0,list)
    List(Enum.FillDirection.Vertical,0,list)
    for _,v in ipairs(values) do
        local opt=New("TextButton",{Text=v,Font=Enum.Font.Gotham,TextSize=12,
            TextColor3=C.MUTED,Size=UDim2.new(1,0,0,24),
            BackgroundColor3=C.BG3,BackgroundTransparency=1,
            BorderSizePixel=0,AutoButtonColor=false,ZIndex=21,Parent=list})
        opt.MouseEnter:Connect(function() Tw(opt,{BackgroundTransparency=0.7,TextColor3=C.WHITE}) end)
        opt.MouseLeave:Connect(function() Tw(opt,{BackgroundTransparency=1,TextColor3=C.MUTED}) end)
        opt.MouseButton1Click:Connect(function()
            sel=v selLbl.Text=v list.Visible=false end)
    end
    local tog=New("TextButton",{Text="",Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1,ZIndex=2,Parent=box})
    tog.MouseButton1Click:Connect(function() list.Visible=not list.Visible end)
    return function() return sel end
end

-- Action Button
local function MakeButton(parent,yPos,labelTxt,col,onClick)
    col=col or C.ACC
    local btn=New("TextButton",{
        Text=labelTxt,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.WHITE,
        Size=UDim2.new(1,-24,0,32),Position=UDim2.new(0,12,0,yPos),
        BackgroundColor3=col,BorderSizePixel=0,AutoButtonColor=false,Parent=parent})
    Corner(7,btn)
    btn.MouseEnter:Connect(function() Tw(btn,{BackgroundColor3=Color3.new(
        math.min(col.R+0.06,1),math.min(col.G+0.06,1),math.min(col.B+0.06,1))}) end)
    btn.MouseLeave:Connect(function() Tw(btn,{BackgroundColor3=col}) end)
    if onClick then btn.MouseButton1Click:Connect(onClick) end
    return btn
end

-- Label
local function MakeLabel(parent,yPos,txt,col)
    return New("TextLabel",{Text=txt,Font=Enum.Font.Gotham,TextSize=11,
        TextColor3=col or C.DIM,BackgroundTransparency=1,
        Size=UDim2.new(1,-24,0,28),Position=UDim2.new(0,12,0,yPos),
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=parent})
end

-- Input box
local function MakeInput(parent,yPos,labelTxt,placeholder)
    local row=New("Frame",{Size=UDim2.new(1,-24,0,50),Position=UDim2.new(0,12,0,yPos),
        BackgroundTransparency=1,Parent=parent})
    New("TextLabel",{Text=labelTxt,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.MUTED,
        BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    local box=New("TextBox",{PlaceholderText=placeholder or "",Text="",
        Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.WHITE,
        PlaceholderColor3=C.DIM,
        Size=UDim2.new(1,0,0,28),Position=UDim2.new(0,0,0,18),
        BackgroundColor3=C.BG4,BorderSizePixel=0,
        ClearTextOnFocus=false,Parent=row})
    Corner(6,box) Stroke(C.BOR2,1,box)
    Pad(0,8,0,8,box)
    return function() return box.Text end
end

-- ============================================================
--  PAGE: MAIN TAB
-- ============================================================
local MainPage=New("Frame",{
    Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
    Visible=true,Parent=Content,
})
PageFrames["Main"]=MainPage

-- page header
New("TextLabel",{Text="Dashboard",Font=Enum.Font.GothamBold,TextSize=22,
    TextColor3=C.ACC2,BackgroundTransparency=1,
    Size=UDim2.new(1,-20,0,30),Position=UDim2.new(0,16,0,10),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=MainPage})
New("TextLabel",{Text="Overview of all features and system status.",
    Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.DIM,BackgroundTransparency=1,
    Size=UDim2.new(1,-20,0,18),Position=UDim2.new(0,16,0,38),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=MainPage})

-- ── Status Cards row ────────────────────────────────────────
local CW=194 local CY=64 local CX=16
local function StatusCard(x,accentCol,icon,topLbl,valTxt,valCol,noteTxt)
    local f=Panel(MainPage,x,CY,CW,80)
    New("Frame",{Size=UDim2.new(1,0,0,2),BackgroundColor3=accentCol,
        BorderSizePixel=0,Parent=f})  -- top accent strip
    Corner(8,f)
    -- icon circle
    local ic=New("Frame",{Size=UDim2.new(0,36,0,36),Position=UDim2.new(0,10,0,22),
        BackgroundColor3=accentCol,BackgroundTransparency=0.8,BorderSizePixel=0,Parent=f})
    Corner(18,ic)
    New("TextLabel",{Text=icon,Font=Enum.Font.GothamBold,TextSize=18,
        TextColor3=accentCol,BackgroundTransparency=1,
        Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center,
        TextYAlignment=Enum.TextYAlignment.Center,Parent=ic})
    New("TextLabel",{Text=topLbl,Font=Enum.Font.Gotham,TextSize=9,TextColor3=C.DIM,
        BackgroundTransparency=1,Position=UDim2.new(0,54,0,16),
        Size=UDim2.new(1,-60,0,14),TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    New("TextLabel",{Text=valTxt,Font=Enum.Font.GothamBold,TextSize=16,
        TextColor3=valCol,BackgroundTransparency=1,
        Position=UDim2.new(0,54,0,30),Size=UDim2.new(1,-60,0,22),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    New("TextLabel",{Text=noteTxt,Font=Enum.Font.Gotham,TextSize=9,TextColor3=C.DIM,
        BackgroundTransparency=1,Position=UDim2.new(0,54,0,52),
        Size=UDim2.new(1,-60,0,14),TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
end
StatusCard(CX,              C.GREEN,"✔","Script Status","Active",  C.GREEN,"Last update: Today")
StatusCard(CX+CW+6,         C.ACC,  "🎮","Game",         "AOTR",    C.ACC2, "Attack on Titan Revolution")
StatusCard(CX+(CW+6)*2,     C.CYAN, ">_","Executor",     "Delta",   C.CYAN, "Recommended")
StatusCard(CX+(CW+6)*3,     C.GOLD, "🔑","Key Status",   "Premium", C.GOLD, "Valid Until: Lifetime")

-- ── Main Features panel ─────────────────────────────────────
local FeatPanel=Panel(MainPage,16,158,370,270)
PanelHeader(FeatPanel,"★","MAIN FEATURES")

local getAutoFarm,setAutoFarm=MakeToggle(FeatPanel,50,"Auto Farm",false)
local getAutoGrind,_=MakeToggle(FeatPanel,82,"Auto Grind",false)
local getAutoSpin,_=MakeToggle(FeatPanel,114,"Auto Spin",false)
local getAutoUpgrade,_=MakeToggle(FeatPanel,146,"Auto Upgrade",false)
local getAutoChestT,_=MakeToggle(FeatPanel,178,"Auto Open Chests",false)
local getAutoRetryT,_=MakeToggle(FeatPanel,210,"Auto Retry",false)

MakeButton(FeatPanel,242,"▶  Start All Features",C.ACC,function()
    setAutoFarm(true)
end)

-- ── Player panel ────────────────────────────────────────────
local PlrPanel=Panel(MainPage,400,158,348,270)
PanelHeader(PlrPanel,"👤","PLAYER")

local getWalkSpeed=MakeSlider(PlrPanel,50,"WalkSpeed",16,500,250)
local getJumpPower=MakeSlider(PlrPanel,96,"JumpPower",0,1000,500)
local getNoClip,_=MakeToggle(PlrPanel,148,"NoClip",true)
local getInfStam,_=MakeToggle(PlrPanel,180,"Infinite Stamina",true)
local getAntiStun,_=MakeToggle(PlrPanel,212,"Anti-Stun",true)

MakeButton(PlrPanel,242,"↺  Reset Player",C.BG3,function()
    local char=lp.Character
    if char then
        local h=char:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed=16 h.JumpPower=50 end
    end
end)

-- ── Teleports panel ─────────────────────────────────────────
local TpPanel=Panel(MainPage,762,158,140,270)
PanelHeader(TpPanel,"📍","TELEPORTS")

local teleports={
    {name="Eren's City"},
    {name="Utopia District"},
    {name="Stohess"},
    {name="Underground City"},
    {name="Crystal Cave"},
    {name="Shiganshina"},
}
for i,tp in ipairs(teleports) do
    local btn=New("TextButton",{
        Text=tp.name.."  ›",Font=Enum.Font.Gotham,TextSize=11,
        TextColor3=C.MUTED,Size=UDim2.new(1,-20,0,26),
        Position=UDim2.new(0,10,0,44+(i-1)*30),
        BackgroundColor3=C.BG3,BorderSizePixel=0,
        AutoButtonColor=false,TextXAlignment=Enum.TextXAlignment.Left,
        Parent=TpPanel,
    })
    Corner(5,btn) Stroke(C.BOR,1,btn)
    Pad(0,6,0,8,btn)
    btn.MouseEnter:Connect(function()
        Tw(btn,{BackgroundColor3=C.BG4,TextColor3=C.WHITE}) end)
    btn.MouseLeave:Connect(function()
        Tw(btn,{BackgroundColor3=C.BG3,TextColor3=C.MUTED}) end)
end

-- ── System Log ──────────────────────────────────────────────
local LogPanel=Panel(MainPage,16,442,530,148)
PanelHeader(LogPanel,"</>","SYSTEM LOG")
local LogScroll=New("ScrollingFrame",{
    Size=UDim2.new(1,-24,1,-54),Position=UDim2.new(0,12,0,48),
    BackgroundTransparency=1,ScrollBarThickness=2,
    ScrollBarImageColor3=C.BOR2,
    CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
    Parent=LogPanel,
})
List(Enum.FillDirection.Vertical,0,LogScroll)

local logColors={["green"]=C.GREEN,["gold"]=C.GOLD,["cyan"]=C.CYAN,["red"]=C.RED,["dim"]=C.DIM}
local function LogWrite(msg,col)
    local t=os.date("[%H:%M:%S] ")
    local lbl=New("TextLabel",{
        Text=t..msg,Font=Enum.Font.Code,TextSize=11,
        TextColor3=logColors[col] or C.MUTED,BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Left,
        Parent=LogScroll,
    })
    Pad(0,4,0,4,lbl)
    task.defer(function()
        LogScroll.CanvasPosition=Vector2.new(0,LogScroll.AbsoluteCanvasSize.Y) end)
    return lbl
end

LogWrite("Script loaded successfully.","green")
LogWrite("Key verified.  Premium access granted.","gold")
LogWrite("Welcome back, User#ZEKE!","cyan")

-- helper so existing code can still call UpdateStatus
getgenv().CurrentStatusLabel = {SetText=function(_,t) LogWrite(t,"dim") end}
function UpdateStatus(text) LogWrite("Status: "..text,"dim") end

-- ── Quick Actions ────────────────────────────────────────────
local QAPanel=Panel(MainPage,560,442,348,148)
PanelHeader(QAPanel,"⚡","QUICK ACTIONS")
local QAGrid=New("Frame",{Size=UDim2.new(1,-24,0,80),Position=UDim2.new(0,12,0,52),
    BackgroundTransparency=1,Parent=QAPanel})
New("UIGridLayout",{CellSize=UDim2.new(0.5,-4,0,32),CellPaddingY=UDim.new(0,6),
    SortOrder=Enum.SortOrder.LayoutOrder,Parent=QAGrid})

local function QBtn(lbl,col,cb)
    local b=New("TextButton",{Text=lbl,Font=Enum.Font.GothamBold,TextSize=12,
        TextColor3=col==C.RED and C.RED or C.WHITE,
        BackgroundColor3=col==C.RED and Color3.fromRGB(60,15,15) or C.BG3,
        BorderSizePixel=0,AutoButtonColor=false,Parent=QAGrid})
    Corner(6,b)
    Stroke(col==C.RED and Color3.fromRGB(100,30,30) or C.BOR2,1,b)
    b.MouseEnter:Connect(function() Tw(b,{BackgroundColor3=C.BG4}) end)
    b.MouseLeave:Connect(function() Tw(b,{BackgroundColor3=col==C.RED and Color3.fromRGB(60,15,15) or C.BG3}) end)
    if cb then b.MouseButton1Click:Connect(cb) end
end
QBtn("↺  Rejoin",C.BG3,function()
    local TS=game:GetService("TeleportService")
    TS:Teleport(game.PlaceId,lp)
end)
QBtn("⇄  Server Hop",C.BG3,function()
    local TS=game:GetService("TeleportService")
    local pages=TS:GetSortedGameInstances(game.PlaceId,10)
    if pages and pages[1] then TS:TeleportToPlaceInstance(game.PlaceId,pages[1].Id,lp) end
end)
QBtn("■  Stop Script",C.RED,function()
    Screen:Destroy()
end)

-- ============================================================
--  PAGE: MISC TAB
-- ============================================================
local MiscPage=New("Frame",{
    Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
    Visible=false,Parent=Content,
})
PageFrames["Misc"]=MiscPage

New("TextLabel",{Text="Misc",Font=Enum.Font.GothamBold,TextSize=22,
    TextColor3=C.ACC2,BackgroundTransparency=1,
    Size=UDim2.new(1,-20,0,30),Position=UDim2.new(0,16,0,10),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=MiscPage})

-- Slot panel
local SlotPanel=Panel(MiscPage,16,58,380,240)
PanelHeader(SlotPanel,"🎰","SLOT")
local getAutoSlotT,_=MakeToggle(SlotPanel,50,"Auto Select Slot",false)
local getSlotDrop=MakeDropdown(SlotPanel,82,"Select Slot",{"Slot A","Slot B","Slot C"},"Slot A")
local getAutoPrestigeT,_=MakeToggle(SlotPanel,140,"Auto Prestige",false)
local getBoostDrop=MakeDropdown(SlotPanel,172,"Select Boost",{"Luck Boost","EXP Boost","Gold Boost"},"Luck Boost")
local getPrestigeGold=MakeSlider(SlotPanel,228,"Prestige Gold (M)",0,100,0)

-- Family Roll panel
local FamPanel=Panel(MiscPage,410,58,374,240)
PanelHeader(FamPanel,"🎲","FAMILY ROLL")
local getAutoRollT,_=MakeToggle(FamPanel,50,"Auto Roll",false)
local getFamilyInput=MakeInput(FamPanel,82,"Select Families","Fritz,Yeager,etc.")
local getFamilyRarity=MakeDropdown(FamPanel,140,"Stop At (Rarity)",{"Rare","Epic","Legendary","Mythical"},"Legendary")
MakeLabel(FamPanel,196,"Mythical families won't be rolled\nSeparate with commas, no spaces.")

-- ============================================================
--  PAGE: SETTINGS TAB
-- ============================================================
local SettPage=New("Frame",{
    Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
    Visible=false,Parent=Content,
})
PageFrames["Settings"]=SettPage

New("TextLabel",{Text="Settings",Font=Enum.Font.GothamBold,TextSize=22,
    TextColor3=C.ACC2,BackgroundTransparency=1,
    Size=UDim2.new(1,-20,0,30),Position=UDim2.new(0,16,0,10),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=SettPage})

local SettPanel=Panel(SettPage,16,58,380,220)
PanelHeader(SettPanel,"⚙","SETTINGS")
local getAutoHideT,_=MakeToggle(SettPanel,50,"Auto Hide GUI",false)
local getDis3DT,_=MakeToggle(SettPanel,82,"Disable 3D Rendering (FPS Boost)",false)
MakeLabel(SettPanel,120,"Menu toggle: Right Control (default)",C.DIM)

local WebPanel=Panel(SettPage,410,58,374,220)
PanelHeader(WebPanel,"🔗","WEBHOOK")
local getRewardWHT,_=MakeToggle(WebPanel,50,"Reward Webhook",false)
local getMythWHT,_=MakeToggle(WebPanel,82,"Mythical Family Webhook",false)
local getWebhookURL=MakeInput(WebPanel,114,"Webhook URL","https://discord.com/api/webhooks/...")

-- ============================================================
--  WIRE UP LOGIC — mirror the original Obsidian toggles
-- ============================================================

-- UpdateStatus already set above

-- 3D rendering toggle
local RS=game:GetService("RunService")
task.spawn(function()
    while true do
        task.wait(0.5)
        if getDis3DT then
            RS:Set3dRenderingEnabled(not getDis3DT())
        end
    end
end)

-- Auto Hide
task.defer(function()
    task.wait(0.5)
    if getAutoHideT and getAutoHideT() then
        Win.Visible=false
        LogWrite("Auto Hide: GUI hidden. Press RightControl to show.","dim")
    end
end)

-- Toggle visibility with RightControl
UserInputService.InputBegan:Connect(function(inp,gp)
    if not gp and inp.KeyCode==Enum.KeyCode.RightControl then
        Win.Visible=not Win.Visible
    end
end)

-- Anti-AFK
local VU=game:GetService("VirtualUser")
lp.Idled:Connect(function()
    VU:CaptureController()
    VU:ClickButton2(Vector2.new())
end)

-- Auto Farm loop bridge
task.spawn(function()
    while true do
        task.wait(0.5)
        if getAutoFarm and getAutoFarm() then
            if AutoFarm and not AutoFarm._running then AutoFarm:Start() end
        else
            if AutoFarm and AutoFarm._running then AutoFarm:Stop() end
        end
        if getAutoChestT and getAutoChestT() then
            getgenv().AutoChest=true
        else
            getgenv().AutoChest=false
        end
        if getAutoRetryT and getAutoRetryT() then
            getgenv().AutoRetry=true
        else
            getgenv().AutoRetry=false
        end
    end
end)

-- Character speed/jump live update
RunService.Heartbeat:Connect(function()
    local char=lp.Character
    if not char then return end
    local h=char:FindFirstChildOfClass("Humanoid")
    if not h then return end
    if getNoClip and getNoClip() then
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end
    if getInfStam then
        -- Stamina attribute set to max if available
        if char:GetAttribute("Stamina") then
            char:SetAttribute("Stamina",char:GetAttribute("MaxStamina") or 100)
        end
    end
end)

-- Family Roll loop
task.spawn(function()
    while true do
        task.wait(0.25)
        if getAutoRollT and getAutoRollT() then
            getgenv().AutoRoll=true
        else
            getgenv().AutoRoll=false
        end
    end
end)

-- Webhook URL sync
task.spawn(function()
    while true do
        task.wait(1)
        if getWebhookURL then
            webhook=getWebhookURL()
        end
    end
end)

LogWrite("All systems ready.","green")

-- ── END TITANIC HUB ─────────────────────────────────────────
