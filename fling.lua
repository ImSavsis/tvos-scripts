local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    Combat = {
        Aimbot = false,
        LockPart = "Head",
        FOV = 300,
        Godmode = false
    },
    Visuals = {
        ESP = false,
        TeamCheck = false,
        Color = Color3.fromRGB(170, 0, 255)
    },
    Movement = {
        Fly = false,
        Noclip = false,
        FlySpeed = 60,
        Wallbang = false,
        TPKey = Enum.KeyCode.X,
        BehindOffset = 3,
        TargetPlayer = nil
    },
    Trolling = {
        FlingLoop = false,
        TargetPlayer = nil
    },
    BombGame = {
        AutoSteal = false,
        AntiGive = false,
        AntiSteal = false,
        AutoPass = false,
        TargetPlayer = nil
    },
    Misc = {
        AntiFling = true
    },
    AntiAim = { Enabled = false, Speed = 50 },
    Audio = { JumpSoundId = "rbxassetid://9114223179" }
}

local Active = true
local Connections = {}
local Highlights = {}

local JumpSound = Instance.new("Sound")
JumpSound.SoundId = Config.Audio.JumpSoundId
JumpSound.Volume = 1
JumpSound.Parent = SoundService

local ok = pcall(function() return game:GetService("CoreGui").Name end)
local UIContainer = ok and game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TVOS_Menu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = UIContainer

local function IsValidTarget(plr)
    if not plr or plr == LocalPlayer or not plr.Character then return false end
    local hum = plr.Character:FindFirstChild("Humanoid")
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return false end
    if Config.Visuals.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function GetAimTarget()
    local closest = nil
    local minDistance = Config.Combat.FOV
    local mousePos = UserInputService:GetMouseLocation()
    local cam = workspace.CurrentCamera
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValidTarget(plr) and plr.Character:FindFirstChild(Config.Combat.LockPart) then
            local pos, vis = cam:WorldToViewportPoint(plr.Character[Config.Combat.LockPart].Position)
            if vis then
                local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                if dist < minDistance then
                    closest = plr
                    minDistance = dist
                end
            end
        end
    end
    return closest
end

