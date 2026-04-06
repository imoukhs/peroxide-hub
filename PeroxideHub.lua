--[[
    Peroxide Hub v2.0
    Context-aware dark-themed hub for Peroxide
    Races: Soul Reaper | Quincy | Hollow/Arrancar | Fullbringer
    Features: Fast Travel | ESP | Auto Farm | Stats | Auto Heal | Boss Notify | Auto Block
    Anti-Detection: Humanized movement, random delays, obfuscated names, gradual TP, anti-idle
    Toggle: RightShift
    Universal executor compatible
]]

------------------------------------------------------
-- 1. SERVICES & CONFIG
------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------
-- ANTI-DETECTION: Obfuscated naming
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

local GUI_NAME = randomName(16)
local ESP_TAG = randomName(10)

-- Use gethui() if available (hides from anticheat CoreGui scans), fallback to CoreGui
local function getGuiParent()
    if gethui then
        return gethui()
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

------------------------------------------------------
-- ANTI-DETECTION: Random delay helper
------------------------------------------------------
local function jitterWait(base)
    local mult = 0.8 + math.random() * 0.7 -- 0.8x to 1.5x
    task.wait(base * mult)
end

------------------------------------------------------
-- RACE THEMES
------------------------------------------------------
local RaceThemes = {
    ["Soul Reaper"] = {
        Background   = Color3.fromRGB(20, 20, 40),
        Secondary    = Color3.fromRGB(16, 26, 52),
        Accent       = Color3.fromRGB(30, 60, 120),
        Highlight    = Color3.fromRGB(70, 150, 255),
        TextPrimary  = Color3.fromRGB(220, 230, 255),
        TextSecondary= Color3.fromRGB(140, 160, 200),
        ButtonHover  = Color3.fromRGB(35, 45, 80),
        ToggleOn     = Color3.fromRGB(70, 150, 255),
        ToggleOff    = Color3.fromRGB(100, 110, 140),
    },
    ["Quincy"] = {
        Background   = Color3.fromRGB(24, 24, 34),
        Secondary    = Color3.fromRGB(30, 30, 50),
        Accent       = Color3.fromRGB(60, 60, 100),
        Highlight    = Color3.fromRGB(180, 200, 255),
        TextPrimary  = Color3.fromRGB(230, 235, 255),
        TextSecondary= Color3.fromRGB(160, 170, 200),
        ButtonHover  = Color3.fromRGB(45, 45, 70),
        ToggleOn     = Color3.fromRGB(180, 200, 255),
        ToggleOff    = Color3.fromRGB(110, 115, 140),
    },
    ["Hollow"] = {
        Background   = Color3.fromRGB(30, 16, 16),
        Secondary    = Color3.fromRGB(45, 20, 20),
        Accent       = Color3.fromRGB(80, 25, 25),
        Highlight    = Color3.fromRGB(233, 69, 69),
        TextPrimary  = Color3.fromRGB(255, 220, 220),
        TextSecondary= Color3.fromRGB(200, 150, 150),
        ButtonHover  = Color3.fromRGB(60, 30, 30),
        ToggleOn     = Color3.fromRGB(233, 69, 69),
        ToggleOff    = Color3.fromRGB(130, 100, 100),
    },
    ["Fullbringer"] = {
        Background   = Color3.fromRGB(18, 26, 18),
        Secondary    = Color3.fromRGB(22, 36, 22),
        Accent       = Color3.fromRGB(30, 70, 40),
        Highlight    = Color3.fromRGB(76, 209, 55),
        TextPrimary  = Color3.fromRGB(220, 255, 220),
        TextSecondary= Color3.fromRGB(150, 200, 150),
        ButtonHover  = Color3.fromRGB(30, 50, 30),
        ToggleOn     = Color3.fromRGB(76, 209, 55),
        ToggleOff    = Color3.fromRGB(100, 130, 100),
    },
}

-- Default fallback theme
local DefaultTheme = {
    Background   = Color3.fromRGB(26, 26, 46),
    Secondary    = Color3.fromRGB(22, 33, 62),
    Accent       = Color3.fromRGB(15, 52, 96),
    Highlight    = Color3.fromRGB(233, 69, 96),
    TextPrimary  = Color3.fromRGB(234, 234, 234),
    TextSecondary= Color3.fromRGB(160, 160, 176),
    ButtonHover  = Color3.fromRGB(42, 42, 78),
    ToggleOn     = Color3.fromRGB(76, 209, 55),
    ToggleOff    = Color3.fromRGB(120, 120, 140),
}

local Theme = DefaultTheme -- will be swapped on race detect

------------------------------------------------------
-- CONFIG
------------------------------------------------------
local Config = {
    Title = "Peroxide Hub",
    Size = UDim2.new(0, 460, 0, 560),
    ToggleKey = Enum.KeyCode.RightShift,
    -- Feature states
    ESPEnabled = false,
    AutoFarmEnabled = false,
    AutoSkillEnabled = false,
    AutoHealEnabled = false,
    AutoBlockEnabled = false,
    BossNotifyEnabled = false,
    AntiIdleEnabled = true,
    -- Settings
    FarmRange = 80,
    HealThreshold = 30, -- percent
    SelectedBuild = "Balanced",
    TPShortRange = 30, -- below this: micro-TP, above: walk
    -- Detected at runtime
    PlayerRace = "Unknown",
    CurrentLocation = "Unknown",
}

