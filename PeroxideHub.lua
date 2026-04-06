--[[
    Peroxide Hub v3.0 — Rayfield Edition
    Built on Rayfield UI (widely used, anticheat-safe GUI fingerprint)
    Races: Soul Reaper | Quincy | Hollow/Arrancar | Fullbringer
    Features: Fast Travel | ESP | Auto Farm | Stats | Auto Heal | Boss Notify | Auto Block
    Anti-Detection: Humanized movement, random delays, gradual TP, anti-idle
    Toggle: RightShift
]]

------------------------------------------------------
-- STEALTH STARTUP
------------------------------------------------------
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2 + math.random() * 3) -- random 2-5s delay before anything loads

------------------------------------------------------
-- SERVICES
------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------
-- LOAD RAYFIELD
------------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

------------------------------------------------------
-- ANTI-DETECTION HELPERS
------------------------------------------------------
local function randomName(len)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local out = ""
    for _ = 1, (len or 12) do
        local i = math.random(1, #chars)
        out = out .. chars:sub(i, i)
    end
    return out
end

local ESP_TAG = randomName(10)

local function jitterWait(base)
    local mult = 0.8 + math.random() * 0.7
    task.wait(base * mult)
end

------------------------------------------------------
-- CONFIG
------------------------------------------------------
local Config = {
    ESPEnabled = false,
    AutoFarmEnabled = false,
    AutoSkillEnabled = false,
    AutoHealEnabled = false,
    AutoBlockEnabled = false,
    BossNotifyEnabled = false,
    AntiIdleEnabled = true,
    MetahookEnabled = false,
    FarmRange = 80,
    HealThreshold = 30,
    SelectedBuild = "Balanced",
    TPShortRange = 30,
    PlayerRace = "Unknown",
    CurrentLocation = "Unknown",
}

local Connections = {}
local ESPObjects = {}

------------------------------------------------------
-- RACE & LOCATION DETECTION
------------------------------------------------------
local function detectRace()
    local char = LocalPlayer.Character
    if not char then return "Unknown" end
    for _, item in pairs(char:GetChildren()) do
        local name = item.Name:lower()
        if name:find("zanpakuto") or name:find("shikai") or name:find("bankai") or name:find("shinigami") then
            return "Soul Reaper"
        elseif name:find("quincy") or name:find("cross") or name:find("blut") or name:find("vollstandig") then
            return "Quincy"
        elseif name:find("hollow") or name:find("mask") or name:find("cero") or name:find("arrancar") or name:find("resurreccion") then
            return "Hollow"
        elseif name:find("fullbring") or name:find("bringer") then
            return "Fullbringer"
        end
    end
    if LocalPlayer.Team then
        local team = LocalPlayer.Team.Name:lower()
        if team:find("soul") or team:find("shinigami") then return "Soul Reaper" end
        if team:find("quincy") then return "Quincy" end
        if team:find("hollow") or team:find("arrancar") then return "Hollow" end
        if team:find("fullbring") then return "Fullbringer" end
    end
    return "Unknown"
end

local function detectLocation()
    local char = LocalPlayer.Character
    if not char then return "Unknown" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return "Unknown" end
    local pos = hrp.Position
    -- TODO: Replace zone boundaries with real Peroxide map data
    local zones = {
        {name = "Karakura Town",  min = Vector3.new(-500, -50, -500),   max = Vector3.new(500, 500, 500)},
        {name = "Soul Society",   min = Vector3.new(800, -50, -500),    max = Vector3.new(1600, 500, 500)},
        {name = "Hueco Mundo",    min = Vector3.new(-1500, -50, -500),  max = Vector3.new(-700, 500, 500)},
        {name = "Vasanta",        min = Vector3.new(300, -50, -800),    max = Vector3.new(700, 500, -400)},
        {name = "The Storm",      min = Vector3.new(-700, -50, -800),   max = Vector3.new(-300, 500, -400)},
        {name = "Menos Forest",   min = Vector3.new(-1300, -200, -600), max = Vector3.new(-900, 100, -200)},
    }
    for _, zone in ipairs(zones) do
        if pos.X >= zone.min.X and pos.X <= zone.max.X
            and pos.Y >= zone.min.Y and pos.Y <= zone.max.Y
            and pos.Z >= zone.min.Z and pos.Z <= zone.max.Z then
            return zone.name
        end
    end
    return "Unknown"
end

------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isAlive(player)
    local char = player and player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getMyPosition()
    local hrp = getHRP()
    if hrp then
        local pos = hrp.Position
        local coordStr = string.format("Vector3.new(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
        print("=== YOUR POSITION === " .. coordStr)
        pcall(function()
            if setclipboard then setclipboard(coordStr)
            elseif toclipboard then toclipboard(coordStr) end
        end)
        pcall(function()
            if writefile and readfile and isfile then
                local existing = isfile("PeroxideCoords.txt") and readfile("PeroxideCoords.txt") or ""
                writefile("PeroxideCoords.txt", existing .. string.format("[%s] %s -- %s\n", os.date("%H:%M:%S"), coordStr, detectLocation()))
            end
        end)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Saved!", Text = coordStr, Duration = 3})
        end)
    end
end

------------------------------------------------------
-- MOVEMENT (Anti-Detection)
------------------------------------------------------
local function gradualTP(targetPos, steps)
    local hrp = getHRP()
    if not hrp then return end
    steps = steps or 8
    local startPos = hrp.Position
    local dist = (targetPos - startPos).Magnitude
    if dist < Config.TPShortRange then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        return
    end
    for i = 1, steps do
        if not getHRP() then break end
        local midPoint = startPos:Lerp(targetPos, i / steps) + Vector3.new(0, 3, 0)
        hrp.CFrame = CFrame.new(midPoint)
        jitterWait(0.05)
    end
end

local function smartMoveTo(targetPos)
    local hrp = getHRP()
    if not hrp then return end
    local dist = (targetPos - hrp.Position).Magnitude
    if dist <= Config.TPShortRange then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.5, 0), targetPos)
        return
    end
    local hum = getHumanoid()
    if hum then
        hum:MoveTo(targetPos)
        local t = tick()
        while (getHRP().Position - targetPos).Magnitude > Config.TPShortRange and tick() - t < 10 do
            jitterWait(0.2)
            if not isAlive(LocalPlayer) then return end
        end
        local hrp2 = getHRP()
        if hrp2 and (hrp2.Position - targetPos).Magnitude <= Config.TPShortRange then
            hrp2.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.5, 0), targetPos)
        end
    end
