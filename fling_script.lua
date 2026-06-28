-- Скрипт для MM2 - подкидывание и полет под игроком
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- НАСТРОЙКИ (меняй под себя)
local FLING_POWER = 150        -- Сила подкидывания (чем больше, тем выше)
local FOLLOW_DISTANCE = 3      -- Расстояние под игроком
local FLY_SPEED = 5            -- Скорость полёта
local FLING_INTERVAL = 0.5     -- Как часто подкидывать (в секундах)
local KEY_TOGGLE = Enum.KeyCode.F  -- Клавиша включения/выключения

-- Переменные состояния
local TARGET = nil
local enabled = false
local bv = nil
local lastFling = 0
local heartbeatConnection = nil

-- Функция для поиска ближайшего игрока
local function getTarget(name)
    if name then
        return game.Players:FindFirstChild(name)
    else
        local nearest = nil
        local dist = math.huge
        for _, plr in ipairs(game.Players:GetPlayers()) do
            if plr ~= Player then
                local char = plr.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local d = (RootPart.Position - char.HumanoidRootPart.Position).Magnitude
                    if d < dist then
                        dist = d
                        nearest = plr
                    end
                end
            end
        end
        return nearest
    end
end

-- Функция для подкидывания цели
local function flingTarget(target)
    if not target then return end
    local char = target.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    root.Velocity = Vector3.new(0, FLING_POWER, 0)
end

-- Функция остановки полёта
local function stopFlying()
    enabled = false
    if bv then
        bv:Destroy()
        bv = nil
    end
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    Humanoid.PlatformStand = false
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    print("❌ Скрипт остановлен")
end

-- Основная функция полёта под целью
local function flyUnder(target)
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- Останавливаем предыдущий полёт, если был
    stopFlying()

    -- Создаём BodyVelocity
    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = RootPart

    -- Отключаем гравитацию
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    Humanoid.PlatformStand = true

    enabled = true
    lastFling = 0

    -- Цикл обновления
    heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not enabled then return end

        -- Проверяем, существует ли цель
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            print("⚠️ Цель исчезла, останавливаем...")
            stopFlying()
            return
        end

        local targetPos = target.Character.HumanoidRootPart.Position
        local underPos = targetPos - Vector3.new(0, FOLLOW_DISTANCE, 0)
        local currentPos = RootPart.Position
        local direction = (underPos - currentPos)

        -- Движение к цели
        if direction.Magnitude > 10 then
            RootPart.CFrame = CFrame.new(underPos)
        else
            bv.Velocity = direction * FLY_SPEED
        end

        -- Подкидываем цель с интервалом
        if tick() - lastFling > FLING_INTERVAL then
            flingTarget(target)
            lastFling = tick()
        end
    end)

    print("✅ Теперь вы летаете под игроком " .. target.Name .. " и подкидываете его!")
end

-- Обработка нажатия клавиши F (включение/выключение)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == KEY_TOGGLE then
        if enabled then
            -- Если включено - выключаем
            stopFlying()
            print("🔴 Скрипт выключен")
        else
            -- Если выключено - ищем цель и включаем
            TARGET = getTarget(nil)
            if TARGET then
                flyUnder(TARGET)
            else
                print("⚠️ Нет игроков поблизости!")
            end
        end
    end
end)

-- Очистка при выходе из игры
Player.CharacterAdded:Connect(function()
    stopFlying()
end)

print("🟢 Скрипт загружен! Нажмите F, чтобы включить/выключить.")
