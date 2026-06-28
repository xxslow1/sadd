-- Fling Controller v5.0
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
wait(0.5)

local CONFIG = {
    FLING_POWER = 150,
    FOLLOW_DISTANCE = 3,
    FLY_SPEED = 8,
    FLING_INTERVAL = 0.5,
    GUI_BG_COLOR = Color3.fromRGB(20,22,30),
    GUI_BG_TRANSPARENCY = 0.08,
    GUI_ACCENT = Color3.fromRGB(0,180,255),
    TARGET_NAME = "",
    ESP_ENABLED = false,
    ESP_COLOR = Color3.fromRGB(0,255,0),
    HIGHLIGHT_MURDERER = Color3.fromRGB(255,0,0),
    HIGHLIGHT_SHERIFF = Color3.fromRGB(0,0,255),
    AIMBOT_ENABLED = true,
    AIMBOT_FOV = 45,
    AIMBOT_RADIUS = 100,
    SHERIFF_RADIUS = 100,
}

local TARGET = nil
local enabled = false
local bv, gyro = nil, nil
local lastFling = 0
local heartbeatConnection = nil
local menuOpen = false
local espBoxes, roleBoxes = {}, {}
local aimbotConnections = {}

-- ===== Вспомогательные функции =====
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

        local rot = CFrame.Angles(math.rad(90), 0, 0)
        RootPart.CFrame = CFrame.new(RootPart.Position) * rot

        if tick() - lastFling > CONFIG.FLING_INTERVAL then
            flingTarget(target)
            lastFling = tick()
        end
    end)
end

-- ===== ESP и выделение ролей =====
local function clearESP()
    for plr, box in pairs(espBoxes) do if box and box.Parent then box:Destroy() end end
    espBoxes = {}
    for plr, box in pairs(roleBoxes) do if box and box.Parent then box:Destroy() end end
    roleBoxes = {}
end

local function createBox(player, color, isESP)
    if not player or not player.Character then return nil end
    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local old = char:FindFirstChild(isESP and "ESPBox" or "RoleBox")
    if old then old:Destroy() end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = isESP and "ESPBox" or "RoleBox"
    box.Size = Vector3.new(3,4,1.5)
    box.Adornee = hrp
    box.Color3 = color
    box.Transparency = isESP and 0.3 or 0.4
    box.ZIndex = 0
    box.AlwaysOnTop = true
    box.Parent = char
    return box
end

local function updateESP()
    clearESP()
    if CONFIG.ESP_ENABLED then
        for _, plr in ipairs(game.Players:GetPlayers()) do
            if plr ~= Player then
                local box = createBox(plr, CONFIG.ESP_COLOR, true)
                if box then espBoxes[plr] = box end
            end
        end
    end
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
        local box = createBox(murderer, CONFIG.HIGHLIGHT_MURDERER, false)
        if box then roleBoxes[murderer] = box end
    end
    if sheriff then
        local box = createBox(sheriff, CONFIG.HIGHLIGHT_SHERIFF, false)
        if box then roleBoxes[sheriff] = box end
    end
end

game.Players.PlayerAdded:Connect(updateESP)
game.Players.PlayerRemoving:Connect(updateESP)

-- ===== Аимбот =====
local function getAimbotTarget(weapon, isMurderer, isSheriff)
    local camera = workspace.CurrentCamera
    local cameraPos = camera.CFrame.Position
    local cameraDir = camera.CFrame.LookVector

    local bestScore = math.huge
    local bestTarget = nil

    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr == Player then continue end
        if not plr.Character then continue end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local isTargetMurderer = false
        local isTargetSheriff = false
        local tool = plr.Character:FindFirstChildWhichIsA("Tool")
        if tool then
            local name = tool.Name:lower()
            if name:find("knife") or name:find("dagger") or name:find("blade") then isTargetMurderer = true end
            if name:find("gun") or name:find("pistol") or name:find("revolver") then isTargetSheriff = true end
        end

        if isMurderer then
            if isTargetSheriff then continue end
            if isTargetMurderer then continue end
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
        if offset < bestScore then
            bestScore = offset
            bestTarget = plr
        end
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
                    camera.CFrame = CFrame.new(camera.CFrame.Position, targetHrp.Position)
                end
            end
        end)
        table.insert(aimbotConnections, {heartbeat = conn})
    end

    Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            onWeaponEquipped(child)
        end
    end)

    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") then
            onWeaponEquipped(tool)
        end
    end
