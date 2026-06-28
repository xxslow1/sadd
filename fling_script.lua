-- Fling Controller v11.5
-- Разделы меню в горизонтальной линии, как цвета
local Player = game.Players.LocalPlayer
local function getCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local Character = getCharacter()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
wait(0.5)

local CONFIG = {
    FLING_POWER = 63,
    FOLLOW_DISTANCE = 3,
    FLY_SPEED = 25,
    FLING_INTERVAL = 0.5,
    TARGET_NAME = "",
    ESP_ENABLED = false,
    ESP_COLOR_NORMAL = Color3.fromRGB(0,255,0),
    ESP_COLOR_MURDERER = Color3.fromRGB(255,0,0),
    ESP_COLOR_SHERIFF = Color3.fromRGB(0,0,255),
    ESP_COLOR_SELF = Color3.fromRGB(0,255,255),
    SELF_HITBOX_SIZE = 3,
    AIMBOT_ENABLED = true,
    AIMBOT_FOV = 45,
    AIMBOT_RADIUS = 100,
    SHERIFF_RADIUS = 100,
    FLYJUMP_ENABLED = false,
    FOV_CIRCLE_ENABLED = true,
    FOV_CIRCLE_RADIUS = 150,
    FOV_CIRCLE_COLOR = Color3.fromRGB(0,200,255),
    SHERIFF_WEAPON_LINE_ENABLED = true,
    SHERIFF_WEAPON_LINE_COLOR = Color3.fromRGB(255,200,0),
    BIND_FLING = Enum.KeyCode.F,
    BIND_FLYJUMP = Enum.KeyCode.G,
    BIND_AIMBOT = Enum.KeyCode.H,
    BIND_ESP = Enum.KeyCode.Z,
}

local TARGET = nil
local enabled = false
local flyjumpActive = false
local bv, gyro = nil, nil
local lastFling = 0
local heartbeatConnection = nil
local menuOpen = false
local espBoxes, roleBoxes = {}, {}
local selfHitbox = nil
local aimbotConnections = {}
local fovCircle = nil
local sheriffLine = nil
local keyBindMode = nil

-- ===== Переподключение при смене персонажа =====
local function refreshCharacter()
    Character = getCharacter()
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    if enabled and TARGET then flyUnder(TARGET) end
    startAimbot()
    updateSelfHitbox()
    updateFovCircle()
    updateSheriffWeaponLine()
end
Player.CharacterAdded:Connect(refreshCharacter)

-- ===== Основные функции =====
local function getTargetByName(name)
    if name and name ~= "" then return game.Players:FindFirstChild(name) end
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
    if root then root.Velocity = Vector3.new(0, CONFIG.FLING_POWER, 0) end
end

local function stopFlying()
    enabled = false
    flyjumpActive = false
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
    flyjumpActive = CONFIG.FLYJUMP_ENABLED
    lastFling = 0
    if statusLabel then statusLabel.Text = "Включено (цель: " .. target.Name .. ")"; statusLabel.TextColor3 = Color3.fromRGB(0,255,150) end
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
        local rot = CFrame.Angles(math.rad(90), 0, 0)
        RootPart.CFrame = CFrame.new(RootPart.Position) * rot
        if flyjumpActive then
            if tick() - lastFling > CONFIG.FLING_INTERVAL then
                flingTarget(target)
                lastFling = tick()
            end
        end
    end)
end

-- ===== Хитбокс себя =====
local function updateSelfHitbox()
    if selfHitbox then selfHitbox:Destroy(); selfHitbox = nil end
    if not RootPart then return end
    selfHitbox = Instance.new("BoxHandleAdornment")
    selfHitbox.Name = "SelfHitbox"
    selfHitbox.Size = Vector3.new(CONFIG.SELF_HITBOX_SIZE, CONFIG.SELF_HITBOX_SIZE, CONFIG.SELF_HITBOX_SIZE)
    selfHitbox.Adornee = RootPart
    selfHitbox.Color3 = CONFIG.ESP_COLOR_SELF
    selfHitbox.Transparency = 0.3
    selfHitbox.ZIndex = 0
    selfHitbox.AlwaysOnTop = true
    selfHitbox.Parent = RootPart
end

-- ===== ESP =====
local function clearESP()
    for plr, box in pairs(espBoxes) do if box and box.Parent then box:Destroy() end end
    espBoxes = {}
    for plr, box in pairs(roleBoxes) do if box and box.Parent then box:Destroy() end end
    roleBoxes = {}
end