end

------------------------------------------------------
-- METAHOOK (Optional)
------------------------------------------------------
local function setupMetahook()
    pcall(function()
        if not getrawmetatable then return end
        local mt = getrawmetatable(game)
        if not mt then return end
        local oldIndex = mt.__index
        if setreadonly then setreadonly(mt, false) end
        mt.__index = newcclosure(function(self, key)
            if self == getHumanoid() then
                if key == "WalkSpeed" then return 16 end
                if key == "JumpPower" then return 50 end
                if key == "JumpHeight" then return 7.2 end
            end
            return oldIndex(self, key)
        end)
        if setreadonly then setreadonly(mt, true) end
    end)
end

------------------------------------------------------
-- ANTI-IDLE
------------------------------------------------------
local function startAntiIdle()
    task.spawn(function()
        while Config.AntiIdleEnabled do
            pcall(function()
                local cam = Workspace.CurrentCamera
                if cam then
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.01), 0)
                    task.wait(0.1)
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(-0.01), 0)
                end
            end)
            task.wait(55 + math.random() * 10)
        end
    end)
end

------------------------------------------------------
-- ENTITY FINDING
------------------------------------------------------
local function findNearestNPC(range)
    local hrp = getHRP()
    if not hrp then return nil, math.huge end
    local nearest, bestDist = nil, range or Config.FarmRange
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj ~= getCharacter() then
            local isPlayer = false
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character == obj then isPlayer = true; break end
            end
            if not isPlayer then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
                if hum and hum.Health > 0 and root then
                    local d = (root.Position - hrp.Position).Magnitude
                    if d < bestDist then nearest = obj; bestDist = d end
                end
            end
        end
    end
    return nearest, bestDist
end

local function findNearestLoot(range)
    local hrp = getHRP()
    if not hrp then return nil end
    local nearest, bestDist = nil, range or Config.FarmRange
    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) then
            local name = obj.Name:lower()
            if name:find("loot") or name:find("drop") or name:find("item") or name:find("chest") or name:find("pickup") then
                local part = obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                if part and part:IsA("BasePart") then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bestDist then nearest = obj; bestDist = d end
                end
            end
        end
    end
    return nearest