-- State
local Connections = {}
local ESPObjects = {}
local GuiOpen = true
local ThemedElements = {} -- track elements for live re-theming

------------------------------------------------------
-- 2. RACE & LOCATION DETECTION
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

    -- Check team
    if LocalPlayer.Team then
        local team = LocalPlayer.Team.Name:lower()
        if team:find("soul") or team:find("shinigami") then return "Soul Reaper" end
        if team:find("quincy") then return "Quincy" end
        if team:find("hollow") or team:find("arrancar") then return "Hollow" end
        if team:find("fullbring") or team:find("bringer") then return "Fullbringer" end
    end

    return "Unknown"
end

local function detectLocation()
    local char = LocalPlayer.Character
    if not char then return "Unknown" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return "Unknown" end
    local pos = hrp.Position

    -- REPLACE: These are rough zone boundaries. Adjust with real Peroxide map data.
    -- Use your remote spy / position printer to map these zones.
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
-- 3. UTILITY FUNCTIONS
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

local function tweenProp(obj, props, duration)
    local info = TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local tween = TweenService:Create(obj, info, props)
    tween:Play()
    return tween
end

local function getMyPosition()
    local hrp = getHRP()
    if hrp then
        local pos = hrp.Position
        print("=== YOUR CURRENT POSITION ===")
        print(string.format("Vector3.new(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z))
        print(string.format("CFrame.new(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z))
        print("=============================")
    end
end

------------------------------------------------------
-- ANTI-DETECTION: Humanized movement
------------------------------------------------------

-- Gradual teleport: lerps through waypoints instead of instant jump
local function gradualTP(targetPos, steps)
    local hrp = getHRP()
    if not hrp then return end
    steps = steps or 8
    local startPos = hrp.Position
    local dist = (targetPos - startPos).Magnitude

    if dist < Config.TPShortRange then
        -- Short range: micro-TP (single jump, low risk)
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        return
    end

    -- Long range: lerp through points
    for i = 1, steps do
        if not getHRP() then break end
        local alpha = i / steps
        local midPoint = startPos:Lerp(targetPos, alpha) + Vector3.new(0, 3, 0)
        hrp.CFrame = CFrame.new(midPoint)
        jitterWait(0.05)
    end
end

-- Walk to target using short-range TP bursts (under detection threshold)
local function smartMoveTo(targetPos)
    local hrp = getHRP()
    if not hrp then return end
    local dist = (targetPos - hrp.Position).Magnitude

    if dist <= Config.TPShortRange then
        -- Close enough: micro-TP
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.5, 0), targetPos)
        return
    end

    -- Walk via Humanoid:MoveTo for natural movement, then micro-TP when close
    local hum = getHumanoid()
    if hum then
        hum:MoveTo(targetPos)
        local startTime = tick()
        while (getHRP().Position - targetPos).Magnitude > Config.TPShortRange and tick() - startTime < 10 do
            jitterWait(0.2)
            if not isAlive(LocalPlayer) then return end
        end
        -- Final micro-TP to exact position
        local hrp2 = getHRP()
        if hrp2 and (hrp2.Position - targetPos).Magnitude <= Config.TPShortRange then
            hrp2.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.5, 0), targetPos)
        end
    end
end

------------------------------------------------------
-- ANTI-DETECTION: Metamethod hook (anti-cheat bypass)
------------------------------------------------------