local function createBox(player, color, name)
    if not player or not player.Character then return nil end
    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local old = char:FindFirstChild(name)
    if old then old:Destroy() end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = name
    box.Size = Vector3.new(3,4,1.5)
    box.Adornee = hrp
    box.Color3 = color
    box.Transparency = 0.3
    box.ZIndex = 0
    box.AlwaysOnTop = true
    box.Parent = char
    return box
end

local function updateESP()
    clearESP()
    if not CONFIG.ESP_ENABLED then return end
    local murderer, sheriff = nil, nil
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr ~= Player then
            local char = plr.Character
            if char then
                local tool = char:FindFirstChildWhichIsA("Tool")
                if tool then
                    local name = tool.Name:lower()
                    if name:find("knife") or name:find("dagger") or name:find("blade") then murderer = plr
                    elseif name:find("gun") or name:find("pistol") or name:find("revolver") then sheriff = plr end
                end
            end
        end
    end
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr ~= Player then
            local color = CONFIG.ESP_COLOR_NORMAL
            if plr == murderer then color = CONFIG.ESP_COLOR_MURDERER
            elseif plr == sheriff then color = CONFIG.ESP_COLOR_SHERIFF end
            local box = createBox(plr, color, "ESPBox")
            if box then espBoxes[plr] = box end
        end
    end
    updateSelfHitbox()
end
game.Players.PlayerAdded:Connect(updateESP)
game.Players.PlayerRemoving:Connect(updateESP)

-- ===== FOV круг =====
local function updateFovCircle()
    if fovCircle then fovCircle:Destroy(); fovCircle = nil end
    if not CONFIG.FOV_CIRCLE_ENABLED then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    fovCircle = Instance.new("Frame")
    fovCircle.Name = "FovCircle"
    fovCircle.Size = UDim2.new(0, CONFIG.FOV_CIRCLE_RADIUS*2, 0, CONFIG.FOV_CIRCLE_RADIUS*2)
    fovCircle.Position = UDim2.new(0.5, -CONFIG.FOV_CIRCLE_RADIUS, 0.5, -CONFIG.FOV_CIRCLE_RADIUS)
    fovCircle.BackgroundTransparency = 0.85
    fovCircle.BackgroundColor3 = CONFIG.FOV_CIRCLE_COLOR
    fovCircle.BorderSizePixel = 2
    fovCircle.BorderColor3 = CONFIG.FOV_CIRCLE_COLOR
    fovCircle.ZIndex = 999
    fovCircle.Parent = Player.PlayerGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1,0)
    corner.Parent = fovCircle
    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1, -4, 1, -4)
    inner.Position = UDim2.new(0, 2, 0, 2)
    inner.BackgroundTransparency = 0.95
    inner.BackgroundColor3 = CONFIG.FOV_CIRCLE_COLOR
    inner.BorderSizePixel = 0
    inner.Parent = fovCircle
    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(1,0)
    corner2.Parent = inner
end

-- ===== Линии к оружию шерифа =====
local function updateSheriffWeaponLine()
    if sheriffLine then
        if sheriffLine.line then sheriffLine.line:Destroy() end
        if sheriffLine.connection then sheriffLine.connection:Disconnect() end
        sheriffLine = nil
    end
    if not CONFIG.SHERIFF_WEAPON_LINE_ENABLED then return end
    local weapon = nil
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Tool") then
            local name = obj.Name:lower()
            if name:find("gun") or name:find("pistol") or name:find("revolver") then
                weapon = obj
                break
            end
        end
    end
    if not weapon then return end
    local line = Instance.new("Frame")
    line.Name = "SheriffWeaponLine"
    line.BackgroundColor3 = CONFIG.SHERIFF_WEAPON_LINE_COLOR
    line.BorderSizePixel = 0
    line.Size = UDim2.new(0, 2, 0, 0)
    line.ZIndex = 998
    line.Parent = Player.PlayerGui
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        if not CONFIG.SHERIFF_WEAPON_LINE_ENABLED or not weapon or not weapon.Parent then
            if line then line:Destroy() end
            if conn then conn:Disconnect() end
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local weaponPos = weapon.Position
        local screenPos, onScreen = camera:WorldToViewportPoint(weaponPos)
        if not onScreen then return end
        local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
        local lineLength = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        local angle = math.atan2(screenPos.Y - center.Y, screenPos.X - center.X)
        line.Size = UDim2.new(0, 2, 0, lineLength)
        line.Position = UDim2.new(0.5, 0, 0.5, 0)
        line.Rotation = math.deg(angle)
        line.BackgroundColor3 = CONFIG.SHERIFF_WEAPON_LINE_COLOR
    end)
    sheriffLine = {line = line, connection = conn}
end

