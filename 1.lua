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
					Title = "Tekkit Hub",
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
				Title = "Tekkit Hub",
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
-- TEKKIT HUB CUSTOM UI LIBRARY (inline)
-- ==========================================

local Library, ThemeManager, SaveManager = (function()

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local lp2              = Players.LocalPlayer

local C = {
    BG          = Color3.fromRGB(28,  28,  30),
    SIDEBAR     = Color3.fromRGB(22,  22,  24),
    PANEL       = Color3.fromRGB(34,  34,  36),
    ROW         = Color3.fromRGB(40,  40,  43),
    ROW_HOVER   = Color3.fromRGB(50,  50,  54),
    DIVIDER     = Color3.fromRGB(55,  55,  58),
    SECTION     = Color3.fromRGB(130, 130, 140),
    NAV_TEXT    = Color3.fromRGB(210, 210, 215),
    NAV_ACTIVE  = Color3.fromRGB(255, 255, 255),
    NAV_ACTIVE_BG = Color3.fromRGB(55, 55, 60),
    TITLE_TEXT  = Color3.fromRGB(255, 255, 255),
    SUB_TEXT    = Color3.fromRGB(140, 140, 150),
    ACCENT      = Color3.fromRGB(100, 210, 255),
    TOGGLE_OFF  = Color3.fromRGB(75,  75,  80),
    TOGGLE_ON   = Color3.fromRGB(48,  180, 120),
    SLIDER_BG   = Color3.fromRGB(55,  55,  60),
    SLIDER_FILL = Color3.fromRGB(100, 210, 255),
    INPUT_BG    = Color3.fromRGB(22,  22,  24),
    INPUT_BORDER= Color3.fromRGB(70,  70,  75),
    BTN_BG      = Color3.fromRGB(50,  50,  55),
    BTN_HOVER   = Color3.fromRGB(65,  65,  72),
    BTN_TEXT    = Color3.fromRGB(220, 220, 225),
    NOTIF_BG    = Color3.fromRGB(38,  38,  42),
    NOTIF_BORDER= Color3.fromRGB(70,  70,  78),
    WINDOW_TITLE= Color3.fromRGB(255, 255, 255),
    FOOTER_TEXT = Color3.fromRGB(110, 110, 120),
    TOPBAR      = Color3.fromRGB(22,  22,  24),
    DROP_BG     = Color3.fromRGB(28,  28,  32),
    DROP_ITEM   = Color3.fromRGB(40,  40,  44),
    DROP_HOVER  = Color3.fromRGB(55,  55,  60),
    DROP_BORDER = Color3.fromRGB(65,  65,  72),
}

local function newI(cls, props)
    local o = Instance.new(cls)
    for k,v in pairs(props) do o[k]=v end
    return o
end
local function tw(obj, goal, t) TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), goal):Play() end
local function corner(p, r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 6) c.Parent=p return c end
local function stroke(p, col, th) local s=Instance.new("UIStroke") s.Color=col or C.DIVIDER s.Thickness=th or 1 s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Parent=p return s end
local function pad(p,t,b,l,r) local x=Instance.new("UIPadding") x.PaddingTop=UDim.new(0,t or 0) x.PaddingBottom=UDim.new(0,b or 0) x.PaddingLeft=UDim.new(0,l or 0) x.PaddingRight=UDim.new(0,r or 0) x.Parent=p end
local function listL(p,dir,sp) local l=Instance.new("UIListLayout") l.FillDirection=dir or Enum.FillDirection.Vertical l.SortOrder=Enum.SortOrder.LayoutOrder l.Padding=UDim.new(0,sp or 0) l.Parent=p return l end
local function lbl(parent,text,size,color,halign,extra)
    local o=newI("TextLabel",{Text=text,TextSize=size or 13,TextColor3=color or C.TITLE_TEXT,Font=Enum.Font.GothamSemibold,BackgroundTransparency=1,TextXAlignment=halign or Enum.TextXAlignment.Left,TextWrapped=true,Size=UDim2.new(1,0,0,(size or 13)+5),Parent=parent})
    if extra then for k,v in pairs(extra) do o[k]=v end end
    return o
end
local function makeDraggable(handle, frame)
    local drag,inp,start,pos=false
    handle.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true start=i.Position pos=frame.Position end end)
    handle.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then inp=i end end)
    handle.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UserInputService.InputChanged:Connect(function(i) if i==inp and drag then local d=i.Position-start frame.Position=UDim2.new(pos.X.Scale,pos.X.Offset+d.X,pos.Y.Scale,pos.Y.Offset+d.Y) end end)
end

local Library = { Options={}, Toggles={}, Unloaded=false, _unloadCbs={}, _notifQ={}, _notifBusy=false, ToggleKeybind=nil, _mainGui=nil }
local notifHolder

local function nextNotif()
    if #Library._notifQ==0 then Library._notifBusy=false return end
    Library._notifBusy=true
    local n=table.remove(Library._notifQ,1)
    local f=newI("Frame",{Size=UDim2.new(0,280,0,0),BackgroundColor3=C.NOTIF_BG,AutomaticSize=Enum.AutomaticSize.Y,Parent=notifHolder})
    corner(f,8) stroke(f,C.NOTIF_BORDER)
    newI("Frame",{Size=UDim2.new(0,3,1,0),BackgroundColor3=C.ACCENT,BorderSizePixel=0,Parent=f})
    local inner=newI("Frame",{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.Y,Parent=f})
    pad(inner,10,10,14,12) listL(inner,Enum.FillDirection.Vertical,3)
    lbl(inner,n.Title or "Tekkit Hub",13,C.ACCENT)
    local d=lbl(inner,n.Description or "",12,C.SUB_TEXT) d.Font=Enum.Font.Gotham d.AutomaticSize=Enum.AutomaticSize.Y d.Size=UDim2.new(1,0,0,0)
    task.delay(n.Time or 3,function() tw(f,{BackgroundTransparency=1},0.3) task.wait(0.35) f:Destroy() nextNotif() end)
end
function Library:Notify(o) table.insert(self._notifQ,o) if not self._notifBusy then nextNotif() end end
function Library:Toggle(v) if self._mainGui then self._mainGui.Enabled=v~=nil and v or not self._mainGui.Enabled end end
function Library:OnUnload(cb) table.insert(self._unloadCbs,cb) end

