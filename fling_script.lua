--[[
    Fling Controller для MM2
    - полёт под игроком + подкидывание
    - настройки силы, дистанции, интервала
    - выбор цветовой схемы GUI (чёрный, серый, зелёный, мятный, медовый, градиент, белый)
    - регулировка прозрачности фона
    - выделение убийцы и шерифа цветными хитбоксами (вкл/выкл, выбор цветов)
--]]

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Настройки по умолчанию
local CONFIG = {
    FLING_POWER = 150,
    FOLLOW_DISTANCE = 3,
    FLY_SPEED = 5,
    FLING_INTERVAL = 0.5,
    GUI_BG_COLOR = Color3.fromRGB(20,22,30),
    GUI_BG_TRANSPARENCY = 0.08,
    GUI_ACCENT = Color3.fromRGB(0,180,255),
    HIGHLIGHT_ENABLED = false,
    HIGHLIGHT_MURDERER = Color3.fromRGB(255,0,0),
    HIGHLIGHT_SHERIFF = Color3.fromRGB(0,0,255),
}

-- Состояния
local TARGET = nil
local enabled = false
local bv = nil
local lastFling = 0
local heartbeatConnection = nil
local menuOpen = false
local highlights = {} -- {player -> box}
local highlightTasks = {}

-- Вспомогательные функции
local function getTarget(name)
    if name then return game.Players:FindFirstChild(name) end
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

local function flingTarget(target)
    if not target or not target.Character then return end
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    if root then root.Velocity = Vector3.new(0, CONFIG.FLING_POWER, 0) end
end

local function stopFlying()
    enabled = false
    if bv then bv:Destroy(); bv = nil end
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
        if tick() - lastFling > CONFIG.FLING_INTERVAL then
            flingTarget(target)
            lastFling = tick()
        end
    end)
end

-- ===== Функции выделения =====
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

    -- Определяем роли (убийца, шериф) по наличию оружия
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

    -- Следим за пересозданием персонажей
    local function watchPlayer(plr)
        local task = {}
        task.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            if not plr or not plr.Character then return end
            if not highlights[plr] then
                -- если персонаж пересоздан, добавить выделение заново
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

-- ===== Построение GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlingMenu"
screenGui.Parent = Player.PlayerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 380, 0, 500)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -250)
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

-- Заголовок
local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,50)
header.Position = UDim2.new(0,0,0,0)
header.BackgroundColor3 = Color3.fromRGB(40,45,60)
header.BorderSizePixel = 0
header.Parent = mainFrame
local cornerHeader = Instance.new("UICorner")
cornerHeader.CornerRadius = UDim.new(0,20)
cornerHeader.Parent = header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,1,0)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundTransparency = 1
title.Text = "✦ Fling Controller ✦"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = header

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,30,0,30)
closeBtn.Position = UDim2.new(1,-40,0,10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = mainFrame
local cornerClose = Instance.new("UICorner")
cornerClose.CornerRadius = UDim.new(0,15)
cornerClose.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    menuOpen = false
end)

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,0,0,30)
statusLabel.Position = UDim2.new(0,0,0,55)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Выключено"
statusLabel.TextColor3 = Color3.fromRGB(255,70,70)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.Parent = mainFrame

-- Кнопка включения
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.8,0,0,45)
toggleBtn.Position = UDim2.new(0.1,0,0,95)
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
toggleBtn.MouseEnter:Connect(function()
    toggleBtn.BackgroundColor3 = Color3.fromRGB(80,90,130)
end)
toggleBtn.MouseLeave:Connect(function()
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60,70,100)
end)
toggleBtn.MouseButton1Click:Connect(function()
    if enabled then
        stopFlying()
        toggleBtn.Text = "▶ Включить"
    else
        local target = getTarget(nil)
        if target then
            flyUnder(target)
            toggleBtn.Text = "⏹ Выключить"
        else
            statusLabel.Text = "Нет игроков!"
            statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
        end
    end
end)

-- Создание ползунков
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

-- Слайдеры
createSlider("Сила: ", 135, 10, 500, 5, function() return CONFIG.FLING_POWER end, function(v) CONFIG.FLING_POWER = v end)
createSlider("Дистанция: ", 195, 0.5, 10, 0.5, function() return CONFIG.FOLLOW_DISTANCE end, function(v) CONFIG.FOLLOW_DISTANCE = v end)
createSlider("Интервал: ", 255, 0.1, 2, 0.1, function() return CONFIG.FLING_INTERVAL end, function(v) CONFIG.FLING_INTERVAL = v end)

-- Настройки цветов GUI и прозрачности
local colorSectionY = 315
local colorLabel = Instance.new("TextLabel")
colorLabel.Size = UDim2.new(0.4,0,0,20)
colorLabel.Position = UDim2.new(0.05,0,0,colorSectionY)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "Цвет GUI:"
colorLabel.TextColor3 = Color3.fromRGB(200,200,220)
colorLabel.TextScaled = true
colorLabel.Font = Enum.Font.Gotham
colorLabel.Parent = mainFrame

