-- TITANIC HUB | AOT:R | Rayfield UI
-- Discord: https://discord.gg/Cczp9ZWxvY

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

repeat task.wait() until lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local TeleportService    = game:GetService("TeleportService")
local GuiService         = game:GetService("GuiService")
local HttpService        = game:GetService("HttpService")
local PlayerGui          = lp:WaitForChild("PlayerGui")
local remotesFolder      = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local getRemote          = remotesFolder:WaitForChild("GET")
local postRemote         = remotesFolder:WaitForChild("POST")
local vim                = game:GetService("VirtualInputManager")
local INTERFACE          = PlayerGui:WaitForChild("Interface")
local rewards            = INTERFACE:FindFirstChild("Rewards")
local statsFrame         = rewards and rewards.Main.Info.Main.Stats or nil
local itemsFrame         = rewards and rewards.Main.Info.Main.Items or nil
local customisation      = INTERFACE:FindFirstChild("Customisation") or nil
local familyFrame        = customisation and customisation:FindFirstChild("Family") or nil
local rollButton         = familyFrame and familyFrame.Buttons_2.Roll or nil
local V3_ZERO            = Vector3.new(0, 0, 0)

-- ==========================================
-- PLAYER DATA CACHE
-- ==========================================
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
	if not mapData then lastPlayerData = nil; GetPlayerData() end
until mapData ~= nil or (lastPlayerData ~= nil and (isLobby or os.clock() - startLoadTime > 15))

if mapData and mapData.Map and mapData.Map.Type == "Raids" then
	repeat task.wait() until workspace:GetAttribute("Finalised")
end

local function checkMission()
	if workspace:GetAttribute("Type") then return true end
	mapData = getRemote:InvokeServer("Data", "Copy")
	return mapData ~= nil and mapData.Map ~= nil and mapData.Slots ~= nil
end

-- ==========================================
-- CONFIG SYSTEM
-- ==========================================
if not isfolder("./THUB") then makefolder("./THUB") end
if not isfolder("./THUB/aotr") then makefolder("./THUB/aotr") end

local ConfigFile       = "./THUB/aotr/dropdown_config.json"
local returnCounterPath= "./THUB/aotr/return_lobby_counter.txt"

local function LoadConfig()
	if not isfile(ConfigFile) then return { Missions = {}, Raids = {}, DeleteMap = false } end
	local ok, cfg = pcall(HttpService.JSONDecode, HttpService, readfile(ConfigFile))
	return ok and cfg or { Missions = {}, Raids = {}, DeleteMap = false }
end
local function SaveConfig(cfg) pcall(writefile, ConfigFile, HttpService:JSONEncode(cfg)) end

local DropdownConfig = LoadConfig()
if not isfile(returnCounterPath) then writefile(returnCounterPath, "0") end

-- ==========================================
-- GLOBAL FLAGS
-- ==========================================
getgenv().AutoExec             = false
getgenv().AutoRoll             = false
getgenv().AutoSlot             = false
getgenv().AutoUpgrade          = false
getgenv().AutoPerk             = false
getgenv().AutoSkillTree        = false
getgenv().AutoStart            = false
getgenv().AutoChest            = false
getgenv().AutoRetry            = false
getgenv().AutoSkip             = false
getgenv().AutoPrestige         = false
getgenv().AutoFailsafe         = false
getgenv().AutoExecute          = false
getgenv().RewardWebhook        = false
getgenv().MythicalFamilyWebhook= false
getgenv().AutoReturnLobby      = false
getgenv().OpenSecondChest      = false
getgenv().DeleteMap            = DropdownConfig.DeleteMap or false
getgenv().SoloOnly             = false
getgenv().AutoEscape           = false

getgenv().AutoFarmConfig = {
	AttackCooldown = 1,
	ReloadCooldown = 1,
	AttackRange    = 150,
	MoveSpeed      = 400,
	HeightOffset   = 250,
	MovementMode   = "Hover",
}
getgenv().MasteryFarmConfig = { Enabled = false, Mode = "Both" }

-- Runtime dropdown state (replaces Rayfield.Flags dependency)
local State = {
	MasteryMode       = "Both",
	MovementMode      = "Hover",
	FarmOptions       = {},
	StartType         = DropdownConfig._lastType or "Missions",
	MissionMap        = DropdownConfig.Missions and DropdownConfig.Missions.map or "Shiganshina",
	MissionObjective  = DropdownConfig.Missions and DropdownConfig.Missions.objective or "Skirmish",
	MissionDifficulty = DropdownConfig.Missions and DropdownConfig.Missions.difficulty or "Normal",
	RaidMap           = DropdownConfig.Raids and DropdownConfig.Raids.map or "Trost",
	RaidObjective     = DropdownConfig.Raids and DropdownConfig.Raids.objective or "Skirmish",
	RaidDifficulty    = DropdownConfig.Raids and DropdownConfig.Raids.difficulty or "Hard",
	Modifiers         = {},
	SelectSlot        = "Slot A",
	SelectBoost       = "Luck Boost",
	PrestigeGold      = 0,
	PerkSlot          = "Body",
	FoodPerks         = {},
	MiddlePath        = "Critical",
	LeftPath          = "Cooldown Reduction",
	RightPath         = "Health",
	Priority1         = "Middle",
	Priority2         = "Left",
	Priority3         = "None",
	FamilyInput       = "",
	FamilyRarity      = {},
	WebhookUrl        = "",
}

-- Status notify helper (Rayfield labels are static, use notify for status)
local _lastStatus = "Idle"
local function UpdateStatus(text)
	_lastStatus = text
	-- Status is readable via _lastStatus; major changes use Notify
end

-- ==========================================
-- DATA TABLES
-- ==========================================
local familyRaritiesOptions = { "Rare", "Epic", "Legendary", "Mythical" }

local Perks = {
	Legendary = {"Peerless Commander","Indefatigable","Tyrant's Stare","Invincible","Eviscerate","Font of Vitality","Flame Rhapsody","Robust","Sixth Sense","Gear Master","Carnifex","Munitions Master","Sanctified","Wind Rhapsody","Peerless Constitution","Exhumation","Warchief","Peerless Focus","Perfect Form","Courage Catalyst","Aegis","Unparalleled Strength","Perfect Soul"},
	Common    = {"Cripple","Lucky","Enhanced Metabolism","First Aid","Mighty","Fortitude","Hollow","Gear Beginner","Enduring"},
	Epic      = {"Munitions Expert","Gear Expert","Butcher","Resilient","Speedy","Reckless Abandon","Focus","Stalwart Durability","Adrenaline","Safeguard","Warrior","Solo","Mutilate","Trauma Battery","Hardy","Unbreakable","Siphoning","Flawed Release","Luminous","Peerless Strength"},
	Rare      = {"Blessed","Gear Intermediate","Unyielding","Fully Stocked","Forceful","Lightweight","Protection","Mangle","Experimental Shells","Critical Hunter","Tough","Heightened Vitality"},
	Secret    = {"Everlasting Flame","Heavenly Restriction","Adaptation","Maximum Firepower","Soulfeed","Kengo","Black Flash","Font of Inspiration","Explosive Fortune","Immortal","Art of War","Tatsujin","Founder's Blessing"},
}
local PerkRarityMap = {}
for rarity, names in pairs(Perks) do for _, name in pairs(names) do PerkRarityMap[name] = rarity end end

