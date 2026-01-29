local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Проверка API
assert(Drawing, "Drawing API not available")

-- Настройки темы
local UI_Color = Color3.fromRGB(170, 0, 255)
local BG_Color = Color3.fromRGB(15, 10, 20)

local Config = {
    Visuals = {
        Enabled = true,
        Boxes = true,
        Names = true,
        Health = true,
        TeamCheck = true
    },
    Aimbot = {
        Enabled = true,
        Key = Enum.UserInputType.MouseButton2,
        LockPart = "Head",
        FOV = 250
    },
    Movement = {
        Fly = false,
        Noclip = false,
        FlySpeed = 60,
        TPKey = Enum.KeyCode.E,
        BehindOffset = -5
    },
    World = {
        FieldOfView = 80
    }
}

-- [ ФУНКЦИИ DRAWING ]
local function CreateLine(color, thickness)
    local l = Drawing.new("Line")
    l.Color = color or Color3.new(1,1,1)
    l.Thickness = thickness or 2
    l.Visible = false
    return l
end

local function CreateText(text, color, size)
    local t = Drawing.new("Text")
    t.Text = text or ""
    t.Color = color or Color3.new(1,1,1)
    t.Size = size or 16
    t.Center = true
    t.Outline = true
    t.Visible = false
    return t
end

local function CreateSquare(color, thickness)
    local s = Drawing.new("Square")
    s.Color = color or Color3.new(1,1,1)
    s.Thickness = thickness or 2
    s.Filled = false
    s.Visible = false
    return s
end

-- [ ЛОГИКА AIMBOT ]
local AimRunning = false
local LockedTarget = nil

local function GetClosestPlayerToMouse()
    local closest = nil
    local shortestDist = Config.Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild(Config.Aimbot.LockPart) then
            if Config.Visuals.TeamCheck and plr.Team == LocalPlayer.Team then continue end
            
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos, vis = Camera:WorldToViewportPoint(plr.Character[Config.Aimbot.LockPart].Position)
                if vis then
                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if dist < shortestDist then
                        closest = plr
                        shortestDist = dist
                    end
                end
            end
        end
    end
    return closest
end

-- [ ЛОГИКА ESP ]
local ESPObjects = {}
local function DrawESP(plr)
    RunService.RenderStepped:Connect(function()
        if not ESPObjects[plr.Name] then
            ESPObjects[plr.Name] = {
                box = CreateSquare(UI_Color, 2),
                name = CreateText(plr.Name, Color3.new(1,1,1), 16),
                health = CreateLine(Color3.fromRGB(0, 255, 0), 2)
            }
        end

        local data = ESPObjects[plr.Name]
        local char = plr.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        local isTeam = (plr.Team == LocalPlayer.Team)
        local shouldShow = Config.Visuals.Enabled and (not Config.Visuals.TeamCheck or not isTeam)

        if not char or not hum or hum.Health <= 0 or not hrp or not shouldShow then
            data.box.Visible = false
            data.name.Visible = false
            data.health.Visible = false
            return
        end

        local parts = {Head=char:FindFirstChild("Head"), Torso=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")}
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local anyVisible = false

        for _, part in pairs(parts) do
            if part then
                local pos, vis = Camera:WorldToViewportPoint(part.Position)
                anyVisible = anyVisible or vis
                minX = math.min(minX, pos.X)
                minY = math.min(minY, pos.Y)
                maxX = math.max(maxX, pos.X)
                maxY = math.max(maxY, pos.Y)
            end
        end

        if anyVisible then
            local width = maxX - minX
            local height = maxY - minY
            local centerX = (minX + maxX)/2

            data.box.Position = Vector2.new(minX, minY)
            data.box.Size = Vector2.new(math.max(width, 6), math.max(height, 6))
            data.box.Visible = Config.Visuals.Boxes
            data.box.Color = UI_Color

            data.name.Position = Vector2.new(centerX, minY - 14)
            data.name.Visible = Config.Visuals.Names

            if Config.Visuals.Health then
                local healthRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                data.health.From = Vector2.new(minX - 8, maxY)
                data.health.To = Vector2.new(minX - 8, maxY - (height * healthRatio))
                data.health.Color = Color3.fromHSV(healthRatio * 0.3, 1, 1)
                data.health.Visible = true
            else
                data.health.Visible = false
            end
        else
            data.box.Visible = false
            data.name.Visible = false
            data.health.Visible = false
        end
    end)
end

-- Инициализация ESP
for _, plr in pairs(Players:GetPlayers()) do if plr ~= LocalPlayer then DrawESP(plr) end end
Players.PlayerAdded:Connect(function(plr) if plr ~= LocalPlayer then DrawESP(plr) end end)

-- [ ТЕЛЕПОРТ ]
local function GetClosestEnemyForTP(maxDistance)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local root = character.HumanoidRootPart
    local closest, closestDist = nil, maxDistance
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            if Config.Visuals.TeamCheck and plr.Team == LocalPlayer.Team then continue end
            local enemyRoot = plr.Character.HumanoidRootPart
            local dist = (enemyRoot.Position - root.Position).Magnitude
            if dist < closestDist then
                closest = enemyRoot
                closestDist = dist
            end
        end
    end
    return closest
end

local function TeleportBehindTarget()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local target = GetClosestEnemyForTP(9999)
    if target then
        local enemyLook = target.CFrame.LookVector
        local behindPosition = target.Position + (enemyLook * Config.Movement.BehindOffset)
        character.HumanoidRootPart.CFrame = CFrame.new(behindPosition, target.Position)
    end
end

-- [ ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ]
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 240, 0, 420); Main.Position = UDim2.new(0.05, 0, 0.2, 0); Main.BackgroundColor3 = BG_Color; Main.BorderSizePixel = 2; Main.BorderColor3 = UI_Color; Main.Active = true; Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 35); Title.Text = "TVOS SCRIPTS V14"; Title.BackgroundColor3 = Color3.fromRGB(30, 0, 60); Title.TextColor3 = Color3.new(1,1,1); Title.Font = Enum.Font.GothamBold