end

local function getFaction(player)
    local char = player and player.Character
    if not char then return "Unknown" end
    for _, item in pairs(char:GetChildren()) do
        local name = item.Name:lower()
        if name:find("zanpakuto") or name:find("shikai") or name:find("bankai") then return "Soul Reaper" end
        if name:find("quincy") or name:find("cross") or name:find("blut") then return "Quincy" end
        if name:find("hollow") or name:find("mask") or name:find("cero") or name:find("arrancar") then return "Hollow" end
        if name:find("fullbring") or name:find("bringer") then return "Fullbringer" end
    end
    return "Unknown"
end

local function getFactionColor(faction)
    if faction == "Soul Reaper" then return Color3.fromRGB(85, 170, 255) end
    if faction == "Quincy" then return Color3.fromRGB(200, 210, 255) end
    if faction == "Hollow" then return Color3.fromRGB(255, 80, 80) end
    if faction == "Fullbringer" then return Color3.fromRGB(76, 209, 55) end
    return Color3.fromRGB(160, 160, 176)
end

------------------------------------------------------
-- FACTION DATA
------------------------------------------------------
local RaceSkills = {
    ["Soul Reaper"] = {
        {key = Enum.KeyCode.Z, name = "Shikai Ability 1",  cooldown = 5},
        {key = Enum.KeyCode.X, name = "Shikai Ability 2",  cooldown = 8},
        {key = Enum.KeyCode.C, name = "Kido",              cooldown = 6},
        {key = Enum.KeyCode.V, name = "Flash Step Strike",  cooldown = 10},
    },
    ["Quincy"] = {
        {key = Enum.KeyCode.Z, name = "Heilig Pfeil",      cooldown = 4},
        {key = Enum.KeyCode.X, name = "Blut Vene",         cooldown = 10},
        {key = Enum.KeyCode.C, name = "Licht Regen",       cooldown = 12},
        {key = Enum.KeyCode.V, name = "Vollstandig",       cooldown = 30},
    },
    ["Hollow"] = {
        {key = Enum.KeyCode.Z, name = "Cero",              cooldown = 5},
        {key = Enum.KeyCode.X, name = "Bala",              cooldown = 3},
        {key = Enum.KeyCode.C, name = "Sonido Strike",     cooldown = 7},
        {key = Enum.KeyCode.V, name = "Resurreccion",      cooldown = 30},
    },
    ["Fullbringer"] = {
        {key = Enum.KeyCode.Z, name = "Fullbring Ability 1", cooldown = 5},
        {key = Enum.KeyCode.X, name = "Fullbring Ability 2", cooldown = 8},
        {key = Enum.KeyCode.C, name = "Bringer Light",       cooldown = 6},
        {key = Enum.KeyCode.V, name = "Full Release",        cooldown = 25},
    },
}