function Library:CreateWindow(opts)
    opts=opts or {}
    local title=opts.Title or "Tekkit Hub"
    local footer=opts.Footer or ""
    local sg=newI("ScreenGui",{Name="TekkitHub",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true,Parent=lp2:WaitForChild("PlayerGui")})
    self._mainGui=sg

    notifHolder=newI("Frame",{Size=UDim2.new(0,290,1,0),Position=UDim2.new(1,-300,0,0),BackgroundTransparency=1,Parent=sg})
    local nl=listL(notifHolder,Enum.FillDirection.Vertical,8) nl.VerticalAlignment=Enum.VerticalAlignment.Bottom
    pad(notifHolder,0,16,0,0)

    local winW,winH=780,490
    local mf=newI("Frame",{Size=UDim2.new(0,winW,0,winH),Position=UDim2.new(0.5,-winW/2,0.5,-winH/2),BackgroundColor3=C.BG,BorderSizePixel=0,ClipsDescendants=true,Parent=sg})
    corner(mf,10) stroke(mf,C.DIVIDER)

    -- Top bar
    local tb=newI("Frame",{Size=UDim2.new(1,0,0,42),BackgroundColor3=C.TOPBAR,BorderSizePixel=0,Parent=mf})
    corner(tb,10)
    newI("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),BackgroundColor3=C.TOPBAR,BorderSizePixel=0,Parent=tb})
    lbl(tb,title,14,C.WINDOW_TITLE,Enum.TextXAlignment.Left,{Position=UDim2.new(0,18,0,0),Size=UDim2.new(0.7,0,1,0),Font=Enum.Font.GothamBold})

    local function mkBtn(xOff, txt)
        local b=newI("TextButton",{Size=UDim2.new(0,28,0,28),Position=UDim2.new(1,xOff,0.5,-14),BackgroundColor3=Color3.fromRGB(60,60,65),Text=txt,TextColor3=Color3.fromRGB(200,200,205),TextSize=16,Font=Enum.Font.GothamBold,Parent=tb})
        corner(b,6) return b
    end
    local closeB=mkBtn(-36,"×")
    local minB=mkBtn(-72,"–")
    closeB.MouseButton1Click:Connect(function()
        tw(mf,{Size=UDim2.new(0,winW,0,0)},0.2) task.wait(0.22) sg:Destroy()
        for _,cb in ipairs(Library._unloadCbs) do pcall(cb) end Library.Unloaded=true
    end)
    local minimised=false
    minB.MouseButton1Click:Connect(function()
        minimised=not minimised
        tw(mf,{Size=UDim2.new(0,winW,0,minimised and 42 or winH)},0.2)
    end)
    makeDraggable(tb,mf)

    -- Body
    local body=newI("Frame",{Size=UDim2.new(1,0,1,-42),Position=UDim2.new(0,0,0,42),BackgroundTransparency=1,Parent=mf})
    local sbW=175
    local sb=newI("Frame",{Size=UDim2.new(0,sbW,1,0),BackgroundColor3=C.SIDEBAR,BorderSizePixel=0,Parent=body})
    newI("Frame",{Size=UDim2.new(1,0,0,10),BackgroundColor3=C.SIDEBAR,BorderSizePixel=0,Parent=sb})
    -- divider line
    newI("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,-1,0,0),BackgroundColor3=C.DIVIDER,BorderSizePixel=0,Parent=sb})

    local sbScroll=newI("ScrollingFrame",{Size=UDim2.new(1,0,1,-30),Position=UDim2.new(0,0,0,8),BackgroundTransparency=1,ScrollBarThickness=0,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Parent=sb})
    listL(sbScroll,Enum.FillDirection.Vertical,1) pad(sbScroll,4,4,8,8)
    newI("TextLabel",{Size=UDim2.new(1,0,0,22),Position=UDim2.new(0,0,1,-26),BackgroundTransparency=1,Text=footer,TextSize=10,TextColor3=C.FOOTER_TEXT,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,Parent=sb})

    local cp=newI("Frame",{Size=UDim2.new(1,-sbW,1,0),Position=UDim2.new(0,sbW,0,0),BackgroundColor3=C.PANEL,BorderSizePixel=0,Parent=body})

    local Win={_sb=sbScroll,_cp=cp,_navBtns={},_activePage=nil,_secOrder=0}

    -- AddSection: creates a sidebar category header + returns section with AddTab
    function Win:AddSection(name)
        local secLbl=newI("TextLabel",{
            Size=UDim2.new(1,0,0,20),
            BackgroundTransparency=1,
            Text=string.upper(name),
            TextSize=10,
            TextColor3=C.SECTION,
            Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Left,
            LayoutOrder=self._secOrder,
            Parent=self._sb,
        })
        pad(secLbl,6,0,6,0)
        self._secOrder=self._secOrder+1

        local section={_win=self}
        function section:AddTab(tabName)
            return Win:_makeTab(tabName)
        end
        return section
    end

    -- _makeTab: internal tab builder
    function Win:_makeTab(tabName)
        local order = self._secOrder
        self._secOrder = self._secOrder + 1

        -- Content scroll page
        local page=newI("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,ScrollBarThickness=3,ScrollBarImageColor3=C.DIVIDER,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false,Parent=self._cp})
        listL(page,Enum.FillDirection.Vertical,0) pad(page,12,12,16,16)

        -- Nav button
        local nb=newI("TextButton",{Size=UDim2.new(1,0,0,36),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,Text="",LayoutOrder=order,Parent=self._sb})
        corner(nb,7)
        local nl2=lbl(nb,tabName,13,C.NAV_TEXT,Enum.TextXAlignment.Left,{Position=UDim2.new(0,12,0,0),Size=UDim2.new(1,-12,1,0)})
        local abar=newI("Frame",{Size=UDim2.new(0,3,0.55,0),Position=UDim2.new(0,0,0.225,0),BackgroundColor3=C.ACCENT,BackgroundTransparency=1,BorderSizePixel=0,Parent=nb})
        corner(abar,2)

        local entry={btn=nb,lbl=nl2,bar=abar,page=page}
        table.insert(self._navBtns,entry)

        local winRef = self
        local function activate()
            for _,e in ipairs(winRef._navBtns) do
                e.page.Visible=false
                tw(e.btn,{BackgroundTransparency=1},0.1)
                tw(e.lbl,{TextColor3=C.NAV_TEXT},0.1)
                tw(e.bar,{BackgroundTransparency=1},0.1)
            end
            page.Visible=true
            tw(nb,{BackgroundColor3=C.NAV_ACTIVE_BG,BackgroundTransparency=0},0.1)
            tw(nl2,{TextColor3=C.NAV_ACTIVE},0.1)
            tw(abar,{BackgroundTransparency=0},0.1)
            winRef._activePage=page
        end
        nb.MouseButton1Click:Connect(activate)
        nb.MouseEnter:Connect(function() if winRef._activePage~=page then tw(nb,{BackgroundColor3=Color3.fromRGB(38,38,42),BackgroundTransparency=0},0.08) end end)
        nb.MouseLeave:Connect(function() if winRef._activePage~=page then tw(nb,{BackgroundTransparency=1},0.08) end end)
        if #self._navBtns==1 then activate() end

        -- ── Tab object ──────────────────────────────────
        local Tab={}

        local function makeRow(titleTxt, subtitleTxt)
            local row=newI("Frame",{Size=UDim2.new(1,0,0,0),BackgroundColor3=C.ROW,BorderSizePixel=0,AutomaticSize=Enum.AutomaticSize.Y,Parent=page})
            corner(row,6)
            newI("Frame",{Size=UDim2.new(1,-32,0,1),Position=UDim2.new(0,16,1,-1),BackgroundColor3=C.DIVIDER,BackgroundTransparency=0.65,BorderSizePixel=0,Parent=row})
            local inner=newI("Frame",{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.Y,Parent=row})
            pad(inner,10,10,14,14)
            local tb2=newI("Frame",{Size=UDim2.new(0.55,0,0,0),BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.Y,Parent=inner})
            listL(tb2,Enum.FillDirection.Vertical,2)
            if titleTxt then lbl(tb2,titleTxt,13,C.TITLE_TEXT) end
            if subtitleTxt then local s=lbl(tb2,subtitleTxt,11,C.SUB_TEXT) s.Font=Enum.Font.Gotham s.AutomaticSize=Enum.AutomaticSize.Y s.Size=UDim2.new(1,0,0,0) end
            local cf=newI("Frame",{Size=UDim2.new(0.45,-14,1,0),Position=UDim2.new(0.55,0,0,0),BackgroundTransparency=1,Parent=inner})
            row.MouseEnter:Connect(function() tw(row,{BackgroundColor3=C.ROW_HOVER},0.08) end)
            row.MouseLeave:Connect(function() tw(row,{BackgroundColor3=C.ROW},0.08) end)
            newI("Frame",{Size=UDim2.new(1,0,0,4),BackgroundTransparency=1,Parent=page})
            return row,cf
        end

        function Tab:AddToggle(id,opts)
            opts=opts or {}
            local val=opts.Default or false
            local cbs={}
            local obj={Value=val,_cbs=cbs}
            local row,cf=makeRow(opts.Text,opts.Subtitle)
            local sw,sh=44,24
            local sbg=newI("Frame",{Size=UDim2.new(0,sw,0,sh),Position=UDim2.new(1,-sw,0.5,-sh/2),BackgroundColor3=val and C.TOGGLE_ON or C.TOGGLE_OFF,Parent=cf})
            corner(sbg,sh/2)
            local th2=newI("Frame",{Size=UDim2.new(0,sh-6,0,sh-6),Position=UDim2.new(0,val and sw-sh+3 or 3,0,3),BackgroundColor3=Color3.new(1,1,1),Parent=sbg})
            corner(th2,(sh-6)/2)
            local btn2=newI("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=sbg})
            local function setV(v,fire)
                val=v obj.Value=v
                tw(sbg,{BackgroundColor3=v and C.TOGGLE_ON or C.TOGGLE_OFF},0.15)
                tw(th2,{Position=UDim2.new(0,v and sw-sh+3 or 3,0,3)},0.15)
                if fire~=false then for _,cb in ipairs(cbs) do pcall(cb,v) end end
            end
            btn2.MouseButton1Click:Connect(function() setV(not val) end)
            row.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then setV(not val) end end)
            function obj:SetValue(v) setV(v,true) end
            function obj:OnChanged(cb) table.insert(cbs,cb) return obj end
            Library.Toggles[id]=obj return obj
        end

        function Tab:AddDropdown(id,opts)
            opts=opts or {}
            local vals=opts.Values or {}
            local multi=opts.Multi or false
            local defIdx=opts.Default or 1
            local cbs={}
            local cur=multi and (type(defIdx)=="table" and defIdx or {}) or (vals[defIdx] or vals[1])
            local obj={Value=cur,_cbs=cbs,_vals=vals,_visible=true}
            local row,cf=makeRow(opts.Text,opts.Subtitle)
            local bh=28
            local db=newI("TextButton",{Size=UDim2.new(1,0,0,bh),Position=UDim2.new(0,0,0.5,-bh/2),BackgroundColor3=C.INPUT_BG,Text="",Parent=cf})
            corner(db,5) stroke(db,C.INPUT_BORDER)
            local function dispTxt() if multi then local t={} for k,v in pairs(cur) do if v then table.insert(t,k) end end return #t==0 and "None" or table.concat(t,", ") else return tostring(cur or "Select...") end end
            local dlbl=lbl(db,dispTxt(),12,C.NAV_TEXT,Enum.TextXAlignment.Left,{Position=UDim2.new(0,8,0,0),Size=UDim2.new(1,-24,1,0)})
            lbl(db,"▾",12,C.SUB_TEXT,Enum.TextXAlignment.Right,{Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,-6,1,0)})

            local lf=newI("Frame",{BackgroundColor3=C.DROP_BG,BorderSizePixel=0,Visible=false,ZIndex=100,Parent=Library._mainGui})
            corner(lf,6) stroke(lf,C.DROP_BORDER)
            local ls=newI("ScrollingFrame",{Size=UDim2.new(1,-2,1,-2),Position=UDim2.new(0,1,0,1),BackgroundTransparency=1,ScrollBarThickness=3,ScrollBarImageColor3=C.ACCENT,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=101,Parent=lf})
            listL(ls,Enum.FillDirection.Vertical,1) pad(ls,4,4,4,4)

            local function rebuild()
                for _,c3 in ipairs(ls:GetChildren()) do if c3:IsA("TextButton") then c3:Destroy() end end
                for _,v in ipairs(vals) do
                    local sel=multi and (cur[v]==true) or (cur==v)
                    local it=newI("TextButton",{Size=UDim2.new(1,0,0,30),BackgroundColor3=sel and C.DROP_HOVER or C.DROP_ITEM,Text="",ZIndex=102,Parent=ls})
                    corner(it,4)
                    lbl(it,v,12,sel and C.ACCENT or C.NAV_TEXT,Enum.TextXAlignment.Left,{Position=UDim2.new(0,8,0,0),Size=UDim2.new(1,-8,1,0),ZIndex=103})
                    it.MouseEnter:Connect(function() if not sel then tw(it,{BackgroundColor3=C.DROP_HOVER},0.07) end end)
                    it.MouseLeave:Connect(function() if not sel then tw(it,{BackgroundColor3=C.DROP_ITEM},0.07) end end)
                    it.MouseButton1Click:Connect(function()
                        if multi then cur[v]=not cur[v] else cur=v end
                        obj.Value=cur dlbl.Text=dispTxt()
                        for _,cb in ipairs(cbs) do pcall(cb,cur) end
                        rebuild()
                        if not multi then lf.Visible=false end
                    end)
                end
            end
            rebuild()
            local open2=false
            db.MouseButton1Click:Connect(function()
                open2=not open2
                if open2 then rebuild() local ap=db.AbsolutePosition local as2=db.AbsoluteSize local ic=math.min(#vals,6) lf.Position=UDim2.new(0,ap.X,0,ap.Y+as2.Y+4) lf.Size=UDim2.new(0,as2.X,0,ic*31+8) end
                lf.Visible=open2
            end)
            UserInputService.InputBegan:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1 and open2 then
                    local mp=UserInputService:GetMouseLocation() local ap=lf.AbsolutePosition local as2=lf.AbsoluteSize
                    if mp.X<ap.X or mp.X>ap.X+as2.X or mp.Y<ap.Y or mp.Y>ap.Y+as2.Y then open2=false lf.Visible=false end
                end
            end)
            function obj:SetValue(v) cur=v self.Value=v dlbl.Text=dispTxt() end
            function obj:SetValues(nv) vals=nv self._vals=nv cur=nv[1] or "" self.Value=cur dlbl.Text=dispTxt() rebuild() end
            function obj:SetVisible(vis) row.Visible=vis self._visible=vis end
            function obj:OnChanged(cb) table.insert(cbs,cb) return obj end
            Library.Options[id]=obj return obj
        end

        function Tab:AddSlider(id,opts)
            opts=opts or {}
            local mn=opts.Min or 0 local mx=opts.Max or 100 local dv=opts.Default or mn local rd=opts.Rounding or 0
            local cbs={} local val=dv
            local obj={Value=val,_cbs=cbs}
            local row,cf=makeRow(opts.Text,opts.Subtitle)
            local sh2=8
            local trk=newI("Frame",{Size=UDim2.new(1,0,0,sh2),Position=UDim2.new(0,0,0.5,-sh2/2),BackgroundColor3=C.SLIDER_BG,Parent=cf})
            corner(trk,sh2/2)
            local fil=newI("Frame",{Size=UDim2.new((val-mn)/(mx-mn),0,1,0),BackgroundColor3=C.SLIDER_FILL,BorderSizePixel=0,Parent=trk})
            corner(fil,sh2/2)
            local vl=lbl(cf,tostring(val),11,C.ACCENT,Enum.TextXAlignment.Right,{Position=UDim2.new(0,0,0,-17),Size=UDim2.new(1,0,0,13)})
            local ts=14
            local th3=newI("Frame",{Size=UDim2.new(0,ts,0,ts),BackgroundColor3=Color3.new(1,1,1),ZIndex=2,Parent=trk})
            corner(th3,ts/2)
            local function upd(v)
                v=math.clamp(v,mn,mx) if rd==0 then v=math.floor(v+0.5) else v=math.floor(v*(10^rd)+0.5)/(10^rd) end
                val=v obj.Value=v local p=(v-mn)/(mx-mn)
                tw(fil,{Size=UDim2.new(p,0,1,0)},0.05) th3.Position=UDim2.new(p,-ts/2,0.5,-ts/2) vl.Text=tostring(v)
                for _,cb in ipairs(cbs) do pcall(cb,v) end
            end
            upd(dv)
            local sliding=false
            trk.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=true local r=i.Position.X-trk.AbsolutePosition.X upd(mn+(r/trk.AbsoluteSize.X)*(mx-mn)) end end)
            trk.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=false end end)
            UserInputService.InputChanged:Connect(function(i) if sliding and i.UserInputType==Enum.UserInputType.MouseMovement then local r=i.Position.X-trk.AbsolutePosition.X upd(mn+(r/trk.AbsoluteSize.X)*(mx-mn)) end end)
            function obj:OnChanged(cb) table.insert(cbs,cb) return obj end
            Library.Options[id]=obj return obj
        end

        function Tab:AddInput(id,opts)
            opts=opts or {}
            local cbs={} local obj={Value=opts.Default or "",_cbs=cbs}
            local row,cf=makeRow(opts.Text,opts.Subtitle)
            local ih=28
            local ib=newI("TextBox",{Size=UDim2.new(1,0,0,ih),Position=UDim2.new(0,0,0.5,-ih/2),BackgroundColor3=C.INPUT_BG,TextColor3=C.NAV_TEXT,PlaceholderColor3=C.SUB_TEXT,PlaceholderText=opts.Placeholder or "",Text=opts.Default or "",TextSize=12,Font=Enum.Font.Gotham,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,Parent=cf})
            corner(ib,5) stroke(ib,C.INPUT_BORDER) pad(ib,0,0,8,0)
            ib.FocusLost:Connect(function() obj.Value=ib.Text for _,cb in ipairs(cbs) do pcall(cb,ib.Text) end end)
            function obj:OnChanged(cb) table.insert(cbs,cb) return obj end
            Library.Options[id]=obj return obj
        end

        function Tab:AddButton(opts)
            opts=opts or {}
            local row,cf=makeRow(opts.Text,opts.Subtitle)
            local bh2=30
            local b=newI("TextButton",{Size=UDim2.new(0,110,0,bh2),Position=UDim2.new(1,-110,0.5,-bh2/2),BackgroundColor3=C.BTN_BG,Text=opts.Text or "Click",TextColor3=C.BTN_TEXT,TextSize=12,Font=Enum.Font.GothamSemibold,Parent=cf})
            corner(b,6)
            b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=C.BTN_HOVER},0.08) end)
            b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=C.BTN_BG},0.08) end)
            b.MouseButton1Click:Connect(function() tw(b,{BackgroundColor3=C.ACCENT},0.05) task.delay(0.12,function() tw(b,{BackgroundColor3=C.BTN_BG},0.1) end) if opts.Func then pcall(opts.Func) end end)
            return b
        end

        function Tab:AddLabel(text, isSub)
            if isSub then return end
            local lr=newI("Frame",{Size=UDim2.new(1,0,0,34),BackgroundColor3=Color3.fromRGB(30,30,33),BorderSizePixel=0,Parent=page})
            corner(lr,6) pad(lr,0,0,14,14)
            local l2=lbl(lr,text,12,C.ACCENT) l2.Size=UDim2.new(1,0,1,0)
            newI("Frame",{Size=UDim2.new(1,0,0,4),BackgroundTransparency=1,Parent=page})
            local lo={} function lo:SetText(t) l2.Text=t end return lo
        end

        function Tab:AddDivider()
            newI("Frame",{Size=UDim2.new(1,-32,0,1),BackgroundColor3=C.DIVIDER,BorderSizePixel=0,Parent=page})
            newI("Frame",{Size=UDim2.new(1,0,0,6),BackgroundTransparency=1,Parent=page})
        end

        function Tab:AddKeyPicker(id,opts)
            opts=opts or {}
            local ko={Value=opts.Default or "RightControl",_cbs={}}
            Library.Options[id]=ko
            local row,cf=makeRow("Menu Keybind","Press to open / close the GUI.")
            local bh3=28
            local kb=newI("TextButton",{Size=UDim2.new(0,130,0,bh3),Position=UDim2.new(1,-130,0.5,-bh3/2),BackgroundColor3=C.BTN_BG,Text=ko.Value,TextColor3=C.ACCENT,TextSize=12,Font=Enum.Font.GothamBold,Parent=cf})
            corner(kb,5) stroke(kb,C.INPUT_BORDER)
            local listening=false
            kb.MouseButton1Click:Connect(function() listening=true kb.Text="..." kb.TextColor3=C.SUB_TEXT end)
            UserInputService.InputBegan:Connect(function(i)
                if listening and i.UserInputType==Enum.UserInputType.Keyboard then
                    listening=false ko.Value=i.KeyCode.Name kb.Text=i.KeyCode.Name kb.TextColor3=C.ACCENT
                end
            end)
            function ko:OnChanged(cb) table.insert(self._cbs,cb) end
            return ko
        end

        -- Groupbox stubs (flat layout — all elements go into tab directly)
        function Tab:AddLeftGroupbox(_) return self end
        function Tab:AddRightGroupbox(_) return self end

        return Tab
    end -- end _makeTab

    function Win:AddTab(name,_) return self:_makeTab(name) end
    return Win