local function GetClosestTarget()
    local closest = nil
    local minDistance = math.huge
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValidTarget(plr) then
            local dist = (plr.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
            if dist < minDistance then
                closest = plr
                minDistance = dist
            end
        end
    end
    return closest
end

local function GetTargetForTab(cfgTab)
    if cfgTab.TargetPlayer and IsValidTarget(cfgTab.TargetPlayer) then
        return cfgTab.TargetPlayer
    end
    return GetClosestTarget()
end

local function UpdateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char and Config.Visuals.ESP and IsValidTarget(plr) then
                local hl = Highlights[plr] or Instance.new("Highlight")
                hl.Name = "TVOS_ESP"
                hl.Adornee = char
                hl.FillColor = Config.Visuals.Color
                hl.OutlineColor = Color3.new(1, 1, 1)
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 0
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
end

table.insert(Connections, RunService.RenderStepped:Connect(UpdateESP))

local function HasBomb(plr)
    if not plr or not plr.Character then return false end
    for _, item in ipairs(plr.Character:GetChildren()) do
        local name = item.Name:lower()
        if item:IsA("Tool") or item:IsA("BasePart") then
            if name:find("bomb") or name:find("potato") or name:find("tnt") or name:find("c4") then
                return true
            end
        end
    end
    return false
end

local function GetBombHolder()
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValidTarget(plr) and HasBomb(plr) then
            return plr
        end
    end
    return nil
end

local function StealBomb()
    local holder = GetBombHolder()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not holder or not holder.Character or not myHRP then return end
    local targetHRP = holder.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local oldCF = myHRP.CFrame
    myHRP.CFrame = targetHRP.CFrame
    task.wait(0.03)
    myHRP.CFrame = oldCF
end

local function PassBombAggressive()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP or not HasBomb(LocalPlayer) then return end

    local target = GetTargetForTab(Config.BombGame)
    if not target or not target.Character then return end
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local oldCF = myHRP.CFrame
    for i = 1, 3 do
        myHRP.CFrame = targetHRP.CFrame * CFrame.Angles(0, math.rad(i * 120), 0)
        task.wait()
    end
    myHRP.CFrame = oldCF
end

local function ExecuteInstantFling(targetPlr)
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP or not targetPlr or not targetPlr.Character then return end
    local targetHRP = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local originalCFrame = myHRP.CFrame

    for _, p in ipairs(myChar:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end

    myHRP.CFrame = targetHRP.CFrame
    myHRP.AssemblyAngularVelocity = Vector3.new(0, 999999, 0)
    myHRP.AssemblyLinearVelocity = Vector3.new(99999, 99999, 99999)
    targetHRP.CanCollide = true

    task.wait(0.04)

    myHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    myHRP.CFrame = originalCFrame
end

local function SetupGodmode(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        local conn = hum.StateChanged:Connect(function(_, newState)
            if Config.Combat.Godmode and newState == Enum.HumanoidStateType.Dead then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            if newState == Enum.HumanoidStateType.Jumping then
                JumpSound:Play()
            end
        end)
        table.insert(Connections, conn)
    end
end

if LocalPlayer.Character then SetupGodmode(LocalPlayer.Character) end
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(SetupGodmode))

table.insert(Connections, Players.PlayerRemoving:Connect(function(plr)
    if Config.Movement.TargetPlayer == plr then Config.Movement.TargetPlayer = nil end
    if Config.Trolling.TargetPlayer == plr then Config.Trolling.TargetPlayer = nil end
    if Config.BombGame.TargetPlayer == plr then Config.BombGame.TargetPlayer = nil end
    if Highlights[plr] then
        Highlights[plr]:Destroy()
        Highlights[plr] = nil
    end
end))

-- UI Frame
local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 380, 0, 430)
Main.Position = UDim2.new(0.05, 0, 0.2, 0)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true

local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(40, 40, 55)

-- Tab Bar
local TabBar = Instance.new("Frame", Main)
TabBar.Size = UDim2.new(1, 0, 0, 40)
TabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
TabBar.BorderSizePixel = 0

local TabBarCorner = Instance.new("UICorner", TabBar)
TabBarCorner.CornerRadius = UDim.new(0, 8)

local TabListLayout = Instance.new("UIListLayout", TabBar)
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabListLayout.Padding = UDim.new(0, 3)

local Pages = Instance.new("Frame", Main)
Pages.Position = UDim2.new(0, 0, 0, 45)
Pages.Size = UDim2.new(1, 0, 1, -45)
Pages.BackgroundTransparency = 1

local PageViews = {}
local TabButtons = {}

local function SwitchTab(targetName)
    for name, page in pairs(PageViews) do
        page.Visible = (name == targetName)
    end
    for name, btn in pairs(TabButtons) do
        if name == targetName then
            btn.BackgroundColor3 = Color3.fromRGB(130, 40, 200)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
            btn.TextColor3 = Color3.fromRGB(140, 140, 160)
        end
    end
end

local function CreatePage(name)
    local page = Instance.new("ScrollingFrame", Pages)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)

    local layout = Instance.new("UIListLayout", page)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 6)

    local padding = Instance.new("UIPadding", page)
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 12)

    PageViews[name] = page

    local tabBtn = Instance.new("TextButton", TabBar)
    tabBtn.Size = UDim2.new(0.15, 0, 0.75, 0)
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(140, 140, 160)
    tabBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.TextSize = 10

    local btnCorner = Instance.new("UICorner", tabBtn)
    btnCorner.CornerRadius = UDim.new(0, 6)

    TabButtons[name] = tabBtn

    tabBtn.MouseButton1Click:Connect(function()
        SwitchTab(name)
    end)

    return page
end

local CombatPage = CreatePage("Combat")
local VisualsPage = CreatePage("Visuals")
local MovementPage = CreatePage("Movement")
local TrollingPage = CreatePage("Trolling")
local BombPage = CreatePage("Bomb Game")
local MiscPage = CreatePage("Misc")