-- TODO: Replace all Vector3 values with real in-game coordinates
local LocationData = {
    ["Karakura Town"] = {
        teleports = {
            {name = "Town Center",     pos = Vector3.new(0, 100, 0)},
            {name = "Park",            pos = Vector3.new(200, 100, 150)},
            {name = "Urahara Shop",    pos = Vector3.new(-100, 100, 200)},
            {name = "School Rooftop",  pos = Vector3.new(150, 130, -50)},
            {name = "River Bridge",    pos = Vector3.new(-200, 95, 100)},
        },
        farmSpots = {
            {name = "Hollow NPCs",  pos = Vector3.new(100, 100, 100),  races = {"Soul Reaper", "Quincy", "Fullbringer"}},
            {name = "Quincy Mobs",  pos = Vector3.new(-150, 100, -100), races = {"Hollow"}},
        },
        chests = {
            {name = "Park Chest",     pos = Vector3.new(210, 100, 160)},
            {name = "Alley Chest",    pos = Vector3.new(-80, 100, 50)},
            {name = "Rooftop Chest",  pos = Vector3.new(160, 135, -40)},
        },
    },
    ["Soul Society"] = {
        teleports = {
            {name = "Seireitei Gate",   pos = Vector3.new(1000, 100, 0)},
            {name = "Seireitei Center", pos = Vector3.new(1200, 100, 200)},
            {name = "Training Grounds", pos = Vector3.new(1100, 100, -100)},
            {name = "Sokyoku Hill",     pos = Vector3.new(1300, 150, 100)},
            {name = "Squad Barracks",   pos = Vector3.new(1050, 100, 150)},
        },
        farmSpots = {
            {name = "Training Dummies", pos = Vector3.new(1120, 100, -90),  races = {"Soul Reaper"}},
            {name = "Invader Hollows",  pos = Vector3.new(1250, 100, 50),   races = {"Soul Reaper"}},
            {name = "Stealth Farm",     pos = Vector3.new(1150, 100, 200),  races = {"Hollow", "Quincy", "Fullbringer"}},
        },
        chests = {
            {name = "Barracks Chest",   pos = Vector3.new(1060, 100, 160)},
            {name = "Hilltop Chest",    pos = Vector3.new(1310, 155, 110)},
        },
    },
    ["Hueco Mundo"] = {
        teleports = {
            {name = "Desert Entrance",  pos = Vector3.new(-1000, 100, 0)},
            {name = "Las Noches Gate",  pos = Vector3.new(-1200, 100, 200)},
            {name = "Menos Forest",     pos = Vector3.new(-1100, 50, -400)},
            {name = "Hollow Nest",      pos = Vector3.new(-1050, 100, 100)},
            {name = "Arrancar Palace",  pos = Vector3.new(-1300, 120, 300)},
        },
        farmSpots = {
            {name = "Menos Grande",     pos = Vector3.new(-1100, 60, -380), races = {"Hollow", "Arrancar"}},
            {name = "Lesser Hollows",   pos = Vector3.new(-1050, 100, 80),  races = {"Soul Reaper", "Quincy", "Fullbringer"}},
            {name = "Adjuchas Hunt",    pos = Vector3.new(-1200, 100, 100), races = {"Hollow"}},
        },
        chests = {
            {name = "Desert Chest",     pos = Vector3.new(-1020, 100, 50)},
            {name = "Cave Chest",       pos = Vector3.new(-1120, 40, -350)},
            {name = "Palace Chest",     pos = Vector3.new(-1290, 125, 310)},
        },
    },
    ["Vasanta"] = {
        teleports = {
            {name = "Vasanta Center",   pos = Vector3.new(500, 100, -500)},
            {name = "Vasanta Shrine",   pos = Vector3.new(550, 110, -550)},
        },
        farmSpots = {
            {name = "Vasanta Mobs",     pos = Vector3.new(520, 100, -480), races = {"Soul Reaper", "Quincy", "Hollow", "Fullbringer"}},
        },
        chests = {
            {name = "Shrine Chest",     pos = Vector3.new(560, 112, -555)},
        },
    },
    ["The Storm"] = {
        teleports = {
            {name = "Storm Center",     pos = Vector3.new(-500, 100, -500)},
            {name = "Storm Edge",       pos = Vector3.new(-450, 100, -450)},
        },
        farmSpots = {
            {name = "Storm Enemies",    pos = Vector3.new(-490, 100, -490), races = {"Soul Reaper", "Quincy", "Hollow", "Fullbringer"}},
        },
        chests = {
            {name = "Storm Chest",      pos = Vector3.new(-470, 100, -470)},
        },
    },
}

local BuildPresets = {
    ["Soul Reaper"] = {
        ["Balanced"]    = {STR = 1, RES = 1, SPD = 1, REI = 1},
        ["Kenpachi"]    = {STR = 3, RES = 1, SPD = 1, REI = 0},
        ["Tank"]        = {STR = 1, RES = 3, SPD = 1, REI = 0},
        ["Flash Step"]  = {STR = 1, RES = 0, SPD = 3, REI = 1},
        ["Kido Master"] = {STR = 0, RES = 1, SPD = 1, REI = 3},
    },
    ["Quincy"] = {
        ["Balanced"]    = {STR = 1, RES = 1, SPD = 1, REI = 1},
        ["Letzt Stil"]  = {STR = 0, RES = 1, SPD = 1, REI = 3},
        ["Blut Tank"]   = {STR = 1, RES = 3, SPD = 1, REI = 0},
        ["Speed Archer"]= {STR = 1, RES = 0, SPD = 3, REI = 1},
    },
    ["Hollow"] = {
        ["Balanced"]    = {STR = 1, RES = 1, SPD = 1, REI = 1},
        ["Berserker"]   = {STR = 3, RES = 1, SPD = 1, REI = 0},
        ["Hierro Tank"] = {STR = 1, RES = 3, SPD = 0, REI = 1},
        ["Sonido Rush"] = {STR = 1, RES = 0, SPD = 3, REI = 1},
        ["Cero Spam"]   = {STR = 0, RES = 1, SPD = 1, REI = 3},
    },
    ["Fullbringer"] = {
        ["Balanced"]    = {STR = 1, RES = 1, SPD = 1, REI = 1},
        ["Power"]       = {STR = 3, RES = 1, SPD = 1, REI = 0},
        ["Bringer Speed"] = {STR = 1, RES = 0, SPD = 3, REI = 1},
        ["Spirit Focus"]= {STR = 0, RES = 1, SPD = 1, REI = 3},
    },
}