end -- end CreateWindow

-- ThemeManager & SaveManager stubs
local TM={} function TM:SetLibrary(_) end function TM:SetFolder(_) end function TM:ApplyTheme(_) end function TM:ApplyToTab(_) end
local SM={} function SM:SetLibrary(_) end function SM:SetFolder(_) end function SM:BuildConfigSection(_) end function SM:LoadAutoloadConfig() end

return Library, TM, SM
end)()

local Options = Library.Options
local Toggles = Library.Toggles

-- ==========================================
-- TEKKIT HUB WINDOW + SIDEBAR SECTIONS
-- ==========================================

local Window = Library:CreateWindow({
	Title = "Tekkit Hub",
	Footer = "AOT:R  •  v2.0",
})

-- In-Game section
local SecInGame  = Window:AddSection("In-Game")
local TabFarming = SecInGame:AddTab("Farming")
local TabIGSet   = SecInGame:AddTab("Settings")

-- Lobby section
local SecLobby   = Window:AddSection("Lobby")
local TabLobAuto = SecLobby:AddTab("Automation")
local TabLobSet  = SecLobby:AddTab("Settings")

-- Main Menu section
local SecMenu    = Window:AddSection("Main Menu")
local TabMenuAuto = SecMenu:AddTab("Automation")
local TabMenuSet  = SecMenu:AddTab("Settings")