local function AddToggleToPage(page, text, cfgTable, cfgVal)
    local btn = Instance.new("TextButton", page)
    btn.Size = UDim2.new(0.92, 0, 0, 32)
    btn.Text = "  " .. text
    btn.TextColor3 = cfgTable[cfgVal] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 170)
    btn.BackgroundColor3 = cfgTable[cfgVal] and Color3.fromRGB(130, 40, 200) or Color3.fromRGB(26, 26, 34)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left

    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        cfgTable[cfgVal] = not cfgTable[cfgVal]
        btn.BackgroundColor3 = cfgTable[cfgVal] and Color3.fromRGB(130, 40, 200) or Color3.fromRGB(26, 26, 34)
        btn.TextColor3 = cfgTable[cfgVal] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 170)
    end)
end

local function CreateDropdownInPage(page, titleText, onSelect)
    local dropBtn = Instance.new("TextButton", page)
    dropBtn.Size = UDim2.new(0.92, 0, 0, 32)
    dropBtn.Text = "  " .. titleText .. ": Nearest"
    dropBtn.TextColor3 = Color3.fromRGB(180, 180, 210)
    dropBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    dropBtn.Font = Enum.Font.Gotham
    dropBtn.TextSize = 12
    dropBtn.TextXAlignment = Enum.TextXAlignment.Left

    local dropCorner = Instance.new("UICorner", dropBtn)
    dropCorner.CornerRadius = UDim.new(0, 6)

    local listFrame = Instance.new("Frame", page)
    listFrame.Size = UDim2.new(0.92, 0, 0, 0)
    listFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    listFrame.ClipsDescendants = true
    listFrame.Visible = false

    local listCorner = Instance.new("UICorner", listFrame)
    listCorner.CornerRadius = UDim.new(0, 6)

    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Padding = UDim.new(0, 3)

    local listPadding = Instance.new("UIPadding", listFrame)
    listPadding.PaddingTop = UDim.new(0, 4)
    listPadding.PaddingBottom = UDim.new(0, 4)

    local function Refresh()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        local autoBtn = Instance.new("TextButton", listFrame)
        autoBtn.Size = UDim2.new(0.95, 0, 0, 24)
        autoBtn.Text = "[ Nearest Player ]"
        autoBtn.TextColor3 = Color3.fromRGB(160, 160, 180)
        autoBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
        autoBtn.Font = Enum.Font.Gotham
        autoBtn.TextSize = 11

        local autoCorner = Instance.new("UICorner", autoBtn)
        autoCorner.CornerRadius = UDim.new(0, 4)

        autoBtn.MouseButton1Click:Connect(function()
            onSelect(nil)
            dropBtn.Text = "  " .. titleText .. ": Nearest"
            listFrame.Visible = false
            listFrame.Size = UDim2.new(0.92, 0, 0, 0)
        end)

        local height = 32
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local pBtn = Instance.new("TextButton", listFrame)
                pBtn.Size = UDim2.new(0.95, 0, 0, 24)
                pBtn.Text = plr.Name
                pBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
                pBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
                pBtn.Font = Enum.Font.Gotham
                pBtn.TextSize = 11

                local pCorner = Instance.new("UICorner", pBtn)
                pCorner.CornerRadius = UDim.new(0, 4)

                pBtn.MouseButton1Click:Connect(function()
                    onSelect(plr)
                    dropBtn.Text = "  " .. titleText .. ": " .. plr.Name
                    listFrame.Visible = false
                    listFrame.Size = UDim2.new(0.92, 0, 0, 0)
                end)
                height = height + 27
            end
        end

        if listFrame.Visible then
            listFrame.Size = UDim2.new(0.92, 0, 0, math.min(height, 120))
        end
    end

    dropBtn.MouseButton1Click:Connect(function()
        listFrame.Visible = not listFrame.Visible
        if listFrame.Visible then Refresh() else listFrame.Size = UDim2.new(0.92, 0, 0, 0) end
    end)

    table.insert(Connections, Players.PlayerAdded:Connect(Refresh))
    table.insert(Connections, Players.PlayerRemoving:Connect(Refresh))