local function setupMetahook()
    -- Hook __namecall to intercept anticheat checks
    -- This spoofs responses when the server queries walkspeed, position, etc.
    pcall(function()
        if not getrawmetatable then return end
        local mt = getrawmetatable(game)
        if not mt then return end

        local oldNamecall = mt.__namecall
        local oldIndex = mt.__index

        if setreadonly then setreadonly(mt, false) end

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()

            -- Spoof kick attempts
            if method == "Kick" and self == LocalPlayer then
                return
            end

            return oldNamecall(self, ...)
        end)

        mt.__index = newcclosure(function(self, key)
            -- Spoof walkspeed / jumppower checks
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
-- ANTI-DETECTION: Anti-idle
------------------------------------------------------

local function startAntiIdle()
    Connections["AntiIdle"] = RunService.Heartbeat:Connect(function()
        if not Config.AntiIdleEnabled then return end
        -- VirtualUser keeps the client "active"
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end)
end

------------------------------------------------------
-- FACTION-SPECIFIC DATA
------------------------------------------------------

-- Skills per race (keybinds that auto-skill will press)
-- TODO: Replace with actual Peroxide keybinds from your testing
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

-- Location-specific farm spots and teleport points per race
-- TODO: Replace Vector3 values with real coords. Use "Print My Position" in-game.
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
        quests = {
            {name = "Hollow Hunt",    races = {"Soul Reaper", "Quincy"}},
            {name = "Soul Collection", races = {"Hollow"}},
            {name = "Patrol Duty",    races = {"Soul Reaper"}},
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
        quests = {
            {name = "Squad Training",   races = {"Soul Reaper"}},
            {name = "Infiltration",     races = {"Hollow", "Quincy"}},
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
        quests = {
            {name = "Hollow Evolution", races = {"Hollow"}},
            {name = "Raid Las Noches",  races = {"Soul Reaper", "Quincy"}},
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
        quests = {},
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
        quests = {},
    },
}

-- Build presets per race
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
-- 4. FIND NEARBY ENTITIES
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
                    if d < bestDist then
                        nearest = obj
                        bestDist = d
                    end
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
                local part = obj
                if obj:IsA("Model") then
                    part = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                end
                if part and part:IsA("BasePart") then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bestDist then
                        nearest = obj
                        bestDist = d
                    end
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
    if player.Team then
        local team = player.Team.Name:lower()
        if team:find("soul") or team:find("shinigami") then return "Soul Reaper" end
        if team:find("quincy") then return "Quincy" end
        if team:find("hollow") or team:find("arrancar") then return "Hollow" end
        if team:find("fullbring") then return "Fullbringer" end
    end
    return "Unknown"
end

local function getFactionColor(faction)
    if faction == "Soul Reaper" then return Color3.fromRGB(85, 170, 255) end
    if faction == "Quincy" then return Color3.fromRGB(200, 210, 255) end
    if faction == "Hollow" then return Color3.fromRGB(255, 80, 80) end
    if faction == "Fullbringer" then return Color3.fromRGB(76, 209, 55) end
    return DefaultTheme.TextSecondary
end

------------------------------------------------------
-- 5. GUI FRAMEWORK
------------------------------------------------------

-- Destroy previous
for _, gui in pairs(getGuiParent():GetChildren()) do
    if gui:IsA("ScreenGui") and gui:GetAttribute("PeroxideHub") then
        gui:Destroy()
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui:SetAttribute("PeroxideHub", true)
ScreenGui.Parent = getGuiParent()

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = randomName(8)
MainFrame.Size = Config.Size
MainFrame.Position = UDim2.new(0.5, -230, 0.5, -280)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

table.insert(ThemedElements, {obj = MainFrame, prop = "BackgroundColor3", key = "Background"})

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Accent
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

table.insert(ThemedElements, {obj = MainStroke, prop = "Color", key = "Accent"})

-- Drag
local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and input.Position.Y - MainFrame.AbsolutePosition.Y < 44 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Theme.Secondary
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
table.insert(ThemedElements, {obj = TitleBar, prop = "BackgroundColor3", key = "Secondary"})

Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 14)
TitleFix.Position = UDim2.new(0, 0, 1, -14)
TitleFix.BackgroundColor3 = Theme.Secondary
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar
table.insert(ThemedElements, {obj = TitleFix, prop = "BackgroundColor3", key = "Secondary"})

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = Config.Title
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Theme.Highlight
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.Parent = TitleBar
table.insert(ThemedElements, {obj = TitleLabel, prop = "TextColor3", key = "Highlight"})

-- Race & location indicator
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Text = ""
InfoLabel.Size = UDim2.new(0, 200, 0, 14)
InfoLabel.Position = UDim2.new(0, 14, 1, -16)
InfoLabel.BackgroundTransparency = 1
InfoLabel.TextColor3 = Theme.TextSecondary
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextSize = 10
InfoLabel.Parent = TitleBar
table.insert(ThemedElements, {obj = InfoLabel, prop = "TextColor3", key = "TextSecondary"})

-- Close & minimize buttons
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -38, 0, 7)
CloseBtn.BackgroundColor3 = Theme.Highlight
CloseBtn.TextColor3 = Theme.TextPrimary
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
    GuiOpen = false
    tweenProp(MainFrame, {Size = UDim2.new(0, 460, 0, 0)}, 0.3)
    task.wait(0.3)
    MainFrame.Visible = false
end)

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "-"
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -72, 0, 7)
MinBtn.BackgroundColor3 = Theme.Accent
MinBtn.TextColor3 = Theme.TextPrimary
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)
table.insert(ThemedElements, {obj = MinBtn, prop = "BackgroundColor3", key = "Accent"})

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tweenProp(MainFrame, {Size = UDim2.new(0, 460, 0, 44)}, 0.25)
        MinBtn.Text = "+"
    else
        tweenProp(MainFrame, {Size = Config.Size}, 0.25)
        MinBtn.Text = "-"
    end
end)

------------------------------------------------------
-- TAB SYSTEM
------------------------------------------------------
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 36)
TabBar.Position = UDim2.new(0, 0, 0, 44)
TabBar.BackgroundColor3 = Theme.Background
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame
table.insert(ThemedElements, {obj = TabBar, prop = "BackgroundColor3", key = "Background"})

local TabNames = {"Travel", "ESP", "Farm", "Stats", "Extras"}
local TabButtons = {}
local TabContents = {}
local ActiveTab = nil

local tabWidth = 1 / #TabNames

