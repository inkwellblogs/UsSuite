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
local V3_ZERO = Vector3.new(0, 0, 0)

local mapData = nil
local startLoadTime = os.clock()
local isLobby = game.PlaceId == 14916516914

repeat
    task.wait(1)
    mapData = getRemote:InvokeServer("Data", "Copy")
until mapData ~= nil or os.clock() - startLoadTime > 15

if mapData and mapData.Map.Type == "Raids" then
    repeat task.wait() until workspace:GetAttribute("Finalised")
end

local function checkMission()
    if workspace:GetAttribute("Type") then return true end
    mapData = getRemote:InvokeServer("Data", "Copy")
    return mapData ~= nil and mapData.Map ~= nil and mapData.Slots ~= nil
end

getgenv().AutoFarmConfig = {AttackCooldown = 1, AttackRange = 150, MoveSpeed = 400, HeightOffset = 250, MovementMode = "Hover"}
getgenv().MasteryFarmConfig = {Enabled = false, Mode = "Both"}
getgenv().AutoEscape = false
getgenv().SoloOnly = false
getgenv().DeleteMap = false
getgenv().AutoFailsafe = false

local AutoFarm = {}
AutoFarm._running = false

function AutoFarm:Start()
    if self._running or isLobby then return end
    self._running = true
    
    task.spawn(function()
        while self._running do
            if not checkMission() then task.wait(1); continue end
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(); continue end
            
            -- No-collide
            for _, p in char:GetDescendants() do if p:IsA("BasePart") then p.CanCollide = false end end
            
            local tf = workspace:FindFirstChild("Titans")
            if not tf then task.wait(); continue end
            
            -- Solo check
            if getgenv().SoloOnly and (workspace:GetAttribute("Player_Count") or #Players:GetPlayers()) > 1 then
                self:Stop()
                getRemote:InvokeServer("Functions", "Teleport", "Lobby")
                task.wait(0.5); TeleportService:Teleport(14916516914, lp)
                break
            end
            
            -- Failsafe
            if getgenv().AutoFailsafe then
                if not self.missionStartTime then self.missionStartTime = os.clock() end
                if os.clock() - self.missionStartTime >= 900 then
                    self:Stop()
                    getRemote:InvokeServer("Functions", "Teleport", "Lobby")
                    task.wait(0.5); TeleportService:Teleport(14916516914, lp)
                    break
                end
            end
            
            -- Find target
            for _, t in tf:GetChildren() do
                if t:GetAttribute("Killed") then continue end
                local nape = t:FindFirstChild("Hitboxes") and t.Hitboxes:FindFirstChild("Hit") and t.Hitboxes.Hit:FindFirstChild("Nape")
                if nape then
                    local dist = (hrp.Position - nape.Position).Magnitude
                    if dist > getgenv().AutoFarmConfig.AttackRange then
                        -- Move towards
                        local tp = nape.Position + Vector3.new(0, getgenv().AutoFarmConfig.HeightOffset, 0)
                        if getgenv().AutoFarmConfig.MovementMode == "Hover" then
                            local dir = tp - hrp.Position
                            hrp.AssemblyLinearVelocity = dir.Unit * getgenv().AutoFarmConfig.MoveSpeed
                        else
                            hrp.CFrame = CFrame.new(tp)
                        end
                    else
                        -- Attack
                        local si = lp:GetAttribute("Slot")
                        local sd = si and mapData and mapData.Slots and mapData.Slots[si]
                        if sd then
                            postRemote:FireServer("Attacks", "Slash", true)
                            postRemote:FireServer("Hitboxes", "Register", nape, math.random(625, 850))
                        end
                    end
                    break
                end
            end
            task.wait()
        end
    end)
end

function AutoFarm:Stop()
    self._running = false
    self.missionStartTime = nil
end

-- Weapon reload
local autoReloadEnabled = false
local isReloading = false
task.spawn(function()
    while true do
        if autoReloadEnabled and not isReloading then
            local refill = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Reloads") and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks") and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
            if refill then
                isReloading = true
                postRemote:FireServer("Attacks", "Reload", refill)
                task.delay(1, function() isReloading = false end)
            end
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- RAYFIELD UI
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "TITANIC HUB",
   LoadingTitle = "TITANIC HUB",
   LoadingSubtitle = "by TH Developers",
   ConfigurationSaving = {Enabled = true, FolderName = "THUB", FileName = "aotr_config"},
   Discord = {Enabled = true, Invite = "xq5VCpFQsH", RememberJoins = true},
   KeySystem = false,
})

