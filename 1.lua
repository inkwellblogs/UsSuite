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
	local args = {"Functions", "Settings", "Get"}
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
    if not mapData then lastPlayerData = nil; GetPlayerData() end
until mapData ~= nil or (lastPlayerData ~= nil and (isLobby or os.clock() - startLoadTime > 15))

if mapData then
	if mapData.Map.Type == "Raids" then
		repeat task.wait() until workspace:GetAttribute("Finalised")
	end
end

local function checkMission()
	if workspace:GetAttribute("Type") then return true end
	mapData = getRemote:InvokeServer("Data", "Copy")
	return mapData ~= nil and mapData.Map ~= nil and mapData.Slots ~= nil
end

local familyRaritiesOptions = {"Rare", "Epic", "Legendary", "Mythical"}

if not isfolder("./THUH") then makefolder("./THUB") end
if not isfolder("./THUB/aotr") then makefolder("./THUB/aotr") end

local ConfigFile = "./THUB/aotr/dropdown_config.json"
local returnCounterPath = "./THUB/aotr/return_lobby_counter.txt"
local HttpService = game:GetService("HttpService")

local function LoadConfig()
	if not isfile(ConfigFile) then return { Missions = {}, Raids = {}, DeleteMap = false } end
	local s, c = pcall(HttpService.JSONDecode, HttpService, readfile(ConfigFile))
	return s and c or { Missions = {}, Raids = {}, DeleteMap = false }
end
local function SaveConfig(c) pcall(writefile, ConfigFile, HttpService:JSONEncode(c)) end
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
getgenv().SoloOnly = false
if not isfile(returnCounterPath) then writefile(returnCounterPath, "0") end

-- ==========================================
-- RAYFIELD UI
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "TITANIC HUB",
   LoadingTitle = "TITANIC HUB",
   LoadingSubtitle = "by TH Developers",
   ConfigurationSaving = {Enabled = true, FolderName = "THUB", FileName = "aotr_config"},
   Discord = {Enabled = false, Invite = "xq5VCpFQsH", RememberJoins = true},
   KeySystem = false,
})

Rayfield:Notify({Title = "TITANIC HUB", Content = "Script loaded successfully!", Duration = 5, Image = "coins"})