-- ===== Аимбот =====
local VirtualUser = game:GetService("VirtualUser")
local function getAimbotTarget(weapon, isMurderer, isSheriff)
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local cameraPos = camera.CFrame.Position
    local cameraDir = camera.CFrame.LookVector
    local bestScore = math.huge
    local bestTarget = nil
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr == Player then continue end
        if not plr.Character then continue end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local isTargetMurderer, isTargetSheriff = false, false
        local tool = plr.Character:FindFirstChildWhichIsA("Tool")
        if tool then
            local name = tool.Name:lower()
            if name:find("knife") or name:find("dagger") or name:find("blade") then isTargetMurderer = true end
            if name:find("gun") or name:find("pistol") or name:find("revolver") then isTargetSheriff = true end
        end
        if isMurderer then
            if isTargetSheriff or isTargetMurderer then continue end
        elseif isSheriff then
            if not isTargetMurderer then continue end
            local dist = (hrp.Position - cameraPos).Magnitude
            if dist > CONFIG.SHERIFF_RADIUS then continue end
        else
            continue
        end
        local dist = (hrp.Position - cameraPos).Magnitude
        if dist > CONFIG.AIMBOT_RADIUS then continue end
        local toTarget = (hrp.Position - cameraPos).Unit
        local angle = math.deg(math.acos(cameraDir:Dot(toTarget)))
        if angle > CONFIG.AIMBOT_FOV then continue end
        local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end
        local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
        local offset = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if offset < bestScore then bestScore = offset; bestTarget = plr end
    end
    return bestTarget
end

local function startAimbot()
    for _, conn in ipairs(aimbotConnections) do
        if conn and conn.heartbeat then conn.heartbeat:Disconnect() end
    end
    aimbotConnections = {}
    if not CONFIG.AIMBOT_ENABLED then return end
    local function onWeaponEquipped(tool)
        if not tool then return end
        local toolName = tool.Name:lower()
        local isMurderer = toolName:find("knife") or toolName:find("dagger") or toolName:find("blade")
        local isSheriff = toolName:find("gun") or toolName:find("pistol") or toolName:find("revolver")
        if not isMurderer and not isSheriff then return end
        local conn
        conn = game:GetService("RunService").Heartbeat:Connect(function()
            if not enabled then return end
            local target = getAimbotTarget(tool, isMurderer, isSheriff)
            if target and target.Character then
                local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp then
                    local camera = workspace.CurrentCamera
                    if camera then
                        camera.CFrame = CFrame.new(camera.CFrame.Position, targetHrp.Position)
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new(0,0), camera.CFrame.Position)
                    end
                end
            end
        end)
        table.insert(aimbotConnections, {heartbeat = conn})
    end
    Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then onWeaponEquipped(child) end
    end)
    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") then onWeaponEquipped(tool) end
    end
end
startAimbot()

-- ===== Биндинг клавиш =====
local function updateBindings()
    local inputService = game:GetService("UserInputService")
    inputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if keyBindMode then
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                if keyBindMode == "FLING" then CONFIG.BIND_FLING = input.KeyCode
                elseif keyBindMode == "FLYJUMP" then CONFIG.BIND_FLYJUMP = input.KeyCode
                elseif keyBindMode == "AIMBOT" then CONFIG.BIND_AIMBOT = input.KeyCode
                elseif keyBindMode == "ESP" then CONFIG.BIND_ESP = input.KeyCode end
                keyBindMode = nil
                statusLabel.Text = "Клавиша назначена!"
                statusLabel.TextColor3 = Color3.fromRGB(0,255,0)
                wait(1)
                if enabled then
                    statusLabel.Text = "Включено (цель: " .. (TARGET and TARGET.Name or "?") .. ")"
                    statusLabel.TextColor3 = Color3.fromRGB(0,255,150)
                else
                    statusLabel.Text = "Выключено"
                    statusLabel.TextColor3 = Color3.fromRGB(255,70,70)
                end
            end
            return
        end
        if input.KeyCode == CONFIG.BIND_FLING then
            toggleBtn.MouseButton1Click:Fire()
        elseif input.KeyCode == CONFIG.BIND_FLYJUMP then
            if flyjumpBtn then flyjumpBtn.MouseButton1Click:Fire() end
        elseif input.KeyCode == CONFIG.BIND_AIMBOT then
            if aimbotToggle then aimbotToggle.MouseButton1Click:Fire() end
        elseif input.KeyCode == CONFIG.BIND_ESP then
            if espToggle then espToggle.MouseButton1Click:Fire() end
        end
    end)
end
updateBindings()