local Talents = {"Blitzblade","Crescendo","Swiftshot","Surgeshot","Guardian","Deflectra","Mendmaster","Cooldown Blitz","Stalwart","Stormcharged","Aegisurge","Riposte","Lifefeed","Vitalize","Gem Fiend","Luck Boost","EXP Boost","Gold Boost","Furyforge","Quakestrike","Assassin","Amputation","Steel Frame","Resilience","Vengeflare","Flashstep","Omnirange","Tactician","Gambler","Overslash","Afterimages","Necromantic","Thanatophobia","Apotheosis","Bloodthief"}

local Perk_Level_XP = {
	Common    = {50,100,150,200,250,300,350,400,450,500},
	Rare      = {125,250,375,500,625,750,875,1000,1125,1250},
	Epic      = {250,500,750,1000,1250,1500,1750,2000,2250,2500},
	Legendary = {500,1000,1500,2000,2500,3000,3500,4000,4500,5000},
	Secret    = {2000,4000,6000,8000,10000,12000,14000,16000,18000,20000},
}
local Perk_Base_XP = { Common=100, Rare=250, Epic=625, Legendary=2500, Secret=10000 }

local Blades_Critical  = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25"}
local Blades_Damage    = {"1","2","3","4","5","6","7","8","9","10","11","12","13","26","27","28","29","30","31","32","33","34","35","36","37"}
local Spears_Critical  = {"113","114","115","116","117","118","119","120","121","122","123","124","125","126","127","128","129","130","131","132","133","134","135","136","137"}
local Spears_Damage    = {"113","114","115","116","117","118","119","120","121","122","123","124","125","138","139","140","141","142","143","144","145","146","147","148","149"}
local Defense_Health   = {"38","39","40","41","42","43","44","45","46","47","48","49","50","51","52","53","54","55","56","57"}
local Defense_DmgRed   = {"38","39","40","41","42","43","44","45","58","59","60","61","62","63","64","65","66","67","68","69"}
local Support_Regen    = {"70","71","72","73","74","75","76","77","78","79","80","81","82","83","84","85","86","87","88","89"}
local Support_CDR      = {"70","71","72","73","74","75","76","77","78","79","80","90","91","92","93","94","95","96","97","98"}

local Missions = {
	["Shiganshina"]  = {"Skirmish","Breach","Random"},
	["Trost"]        = {"Skirmish","Protect","Random"},
	["Outskirts"]    = {"Skirmish","Escort","Random"},
	["Giant Forest"] = {"Skirmish","Guard","Random"},
	["Utgard"]       = {"Skirmish","Defend","Random"},
	["Loading Docks"]= {"Skirmish","Stall","Random"},
	["Stohess"]      = {"Skirmish","Random"},
}
local SkillPaths = {
	Blades  = {Damage=Blades_Damage, Critical=Blades_Critical},
	Spears  = {Damage=Spears_Damage, Critical=Spears_Critical},
	Defense = {Health=Defense_Health, ["Damage Reduction"]=Defense_DmgRed},
	Support = {Regen=Support_Regen,   ["Cooldown Reduction"]=Support_CDR},
}

local function GetPerkRarity(n) return PerkRarityMap[n] end
local function GetPerkXP(r, l) return (Perk_Base_XP[r] or 0) * math.max(l,1) end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================
local function UseButton(btn)
	if not btn or not btn.Parent or not btn.Visible then return false end
	if GuiService.MenuIsOpen then
		vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
		vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
		task.wait(0.1)
	end
	GuiService.SelectedObject = btn
	task.wait(0.05)
	vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
	return true
end