------------------------------------------------------
-- ESP SYSTEM
------------------------------------------------------
local function cleanupESP()
    for player, bb in pairs(ESPObjects) do
        if bb and bb.Parent then bb:Destroy() end
    end
    ESPObjects = {}
end

local function createESPBillboard(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    if ESPObjects[player] then ESPObjects[player]:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = ESP_TAG
    bb.Adornee = head
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local nl = Instance.new("TextLabel")
    nl.Name = "N"
    nl.Size = UDim2.new(1, 0, 0.5, 0)
    nl.BackgroundTransparency = 1
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 13
    nl.TextStrokeTransparency = 0.4
    nl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nl.Text = player.Name
    nl.Parent = bb

    local il = Instance.new("TextLabel")
    il.Name = "I"
    il.Size = UDim2.new(1, 0, 0.5, 0)
    il.Position = UDim2.new(0, 0, 0.5, 0)
    il.BackgroundTransparency = 1
    il.Font = Enum.Font.Gotham
    il.TextSize = 10
    il.TextStrokeTransparency = 0.4
    il.TextStrokeColor3 = Color3.new(0, 0, 0)
    il.Parent = bb

    ESPObjects[player] = bb
end

local function updateESP()
    local myHRP = getHRP()
    if not myHRP then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local bb = ESPObjects[player]
            if not bb or not bb.Parent then createESPBillboard(player); bb = ESPObjects[player] end
            if bb then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
                    local faction = getFaction(player)
                    local color = getFactionColor(faction)
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hp = hum and math.floor(hum.Health) or 0
                    local n = bb:FindFirstChild("N")
                    local i = bb:FindFirstChild("I")
                    if n then n.TextColor3 = color; n.Text = player.Name end
                    if i then i.TextColor3 = color; i.Text = string.format("[%s] %dm | HP:%d", faction, dist, hp) end
                else
                    if bb.Parent then bb:Destroy() end
                    ESPObjects[player] = nil
                end
            end
        end
    end
    for player, bb in pairs(ESPObjects) do
        if not player.Parent then
            if bb and bb.Parent then bb:Destroy() end
            ESPObjects[player] = nil
        end
    end
end

------------------------------------------------------
-- AUTO FARM LOOP
------------------------------------------------------
local farmStatusLabel = nil

local function runAutoFarm()
    while Config.AutoFarmEnabled and isAlive(LocalPlayer) do
        local hrp = getHRP()
        if not hrp then jitterWait(1); continue end

        local npc, dist = findNearestNPC(Config.FarmRange)
        if npc then
            local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc:FindFirstChild("Head")
            if npcRoot then
                if dist > Config.TPShortRange then
                    local hum = getHumanoid()
                    if hum then hum:MoveTo(npcRoot.Position) end
                    jitterWait(0.5)
                else
                    hrp.CFrame = CFrame.new(npcRoot.Position + Vector3.new(0, 0, 3), npcRoot.Position)
                end
                jitterWait(0.1)
                pcall(function()
                    local tool = getCharacter():FindFirstChildOfClass("Tool")
                    if tool then tool:Activate() end
                end)
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    task.wait(0.05)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end)
            end
            jitterWait(0.3)
        else
            local loot = findNearestLoot(Config.FarmRange)
            if loot then
                local pos
                if loot:IsA("Model") then
                    local part = loot:FindFirstChild("HumanoidRootPart") or loot.PrimaryPart or loot:FindFirstChildWhichIsA("BasePart")
                    if part then pos = part.Position end
                else
                    pos = loot.Position
                end
                if pos then
                    smartMoveTo(pos)
                    jitterWait(0.3)
                    pcall(function()
                        if loot:IsA("BasePart") and firetouchinterest then
                            firetouchinterest(hrp, loot, 0)
                            task.wait(0.1)
                            firetouchinterest(hrp, loot, 1)
                        end
                    end)
                end
                jitterWait(0.3)
            else
                jitterWait(1)
            end
        end
        jitterWait(0.15)
    end