-- Group aliases (AddLeftGroupbox/AddRightGroupbox both return same Tab)
local MainGroup      = TabFarming:AddLeftGroupbox("Farm")
local AutoStartGroup = TabFarming:AddRightGroupbox("Auto Start")

local SettingsGroup  = TabIGSet:AddLeftGroupbox("Settings")
local WebhookGroup   = TabIGSet:AddRightGroupbox("Webhook")

local UpgradesGroup  = TabLobAuto:AddLeftGroupbox("Upgrades")
local SkillTreeGroup = TabLobAuto:AddRightGroupbox("Skill Tree")

local SlotGroup       = TabLobSet:AddLeftGroupbox("Slot")
local FamilyRollGroup = TabLobSet:AddRightGroupbox("Family Roll")

-- ==========================================
-- IN-GAME › FARMING TAB : Farm Groupbox
-- (Tekkit Hub style — subtitle labels under each item)
-- ==========================================
getgenv().CurrentStatusLabel = MainGroup:AddLabel("Status: Idle")

MainGroup:AddToggle("AutoKillToggle", {
	Text = "Auto Farm",
	Default = false,
})
MainGroup:AddLabel("Automatically kills titans and collects rewards.", true)
Toggles.AutoKillToggle:OnChanged(function()
	if Toggles.AutoKillToggle.Value then AutoFarm:Start() else AutoFarm:Stop() end
end)