local _deleteMapRunning = false
local function DeleteMap()
	if _deleteMapRunning or not getgenv().DeleteMap or not workspace:FindFirstChild("Climbable") then return end
	if mapData and mapData.Map and mapData.Map.Type == "Raids" then return end
	task.spawn(function()
		_deleteMapRunning = true
		while getgenv().DeleteMap do
			if not workspace:FindFirstChild("Climbable") then break end
			if mapData and mapData.Map and mapData.Map.Type == "Raids" then break end
			for _, v in workspace.Climbable:GetChildren() do v:Destroy() end
			for _, v in workspace.Unclimbable:GetChildren() do
				if v.Name ~= "Reloads" and v.Name ~= "Objective" and v.Name ~= "Cutscene" then v:Destroy() end
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
			local free    = chests:FindFirstChild("Free")
			local premium = chests:FindFirstChild("Premium")
			local finish  = chests:FindFirstChild("Finish")
			if free and free.Visible then UseButton(free); task.wait(0.5)
			elseif premium and premium.Visible and premium:FindFirstChild("Title")
				and not string.find(premium.Title.Text,"(0)") and getgenv().OpenSecondChest then
				UseButton(premium); task.wait(0.5)
			elseif finish and finish.Visible then UseButton(finish) end
		end
	end
	if getgenv().AutoRetry then
		local rg = INTERFACE:FindFirstChild("Rewards")
		if rg and rg.Visible then
			local rb = rg:FindFirstChild("Main") and rg.Main:FindFirstChild("Info")
				and rg.Main.Info:FindFirstChild("Main") and rg.Main.Info.Main:FindFirstChild("Buttons")
				and rg.Main.Info.Main.Buttons:FindFirstChild("Retry")
			if rb then UseButton(rb) end
		end
	end
end

-- ==========================================
-- INJURY REMOVER
-- ==========================================
task.spawn(function()
	while true do
		local inj = lp.Character and lp.Character:FindFirstChild("Injuries")
		if inj then for _, v in inj:GetChildren() do v:Destroy() end end
		task.wait(1)
	end
end)

-- ==========================================
-- WEBHOOK
-- ==========================================
local webhook = ""
local gamesPlayed = 0
local function fmtTable(t) local r={} for k,v in pairs(t) do table.insert(r,tostring(k)..": "..tostring(v)) end return table.concat(r,"\n") end
local function fmtItems(t)  local r={} for k,v in pairs(t) do table.insert(r,tostring(k).." x"..tostring(v)) end return table.concat(r,"\n") end

local function SendRewardWebhook()
	if not getgenv().RewardWebhook then return end
	gamesPlayed = gamesPlayed + 1
	task.spawn(function()
		local data = {Stats={}, Total={}, Items={}, Special={}}
		local start = os.clock()
		repeat task.wait(0.5) until (statsFrame and #statsFrame:GetChildren()>0) or os.clock()-start>2
		for _, v in ipairs(statsFrame:GetChildren()) do
			if v:IsA("Frame") and v:FindFirstChild("Stat") and v:FindFirstChild("Amount") then
				data.Stats[string.gsub(v.Name,"_"," ")] = v.Amount.Text
			end
		end
		for _, v in ipairs(itemsFrame:GetChildren()) do
			if v:IsA("Frame") and v:FindFirstChild("Main") then
				local inner = v.Main:FindFirstChild("Inner")
				if inner then
					data.Items[v.Name] = inner.Quantity.Text
					if inner:FindFirstChild("Rarity") and inner.Rarity.BackgroundColor3==Color3.fromRGB(255,0,0) then
						data.Special[v.Name] = inner.Quantity.Text
					end
				end
			end
		end
		local sl = lp:GetAttribute("Slot") or "A"
		local sd = mapData and mapData.Slots and mapData.Slots[sl]
		local ex = identifyexecutor and identifyexecutor() or "Unknown"
		if sd then
			if sd.Currency    then for k,v in pairs(sd.Currency)    do if k=="Gems" or k=="Gold"                       then data.Total[k]=v end end end
			if sd.Progression then for k,v in pairs(sd.Progression) do if k=="Prestige" or k=="Level" or k=="Streak"  then data.Total[k]=v end end end
		end
		local hs = next(data.Special)~=nil
		if webhook~="" then
			request({Url=webhook,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({
				content=hs and "MYTHICAL DROP! @everyone" or nil,
				embeds={{title="TH Rewards",color=hs and 0xff0000 or 0x2b2d31,
					fields={
						{name="Information",value="```\nUser: "..lp.Name.."\nGames: "..gamesPlayed.."\nExec: "..ex.."\n```",inline=true},
						{name="Total",      value="```\nLevel: "..(data.Total.Level or 1).."\nGold: "..(data.Total.Gold or 0).."\nGems: "..(data.Total.Gems or 0).."\n```",inline=true},
						{name="Combat",     value="```\n"..fmtTable(data.Stats).."\n```",inline=true},
						{name="Rewards",    value="```\n"..fmtItems(data.Items).."\n```",inline=true},
						{name="Special",    value="```\n"..(hs and fmtItems(data.Special) or "None").."\n```",inline=true},
					},
					footer={text="TITANIC HUB • "..DateTime.now():FormatLocalTime("LTS","en-us")},
					timestamp=DateTime.now():ToIsoDate(),
				}}
			})})
		end
	end)
end

-- ==========================================
-- AUTO FARM
-- ==========================================
local AutoFarm = {}
AutoFarm._running = false

function AutoFarm:Start()
	if self._running or isLobby then return end
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
						titansReady = true; break
					end
				end
			end
			return playerReady and mapReady and titansReady
		end

		local waitNotify = os.clock()
		while self._running and not checkReady() do
			if os.clock()-waitNotify > 10 then
				Window:Notify({Title="TITANIC HUB",Content="Waiting for mission assets...",Duration=5,Image=4483362458})
				waitNotify = os.clock()
			end
			task.wait(1)
		end
		if not self._running then return end
		UpdateStatus("Farming")

		local titansFolder = workspace:FindFirstChild("Titans")
		local lastAttack = 0
		local currentChar, root, charParts = nil, nil, {}
		local bossNames = {Attack_Titan=true, Armored_Titan=true, Female_Titan=true}
		local attackTitanSpawnTime = nil
		local validNapes = {}
		local nextTitanUpdate, nextObjUpdate = 0, 0
		local cachedObjPart = nil
		local masteryComboIdx = 1
		local lastMasteryPunch = 0

		local function updateChar()
			local char = lp.Character
			if not char then return false end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end
			if char ~= currentChar then
				currentChar = char; root = hrp; charParts = {}
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide=false; table.insert(charParts,p) end
				end
			end
			return true
		end

		while self._running do
			if lp:GetAttribute("Cutscene") then task.wait(); continue end
			if not checkMission() then UpdateStatus("Waiting for mission..."); task.wait(1); continue end

			local slotIndex = lp:GetAttribute("Slot")
			local slotData  = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]
			if not slotData then UpdateStatus("Waiting for data..."); task.wait(1); continue end

			getgenv().AutoFarmConfig.AttackCooldown = slotData.Weapon=="Blades" and 0.15 or 1

			if getgenv().AutoFailsafe then
				if not self.missionStartTime then self.missionStartTime = os.clock() end
				if os.clock()-self.missionStartTime >= 900 then
					self:Stop()
					task.spawn(function() getRemote:InvokeServer("Functions","Teleport","Lobby") end)
					task.wait(0.5); TeleportService:Teleport(14916516914, lp); break
				end
			end

			local pc = workspace:GetAttribute("Player_Count") or #Players:GetPlayers()
			if getgenv().SoloOnly and pc>1 then
				self:Stop()
				task.spawn(function() getRemote:InvokeServer("Functions","Teleport","Lobby") end)
				task.wait(0.5); TeleportService:Teleport(14916516914, lp); break
			end

			if not updateChar() then task.wait(); continue end
			titansFolder = workspace:FindFirstChild("Titans") or titansFolder

			local ws_Obj = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective")
			local rs_Obj = ReplicatedStorage:FindFirstChild("Objectives")
			local mapType = workspace:GetAttribute("Type") or (mapData and mapData.Map and mapData.Map.Type)
			local isArmoredRaid    = ws_Obj and ws_Obj:FindFirstChild("Armored_Boss")
			local isFemaleRaid     = rs_Obj and rs_Obj:FindFirstChild("Defeat_Annie")
			local femaleExists     = ws_Obj and ws_Obj:FindFirstChild("Female_Boss")
			local attackExists     = ws_Obj and ws_Obj:FindFirstChild("Attack_Boss")
			local hasReinerObj     = rs_Obj and rs_Obj:FindFirstChild("Defeat_Reiner")

			if isFemaleRaid and not femaleExists and not attackExists then task.wait(); continue end

			for i=1,#charParts do local p=charParts[i]; if p and p.Parent then p.CanCollide=false end end

			local now = os.clock()
			local isShifted = currentChar and currentChar:GetAttribute("Shifter") or false

			if getgenv().MasteryFarmConfig.Enabled then
				local bar = lp:GetAttribute("Bar")
				if not isShifted and bar and bar==100 then
					repeat getRemote:InvokeServer("S_Skills","Usage","999",false); task.wait(1) until not self._running or (lp.Character and lp.Character:GetAttribute("Shifter"))
					continue
				end
			end

			if now >= nextTitanUpdate then
				nextTitanUpdate = now+0.1
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

			local referencePos = root.Position
			if now >= nextObjUpdate then
				nextObjUpdate = now+1; cachedObjPart = nil
				if ws_Obj then
					for _, d in ipairs(ws_Obj:GetDescendants()) do
						if d:IsA("BillboardGui") and d.Parent and d.Parent:IsA("BasePart") then
							cachedObjPart = d.Parent; break
						end
					end
				end
			end
			local objectiveFound = cachedObjPart and cachedObjPart.Parent
			if objectiveFound then referencePos = cachedObjPart.Position end

			local useRangeLimit = objectiveFound and isArmoredRaid and not hasReinerObj
			local closestDist, closestNape, closestIsBoss = math.huge, nil, false
			local bossDist, bossHitPoint, bossIsRoaring = math.huge, nil, false
			local attackTitanFound = false
			local highestZ = -math.huge
			local isStall = mapData and mapData.Map and mapData.Map.Objective=="Stall"

			for i=1,#validNapes do
				local nape = validNapes[i]
				if not nape.Parent then continue end
				local tm   = nape.Parent.Parent.Parent
				local fake = tm:FindFirstChild("Fake")
				if (fake and fake:FindFirstChild("Collision") and not fake.Collision.CanCollide) or tm:GetAttribute("Dead") then continue end
				local tName  = tm.Name
				local isBoss = bossNames[tName]
				if isArmoredRaid and not hasReinerObj and tName=="Armored_Titan" then continue end
				if isBoss and not tm:GetAttribute("State") then continue end
				local isRoaring = isBoss and (tm:GetAttribute("Attack")=="Roar" or tm:GetAttribute("Attack")=="Berserk_Mode")
				if tName=="Attack_Titan" then attackTitanFound=true end
				local dx=referencePos.X-nape.Position.X; local dz=referencePos.Z-nape.Position.Z; local d=dx*dx+dz*dz
				local adj = d - (getgenv()._currentTargetNape==nape and 15000 or 0)
				if useRangeLimit and d>90000 then continue end
				if isBoss then
					local hp=(tm:FindFirstChild("Marker") and tm.Marker.Adornee) or tm.Hitboxes.Hit.Nape
					if hp and adj<bossDist then bossDist=adj; bossHitPoint=hp; bossIsRoaring=isRoaring end
				end
				if isStall then
					if nape.Position.Z>highestZ then highestZ=nape.Position.Z; closestNape=nape end
				elseif adj<closestDist then
					closestDist=adj; closestNape=nape; closestIsBoss=isBoss
				end
			end

			local targetPart = bossHitPoint or closestNape
			local targetIsRoaring = (targetPart and targetPart==bossHitPoint) and bossIsRoaring or false
			if useRangeLimit and closestNape then targetPart=closestNape; targetIsRoaring=false end
			if targetPart and #validNapes==1 and mapType=="Missions" and (workspace:GetAttribute("Seconds") or 0)<29 then targetPart=nil end

			getgenv()._currentTargetNape = targetPart
			if attackTitanFound then attackTitanSpawnTime = attackTitanSpawnTime or now else attackTitanSpawnTime=nil end
			local atkReady = not attackTitanFound or (attackTitanSpawnTime and (now-attackTitanSpawnTime)>=5)

			if targetPart then
				UpdateStatus(closestIsBoss and "Attacking Boss..." or "Farming Titans...")
				local tm = targetPart
				if titansFolder then while tm and tm.Parent~=titansFolder do tm=tm.Parent end end

				if isShifted then
					local hrp = tm and tm:FindFirstChild("HumanoidRootPart")
					local tcf = hrp and hrp.CFrame or targetPart.CFrame
					root.AssemblyLinearVelocity = V3_ZERO
					root.CFrame = tcf * CFrame.new(0,0,80)
					local doPunch  = getgenv().MasteryFarmConfig.Mode=="Punching" or getgenv().MasteryFarmConfig.Mode=="Both"
					local doSkills = getgenv().MasteryFarmConfig.Mode=="Skill Usage" or getgenv().MasteryFarmConfig.Mode=="Both"
					if not targetIsRoaring then
						if doPunch and (now-lastMasteryPunch)>=1 then
							lastMasteryPunch=now
							postRemote:FireServer("Attacks","Slash",true)
							postRemote:FireServer("Hitboxes","Register",targetPart,nil,nil,masteryComboIdx)
							masteryComboIdx = masteryComboIdx%4+1
						end
						if doSkills and slotData.Skills and slotData.Skills.Shifter and not getgenv().ShifterSkillsRunning then
							getgenv().ShifterSkillsRunning=true
							task.spawn(function()
								for _, sid in ipairs(slotData.Skills.Shifter) do
									local n=tonumber(sid)
									if n and n~=200 and n~=300 and n~=400 and n~=210 and n~=211 and n~=306 and n~=308 and n~=402 and n~=403 and n~=407 then
										getRemote:InvokeServer("S_Skills","Usage",tostring(sid),false)
									end
									task.wait(1)
								end
								getgenv().ShifterSkillsRunning=false
							end)
						end
					end
				else
					local tPos = targetPart.Position + Vector3.new(0, getgenv().AutoFarmConfig.HeightOffset, 0)
					if getgenv().AutoFarmConfig.MovementMode=="Teleport" then
						root.CFrame = CFrame.new(tPos); root.AssemblyLinearVelocity=V3_ZERO
					else
						local dir=tPos-root.Position; local dist=dir.Magnitude
						if dist>10 then root.AssemblyLinearVelocity=dir.Unit*math.min(getgenv().AutoFarmConfig.MoveSpeed, dist*10)
						else root.AssemblyLinearVelocity=V3_ZERO end
					end
					if atkReady and (now-lastAttack)>=getgenv().AutoFarmConfig.AttackCooldown then
						lastAttack=now
						if slotData.Weapon=="Blades" then
							postRemote:FireServer("Attacks","Slash",false)
							postRemote:FireServer("Hitboxes","Register",targetPart,nil,nil,1)
						elseif slotData.Weapon=="Spears" then
							postRemote:FireServer("Attacks","Throw",targetPart.Position)
						end
					end
				end
			else
				UpdateStatus("No targets")
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
-- WEAPON RELOAD
-- ==========================================
local lastReloadTime, autoReloadEnabled, autoRefillEnabled, isReloading = 0, false, false, false

local function getBladeCount()
	if not INTERFACE:FindFirstChild("HUD") then return nil end
	local txt = pcall(function() return PlayerGui.Interface.HUD.Main.Top.Blades.Sets.Text end) and PlayerGui.Interface.HUD.Main.Top.Blades.Sets.Text or "0"
	return tonumber(txt:match("(%d+)%s*/"))
end

local function handleWeaponReload()
	if not autoReloadEnabled or isReloading or os.clock()-lastReloadTime<getgenv().AutoFarmConfig.ReloadCooldown then return end
	local si = lp:GetAttribute("Slot"); local slot = si and mapData and mapData.Slots and mapData.Slots[si]; if not slot then return end
	local wt = slot.Weapon
	if wt=="Blades" then
		local char=lp.Character; local rig=char and char:FindFirstChild("Rig_"..lp.Name)
		local blade=rig and rig:FindFirstChild("LeftHand") and rig.LeftHand:FindFirstChild("Blade_1")
		local cur=getBladeCount() or 0
		if cur==0 and autoRefillEnabled then
			local rp=workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Reloads") and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks") and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
			if rp then isReloading=true; lastReloadTime=os.clock(); pcall(function() postRemote:FireServer("Attacks","Reload",rp) end); task.delay(1,function() isReloading=false end); return end
		end
		if blade and blade.Transparency==1 and cur>0 then
			isReloading=true; lastReloadTime=os.clock(); pcall(function() getRemote:InvokeServer("Blades","Reload") end); task.delay(0.5,function() isReloading=false end)
		end
	elseif wt=="Spears" then
		local HUD=INTERFACE:FindFirstChild("HUD"); if not HUD then return end
		local sc=tonumber(HUD.Main.Top.Spears.Spears.Text:match("(%d+)%s*/")) or 0
		if sc==0 and autoRefillEnabled then
			local rp=workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Reloads") and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks") and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
			if rp then isReloading=true; lastReloadTime=os.clock(); postRemote:FireServer("Attacks","Reload",rp); task.delay(1,function() isReloading=false end) end
		end
	end