end

startAimbot()

-- ===== GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlingMenu"
screenGui.Parent = Player.PlayerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 460, 0, 700)
mainFrame.Position = UDim2.new(0.5, -230, 0.5, -350)
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

-- Кнопка закрытия скрипта
local closeScriptBtn = Instance.new("TextButton")
closeScriptBtn.Size = UDim2.new(0,35,0,35)
closeScriptBtn.Position = UDim2.new(1,-45,0,10)
closeScriptBtn.BackgroundColor3 = Color3.fromRGB(200,30,30)
closeScriptBtn.Text = "✕"
closeScriptBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeScriptBtn.TextScaled = true
closeScriptBtn.Font = Enum.Font.GothamBold
closeScriptBtn.BorderSizePixel = 0
closeScriptBtn.Parent = mainFrame
local cornerCS = Instance.new("UICorner")
cornerCS.CornerRadius = UDim.new(0,10)
cornerCS.Parent = closeScriptBtn
closeScriptBtn.MouseButton1Click:Connect(function()
    stopFlying()
    clearESP()
    screenGui:Destroy()
    print("Скрипт остановлен.")
end)

-- Палитра цветов (сверху, под заголовком)
local paletteFrame = Instance.new("Frame")
paletteFrame.Size = UDim2.new(1,0,0,30)
paletteFrame.Position = UDim2.new(0,0,0,60)
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
        local oldGrad = mainFrame:FindFirstChildWhichIsA("UIGradient")
        if oldGrad then oldGrad:Destroy() end
        mainFrame.BackgroundColor3 = color
        mainFrame.BackgroundTransparency = CONFIG.GUI_BG_TRANSPARENCY
        CONFIG.GUI_BG_COLOR = color
    end)
end

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,0,0,25)
statusLabel.Position = UDim2.new(0,0,0,95)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Выключено"
statusLabel.TextColor3 = Color3.fromRGB(255,70,70)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.Parent = mainFrame

-- Кнопка включения
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.8,0,0,40)
toggleBtn.Position = UDim2.new(0.1,0,0,125)
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

-- Выбор цели
local playerListBtn = Instance.new("TextButton")
playerListBtn.Size = UDim2.new(0.8,0,0,30)
playerListBtn.Position = UDim2.new(0.1,0,0,175)
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

local playerListFrame = Instance.new("Frame")
playerListFrame.Size = UDim2.new(0.8,0,0,120)
playerListFrame.Position = UDim2.new(0.1,0,0,210)
playerListFrame.BackgroundColor3 = Color3.fromRGB(40,45,60)
playerListFrame.BackgroundTransparency = 0.2
playerListFrame.BorderSizePixel = 0
playerListFrame.Visible = false
playerListFrame.Parent = mainFrame
local cornerPLF = Instance.new("UICorner")
cornerPLF.CornerRadius = UDim.new(0,10)
cornerPLF.Parent = playerListFrame

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1,0,1,0)
scrollingFrame.Position = UDim2.new(0,0,0,0)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.CanvasSize = UDim2.new(0,0,0,0)
scrollingFrame.ScrollBarThickness = 8
scrollingFrame.Parent = playerListFrame

local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Padding = UDim.new(0,4)
playerListLayout.SortOrder = Enum.SortOrder.Name
playerListLayout.Parent = scrollingFrame

local function updatePlayerList()
    for _, child in ipairs(scrollingFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
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
            btn.Parent = scrollingFrame
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0,6)
            corner.Parent = btn
            btn.MouseButton1Click:Connect(function()
                CONFIG.TARGET_NAME = plr.Name
                playerListBtn.Text = "Выбрать цель: " .. plr.Name
                playerListFrame.Visible = false
                if enabled then
                    local newTarget = getTarget()
                    if newTarget then
                        flyUnder(newTarget)
                    else
                        stopFlying()
                        statusLabel.Text = "Цель не найдена!"
                        statusLabel.TextColor3 = Color3.fromRGB(255,0,0)
                    end
                end
            end)
            ySize = ySize + 25 + 4
        end
    end
    scrollingFrame.CanvasSize = UDim2.new(0,0,0,ySize)