-- ===== GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlingMenu"
screenGui.Parent = Player.PlayerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 520, 0, 780)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -390)
mainFrame.BackgroundColor3 = Color3.fromRGB(20,22,30)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local cornerMain = Instance.new("UICorner")
cornerMain.CornerRadius = UDim.new(0, 25)
cornerMain.Parent = mainFrame

-- Градиентный фон
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60,0,100)),
    ColorSequenceKeypoint.new(0.3, Color3.fromRGB(0,100,200)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(200,0,150)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0,200,100))
}
bgGradient.Rotation = 0
bgGradient.Parent = mainFrame
local gradAngle = 0
game:GetService("RunService").Heartbeat:Connect(function()
    if not mainFrame.Visible then return end
    gradAngle = gradAngle + 0.2
    bgGradient.Rotation = gradAngle % 360
end)

-- Тень
local shadow = Instance.new("ImageLabel")
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -15)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://1316044259"
shadow.ImageColor3 = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 0.5
shadow.ZIndex = 0
shadow.Parent = mainFrame

-- Заголовок
local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,60)
header.Position = UDim2.new(0,0,0,0)
header.BackgroundColor3 = Color3.fromRGB(30,35,50)
header.BackgroundTransparency = 0.2
header.BorderSizePixel = 0
header.Parent = mainFrame
local cornerHeader = Instance.new("UICorner")
cornerHeader.CornerRadius = UDim.new(0,25)
cornerHeader.Parent = header
local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,150)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255,200,0))
}
headerGrad.Rotation = 45
headerGrad.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.8,0,1,0)
title.Position = UDim2.new(0,15,0,0)
title.BackgroundTransparency = 1
title.Text = "✦ Fling Controller ✦"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = header

local closeScriptBtn = Instance.new("TextButton")
closeScriptBtn.Size = UDim2.new(0,40,0,40)
closeScriptBtn.Position = UDim2.new(1,-50,0,10)
closeScriptBtn.BackgroundColor3 = Color3.fromRGB(200,30,30)
closeScriptBtn.Text = "✕"
closeScriptBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeScriptBtn.TextScaled = true
closeScriptBtn.Font = Enum.Font.GothamBold
closeScriptBtn.BorderSizePixel = 0
closeScriptBtn.Parent = mainFrame
local cornerCS = Instance.new("UICorner")
cornerCS.CornerRadius = UDim.new(0,12)
cornerCS.Parent = closeScriptBtn
closeScriptBtn.MouseButton1Click:Connect(function()
    stopFlying()
    clearESP()
    if fovCircle then fovCircle:Destroy() end
    if sheriffLine then sheriffLine.line:Destroy(); sheriffLine.connection:Disconnect() end
    screenGui:Destroy()
    print("Скрипт остановлен.")
end)

-- Палитра цветов фона
local paletteFrame = Instance.new("Frame")
paletteFrame.Size = UDim2.new(1,0,0,35)
paletteFrame.Position = UDim2.new(0,0,0,65)
paletteFrame.BackgroundTransparency = 1
paletteFrame.Parent = mainFrame
local colors = {
    Color3.fromRGB(15,15,20), Color3.fromRGB(50,55,65),
    Color3.fromRGB(20,40,25), Color3.fromRGB(25,60,55),
    Color3.fromRGB(60,45,20), Color3.fromRGB(40,40,45),
    Color3.fromRGB(80,20,30), Color3.fromRGB(20,30,60),
    Color3.fromRGB(0,150,200), Color3.fromRGB(200,100,0),
    Color3.fromRGB(150,0,150), Color3.fromRGB(30,150,100),
    Color3.fromRGB(255,105,180), Color3.fromRGB(255,255,255)
}
for i, color in ipairs(colors) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.06,0,1,0)
    btn.Position = UDim2.new(0.02 + (i-1)*0.07, 0, 0, 0)
    btn.BackgroundColor3 = color
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = paletteFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,5)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(function()
        mainFrame.BackgroundColor3 = color
        mainFrame.BackgroundTransparency = 0.15
        bgGradient.Enabled = false
    end)
end