end

task.spawn(function() while true do pcall(handleWeaponReload); task.wait(0.5) end end)

postRemote.OnClientEvent:Connect(function(...)
	local a={...}
	if getgenv().AutoEscape and a[1]=="Titans" and a[2]=="Grab_Event" then
		PlayerGui.Interface.Buttons.Visible = not getgenv().AutoEscape
		postRemote:FireServer("Attacks","Slash_Escape")
	end
end)

-- ==========================================
-- FAMILY ROLL
-- ==========================================
local function roll(targets, rarities)
	if not PlayerGui.Interface.Customisation.Visible then return end
	local fs = PlayerGui.Interface.Customisation.Family.Family.Title.Text
	local fn = targets and string.lower(string.split(fs," ")[1]) or nil
	local fr = string.lower(string.match(fs,"%((.-)%)") or "")
	local stop = false
	if targets and fn and table.find(targets,fn) then stop=true end
	if rarities and table.find(rarities,fr) then stop=true end
	if fr=="mythical" then stop=true end
	if stop then
		getgenv().AutoRoll=false
		Window:Notify({Title="TITANIC HUB",Content="Target family rolled: "..fs,Duration=5,Image=4483362458})
		if fr=="mythical" and getgenv().MythicalFamilyWebhook and webhook~="" then
			request({Url=webhook,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({
				content="MYTHICAL FAMILY ROLLED! @everyone",
				embeds={{title="Family Roll Success",color=0xff0000,
					fields={{name="Info",value="```\nUser: "..lp.Name.."\nFamily: "..fs.."\n```",inline=true}},
					footer={text="TITANIC HUB"},timestamp=DateTime.now():ToIsoDate()}}
			})})
		end
		return
	end
	if PlayerGui.Interface.Warning.Prompt.Visible then UseButton(PlayerGui.Interface.Warning.Prompt.Main.Yes); task.wait(0.5) end
	if familyFrame and not familyFrame.Visible then UseButton(PlayerGui.Interface.Customisation.Categories.Family.Interact); task.wait(1) end
	if rollButton then UseButton(rollButton) end
