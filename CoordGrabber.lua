--[[
    Peroxide Coordinate Grabber
    Run this on mobile to collect location coordinates.

    HOW TO USE:
    1. Execute this script in Delta
    2. Walk to any location you want to save
    3. Tap the "SAVE POS" button on screen
    4. It saves to PeroxideCoords.txt in your executor folder
    5. Repeat for every location
    6. When done, tap "SHOW ALL" to see all saved coords

    Then paste those Vector3 values into PeroxideHub.lua
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-- Kill old instance
for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
    if gui.Name == "CoordGrabber" then gui:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CoordGrabber"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Save button (big, easy to tap on mobile)
local SaveBtn = Instance.new("TextButton")
SaveBtn.Text = "SAVE POS"
SaveBtn.Size = UDim2.new(0, 120, 0, 50)
SaveBtn.Position = UDim2.new(0, 10, 0.5, -60)
SaveBtn.BackgroundColor3 = Color3.fromRGB(233, 69, 96)
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 18
SaveBtn.BorderSizePixel = 0
SaveBtn.Parent = ScreenGui
Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 12)

-- Show All button
local ShowBtn = Instance.new("TextButton")
ShowBtn.Text = "SHOW ALL"
ShowBtn.Size = UDim2.new(0, 120, 0, 50)
ShowBtn.Position = UDim2.new(0, 10, 0.5, 0)
ShowBtn.BackgroundColor3 = Color3.fromRGB(15, 52, 96)
ShowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ShowBtn.Font = Enum.Font.GothamBold
ShowBtn.TextSize = 16
ShowBtn.BorderSizePixel = 0
ShowBtn.Parent = ScreenGui
Instance.new("UICorner", ShowBtn).CornerRadius = UDim.new(0, 12)

-- Label name input (simple text label showing last save)
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Text = "Walk to a location, tap SAVE POS"
InfoLabel.Size = UDim2.new(0, 300, 0, 40)
InfoLabel.Position = UDim2.new(0, 10, 0.5, -110)
InfoLabel.BackgroundColor3 = Color3.fromRGB(26, 26, 46)
InfoLabel.TextColor3 = Color3.fromRGB(234, 234, 234)
InfoLabel.Font = Enum.Font.GothamBold
InfoLabel.TextSize = 12
InfoLabel.TextWrapped = true
InfoLabel.BorderSizePixel = 0
InfoLabel.Parent = ScreenGui
Instance.new("UICorner", InfoLabel).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", InfoLabel).PaddingLeft = UDim.new(0, 8)

-- Output panel (for SHOW ALL)
local OutputFrame = Instance.new("ScrollingFrame")
OutputFrame.Size = UDim2.new(0.8, 0, 0.6, 0)
OutputFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
OutputFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 36)
OutputFrame.BorderSizePixel = 0
OutputFrame.ScrollBarThickness = 4
OutputFrame.Visible = false
OutputFrame.Parent = ScreenGui
Instance.new("UICorner", OutputFrame).CornerRadius = UDim.new(0, 10)

local OutputText = Instance.new("TextLabel")
OutputText.Size = UDim2.new(1, -16, 1, 0)
OutputText.Position = UDim2.new(0, 8, 0, 0)
OutputText.BackgroundTransparency = 1
OutputText.TextColor3 = Color3.fromRGB(200, 200, 200)
OutputText.Font = Enum.Font.Code
OutputText.TextSize = 11
OutputText.TextXAlignment = Enum.TextXAlignment.Left
OutputText.TextYAlignment = Enum.TextYAlignment.Top
OutputText.TextWrapped = true
OutputText.Parent = OutputFrame

local CloseOutput = Instance.new("TextButton")
CloseOutput.Text = "X"
CloseOutput.Size = UDim2.new(0, 30, 0, 30)
CloseOutput.Position = UDim2.new(1, -35, 0, 5)
CloseOutput.BackgroundColor3 = Color3.fromRGB(233, 69, 96)
CloseOutput.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseOutput.Font = Enum.Font.GothamBold
CloseOutput.TextSize = 14
CloseOutput.BorderSizePixel = 0
CloseOutput.Parent = OutputFrame
Instance.new("UICorner", CloseOutput).CornerRadius = UDim.new(0, 6)

CloseOutput.MouseButton1Click:Connect(function()
    OutputFrame.Visible = false
end)

-- Counter
local saveCount = 0

SaveBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local pos = hrp.Position
    local coordStr = string.format("Vector3.new(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
    saveCount = saveCount + 1

    -- Flash green to confirm
    SaveBtn.BackgroundColor3 = Color3.fromRGB(76, 209, 55)
    SaveBtn.Text = "SAVED!"
    task.delay(1, function()
        SaveBtn.BackgroundColor3 = Color3.fromRGB(233, 69, 96)
        SaveBtn.Text = "SAVE POS"
    end)

    -- Copy to clipboard
    pcall(function()
        if setclipboard then setclipboard(coordStr)
        elseif toclipboard then toclipboard(coordStr) end
    end)

    -- Save to file
    pcall(function()
        if writefile and readfile and isfile then
            local existing = ""
            if isfile("PeroxideCoords.txt") then
                existing = readfile("PeroxideCoords.txt")
            end
            local entry = string.format(
                "-- Location #%d  (saved %s)\n[\"NAME_HERE\"] = %s,\n\n",
                saveCount,
                os.date("%H:%M:%S"),
                coordStr
            )
            writefile("PeroxideCoords.txt", existing .. entry)
        end
    end)

    -- Show notification
    InfoLabel.Text = "#" .. saveCount .. " saved: " .. coordStr

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Pos #" .. saveCount .. " Saved",
            Text = coordStr,
            Duration = 3,
        })
    end)

    print("[CoordGrabber] #" .. saveCount .. ": " .. coordStr)
end)

ShowBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if readfile and isfile and isfile("PeroxideCoords.txt") then
            local data = readfile("PeroxideCoords.txt")
            OutputText.Text = data
            OutputText.Size = UDim2.new(1, -16, 0, #data * 0.5)
            OutputFrame.CanvasSize = UDim2.new(0, 0, 0, #data * 0.5)
            OutputFrame.Visible = true
        else
            OutputText.Text = "No coordinates saved yet.\nWalk to locations and tap SAVE POS."
            OutputFrame.Visible = true
        end
    end)
end)

print("=================================")
print("  Coord Grabber Loaded")
print("  Walk around + tap SAVE POS")
print("=================================")