-- Кнопки выбора цвета (палитра)
local colorPalette = {
    {name="Чёрный", color=Color3.fromRGB(15,15,20)},
    {name="Серый", color=Color3.fromRGB(50,55,65)},
    {name="Зелёный", color=Color3.fromRGB(20,40,25)},
    {name="Мятный", color=Color3.fromRGB(25,60,55)},
    {name="Медовый", color=Color3.fromRGB(60,45,20)},
    {name="Градиент", color=nil}, -- особый случай
    {name="Белый", color=Color3.fromRGB(40,40,45)},
}
local colorBtns = {}
for i, data in ipairs(colorPalette) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.1,0,0,20)
    btn.Position = UDim2.new(0.05 + (i-1)*0.12, 0, colorSectionY+25, 0)
    btn.BackgroundColor3 = data.color or Color3.fromRGB(0,180,255)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = mainFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,5)
    corner.Parent = btn
    -- для градиента - сделаем двухцветный фон
    if data.name == "Градиент" then
        btn.BackgroundColor3 = Color3.fromRGB(30,30,40)
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0,0,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,255)),
        }
        grad.Rotation = 45
        grad.Parent = btn
    end
    btn.MouseButton1Click:Connect(function()
        if data.name == "Градиент" then
            -- Создаём градиентный фон (динамический)
            local grad = Instance.new("UIGradient")
            grad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
                ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0,0,255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,255)),
            }
            grad.Rotation = 45
            grad.Parent = mainFrame
            mainFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
            mainFrame.BackgroundTransparency = CONFIG.GUI_BG_TRANSPARENCY
            -- Удаляем старый градиент, если есть
            local old = mainFrame:FindFirstChildWhichIsA("UIGradient")
            if old and old ~= grad then old:Destroy() end
        else
            local old = mainFrame:FindFirstChildWhichIsA("UIGradient")
            if old then old:Destroy() end
            mainFrame.BackgroundColor3 = data.color
            mainFrame.BackgroundTransparency = CONFIG.GUI_BG_TRANSPARENCY
        end
        CONFIG.GUI_BG_COLOR = data.color or Color3.fromRGB(0,0,0)
    end)
    table.insert(colorBtns, btn)
end

-- Прозрачность
local alphaLabel = Instance.new("TextLabel")
alphaLabel.Size = UDim2.new(0.3,0,0,20)
alphaLabel.Position = UDim2.new(0.6,0,0,colorSectionY)
alphaLabel.BackgroundTransparency = 1
alphaLabel.Text = "Прозр.: 0.08"
alphaLabel.TextColor3 = Color3.fromRGB(200,200,220)
alphaLabel.TextScaled = true
alphaLabel.Font = Enum.Font.Gotham
alphaLabel.Parent = mainFrame

local alphaBtnLeft = Instance.new("TextButton")
alphaBtnLeft.Size = UDim2.new(0.05,0,0,20)
alphaBtnLeft.Position = UDim2.new(0.85,0,0,colorSectionY+25)
alphaBtnLeft.BackgroundColor3 = Color3.fromRGB(60,65,85)
alphaBtnLeft.Text = "◀"
alphaBtnLeft.TextColor3 = Color3.fromRGB(255,255,255)
alphaBtnLeft.TextScaled = true
alphaBtnLeft.Font = Enum.Font.Gotham
alphaBtnLeft.BorderSizePixel = 0
alphaBtnLeft.Parent = mainFrame
local cornerAL = Instance.new("UICorner")
cornerAL.CornerRadius = UDim.new(0,5)
cornerAL.Parent = alphaBtnLeft

local alphaBtnRight = Instance.new("TextButton")
alphaBtnRight.Size = UDim2.new(0.05,0,0,20)
alphaBtnRight.Position = UDim2.new(0.91,0,0,colorSectionY+25)
alphaBtnRight.BackgroundColor3 = Color3.fromRGB(60,65,85)
alphaBtnRight.Text = "▶"
alphaBtnRight.TextColor3 = Color3.fromRGB(255,255,255)
alphaBtnRight.TextScaled = true
alphaBtnRight.Font = Enum.Font.Gotham
alphaBtnRight.BorderSizePixel = 0
alphaBtnRight.Parent = mainFrame
local cornerAR = Instance.new("UICorner")
cornerAR.CornerRadius = UDim.new(0,5)
cornerAR.Parent = alphaBtnRight

local function updateAlpha()
    local a = CONFIG.GUI_BG_TRANSPARENCY
    alphaLabel.Text = "Прозр.: " .. string.format("%.2f", a)
    mainFrame.BackgroundTransparency = a
end
alphaBtnLeft.MouseButton1Click:Connect(function()
    CONFIG.GUI_BG_TRANSPARENCY = math.max(0, CONFIG.GUI_BG_TRANSPARENCY - 0.02)
    updateAlpha()
end)
alphaBtnRight.MouseButton1Click:Connect(function()
    CONFIG.GUI_BG_TRANSPARENCY = math.min(0.5, CONFIG.GUI_BG_TRANSPARENCY + 0.02)
    updateAlpha()
end)
updateAlpha()