-- ===== Горизонтальные вкладки (разделы) =====
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1,0,0,35)
tabContainer.Position = UDim2.new(0,0,0,105)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabs = {"Fling", "ESP", "Хитбокс", "FOV", "Линии", "Аимбот", "Бинды"}
local tabButtons = {}
local contentFrames = {}
local currentTab = nil

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.12,0,1,0)
    btn.Position = UDim2.new(0.02 + (i-1)*0.13, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40,45,60)
    btn.Text = tabName
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.BorderSizePixel = 0
    btn.Parent = tabContainer
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,8)
    corner.Parent = btn
    tabButtons[tabName] = btn

    -- Контейнер для содержимого вкладки
    local content = Instance.new("Frame")
    content.Size = UDim2.new(0.9,0,0,0)
    content.Position = UDim2.new(0.05,0,0,145)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = mainFrame
    contentFrames[tabName] = content

    btn.MouseButton1Click:Connect(function()
        -- Скрыть все контейнеры
        for _, frame in pairs(contentFrames) do
            frame.Visible = false
        end
        -- Показать выбранный
        content.Visible = true
        -- Обновить внешний вид кнопок
        for name, button in pairs(tabButtons) do
            if name == tabName then
                button.BackgroundColor3 = Color3.fromRGB(60,70,100)
            else
                button.BackgroundColor3 = Color3.fromRGB(40,45,60)
            end
        end
        currentTab = tabName
        -- Пересчитать высоту контента
        local totalHeight = 0
        for _, child in ipairs(content:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                totalHeight = totalHeight + child.Size.Y.Offset + 4
            end
        end
        content.Size = UDim2.new(0.9,0,0,totalHeight)
    end)
end

-- Автоматически открыть первую вкладку
if #tabs > 0 then
    tabButtons[tabs[1]].MouseButton1Click:Fire()
end

-- ===== Функции для создания элементов внутри вкладок =====
local function createSliderInTab(parent, labelText, yPos, minVal, maxVal, step, getter, setter)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6,0,0,22)
    label.Position = UDim2.new(0.05,0,0,yPos)
    label.BackgroundTransparency = 1
    label.Text = labelText .. getter()
    label.TextColor3 = Color3.fromRGB(200,200,220)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = parent

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(0.8,0,0,12)
    sliderFrame.Position = UDim2.new(0.1,0,0,yPos+25)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(50,55,70)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = parent
    local cornerSlider = Instance.new("UICorner")
    cornerSlider.CornerRadius = UDim.new(0,6)
    cornerSlider.Parent = sliderFrame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5,0,1,0)
    fill.Position = UDim2.new(0,0,0,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,180,255)
    fill.BorderSizePixel = 0
    fill.Parent = sliderFrame
    local cornerFill = Instance.new("UICorner")
    cornerFill.CornerRadius = UDim.new(0,6)
    cornerFill.Parent = fill

    local leftBtn = Instance.new("TextButton")
    leftBtn.Size = UDim2.new(0.1,0,1.6,0)
    leftBtn.Position = UDim2.new(-0.12,0,-0.3,0)
    leftBtn.BackgroundColor3 = Color3.fromRGB(60,65,85)
    leftBtn.Text = "◀"
    leftBtn.TextColor3 = Color3.fromRGB(255,255,255)
    leftBtn.TextScaled = true
    leftBtn.Font = Enum.Font.Gotham
    leftBtn.BorderSizePixel = 0
    leftBtn.Parent = sliderFrame
    local cornerLeft = Instance.new("UICorner")
    cornerLeft.CornerRadius = UDim.new(0,8)
    cornerLeft.Parent = leftBtn

    local rightBtn = Instance.new("TextButton")
    rightBtn.Size = UDim2.new(0.1,0,1.6,0)
    rightBtn.Position = UDim2.new(1.02,0,-0.3,0)
    rightBtn.BackgroundColor3 = Color3.fromRGB(60,65,85)
    rightBtn.Text = "▶"
    rightBtn.TextColor3 = Color3.fromRGB(255,255,255)
    rightBtn.TextScaled = true
    rightBtn.Font = Enum.Font.Gotham
    rightBtn.BorderSizePixel = 0
    rightBtn.Parent = sliderFrame
    local cornerRight = Instance.new("UICorner")
    cornerRight.CornerRadius = UDim.new(0,8)
    cornerRight.Parent = rightBtn

    local function update()
        local val = getter()
        local norm = (val - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(math.clamp(norm,0,1),0,1,0)
        label.Text = labelText .. val
    end

    leftBtn.MouseButton1Click:Connect(function()
        local newVal = math.max(minVal, getter() - step)
        setter(newVal); update()
    end)
    rightBtn.MouseButton1Click:Connect(function()
        local newVal = math.min(maxVal, getter() + step)
        setter(newVal); update()
    end)
    update()
    return label
end

local function createToggleInTab(parent, labelText, yPos, getter, setter)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.8,0,0,30)
    btn.Position = UDim2.new(0.1,0,0,yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50,55,70)
    btn.Text = labelText .. (getter() and "Вкл" or "Выкл")
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,8)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.Text = labelText .. (getter() and "Вкл" or "Выкл")
        if labelText:find("FOV") then updateFovCircle()
        elseif labelText:find("Линии") then updateSheriffWeaponLine()
        elseif labelText:find("Хитбокс") then updateSelfHitbox()
        elseif labelText:find("ESP") then updateESP()
        elseif labelText:find("Аимбот") then startAimbot()
        elseif labelText:find("Flyjump") then
            CONFIG.FLYJUMP_ENABLED = getter()
            if enabled then flyjumpActive = CONFIG.FLYJUMP_ENABLED end
        end
    end)
    return btn