for i, name in ipairs(TabNames) do
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Text = name
    btn.Size = UDim2.new(tabWidth, -2, 1, 0)
    btn.Position = UDim2.new(tabWidth * (i - 1), 1, 0, 0)
    btn.BackgroundTransparency = 1
    btn.TextColor3 = Theme.TextSecondary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = TabBar

    local underline = Instance.new("Frame")
    underline.Size = UDim2.new(0.7, 0, 0, 3)
    underline.Position = UDim2.new(0.15, 0, 1, -3)
    underline.BackgroundColor3 = Theme.Highlight
    underline.BorderSizePixel = 0
    underline.Visible = false
    underline.Parent = btn
    Instance.new("UICorner", underline).CornerRadius = UDim.new(0, 2)
    table.insert(ThemedElements, {obj = underline, prop = "BackgroundColor3", key = "Highlight"})

    TabButtons[name] = {Button = btn, Underline = underline}

    local content = Instance.new("ScrollingFrame")
    content.Name = name .. "Content"
    content.Size = UDim2.new(1, -20, 1, -90)
    content.Position = UDim2.new(0, 10, 0, 84)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Theme.Accent
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = false
    content.Parent = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = content

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.Parent = content

    TabContents[name] = content

    btn.MouseButton1Click:Connect(function()
        for n, data in pairs(TabButtons) do
            data.Button.TextColor3 = Theme.TextSecondary
            data.Underline.Visible = false
            TabContents[n].Visible = false
        end
        btn.TextColor3 = Theme.TextPrimary
        underline.Visible = true
        content.Visible = true
        ActiveTab = name
    end)
end

------------------------------------------------------
-- GUI HELPERS
------------------------------------------------------

local function createButton(parent, text, order, callback)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Theme.Secondary
    btn.TextColor3 = Theme.TextPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order or 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    table.insert(ThemedElements, {obj = btn, prop = "BackgroundColor3", key = "Secondary"})

    btn.MouseEnter:Connect(function() tweenProp(btn, {BackgroundColor3 = Theme.ButtonHover}, 0.15) end)
    btn.MouseLeave:Connect(function() tweenProp(btn, {BackgroundColor3 = Theme.Secondary}, 0.15) end)
    if callback then btn.MouseButton1Click:Connect(callback) end
    return btn
end

local function createToggle(parent, text, order, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 38)
    frame.BackgroundColor3 = Theme.Secondary
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order or 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    table.insert(ThemedElements, {obj = frame, prop = "BackgroundColor3", key = "Secondary"})

    local label = Instance.new("TextLabel")
    label.Text = text
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Theme.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = frame

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 42, 0, 20)
    toggleBg.Position = UDim2.new(1, -54, 0.5, -10)
    toggleBg.BackgroundColor3 = default and Theme.ToggleOn or Theme.ToggleOff
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = frame
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Theme.TextPrimary
    knob.BorderSizePixel = 0
    knob.Parent = toggleBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default or false
    local btn = Instance.new("TextButton")
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Parent = frame

    btn.MouseButton1Click:Connect(function()
        state = not state
        tweenProp(toggleBg, {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}, 0.2)
        tweenProp(knob, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.2)
        if callback then callback(state) end
    end)

    return frame, function() return state end
end