end

------------------------------------------------------
-- DETECT RACE ON STARTUP
------------------------------------------------------
Config.PlayerRace = detectRace()
Config.CurrentLocation = detectLocation()

------------------------------------------------------
-- RAYFIELD GUI
------------------------------------------------------
local Window = Rayfield:CreateWindow({
    Name = "Peroxide Hub v3",
    Icon = 0,
    LoadingTitle = "Peroxide Hub",
    LoadingSubtitle = "by imoukhs",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PeroxideHub",
        FileName = "Config"
    },
    KeySystem = false,
})

------------------------------------------------------
-- TAB: FAST TRAVEL
------------------------------------------------------
local TravelTab = Window:CreateTab("Travel", 4483362458)

TravelTab:CreateSection("Tools")

TravelTab:CreateButton({
    Name = "Print My Position (saves + copies)",
    Callback = getMyPosition,
})

TravelTab:CreateSection("Current: " .. Config.CurrentLocation)

-- Add teleports for each location
for locName, data in pairs(LocationData) do
    TravelTab:CreateSection(locName)

    for _, tp in ipairs(data.teleports) do
        TravelTab:CreateButton({
            Name = tp.name,
            Callback = function()
                gradualTP(tp.pos, 10)
            end,
        })
    end

    -- Chests
    if data.chests and #data.chests > 0 then
        for _, chest in ipairs(data.chests) do
            TravelTab:CreateButton({
                Name = "[Chest] " .. chest.name,
                Callback = function()
                    gradualTP(chest.pos, 10)
                end,
            })
        end
    end
end

------------------------------------------------------
-- TAB: ESP
------------------------------------------------------
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateSection("Player ESP")

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(state)
        Config.ESPEnabled = state
        if state then
            for _, player in pairs(Players:GetPlayers()) do createESPBillboard(player) end
            Connections["ESP"] = RunService.Heartbeat:Connect(function()
                if Config.ESPEnabled then updateESP() end
            end)
            Connections["ESPJoin"] = Players.PlayerAdded:Connect(function(p)
                p.CharacterAdded:Connect(function()
                    task.wait(1)
                    if Config.ESPEnabled then createESPBillboard(p) end
                end)
            end)
        else
            if Connections["ESP"] then Connections["ESP"]:Disconnect(); Connections["ESP"] = nil end
            if Connections["ESPJoin"] then Connections["ESPJoin"]:Disconnect(); Connections["ESPJoin"] = nil end
            cleanupESP()
        end
    end,
})

ESPTab:CreateLabel("Blue = Soul Reaper | White = Quincy | Red = Hollow | Green = Fullbringer")

------------------------------------------------------
-- TAB: AUTO FARM
------------------------------------------------------
local FarmTab = Window:CreateTab("Farm", 4483362458)

FarmTab:CreateSection("Auto Farm")

FarmTab:CreateToggle({
    Name = "Enable Auto Farm",
    CurrentValue = false,
    Flag = "AutoFarmToggle",
    Callback = function(state)
        Config.AutoFarmEnabled = state
        if state then task.spawn(runAutoFarm) end
    end,
})

FarmTab:CreateSlider({
    Name = "Farm Range (studs)",
    Range = {20, 300},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = Config.FarmRange,
    Flag = "FarmRange",
    Callback = function(val)
        Config.FarmRange = val
    end,
})

FarmTab:CreateSection("Survivability")