end

local function createColorPickerInTab(parent, labelText, yPos, getter, setter)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4,0,0,22)
    label.Position = UDim2.new(0.05,0,0,yPos)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200,200,220)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.08,0,0,20)
    btn.Position = UDim2.new(0.5,0,0,yPos+1)
    btn.BackgroundColor3 = getter()
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,5)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(function()
        local colors = {Color3.fromRGB(255,0,0), Color3.fromRGB(0,255,0), Color3.fromRGB(0,0,255), Color3.fromRGB(255,255,0), Color3.fromRGB(255,0,255), Color3.fromRGB(0,255,255), Color3.fromRGB(255,255,255)}
        for i, c in ipairs(colors) do
            if c == getter() then
                setter(colors[i % #colors + 1])
                break
            end
        end
        btn.BackgroundColor3 = getter()
        updateESP()
    end)
    return btn
end

local function createKeyBindInTab(parent, labelText, yPos, bindKey)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4,0,0,22)
    label.Position = UDim2.new(0.05,0,0,yPos)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200,200,220)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.3,0,0,25)
    btn.Position = UDim2.new(0.5,0,0,yPos)
    btn.BackgroundColor3 = Color3.fromRGB(60,65,85)
    btn.Text = tostring(bindKey):gsub("Enum.KeyCode.", "")
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,8)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(function()
        keyBindMode = labelText:gsub(": ", "")
        statusLabel.Text = "Нажмите клавишу для " .. labelText
        statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
        btn.Text = "..."
    end)
end

-- ===== Заполнение вкладок =====
-- Вкладка Fling
local flingContent = contentFrames["Fling"]
createSliderInTab(flingContent, "Сила: ", 0, 10, 500, 5, function() return CONFIG.FLING_POWER end, function(v) CONFIG.FLING_POWER = v end)
createSliderInTab(flingContent, "Дистанция: ", 35, 0.5, 10, 0.5, function() return CONFIG.FOLLOW_DISTANCE end, function(v) CONFIG.FOLLOW_DISTANCE = v end)
createSliderInTab(flingContent, "Интервал: ", 70, 0.1, 2, 0.1, function() return CONFIG.FLING_INTERVAL end, function(v) CONFIG.FLING_INTERVAL = v end)
createSliderInTab(flingContent, "Скорость Fly: ", 105, 1, 50, 0.5, function() return CONFIG.FLY_SPEED end, function(v) CONFIG.FLY_SPEED = v end)
createKeyBindInTab(flingContent, "Бинд Fling: ", 140, CONFIG.BIND_FLING)
createToggleInTab(flingContent, "Flyjump: ", 175, function() return CONFIG.FLYJUMP_ENABLED end, function(v) CONFIG.FLYJUMP_ENABLED = v end)

-- Вкладка ESP
local espContent = contentFrames["ESP"]
createToggleInTab(espContent, "ESP: ", 0, function() return CONFIG.ESP_ENABLED end, function(v) CONFIG.ESP_ENABLED = v end)
createColorPickerInTab(espContent, "Обычные: ", 35, function() return CONFIG.ESP_COLOR_NORMAL end, function(v) CONFIG.ESP_COLOR_NORMAL = v end)
createColorPickerInTab(espContent, "Убийца: ", 65, function() return CONFIG.ESP_COLOR_MURDERER end, function(v) CONFIG.ESP_COLOR_MURDERER = v end)
createColorPickerInTab(espContent, "Шериф: ", 95, function() return CONFIG.ESP_COLOR_SHERIFF end, function(v) CONFIG.ESP_COLOR_SHERIFF = v end)
createColorPickerInTab(espContent, "Свой: ", 125, function() return CONFIG.ESP_COLOR_SELF end, function(v) CONFIG.ESP_COLOR_SELF = v end)
createKeyBindInTab(espContent, "Бинд ESP: ", 155, CONFIG.BIND_ESP)

