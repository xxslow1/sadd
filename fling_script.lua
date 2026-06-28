-- Скрипт для MM2 - подкидывание и полет под игроком
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Настройки
local FLING_POWER = 150        -- сила подкидывания
local FOLLOW_DISTANCE = 3      -- расстояние под игроком
local FLY_SPEED = 5            -- скорость полёта
local FLING_INTERVAL = 0.5     -- интервал между подкидываниями (сек)
local KEY_TOGGLE = Enum.KeyCode.F  -- клавиша для включения/выключения

local TARGET = nil
local enabled = false
local bv = nil
local lastFling = 0

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

-- Основная функция полёта под целью
local function flyUnder(target)
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- Создаём BodyVelocity
    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = RootPart

    -- Отключаем гравитацию
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    Humanoid.PlatformStand = true

    -- Цикл обновления
    game:GetService("RunService").Heartbeat:Connect(function()
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            if bv then bv:Destroy() end
            Humanoid.PlatformStand = false
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            enabled = false
            return
        end

        local targetPos = target.Character.HumanoidRootPart.Position
        local underPos = targetPos - Vector3.new(0, FOLLOW_DISTANCE, 0)
        local currentPos = RootPart.Position
        local direction = (underPos - currentPos)

        if direction.Magnitude > 10 then
            RootPart.CFrame = CFrame.new(underPos)
        else
            bv.Velocity = direction * FLY_SPEED
        end

        -- Подкидываем цель
        if tick() - lastFling > FLING_INTERVAL then
            flingTarget(target)
            lastFling = tick()
        end
    end)
end

-- Включение/выключение по клавише
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == KEY_TOGGLE then
        enabled = not enabled
        if enabled then
            TARGET = getTarget(nil)
            if TARGET then
                flyUnder(TARGET)
            else
                print("Нет игроков поблизости!")
                enabled = false
            end
        else
            -- Выключаем
            if bv then bv:Destroy() end
            Humanoid.PlatformStand = false
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            print("Выключено")
        end
    end
end)

print("Скрипт загружен! Нажмите F, чтобы включить/выключить.")