local function createHeader(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Theme.Highlight
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.LayoutOrder = order or 0
    lbl.Parent = parent
    table.insert(ThemedElements, {obj = lbl, prop = "TextColor3", key = "Highlight"})
    return lbl
end

local function createStatus(parent, order)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Status"
    lbl.Text = "Status: Idle"
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Theme.TextSecondary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.LayoutOrder = order or 0
    lbl.Parent = parent
    return lbl
end

local function createInfoText(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, 0, 0, 30)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Theme.TextSecondary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextWrapped = true
    lbl.LayoutOrder = order or 0
    lbl.Parent = parent
    return lbl
end

------------------------------------------------------
-- LIVE THEME SWITCHER
------------------------------------------------------

local function applyTheme(newTheme)
    Theme = newTheme
    for _, entry in ipairs(ThemedElements) do
        if entry.obj and entry.obj.Parent then
            pcall(function()
                entry.obj[entry.prop] = Theme[entry.key]
            end)
        end
    end
end

------------------------------------------------------
-- 6. TAB: FAST TRAVEL (Context-Aware)
------------------------------------------------------
local travelContent = TabContents["Travel"]
local travelElements = {} -- for dynamic refresh

local function refreshTravelTab()
    -- Clear existing travel buttons
    for _, el in ipairs(travelElements) do
        if el and el.Parent then el:Destroy() end
    end
    travelElements = {}

    local order = 0

    -- Position helper
    local posBtn = createButton(travelContent, ">> Print My Position <<", order, getMyPosition)
    table.insert(travelElements, posBtn)
    order = order + 1

    -- Current location header
    local locHeader = createHeader(travelContent, "Current: " .. Config.CurrentLocation, order)
    table.insert(travelElements, locHeader)
    order = order + 1

    -- Show location-specific teleports first (if in a known location)
    local locData = LocationData[Config.CurrentLocation]
    if locData then
        local h = createHeader(travelContent, "Nearby Points", order)
        table.insert(travelElements, h)
        order = order + 1

        for _, tp in ipairs(locData.teleports) do
            local b = createButton(travelContent, tp.name, order, function()
                gradualTP(tp.pos)
            end)
            table.insert(travelElements, b)
            order = order + 1
        end

        -- Show chests for current location
        if #locData.chests > 0 then
            local ch = createHeader(travelContent, "Chests / Loot", order)
            table.insert(travelElements, ch)
            order = order + 1
            for _, chest in ipairs(locData.chests) do
                local b = createButton(travelContent, chest.name, order, function()
                    gradualTP(chest.pos)
                end)
                table.insert(travelElements, b)
                order = order + 1
            end
        end

        -- Race-specific farm spots
        if #locData.farmSpots > 0 then
            local fh = createHeader(travelContent, "Farm Spots (" .. Config.PlayerRace .. ")", order)
            table.insert(travelElements, fh)
            order = order + 1
            for _, spot in ipairs(locData.farmSpots) do
                local isRelevant = false
                for _, race in ipairs(spot.races) do
                    if race == Config.PlayerRace or Config.PlayerRace == "Unknown" then
                        isRelevant = true; break
                    end
                end
                if isRelevant then
                    local b = createButton(travelContent, spot.name, order, function()
                        gradualTP(spot.pos)
                    end)
                    table.insert(travelElements, b)
                    order = order + 1
                end
            end
        end
    end

    -- All locations (for cross-map travel)
    local ah = createHeader(travelContent, "All Locations", order)
    table.insert(travelElements, ah)
    order = order + 1

    for locName, data in pairs(LocationData) do
        if #data.teleports > 0 then
            local b = createButton(travelContent, locName .. " >>", order, function()
                gradualTP(data.teleports[1].pos, 12) -- more steps for long distance
            end)
            table.insert(travelElements, b)
            order = order + 1
        end
    end
end

------------------------------------------------------
-- 7. TAB: ESP
------------------------------------------------------
local espContent = TabContents["ESP"]

local function cleanupESP()
    for player, billboard in pairs(ESPObjects) do
        if billboard and billboard.Parent then billboard:Destroy() end
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

    local billboard = Instance.new("BillboardGui")
    billboard.Name = ESP_TAG
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "N"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Theme.TextPrimary
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = player.Name
    nameLabel.Parent = billboard

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "I"
    infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 10
    infoLabel.TextStrokeTransparency = 0.4
    infoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    infoLabel.Parent = billboard

    ESPObjects[player] = billboard
end

local function updateESP()
    local myHRP = getHRP()
    if not myHRP then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local bb = ESPObjects[player]
            if not bb or not bb.Parent then
                createESPBillboard(player)
                bb = ESPObjects[player]
            end
            if bb then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
                    local faction = getFaction(player)
                    local color = getFactionColor(faction)
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hp = hum and math.floor(hum.Health) or 0
                    local nl = bb:FindFirstChild("N")
                    local il = bb:FindFirstChild("I")
                    if nl then nl.TextColor3 = color; nl.Text = player.Name end
                    if il then il.TextColor3 = color; il.Text = string.format("[%s] %dm | HP:%d", faction, dist, hp) end
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

createToggle(espContent, "Enable ESP", 1, false, function(state)
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
end)

createInfoText(espContent, "Name + distance + faction + HP through walls.\nBlue=Soul Reaper  White=Quincy  Red=Hollow  Green=Fullbringer", 2)

------------------------------------------------------
-- 8. TAB: AUTO FARM (Context-Aware)
------------------------------------------------------
local farmContent = TabContents["Farm"]
local farmStatus = nil

local function runAutoFarm()
    while Config.AutoFarmEnabled and isAlive(LocalPlayer) do
        local hrp = getHRP()
        if not hrp then jitterWait(1); continue end

        -- Priority 1: Kill nearby NPCs
        local npc, dist = findNearestNPC(Config.FarmRange)
        if npc then
            local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc:FindFirstChild("Head")
            if npcRoot then
                farmStatus.Text = "Status: Attacking " .. npc.Name .. " (" .. math.floor(dist) .. "m)"

                -- Smart move: walk if far, micro-TP if close
                if dist > Config.TPShortRange then
                    local hum = getHumanoid()
                    if hum then hum:MoveTo(npcRoot.Position) end
                    jitterWait(0.5)
                else
                    hrp.CFrame = CFrame.new(npcRoot.Position + Vector3.new(0, 0, 3), npcRoot.Position)
                end

                jitterWait(0.1)

                -- Attack
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
            -- Priority 2: Collect loot
            local loot = findNearestLoot(Config.FarmRange)
            if loot then
                farmStatus.Text = "Status: Collecting " .. loot.Name
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
                        if loot:IsA("BasePart") then
                            firetouchinterest(hrp, loot, 0)
                            task.wait(0.1)
                            firetouchinterest(hrp, loot, 1)
                        end
                    end)
                end
                jitterWait(0.3)
            else
                farmStatus.Text = "Status: Idle - No targets"
                jitterWait(1)
            end
        end
        jitterWait(0.15)
    end
    if farmStatus then farmStatus.Text = "Status: Stopped" end
end

createToggle(farmContent, "Auto Farm", 1, false, function(state)
    Config.AutoFarmEnabled = state
    if state then task.spawn(runAutoFarm) end
end)