local DiscordLink = Instance.new("TextLabel", Main)
DiscordLink.Size = UDim2.new(1, 0, 0, 20); DiscordLink.Position = UDim2.new(0, 0, 0, 35); DiscordLink.BackgroundTransparency = 1; DiscordLink.Text = "discord.gg/6mkPrSdgVa"; DiscordLink.Font = Enum.Font.Code; DiscordLink.TextSize = 14
RunService.RenderStepped:Connect(function() DiscordLink.TextColor3 = Color3.fromHSV(tick() % 5 / 5, 1, 1) end)

local Content = Instance.new("ScrollingFrame", Main)
Content.Position = UDim2.new(0,0,0,60); Content.Size = UDim2.new(1,0,1,-60); Content.BackgroundTransparency = 1; Content.CanvasSize = UDim2.new(0,0,1.8,0)
Instance.new("UIListLayout", Content).HorizontalAlignment = "Center"; Content.UIListLayout.Padding = UDim.new(0, 5)

local function AddToggle(text, configTable, configValue)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(0.9, 0, 0, 30); btn.Text = text; btn.BackgroundColor3 = configTable[configValue] and UI_Color or Color3.fromRGB(40, 40, 40); btn.TextColor3 = Color3.new(1,1,1)
    btn.MouseButton1Click:Connect(function() configTable[configValue] = not configTable[configValue] btn.BackgroundColor3 = configTable[configValue] and UI_Color or Color3.fromRGB(40, 40, 40) end)
end

local function AddSlider(text, min, max, configTable, configValue)
    local container = Instance.new("Frame", Content); container.Size = UDim2.new(0.9, 0, 0, 45); container.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", container); label.Size = UDim2.new(1, 0, 0, 20); label.Text = text .. ": " .. configTable[configValue]; label.TextColor3 = Color3.new(1,1,1); label.BackgroundTransparency = 1
    local sliderBar = Instance.new("Frame", container); sliderBar.Size = UDim2.new(1, 0, 0, 8); sliderBar.Position = UDim2.new(0, 0, 0, 25); sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    local sliderBtn = Instance.new("TextButton", sliderBar); sliderBtn.Size = UDim2.new(0, 10, 1, 0); sliderBtn.BackgroundColor3 = UI_Color; sliderBtn.Text = ""
    sliderBtn.MouseButton1Down:Connect(function()
        local move; move = RunService.RenderStepped:Connect(function()
            local rel = math.clamp((UserInputService:GetMouseLocation().X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
            configTable[configValue] = math.floor(min + (rel * (max - min)))
            label.Text = text .. ": " .. configTable[configValue]
            sliderBtn.Position = UDim2.new(rel, -5, 0, 0)
        end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then move:Disconnect() end end)
    end)
end

AddToggle("ESP Enabled", Config.Visuals, "Enabled")
AddToggle("ESP Boxes", Config.Visuals, "Boxes")
AddToggle("AimLock (Right Click)", Config.Aimbot, "Enabled")
AddToggle("Fly Mode", Config.Movement, "Fly")
AddToggle("Noclip", Config.Movement, "Noclip")
AddToggle("Team Check", Config.Visuals, "TeamCheck")
AddSlider("Field of View", 70, 120, Config.World, "FieldOfView")
AddSlider("Fly Speed", 20, 300, Config.Movement, "FlySpeed")

-- [ ОБРАБОТКА ПОЛЕТА И АИМА ]
RunService.RenderStepped:Connect(function()
    Camera.FieldOfView = Config.World.FieldOfView
    
    -- Логика Аима
    if AimRunning and Config.Aimbot.Enabled then
        LockedTarget = GetClosestPlayerToMouse()
        if LockedTarget and LockedTarget.Character and LockedTarget.Character:FindFirstChild(Config.Aimbot.LockPart) then
            local targetPos = LockedTarget.Character[Config.Aimbot.LockPart].Position
            local screenPos, _ = Camera:WorldToViewportPoint(targetPos)
            local mousePos = UserInputService:GetMouseLocation()
            mousemoverel(screenPos.X - mousePos.X, screenPos.Y - mousePos.Y)
        end
    end

    -- Логика Полета
    if Config.Movement.Fly and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("TvosFly") or Instance.new("BodyVelocity", hrp)
            bv.Name = "TvosFly"; bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            local dir = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
            bv.Velocity = dir * Config.Movement.FlySpeed
            LocalPlayer.Character.Humanoid.PlatformStand = true
        end
    else
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local bv = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("TvosFly")
            if bv then bv:Destroy() end
            LocalPlayer.Character.Humanoid.PlatformStand = false
        end
    end
end)

RunService.Stepped:Connect(function()
    if Config.Movement.Noclip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end
    end
end)

UserInputService.InputBegan:Connect(function(i, g)
    if not g and i.KeyCode == Config.Movement.TPKey then TeleportBehindTarget() end
    if i.KeyCode == Enum.KeyCode.Home then Main.Visible = not Main.Visible end
    if i.UserInputType == Config.Aimbot.Key then AimRunning = true end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Config.Aimbot.Key then AimRunning = false; LockedTarget = nil end
end)

setclipboard("https://discord.gg/6mkPrSdgVa")