end

-- ==========================================
-- RAYFIELD UI
-- ==========================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name               = "TITANIC HUB  |  AOT:R",
	Icon               = 0,
	LoadingTitle       = "TITANIC HUB",
	LoadingSubtitle    = "by the community",
	Theme              = "Default",
	DisableRayfieldPrompts  = false,
	DisableBuildWarnings    = false,
	ConfigurationSaving = { Enabled = false },
	Discord = { Enabled = true, Invite = "Cczp9ZWxvY", RememberJoins = true },
	KeySystem = false,
})

-- ==========================================
-- TAB 1 : MAIN  (Farm + Auto Start)
-- ==========================================
local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateSection("Farm")

MainTab:CreateLabel("Status: Idle  |  Toggle Auto Farm below")

MainTab:CreateToggle({
	Name = "Auto Farm", CurrentValue = false, Flag = "AutoKillToggle",
	Callback = function(v) if v then AutoFarm:Start() else AutoFarm:Stop() end end,
})

MainTab:CreateToggle({
	Name = "Titan Mastery Farm", CurrentValue = false, Flag = "MasteryFarmToggle",
	Callback = function(v)
		getgenv().MasteryFarmConfig.Enabled = v
		if v and not AutoFarm._running then AutoFarm:Start() end
	end,
})

MainTab:CreateDropdown({
	Name = "Mastery Mode", Options = {"Punching","Skill Usage","Both"},
	CurrentOption = {"Both"}, MultipleOptions = false, Flag = "MasteryModeDropdown",
	Callback = function(v) getgenv().MasteryFarmConfig.Mode = v; State.MasteryMode = v end,
})

MainTab:CreateDropdown({
	Name = "Movement Mode", Options = {"Hover","Teleport"},
	CurrentOption = {"Hover"}, MultipleOptions = false, Flag = "MovementModeDropdown",
	Callback = function(v) getgenv().AutoFarmConfig.MovementMode = v; State.MovementMode = v end,
})

MainTab:CreateDropdown({
	Name = "Farm Options", Options = {"Auto Execute","Failsafe","Open Second Chest"},
	CurrentOption = {}, MultipleOptions = true, Flag = "FarmOptionsDropdown",
	Callback = function(vals)
		local function has(x) for _,v in ipairs(vals) do if v==x then return true end end return false end
		getgenv().AutoFailsafe     = has("Failsafe")
		getgenv().AutoExecute      = has("Auto Execute")
		getgenv().OpenSecondChest  = has("Open Second Chest")
		if getgenv().AutoExecute then setupAutoExecute() end
		State.FarmOptions = vals
	end,
})

MainTab:CreateSlider({
	Name = "Hover Speed", Range = {100,500}, Increment = 10,
	Suffix = "", CurrentValue = 400, Flag = "HoverSpeedSlider",
	Callback = function(v) getgenv().AutoFarmConfig.MoveSpeed = v end,
})

MainTab:CreateSlider({
	Name = "Float Height", Range = {100,300}, Increment = 10,
	Suffix = "", CurrentValue = 250, Flag = "FloatHeightSlider",
	Callback = function(v) getgenv().AutoFarmConfig.HeightOffset = v end,
})

MainTab:CreateToggle({
	Name = "Auto Reload / Refill", CurrentValue = false, Flag = "AutoReloadToggle",
	Callback = function(v) autoReloadEnabled = v; autoRefillEnabled = v end,
})

MainTab:CreateToggle({
	Name = "Auto Escape", CurrentValue = false, Flag = "AutoEscapeToggle",
	Callback = function(v) getgenv().AutoEscape = v end,
})

MainTab:CreateToggle({
	Name = "Auto Skip Cutscenes", CurrentValue = false, Flag = "AutoSkipToggle",
	Callback = function(v) getgenv().AutoSkip = v; if v then ExecuteImmediateAutomation() end end,
})

MainTab:CreateToggle({
	Name = "Auto Retry", CurrentValue = false, Flag = "AutoRetryToggle",
	Callback = function(v) getgenv().AutoRetry = v; if v then ExecuteImmediateAutomation() end end,
})

MainTab:CreateToggle({
	Name = "Auto Open Chests", CurrentValue = false, Flag = "AutoChestToggle",
	Callback = function(v) getgenv().AutoChest = v; if v then ExecuteImmediateAutomation() end end,
})

MainTab:CreateToggle({
	Name = "Delete Map (FPS Boost)", CurrentValue = DropdownConfig.DeleteMap or false, Flag = "DeleteMapToggle",
	Callback = function(v) getgenv().DeleteMap=v; DropdownConfig.DeleteMap=v; SaveConfig(DropdownConfig); if v then DeleteMap() end end,
})

MainTab:CreateToggle({
	Name = "Solo Only", CurrentValue = false, Flag = "SoloOnlyToggle",
	Callback = function(v) getgenv().SoloOnly = v end,
})