createToggle(farmContent, "Auto-Kill NPCs", 2, true, function() end)
createToggle(farmContent, "Auto-Collect Loot", 3, true, function() end)

createHeader(farmContent, "Farm Range", 4)

local rangeFrame = Instance.new("Frame")
rangeFrame.Size = UDim2.new(1, 0, 0, 34)
rangeFrame.BackgroundColor3 = Theme.Secondary
rangeFrame.BorderSizePixel = 0
rangeFrame.LayoutOrder = 5
rangeFrame.Parent = farmContent
Instance.new("UICorner", rangeFrame).CornerRadius = UDim.new(0, 8)

local rangeLabel = Instance.new("TextLabel")
rangeLabel.Text = "Range: " .. Config.FarmRange .. " studs"
rangeLabel.Size = UDim2.new(1, -120, 1, 0)
rangeLabel.Position = UDim2.new(0, 14, 0, 0)
rangeLabel.BackgroundTransparency = 1
rangeLabel.TextColor3 = Theme.TextPrimary
rangeLabel.TextXAlignment = Enum.TextXAlignment.Left
rangeLabel.Font = Enum.Font.Gotham
rangeLabel.TextSize = 12
rangeLabel.Parent = rangeFrame

local function makeRangeBtn(text, xPos, delta)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Size = UDim2.new(0, 36, 0, 24)
    b.Position = UDim2.new(1, xPos, 0.5, -12)
    b.BackgroundColor3 = Theme.Accent
    b.TextColor3 = Theme.TextPrimary
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.BorderSizePixel = 0
    b.Parent = rangeFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        Config.FarmRange = math.clamp(Config.FarmRange + delta, 20, 300)
        rangeLabel.Text = "Range: " .. Config.FarmRange .. " studs"
    end)
end

makeRangeBtn("-", -100, -20)
makeRangeBtn("+", -56, 20)

createHeader(farmContent, "Context: " .. Config.CurrentLocation, 6)
farmStatus = createStatus(farmContent, 7)

------------------------------------------------------
-- 9. TAB: STATS (Race-Aware)
------------------------------------------------------
local statContent = TabContents["Stats"]
local statElements = {}

local function refreshStatsTab()
    for _, el in ipairs(statElements) do
        if el and el.Parent then el:Destroy() end
    end
    statElements = {}

    local order = 0
    local race = Config.PlayerRace
    local builds = BuildPresets[race] or BuildPresets["Soul Reaper"]

    local rh = createHeader(statContent, "Build Presets (" .. race .. ")", order)
    table.insert(statElements, rh)
    order = order + 1

    local selectedBuildLabel = nil

    for buildName, stats in pairs(builds) do
        local ratioText = string.format("STR:%d  RES:%d  SPD:%d  REI:%d", stats.STR, stats.RES, stats.SPD, stats.REI)
        local isDefault = buildName == Config.SelectedBuild

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 38)
        frame.BackgroundColor3 = isDefault and Theme.Accent or Theme.Secondary
        frame.BorderSizePixel = 0
        frame.LayoutOrder = order
        frame.Parent = statContent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        table.insert(statElements, frame)

        local nl = Instance.new("TextLabel")
        nl.Text = buildName
        nl.Size = UDim2.new(0.4, 0, 1, 0)
        nl.Position = UDim2.new(0, 14, 0, 0)
        nl.BackgroundTransparency = 1
        nl.TextColor3 = Theme.TextPrimary
        nl.TextXAlignment = Enum.TextXAlignment.Left
        nl.Font = Enum.Font.GothamBold
        nl.TextSize = 12
        nl.Parent = frame

        local rl = Instance.new("TextLabel")
        rl.Text = ratioText
        rl.Size = UDim2.new(0.55, 0, 1, 0)
        rl.Position = UDim2.new(0.4, 0, 0, 0)
        rl.BackgroundTransparency = 1
        rl.TextColor3 = Theme.TextSecondary
        rl.TextXAlignment = Enum.TextXAlignment.Right
        rl.Font = Enum.Font.Gotham
        rl.TextSize = 10
        rl.Parent = frame

        local sb = Instance.new("TextButton")
        sb.Text = ""
        sb.Size = UDim2.new(1, 0, 1, 0)
        sb.BackgroundTransparency = 1
        sb.Parent = frame
        sb.MouseButton1Click:Connect(function()
            Config.SelectedBuild = buildName
            for _, child in pairs(statContent:GetChildren()) do
                if child:IsA("Frame") then
                    tweenProp(child, {BackgroundColor3 = Theme.Secondary}, 0.2)
                end
            end
            tweenProp(frame, {BackgroundColor3 = Theme.Accent}, 0.2)
            if selectedBuildLabel then selectedBuildLabel.Text = "Selected: " .. buildName end
        end)

        order = order + 1
    end

    local ah = createHeader(statContent, "Auto Assign", order)
    table.insert(statElements, ah)
    order = order + 1

    selectedBuildLabel = Instance.new("TextLabel")
    selectedBuildLabel.Text = "Selected: " .. Config.SelectedBuild
    selectedBuildLabel.Size = UDim2.new(1, 0, 0, 20)
    selectedBuildLabel.BackgroundTransparency = 1
    selectedBuildLabel.TextColor3 = Theme.TextSecondary
    selectedBuildLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedBuildLabel.Font = Enum.Font.Gotham
    selectedBuildLabel.TextSize = 11
    selectedBuildLabel.LayoutOrder = order
    selectedBuildLabel.Parent = statContent
    table.insert(statElements, selectedBuildLabel)
    order = order + 1

    local ab = createButton(statContent, "Auto-Assign Stat Points", order, function()
        local build = builds[Config.SelectedBuild]
        if not build then return end
        -- TODO: Replace with actual remote name from your remote spy
        -- Example: ReplicatedStorage.Remotes.AllocateStat:FireServer("STR")
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
                    print("[Hub] Fired stat allocation: " .. Config.SelectedBuild)
                    break
                end
            end
        end)
    end)
    table.insert(statElements, ab)
    order = order + 1

    -- Auto-skill section
    local skills = RaceSkills[race] or RaceSkills["Soul Reaper"]
    local sh = createHeader(statContent, "Auto Skill (" .. race .. ")", order)
    table.insert(statElements, sh)
    order = order + 1

    local skillToggle, skillGetter = createToggle(statContent, "Auto-Use Skills", order, false, function(state)
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
    end)
    table.insert(statElements, skillToggle)
    order = order + 1

    -- List skills
    for _, skill in ipairs(skills) do
        local si = createInfoText(statContent, skill.name .. " [" .. skill.key.Name .. "] - CD: " .. skill.cooldown .. "s", order)
        table.insert(statElements, si)
        order = order + 1
    end