end

-- Combat
AddToggleToPage(CombatPage, "AimLock (RMB)", Config.Combat, "Aimbot")
AddToggleToPage(CombatPage, "Godmode / Anti-Die", Config.Combat, "Godmode")

-- Visuals
AddToggleToPage(VisualsPage, "ESP (Highlight ВХ)", Config.Visuals, "ESP")
AddToggleToPage(VisualsPage, "Team Check", Config.Visuals, "TeamCheck")

-- Movement
AddToggleToPage(MovementPage, "Noclip", Config.Movement, "Noclip")
AddToggleToPage(MovementPage, "Wallbang", Config.Movement, "Wallbang")
AddToggleToPage(MovementPage, "Fly Mode", Config.Movement, "Fly")

-- Trolling
CreateDropdownInPage(TrollingPage, "Fling Target", function(plr)
    Config.Trolling.TargetPlayer = plr
end)

local FlingBtn = Instance.new("TextButton", TrollingPage)
FlingBtn.Size = UDim2.new(0.92, 0, 0, 32)
FlingBtn.Text = "INSTANT FLING TARGET"
FlingBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
FlingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlingBtn.Font = Enum.Font.GothamBold
FlingBtn.TextSize = 11

local FlingCorner = Instance.new("UICorner", FlingBtn)
FlingCorner.CornerRadius = UDim.new(0, 6)
FlingBtn.MouseButton1Click:Connect(function()
    local target = GetTargetForTab(Config.Trolling)
    if target then ExecuteInstantFling(target) end
end)

AddToggleToPage(TrollingPage, "Loop Fling Target", Config.Trolling, "FlingLoop")

-- Bomb Game
CreateDropdownInPage(BombPage, "Pass Target", function(plr)
    Config.BombGame.TargetPlayer = plr
end)

AddToggleToPage(BombPage, "Auto-Steal (Всегда забирать)", Config.BombGame, "AutoSteal")
AddToggleToPage(BombPage, "Auto Pass (Авто спам отдать)", Config.BombGame, "AutoPass")

local StealBtn = Instance.new("TextButton", BombPage)
StealBtn.Size = UDim2.new(0.92, 0, 0, 32)
StealBtn.Text = "STEAL BOMB NOW (Забрать)"
StealBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 30)
StealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StealBtn.Font = Enum.Font.GothamBold
StealBtn.TextSize = 11

local StealCorner = Instance.new("UICorner", StealBtn)
StealCorner.CornerRadius = UDim.new(0, 6)
StealBtn.MouseButton1Click:Connect(StealBomb)

local PassBtn = Instance.new("TextButton", BombPage)
PassBtn.Size = UDim2.new(0.92, 0, 0, 32)
PassBtn.Text = "FORCE PASS BOMB (Отдать 100%)"
PassBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 80)
PassBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PassBtn.Font = Enum.Font.GothamBold
PassBtn.TextSize = 11

local PassCorner = Instance.new("UICorner", PassBtn)
PassCorner.CornerRadius = UDim.new(0, 6)
PassBtn.MouseButton1Click:Connect(PassBombAggressive)

AddToggleToPage(BombPage, "Anti-Give (Защита от передачи)", Config.BombGame, "AntiGive")
AddToggleToPage(BombPage, "Anti-Steal (Защита от кражи)", Config.BombGame, "AntiSteal")

-- Misc
AddToggleToPage(MiscPage, "Anti-Fling (Защита от флинга)", Config.Misc, "AntiFling")

local UnloadBtn = Instance.new("TextButton", MiscPage)
UnloadBtn.Size = UDim2.new(0.92, 0, 0, 35)
UnloadBtn.Text = "UNLOAD SCRIPT"
UnloadBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 40)
UnloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.TextSize = 12

local UnloadCorner = Instance.new("UICorner", UnloadBtn)
UnloadCorner.CornerRadius = UDim.new(0, 6)