MainTab:CreateToggle({
	Name = "Auto Return to Lobby", CurrentValue = false, Flag = "AutoReturnLobbyToggle",
	Callback = function(v)
		getgenv().AutoReturnLobby = v
		if not v then pcall(function() writefile(returnCounterPath,"0") end) end
	end,
})

MainTab:CreateLabel("Failsafe teleports you back to lobby after 15 minutes.")

-- Auto Start section
MainTab:CreateSection("Auto Start")

MainTab:CreateButton({
	Name = "Return to Lobby",
	Callback = function()
		getRemote:InvokeServer("Functions","Teleport","Lobby")
		TeleportService:Teleport(14916516914, lp)
	end,
})

MainTab:CreateButton({
	Name = "Join Discord",
	Callback = function()
		setclipboard("https://discord.gg/Cczp9ZWxvY")
		Window:Notify({Title="Discord",Content="Invite link copied to clipboard!",Duration=4,Image=4483362458})
	end,
})

MainTab:CreateToggle({
	Name = "Auto Start", CurrentValue = false, Flag = "AutoStartToggle",
	Callback = function(v)
		getgenv().AutoStart = v
		if not v then return end
		if game.PlaceId ~= 14916516914 then
			Window:Notify({Title="Auto Start",Content="Must be in lobby!",Duration=3,Image=4483362458}); return
		end
		task.spawn(function()
			local MAX = 10; local retries = 0
			local function getMyMission()
				local t=os.clock()
				while os.clock()-t<2 do
					for _, m in next, ReplicatedStorage.Missions:GetChildren() do
						if m:FindFirstChild("Leader") and m.Leader.Value==lp.Name then return m end
					end
					task.wait(0.1)
				end
			end
			while getgenv().AutoStart do
				for _, m in next, ReplicatedStorage.Missions:GetChildren() do
					if m:FindFirstChild("Leader") and m.Leader.Value==lp.Name then getRemote:InvokeServer("S_Missions","Leave") end
				end
				local isMission = State.StartType ~= "Raids"
				local diff    = isMission and State.MissionDifficulty or State.RaidDifficulty
				local mapName = isMission and State.MissionMap      or State.RaidMap
				local obj     = isMission and State.MissionObjective or State.RaidObjective
				local mtype   = isMission and "Missions" or "Raids"
				local created = false
				if diff=="Hardest" then
					local order = mtype=="Raids" and {"Aberrant","Severe","Hard"} or {"Aberrant","Severe","Hard","Normal","Easy"}
					for _, d in ipairs(order) do
						if not getgenv().AutoStart then break end
						getRemote:InvokeServer("S_Missions","Create",{Difficulty=d,Type=mtype,Name=mapName,Objective=obj})
						if getMyMission() then
							Window:Notify({Title="Auto Start",Content="Difficulty: "..d,Duration=3,Image=4483362458}); created=true; break
						end
					end
				else
					getRemote:InvokeServer("S_Missions","Create",{Difficulty=diff,Type=mtype,Name=mapName,Objective=obj})
					if getMyMission() then created=true end
				end
				if not getgenv().AutoStart then break end
				if not created then
					retries=retries+1
					if retries>=MAX then
						Window:Notify({Title="Auto Start",Content="Failed "..MAX.." times. Stopping.",Duration=8,Image=4483362458})
						getgenv().AutoStart=false; break
					end
					local back=math.min(retries*2,20)
					Window:Notify({Title="Auto Start",Content="Retry "..retries.."/"..MAX.." in "..back.."s",Duration=back,Image=4483362458})
					task.wait(back); continue
				end
				retries=0
				for _, mod in ipairs(State.Modifiers) do getRemote:InvokeServer("S_Missions","Modify",mod) end
				task.wait(0.5); getRemote:InvokeServer("S_Missions","Start"); task.wait(5)
			end
		end)
	end,
})

MainTab:CreateDropdown({
	Name = "Type", Options = {"Missions","Raids"},
	CurrentOption = {State.StartType}, MultipleOptions = false, Flag = "StartTypeDropdown",
	Callback = function(v) State.StartType=v; DropdownConfig._lastType=v; SaveConfig(DropdownConfig) end,
})

MainTab:CreateDropdown({
	Name = "Mission Map",
	Options = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"},
	CurrentOption = {State.MissionMap}, MultipleOptions = false, Flag = "MissionMapDropdown",
	Callback = function(v) State.MissionMap=v; DropdownConfig.Missions=DropdownConfig.Missions or {}; DropdownConfig.Missions.map=v; SaveConfig(DropdownConfig) end,
})

MainTab:CreateDropdown({
	Name = "Mission Objective",
	Options = Missions[State.MissionMap] or {"Skirmish","Breach","Random"},
	CurrentOption = {State.MissionObjective}, MultipleOptions = false, Flag = "MissionObjectiveDropdown",
	Callback = function(v) State.MissionObjective=v; DropdownConfig.Missions=DropdownConfig.Missions or {}; DropdownConfig.Missions.objective=v; SaveConfig(DropdownConfig) end,
})

MainTab:CreateDropdown({
	Name = "Mission Difficulty",
	Options = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
	CurrentOption = {State.MissionDifficulty}, MultipleOptions = false, Flag = "MissionDifficultyDropdown",
	Callback = function(v) State.MissionDifficulty=v; DropdownConfig.Missions=DropdownConfig.Missions or {}; DropdownConfig.Missions.difficulty=v; SaveConfig(DropdownConfig) end,
})

MainTab:CreateDropdown({
	Name = "Raid Map", Options = {"Trost","Shiganshina","Stohess"},
	CurrentOption = {State.RaidMap}, MultipleOptions = false, Flag = "RaidMapDropdown",
	Callback = function(v) State.RaidMap=v; DropdownConfig.Raids=DropdownConfig.Raids or {}; DropdownConfig.Raids.map=v; SaveConfig(DropdownConfig) end,
})

MainTab:CreateDropdown({
	Name = "Raid Objective",
	Options = Missions[State.RaidMap] or {"Skirmish","Protect","Random"},
	CurrentOption = {State.RaidObjective}, MultipleOptions = false, Flag = "RaidObjectiveDropdown",
	Callback = function(v) State.RaidObjective=v; DropdownConfig.Raids=DropdownConfig.Raids or {}; DropdownConfig.Raids.objective=v; SaveConfig(DropdownConfig) end,
})

MainTab:CreateDropdown({
	Name = "Raid Difficulty", Options = {"Hard","Severe","Aberrant","Hardest"},
	CurrentOption = {State.RaidDifficulty}, MultipleOptions = false, Flag = "RaidDifficultyDropdown",
	Callback = function(v) State.RaidDifficulty=v; DropdownConfig.Raids=DropdownConfig.Raids or {}; DropdownConfig.Raids.difficulty=v; SaveConfig(DropdownConfig) end,
})

MainTab:CreateLabel("Trost = Attack Titan  |  Shiganshina = Armored  |  Stohess = Female")

