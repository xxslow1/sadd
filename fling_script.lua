-- Скрипт для MM2 - подкидывание и полет под игроком
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Настройки
local FLING_POWER = 150 -- сила подкидывания
local FOLLOW_DISTANCE = 3 -- расстояние под игроком
local TARGET = nil -- цель, можно установить по имени или выбрать ближайшего

-- Функция для поиска игрока по имени или ближайшего
local function getTarget(name)
    if name then
        return game.Players:FindFirstChild(name)
    else
        -- ближайший
        local nearest = nil
        local dist = math.huge
        for _, plr in ipairs(game.Players:GetPlayers()) do
            if plr ~= Player then
                local char = plr.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local d = (RootPart.Position - char.HumanoidRootPart.Position).magnitude
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
    -- Устанавливаем вертикальную скорость
    root.Velocity = Vector3.new(0, FLING_POWER, 0)
    -- Можно также добавить случайное горизонтальное смещение
end

-- Создаем BodyVelocity для нашего персонажа, чтобы летать под целью
local function flyUnder(target)
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    
    -- Создаем BodyVelocity в нашем RootPart
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = RootPart
    
    -- Отключаем гравитацию для нас (можно через Humanoid)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    Humanoid.PlatformStand = true
    
    -- Цикл обновления позиции под целью
    game:GetService("RunService").Heartbeat:Connect(function()
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            bv:Destroy()
            Humanoid.PlatformStand = false
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            return
        end
        local targetPos = target.Character.HumanoidRootPart.Position
        local underPos = targetPos - Vector3.new(0, FOLLOW_DISTANCE, 0)
        -- Устанавливаем скорость, чтобы двигаться к underPos
        local currentPos = RootPart.Position
        local direction = (underPos - currentPos)
        -- Если далеко, телепортируем, иначе плавно летим
        if direction.magnitude > 10 then
            RootPart.CFrame = CFrame.new(underPos)
        else
            bv.Velocity = direction * 5 -- скорость полета
        end
        -- Подкидываем цель каждые 0.5 секунды
        if not lastFling or tick() - lastFling > 0.5 then
            flingTarget(target)
            lastFling = tick()
        end
    end)
end

-- Инициализация: выбираем цель (можно изменить на конкретное имя)
TARGET = getTarget() -- ближайший

if TARGET then
    flyUnder(TARGET)
    print("Теперь вы летаете под игроком " .. TARGET.Name .. " и подкидываете его!")
else
    print("Не найден игрок для цели.")
end

-- Остановка по нажатию клавиши (например, G)
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        -- остановить скрипт (перезагрузить?)
        -- Просто выведем сообщение
        print("Остановка. Перезапустите скрипт для активации.")
        -- можно сломать, но для простоты ничего не делаем
    end
end)