-- Вкладка Хитбокс
local hitboxContent = contentFrames["Хитбокс"]
createSliderInTab(hitboxContent, "Размер: ", 0, 1, 10, 0.5, function() return CONFIG.SELF_HITBOX_SIZE end, function(v) CONFIG.SELF_HITBOX_SIZE = v end)
createToggleInTab(hitboxContent, "Хитбокс: ", 35, function() return CONFIG.ESP_ENABLED end, function(v) CONFIG.ESP_ENABLED = v end)  -- используем ESP как триггер

-- Вкладка FOV
local fovContent = contentFrames["FOV"]
createToggleInTab(fovContent, "FOV круг: ", 0, function() return CONFIG.FOV_CIRCLE_ENABLED end, function(v) CONFIG.FOV_CIRCLE_ENABLED = v end)
createSliderInTab(fovContent, "Радиус круга: ", 35, 50, 300, 5, function() return CONFIG.FOV_CIRCLE_RADIUS end, function(v) CONFIG.FOV_CIRCLE_RADIUS = v end)
createColorPickerInTab(fovContent, "Цвет круга: ", 70, function() return CONFIG.FOV_CIRCLE_COLOR end, function(v) CONFIG.FOV_CIRCLE_COLOR = v end)

-- Вкладка Линии
local sheriffContent = contentFrames["Линии"]
createToggleInTab(sheriffContent, "Линии: ", 0, function() return CONFIG.SHERIFF_WEAPON_LINE_ENABLED end, function(v) CONFIG.SHERIFF_WEAPON_LINE_ENABLED = v end)
createColorPickerInTab(sheriffContent, "Цвет линии: ", 35, function() return CONFIG.SHERIFF_WEAPON_LINE_COLOR end, function(v) CONFIG.SHERIFF_WEAPON_LINE_COLOR = v end)

-- Вкладка Аимбот
local aimbotContent = contentFrames["Аимбот"]
createToggleInTab(aimbotContent, "Аимбот: ", 0, function() return CONFIG.AIMBOT_ENABLED end, function(v) CONFIG.AIMBOT_ENABLED = v end)
createSliderInTab(aimbotContent, "FOV: ", 35, 5, 180, 5, function() return CONFIG.AIMBOT_FOV end, function(v) CONFIG.AIMBOT_FOV = v end)
createSliderInTab(aimbotContent, "Радиус: ", 70, 10, 500, 10, function() return CONFIG.AIMBOT_RADIUS end, function(v) CONFIG.AIMBOT_RADIUS = v end)
createSliderInTab(aimbotContent, "Радиус шерифа: ", 105, 10, 500, 10, function() return CONFIG.SHERIFF_RADIUS end, function(v) CONFIG.SHERIFF_RADIUS = v end)
createKeyBindInTab(aimbotContent, "Бинд Аимбот: ", 140, CONFIG.BIND_AIMBOT)

-- Вкладка Бинды
local bindContent = contentFrames["Бинды"]
createKeyBindInTab(bindContent, "Бинд Flyjump: ", 0, CONFIG.BIND_FLYJUMP)
-- можно добавить другие бинды

-- ===== Статус и кнопка включения (размещены над вкладками) =====
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,0,0,30)
statusLabel.Position = UDim2.new(0,0,0,75)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Выключено"
statusLabel.TextColor3 = Color3.fromRGB(255,70,70)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.Parent = mainFrame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.8,0,0,35)
toggleBtn.Position = UDim2.new(0.1,0,0,110) -- чуть ниже статуса
toggleBtn.BackgroundColor3 = Color3.fromRGB(60,70,100)
toggleBtn.Text = "▶ Включить"
toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
toggleBtn.TextScaled = true
toggleBtn.Font = Enum.Font.Gotham
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = mainFrame
local cornerBtn = Instance.new("UICorner")
cornerBtn.CornerRadius = UDim.new(0,12)
cornerBtn.Parent = toggleBtn
toggleBtn.MouseEnter:Connect(function() toggleBtn.BackgroundColor3 = Color3.fromRGB(80,90,130) end)
toggleBtn.MouseLeave:Connect(function() toggleBtn.BackgroundColor3 = Color3.fromRGB(60,70,100) end)
toggleBtn.MouseButton1Click:Connect(function()
    if enabled then
        stopFlying()
        toggleBtn.Text = "▶ Включить"
    else
        local target = getTarget()
        if target then
            flyUnder(target)
            toggleBtn.Text = "⏹ Выключить"
        else
            statusLabel.Text = "Нет игроков!"
            statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
        end
    end
end)