UnloadBtn.MouseButton1Click:Connect(function()
    Active = false
    ScreenGui:Destroy()
    if JumpSound then JumpSound:Destroy() end
    for _, hl in pairs(Highlights) do
        if hl then hl:Destroy() end
    end
    Highlights = {}
    for _, c in pairs(Connections) do c:Disconnect() end
end)

SwitchTab("Trolling")

-- Anti-Fling Logic
table.insert(Connections, RunService.Stepped:Connect(function()
    if not Active or not Config.Misc.AntiFling then return end
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    -- Сброс ненормального внешнего физического импульса
    if myHRP.AssemblyLinearVelocity.Magnitude > 250 or myHRP.AssemblyAngularVelocity.Magnitude > 250 then
        myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        myHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end

    -- Защита при приближении вражеских флинг-скриптов
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP = plr.Character.HumanoidRootPart
            local dist = (myHRP.Position - targetHRP.Position).Magnitude
            if dist < 8 and (targetHRP.AssemblyAngularVelocity.Magnitude > 300 or targetHRP.AssemblyLinearVelocity.Magnitude > 300) then
                for _, part in ipairs(myChar:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                myHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end))

-- Main Loops
table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not Active then return end

    if Config.Trolling.FlingLoop then
        local target = GetTargetForTab(Config.Trolling)
        if target then ExecuteInstantFling(target) end
    end

    if Config.BombGame.AutoSteal and not HasBomb(LocalPlayer) then
        local holder = GetBombHolder()
        if holder then
            StealBomb()
        end
    end

    if Config.BombGame.AutoPass and HasBomb(LocalPlayer) then
        PassBombAggressive()
    end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myHRP and Config.BombGame.AntiGive and not HasBomb(LocalPlayer) then
        local holder = GetBombHolder()
        if holder and holder.Character and holder.Character:FindFirstChild("HumanoidRootPart") then
            local hHRP = holder.Character.HumanoidRootPart
            if (myHRP.Position - hHRP.Position).Magnitude < 14 then
                local pushDir = (myHRP.Position - hHRP.Position).Unit
                myHRP.CFrame = myHRP.CFrame + (pushDir * 5)
            end
        end
    end

    if myHRP and Config.BombGame.AntiSteal and HasBomb(LocalPlayer) then
        local closest = GetClosestTarget()
        if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
            local cHRP = closest.Character.HumanoidRootPart
            if (myHRP.Position - cHRP.Position).Magnitude < 14 then
                local runDir = (myHRP.Position - cHRP.Position).Unit
                myHRP.CFrame = myHRP.CFrame + (runDir * 5)
            end
        end
    end
end))

-- Keybinds
table.insert(Connections, UserInputService.InputBegan:Connect(function(i, g)
    if not g then
        if i.KeyCode == Enum.KeyCode.Home or i.KeyCode == Enum.KeyCode.Insert then
            Main.Visible = not Main.Visible
        elseif i.KeyCode == Config.Movement.TPKey then
            local target = GetTargetForTab(Config.Movement)
            local myChar = LocalPlayer.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and myHRP then
                myHRP.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, Config.Movement.BehindOffset)
            end
        end
    end
end))

-- Render Loop
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not Active then return end
    local cam = workspace.CurrentCamera

    if Config.Combat.Aimbot and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetAimTarget()
        if target and target.Character and target.Character:FindFirstChild(Config.Combat.LockPart) then
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, target.Character[Config.Combat.LockPart].Position)
        end
    end

    if Config.Movement.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local hum = LocalPlayer.Character.Humanoid
        local bv = hrp:FindFirstChild("TvosFly") or Instance.new("BodyVelocity", hrp)
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Name = "TvosFly"
        local dir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        bv.Velocity = dir * Config.Movement.FlySpeed
        hum.PlatformStand = true
    else
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local bv = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("TvosFly")
            if bv then bv:Destroy() end
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end
end))

table.insert(Connections, RunService.Stepped:Connect(function()
    if Config.Movement.Noclip and LocalPlayer.Character then
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end))