FarmTab:CreateToggle({
    Name = "Auto Heal",
    CurrentValue = false,
    Flag = "AutoHealToggle",
    Callback = function(state)
        Config.AutoHealEnabled = state
        if state then
            Connections["AutoHeal"] = RunService.Heartbeat:Connect(function()
                if not Config.AutoHealEnabled then return end
                local hum = getHumanoid()
                if not hum then return end
                if (hum.Health / hum.MaxHealth) * 100 <= Config.HealThreshold then
                    -- TODO: Replace with actual heal key from Peroxide
                    pcall(function()
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                        task.wait(0.05)
                        vim:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                    end)
                    pcall(function()
                        local char = getCharacter()
                        for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
                            if item:IsA("Tool") and item.Name:lower():find("heal") then
                                item.Parent = char
                                task.wait(0.2)
                                item:Activate()
                                break
                            end
                        end
                    end)
                    jitterWait(2)
                end
            end)
        else
            if Connections["AutoHeal"] then Connections["AutoHeal"]:Disconnect(); Connections["AutoHeal"] = nil end
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Heal Threshold",
    Range = {10, 80},
    Increment = 5,
    Suffix = "% HP",
    CurrentValue = Config.HealThreshold,
    Flag = "HealThreshold",
    Callback = function(val)
        Config.HealThreshold = val
    end,
})

FarmTab:CreateToggle({
    Name = "Auto Block",
    CurrentValue = false,
    Flag = "AutoBlockToggle",
    Callback = function(state)
        Config.AutoBlockEnabled = state
        if state then
            Connections["AutoBlock"] = RunService.Heartbeat:Connect(function()
                if not Config.AutoBlockEnabled or not isAlive(LocalPlayer) then return end
                local myHRP = getHRP()
                if not myHRP then return end
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude < 15 then
                            -- TODO: Replace with actual block key
                            pcall(function()
                                local vim = game:GetService("VirtualInputManager")
                                vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                                task.wait(0.5)
                                vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                            end)
                            break
                        end
                    end
                end
            end)
        else
            if Connections["AutoBlock"] then Connections["AutoBlock"]:Disconnect(); Connections["AutoBlock"] = nil end
        end
    end,
})

FarmTab:CreateSection("Notifications")

FarmTab:CreateToggle({
    Name = "Boss Spawn Alert",
    CurrentValue = false,
    Flag = "BossNotifyToggle",
    Callback = function(state)
        Config.BossNotifyEnabled = state
        if state then
            Connections["BossNotify"] = RunService.Heartbeat:Connect(function()
                if not Config.BossNotifyEnabled then return end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                        local name = obj.Name:lower()
                        if name:find("boss") or name:find("vasto") or name:find("captain") or name:find("espada") or name:find("menos") then
                            local hum = obj:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 then
                                pcall(function()
                                    game:GetService("StarterGui"):SetCore("SendNotification", {
                                        Title = "Boss Spawned!",
                                        Text = obj.Name .. " detected!",
                                        Duration = 5,
                                    })
                                end)
                                jitterWait(30)
                            end
                        end
                    end
                end
            end)
        else
            if Connections["BossNotify"] then Connections["BossNotify"]:Disconnect(); Connections["BossNotify"] = nil end
        end
    end,
})

------------------------------------------------------
-- TAB: STATS & SKILLS
------------------------------------------------------
local StatsTab = Window:CreateTab("Stats", 4483362458)

local race = Config.PlayerRace
local builds = BuildPresets[race] or BuildPresets["Soul Reaper"]
local skills = RaceSkills[race] or RaceSkills["Soul Reaper"]

StatsTab:CreateSection("Race: " .. race)

-- Build dropdown
local buildNames = {}
for name, _ in pairs(builds) do table.insert(buildNames, name) end

StatsTab:CreateDropdown({
    Name = "Build Preset",
    Options = buildNames,
    CurrentOption = {Config.SelectedBuild},
    MultipleOptions = false,
    Flag = "BuildPreset",
    Callback = function(option)
        Config.SelectedBuild = option[1] or option
    end,
})

-- Show build stats
for buildName, stats in pairs(builds) do
    StatsTab:CreateLabel(string.format("%s: STR:%d RES:%d SPD:%d REI:%d", buildName, stats.STR, stats.RES, stats.SPD, stats.REI))
end

StatsTab:CreateButton({
    Name = "Auto-Assign Stat Points",
    Callback = function()
        local build = builds[Config.SelectedBuild]
        if not build then return end
        -- TODO: Replace with actual remote name from SimpleSpy
        pcall(function()
            for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
                local name = remote.Name:lower()
                if (name:find("stat") or name:find("allocat") or name:find("point")) and remote:IsA("RemoteEvent") then
                    for stat, ratio in pairs(build) do
                        for _ = 1, ratio do
                            remote:FireServer(stat)
                            jitterWait(0.15)
                        end
                    end
                    print("[Hub] Stats allocated: " .. Config.SelectedBuild)
                    break
                end
            end
        end)
    end,
})