-- Кнопка выбора цели (отдельное окно слева)
local playerListBtn = Instance.new("TextButton")
playerListBtn.Size = UDim2.new(0.8,0,0,30)
playerListBtn.Position = UDim2.new(0.1,0,0,150) -- под вкладками
playerListBtn.BackgroundColor3 = Color3.fromRGB(50,55,70)
playerListBtn.Text = "Выбрать цель: " .. (CONFIG.TARGET_NAME ~= "" and CONFIG.TARGET_NAME or "авто")
playerListBtn.TextColor3 = Color3.fromRGB(255,255,255)
playerListBtn.TextScaled = true
playerListBtn.Font = Enum.Font.Gotham
playerListBtn.BorderSizePixel = 0
playerListBtn.Parent = mainFrame
local cornerPL = Instance.new("UICorner")
cornerPL.CornerRadius = UDim.new(0,10)
cornerPL.Parent = playerListBtn

-- Окно списка игроков (слева, перетаскиваемое)
local playerListFrame = Instance.new("Frame")
playerListFrame.Size = UDim2.new(0, 200, 0, 300)
playerListFrame.Position = UDim2.new(0.02, 0, 0.1, 0)
playerListFrame.BackgroundColor3 = Color3.fromRGB(30,35,45)
playerListFrame.BackgroundTransparency = 0.2
playerListFrame.BorderSizePixel = 0
playerListFrame.Visible = false
playerListFrame.Active = true
playerListFrame.Draggable = true
playerListFrame.Parent = screenGui
local cornerPLF = Instance.new("UICorner")
cornerPLF.CornerRadius = UDim.new(0,12)
cornerPLF.Parent = playerListFrame
local plTitle = Instance.new("TextLabel")
plTitle.Size = UDim2.new(1,0,0,30)
plTitle.Position = UDim2.new(0,0,0,0)
plTitle.BackgroundColor3 = Color3.fromRGB(40,45,60)
plTitle.Text = "Игроки"
plTitle.TextColor3 = Color3.fromRGB(255,255,255)
plTitle.TextScaled = true
plTitle.Font = Enum.Font.GothamBold
plTitle.Parent = playerListFrame
local cornerPLT = Instance.new("UICorner")
cornerPLT.CornerRadius = UDim.new(0,12)
cornerPLT.Parent = plTitle
local plScrolling = Instance.new("ScrollingFrame")
plScrolling.Size = UDim2.new(1,0,1,-30)
plScrolling.Position = UDim2.new(0,0,0,30)
plScrolling.BackgroundTransparency = 1
plScrolling.CanvasSize = UDim2.new(0,0,0,0)
plScrolling.ScrollBarThickness = 8
plScrolling.Parent = playerListFrame
local plLayout = Instance.new("UIListLayout")
plLayout.Padding = UDim.new(0,4)
plLayout.SortOrder = Enum.SortOrder.Name
plLayout.Parent = plScrolling
local function updatePlayerListWindow()
    for _, child in ipairs(plScrolling:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    local ySize = 0
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr ~= Player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1,0,0,25)
            btn.BackgroundColor3 = Color3.fromRGB(60,65,85)
            btn.Text = plr.Name
            btn.TextColor3 = Color3.fromRGB(255,255,255)
            btn.TextScaled = true
            btn.Font = Enum.Font.Gotham
            btn.BorderSizePixel = 0
            btn.Parent = plScrolling
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0,6)
            corner.Parent = btn
            btn.MouseButton1Click:Connect(function()
                CONFIG.TARGET_NAME = plr.Name
                playerListBtn.Text = "Выбрать цель: " .. plr.Name
                playerListFrame.Visible = false
                if enabled then
                    local newTarget = getTarget()
                    if newTarget then flyUnder(newTarget)
                    else stopFlying(); statusLabel.Text = "Цель не найдена!"; statusLabel.TextColor3 = Color3.fromRGB(255,0,0) end
                end
            end)
            ySize = ySize + 25 + 4
        end
    end
    plScrolling.CanvasSize = UDim2.new(0,0,0,ySize)
end
playerListBtn.MouseButton1Click:Connect(function()
    playerListFrame.Visible = not playerListFrame.Visible
    if playerListFrame.Visible then updatePlayerListWindow() end
end)

-- ===== Открытие меню по правому Shift =====
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        menuOpen = not menuOpen
        mainFrame.Visible = menuOpen
        if menuOpen then
            if enabled then
                statusLabel.Text = "Включено (цель: " .. (TARGET and TARGET.Name or "?") .. ")"
                statusLabel.TextColor3 = Color3.fromRGB(0,255,150)
            else
                statusLabel.Text = "Выключено"
                statusLabel.TextColor3 = Color3.fromRGB(255,70,70)
            end
            updateESP()
            updateFovCircle()
            updateSheriffWeaponLine()
        end
    end
end)

print("Скрипт загружен. Правый Shift для меню.")
