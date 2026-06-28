-- Fling Controller v2.1
-- Положение лёжа, выбор цели из списка игроков, скорость полёта, уведомление, закрытие скрипта

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Настройки по умолчанию
local CONFIG = {
    FLING_POWER = 150,
    FOLLOW_DISTANCE = 3,
    FLY_SPEED = 8,
    FLING_INTERVAL = 0.5,
    GUI_BG_COLOR = Color3.fromRGB(20,22,30),
    GUI_BG_TRANSPARENCY = 0.08,
    GUI_ACCENT = Color3.fromRGB(0,180,255),
    HIGHLIGHT_ENABLED = false,
    HIGHLIGHT_MURDERER = Color3.fromRGB(255,0,0),
    HIGHLIGHT_SHERIFF = Color3.fromRGB(0,0,255),
    TARGET_NAME = "",
}

-- Состояния
local TARGET = nil
local enabled = false
local bv = nil
local gyro = nil
local lastFling = 0
local heartbeatConnection = nil
local menuOpen = false
local playerListOpen = false
local highlights = {}
local highlightTasks = {}

-- ===== Вспомогательные функции =====
local function getTargetByName(name)
    if name and name ~= "" then
        return game.Players:FindFirstChild(name)
    end
    return nil
end

local function getClosestPlayer()
    local nearest, dist = nil, math.huge
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr ~= Player then
            local char = plr.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local d = (RootPart.Position - char.HumanoidRootPart.Position).Magnitude
                if d < dist then dist, nearest = d, plr end
            end
        end
    end
    return nearest
end

local function getTarget()
    local byName = getTargetByName(CONFIG.TARGET_NAME)
    if byName then return byName end
    return getClosestPlayer()
end

local function flingTarget(target)
    if not target or not target.Character then return end
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.Velocity = Vector3.new(0, CONFIG.FLING_POWER, 0)
    end
end

local function stopFlying()
    enabled = false
    if bv then bv:Destroy(); bv = nil end
    if gyro then gyro:Destroy(); gyro = nil end
    if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
    Humanoid.PlatformStand = false
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    if statusLabel then statusLabel.Text = "Выключено"; statusLabel.TextColor3 = Color3.fromRGB(255,70,70) end
    if toggleBtn then toggleBtn.Text = "▶ Включить" end
end

local function flyUnder(target)
    if not target or not target.Character then return end
    stopFlying()

    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = Vector3.new(0,0,0)
    bv.Parent = RootPart

    gyro = Instance.new("BodyGyro")
    gyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
    gyro.CFrame = CFrame.new(RootPart.Position, RootPart.Position + Vector3.new(0,-1,0))
    gyro.Parent = RootPart

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    Humanoid.PlatformStand = true

    enabled = true
    lastFling = 0
    if statusLabel then
        statusLabel.Text = "Включено (цель: " .. target.Name .. ")"
        statusLabel.TextColor3 = Color3.fromRGB(0,255,150)
    end
    if toggleBtn then toggleBtn.Text = "⏹ Выключить" end

    heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not enabled then return end
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            stopFlying(); return
        end

        local targetPos = target.Character.HumanoidRootPart.Position
        local underPos = targetPos - Vector3.new(0, CONFIG.FOLLOW_DISTANCE, 0)
        local direction = (underPos - RootPart.Position)

        if direction.Magnitude > 10 then
            RootPart.CFrame = CFrame.new(underPos)
        else
            bv.Velocity = direction * CONFIG.FLY_SPEED
        end

        -- Лежачее положение
        local rot = CFrame.Angles(math.rad(90), 0, 0)
        RootPart.CFrame = CFrame.new(RootPart.Position) * rot

        if tick() - lastFling > CONFIG.FLING_INTERVAL then
            flingTarget(target)
            lastFling = tick()
        end
    end)
end

-- ===== Выделение (хитбоксы) =====
local function clearHighlights()
    for plr, box in pairs(highlights) do
        if box and box.Parent then box:Destroy() end
    end
    highlights = {}
    for _, task in ipairs(highlightTasks) do
        if task and task.heartbeat then task.heartbeat:Disconnect() end
    end
    highlightTasks = {}
end

local function createHighlight(player, color)
    if not player or not player.Character then return nil end
    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local old = char:FindFirstChild("HighlightBox")
    if old then old:Destroy() end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "HighlightBox"
    box.Size = Vector3.new(3,4,1.5)
    box.Adornee = hrp
    box.Color3 = color
    box.Transparency = 0.4
    box.ZIndex = 0
    box.AlwaysOnTop = true
    box.Parent = char
    return box
end

local function updateHighlights()
    clearHighlights()
    if not CONFIG.HIGHLIGHT_ENABLED then return end
    local murderer, sheriff = nil, nil
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr ~= Player then
            local char = plr.Character
            if char then
                local tool = char:FindFirstChildWhichIsA("Tool")
                if tool then
                    local name = tool.Name:lower()
                    if name:find("knife") or name:find("dagger") or name:find("blade") then
                        murderer = plr
                    elseif name:find("gun") or name:find("pistol") or name:find("revolver") then
                        sheriff = plr
                    end
                end
            end
        end
    end
    if murderer then
        local box = createHighlight(murderer, CONFIG.HIGHLIGHT_MURDERER)
        if box then highlights[murderer] = box end
    end
    if sheriff then
        local box = createHighlight(sheriff, CONFIG.HIGHLIGHT_SHERIFF)
        if box then highlights[sheriff] = box end
    end
    local function watchPlayer(plr)
        local task = {}
        task.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            if not plr or not plr.Character then return end
            if not highlights[plr] then
                local isMurderer = (plr == murderer)
                local isSheriff = (plr == sheriff)
                if isMurderer then
                    local box = createHighlight(plr, CONFIG.HIGHLIGHT_MURDERER)
                    if box then highlights[plr] = box end
                elseif isSheriff then
                    local box = createHighlight(plr, CONFIG.HIGHLIGHT_SHERIFF)
                    if box then highlights[plr] = box end
                end
            end
        end)
        table.insert(highlightTasks, task)
    end
    if murderer then watchPlayer(murderer) end
    if sheriff then watchPlayer(sheriff) end
end

-- ===== СОЗДАНИЕ GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlingMenu"
screenGui.Parent = Player.PlayerGui
screenGui.ResetOnSpawn = false

-- Главное окно
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 420, 0, 580)
mainFrame.Position = UDim2.new(0.5, -210, 0.5, -290)
mainFrame.BackgroundColor3 = CONFIG.GUI_BG_COLOR
mainFrame.BackgroundTransparency = CONFIG.GUI_BG_TRANSPARENCY
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local cornerMain = Instance.new("UICorner")
cornerMain.CornerRadius = UDim.new(0, 20)
cornerMain.Parent = mainFrame

-- Тень
local shadow = Instance.new("ImageLabel")
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -10)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://1316044259"
shadow.ImageColor3 = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 0.6
shadow.ZIndex = 0
shadow.Parent = mainFrame

-- Заголовок
local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,55)
header.Position = UDim2.new(0,0,0,0)
header.BackgroundColor3 = Color3.fromRGB(40,45,60)
header.BorderSizePixel = 0
header.Parent = mainFrame
local cornerHeader = Instance.new("UICorner")
cornerHeader.CornerRadius = UDim.new(0,20)
cornerHeader.Parent = header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.8,0,1,0)
title.Position = UDim2.new(0,10,0,0)
title.BackgroundTransparency = 1
title.Text = "✦ Fling Controller ✦"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = header

-- Кнопка закрытия скрипта (красный X)
local closeScriptBtn = Instance.new