-- TAB 1: Farm
local FarmTab = Window:CreateTab("Farm", "swords")
FarmTab:CreateSection("Auto Farm")
local AutoKillToggle = FarmTab:CreateToggle({Name = "Auto Farm", CurrentValue = false, Flag = "AutoKillToggle", Callback = function(v) if v then AutoFarm:Start() else AutoFarm:Stop() end end})
local MasteryFarmToggle = FarmTab:CreateToggle({Name = "Titan Mastery Farm", CurrentValue = false, Flag = "MasteryFarmToggle", Callback = function(v) getgenv().MasteryFarmConfig.Enabled = v; if v and not AutoFarm._running then AutoFarm:Start() end end})
local MasteryModeDropdown = FarmTab:CreateDropdown({Name = "Mastery Mode", Options = {"Punching","Skill Usage","Both"}, CurrentOption = {"Both"}, Flag = "MasteryModeDropdown", Callback = function(o) getgenv().MasteryFarmConfig.Mode = o[1] end})
FarmTab:CreateSection("Movement")
local MovementModeDropdown = FarmTab:CreateDropdown({Name = "Movement Mode", Options = {"Hover","Teleport"}, CurrentOption = {"Hover"}, Flag = "MovementModeDropdown", Callback = function(o) getgenv().AutoFarmConfig.MovementMode = o[1] end})
local HoverSpeedSlider = FarmTab:CreateSlider({Name = "Hover Speed", Range = {100,500}, Increment = 5, Suffix = "Studs", CurrentValue = 400, Flag = "HoverSpeedSlider", Callback = function(v) getgenv().AutoFarmConfig.MoveSpeed = v end})
local FloatHeightSlider = FarmTab:CreateSlider({Name = "Float Height", Range = {100,300}, Increment = 5, Suffix = "Studs", CurrentValue = 250, Flag = "FloatHeightSlider", Callback = function(v) getgenv().AutoFarmConfig.HeightOffset = v end})
FarmTab:CreateSection("Combat")
local AutoReloadToggle = FarmTab:CreateToggle({Name = "Auto Reload/Refill", CurrentValue = false, Flag = "AutoReloadToggle", Callback = function(v) autoReloadEnabled = v; autoRefillEnabled = v end})
local AutoEscapeToggle = FarmTab:CreateToggle({Name = "Auto Escape", CurrentValue = false, Flag = "AutoEscapeToggle", Callback = function(v) getgenv().AutoEscape = v end})
FarmTab:CreateSection("Misc Options")
local AutoSkipToggle = FarmTab:CreateToggle({Name = "Auto Skip Cutscenes", CurrentValue = false, Flag = "AutoSkipToggle", Callback = function(v) getgenv().AutoSkip = v end})
local AutoRetryToggle = FarmTab:CreateToggle({Name = "Auto Retry", CurrentValue = false, Flag = "AutoRetryToggle", Callback = function(v) getgenv().AutoRetry = v end})
local AutoChestToggle = FarmTab:CreateToggle({Name = "Auto Open Chests", CurrentValue = false, Flag = "AutoChestToggle", Callback = function(v) getgenv().AutoChest = v end})
local SoloOnlyToggle = FarmTab:CreateToggle({Name = "Solo Only", CurrentValue = false, Flag = "SoloOnlyToggle", Callback = function(v) getgenv().SoloOnly = v end})
local AutoReturnLobbyToggle = FarmTab:CreateToggle({Name = "Auto Return to Lobby", CurrentValue = false, Flag = "AutoReturnLobbyToggle", Callback = function(v) getgenv().AutoReturnLobby = v end})
local FarmOptionsDropdown = FarmTab:CreateDropdown({Name = "Farm Options", Options = {"Auto Execute","Failsafe","Open Second Chest"}, CurrentOption = {}, Flag = "FarmOptionsDropdown", Multi = true, Callback = function(o) getgenv().AutoFailsafe=false; getgenv().AutoExecute=false; getgenv().OpenSecondChest=false; for _,opt in pairs(o) do if opt=="Failsafe"then getgenv().AutoFailsafe=true elseif opt=="Auto Execute"then getgenv().AutoExecute=true elseif opt=="Open Second Chest"then getgenv().OpenSecondChest=true end end end})

-- TAB 2: TS Quest
local TSQuestTab = Window:CreateTab("TS Quest", "scroll")
TSQuestTab:CreateSection("Coming Soon")
TSQuestTab:CreateParagraph({Title = "TS Quest", Content = "Future TS Quest features coming soon!"})

