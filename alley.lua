local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Active = true
local ESPEnabled = false
local InvisEnabled = false
local Connections = {}
local Highlights = {}

local ok = pcall(function() return game:GetService("CoreGui").Name end)
local UIContainer = ok and game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TVOS_Clean"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = UIContainer

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 210, 0, 150)
Main.Position = UDim2.new(0.05, 0, 0.2, 0)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true

local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(40, 40, 55)

local function CreateBtn(text, pos, bg, textCol)
    local btn = Instance.new("TextButton", Main)
    btn.Size = UDim2.new(0.9, 0, 0, 32)
    btn.Position = pos
    btn.Text = text
    btn.TextColor3 = textCol or Color3.fromRGB(180, 180, 200)
    btn.BackgroundColor3 = bg or Color3.fromRGB(28, 28, 38)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)
    return btn
end

local ESPBtn = CreateBtn("ESP: OFF", UDim2.new(0.05, 0, 0.1, 0))
local InvisBtn = CreateBtn("FE INVIS: OFF", UDim2.new(0.05, 0, 0.38, 0))
local UnloadBtn = CreateBtn("UNLOAD", UDim2.new(0.05, 0, 0.66, 0), Color3.fromRGB(150, 30, 40), Color3.fromRGB(255, 255, 255))

ESPBtn.MouseButton1Click:Connect(function()
    ESPEnabled = not ESPEnabled
    ESPBtn.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
    ESPBtn.BackgroundColor3 = ESPEnabled and Color3.fromRGB(130, 40, 200) or Color3.fromRGB(28, 28, 38)
    ESPBtn.TextColor3 = ESPEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 200)
end)

local OriginalC0 = nil
InvisBtn.MouseButton1Click:Connect(function()
    InvisEnabled = not InvisEnabled
    InvisBtn.Text = InvisEnabled and "FE INVIS: ON" or "FE INVIS: OFF"
    InvisBtn.BackgroundColor3 = InvisEnabled and Color3.fromRGB(130, 40, 200) or Color3.fromRGB(28, 28, 38)
    InvisBtn.TextColor3 = InvisEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 200)

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local lowerTorso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
    if not hrp or not lowerTorso then return end

    local rootJoint = lowerTorso:FindFirstChild("RootJoint") or hrp:FindFirstChild("RootJoint")
    if rootJoint then
        if InvisEnabled then
            if not OriginalC0 then OriginalC0 = rootJoint.C0 end
            rootJoint.C0 = OriginalC0 * CFrame.new(0, -500, 0)
        else
            if OriginalC0 then
                rootJoint.C0 = OriginalC0
                OriginalC0 = nil
            end
        end
    end
end)

UnloadBtn.MouseButton1Click:Connect(function()
    Active = false
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local lowerTorso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
        if hrp and lowerTorso and OriginalC0 then
            local rootJoint = lowerTorso:FindFirstChild("RootJoint") or hrp:FindFirstChild("RootJoint")
            if rootJoint then rootJoint.C0 = OriginalC0 end
        end
    end
    ScreenGui:Destroy()
    for _, hl in pairs(Highlights) do
        if hl then hl:Destroy() end
    end
    Highlights = {}
    for _, c in pairs(Connections) do c:Disconnect() end
end)

-- ESP Loop
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not Active then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local char = plr.Character
            local hum = char:FindFirstChild("Humanoid")
            if ESPEnabled and hum and hum.Health > 0 then
                local hl = Highlights[plr] or Instance.new("Highlight")
                hl.Name = "TVOS_ESP"
                hl.Adornee = char
                hl.FillColor = Color3.fromRGB(170, 0, 255)
                hl.OutlineColor = Color3.new(1, 1, 1)
                hl.FillTransparency = 0.5
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = char
                Highlights[plr] = hl
            else
                if Highlights[plr] then
                    Highlights[plr]:Destroy()
                    Highlights[plr] = nil
                end
            end
        end
    end
end))

-- TP по кнопке X / Ч
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.X then
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end

        local closestPlr = nil
        local minDist = math.huge

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hum = plr.Character:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    local dist = (plr.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closestPlr = plr
                    end
                end
            end
        end

        if closestPlr and closestPlr.Character and closestPlr.Character:FindFirstChild("HumanoidRootPart") then
            myHRP.CFrame = closestPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        end
    end
end))

table.insert(Connections, Players.PlayerRemoving:Connect(function(plr)
    if Highlights[plr] then
        Highlights[plr]:Destroy()
        Highlights[plr] = nil
    end
end))