end

------------------------------------------------------
-- 10. TAB: EXTRAS (Auto Heal, Boss Notify, Auto Block, Settings)
------------------------------------------------------
local extraContent = TabContents["Extras"]

createHeader(extraContent, "Survivability", 1)

-- Auto Heal
createToggle(extraContent, "Auto Heal", 2, false, function(state)
    Config.AutoHealEnabled = state
    if state then
        Connections["AutoHeal"] = RunService.Heartbeat:Connect(function()
            if not Config.AutoHealEnabled then return end
            local hum = getHumanoid()
            if not hum then return end
            local hpPercent = (hum.Health / hum.MaxHealth) * 100
            if hpPercent <= Config.HealThreshold then
                -- Try using healing item/ability
                -- TODO: Replace with actual heal remote/keybind
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    -- Common heal key (often Q or a number key)
                    vim:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                    task.wait(0.05)
                    vim:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                end)
                -- Also try finding and using a healing tool
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
                jitterWait(2) -- cooldown between heal attempts
            end
        end)
    else
        if Connections["AutoHeal"] then Connections["AutoHeal"]:Disconnect(); Connections["AutoHeal"] = nil end
    end
end)

-- Heal threshold
local healFrame = Instance.new("Frame")
healFrame.Size = UDim2.new(1, 0, 0, 34)
healFrame.BackgroundColor3 = Theme.Secondary
healFrame.BorderSizePixel = 0
healFrame.LayoutOrder = 3
healFrame.Parent = extraContent
Instance.new("UICorner", healFrame).CornerRadius = UDim.new(0, 8)

local healLabel = Instance.new("TextLabel")
healLabel.Text = "Heal at: " .. Config.HealThreshold .. "% HP"
healLabel.Size = UDim2.new(1, -120, 1, 0)
healLabel.Position = UDim2.new(0, 14, 0, 0)
healLabel.BackgroundTransparency = 1
healLabel.TextColor3 = Theme.TextPrimary
healLabel.TextXAlignment = Enum.TextXAlignment.Left
healLabel.Font = Enum.Font.Gotham
healLabel.TextSize = 12
healLabel.Parent = healFrame

local function makeHealBtn(text, xPos, delta)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Size = UDim2.new(0, 36, 0, 24)
    b.Position = UDim2.new(1, xPos, 0.5, -12)
    b.BackgroundColor3 = Theme.Accent
    b.TextColor3 = Theme.TextPrimary
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.BorderSizePixel = 0
    b.Parent = healFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        Config.HealThreshold = math.clamp(Config.HealThreshold + delta, 10, 80)
        healLabel.Text = "Heal at: " .. Config.HealThreshold .. "% HP"
    end)
end

makeHealBtn("-", -100, -10)
makeHealBtn("+", -56, 10)

-- Auto Block
createToggle(extraContent, "Auto Block", 4, false, function(state)
    Config.AutoBlockEnabled = state
    if state then
        Connections["AutoBlock"] = RunService.Heartbeat:Connect(function()
            if not Config.AutoBlockEnabled or not isAlive(LocalPlayer) then return end
            -- Check if any player is attacking us (close + facing us)
            local myHRP = getHRP()
            if not myHRP then return end
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dist = (hrp.Position - myHRP.Position).Magnitude
                        if dist < 15 then
                            -- Someone is close, hold block
                            -- TODO: Replace with actual block key from Peroxide
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
            end
        end)
    else
        if Connections["AutoBlock"] then Connections["AutoBlock"]:Disconnect(); Connections["AutoBlock"] = nil end
    end
end)

createHeader(extraContent, "Notifications", 5)