MainGroup:AddToggle("MasteryFarmToggle", {
	Text = "Titan Mastery Farm",
	Default = false,
})
MainGroup:AddLabel("Farms titan mastery XP via punching or skills.", true)
Toggles.MasteryFarmToggle:OnChanged(function()
	getgenv().MasteryFarmConfig.Enabled = Toggles.MasteryFarmToggle.Value
	if Toggles.MasteryFarmToggle.Value then
		if not Toggles.AutoKillToggle.Value then
			Toggles.AutoKillToggle:SetValue(true)
		elseif not AutoFarm._running then
			AutoFarm:Start()
		end
	end
end)

MainGroup:AddDropdown("MasteryModeDropdown", {
	Values = {"Punching", "Skill Usage", "Both"},
	Default = 3,
	Multi = false,
	Text = "Mastery Mode",
})
MainGroup:AddLabel("Choose how mastery XP is farmed.", true)
Options.MasteryModeDropdown:OnChanged(function()
	getgenv().MasteryFarmConfig.Mode = Options.MasteryModeDropdown.Value
end)

MainGroup:AddDropdown("MovementModeDropdown", {
	Values = {"Hover", "Teleport"},
	Default = 1,
	Multi = false,
	Text = "Movement Mode",
})
MainGroup:AddLabel("How the bot moves toward titans.", true)
Options.MovementModeDropdown:OnChanged(function()
	getgenv().AutoFarmConfig.MovementMode = Options.MovementModeDropdown.Value
end)