StatsTab:CreateSection("Auto Skill (" .. race .. ")")

StatsTab:CreateToggle({
    Name = "Auto-Use Skills",
    CurrentValue = false,
    Flag = "AutoSkillToggle",
    Callback = function(state)
        Config.AutoSkillEnabled = state
        if state then
            local lastUsed = {}
            Connections["AutoSkill"] = RunService.Heartbeat:Connect(function()
                if not Config.AutoSkillEnabled or not isAlive(LocalPlayer) then return end
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    for _, skill in ipairs(skills) do
                        local now = tick()
                        if not lastUsed[skill.name] or (now - lastUsed[skill.name]) >= skill.cooldown then
                            vim:SendKeyEvent(true, skill.key, false, game)
                            task.wait(0.05)
                            vim:SendKeyEvent(false, skill.key, false, game)
                            lastUsed[skill.name] = now
                            jitterWait(0.3)
                        end
                    end
                end)
            end)
        else
            if Connections["AutoSkill"] then Connections["AutoSkill"]:Disconnect(); Connections["AutoSkill"] = nil end
        end
    end,
})

-- Show skill list
for _, skill in ipairs(skills) do
    StatsTab:CreateLabel(skill.name .. " [" .. skill.key.Name .. "] CD: " .. skill.cooldown .. "s")
end

------------------------------------------------------
-- TAB: EXTRAS
------------------------------------------------------
local ExtrasTab = Window:CreateTab("Extras", 4483362458)

ExtrasTab:CreateSection("Anti-Detection")

ExtrasTab:CreateToggle({
    Name = "Anti-Idle",
    CurrentValue = true,
    Flag = "AntiIdleToggle",
    Callback = function(state)
        Config.AntiIdleEnabled = state
        if state then startAntiIdle() end
    end,
})

ExtrasTab:CreateToggle({
    Name = "Metahook (Spoof WalkSpeed)",
    CurrentValue = false,
    Flag = "MetahookToggle",
    Callback = function(state)
        Config.MetahookEnabled = state
        if state then setupMetahook() end
    end,
})

ExtrasTab:CreateLabel("Anti-Idle: Micro camera nudge to prevent AFK kick")
ExtrasTab:CreateLabel("Metahook: Spoofs Humanoid stats to default values")

ExtrasTab:CreateSection("Info")
ExtrasTab:CreateLabel("Race: " .. Config.PlayerRace)
ExtrasTab:CreateLabel("Location: " .. Config.CurrentLocation)

ExtrasTab:CreateSection("Settings")

ExtrasTab:CreateButton({
    Name = "Save Config",
    Callback = function()
        pcall(function()
            if writefile then
                writefile("PeroxideHubConfig.json", HttpService:JSONEncode({
                    FarmRange = Config.FarmRange,
                    HealThreshold = Config.HealThreshold,
                    SelectedBuild = Config.SelectedBuild,
                }))
                print("[Hub] Config saved")
            end
        end)
    end,
})

ExtrasTab:CreateButton({
    Name = "Load Config",
    Callback = function()
        pcall(function()
            if readfile and isfile and isfile("PeroxideHubConfig.json") then
                local data = HttpService:JSONDecode(readfile("PeroxideHubConfig.json"))
                Config.FarmRange = data.FarmRange or Config.FarmRange
                Config.HealThreshold = data.HealThreshold or Config.HealThreshold
                Config.SelectedBuild = data.SelectedBuild or Config.SelectedBuild
                print("[Hub] Config loaded")
            end
        end)
    end,
})

------------------------------------------------------
-- BACKGROUND TASKS
------------------------------------------------------

-- Staggered startup
task.wait(1)
startAntiIdle()

-- Context refresh loop
task.spawn(function()
    while task.wait(15 + math.random() * 10) do
        Config.PlayerRace = detectRace()
        Config.CurrentLocation = detectLocation()
    end
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
end)

print("================================================")
print("  Peroxide Hub v3.0 (Rayfield) Loaded")
print("  Race: " .. Config.PlayerRace)
print("  Location: " .. Config.CurrentLocation)
print("================================================")