MainTab:CreateDropdown({
	Name = "Modifiers",
	Options = {"No Perks","No Skills","No Talents","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"},
	CurrentOption = {}, MultipleOptions = true, Flag = "ModifiersDropdown",
	Callback = function(v) State.Modifiers = v end,
})

-- ==========================================
-- TAB 2 : UPGRADES
-- ==========================================
local UpgradesTab = Window:CreateTab("Upgrades", 4483362458)

UpgradesTab:CreateSection("Gear Upgrades")

UpgradesTab:CreateToggle({
	Name = "Upgrade Gear", CurrentValue = false, Flag = "AutoUpgradeToggle",
	Callback = function(v)
		getgenv().AutoUpgrade = v
		if not v or game.PlaceId~=14916516914 then return end
		task.spawn(function()
			local pd = GetPlayerData(); if not pd or not pd.Slots then return end
			while getgenv().AutoUpgrade do
				local si=lp:GetAttribute("Slot"); if not si or not pd.Slots[si] then task.wait(1); continue end
				local wpn=pd.Slots[si].Weapon; local upgrades=pd.Slots[si].Upgrades[wpn]
				for upg, lvl in next, upgrades do
					if getRemote:InvokeServer("S_Equipment","Upgrade",upg) then
						Window:Notify({Title="Upgraded "..string.gsub(upg,"_"," "),Content="Level "..tostring(lvl),Duration=1,Image=4483362458})
						task.wait(0.3)
					end
				end
				task.wait(0.5)
			end
		end)
	end,
})

UpgradesTab:CreateToggle({
	Name = "Enhance Perks", CurrentValue = false, Flag = "AutoEnhanceToggle",
	Callback = function(v)
		getgenv().AutoPerk = v
		if not v or game.PlaceId~=14916516914 then return end
		task.spawn(function()
			local pd=GetPlayerData(); if not pd or not pd.Slots then return end
			local si=lp:GetAttribute("Slot"); if not si or not pd.Slots[si] then getgenv().AutoPerk=false; return end
			local slot=pd.Slots[si]
			local sp={} for id,val in pairs(slot.Perks.Storage) do sp[id]=val end
			local ps=State.PerkSlot
			local epid=slot.Perks.Equipped[ps]
			if not epid then Window:Notify({Title="Auto Perk",Content="No perk in "..ps.." slot.",Duration=3,Image=4483362458}); getgenv().AutoPerk=false; return end
			local pd2=sp[epid]; if not pd2 then getgenv().AutoPerk=false; return end
			local pn=pd2.Name; local rar=GetPerkRarity(pn); local clvl=pd2.Level or 0; local cxp=pd2.XP or 0
			while getgenv().AutoPerk do
				if clvl>=10 then Window:Notify({Title="Auto Perk",Content=pn.." is Level 10!",Duration=3,Image=4483362458}); break end
				local rp={}; for _,r in ipairs(State.FoodPerks) do rp[r]=true end
				local vp={}; local txp=0
				for pid,tbl in pairs(sp) do
					local r=GetPerkRarity(tbl.Name)
					if pid~=epid and rp[r] then table.insert(vp,pid); txp=txp+GetPerkXP(r,math.max(tbl.Level or 0,1)); if #vp>=5 then break end end
				end
				if #vp==0 then Window:Notify({Title="Auto Perk",Content="No food perks left.",Duration=3,Image=4483362458}); break end
				if getRemote:InvokeServer("S_Equipment","Enhance",epid,vp) then
					for _,id in ipairs(vp) do sp[id]=nil end
					cxp=cxp+txp
					while clvl<10 do
						local th=Perk_Level_XP[rar]; if not th then break end
						local nd=th[clvl+1]; if not nd or cxp<nd then break end
						cxp=cxp-nd; clvl=clvl+1
					end
					Window:Notify({Title="Enhanced: "..pn,Content="Lvl "..clvl.." (+"..txp.." XP)",Duration=1,Image=4483362458})
				end
				task.wait(0.5)
			end
			getgenv().AutoPerk=false
		end)
	end,
})

UpgradesTab:CreateDropdown({
	Name = "Perk Slot", Options = {"Defense","Support","Family","Extra","Offense","Body"},
	CurrentOption = {"Body"}, MultipleOptions = false, Flag = "PerkSlotDropdown",
	Callback = function(v) State.PerkSlot = v end,
})

UpgradesTab:CreateDropdown({
	Name = "Perks to use as Food", Options = {"Common","Rare","Epic","Legendary"},
	CurrentOption = {}, MultipleOptions = true, Flag = "SelectPerksDropdown",
	Callback = function(v) State.FoodPerks = v end,
})

UpgradesTab:CreateLabel("Default perk slot is Body. Select food perk rarities above.")

UpgradesTab:CreateSection("Skill Tree")

UpgradesTab:CreateToggle({
	Name = "Auto Skill Tree", CurrentValue = false, Flag = "AutoSkillTree",
	Callback = function(v)
		getgenv().AutoSkillTree = v
		if not v or game.PlaceId~=14916516914 then return end
		local pd=GetPlayerData(); if not pd or not pd.Slots then return end
		task.spawn(function()
			while getgenv().AutoSkillTree do
				local si=lp:GetAttribute("Slot"); if not si or not pd.Slots[si] then task.wait(1); continue end
				local wpn=pd.Slots[si].Weapon
				local mp = SkillPaths[wpn] and SkillPaths[wpn][State.MiddlePath]
				local lp2= SkillPaths.Support[State.LeftPath]
				local rp = SkillPaths.Defense[State.RightPath]
				local pm = {Left=lp2, Middle=mp, Right=rp}
				local paths={}; local used={}
				local function addP(p) if p~="None" and not used[p] and pm[p] then table.insert(paths,pm[p]); used[p]=true end end
				addP(State.Priority1); addP(State.Priority2); addP(State.Priority3)
				for _, path in ipairs(paths) do
					if path then
						for _, sid in ipairs(path) do
							if table.find(pd.Slots[si].Skills.Unlocked, sid) then continue end
							if getRemote:InvokeServer("S_Equipment","Unlock",{sid}) then
								Window:Notify({Title="Skill Unlocked",Content="ID: "..sid,Duration=1,Image=4483362458})
							end
						end
					end
				end
				task.wait()
			end
		end)
	end,
})

UpgradesTab:CreateDropdown({
	Name = "Middle Path", Options = {"Damage","Critical"},
	CurrentOption = {"Critical"}, MultipleOptions = false, Flag = "MiddlePathDropdown",
	Callback = function(v) State.MiddlePath = v end,
})

UpgradesTab:CreateDropdown({
	Name = "Left Path (Support)", Options = {"Regen","Cooldown Reduction"},
	CurrentOption = {"Cooldown Reduction"}, MultipleOptions = false, Flag = "LeftPathDropdown",
	Callback = function(v) State.LeftPath = v end,
})

UpgradesTab:CreateDropdown({
	Name = "Right Path (Defense)", Options = {"Health","Damage Reduction"},
	CurrentOption = {"Health"}, MultipleOptions = false, Flag = "RightPathDropdown",
	Callback = function(v) State.RightPath = v end,
})