MainGroup:AddDropdown("FarmOptionsDropdown", {
	Values = {"Auto Execute", "Failsafe", "Open Second Chest"},
	Default = {},
	Multi = true,
	Text = "Farm Options",
})
MainGroup:AddLabel("Extra options applied during farming.", true)
Options.FarmOptionsDropdown:OnChanged(function()
	local vals = Options.FarmOptionsDropdown.Value
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
MainGroup:AddLabel("Speed at which the bot hovers to titans.", true)
Options.HoverSpeedSlider:OnChanged(function()
	getgenv().AutoFarmConfig.MoveSpeed = Options.HoverSpeedSlider.Value
end)

MainGroup:AddSlider("FloatHeightSlider", {
	Text = "Float Height",
	Default = 250,
	Min = 100,
	Max = 300,
	Rounding = 0,
})
MainGroup:AddLabel("Height above ground while hovering.", true)
Options.FloatHeightSlider:OnChanged(function()
	getgenv().AutoFarmConfig.HeightOffset = Options.FloatHeightSlider.Value
end)

MainGroup:AddToggle("AutoReloadToggle", {
	Text = "Auto Reload / Refill",
	Default = false,
})
MainGroup:AddLabel("Automatically reloads blades and refills gas.", true)
Toggles.AutoReloadToggle:OnChanged(function()
	autoReloadEnabled = Toggles.AutoReloadToggle.Value
	autoRefillEnabled = Toggles.AutoReloadToggle.Value
end)

MainGroup:AddToggle("AutoEscapeToggle", {
	Text = "Auto Escape",
	Default = false,
})
MainGroup:AddLabel("Escapes titan grabs automatically.", true)
Toggles.AutoEscapeToggle:OnChanged(function()
	getgenv().AutoEscape = Toggles.AutoEscapeToggle.Value
end)

MainGroup:AddToggle("AutoSkipToggle", {
	Text = "Auto Skip Cutscenes",
	Default = false,
})
MainGroup:AddLabel("Skips mission cutscenes to save time.", true)
Toggles.AutoSkipToggle:OnChanged(function()
	getgenv().AutoSkip = Toggles.AutoSkipToggle.Value
	if getgenv().AutoSkip then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("AutoRetryToggle", {
	Text = "Auto Retry",
	Default = false,
})
MainGroup:AddLabel("Retries the mission after completion or failure.", true)
Toggles.AutoRetryToggle:OnChanged(function()
	getgenv().AutoRetry = Toggles.AutoRetryToggle.Value
	if getgenv().AutoRetry then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("AutoChestToggle", {
	Text = "Auto Open Chests",
	Default = false,
})
MainGroup:AddLabel("Automatically opens chests at end of mission.", true)
Toggles.AutoChestToggle:OnChanged(function()
	getgenv().AutoChest = Toggles.AutoChestToggle.Value
	if getgenv().AutoChest then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("DeleteMapToggle", {
	Text = "Delete Map (FPS Boost)",
	Default = DropdownConfig.DeleteMap or false,
})
MainGroup:AddLabel("Removes map geometry for better performance.", true)
Toggles.DeleteMapToggle:OnChanged(function()
	getgenv().DeleteMap = Toggles.DeleteMapToggle.Value
	DropdownConfig.DeleteMap = getgenv().DeleteMap
	SaveConfig(DropdownConfig)
	if getgenv().DeleteMap then DeleteMap() end
end)

MainGroup:AddToggle("SoloOnlyToggle", {
	Text = "Solo Only",
	Default = false,
})
Toggles.SoloOnlyToggle:OnChanged(function()
	getgenv().SoloOnly = Toggles.SoloOnlyToggle.Value
end)
MainGroup:AddLabel("Only farms when no other players are present.", true)

MainGroup:AddToggle("AutoReturnLobbyToggle", {
	Text = "Auto Return to Lobby",
	Default = false,
})
MainGroup:AddLabel("Returns to lobby after timeout or mission end.", true)
Toggles.AutoReturnLobbyToggle:OnChanged(function()
	getgenv().AutoReturnLobby = Toggles.AutoReturnLobbyToggle.Value
	if not getgenv().AutoReturnLobby then
		pcall(function() writefile(returnCounterPath, "0") end)
	end
end)

-- ==========================================
-- IN-GAME › FARMING TAB : Auto Start Groupbox
-- ==========================================

AutoStartGroup:AddButton({
	Text = "Return to Lobby",
	Func = function()
		getRemote:InvokeServer("Functions", "Teleport", "Lobby")
		TeleportService:Teleport(14916516914, lp)
	end,
})
AutoStartGroup:AddLabel("Teleports you back to the main lobby.", true)

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
AutoStartGroup:AddLabel("Copies the community Discord invite link.", true)

AutoStartGroup:AddToggle("AutoStartToggle", {
	Text = "Auto Start",
	Default = false,
})
AutoStartGroup:AddLabel("Automatically creates and starts missions.", true)
Toggles.AutoStartToggle:OnChanged(function()
	getgenv().AutoStart = Toggles.AutoStartToggle.Value

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

				local missionType = Options.StartTypeDropdown.Value
				local selectedDifficulty
				local mapName
				local objective

				if missionType == "Missions" then
					selectedDifficulty = Options.MissionDifficultyDropdown.Value
					mapName = Options.MissionMapDropdown.Value
					objective = Options.MissionObjectiveDropdown.Value
				else
					selectedDifficulty = Options.RaidDifficultyDropdown.Value
					mapName = Options.RaidMapDropdown.Value
					objective = Options.RaidObjectiveDropdown.Value
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
						Toggles.AutoStartToggle:SetValue(false)
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
				if Options.ModifiersDropdown.Value then
					for modName, isActive in pairs(Options.ModifiersDropdown.Value) do
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
	Default = DropdownConfig._lastType and table.find({"Missions", "Raids"}, DropdownConfig._lastType) or 1,
	Multi = false,
	Text = "Type",
})
AutoStartGroup:AddLabel("Choose between Missions or Raids.", true)
Options.StartTypeDropdown:OnChanged(function()
	local Value = Options.StartTypeDropdown.Value
	if not Value then return end
	
	DropdownConfig._lastType = Value
	SaveConfig(DropdownConfig)

	local isMission = Value == "Missions"
	Options.MissionMapDropdown:SetVisible(isMission)
	Options.MissionObjectiveDropdown:SetVisible(isMission)
	Options.MissionDifficultyDropdown:SetVisible(isMission)

	Options.RaidMapDropdown:SetVisible(not isMission)
	Options.RaidObjectiveDropdown:SetVisible(not isMission)
	Options.RaidDifficultyDropdown:SetVisible(not isMission)
end)

AutoStartGroup:AddDropdown("MissionMapDropdown", {
	Values = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"},
	Default = DropdownConfig.Missions and table.find({"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"}, DropdownConfig.Missions.map) or 1,
	Multi = false,
	Text = "Mission Map",
})
AutoStartGroup:AddLabel("The map your mission will take place on.", true)
Options.MissionMapDropdown:OnChanged(function()
	local Value = Options.MissionMapDropdown.Value
	if not Value then return end
	Options.MissionObjectiveDropdown:SetValues(Missions[Value] or {})
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.map = Value
	SaveConfig(DropdownConfig)
end)

local initMissionMap = DropdownConfig.Missions and DropdownConfig.Missions.map or "Shiganshina"
local initMissionObjVals = Missions[initMissionMap] or {}
local initMissionObjDef = 1
if DropdownConfig.Missions and DropdownConfig.Missions.objective then
	initMissionObjDef = table.find(initMissionObjVals, DropdownConfig.Missions.objective) or 1
end

AutoStartGroup:AddDropdown("MissionObjectiveDropdown", {
	Values = initMissionObjVals,
	Default = initMissionObjDef,
	Multi = false,
	Text = "Mission Objective",
})
AutoStartGroup:AddLabel("The objective type for your mission.", true)
Options.MissionObjectiveDropdown:OnChanged(function()
	local Value = Options.MissionObjectiveDropdown.Value
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.objective = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDropdown("MissionDifficultyDropdown", {
	Values = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
	Default = DropdownConfig.Missions and table.find({"Easy","Normal","Hard","Severe","Aberrant","Hardest"}, DropdownConfig.Missions.difficulty) or 2,
	Multi = false,
	Text = "Mission Difficulty",
})
AutoStartGroup:AddLabel("Hardest tries all difficulties until one works.", true)
Options.MissionDifficultyDropdown:OnChanged(function()
	local Value = Options.MissionDifficultyDropdown.Value
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.difficulty = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDivider()

AutoStartGroup:AddDropdown("RaidMapDropdown", {
	Values = {"Trost","Shiganshina","Stohess"},
	Default = DropdownConfig.Raids and table.find({"Trost","Shiganshina","Stohess"}, DropdownConfig.Raids.map) or 1,
	Multi = false,
	Text = "Raid Map",
})
AutoStartGroup:AddLabel("Trost: Attack  •  Shiganshina: Armored  •  Stohess: Female", true)
Options.RaidMapDropdown:OnChanged(function()
	local Value = Options.RaidMapDropdown.Value
	if not Value then return end
	Options.RaidObjectiveDropdown:SetValues(Missions[Value] or {})
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.map = Value
	SaveConfig(DropdownConfig)
end)

local initRaidMap = DropdownConfig.Raids and DropdownConfig.Raids.map or "Trost"
local initRaidObjVals = Missions[initRaidMap] or {}
local initRaidObjDef = 1
if DropdownConfig.Raids and DropdownConfig.Raids.objective then
	initRaidObjDef = table.find(initRaidObjVals, DropdownConfig.Raids.objective) or 1
end

AutoStartGroup:AddDropdown("RaidObjectiveDropdown", {
	Values = initRaidObjVals,
	Default = initRaidObjDef,
	Multi = false,
	Text = "Raid Objective",
})
AutoStartGroup:AddLabel("The objective for the selected raid map.", true)
Options.RaidObjectiveDropdown:OnChanged(function()
	local Value = Options.RaidObjectiveDropdown.Value
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.objective = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDropdown("RaidDifficultyDropdown", {
	Values = {"Hard","Severe","Aberrant","Hardest"},
	Default = DropdownConfig.Raids and table.find({"Hard","Severe","Aberrant","Hardest"}, DropdownConfig.Raids.difficulty) or 1,
	Multi = false,
	Text = "Raid Difficulty",
})
AutoStartGroup:AddLabel("Hardest tries all raid difficulties descending.", true)
Options.RaidDifficultyDropdown:OnChanged(function()
	local Value = Options.RaidDifficultyDropdown.Value
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.difficulty = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDivider()

AutoStartGroup:AddDropdown("ModifiersDropdown", {
	Values = {"No Perks","No Skills","No Talents","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"},
	Default = {},
	Multi = true,
	Text = "Modifiers",
})
AutoStartGroup:AddLabel("Optional challenge modifiers applied at mission start.", true)

-- Trigger type initialization
task.defer(function()
	task.wait(0.2)
	local savedType = DropdownConfig._lastType or "Missions"
	Options.StartTypeDropdown:SetValue(savedType)
end)

-- ==========================================
-- LOBBY › AUTOMATION TAB : Upgrades Groupbox
-- ==========================================

UpgradesGroup:AddToggle("AutoUpgradeToggle", {
	Text = "Upgrade Gear",
	Default = false,
})
UpgradesGroup:AddLabel("Automatically upgrades your gear with Gold.", true)
Toggles.AutoUpgradeToggle:OnChanged(function()
	getgenv().AutoUpgrade = Toggles.AutoUpgradeToggle.Value
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
UpgradesGroup:AddLabel("Feeds lower-rarity perks into your equipped perk.", true)
Toggles.AutoEnhanceToggle:OnChanged(function()
	getgenv().AutoPerk = Toggles.AutoEnhanceToggle.Value
	if getgenv().AutoPerk then
		if game.PlaceId ~= 14916516914 then return end
		task.spawn(function()
			local plrData = GetPlayerData()
			if not plrData or not plrData.Slots then return end
			local slotIndex = lp:GetAttribute("Slot")
			if not slotIndex or not plrData.Slots[slotIndex] then
				getgenv().AutoPerk = false
				Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local slot = plrData.Slots[slotIndex]
			local storagePerks = {}
			for id, val in pairs(slot.Perks.Storage) do storagePerks[id] = val end

			local perkSlot = Options.PerkSlotDropdown.Value
			local equippedPerkId = slot.Perks.Equipped[perkSlot]
			if not equippedPerkId then
				Library:Notify({ Title = "Auto Perk", Description = "No perk equipped in " .. tostring(perkSlot) .. " slot.", Time = 3 })
				getgenv().AutoPerk = false
				Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local perkData = storagePerks[equippedPerkId]
			if not perkData then
				Library:Notify({ Title = "Auto Perk", Description = "Equipped perk data not found.", Time = 3 })
				getgenv().AutoPerk = false
				Toggles.AutoEnhanceToggle:SetValue(false)
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

				local selectedRarities = Options.SelectPerksDropdown.Value
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
			Toggles.AutoEnhanceToggle:SetValue(false)
		end)
	end
end)

UpgradesGroup:AddDropdown("PerkSlotDropdown", {
	Values = {"Defense", "Support", "Family", "Extra", "Offense", "Body"},
	Default = 6,
	Multi = false,
	Text = "Perk Slot",
})
UpgradesGroup:AddLabel("The equipped perk slot to enhance. Default: Body.", true)

UpgradesGroup:AddDropdown("SelectPerksDropdown", {
	Values = {"Common", "Rare", "Epic", "Legendary"},
	Default = {},
	Multi = true,
	Text = "Perks to use as Food",
})
UpgradesGroup:AddLabel("Rarities of perks to sacrifice as enhancement food.", true)

-- ==========================================
-- LOBBY › AUTOMATION TAB : Skill Tree Groupbox
-- ==========================================

SkillTreeGroup:AddToggle("AutoSkillTree", {
	Text = "Auto Skill Tree",
	Default = false,
})
SkillTreeGroup:AddLabel("Automatically unlocks skill tree nodes in priority order.", true)
Toggles.AutoSkillTree:OnChanged(function()
	getgenv().AutoSkillTree = Toggles.AutoSkillTree.Value
	local plrData = GetPlayerData()

	if getgenv().AutoSkillTree then
		if game.PlaceId ~= 14916516914 then return end
		if not plrData or not plrData.Slots then return end
		task.spawn(function()
			while getgenv().AutoSkillTree do
				local slotIndex = lp:GetAttribute("Slot")
				if not slotIndex or not plrData.Slots[slotIndex] then task.wait(1) continue end
				local weapon = plrData.Slots[slotIndex].Weapon

				local middle = Options.MiddlePathDropdown.Value
				local left = Options.LeftPathDropdown.Value
				local right = Options.RightPathDropdown.Value

				local middlePath = SkillPaths[weapon] and SkillPaths[weapon][middle]
				local leftPath = SkillPaths.Support[left]
				local rightPath = SkillPaths.Defense[right]

				local p1 = Options.Priority1Dropdown.Value or "Middle"
				local p2 = Options.Priority2Dropdown.Value or "Left"
				local p3 = Options.Priority3Dropdown.Value or "None"

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
	Default = 2,
	Multi = false,
	Text = "Middle Path",
})
SkillTreeGroup:AddLabel("Weapon-specific offensive skill path.", true)

SkillTreeGroup:AddDropdown("LeftPathDropdown", {
	Values = {"Regen", "Cooldown Reduction"},
	Default = 2,
	Multi = false,
	Text = "Left Path",
})
SkillTreeGroup:AddLabel("Support path for sustain or cooldowns.", true)

SkillTreeGroup:AddDropdown("RightPathDropdown", {
	Values = {"Health", "Damage Reduction"},
	Default = 2,
	Multi = false,
	Text = "Right Path",
})
SkillTreeGroup:AddLabel("Defense path for survivability.", true)

SkillTreeGroup:AddDropdown("Priority1Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = 2,
	Multi = false,
	Text = "Priority 1",
})
SkillTreeGroup:AddLabel("First path to unlock skills in.", true)

SkillTreeGroup:AddDropdown("Priority2Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = 1,
	Multi = false,
	Text = "Priority 2",
})
SkillTreeGroup:AddLabel("Second path once Priority 1 is complete.", true)

SkillTreeGroup:AddDropdown("Priority3Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = 4,
	Multi = false,
	Text = "Priority 3",
})
SkillTreeGroup:AddLabel("Final path, or set to None to skip.", true)

-- ==========================================
-- LOBBY › SETTINGS TAB : Slot Groupbox
-- ==========================================

SlotGroup:AddToggle("AutoSelectSlot", {
	Text = "Auto Select Slot",
	Default = false,
})
SlotGroup:AddLabel("Automatically selects and loads your chosen slot.", true)
Toggles.AutoSelectSlot:OnChanged(function()
	getgenv().AutoSlot = Toggles.AutoSelectSlot.Value
	if getgenv().AutoSlot and not lp:GetAttribute("Slot") then
		local selectedSlot = Options.SelectSlotDropdown.Value
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
	Default = 1,
	Multi = false,
	Text = "Select Slot",
})
SlotGroup:AddLabel("The save slot to auto-select on join.", true)

SlotGroup:AddToggle("AutoPrestigeToggle", {
	Text = "Auto Prestige",
	Default = false,
})
SlotGroup:AddLabel("Automatically Prestiges after you hit the Lvl Max.", true)
Toggles.AutoPrestigeToggle:OnChanged(function()
	getgenv().AutoPrestige = Toggles.AutoPrestigeToggle.Value
	if getgenv().AutoPrestige then
		if game.PlaceId ~= 14916516914 then return end
		task.spawn(function()
			local pData = GetPlayerData()
			if not pData or not pData.Slots then return end
			local slotIdx = lp:GetAttribute("Slot")
			if not slotIdx or not pData.Slots[slotIdx] then return end
			local gold = pData.Slots[slotIdx].Currency.Gold
			local requiredGold = Options.PrestigeGoldSlider.Value * 1000000

			if gold < requiredGold then return end

			while getgenv().AutoPrestige do
				for _, Memory in ipairs(Talents) do
					if not getgenv().AutoPrestige then break end
					local success = getRemote:InvokeServer("S_Equipment", "Prestige", {Boosts = Options.SelectBoostDropdown.Value, Talents = Memory})
					if success then
						Library:Notify({
							Title = "Successfully Prestiged",
							Description = "Prestiged with " .. Options.SelectBoostDropdown.Value .. " and " .. Memory,
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
	Default = 1,
	Multi = false,
	Text = "Prestige Boost",
})
SlotGroup:AddLabel("The boost you want to apply when prestiging.", true)

SlotGroup:AddSlider("PrestigeGoldSlider", {
	Text = "Prestige Gold (in millions)",
	Default = 0,
	Min = 0,
	Max = 100,
	Rounding = 0,
})
SlotGroup:AddLabel("Minimum Gold required before Auto Prestige fires.", true)

-- ==========================================
-- LOBBY › SETTINGS TAB : Family Roll Groupbox
-- ==========================================

FamilyRollGroup:AddToggle("AutoRollToggle", {
	Text = "Auto Roll",
	Default = false,
})
FamilyRollGroup:AddLabel("Rolls for families until a target or rarity is hit.", true)
Toggles.AutoRollToggle:OnChanged(function()
	getgenv().AutoRoll = Toggles.AutoRollToggle.Value
	if getgenv().AutoRoll then
		if game.PlaceId ~= 13379208636 then
			Library:Notify({
				Title = "Tekkit Hub",
				Description = "You must be in the lobby to use family roll features.",
				Time = 3
			})
			return
		end
		task.spawn(function()
			while getgenv().AutoRoll do
				local targets, rarities

				local text = Options.SelectFamily.Value
				if text and text ~= "" then
					text = string.lower(text)
					targets = string.split(text, ",")
				end

				local raritySelected = Options.SelectFamilyRarity.Value
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
	Text = "Target Families",
	Placeholder = "Fritz,Yeager,etc.",
})
FamilyRollGroup:AddLabel("Stop rolling when one of these families is hit.", true)
Options.SelectFamily:OnChanged(function()
	if Options.SelectFamily.Value ~= "" then
		Library:Notify({
			Title = "Tekkit Hub",
			Description = "Families selected: " .. Options.SelectFamily.Value,
			Time = 2
		})
	end
end)

FamilyRollGroup:AddDropdown("SelectFamilyRarity", {
	Values = familyRaritiesOptions,
	Default = {},
	Multi = true,
	Text = "Stop At Rarity",
})
FamilyRollGroup:AddLabel("Stops rolling when this rarity or higher is obtained. Mythicals are never rolled. Separate families with commas, no spaces.", true)

-- ==========================================
-- IN-GAME SETTINGS TAB : Settings & Webhook Groupboxes
-- ==========================================

WebhookGroup:AddToggle("ToggleRewardWebhook", {
	Text = "Reward Webhook",
	Default = false,
})
WebhookGroup:AddLabel("Sends a Discord webhook when rewards are received.", true)
Toggles.ToggleRewardWebhook:OnChanged(function()
	getgenv().RewardWebhook = Toggles.ToggleRewardWebhook.Value
end)

WebhookGroup:AddToggle("ToggleMythicalFamilyWebhook", {
	Text = "Mythical Family Webhook",
	Default = false,
})
WebhookGroup:AddLabel("Sends a webhook when a Mythical family is rolled.", true)
Toggles.ToggleMythicalFamilyWebhook:OnChanged(function()
	getgenv().MythicalFamilyWebhook = Toggles.ToggleMythicalFamilyWebhook.Value
end)

WebhookGroup:AddInput("WebhookUrl", {
	Default = "",
	Text = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
})
WebhookGroup:AddLabel("Your Discord webhook URL for notifications.", true)
Options.WebhookUrl:OnChanged(function()
	webhook = Options.WebhookUrl.Value
end)

SettingsGroup:AddToggle("AutoHideToggle", {
	Text = "Auto Hide GUI",
	Default = false,
})
SettingsGroup:AddLabel("Hides the GUI automatically after loading.", true)

SettingsGroup:AddToggle("Disable3DRendering", {
	Text = "Disable 3D Rendering (FPS Boost)",
	Default = false,
})
SettingsGroup:AddLabel("Stops 3D scene rendering for a significant FPS boost.", true)
Toggles.Disable3DRendering:OnChanged(function()
	RunService:Set3dRenderingEnabled(not Toggles.Disable3DRendering.Value)
end)

SettingsGroup:AddLabel("Menu toggle"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind

-- Keybind toggle handler
game:GetService("UserInputService").InputBegan:Connect(function(inp, gp)
	if gp then return end
	if Library.ToggleKeybind and inp.KeyCode.Name == Library.ToggleKeybind.Value then
		Library:Toggle()
	end
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetFolder("UsSuite/aotr")
SaveManager:SetFolder("UsSuite/aotr")

-- Use In-Game Settings tab for config & theme
SaveManager:BuildConfigSection(TabIGSet)
ThemeManager:ApplyToTab(TabIGSet)

ThemeManager:ApplyTheme("Dark")
SaveManager:LoadAutoloadConfig()

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

-- Auto Hide Logic
task.spawn(function()
	task.wait(0.5) -- Wait for config load
	if getgenv().DeleteMap then DeleteMap() end
	if Toggles.AutoHideToggle.Value then
		Library:Toggle(false)
		Library:Notify({
			Title = "Tekkit Hub",
			Description = "GUI auto-hidden. Press RightControl to show.",
			Time = 2
		})
	end
end)