end

playerListBtn.MouseButton1Click:Connect(function()
    playerListFrame.Visible = not playerListFrame.Visible
    if playerListFrame.Visible then updatePlayerList() end
end)

-- Слайдеры
local function createSlider(labelText, yPos, minVal, maxVal, step, getter, setter)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.8,0,0,22)
    label.Position = UDim2.new(0.1,0,0,yPos)
    label.BackgroundTransparency = 1
    label.Text = labelText .. getter()
    label.TextColor3 = Color3.fromRGB(200,200,220)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = mainFrame

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(0.8,0,0,12)
    sliderFrame.Position = UDim2.new(0.1,0,0,yPos+25)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(50,55,70)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = mainFrame
    local cornerSlider = Instance.new("UICorner")
    cornerSlider.CornerRadius = UDim.new(0,6)
    cornerSlider.Parent = sliderFrame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5,0,1,0)
    fill.Position = UDim2.new(0,0,0,0)
    fill.BackgroundColor3 = CONFIG.GUI_ACCENT
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
        setter(newVal)
        update()
    end)
    rightBtn.MouseButton1Click:Connect(function()
        local newVal = math.min(maxVal, getter() + step)
        setter(newVal)
        update()
    end)
    update()
    return label
end

createSlider("Сила: ", 215, 10, 500, 5, function() return CONFIG.FLING_POWER end, function(v) CONFIG.FLING_POWER = v end)
createSlider("Дистанция: ", 275, 0.5, 10, 0.5, function() return CONFIG.FOLLOW_DISTANCE end, function(v) CONFIG.FOLLOW_DISTANCE = v end)
createSlider("Интервал: ", 335, 0.1, 2, 0.1, function() return CONFIG.FLING_INTERVAL end, function(v) CONFIG.FLING_INTERVAL = v end)
createSlider("Скорость Fly: ", 395, 1, 20, 0.5, function() return CONFIG.FLY_SPEED end, function(v) CONFIG.FLY_SPEED = v end)

-- Настройки ESP
local espY = 455
local espToggle = Instance.new("TextButton")
espToggle.Size = UDim2.new(0.25,0,0,25)
espToggle.Position = UDim2.new(0.05,0,0,espY)
espToggle.BackgroundColor3 = Color3.fromRGB(50,55,70)
espToggle.Text = "ESP: Выкл"
espToggle.TextColor3 = Color3.fromRGB(255,255,255)
espToggle.TextScaled = true
espToggle.Font = Enum.Font.Gotham
espToggle.BorderSizePixel = 0
espToggle.Parent = mainFrame
local cornerET = Instance.new("UICorner")
cornerET.CornerRadius = UDim.new(0,8)
cornerET.Parent = espToggle
espToggle.MouseButton1Click:Connect(function()
    CONFIG.ESP_ENABLED = not CONFIG.ESP_ENABLED
    espToggle.Text = "ESP: " .. (CONFIG.ESP_ENABLED and "Вкл" or "Выкл")
    updateESP()
end)