UpgradesTab:CreateDropdown({
	Name = "Priority 1", Options = {"Left","Middle","Right","None"},
	CurrentOption = {"Middle"}, MultipleOptions = false, Flag = "Priority1Dropdown",
	Callback = function(v) State.Priority1 = v end,
})

UpgradesTab:CreateDropdown({
	Name = "Priority 2", Options = {"Left","Middle","Right","None"},
	CurrentOption = {"Left"}, MultipleOptions = false, Flag = "Priority2Dropdown",
	Callback = function(v) State.Priority2 = v end,
})

UpgradesTab:CreateDropdown({
	Name = "Priority 3", Options = {"Left","Middle","Right","None"},
	CurrentOption = {"None"}, MultipleOptions = false, Flag = "Priority3Dropdown",
	Callback = function(v) State.Priority3 = v end,
})

-- ==========================================
-- TAB 3 : MISC
-- ==========================================
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Slot")

MiscTab:CreateToggle({
	Name = "Auto Select Slot", CurrentValue = false, Flag = "AutoSelectSlot",
	Callback = function(v)
		getgenv().AutoSlot = v
		if v and not lp:GetAttribute("Slot") then
			local sl = State.SelectSlot
			local args = {"Functions","Select", string.sub(sl,-1)}
			task.spawn(function()
				repeat getRemote:InvokeServer(unpack(args)); task.wait(1) until lp:GetAttribute("Slot") or not getgenv().AutoSlot
				getRemote:InvokeServer("Functions","Teleport","Lobby")
			end)
		end
	end,
})

MiscTab:CreateDropdown({
	Name = "Select Slot", Options = {"Slot A","Slot B","Slot C"},
	CurrentOption = {"Slot A"}, MultipleOptions = false, Flag = "SelectSlotDropdown",
	Callback = function(v) State.SelectSlot = v end,
})

MiscTab:CreateToggle({
	Name = "Auto Prestige", CurrentValue = false, Flag = "AutoPrestigeToggle",
	Callback = function(v)
		getgenv().AutoPrestige = v
		if not v or game.PlaceId~=14916516914 then return end
		task.spawn(function()
			local pd=GetPlayerData(); if not pd or not pd.Slots then return end
			local si=lp:GetAttribute("Slot"); if not si or not pd.Slots[si] then return end
			local gold=pd.Slots[si].Currency.Gold
			local reqG=State.PrestigeGold*1000000
			if gold<reqG then Window:Notify({Title="Auto Prestige",Content="Not enough gold!",Duration=3,Image=4483362458}); getgenv().AutoPrestige=false; return end
			while getgenv().AutoPrestige do
				for _, mem in ipairs(Talents) do
					if not getgenv().AutoPrestige then break end
					local ok=getRemote:InvokeServer("S_Equipment","Prestige",{Boosts=State.SelectBoost, Talents=mem})
					if ok then Window:Notify({Title="Prestiged!",Content=State.SelectBoost.." + "..mem,Duration=5,Image=4483362458}); break end
					task.wait(0.1)
				end
				task.wait(1)
			end
		end)
	end,
})

MiscTab:CreateDropdown({
	Name = "Select Boost", Options = {"Luck Boost","EXP Boost","Gold Boost"},
	CurrentOption = {"Luck Boost"}, MultipleOptions = false, Flag = "SelectBoostDropdown",
	Callback = function(v) State.SelectBoost = v end,
})

MiscTab:CreateSlider({
	Name = "Prestige Gold (millions)", Range = {0,100}, Increment = 1,
	Suffix = "M", CurrentValue = 0, Flag = "PrestigeGoldSlider",
	Callback = function(v) State.PrestigeGold = v end,
})

MiscTab:CreateSection("Family Roll")

MiscTab:CreateToggle({
	Name = "Auto Roll", CurrentValue = false, Flag = "AutoRollToggle",
	Callback = function(v)
		getgenv().AutoRoll = v
		if not v then return end
		if game.PlaceId~=13379208636 then
			Window:Notify({Title="TITANIC HUB",Content="Must be in lobby to use family roll!",Duration=3,Image=4483362458}); return
		end
		task.spawn(function()
			while getgenv().AutoRoll do
				local txt = State.FamilyInput
				local targets = nil
				if txt and txt~="" then targets = string.split(string.lower(txt),",") end
				local rarities = nil
				if #State.FamilyRarity > 0 then
					rarities = {}; for _, r in ipairs(State.FamilyRarity) do table.insert(rarities, string.lower(r)) end
				end
				roll(targets, rarities)
				task.wait(0.25)
			end
		end)
	end,
})

MiscTab:CreateInput({
	Name = "Target Families", CurrentValue = "",
	PlaceholderText = "Fritz,Yeager,etc.", RemoveTextAfterFocusLost = false, Flag = "SelectFamily",
	Callback = function(v)
		State.FamilyInput = v
		if v~="" then Window:Notify({Title="Families Set",Content=v,Duration=2,Image=4483362458}) end
	end,
})

MiscTab:CreateDropdown({
	Name = "Stop At Rarity", Options = familyRaritiesOptions,
	CurrentOption = {}, MultipleOptions = true, Flag = "SelectFamilyRarity",
	Callback = function(v) State.FamilyRarity = v end,
})

MiscTab:CreateLabel("Mythical families always stop rolling. No spaces between commas.")

-- ==========================================
-- TAB 4 : SETTINGS
-- ==========================================
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("Webhook")

SettingsTab:CreateToggle({
	Name = "Reward Webhook", CurrentValue = false, Flag = "ToggleRewardWebhook",
	Callback = function(v) getgenv().RewardWebhook = v end,
})

SettingsTab:CreateToggle({
	Name = "Mythical Family Webhook", CurrentValue = false, Flag = "ToggleMythicalFamilyWebhook",
	Callback = function(v) getgenv().MythicalFamilyWebhook = v end,
})

SettingsTab:CreateInput({
	Name = "Webhook URL", CurrentValue = "",
	PlaceholderText = "https://discord.com/api/webhooks/...",
	RemoveTextAfterFocusLost = false, Flag = "WebhookUrl",
	Callback = function(v) webhook = v; State.WebhookUrl = v end,
})

SettingsTab:CreateSection("Performance & UI")

SettingsTab:CreateToggle({
	Name = "Disable 3D Rendering (FPS Boost)", CurrentValue = false, Flag = "Disable3DRendering",
	Callback = function(v) RunService:Set3dRenderingEnabled(not v) end,
})

SettingsTab:CreateKeybind({
	Name = "Menu Toggle Keybind", CurrentKeybind = "RightControl",
	HoldToInteract = false, Flag = "MenuKeybind",
	Callback = function(_) end,
})

SettingsTab:CreateLabel("Press keybind above to show/hide the menu.")

-- ==========================================
-- ANTI-AFK
-- ==========================================
local virtualUser = game:GetService("VirtualUser")
lp.Idled:Connect(function()
	virtualUser:CaptureController()
	virtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- MAIN LOOP
-- ==========================================
task.spawn(function()
	while true do
		pcall(ExecuteImmediateAutomation)
		task.wait(0.5)
	end
end)

task.spawn(function()
	task.wait(0.5)
	if getgenv().DeleteMap then DeleteMap() end
end)