-- Выделение (хитбоксы)
local highlightSectionY = 365
local highlightToggle = Instance.new("TextButton")
highlightToggle.Size = UDim2.new(0.3,0,0,25)
highlightToggle.Position = UDim2.new(0.05,0,0,highlightSectionY)
highlightToggle.BackgroundColor3 = Color3.fromRGB(50,55,70)
highlightToggle.Text = "Выделение: Выкл"
highlightToggle.TextColor3 = Color3.fromRGB(255,255,255)
highlightToggle.TextScaled = true
highlightToggle.Font = Enum.Font.Gotham
highlightToggle.BorderSizePixel = 0
highlightToggle.Parent = mainFrame
local cornerHT = Instance.new("UICorner")
cornerHT.CornerRadius = UDim.new(0,8)
cornerHT.Parent = highlightToggle
highlightToggle.MouseButton1Click:Connect(function()
    CONFIG.HIGHLIGHT_ENABLED = not CONFIG.HIGHLIGHT_ENABLED
    highlightToggle.Text = "Выделение: " .. (CONFIG.HIGHLIGHT_ENABLED and "Вкл" or "Выкл")
    updateHighlights()
end)

-- Цвет для убийцы
local murderColorLabel = Instance.new("TextLabel")
murderColorLabel.Size = UDim2.new(0.25,0,0,20)
murderColorLabel.Position = UDim2.new(0.4,0,0,highlightSectionY)
murderColorLabel.BackgroundTransparency = 1
murderColorLabel.Text = "Убийца:"
murderColorLabel.TextColor3 = Color3.fromRGB(200,200,220)
murderColorLabel.TextScaled = true
murderColorLabel.Font = Enum.Font.Gotham
murderColorLabel.Parent = mainFrame

local murderColorBtn = Instance.new("TextButton")
murderColorBtn.Size = UDim2.new(0.08,0,0,20)
murderColorBtn.Position = UDim2.new(0.6,0,0,highlightSectionY)
murderColorBtn.BackgroundColor3 = CONFIG.HIGHLIGHT_MURDERER
murderColorBtn.Text = ""
murderColorBtn.BorderSizePixel = 0
murderColorBtn.Parent = mainFrame
local cornerMC = Instance.new("UICorner")
cornerMC.CornerRadius = UDim.new(0,5)
cornerMC.Parent = murderColorBtn
murderColorBtn.MouseButton1Click:Connect(function()
    -- Простой выбор цвета: меняем на следующий из палитры
    local colors = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,100,0), Color3.fromRGB(255,0,255), Color3.fromRGB(200,0,200), Color3.fromRGB(255,255,0)}
    local idx = 1
    for i, c in ipairs(colors) do
        if c == CONFIG.HIGHLIGHT_MURDERER then idx = i break end
    end
    idx = idx % #colors + 1
    CONFIG.HIGHLIGHT_MURDERER = colors[idx]
    murderColorBtn.BackgroundColor3 = CONFIG.HIGHLIGHT_MURDERER
    updateHighlights()
end)

-- Цвет для шерифа
local sheriffColorLabel = Instance.new("TextLabel")
sheriffColorLabel.Size = UDim2.new(0.25,0,0,20)
sheriffColorLabel.Position = UDim2.new(0.4,0,0,highlightSectionY+25)
sheriffColorLabel.BackgroundTransparency = 1
sheriffColorLabel.Text = "Шериф:"
sheriffColorLabel.TextColor3 = Color3.fromRGB(200,200,220)
sheriffColorLabel.TextScaled = true
sheriffColorLabel.Font = Enum.Font.Gotham
sheriffColorLabel.Parent = mainFrame

local sheriffColorBtn = Instance.new("TextButton")
sheriffColorBtn.Size = UDim2.new(0.08,0,0,20)
sheriffColorBtn.Position = UDim2.new(0.6,0,0,highlightSectionY+25)
sheriffColorBtn.BackgroundColor3 = CONFIG.HIGHLIGHT_SHERIFF
sheriffColorBtn.Text = ""
sheriffColorBtn.BorderSizePixel = 0
sheriffColorBtn.Parent = mainFrame
local cornerSC = Instance.new("UICorner")
cornerSC.CornerRadius = UDim.new(0,5)
cornerSC.Parent = sheriffColorBtn
sheriffColorBtn.MouseButton1Click:Connect(function()
    local colors = {Color3.fromRGB(0,0,255), Color3.fromRGB(0,150,255), Color3.fromRGB(0,255,255), Color3.fromRGB(0,100,200)}
    local idx = 1
    for i, c in ipairs(colors) do
        if c == CONFIG.HIGHLIGHT_SHERIFF then idx = i break end
    end
    idx = idx % #colors + 1
    CONFIG.HIGHLIGHT_SHERIFF = colors[idx]
    sheriffColorBtn.BackgroundColor3 = CONFIG.HIGHLIGHT_SHERIFF
    updateHighlights()
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
            -- обновить выделения при открытии
            updateHighlights()
        end
    end
end)

-- Очистка при выходе
Player.CharacterAdded:Connect(function()
    stopFlying()
    clearHighlights()
end)

print("Загружено. Правый Shift для меню.")