-- Boss Notify
createToggle(extraContent, "Boss Spawn Alert", 6, false, function(state)
    Config.BossNotifyEnabled = state
    if state then
        Connections["BossNotify"] = RunService.Heartbeat:Connect(function()
            if not Config.BossNotifyEnabled then return end
            -- Scan for boss-type NPCs
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                    local name = obj.Name:lower()
                    if name:find("boss") or name:find("vasto") or name:find("captain") or name:find("espada") or name:find("menos") then
                        local hum = obj:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            -- Show notification
                            pcall(function()
                                game:GetService("StarterGui"):SetCore("SendNotification", {
                                    Title = "Boss Spawned!",
                                    Text = obj.Name .. " detected!",
                                    Duration = 5,
                                })
                            end)
                            jitterWait(30) -- don't spam
                        end
                    end
                end
            end
        end)
    else
        if Connections["BossNotify"] then Connections["BossNotify"]:Disconnect(); Connections["BossNotify"] = nil end
    end
end)

createHeader(extraContent, "Anti-Detection", 8)

createToggle(extraContent, "Anti-Idle", 9, true, function(state)
    Config.AntiIdleEnabled = state
end)

createToggle(extraContent, "Metahook (Spoof Stats)", 10, false, function(state)
    if state then
        setupMetahook()
        print("[Hub] Metamethod hooks applied")
    end
end)

createInfoText(extraContent, "Anti-Idle: Prevents AFK kick.\nMetahook: Spoofs WalkSpeed/JumpPower to default values when queried by anticheat.", 11)

createHeader(extraContent, "Settings", 12)

createButton(extraContent, "Save Config (Executor FS)", 13, function()
    pcall(function()
        if writefile then
            local data = HttpService:JSONEncode({
                FarmRange = Config.FarmRange,
                HealThreshold = Config.HealThreshold,
                SelectedBuild = Config.SelectedBuild,
            })
            writefile("PeroxideHubConfig.json", data)
            print("[Hub] Config saved!")
        else
            print("[Hub] writefile not available on this executor")
        end
    end)
end)

createButton(extraContent, "Load Config", 14, function()
    pcall(function()
        if readfile and isfile and isfile("PeroxideHubConfig.json") then
            local data = HttpService:JSONDecode(readfile("PeroxideHubConfig.json"))
            Config.FarmRange = data.FarmRange or Config.FarmRange
            Config.HealThreshold = data.HealThreshold or Config.HealThreshold
            Config.SelectedBuild = data.SelectedBuild or Config.SelectedBuild
            rangeLabel.Text = "Range: " .. Config.FarmRange .. " studs"
            healLabel.Text = "Heal at: " .. Config.HealThreshold .. "% HP"
            print("[Hub] Config loaded!")
        else
            print("[Hub] No saved config found")
        end
    end)
end)

------------------------------------------------------
-- 11. KEYBIND HANDLER
------------------------------------------------------
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleKey then
        GuiOpen = not GuiOpen
        if GuiOpen then
            MainFrame.Visible = true
            MainFrame.Size = UDim2.new(0, 460, 0, 0)
            tweenProp(MainFrame, {Size = Config.Size}, 0.3)
        else
            tweenProp(MainFrame, {Size = UDim2.new(0, 460, 0, 0)}, 0.3)
            task.wait(0.3)
            MainFrame.Visible = false
        end
    end
end)

------------------------------------------------------
-- 12. CONTEXT UPDATE LOOP
------------------------------------------------------
local function updateContext()
    local newRace = detectRace()
    local newLoc = detectLocation()
    local changed = false

    if newRace ~= Config.PlayerRace then
        Config.PlayerRace = newRace
        -- Apply race theme
        local raceTheme = RaceThemes[newRace]
        if raceTheme then
            applyTheme(raceTheme)
        else
            applyTheme(DefaultTheme)
        end
        changed = true
    end

    if newLoc ~= Config.CurrentLocation then
        Config.CurrentLocation = newLoc
        changed = true
    end

    InfoLabel.Text = Config.PlayerRace .. " | " .. Config.CurrentLocation

    if changed then
        refreshTravelTab()
        refreshStatsTab()
    end
end

------------------------------------------------------
-- 13. INIT
------------------------------------------------------

-- Initial context detect
updateContext()

-- Periodic context refresh (every 5s)
task.spawn(function()
    while ScreenGui.Parent do
        updateContext()
        task.wait(5)
    end
end)

-- Start anti-idle
startAntiIdle()

-- Activate first tab
TabButtons["Travel"].Button.TextColor3 = Theme.TextPrimary
TabButtons["Travel"].Underline.Visible = true
TabContents["Travel"].Visible = true
ActiveTab = "Travel"

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
end)

-- Opening animation
MainFrame.Size = UDim2.new(0, 460, 0, 0)
tweenProp(MainFrame, {Size = Config.Size}, 0.4)

print("================================================")
print("  Peroxide Hub v2.0 Loaded")
print("  Toggle: RightShift | Race: " .. Config.PlayerRace)
print("  Tabs: Travel | ESP | Farm | Stats | Extras")
print("  Anti-Detection: Active")
print("================================================")