-- Цвет ESP
local espColorBtn = Instance.new("TextButton")
espColorBtn.Size = UDim2.new(0.06,0,0,20)
espColorBtn.Position = UDim2.new(0.35,0,0,espY+2)
espColorBtn.BackgroundColor3 = CONFIG.ESP_COLOR
espColorBtn.Text = ""
espColorBtn.BorderSizePixel = 0
espColorBtn.Parent = mainFrame
local cornerEC = Instance.new("UICorner")
cornerEC.CornerRadius = UDim.new(0,5)
cornerEC.Parent = espColorBtn
local espColors = {Color3.fromRGB(0,255,0), Color3.fromRGB(255,255,0), Color3.fromRGB(255,0,255), Color3.fromRGB(0,255,255)}
espColorBtn.MouseButton1Click:Connect(function()
    for i, c in ipairs(espColors) do
        if c == CONFIG.ESP_COLOR then
            CONFIG.ESP_COLOR = espColors[i % #espColors + 1]
            break
        end
    end
    espColorBtn.BackgroundColor3 = CONFIG.ESP_COLOR
    updateESP()
end)

-- Аимбот настройки
local aimbotY = 490
local aimbotToggle = Instance.new("TextButton")
aimbotToggle.Size = UDim2.new(0.25,0,0,25)
aimbotToggle.Position = UDim2.new(0.05,0,0,aimbotY)
aimbotToggle.BackgroundColor3 = Color3.fromRGB(50,55,70)
aimbotToggle.Text = "Аимбот: Вкл"
aimbotToggle.TextColor3 = Color3.fromRGB(255,255,255)
aimbotToggle.TextScaled = true
aimbotToggle.Font = Enum.Font.Gotham
aimbotToggle.BorderSizePixel = 0
aimbotToggle.Parent = mainFrame
local cornerAT = Instance.new("UICorner")
cornerAT.CornerRadius = UDim.new(0,8)
cornerAT.Parent = aimbotToggle
aimbotToggle.MouseButton1Click:Connect(function()
    CONFIG.AIMBOT_ENABLED = not CONFIG.AIMBOT_ENABLED
    aimbotToggle.Text = "Аимбот: " .. (CONFIG.AIMBOT_ENABLED and "Вкл" or "Выкл")
    startAimbot()
end)

-- FOV
local fovLabel = Instance.new("TextLabel")
fovLabel.Size = UDim2.new(0.15,0,0,20)
fovLabel.Position = UDim2.new(0.4,0,0,aimbotY)
fovLabel.BackgroundTransparency = 1
fovLabel.Text = "FOV: " .. CONFIG.AIMBOT_FOV
fovLabel.TextColor3 = Color3.fromRGB(200,200,220)
fovLabel.TextScaled = true
fovLabel.Font = Enum.Font.Gotham
fovLabel.Parent = mainFrame

local fovLeft = Instance.new("TextButton")
fovLeft.Size = UDim2.new(0.04,0,0,20)
fovLeft.Position = UDim2.new(0.55,0,0,aimbotY+2)
fovLeft.BackgroundColor3 = Color3.fromRGB(60,65,85)
fovLeft.Text = "◀"
fovLeft.TextColor3 = Color3.fromRGB(255,255,255)
fovLeft.TextScaled = true
fovLeft.Font = Enum.Font.Gotham
fovLeft.BorderSizePixel = 0
fovLeft.Parent = mainFrame
local cornerFL = Instance.new("UICorner")
cornerFL.CornerRadius = UDim.new(0,5)
cornerFL.Parent = fovLeft
fovLeft.MouseButton1Click:Connect(function()
    CONFIG.AIMBOT_FOV = math.max(5, CONFIG.AIMBOT_FOV - 5)
    fovLabel.Text = "FOV: " .. CONFIG.AIMBOT_FOV
end)

local fovRight = Instance.new("TextButton")
fovRight.Size = UDim2.new(0.04,0,0,20)
fovRight.Position = UDim2.new(0.6,0,0,aimbotY+2)
fovRight.BackgroundColor3 = Color3.fromRGB(60,65,85)
fovRight.Text = "▶"
fovRight.TextColor3 = Color3.fromRGB(255,255,255)
fovRight.TextScaled = true
fovRight.Font = Enum.Font.Gotham
fovRight.BorderSizePixel = 0
fovRight.Parent = mainFrame
local cornerFR = Instance.new("UICorner")
cornerFR.CornerRadius = UDim.new(0,5)
cornerFR.Parent = fovRight
fovRight.MouseButton1Click:Connect(function()
    CONFIG.AIMBOT_FOV = math.min(180, CONFIG.AIMBOT_FOV + 5)
    fovLabel.Text = "FOV: " .. CONFIG.AIMBOT_FOV
end)

-- Кнопка копирования FOV
local copyFovBtn = Instance.new("TextButton")
copyFovBtn.Size = UDim2.new(0.06,0,0,20)
copyFovBtn.Position = UDim2.new(0.66,0,0,aimbotY+2)
copyFovBtn.BackgroundColor3 = Color3.fromRGB(40,80,120)
copyFovBtn.Text = "📋"
copyFovBtn.TextColor3 = Color3.fromRGB(255,255,255)
copyFovBtn.TextScaled = true
copyFovBtn.Font = Enum.Font.Gotham
copyFovBtn.BorderSizePixel = 0
copyFovBtn.Parent = mainFrame
local cornerCF = Instance.new("UICorner")
cornerCF.CornerRadius = UDim.new(0,5)
cornerCF.Parent = copyFovBtn
copyFovBtn.MouseButton1Click:Connect(function()
    setclipboard(tostring(CONFIG.AIMBOT_FOV))
    statusLabel.Text = "FOV скопирован: " .. CONFIG.AIMBOT_FOV
    statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
    wait(2)
    if enabled then
        statusLabel.Text = "Включено (цель: " .. (TARGET and TARGET.Name or "?") .. ")"
        statusLabel.TextColor3 = Color3.fromRGB(0,255,150)
    else
        statusLabel.Text = "Выключено"
        statusLabel.TextColor3 = Color3.fromRGB(255,70,70)
    end
end)

-- Радиус
local radiusLabel = Instance.new("TextLabel")
radiusLabel.Size = UDim2.new(0.2,0,0,20)
radiusLabel.Position = UDim2.new(0.05,0,0,aimbotY+30)
radiusLabel.BackgroundTransparency = 1
radiusLabel.Text = "Радиус: " .. CONFIG.AIMBOT_RADIUS
radiusLabel.TextColor3 = Color3.fromRGB(200,200,220)
radiusLabel.TextScaled = true
radiusLabel.Font = Enum.Font.Gotham
radiusLabel.Parent = mainFrame

local radLeft = Instance.new("TextButton")
radLeft.Size = UDim2.new(0.04,0,0,20)
radLeft.Position = UDim2.new(0.25,0,0,aimbotY+32)
radLeft.BackgroundColor3 = Color3.fromRGB(60,65,85)
radLeft.Text = "◀"
radLeft.TextColor3 = Color3.fromRGB(255,255,255)
radLeft.TextScaled = true
radLeft.Font = Enum.Font.Gotham
radLeft.BorderSizePixel = 0
radLeft.Parent = mainFrame
local cornerRL = Instance.new("UICorner")
cornerRL.CornerRadius = UDim.new(0,5)
cornerRL.Parent = radLeft
radLeft.MouseButton1Click:Connect(function()
    CONFIG.AIMBOT_RADIUS = math.max(10, CONFIG.AIMBOT_RADIUS - 10)
    radiusLabel.Text = "Радиус: " .. CONFIG.AIMBOT_RADIUS
end)

local radRight = Instance.new("TextButton")
radRight.Size = UDim2.new(0.04,0,0,20)
radRight.Position = UDim2.new(0.3,0,0,aimbotY+32)
radRight.BackgroundColor3 = Color3.fromRGB(60,65,85)
radRight.Text = "▶"
radRight.TextColor3 = Color3.fromRGB(255,255,255)
radRight.TextScaled = true
radRight.Font = Enum.Font.Gotham
radRight.BorderSizePixel = 0
radRight.Parent = mainFrame
local cornerRR = Instance.new("UICorner")
cornerRR.CornerRadius = UDim.new(0,5)
cornerRR.Parent = radRight
radRight.MouseButton1Click:Connect(function()
    CONFIG.AIMBOT_RADIUS = math.min(500, CONFIG.AIMBOT_RADIUS + 10)
    radiusLabel.Text = "Радиус: " .. CONFIG.AIMBOT_RADIUS
end)

-- Открытие меню по правому Shift
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
        end
    end
end)

Player.CharacterAdded:Connect(function()
    stopFlying()
    clearESP()
end)

print("Скрипт загружен. Правый Shift для меню.")