-- TAB 1: Farm
local FarmTab = Window:CreateTab("Farm", "swords")
FarmTab:CreateSection("Auto Farm")
local AutoKillToggle = FarmTab:CreateToggle({Name = "Auto Farm", CurrentValue = false, Flag = "AutoKillToggle", Callback = function(v) if v then AutoFarm:Start() else AutoFarm:Stop() end end})
FarmTab:CreateToggle({Name = "Titan Mastery Farm", CurrentValue = false, Flag = "MasteryFarmToggle", Callback = function(v) getgenv().MasteryFarmConfig.Enabled = v end})
FarmTab:CreateDropdown({Name = "Mastery Mode", Options = {"Punching","Skill Usage","Both"}, CurrentOption = {"Both"}, Flag = "MasteryModeDropdown", Callback = function(o) getgenv().MasteryFarmConfig.Mode = o[1] end})
FarmTab:CreateSection("Movement")
FarmTab:CreateDropdown({Name = "Movement Mode", Options = {"Hover","Teleport"}, CurrentOption = {"Hover"}, Flag = "MovementModeDropdown", Callback = function(o) getgenv().AutoFarmConfig.MovementMode = o[1] end})
FarmTab:CreateSlider({Name = "Hover Speed", Range = {100,500}, Increment = 5, Suffix = "Studs", CurrentValue = 400, Flag = "HoverSpeedSlider", Callback = function(v) getgenv().AutoFarmConfig.MoveSpeed = v end})
FarmTab:CreateSlider({Name = "Float Height", Range = {100,300}, Increment = 5, Suffix = "Studs", CurrentValue = 250, Flag = "FloatHeightSlider", Callback = function(v) getgenv().AutoFarmConfig.HeightOffset = v end})
FarmTab:CreateSection("Combat")
FarmTab:CreateToggle({Name = "Auto Reload/Refill", CurrentValue = false, Flag = "AutoReloadToggle", Callback = function(v) autoReloadEnabled = v end})
FarmTab:CreateToggle({Name = "Auto Escape", CurrentValue = false, Flag = "AutoEscapeToggle", Callback = function(v) getgenv().AutoEscape = v end})
FarmTab:CreateSection("Misc Options")
FarmTab:CreateToggle({Name = "Solo Only", CurrentValue = false, Flag = "SoloOnlyToggle", Callback = function(v) getgenv().SoloOnly = v end})
FarmTab:CreateDropdown({Name = "Farm Options", Options = {"Failsafe"}, CurrentOption = {}, Flag = "FarmOptionsDropdown", Multi = true, Callback = function(o) getgenv().AutoFailsafe = #o > 0 end})

-- TAB 2: TS Quest
local TSQuestTab = Window:CreateTab("TS Quest", "scroll")
TSQuestTab:CreateSection("Coming Soon")
TSQuestTab:CreateParagraph({Title = "TS Quest", Content = "Future features coming soon!"})

-- TAB 3: Auto Start
local AutoStartTab = Window:CreateTab("Auto Start", "play")
AutoStartTab:CreateSection("Auto Start")
AutoStartTab:CreateButton({Name = "Return to Lobby", Callback = function() getRemote:InvokeServer("Functions","Teleport","Lobby"); task.wait(0.5); TeleportService:Teleport(14916516914,lp) end})
AutoStartTab:CreateToggle({Name = "Auto Start", CurrentValue = false, Flag = "AutoStartToggle", Callback = function(v) getgenv().AutoStart = v end})
AutoStartTab:CreateDropdown({Name = "Type", Options = {"Missions","Raids"}, CurrentOption = {"Missions"}, Flag = "StartTypeDropdown", Callback = function(o) end})
AutoStartTab:CreateDropdown({Name = "Difficulty", Options = {"Easy","Normal","Hard","Severe","Aberrant"}, CurrentOption = {"Normal"}, Flag = "DifficultyDropdown", Callback = function(o) end})

-- TAB 4: Upgrades
local UpgradesTab = Window:CreateTab("Upgrades", "crown")
UpgradesTab:CreateSection("Gear")
UpgradesTab:CreateToggle({Name = "Upgrade Gear", CurrentValue = false, Flag = "AutoUpgradeToggle", Callback = function(v) getgenv().AutoUpgrade = v end})
UpgradesTab:CreateSection("Perks")
UpgradesTab:CreateToggle({Name = "Enhance Perks", CurrentValue = false, Flag = "AutoEnhanceToggle", Callback = function(v) getgenv().AutoPerk = v end})
UpgradesTab:CreateSection("Skill Tree")
UpgradesTab:CreateToggle({Name = "Auto Skill Tree", CurrentValue = false, Flag = "AutoSkillTree", Callback = function(v) getgenv().AutoSkillTree = v end})

-- TAB 5: Prestige & Slot
local PrestigeSlotTab = Window:CreateTab("Prestige & Slot", "star")
PrestigeSlotTab:CreateSection("Slot")
PrestigeSlotTab:CreateToggle({Name = "Auto Select Slot", CurrentValue = false, Flag = "AutoSelectSlot", Callback = function(v) getgenv().AutoSlot = v end})
PrestigeSlotTab:CreateDropdown({Name = "Slot", Options = {"Slot A","Slot B","Slot C"}, CurrentOption = {"Slot A"}, Flag = "SelectSlotDropdown", Callback = function(o) end})
PrestigeSlotTab:CreateSection("Prestige")
PrestigeSlotTab:CreateToggle({Name = "Auto Prestige", CurrentValue = false, Flag = "AutoPrestigeToggle", Callback = function(v) getgenv().AutoPrestige = v end})

-- TAB 6: Family Roll
local FamilyRollTab = Window:CreateTab("Family Roll", "users")
FamilyRollTab:CreateSection("Auto Roll")
FamilyRollTab:CreateToggle({Name = "Auto Roll", CurrentValue = false, Flag = "AutoRollToggle", Callback = function(v) getgenv().AutoRoll = v end})
FamilyRollTab:CreateInput({Name = "Families", PlaceholderText = "Fritz,Yeager", RemoveTextAfterFocusLost = false, Flag = "SelectFamilyInput", Callback = function(t) end})

-- TAB 7: Webhook & Misc
local WebhookMiscTab = Window:CreateTab("Webhook & Misc", "link")
WebhookMiscTab:CreateSection("Webhooks")
WebhookMiscTab:CreateToggle({Name = "Reward Webhook", CurrentValue = false, Flag = "RewardWebhook", Callback = function(v) end})
WebhookMiscTab:CreateInput({Name = "Webhook URL", PlaceholderText = "https://...", RemoveTextAfterFocusLost = false, Flag = "WebhookUrl", Callback = function(t) end})
WebhookMiscTab:CreateSection("FPS")
WebhookMiscTab:CreateToggle({Name = "Disable 3D Rendering", CurrentValue = false, Flag = "Disable3DRendering", Callback = function(v) RunService:Set3dRenderingEnabled(not v) end})

-- TAB 8: Discord
local DiscordTab = Window:CreateTab("Discord", "discord")
DiscordTab:CreateSection("Join Us")
DiscordTab:CreateButton({Name = "Copy Invite", Callback = function() setclipboard("https://discord.gg/xq5VCpFQsH"); Rayfield:Notify({Title="Discord",Content="Copied!",Duration=3,Image="coins"}) end})

-- TAB 9: Settings
local SettingsTab = Window:CreateTab("Settings", "settings")
SettingsTab:CreateSection("Keybinds")
SettingsTab:CreateKeybind({Name = "Menu Toggle", CurrentKeybind = "RightControl", HoldToInteract = false, Flag = "MenuKeybind", Callback = function(k) end})

-- Anti-AFK
local vu = game:GetService("VirtualUser")
lp.Idled:Connect(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)

-- Load config
task.spawn(function() Rayfield:LoadConfiguration() end)