-- TAB 3: Auto Start
local AutoStartTab = Window:CreateTab("Auto Start", "play")
AutoStartTab:CreateSection("Mission/Raid Auto Start")
AutoStartTab:CreateButton({Name = "Return to Lobby", Callback = function() getRemote:InvokeServer("Functions","Teleport","Lobby"); task.wait(0.5); TeleportService:Teleport(14916516914,lp) end})
local AutoStartToggle = AutoStartTab:CreateToggle({Name = "Auto Start", CurrentValue = false, Flag = "AutoStartToggle", Callback = function(v) getgenv().AutoStart=v; if v and game.PlaceId==14916516914 then task.spawn(function() local retries=0; local function getMyMission() local s=os.clock(); while(os.clock()-s)<2 do for _,m in next,ReplicatedStorage.Missions:GetChildren() do if m:FindFirstChild("Leader")and m.Leader.Value==lp.Name then return m end end; task.wait(0.1) end; return nil end; while getgenv().AutoStart do for _,m in next,ReplicatedStorage.Missions:GetChildren() do if m:FindFirstChild("Leader")and m.Leader.Value==lp.Name then getRemote:InvokeServer("S_Missions","Leave") end end; local mt=StartTypeDropdown.CurrentOption[1]; local sd,mn,ob; if mt=="Missions"then sd=MissionDifficultyDropdown.CurrentOption[1]; mn=MissionMapDropdown.CurrentOption[1]; ob=MissionObjectiveDropdown.CurrentOption[1] else sd=RaidDifficultyDropdown.CurrentOption[1]; mn=RaidMapDropdown.CurrentOption[1]; ob=RaidObjectiveDropdown.CurrentOption[1] end; local created=false; if sd=="Hardest"then local dO=mt=="Raids"and{"Aberrant","Severe","Hard"}or{"Aberrant","Severe","Hard","Normal","Easy"}; for _,diff in ipairs(dO)do if not getgenv().AutoStart then break end; getRemote:InvokeServer("S_Missions","Create",{Difficulty=diff,Type=mt,Name=mn,Objective=ob}); if getMyMission()then created=true; break end end else getRemote:InvokeServer("S_Missions","Create",{Difficulty=sd,Type=mt,Name=mn,Objective=ob}); if getMyMission()then created=true end end; if not getgenv().AutoStart then break end; if not created then retries=retries+1; if retries>=10 then getgenv().AutoStart=false; AutoStartToggle:Set(false); break end; task.wait(math.min(retries*2,20)); continue end; retries=0; task.wait(0.5); getRemote:InvokeServer("S_Missions","Start"); task.wait(5) end end) end end})
local StartTypeDropdown = AutoStartTab:CreateDropdown({Name = "Type", Options = {"Missions","Raids"}, CurrentOption = {DropdownConfig._lastType or "Missions"}, Flag = "StartTypeDropdown", Callback = function(o) DropdownConfig._lastType=o[1]; SaveConfig(DropdownConfig) end})
local MissionMapDropdown = AutoStartTab:CreateDropdown({Name = "Mission Map", Options = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"}, CurrentOption = {"Shiganshina"}, Flag = "MissionMapDropdown", Callback = function(o) MissionObjectiveDropdown:Refresh(Missions[o[1]]or{},true) end})
local MissionObjectiveDropdown = AutoStartTab:CreateDropdown({Name = "Mission Objective", Options = Missions["Shiganshina"], CurrentOption = {"Skirmish"}, Flag = "MissionObjectiveDropdown", Callback = function(o) end})
local MissionDifficultyDropdown = AutoStartTab:CreateDropdown({Name = "Mission Difficulty", Options = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"}, CurrentOption = {"Normal"}, Flag = "MissionDifficultyDropdown", Callback = function(o) end})
local RaidMapDropdown = AutoStartTab:CreateDropdown({Name = "Raid Map", Options = {"Trost","Shiganshina","Stohess"}, CurrentOption = {"Trost"}, Flag = "RaidMapDropdown", Callback = function(o) RaidObjectiveDropdown:Refresh(Missions[o[1]]or{},true) end})
local RaidObjectiveDropdown = AutoStartTab:CreateDropdown({Name = "Raid Objective", Options = Missions["Trost"], CurrentOption = {"Skirmish"}, Flag = "RaidObjectiveDropdown", Callback = function(o) end})
local RaidDifficultyDropdown = AutoStartTab:CreateDropdown({Name = "Raid Difficulty", Options = {"Hard","Severe","Aberrant","Hardest"}, CurrentOption = {"Hard"}, Flag = "RaidDifficultyDropdown", Callback = function(o) end})
AutoStartTab:CreateParagraph({Title = "Raid Info", Content = "Trost: Attack Titan | Shiganshina: Armored | Stohess: Female"})
local ModifiersDropdown = AutoStartTab:CreateDropdown({Name = "Modifiers", Options = {"No Perks","No Skills","No Talents","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"}, CurrentOption = {}, Flag = "ModifiersDropdown", Multi = true, Callback = function(o) end})

-- TAB 4: Upgrades
local UpgradesTab = Window:CreateTab("Upgrades", "crown")
UpgradesTab:CreateSection("Gear")
local AutoUpgradeToggle = UpgradesTab:CreateToggle({Name = "Upgrade Gear", CurrentValue = false, Flag = "AutoUpgradeToggle", Callback = function(v) getgenv().AutoUpgrade=v end})
UpgradesTab:CreateSection("Perks")
local AutoEnhanceToggle = UpgradesTab:CreateToggle({Name = "Enhance Perks", CurrentValue = false, Flag = "AutoEnhanceToggle", Callback = function(v) getgenv().AutoPerk=v end})
local PerkSlotDropdown = UpgradesTab:CreateDropdown({Name = "Perk Slot", Options = {"Defense","Support","Family","Extra","Offense","Body"}, CurrentOption = {"Body"}, Flag = "PerkSlotDropdown", Callback = function(o) end})
local SelectPerksDropdown = UpgradesTab:CreateDropdown({Name = "Perks to use (Food)", Options = {"Common","Rare","Epic","Legendary"}, CurrentOption = {}, Flag = "SelectPerksDropdown", Multi = true, Callback = function(o) end})
UpgradesTab:CreateSection("Skill Tree")
local AutoSkillTree = UpgradesTab:CreateToggle({Name = "Auto Skill Tree", CurrentValue = false, Flag = "AutoSkillTree", Callback = function(v) getgenv().AutoSkillTree=v end})
local MiddlePathDropdown = UpgradesTab:CreateDropdown({Name = "Middle Path", Options = {"Damage","Critical"}, CurrentOption = {"Critical"}, Flag = "MiddlePathDropdown", Callback = function(o) end})
local LeftPathDropdown = UpgradesTab:CreateDropdown({Name = "Left Path", Options = {"Regen","Cooldown Reduction"}, CurrentOption = {"Cooldown Reduction"}, Flag = "LeftPathDropdown", Callback = function(o) end})
local RightPathDropdown = UpgradesTab:CreateDropdown({Name = "Right Path", Options = {"Health","Damage Reduction"}, CurrentOption = {"Damage Reduction"}, Flag = "RightPathDropdown", Callback = function(o) end})
local Priority1Dropdown = UpgradesTab:CreateDropdown({Name = "Priority 1", Options = {"Left","Middle","Right","None"}, CurrentOption = {"Middle"}, Flag = "Priority1Dropdown", Callback = function(o) end})
local Priority2Dropdown = UpgradesTab:CreateDropdown({Name = "Priority 2", Options = {"Left","Middle","Right","None"}, CurrentOption = {"Left"}, Flag = "Priority2Dropdown", Callback = function(o) end})
local Priority3Dropdown = UpgradesTab:CreateDropdown({Name = "Priority 3", Options = {"Left","Middle","Right","None"}, CurrentOption = {"None"}, Flag = "Priority3Dropdown", Callback = function(o) end})

-- TAB 5: Prestige & Slot
local PrestigeSlotTab = Window:CreateTab("Prestige & Slot", "star")
PrestigeSlotTab:CreateSection("Slot Selection")
local AutoSelectSlot = PrestigeSlotTab:CreateToggle({Name = "Auto Select Slot", CurrentValue = false, Flag = "AutoSelectSlot", Callback = function(v) getgenv().AutoSlot=v end})
local SelectSlotDropdown = PrestigeSlotTab:CreateDropdown({Name = "Select Slot", Options = {"Slot A","Slot B","Slot C"}, CurrentOption = {"Slot A"}, Flag = "SelectSlotDropdown", Callback = function(o) end})
PrestigeSlotTab:CreateSection("Prestige")
local AutoPrestigeToggle = PrestigeSlotTab:CreateToggle({Name = "Auto Prestige", CurrentValue = false, Flag = "AutoPrestigeToggle", Callback = function(v) getgenv().AutoPrestige=v end})
local SelectBoostDropdown = PrestigeSlotTab:CreateDropdown({Name = "Select Boost", Options = {"Luck Boost","EXP Boost","Gold Boost"}, CurrentOption = {"Luck Boost"}, Flag = "SelectBoostDropdown", Callback = function(o) end})
local PrestigeGoldSlider = PrestigeSlotTab:CreateSlider({Name = "Prestige Gold (M)", Range = {0,100}, Increment = 1, Suffix = "M", CurrentValue = 0, Flag = "PrestigeGoldSlider", Callback = function(v) end})

-- TAB 6: Family Roll
local FamilyRollTab = Window:CreateTab("Family Roll", "users")
FamilyRollTab:CreateSection("Auto Roll Family")
local AutoRollToggle = FamilyRollTab:CreateToggle({Name = "Auto Roll", CurrentValue = false, Flag = "AutoRollToggle", Callback = function(v) getgenv().AutoRoll=v end})
local SelectFamilyInput = FamilyRollTab:CreateInput({Name = "Select Families", PlaceholderText = "Fritz,Yeager", RemoveTextAfterFocusLost = false, Flag = "SelectFamilyInput", Callback = function(t) end})
local SelectFamilyRarity = FamilyRollTab:CreateDropdown({Name = "Stop At", Options = familyRaritiesOptions, CurrentOption = {}, Flag = "SelectFamilyRarity", Multi = true, Callback = function(o) end})
FamilyRollTab:CreateParagraph({Title = "Info", Content = "Separate with commas (Fritz,Yeager)"})

-- TAB 7: Webhook & Misc
local WebhookMiscTab = Window:CreateTab("Webhook & Misc", "link")
WebhookMiscTab:CreateSection("Webhooks")
local ToggleRewardWebhook = WebhookMiscTab:CreateToggle({Name = "Reward Webhook", CurrentValue = false, Flag = "ToggleRewardWebhook", Callback = function(v) getgenv().RewardWebhook=v end})
local ToggleMythicalFamilyWebhook = WebhookMiscTab:CreateToggle({Name = "Mythical Family Webhook", CurrentValue = false, Flag = "ToggleMythicalFamilyWebhook", Callback = function(v) getgenv().MythicalFamilyWebhook=v end})
local WebhookUrlInput = WebhookMiscTab:CreateInput({Name = "Webhook URL", PlaceholderText = "https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost = false, Flag = "WebhookUrl", Callback = function(t) webhook=t end})
WebhookMiscTab:CreateSection("FPS & Performance")
local Disable3DRendering = WebhookMiscTab:CreateToggle({Name = "Disable 3D Rendering", CurrentValue = false, Flag = "Disable3DRendering", Callback = function(v) RunService:Set3dRenderingEnabled(not v) end})
WebhookMiscTab:CreateSection("Map Cleanup")
local DeleteMapToggle = WebhookMiscTab:CreateToggle({Name = "Delete Map (FPS Boost)", CurrentValue = DropdownConfig.DeleteMap or false, Flag = "DeleteMapToggle", Callback = function(v) getgenv().DeleteMap=v; DropdownConfig.DeleteMap=v; SaveConfig(DropdownConfig); if v then DeleteMap() end end})

-- TAB 8: Discord
local DiscordTab = Window:CreateTab("Discord", "discord")
DiscordTab:CreateSection("Join Our Discord")
DiscordTab:CreateButton({Name = "Copy Discord Invite", Callback = function() setclipboard("https://discord.gg/xq5VCpFQsH"); Rayfield:Notify({Title="Discord",Content="Link copied!",Duration=3,Image="coins"}) end})
DiscordTab:CreateParagraph({Title = "Info", Content = "https://discord.gg/xq5VCpFQsH"})

-- TAB 9: Settings
local SettingsTab = Window:CreateTab("Settings", "settings")
SettingsTab:CreateSection("Keybinds")
local MenuKeybind = SettingsTab:CreateKeybind({Name = "Menu Toggle", CurrentKeybind = "RightControl", HoldToInteract = false, Flag = "MenuKeybind", Callback = function(k) end})
SettingsTab:CreateSection("Config")
SettingsTab:CreateParagraph({Title = "Config", Content = "Auto-saved to THUB/aotr_config"})

-- Auto Farm Logic (needs to be defined before UI)
local AutoFarm = {}
AutoFarm._running = false

getgenv().AutoFarmConfig = {AttackCooldown = 1, ReloadCooldown = 1, AttackRange = 150, MoveSpeed = 400, HeightOffset = 250, MovementMode = "Hover"}
getgenv().MasteryFarmConfig = {Enabled = false, Mode = "Both"}

task.spawn(function() while true do local i = lp.Character and lp.Character:FindFirstChild("Injuries"); if i then for _,v in i:GetChildren() do v:Destroy() end end; task.wait(1) end end)

function AutoFarm:Start()
	if self._running or isLobby then return end
	self._running = true
	task.spawn(function()
		while self._running do
			if not checkMission() then task.wait(1); continue end
			local si = lp:GetAttribute("Slot")
			local sd = si and mapData and mapData.Slots and mapData.Slots[si]
			if not sd then task.wait(1); continue end
			local tf = workspace:FindFirstChild("Titans")
			if not tf then task.wait(); continue end
			local char = lp.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then task.wait(); continue end
			for _,v in char:GetDescendants() do if v:IsA("BasePart") then v.CanCollide = false end end
			-- Simple attack logic
			for _,t in tf:GetChildren() do
				if t:GetAttribute("Killed") then continue end
				local nape = t:FindFirstChild("Hitboxes") and t.Hitboxes:FindFirstChild("Hit") and t.Hitboxes.Hit:FindFirstChild("Nape")
				if nape then
					local dist = (hrp.Position - nape.Position).Magnitude
					if dist <= getgenv().AutoFarmConfig.AttackRange then
						if getgenv().AutoFarmConfig.MovementMode == "Hover" then
							local dir = (nape.Position + Vector3.new(0,getgenv().AutoFarmConfig.HeightOffset,0) - hrp.Position)
							hrp.AssemblyLinearVelocity = dir.Unit * getgenv().AutoFarmConfig.MoveSpeed
						else
							hrp.CFrame = CFrame.new(nape.Position + Vector3.new(0,getgenv().AutoFarmConfig.HeightOffset,0))
						end
						if sd.Weapon == "Blades" then
							postRemote:FireServer("Attacks", "Slash", true)
							postRemote:FireServer("Hitboxes", "Register", nape, math.random(625,850))
						end
						break
					end
				end
			end
			task.wait()
		end
	end)
end

function AutoFarm:Stop() self._running = false end

-- Weapon reload
local lastReloadTime = 0
local autoReloadEnabled = false
local autoRefillEnabled = false
local isReloading = false
local function handleWeaponReload()
	if not autoReloadEnabled or isReloading then return end
	if os.clock() - lastReloadTime < getgenv().AutoFarmConfig.ReloadCooldown then return end
	isReloading = true; lastReloadTime = os.clock()
	local refillPart = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Reloads") and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks") and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
	if refillPart then postRemote:FireServer("Attacks", "Reload", refillPart) end
	task.delay(1, function() isReloading = false end)
end
task.spawn(function() while true do pcall(handleWeaponReload); task.wait(0.5) end end)

-- Webhook
local webhook
local function formatTable(t) local s=""; for k,v in pairs(t) do s..=string.format("%s: %s\n",k,tostring(v)) end; return s~=""and s or "None" end
local function formatItems(t) local s=""; for n,q in pairs(t) do s..=string.format("[+] %s (x%s)\n",string.gsub(n,"_"," "),q) end; return s~=""and s or "None" end

-- Anti-AFK
local vu = game:GetService("VirtualUser")
lp.Idled:Connect(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)

-- Load config
task.spawn(function() Rayfield:LoadConfiguration() end)
