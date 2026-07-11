-- ===============================================
--   Da Hood SILENT AIM v15 FIXED
--   Multi-Method | Auto-Fallback | Precision Fix
--   Works on XENO / Delta / Fluxus / KRNL / etc
-- ===============================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3)

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local CG = game:GetService("CoreGui")
local TS = game:GetService("TweenService")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()

if not Drawing then warn("No Drawing lib") return end

-- ==================== EXECUTOR CHECK ====================
print("=== EXECUTOR CAPABILITIES ===")
print("hookmetamethod:", hookmetamethod ~= nil)
print("getnamecallmethod:", getnamecallmethod ~= nil)
print("getrawmetatable:", getrawmetatable ~= nil)
print("setreadonly:", setreadonly ~= nil)
print("newcclosure:", newcclosure ~= nil)
print("hookfunction:", hookfunction ~= nil)
print("gethui:", gethui ~= nil)
print("=============================")

-- ==================== UTILS ====================
local function GetPing()
    local p = 50
    pcall(function()
        p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return p
end

local function Notify(t, m, d)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = t, Text = m, Duration = d or 3
        })
    end)
end

local function Draw(t, p)
    local s, o = pcall(Drawing.new, t)
    if not s then return nil end
    for k, v in pairs(p or {}) do
        pcall(function() o[k] = v end)
    end
    return o
end

local function Tw(obj, props, dur)
    TS:Create(obj, TweenInfo.new(dur or 0.3, Enum.EasingStyle.Quint), props):Play()
end

-- ==================== CONFIG ====================
local CFG = {
    Enabled = true,
    SilentAim = true,
    AimKey = "MB2",
    FOV = 250,
    TeamCheck = false,
    NoDowned = true,
    NoCuffed = true,
    IgnoreWalls = true,
    HitPart = "Head",

    -- FIXED: Simplified prediction - less is more
    SmartPrediction = true,
    DistancePrediction = true,
    BasePred = 0.145,
    MaxPred = 0.165,
    DistanceScale = 200,
    BulletSpeed = 1000,
    BulletDrop = 0,
    VelocityComp = 1.0,
    PredictJump = true,
    PredictFall = true,
    HeadOffset = 0.0,
    UseAccel = false,           -- FIXED: Off by default, causes jitter
    VelocitySmoothing = 0.3,    -- FIXED: Lower default, was too smooth
    ResolverEnabled = true,
    TargetPriority = "Distance",
    PingComp = true,            -- NEW: Separate ping compensation toggle

    ShowFOV = true,
    ShowDot = true,
    ShowLine = false,
    ShowESP = true,
    ShowNames = true,
    ShowHP = true,
    ShowDist = true,
    RainbowFOV = false,
    ShowPredPath = true,
    ShowHeadDot = true,

    Wings = false, WingStyle = "Angel",
    Aura = false, AuraRainbow = false,
    Trail = false, TrailRainbow = false,
    FloatingRings = false, Halo = false,
    BodyGlow = false, Orbs = false,

    BulletTrail = false,
    BulletTrailColor = Color3.fromRGB(255, 55, 85),
    BulletTrailRainbow = false,
    MuzzleFlash = false,
    HitMarker = false,
}

local Alive = true
local Target = nil
local Aiming = false
local RainbowHue = 0
local ActiveEffects = {}
local VelHistory = {}
local PosHistory = {}
local CurrentTab = "Aim"
local SilentMethod = "NONE"

-- ==================== TRACKING (FIXED) ====================
-- FIX: Добавлен timestamp-based tracking с защитой от телепортов
local function UpdateHistory(plr, pos, vel)
    if not VelHistory[plr] then VelHistory[plr] = {} end
    if not PosHistory[plr] then PosHistory[plr] = {} end
    local t = tick()

    -- FIXED: Защита от телепортов - если позиция слишком резко изменилась, очищаем историю
    if #PosHistory[plr] > 0 then
        local lastPos = PosHistory[plr][#PosHistory[plr]].pos
        local lastTime = PosHistory[plr][#PosHistory[plr]].time
        local dt = t - lastTime
        if dt > 0 and dt < 1 then
            local speed = (pos - lastPos).Magnitude / dt
            if speed > 300 then -- Телепорт detected
                VelHistory[plr] = {}
                PosHistory[plr] = {}
            end
        end
    end

    table.insert(VelHistory[plr], {vel = vel, time = t})
    table.insert(PosHistory[plr], {pos = pos, time = t})

    -- FIXED: Храним только последние 12 фреймов (было 20 - слишком много устаревших данных)
    while #VelHistory[plr] > 12 do table.remove(VelHistory[plr], 1) end
    while #PosHistory[plr] > 12 do table.remove(PosHistory[plr], 1) end
end

-- FIXED: Весовая функция теперь экспоненциально затухает
local function GetSmoothedVel(plr)
    if not VelHistory[plr] or #VelHistory[plr] < 2 then return Vector3.zero end
    local now = tick()
    local sum = Vector3.zero
    local weight = 0

    for i = #VelHistory[plr], math.max(1, #VelHistory[plr] - 7), -1 do
        local entry = VelHistory[plr][i]
        local age = now - entry.time
        if age > 1 then continue end -- Игнорируем данные старше 1 секунды

        -- FIXED: Экспоненциальное затухание вместо линейного
        local w = math.exp(-age * 5)
        sum = sum + entry.vel * w
        weight = weight + w
    end

    if weight < 0.01 then return Vector3.zero end
    return sum / weight
end

-- FIXED: Acceleration теперь берёт только 2 последних замера
local function GetAccel(plr)
    if not VelHistory[plr] or #VelHistory[plr] < 3 then return Vector3.zero end
    local last = VelHistory[plr][#VelHistory[plr]]
    local prev = VelHistory[plr][#VelHistory[plr] - 1]
    local dt = last.time - prev.time
    if dt <= 0.001 or dt > 0.5 then return Vector3.zero end
    local accel = (last.vel - prev.vel) / dt

    -- FIXED: Clamp acceleration чтобы избежать экстремальных значений
    local mag = accel.Magnitude
    if mag > 50 then
        accel = accel.Unit * 50
    end
    return accel
end

-- FIXED: Убрана избыточная функция GetMovementDirection
-- Она дублировала GetSmoothedVel и создавала конфликт

-- ==================== CHECKS (FIXED) ====================
local function IsValid(plr)
    if not plr or plr == LP or not plr.Parent then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    -- FIXED: Проверяем конкретный HitPart И Head
    local hitPart = ch:FindFirstChild(CFG.HitPart) or ch:FindFirstChild("Head")
    if not hitPart then return false end

    if CFG.TeamCheck then
        local ok, same = pcall(function()
            return plr.Team and LP.Team and plr.Team == LP.Team
        end)
        if ok and same then return false end
    end

    if CFG.NoDowned then
        local ok, d = pcall(function()
            local be = ch:FindFirstChild("BodyEffects")
            if be then
                local ko = be:FindFirstChild("K.O")
                if ko then return ko.Value end
            end
            return false
        end)
        if ok and d then return false end
    end

    if CFG.NoCuffed then
        local ok, c = pcall(function()
            -- FIXED: Проверяем также через BodyEffects
            if ch:FindFirstChild("Handcuffed") then return true end
            local be = ch:FindFirstChild("BodyEffects")
            if be and be:FindFirstChild("Handcuffed") then return true end
            return false
        end)
        if ok and c then return false end
    end

    return true
end

-- FIXED: Wall check теперь правильно фильтрует персонажей
local function IsHeadVisible(targetChar, headPos)
    if not CFG.IgnoreWalls then return true end -- Если IgnoreWalls вкл, пропускаем проверку
    local ch = LP.Character
    if not ch then return false end
    local myHead = ch:FindFirstChild("Head")
    if not myHead then return false end

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist

    -- FIXED: Фильтруем СВОЕГО персонажа И камеру
    local filterList = {ch, workspace.CurrentCamera}

    -- FIXED: Добавляем персонаж цели в фильтр
    if targetChar then
        table.insert(filterList, targetChar)
    end

    rp.FilterDescendantsInstances = filterList

    local dir = headPos - myHead.Position
    local result = workspace:Raycast(myHead.Position, dir, rp)

    -- Если raycast ничего не нашёл - путь свободен
    if not result then return true end

    -- FIXED: Проверяем, может быть мы попали в часть другого игрока
    local hit = result.Instance
    if hit then
        -- Проверяем вверх по иерархии
        local parent = hit.Parent
        while parent and parent ~= workspace do
            local p = Players:GetPlayerFromCharacter(parent)
            if p then return true end -- Попали в игрока — значит путь до цели свободен
            parent = parent.Parent
        end
    end

    -- FIXED: Более точная проверка расстояния
    local hitDist = (result.Position - myHead.Position).Magnitude
    local targetDist = dir.Magnitude
    return (targetDist - hitDist) < 3
end

-- ==================== TARGET (FIXED) ====================
local function GetMyPos()
    local ch = LP.Character
    if not ch then return nil end
    local root = ch:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

-- FIXED: Полностью переработан target selection
local function GetTarget()
    local myPos = GetMyPos()
    if not myPos then Target = nil; return nil end

    local cands = {}
    local cx = Cam.ViewportSize.X / 2
    local cy = Cam.ViewportSize.Y / 2

    for _, p in ipairs(Players:GetPlayers()) do
        if IsValid(p) then
            local ch = p.Character
            local hitPart = ch:FindFirstChild(CFG.HitPart) or ch:FindFirstChild("Head")
            if hitPart then
                local sp, vis = Cam:WorldToViewportPoint(hitPart.Position)
                if vis and sp.Z > 0 then -- FIXED: Проверяем Z > 0 (перед камерой)
                    local sd = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
                    if sd <= CFG.FOV then
                        -- FIXED: Wall check использует правильный персонаж
                        local wallOk = CFG.IgnoreWalls or IsHeadVisible(ch, hitPart.Position)
                        if wallOk then
                            local worldDist = (myPos - hitPart.Position).Magnitude
                            local hp = 100
                            pcall(function()
                                hp = ch:FindFirstChildOfClass("Humanoid").Health
                            end)

                            -- FIXED: Обновляем историю для всех кандидатов
                            local root = ch:FindFirstChild("HumanoidRootPart")
                            if root then
                                UpdateHistory(p, hitPart.Position, root.AssemblyLinearVelocity)
                            end

                            table.insert(cands, {
                                player = p, sd = sd, hp = hp, dist = worldDist
                            })
                        end
                    end
                end
            end
        end
    end

    if #cands == 0 then Target = nil; return nil end

    if CFG.TargetPriority == "HP" then
        table.sort(cands, function(a, b) return a.hp < b.hp end)
    else
        table.sort(cands, function(a, b) return a.sd < b.sd end)
    end

    Target = cands[1].player
    return Target
end

-- ==================== PREDICTION (COMPLETELY REWRITTEN) ====================
-- FIXED: Вся система prediction переписана с нуля

local function CalculatePredictionTime(distance)
    -- Базовое время предсказания
    local pred = CFG.BasePred

    -- Добавляем дистанционную компонентку
    if CFG.DistancePrediction then
        local t = math.clamp(distance / CFG.DistanceScale, 0, 1)
        pred = CFG.BasePred + (CFG.MaxPred - CFG.BasePred) * t
    end

    -- FIXED: Ping компенсация добавляется ОТДЕЛЬНО и правильно
    if CFG.PingComp then
        local pingSeconds = GetPing() / 1000
        -- Добавляем только ПОЛОВИНУ пинга (один путь, не round-trip)
        pred = pred + pingSeconds * 0.5
    end

    -- Время полёта пули
    local bulletTime = distance / CFG.BulletSpeed
    pred = pred + bulletTime

    return pred
end

local function PredictHeadPos()
    if not Target then return nil end
    local ch = Target.Character
    if not ch then return nil end

    local hitPart = ch:FindFirstChild(CFG.HitPart) or ch:FindFirstChild("Head")
    if not hitPart then return nil end

    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return hitPart.Position end

    local headPos = hitPart.Position
    local myPos = GetMyPos()
    if not myPos then return headPos end

    local distance = (myPos - headPos).Magnitude
    local rawVel = root.AssemblyLinearVelocity

    -- ===== VELOCITY CALCULATION (FIXED) =====
    local finalVel

    if CFG.SmartPrediction then
        local smoothVel = GetSmoothedVel(Target)

        -- FIXED: Простое взвешенное среднее вместо тройного микса
        if smoothVel.Magnitude > 1 then
            local alpha = CFG.VelocitySmoothing
            finalVel = rawVel * (1 - alpha) + smoothVel * alpha
        else
            finalVel = rawVel
        end
    else
        finalVel = rawVel
    end

    -- Применяем velocity compensation
    finalVel = finalVel * CFG.VelocityComp

    -- ===== PREDICTION TIME =====
    local totalPred = CalculatePredictionTime(distance)

    -- ===== BASE PREDICTION =====
    local predicted = headPos + finalVel * totalPred

    -- ===== ACCELERATION (FIXED) =====
    if CFG.UseAccel and CFG.SmartPrediction then
        local accel = GetAccel(Target)
        -- FIXED: Используем стандартную формулу s = v*t + 0.5*a*t^2
        if accel.Magnitude > 2 and accel.Magnitude < 50 then
            predicted = predicted + accel * totalPred * totalPred * 0.5
        end
    end

    -- ===== JUMP/FALL PREDICTION (FIXED) =====
    if CFG.PredictJump or CFG.PredictFall then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            local state = hum:GetState()
            local gravity = workspace.Gravity or 196.2

            if state == Enum.HumanoidStateType.Jumping and CFG.PredictJump then
                -- FIXED: Правильная физика прыжка
                local vy = rawVel.Y
                local yOffset = vy * totalPred - 0.5 * gravity * totalPred * totalPred
                predicted = predicted + Vector3.new(0, yOffset, 0)
                -- Убираем Y из velocity prediction чтобы не дублировать
                predicted = Vector3.new(
                    predicted.X,
                    headPos.Y + yOffset,
                    predicted.Z
                )
            elseif state == Enum.HumanoidStateType.Freefall and CFG.PredictFall then
                -- FIXED: Правильная физика падения
                local vy = rawVel.Y
                local yOffset = vy * totalPred - 0.5 * gravity * totalPred * totalPred
                predicted = Vector3.new(
                    predicted.X,
                    headPos.Y + yOffset,
                    predicted.Z
                )
            end
        end
    end

    -- ===== BULLET DROP =====
    if CFG.BulletDrop > 0 and distance > 50 then
        local bulletTime = distance / CFG.BulletSpeed
        local gravity = workspace.Gravity or 196.2
        local drop = 0.5 * gravity * bulletTime * bulletTime * CFG.BulletDrop
        predicted = predicted + Vector3.new(0, drop, 0)
    end

    -- ===== HEAD OFFSET =====
    if CFG.HeadOffset ~= 0 then
        predicted = predicted + Vector3.new(0, CFG.HeadOffset, 0)
    end

    -- ===== RESOLVER / SANITY CHECK (FIXED) =====
    if CFG.ResolverEnabled then
        local predOffset = predicted - headPos
        local maxDist = finalVel.Magnitude * totalPred * 1.5 + 10

        -- FIXED: Если предсказание улетело слишком далеко - ограничиваем
        if predOffset.Magnitude > maxDist then
            predicted = headPos + predOffset.Unit * maxDist
        end

        -- FIXED: Если скорость игрока очень маленькая (стоит на месте),
        -- предсказание должно быть минимальным
        if finalVel.Magnitude < 2 then
            predicted = headPos + Vector3.new(0, CFG.HeadOffset, 0)
        end
    end

    return predicted
end

-- ==================== SILENT AIM HOOKS (FIXED) ====================
local silentActive = false
local oldNamecall = nil

local function ShouldSilent()
    return CFG.Enabled and CFG.SilentAim and Aiming and Target ~= nil
end

-- FIXED: Вспомогательная функция для безопасного вычисления direction
local function GetSilentDirection(origin, predictedPos, originalDir)
    if not origin or not predictedPos then return originalDir end
    local dir = (predictedPos - origin)
    if dir.Magnitude < 0.001 then return originalDir end

    -- FIXED: Сохраняем ДЛИНУ оригинального direction
    if typeof(originalDir) == "Vector3" and originalDir.Magnitude > 0 then
        return dir.Unit * originalDir.Magnitude
    end
    return dir
end

-- ========== МЕТОД 1: hookmetamethod (лучший) ==========
if not silentActive and hookmetamethod and getnamecallmethod then
    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure and newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if ShouldSilent() then
                local predictedPos = PredictHeadPos()
                if predictedPos then
                    -- FIXED: workspace:Raycast(origin, direction, params)
                    if method == "Raycast" and self == workspace then
                        local origin = args[1]
                        if typeof(origin) == "Vector3" then
                            local originalDir = args[2]
                            -- FIXED: Сохраняем длину оригинального direction
                            args[2] = GetSilentDirection(origin, predictedPos, originalDir)
                            return oldNamecall(self, unpack(args))
                        end
                    end

                    -- FIXED: FindPartOnRay варианты
                    if method == "FindPartOnRayWithIgnoreList"
                    or method == "FindPartOnRayWithWhitelist"
                    or method == "FindPartOnRay" then
                        local ray = args[1]
                        if typeof(ray) == "Ray" then
                            local newDir = (predictedPos - ray.Origin)
                            -- FIXED: Сохраняем длину оригинального ray
                            if newDir.Magnitude > 0.001 then
                                args[1] = Ray.new(
                                    ray.Origin,
                                    newDir.Unit * ray.Direction.Magnitude
                                )
                            end
                            return oldNamecall(self, unpack(args))
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end) or function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if ShouldSilent() then
                local predictedPos = PredictHeadPos()
                if predictedPos then
                    if method == "Raycast" and self == workspace then
                        local origin = args[1]
                        if typeof(origin) == "Vector3" then
                            local originalDir = args[2]
                            args[2] = GetSilentDirection(origin, predictedPos, originalDir)
                            return oldNamecall(self, unpack(args))
                        end
                    end

                    if method == "FindPartOnRayWithIgnoreList"
                    or method == "FindPartOnRayWithWhitelist"
                    or method == "FindPartOnRay" then
                        local ray = args[1]
                        if typeof(ray) == "Ray" then
                            local newDir = (predictedPos - ray.Origin)
                            if newDir.Magnitude > 0.001 then
                                args[1] = Ray.new(ray.Origin, newDir.Unit * ray.Direction.Magnitude)
                            end
                            return oldNamecall(self, unpack(args))
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)

    if ok then
        silentActive = true
        SilentMethod = "hookmetamethod"
        print("[SilentAim] METHOD 1 (hookmetamethod) LOADED")
    else
        warn("[SilentAim] Method 1 failed:", err)
    end
end

-- ========== МЕТОД 2: getrawmetatable + __namecall ==========
if not silentActive and getrawmetatable and setreadonly then
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local oldNC = mt.__namecall

        local newFunc = function(self, ...)
            local method = ""
            pcall(function()
                method = getnamecallmethod and getnamecallmethod() or ""
            end)
            method = tostring(method or "")
            local args = {...}

            if ShouldSilent() then
                local predictedPos = PredictHeadPos()
                if predictedPos then
                    if method == "Raycast" and self == workspace then
                        local origin = args[1]
                        if typeof(origin) == "Vector3" then
                            args[2] = GetSilentDirection(origin, predictedPos, args[2])
                            return oldNC(self, unpack(args))
                        end
                    end

                    if method == "FindPartOnRayWithIgnoreList"
                    or method == "FindPartOnRayWithWhitelist"
                    or method == "FindPartOnRay" then
                        local ray = args[1]
                        if typeof(ray) == "Ray" then
                            local newDir = (predictedPos - ray.Origin)
                            if newDir.Magnitude > 0.001 then
                                args[1] = Ray.new(ray.Origin, newDir.Unit * ray.Direction.Magnitude)
                            end
                            return oldNC(self, unpack(args))
                        end
                    end
                end
            end
            return oldNC(self, ...)
        end

        if newcclosure then
            mt.__namecall = newcclosure(newFunc)
        else
            mt.__namecall = newFunc
        end

        setreadonly(mt, true)
        oldNamecall = oldNC
    end)

    if ok then
        silentActive = true
        SilentMethod = "getrawmetatable"
        print("[SilentAim] METHOD 2 (getrawmetatable) LOADED")
    else
        warn("[SilentAim] Method 2 failed:", err)
    end
end

-- ========== МЕТОД 3: Mouse.Hit + __index override ==========
if not silentActive and getrawmetatable then
    local ok, err = pcall(function()
        local mouseMT = getrawmetatable(Mouse)
        if not mouseMT then error("no mouseMT") end
        if setreadonly then setreadonly(mouseMT, false) end
        local oldIndex = mouseMT.__index

        local newIndex = function(self, key)
            if ShouldSilent() and Target and Target.Character then
                local pred = PredictHeadPos()
                if pred then
                    if key == "Hit" then
                        return CFrame.new(pred)
                    end
                    if key == "Target" then
                        return Target.Character:FindFirstChild(CFG.HitPart)
                            or Target.Character:FindFirstChild("Head")
                    end
                    if key == "X" then return pred.X end
                    if key == "Y" then return pred.Y end
                    if key == "Z" then return pred.Z end
                    -- FIXED: Добавлены UnitRay и Origin для полной совместимости
                    if key == "UnitRay" then
                        local origin = Cam.CFrame.Position
                        return Ray.new(origin, (pred - origin).Unit)
                    end
                end
            end
            if type(oldIndex) == "function" then
                return oldIndex(self, key)
            else
                return oldIndex[key]
            end
        end

        if newcclosure then
            mouseMT.__index = newcclosure(newIndex)
        else
            mouseMT.__index = newIndex
        end
        if setreadonly then setreadonly(mouseMT, true) end
    end)

    if ok then
        silentActive = true
        SilentMethod = "Mouse.Hit"
        print("[SilentAim] METHOD 3 (Mouse.Hit) LOADED")
    else
        warn("[SilentAim] Method 3 failed:", err)
    end
end

-- ========== МЕТОД 4: Remote Intercept (FIXED - replaces broken LAST_RESORT) ==========
if not silentActive then
    -- FIXED: Вместо бесполезного Mouse.Hit = CFrame (read-only),
    -- пытаемся перехватить Remote Events
    local ok2 = false

    if hookfunction then
        pcall(function()
            -- Перехватываем FireServer для всех RemoteEvent'ов
            -- Это работает в Da Hood для перенаправления пуль
            for _, remote in ipairs(game:GetDescendants()) do
                if remote:IsA("RemoteEvent") and
                   (remote.Name:lower():find("shoot") or
                    remote.Name:lower():find("fire") or
                    remote.Name:lower():find("gun") or
                    remote.Name:lower():find("hit")) then

                    local oldFire = remote.FireServer
                    hookfunction(oldFire, function(self, ...)
                        if ShouldSilent() then
                            local pred = PredictHeadPos()
                            if pred then
                                local args = {...}
                                -- Пытаемся найти и заменить CFrame/Vector3 аргументы
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "CFrame" then
                                        args[i] = CFrame.new(pred)
                                    elseif typeof(arg) == "Vector3" then
                                        args[i] = pred
                                    end
                                end
                                return oldFire(self, unpack(args))
                            end
                        end
                        return oldFire(self, ...)
                    end)
                    ok2 = true
                end
            end
        end)
    end

    if ok2 then
        silentActive = true
        SilentMethod = "RemoteHook"
        print("[SilentAim] METHOD 4 (RemoteHook) LOADED")
    else
        warn("[SilentAim] All methods failed. Using visual-only mode.")
        SilentMethod = "VISUAL_ONLY"
        silentActive = false
    end
end

if silentActive then
    Notify("Silent Aim", "Method: " .. SilentMethod, 4)
    print("[SilentAim] Active method:", SilentMethod)
else
    Notify("⚠️ WARNING", "Silent aim hooks failed!\nVisual-only mode.", 5)
end

-- ==================== INPUT (FIXED) ====================
local lastShoot = 0

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end

    -- FIXED: Aim key handling centralized
    local isAimKey = false
    if CFG.AimKey == "MB2" and inp.UserInputType == Enum.UserInputType.MouseButton2 then isAimKey = true
    elseif CFG.AimKey == "MB1" and inp.UserInputType == Enum.UserInputType.MouseButton1 then isAimKey = true
    elseif CFG.AimKey == "Q" and inp.KeyCode == Enum.KeyCode.Q then isAimKey = true
    elseif CFG.AimKey == "E" and inp.KeyCode == Enum.KeyCode.E then isAimKey = true
    elseif CFG.AimKey == "C" and inp.KeyCode == Enum.KeyCode.C then isAimKey = true
    end

    if isAimKey then
        Aiming = true
        -- FIXED: Сразу ищем цель при начале прицеливания
        GetTarget()
    end

    -- Shoot effects
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - lastShoot > 0.08 then
            lastShoot = tick()

            if (CFG.BulletTrail or CFG.MuzzleFlash or CFG.HitMarker) then
                local ch = LP.Character
                if ch then
                    local tool = ch:FindFirstChildOfClass("Tool")
                    if tool then
                        local handle = tool:FindFirstChild("Handle")
                        local origin = handle and handle.Position
                            or (ch:FindFirstChild("Head") and ch.Head.Position)

                        if origin then
                            local target = Mouse.Hit.Position

                            if CFG.MuzzleFlash then
                                task.spawn(function()
                                    local flash = Instance.new("Part")
                                    flash.Size = Vector3.new(1.5, 1.5, 1.5)
                                    flash.Position = origin
                                    flash.Anchored = true
                                    flash.CanCollide = false
                                    flash.Shape = Enum.PartType.Ball
                                    flash.Material = Enum.Material.Neon
                                    flash.Color = Color3.fromRGB(255, 200, 50)
                                    flash.Transparency = 0.3
                                    flash.Parent = workspace

                                    for i = 0, 5 do
                                        pcall(function()
                                            flash.Size = Vector3.new(1.5 - i * 0.25, 1.5 - i * 0.25, 1.5 - i * 0.25)
                                            flash.Transparency = 0.3 + i * 0.14
                                        end)
                                        task.wait(0.02)
                                    end
                                    pcall(function() flash:Destroy() end)
                                end)
                            end

                            if CFG.BulletTrail then
                                task.spawn(function()
                                    local dir = target - origin
                                    local dist = dir.Magnitude
                                    if dist > 0.5 and dist < 500 then
                                        local mid = origin + dir / 2
                                        local trail = Instance.new("Part")
                                        trail.Size = Vector3.new(0.15, 0.15, dist)
                                        trail.CFrame = CFrame.new(mid, target)
                                        trail.Anchored = true
                                        trail.CanCollide = false
                                        trail.Material = Enum.Material.Neon
                                        trail.Color = CFG.BulletTrailRainbow
                                            and Color3.fromHSV((tick() * 0.3) % 1, 1, 1)
                                            or CFG.BulletTrailColor
                                        trail.Parent = workspace

                                        for i = 0, 10 do
                                            pcall(function() trail.Transparency = i / 10 end)
                                            task.wait(0.02)
                                        end
                                        pcall(function() trail:Destroy() end)
                                    end
                                end)
                            end

                            if CFG.HitMarker and Target then
                                task.spawn(function()
                                    local size = 20
                                    local ccx = Cam.ViewportSize.X / 2
                                    local ccy = Cam.ViewportSize.Y / 2
                                    local lines = {}
                                    for i = 1, 4 do
                                        lines[i] = Draw("Line", {
                                            Thickness = 2,
                                            Color = Color3.fromRGB(255, 50, 50),
                                            Visible = true
                                        })
                                    end
                                    if lines[1] and lines[2] and lines[3] and lines[4] then
                                        lines[1].From = Vector2.new(ccx-size, ccy-size)
                                        lines[1].To = Vector2.new(ccx-size/3, ccy-size/3)
                                        lines[2].From = Vector2.new(ccx+size, ccy-size)
                                        lines[2].To = Vector2.new(ccx+size/3, ccy-size/3)
                                        lines[3].From = Vector2.new(ccx-size, ccy+size)
                                        lines[3].To = Vector2.new(ccx-size/3, ccy+size/3)
                                        lines[4].From = Vector2.new(ccx+size, ccy+size)
                                        lines[4].To = Vector2.new(ccx+size/3, ccy+size/3)

                                        task.wait(0.3)
                                        for _, l in ipairs(lines) do
                                            pcall(function() l:Remove() end)
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

UIS.InputEnded:Connect(function(inp)
    local isAimKey = false
    if CFG.AimKey == "MB2" and inp.UserInputType == Enum.UserInputType.MouseButton2 then isAimKey = true
    elseif CFG.AimKey == "MB1" and inp.UserInputType == Enum.UserInputType.MouseButton1 then isAimKey = true
    elseif CFG.AimKey == "Q" and inp.KeyCode == Enum.KeyCode.Q then isAimKey = true
    elseif CFG.AimKey == "E" and inp.KeyCode == Enum.KeyCode.E then isAimKey = true
    elseif CFG.AimKey == "C" and inp.KeyCode == Enum.KeyCode.C then isAimKey = true
    end

    if isAimKey then
        Aiming = false
        -- FIXED: Не сбрасываем Target сразу, позволяем re-aim
    end
end)

-- ==================== EFFECTS (unchanged, kept as-is) ====================
local function ClearEffect(name)
    if ActiveEffects[name] then
        pcall(function() ActiveEffects[name]:Destroy() end)
        ActiveEffects[name] = nil
    end
end

local function ClearAll()
    for n in pairs(ActiveEffects) do ClearEffect(n) end
end

local function GetChar() return LP.Character end
local function GetRoot()
    local ch = GetChar()
    return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function GetTorso()
    local ch = GetChar()
    return ch and (ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso"))
end
local function GetHead()
    local ch = GetChar()
    return ch and ch:FindFirstChild("Head")
end

local function NeonPart(parent, size, color, trans)
    local p = Instance.new("Part")
    p.Size = size
    p.Material = Enum.Material.Neon
    p.Color = color
    p.CanCollide = false
    p.Anchored = false
    p.Transparency = trans or 0
    p.Parent = parent
    return p
end

local function CreateWings()
    ClearEffect("Wings")
    local torso = GetTorso()
    if not torso then return end
    local folder = Instance.new("Model")
    folder.Name = "W"; folder.Parent = torso
    ActiveEffects["Wings"] = folder

    local styles = {
        Angel = {c = Color3.fromRGB(255,255,255), g = Color3.fromRGB(255,215,0), n = 8},
        Demon = {c = Color3.fromRGB(30,0,0), g = Color3.fromRGB(255,0,0), n = 6},
        Fire  = {c = Color3.fromRGB(255,100,0), g = Color3.fromRGB(255,200,0), n = 7},
        Ice   = {c = Color3.fromRGB(150,200,255), g = Color3.fromRGB(200,230,255), n = 7},
        Rainbow = {c = Color3.new(1,1,1), g = Color3.new(1,1,1), n = 8, r = true},
    }
    local st = styles[CFG.WingStyle] or styles.Angel

    local function MW(side)
        local parts = {}
        for i = 1, st.n do
            local f = NeonPart(folder, Vector3.new(4.5-(i-1)*0.3, 0.15, 0.15), st.c, 0.1)
            local w = Instance.new("Weld")
            w.Part0 = torso; w.Part1 = f
            w.C0 = CFrame.new(side*(0.3+(i-1)*0.15), 0.3+(i-1)*0.15, 0.5)
                * CFrame.Angles(0, math.rad(side*-70), math.rad(side*(20+(i-1)*8)*30/57.3))
            w.Parent = f
            Instance.new("PointLight", f).Color = st.g
            table.insert(parts, {p=f, w=w, bc=w.C0, i=i})
        end
        return parts
    end

    local lw = MW(-1); local rw = MW(1)

    task.spawn(function()
        local t = 0
        while Alive and ActiveEffects["Wings"] and CFG.Wings do
            t = t + 0.08
            local flap = math.sin(t) * 0.3
            for _, f in ipairs(lw) do
                pcall(function()
                    f.w.C0 = f.bc * CFrame.Angles(0, 0, flap + math.sin(t+f.i*0.3)*0.15)
                    if st.r or CFG.AuraRainbow then
                        f.p.Color = Color3.fromHSV(((tick()*0.2)+(f.i*0.1))%1, 1, 1)
                    end
                end)
            end
            for _, f in ipairs(rw) do
                pcall(function()
                    f.w.C0 = f.bc * CFrame.Angles(0, 0, -flap - math.sin(t+f.i*0.3)*0.15)
                    if st.r or CFG.AuraRainbow then
                        f.p.Color = Color3.fromHSV(((tick()*0.2)+(f.i*0.1)+0.5)%1, 1, 1)
                    end
                end)
            end
            task.wait(0.03)
        end
    end)
end

local function CreateAura()
    ClearEffect("Aura")
    local root = GetRoot()
    if not root then return end
    local folder = Instance.new("Folder")
    folder.Parent = root
    ActiveEffects["Aura"] = folder

    local ground = NeonPart(folder, Vector3.new(6,0.1,6), CFG.BulletTrailColor, 0.5)
    ground.Shape = Enum.PartType.Cylinder
    local gw = Instance.new("Weld")
    gw.Part0 = root; gw.Part1 = ground
    gw.C0 = CFrame.new(0,-3,0) * CFrame.Angles(0,0,math.rad(90))
    gw.Parent = ground

    local att = Instance.new("Attachment", root)
    att.Parent = folder

    local e = Instance.new("ParticleEmitter")
    e.Rate = 100; e.Lifetime = NumberRange.new(0.5, 1.2)
    e.Speed = NumberRange.new(2, 5)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
    e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
    e.Texture = "rbxassetid://6823507655"
    e.LightEmission = 1
    e.Color = ColorSequence.new(CFG.BulletTrailColor)
    e.Parent = att

    local light = Instance.new("PointLight")
    light.Brightness = 4; light.Range = 20
    light.Color = CFG.BulletTrailColor
    light.Parent = folder

    task.spawn(function()
        while Alive and ActiveEffects["Aura"] and CFG.Aura do
            if CFG.AuraRainbow then
                local c = Color3.fromHSV((tick()*0.15)%1, 1, 1)
                pcall(function()
                    e.Color = ColorSequence.new(c)
                    light.Color = c; ground.Color = c
                end)
            end
            task.wait(0.05)
        end
    end)
end

local function CreateHalo()
    ClearEffect("Halo")
    local head = GetHead()
    if not head then return end
    local halo = NeonPart(head, Vector3.new(3,0.15,3), Color3.fromRGB(255,215,0), 0.1)
    halo.Shape = Enum.PartType.Cylinder
    ActiveEffects["Halo"] = halo
    local w = Instance.new("Weld")
    w.Part0 = head; w.Part1 = halo
    w.C0 = CFrame.new(0,1.5,0) * CFrame.Angles(0,0,math.rad(90))
    w.Parent = halo
    Instance.new("PointLight", halo).Color = Color3.fromRGB(255,215,0)
    task.spawn(function()
        local t = 0
        while Alive and ActiveEffects["Halo"] and CFG.Halo do
            t = t + 0.05
            pcall(function()
                w.C0 = CFrame.new(0, 1.5+math.sin(t)*0.1, 0)
                    * CFrame.Angles(0, math.rad(t*20), math.rad(90))
                if CFG.AuraRainbow then
                    halo.Color = Color3.fromHSV((tick()*0.15)%1, 1, 1)
                end
            end)
            task.wait(0.03)
        end
    end)
end

local function CreateGlow()
    ClearEffect("BodyGlow")
    local ch = GetChar()
    if not ch then return end
    local folder = Instance.new("Folder")
    folder.Parent = ch
    ActiveEffects["BodyGlow"] = folder
    local hl = Instance.new("Highlight")
    hl.FillColor = CFG.BulletTrailColor
    hl.FillTransparency = 0.5
    hl.OutlineColor = CFG.BulletTrailColor
    hl.Adornee = ch
    hl.Parent = folder
    task.spawn(function()
        while Alive and ActiveEffects["BodyGlow"] and CFG.BodyGlow do
            if CFG.AuraRainbow then
                local c = Color3.fromHSV((tick()*0.15)%1, 1, 1)
                pcall(function() hl.FillColor = c; hl.OutlineColor = c end)
            end
            pcall(function() hl.FillTransparency = math.sin(tick()*3)*0.2+0.5 end)
            task.wait(0.05)
        end
    end)
end

local function CreateTrail()
    ClearEffect("Trail")
    local root = GetRoot()
    if not root then return end
    local folder = Instance.new("Folder")
    folder.Parent = root
    ActiveEffects["Trail"] = folder

    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0,2.5,0); a0.Parent = root
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0,-3,0); a1.Parent = root

    local trail = Instance.new("Trail")
    trail.Attachment0 = a0; trail.Attachment1 = a1
    trail.Lifetime = 1.2; trail.LightEmission = 1; trail.FaceCamera = true
    trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0,1.5), NumberSequenceKeypoint.new(1,0)})
    trail.Color = ColorSequence.new(CFG.BulletTrailColor)
    trail.Texture = "rbxassetid://6823507655"
    a0.Parent = folder; a1.Parent = folder; trail.Parent = folder

    task.spawn(function()
        while Alive and ActiveEffects["Trail"] and CFG.Trail do
            if CFG.TrailRainbow then
                local h1 = (tick()*0.3)%1
                pcall(function()
                    trail.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(h1,1,1)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV((h1+0.3)%1,1,1))
                    })
                end)
            end
            task.wait(0.05)
        end
    end)
end

local function CreateRings()
    ClearEffect("Rings")
    local root = GetRoot()
    if not root then return end
    local folder = Instance.new("Folder")
    folder.Parent = workspace
    ActiveEffects["Rings"] = folder
    local rings = {}
    for i = 1, 4 do
        local r = NeonPart(folder, Vector3.new(8-i,0.3,8-i), Color3.fromRGB(120,80,255), 0.2)
        r.Shape = Enum.PartType.Cylinder; r.Anchored = true; rings[i] = r
    end
    task.spawn(function()
        local t = 0
        while Alive and ActiveEffects["Rings"] and CFG.FloatingRings do
            t = t + 0.02
            local r = GetRoot()
            if r then
                for i, ring in ipairs(rings) do
                    pcall(function()
                        ring.CFrame = CFrame.new(r.Position + Vector3.new(0, math.sin(t*2+(i-1)*math.pi/2)*2+(i-2), 0))
                            * CFrame.Angles(math.rad(t*80+i*60), math.rad(t*40), math.rad(90))
                        if CFG.AuraRainbow then
                            ring.Color = Color3.fromHSV(((tick()*0.2)+(i*0.15))%1, 1, 1)
                        end
                    end)
                end
            end
            task.wait(0.02)
        end
        for _, r in ipairs(rings) do pcall(function() r:Destroy() end) end
    end)
end

local function CreateOrbs()
    ClearEffect("Orbs")
    local root = GetRoot()
    if not root then return end
    local folder = Instance.new("Folder")
    folder.Parent = workspace
    ActiveEffects["Orbs"] = folder
    local orbs = {}
    for i = 1, 6 do
        local o = NeonPart(folder, Vector3.new(0.8,0.8,0.8), CFG.BulletTrailColor, 0.2)
        o.Shape = Enum.PartType.Ball; o.Anchored = true
        orbs[i] = o
        local a0 = Instance.new("Attachment", o); a0.Position = Vector3.new(0.4,0,0)
        local a1 = Instance.new("Attachment", o); a1.Position = Vector3.new(-0.4,0,0)
        local tr = Instance.new("Trail", o)
        tr.Attachment0 = a0; tr.Attachment1 = a1
        tr.Lifetime = 0.5; tr.LightEmission = 1
        tr.Color = ColorSequence.new(CFG.BulletTrailColor)
        tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    end
    task.spawn(function()
        local t = 0
        while Alive and ActiveEffects["Orbs"] and CFG.Orbs do
            t = t + 0.03
            local r = GetRoot()
            if r then
                for i, o in ipairs(orbs) do
                    pcall(function()
                        local ang = t + (i-1)*(math.pi*2/6)
                        o.CFrame = CFrame.new(
                            r.Position.X + math.cos(ang)*4,
                            r.Position.Y + math.sin(t*2+i)*1.5,
                            r.Position.Z + math.sin(ang)*4
                        )
                        if CFG.AuraRainbow then
                            o.Color = Color3.fromHSV((tick()*0.2+i*0.15)%1, 1, 1)
                        end
                    end)
                end
            end
            task.wait(0.02)
        end
        for _, o in ipairs(orbs) do pcall(function() o:Destroy() end) end
    end)
end

local function UpdateEffects()
    if CFG.Wings then if not ActiveEffects["Wings"] then CreateWings() end else ClearEffect("Wings") end
    if CFG.Aura then if not ActiveEffects["Aura"] then CreateAura() end else ClearEffect("Aura") end
    if CFG.Halo then if not ActiveEffects["Halo"] then CreateHalo() end else ClearEffect("Halo") end
    if CFG.BodyGlow then if not ActiveEffects["BodyGlow"] then CreateGlow() end else ClearEffect("BodyGlow") end
    if CFG.Trail then if not ActiveEffects["Trail"] then CreateTrail() end else ClearEffect("Trail") end
    if CFG.FloatingRings then if not ActiveEffects["Rings"] then CreateRings() end else ClearEffect("Rings") end
    if CFG.Orbs then if not ActiveEffects["Orbs"] then CreateOrbs() end else ClearEffect("Orbs") end
end

LP.CharacterAdded:Connect(function()
    task.wait(2); ClearAll(); UpdateEffects()
end)
task.spawn(function() while Alive do UpdateEffects(); task.wait(1) end end)

-- ==================== DRAWINGS ====================
local fov = Draw("Circle", {Thickness=2, NumSides=100, Filled=false, Transparency=0.8, Visible=false})
local dot = Draw("Circle", {Thickness=2, NumSides=20, Filled=true, Radius=6, Transparency=1, Visible=false})
local line = Draw("Line", {Thickness=1.5, Transparency=0.8, Visible=false})
local info = Draw("Text", {Size=16, Font=2, Outline=true, Position=Vector2.new(10,10), Visible=false})
local pingTxt = Draw("Text", {Size=12, Font=2, Outline=true, Position=Vector2.new(10,32), Color=Color3.fromRGB(180,180,200), Visible=false})
local distTxt = Draw("Text", {Size=12, Font=2, Outline=true, Position=Vector2.new(10,50), Color=Color3.fromRGB(200,180,100), Visible=false})
local methodTxt = Draw("Text", {Size=12, Font=2, Outline=true, Position=Vector2.new(10,68), Color=Color3.fromRGB(100,255,100), Visible=false})
local watermark = Draw("Text", {Size=18, Font=2, Outline=true, Color=Color3.fromRGB(0,255,120), Visible=true})
local predLine = Draw("Line", {Thickness=2, Color=Color3.fromRGB(0,255,255), Transparency=0.6, Visible=false})
local headDot = Draw("Circle", {Thickness=2, NumSides=16, Filled=true, Radius=4, Color=Color3.fromRGB(0,255,120), Transparency=1, Visible=false})

local ESP = {}
local function MakeESP(plr)
    if plr == LP or ESP[plr] then return end
    ESP[plr] = {
        dot  = Draw("Circle", {Thickness=1, NumSides=14, Filled=true, Radius=4, Transparency=1, Visible=false}),
        name = Draw("Text", {Size=12, Center=true, Outline=true, Font=2, Visible=false}),
        hp   = Draw("Text", {Size=11, Center=true, Outline=true, Font=2, Visible=false}),
        dist = Draw("Text", {Size=10, Center=true, Outline=true, Font=2, Color=Color3.fromRGB(180,180,180), Visible=false}),
    }
end

local function KillESP(plr)
    local e = ESP[plr]
    if not e then return end
    for _, v in pairs(e) do pcall(function() v:Remove() end) end
    ESP[plr] = nil
    VelHistory[plr] = nil
    PosHistory[plr] = nil
end

-- ==================== RENDER (FIXED) ====================
-- FIXED: Добавлена очистка истории для disconnected игроков
local lastCleanup = 0

local rc = RS.RenderStepped:Connect(function()
    if not Alive then return end
    Cam = workspace.CurrentCamera
    local cx = Cam.ViewportSize.X / 2
    local cy = Cam.ViewportSize.Y / 2
    RainbowHue = (RainbowHue + 0.003) % 1

    -- FIXED: Периодическая очистка history для игроков которые ушли
    if tick() - lastCleanup > 5 then
        lastCleanup = tick()
        for plr in pairs(VelHistory) do
            if not plr or not plr.Parent then
                VelHistory[plr] = nil
                PosHistory[plr] = nil
            end
        end
    end

    if CFG.Enabled then GetTarget() else Target = nil end

    if watermark then
        watermark.Position = Vector2.new(Cam.ViewportSize.X - 290, 10)
        watermark.Text = "🎯 SILENT AIM v15F | " .. SilentMethod
        watermark.Color = silentActive and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 60, 60)
        watermark.Visible = true
    end

    if fov then
        fov.Visible = CFG.ShowFOV and CFG.Enabled
        fov.Position = Vector2.new(cx, cy)
        fov.Radius = CFG.FOV
        if CFG.RainbowFOV then
            fov.Color = Color3.fromHSV(RainbowHue, 1, 1)
        else
            fov.Color = Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(0,180,200)
        end
    end

    local pos = PredictHeadPos()
    if pos and CFG.Enabled then
        local sp, vis = Cam:WorldToViewportPoint(pos)
        if vis and sp.Z > 0 then
            if dot and CFG.ShowDot then
                dot.Position = Vector2.new(sp.X, sp.Y)
                dot.Color = Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50)
                dot.Visible = true
            end
            if line and CFG.ShowLine then
                line.From = Vector2.new(cx, cy); line.To = Vector2.new(sp.X, sp.Y)
                line.Color = Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(100,100,120)
                line.Visible = true
            end
            if CFG.ShowPredPath and Target and Target.Character and predLine then
                local hitPart = Target.Character:FindFirstChild(CFG.HitPart) or Target.Character:FindFirstChild("Head")
                if hitPart then
                    local csp, cv = Cam:WorldToViewportPoint(hitPart.Position)
                    if cv and csp.Z > 0 then
                        predLine.From = Vector2.new(csp.X, csp.Y)
                        predLine.To = Vector2.new(sp.X, sp.Y)
                        predLine.Visible = true
                        if headDot and CFG.ShowHeadDot then
                            headDot.Position = Vector2.new(csp.X, csp.Y)
                            headDot.Color = Color3.fromRGB(255,100,100)
                            headDot.Visible = true
                        end
                    else
                        predLine.Visible = false
                        if headDot then headDot.Visible = false end
                    end
                end
            else
                if predLine then predLine.Visible = false end
                if headDot then headDot.Visible = false end
            end
        else
            if dot then dot.Visible = false end
            if line then line.Visible = false end
            if predLine then predLine.Visible = false end
            if headDot then headDot.Visible = false end
        end
    else
        if dot then dot.Visible = false end
        if line then line.Visible = false end
        if predLine then predLine.Visible = false end
        if headDot then headDot.Visible = false end
    end

    if info then
        if CFG.Enabled then
            local status = Aiming and "🎯 LOCKED" or "🔍 SCAN"
            local targetName = Target and Target.Name or "-"
            info.Text = status .. "  " .. targetName
            info.Color = Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50)
            info.Visible = true
        else
            info.Visible = false
        end
    end

    if pingTxt then
        local ping = GetPing()
        pingTxt.Text = "Ping: " .. math.floor(ping) .. "ms"
        pingTxt.Color = ping < 80 and Color3.fromRGB(100,255,100)
            or ping < 150 and Color3.fromRGB(255,255,100)
            or Color3.fromRGB(255,100,100)
        pingTxt.Visible = CFG.Enabled
    end

    if methodTxt then
        methodTxt.Text = "Silent: " .. SilentMethod .. (silentActive and " ✓" or " ✗")
        methodTxt.Color = silentActive and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,80,80)
        methodTxt.Visible = CFG.Enabled
    end

    if distTxt then
        if CFG.Enabled and Target and Target.Character then
            local hitPart = Target.Character:FindFirstChild(CFG.HitPart) or Target.Character:FindFirstChild("Head")
            if hitPart then
                local myPos = GetMyPos()
                if myPos then
                    local d = (myPos - hitPart.Position).Magnitude
                    local pred = CalculatePredictionTime(d)
                    local bt = d / CFG.BulletSpeed
                    -- FIXED: Показываем velocity цели для отладки
                    local vel = 0
                    pcall(function()
                        vel = Target.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude
                    end)
                    distTxt.Text = string.format("D:%.0fm P:%.3fs B:%.3fs V:%.0f", d, pred, bt, vel)
                    distTxt.Visible = true
                else
                    distTxt.Visible = false
                end
            else
                distTxt.Visible = false
            end
        else
            distTxt.Visible = false
        end
    end

    -- ESP rendering
    for plr, e in pairs(ESP) do
        if not plr or not plr.Parent then
            KillESP(plr)
        elseif CFG.ShowESP and IsValid(plr) then
            local hitPart = plr.Character:FindFirstChild("Head")
            if hitPart then
                local sp, vis = Cam:WorldToViewportPoint(hitPart.Position)
                if vis and sp.Z > 0 then
                    local dist = 100
                    local myPos = GetMyPos()
                    if myPos then
                        dist = (myPos - hitPart.Position).Magnitude
                    end

                    if e.dot then
                        e.dot.Position = Vector2.new(sp.X, sp.Y)
                        e.dot.Radius = math.clamp(500/dist, 2, 8)
                        e.dot.Color = (Target == plr) and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,60,80)
                        e.dot.Visible = true
                    end
                    if e.name and CFG.ShowNames then
                        e.name.Text = plr.Name
                        e.name.Position = Vector2.new(sp.X, sp.Y-18)
                        e.name.Color = (Target == plr) and Color3.fromRGB(0,255,120) or Color3.new(1,1,1)
                        e.name.Visible = true
                    elseif e.name then e.name.Visible = false end
                    if e.hp and CFG.ShowHP then
                        local hp = 0
                        pcall(function() hp = math.floor(plr.Character:FindFirstChildOfClass("Humanoid").Health) end)
                        e.hp.Text = hp .. " HP"
                        e.hp.Position = Vector2.new(sp.X, sp.Y+10)
                        e.hp.Color = hp > 60 and Color3.fromRGB(100,255,100)
                            or hp > 30 and Color3.fromRGB(255,255,100)
                            or Color3.fromRGB(255,60,60)
                        e.hp.Visible = true
                    elseif e.hp then e.hp.Visible = false end
                    if e.dist and CFG.ShowDist then
                        e.dist.Text = math.floor(dist) .. "m"
                        e.dist.Position = Vector2.new(sp.X, sp.Y+22)
                        e.dist.Visible = true
                    elseif e.dist then e.dist.Visible = false end
                else
                    for _, v in pairs(e) do pcall(function() v.Visible = false end) end
                end
            else
                for _, v in pairs(e) do pcall(function() v.Visible = false end) end
            end
        else
            for _, v in pairs(e) do pcall(function() v.Visible = false end) end
        end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do MakeESP(p) end
Players.PlayerAdded:Connect(function(p) task.wait(1); MakeESP(p) end)
Players.PlayerRemoving:Connect(KillESP)

-- ==================== UI ====================
local G = Instance.new("ScreenGui")
G.Name = "DHP_" .. math.random(10000, 99999)
G.ResetOnSpawn = false

local guiParent = CG
pcall(function()
    if gethui then guiParent = gethui() end
end)
pcall(function() G.Parent = guiParent end)
if not G.Parent then pcall(function() G.Parent = LP.PlayerGui end) end

local Th = {
    bg     = Color3.fromRGB(10,10,16),
    card   = Color3.fromRGB(20,20,30),
    cardH  = Color3.fromRGB(28,28,42),
    accent = Color3.fromRGB(0,220,130),
    accent2= Color3.fromRGB(120,80,255),
    text   = Color3.fromRGB(235,235,245),
    dim    = Color3.fromRGB(100,100,130),
    on     = Color3.fromRGB(0,220,130),
    off    = Color3.fromRGB(50,50,65),
}

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 500, 0, 580)
Main.Position = UDim2.new(0.5, -250, 0.5, -290)
Main.BackgroundColor3 = Th.bg
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Main.Draggable = true
Main.Parent = G
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
local bs = Instance.new("UIStroke", Main)
bs.Thickness = 1.5; bs.Color = Th.accent; bs.Transparency = 0.4

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1,0,0,50)
topBar.BackgroundColor3 = Color3.fromRGB(14,14,22)
topBar.BorderSizePixel = 0; topBar.Parent = Main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 14)
local tf = Instance.new("Frame")
tf.Size = UDim2.new(1,0,0,14); tf.Position = UDim2.new(0,0,1,-14)
tf.BackgroundColor3 = Color3.fromRGB(14,14,22); tf.BorderSizePixel = 0; tf.Parent = topBar

local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(0,320,1,0); logo.Position = UDim2.new(0,16,0,0)
logo.BackgroundTransparency = 1; logo.Text = "🎯 SILENT AIM v15 FIXED"
logo.TextColor3 = Th.accent; logo.Font = Enum.Font.GothamBlack
logo.TextSize = 15; logo.TextXAlignment = Enum.TextXAlignment.Left; logo.Parent = topBar

local ver = Instance.new("TextLabel")
ver.Size = UDim2.new(0,50,0,20); ver.Position = UDim2.new(1,-70,0.5,-10)
ver.BackgroundColor3 = Th.accent; ver.TextColor3 = Color3.new(1,1,1)
ver.Font = Enum.Font.GothamBold; ver.TextSize = 10; ver.Text = "v15F"
ver.BorderSizePixel = 0; ver.Parent = topBar
Instance.new("UICorner", ver).CornerRadius = UDim.new(1, 0)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,-20,0,36); tabBar.Position = UDim2.new(0,10,0,54)
tabBar.BackgroundColor3 = Th.card; tabBar.BorderSizePixel = 0; tabBar.Parent = Main
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 8)
Instance.new("UIListLayout", tabBar).FillDirection = Enum.FillDirection.Horizontal

local allTabs = {"Aim","Range","Bullets","ESP","Effects","Info"}
local tabFrames = {}; local tabButtons = {}

for _, tn in ipairs(allTabs) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(1/#allTabs,0,1,0)
    tb.BackgroundTransparency = 1
    tb.Text = tn
    tb.TextColor3 = (tn == CurrentTab) and Th.accent or Th.dim
    tb.Font = Enum.Font.GothamBold; tb.TextSize = 11; tb.BorderSizePixel = 0
    tb.Parent = tabBar; tabButtons[tn] = tb
end

local scrollArea = Instance.new("Frame")
scrollArea.Size = UDim2.new(1,-20,1,-100); scrollArea.Position = UDim2.new(0,10,0,94)
scrollArea.BackgroundTransparency = 1; scrollArea.ClipsDescendants = true; scrollArea.Parent = Main

for _, tn in ipairs(allTabs) do
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,1,0); scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Th.accent; scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Visible = (tn == CurrentTab); scroll.Parent = scrollArea
    tabFrames[tn] = scroll
    Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 6)
    local p = Instance.new("UIPadding", scroll)
    p.PaddingTop = UDim.new(0,4); p.PaddingBottom = UDim.new(0,4)
end

for tn, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        CurrentTab = tn
        for n, f in pairs(tabFrames) do f.Visible = (n == tn) end
        for n, b in pairs(tabButtons) do
            Tw(b, {TextColor3 = (n == tn) and Th.accent or Th.dim}, 0.2)
        end
    end)
end

local function Sep(parent, text)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,22); f.BackgroundTransparency = 1; f.Parent = parent
    local l = Instance.new("Frame",f); l.Size = UDim2.new(0.2,0,0,1); l.Position = UDim2.new(0,0,0.5,0); l.BackgroundColor3 = Color3.fromRGB(40,40,55); l.BorderSizePixel = 0
    local t = Instance.new("TextLabel",f); t.Size = UDim2.new(0.6,0,1,0); t.Position = UDim2.new(0.2,0,0,0); t.BackgroundTransparency = 1; t.Text = string.upper(text); t.TextColor3 = Th.dim; t.Font = Enum.Font.GothamBold; t.TextSize = 10
    local r = Instance.new("Frame",f); r.Size = UDim2.new(0.2,0,0,1); r.Position = UDim2.new(0.8,0,0.5,0); r.BackgroundColor3 = Color3.fromRGB(40,40,55); r.BorderSizePixel = 0
end

local function Toggle(parent, name, key, icon)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,38); f.BackgroundColor3 = Th.card; f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
    f.MouseEnter:Connect(function() Tw(f,{BackgroundColor3=Th.cardH},0.15) end)
    f.MouseLeave:Connect(function() Tw(f,{BackgroundColor3=Th.card},0.15) end)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0.7,0,1,0); lbl.Position = UDim2.new(0,16,0,0); lbl.BackgroundTransparency = 1; lbl.Text = (icon or "") .. "  " .. name; lbl.TextColor3 = Th.text; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = f
    local sw = Instance.new("Frame"); sw.Size = UDim2.new(0,46,0,24); sw.Position = UDim2.new(1,-60,0.5,-12); sw.BorderSizePixel = 0; sw.Parent = f
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,20,0,20); knob.BorderSizePixel = 0; knob.BackgroundColor3 = Color3.new(1,1,1); knob.Parent = sw
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = f
    local function upd()
        if CFG[key] then
            Tw(sw,{BackgroundColor3=Th.on},0.2); Tw(knob,{Position=UDim2.new(1,-22,0.5,-10)},0.2)
        else
            Tw(sw,{BackgroundColor3=Th.off},0.2); Tw(knob,{Position=UDim2.new(0,2,0.5,-10)},0.2)
        end
    end
    upd()
    btn.MouseButton1Click:Connect(function() CFG[key] = not CFG[key]; upd(); UpdateEffects() end)
end

local function Slider(parent, name, key, mn, mx, dec)
    dec = dec or 0
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,50); f.BackgroundColor3 = Th.card; f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,-20,0,22); lbl.Position = UDim2.new(0,16,0,4); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Th.text; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = f
    local bar = Instance.new("Frame"); bar.Size = UDim2.new(1,-32,0,8); bar.Position = UDim2.new(0,16,0,32); bar.BackgroundColor3 = Th.off; bar.BorderSizePixel = 0; bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame"); fill.BorderSizePixel = 0; fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    Instance.new("UIGradient", fill).Color = ColorSequence.new(Th.accent2, Th.accent)
    local c = Instance.new("Frame"); c.Size = UDim2.new(0,16,0,16); c.BackgroundColor3 = Color3.new(1,1,1); c.BorderSizePixel = 0; c.ZIndex = 5; c.Parent = bar
    Instance.new("UICorner", c).CornerRadius = UDim.new(1,0)
    local function upd()
        local p = math.clamp((CFG[key]-mn)/(mx-mn), 0, 1)
        fill.Size = UDim2.new(p,0,1,0)
        c.Position = UDim2.new(p,-8,0.5,-8)
        lbl.Text = name .. "    " .. (dec>0 and string.format("%."..dec.."f", CFG[key]) or tostring(math.floor(CFG[key])))
    end
    upd()
    local drag = false
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local p = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = mn + (mx-mn)*p
            CFG[key] = dec>0 and math.floor(v*10^dec)/10^dec or math.floor(v)
            upd()
        end
    end)
end

local function BtnRow(parent, items)
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1; row.Parent = parent
    for i, item in ipairs(items) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1/#items,-4,1,0); b.Position = UDim2.new((i-1)*(1/#items),2,0,0)
        b.BackgroundColor3 = item.col or Th.card; b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.Text = item.name; b.BorderSizePixel = 0; b.Parent = row
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        b.MouseEnter:Connect(function() Tw(b,{BackgroundColor3=Th.accent},0.15) end)
        b.MouseLeave:Connect(function() Tw(b,{BackgroundColor3=item.col or Th.card},0.15) end)
        b.MouseButton1Click:Connect(function() item.cb(); UpdateEffects() end)
    end
end

-- BUILD TABS
local aim = tabFrames["Aim"]
Sep(aim, "🎯 Silent Aim")
Toggle(aim, "Silent Aim ON/OFF", "SilentAim", "🎯")
Toggle(aim, "Master Enable", "Enabled", "⚡")
Toggle(aim, "Smart Prediction", "SmartPrediction", "🧠")
Slider(aim, "FOV", "FOV", 30, 500)
Sep(aim, "Hit Part")
BtnRow(aim, {
    {name="Head", col=Color3.fromRGB(200,40,40), cb=function() CFG.HitPart="Head"; Notify("Target","Head",2) end},
    {name="Body", col=Color3.fromRGB(40,120,200), cb=function() CFG.HitPart="HumanoidRootPart"; Notify("Target","Body",2) end},
})
Sep(aim, "Aim Key")
BtnRow(aim, {
    {name="RMB", col=Th.card, cb=function() CFG.AimKey="MB2"; Notify("Key","RMB",1) end},
    {name="LMB", col=Th.card, cb=function() CFG.AimKey="MB1"; Notify("Key","LMB",1) end},
    {name="Q",   col=Th.card, cb=function() CFG.AimKey="Q"; Notify("Key","Q",1) end},
    {name="E",   col=Th.card, cb=function() CFG.AimKey="E"; Notify("Key","E",1) end},
    {name="C",   col=Th.card, cb=function() CFG.AimKey="C"; Notify("Key","C",1) end},
})
Sep(aim, "Filters")
Toggle(aim, "Team Check", "TeamCheck", "👥")
Toggle(aim, "Ignore Downed", "NoDowned", "💀")
Toggle(aim, "Ignore Cuffed", "NoCuffed", "🔗")
Toggle(aim, "Wall Check", "IgnoreWalls", "🧱")

local rng = tabFrames["Range"]
Sep(rng, "🔭 Prediction")
Toggle(rng, "Distance Prediction", "DistancePrediction", "📏")
Toggle(rng, "Ping Compensation", "PingComp", "📡")
Toggle(rng, "Predict Jump", "PredictJump", "🦘")
Toggle(rng, "Predict Fall", "PredictFall", "⬇️")
Toggle(rng, "Use Acceleration", "UseAccel", "📈")
Toggle(rng, "Resolver", "ResolverEnabled", "🔧")
Sep(rng, "Timing")
Slider(rng, "Base Pred (close)", "BasePred", 0.05, 0.3, 3)
Slider(rng, "Max Pred (far)", "MaxPred", 0.05, 0.5, 3)
Slider(rng, "Distance Scale", "DistanceScale", 50, 500)
Slider(rng, "Bullet Speed", "BulletSpeed", 500, 2000)
Slider(rng, "Bullet Drop", "BulletDrop", 0, 2, 2)
Sep(rng, "Fine Tune")
Slider(rng, "Head Offset", "HeadOffset", -1, 1, 2)
Slider(rng, "Velocity Comp", "VelocityComp", 0.5, 2, 2)
Slider(rng, "Velocity Smoothing", "VelocitySmoothing", 0, 1, 2)
Sep(rng, "Priority")
BtnRow(rng, {
    {name="Distance", col=Color3.fromRGB(40,120,200), cb=function() CFG.TargetPriority="Distance"; Notify("Priority","Distance",1) end},
    {name="Low HP", col=Color3.fromRGB(200,40,60), cb=function() CFG.TargetPriority="HP"; Notify("Priority","Low HP",1) end},
})
Sep(rng, "Da Hood Presets")
BtnRow(rng, {
    {name="Fists", col=Color3.fromRGB(0,180,80), cb=function()
        CFG.BasePred=0.145; CFG.MaxPred=0.145; CFG.BulletSpeed=2000; CFG.BulletDrop=0
        CFG.DistancePrediction=false; CFG.UseAccel=false
        Notify("Preset","Fists (0.145)",2)
    end},
    {name="Pistol", col=Color3.fromRGB(180,160,0), cb=function()
        CFG.BasePred=0.145; CFG.MaxPred=0.165; CFG.BulletSpeed=1500; CFG.BulletDrop=0
        CFG.DistancePrediction=true; CFG.UseAccel=false
        Notify("Preset","Pistol (0.145-0.165)",2)
    end},
    {name="AR", col=Color3.fromRGB(200,80,40), cb=function()
        CFG.BasePred=0.148; CFG.MaxPred=0.175; CFG.BulletSpeed=1300; CFG.BulletDrop=0
        CFG.DistancePrediction=true; CFG.UseAccel=false
        Notify("Preset","Auto Rifle (0.148-0.175)",2)
    end},
    {name="Sniper", col=Color3.fromRGB(200,40,40), cb=function()
        CFG.BasePred=0.15; CFG.MaxPred=0.2; CFG.BulletSpeed=1000; CFG.BulletDrop=0.5
        CFG.DistancePrediction=true; CFG.UseAccel=true
        Notify("Preset","Sniper (0.15-0.2)",2)
    end},
})

local bul = tabFrames["Bullets"]
Sep(bul, "Bullet Effects")
Toggle(bul, "Bullet Trail", "BulletTrail", "💫")
Toggle(bul, "Rainbow Trail", "BulletTrailRainbow", "🌈")
Toggle(bul, "Muzzle Flash", "MuzzleFlash", "🔥")
Toggle(bul, "Hit Marker", "HitMarker", "✖️")

local espT = tabFrames["ESP"]
Sep(espT, "ESP")
Toggle(espT, "ESP", "ShowESP", "👁")
Toggle(espT, "Names", "ShowNames", "📝")
Toggle(espT, "HP", "ShowHP", "❤️")
Toggle(espT, "Distance", "ShowDist", "📏")
Sep(espT, "Aim Visuals")
Toggle(espT, "FOV Circle", "ShowFOV", "⭕")
Toggle(espT, "Rainbow FOV", "RainbowFOV", "🌈")
Toggle(espT, "Target Dot", "ShowDot", "🔴")
Toggle(espT, "Target Line", "ShowLine", "📍")
Toggle(espT, "Prediction Path", "ShowPredPath", "📐")
Toggle(espT, "Head Marker", "ShowHeadDot", "🎯")

local fx = tabFrames["Effects"]
Sep(fx, "Character Effects")
Toggle(fx, "Wings", "Wings", "🪽")
BtnRow(fx, {
    {name="Angel", col=Color3.fromRGB(255,215,0), cb=function() CFG.WingStyle="Angel"; ClearEffect("Wings") end},
    {name="Demon", col=Color3.fromRGB(150,0,0), cb=function() CFG.WingStyle="Demon"; ClearEffect("Wings") end},
    {name="Fire", col=Color3.fromRGB(255,100,0), cb=function() CFG.WingStyle="Fire"; ClearEffect("Wings") end},
    {name="🌈", col=Color3.fromRGB(255,50,150), cb=function() CFG.WingStyle="Rainbow"; ClearEffect("Wings") end},
})
Toggle(fx, "Aura", "Aura", "✨")
Toggle(fx, "Glow", "BodyGlow", "💡")
Toggle(fx, "Halo", "Halo", "😇")
Toggle(fx, "Trail", "Trail", "🌊")
Toggle(fx, "Rainbow", "AuraRainbow", "🌈")
Toggle(fx, "Rings", "FloatingRings", "💫")
Toggle(fx, "Orbs", "Orbs", "🔮")

local infoT = tabFrames["Info"]
Sep(infoT, "ℹ️ Info")
local hlp = Instance.new("TextLabel")
hlp.Size = UDim2.new(1,0,0,300)
hlp.BackgroundColor3 = Th.card
hlp.TextColor3 = Color3.new(1,1,1)
hlp.Font = Enum.Font.Gotham
hlp.TextSize = 11
hlp.TextWrapped = true
hlp.Text = [[🎯 SILENT AIM v15 FIXED

=== ЧТО ИСПРАВЛЕНО ===
✅ Prediction: убрана двойная ping компенсация
✅ Prediction: правильная физика прыжка/падения
✅ Velocity: экспоненциальное затухание вместо линейного
✅ Silent hooks: сохраняется длина Ray direction
✅ Wall check: правильная фильтрация персонажей
✅ Teleport detection: очистка history при телепорте
✅ Resolver: стоящие игроки = нулевая prediction
✅ Target: проверка Z > 0 (перед камерой)
✅ Method 4: RemoteHook вместо сломанного LAST_RESORT

=== МЕТОДЫ (по приоритету) ===
1. hookmetamethod - лучший (Synapse/KRNL/Fluxus)
2. getrawmetatable - альтернативный
3. Mouse.Hit override - fallback
4. RemoteHook - последний шанс

=== КАК ИСПОЛЬЗОВАТЬ ===
1. Держи RMB (или выбранную кнопку)
2. Стреляй LMB — пули летят в голову
3. Используй пресеты под оружие (Range таб)

⚙️ ПРЕСЕТЫ (Range → Da Hood Presets):
• Fists: 0.145 фиксированная
• Pistol: 0.145 → 0.165 по дистанции
• AR: 0.148 → 0.175 по дистанции
• Sniper: 0.15 → 0.2 + bullet drop

INSERT = Скрыть меню | DELETE = Выгрузить]]
hlp.BorderSizePixel = 0
hlp.Parent = infoT
Instance.new("UICorner", hlp).CornerRadius = UDim.new(0, 8)
local pad = Instance.new("UIPadding", hlp)
pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
pad.PaddingTop = UDim.new(0,8)

-- Toggle UI visibility
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Insert or inp.KeyCode == Enum.KeyCode.RightShift then
        G.Enabled = not G.Enabled
    end
end)

-- Unload
task.spawn(function()
    while Alive do
        if UIS:IsKeyDown(Enum.KeyCode.Delete) then
            Alive = false
            ClearAll()
            pcall(function() rc:Disconnect() end)
            for p in pairs(ESP) do KillESP(p) end
            for _, o in pairs({fov,dot,line,info,pingTxt,distTxt,methodTxt,watermark,predLine,headDot}) do
                if o then pcall(function() o:Remove() end) end
            end
            if G then pcall(function() G:Destroy() end) end
            Notify("Silent Aim", "Unloaded", 2)
            break
        end
        task.wait(0.5)
    end
end)

Notify("Silent Aim v15F", "Method: " .. SilentMethod .. " | FIXED", 4)
print("=== SILENT AIM v15 FIXED ===")
print("Active method:", SilentMethod)
print("Silent active:", silentActive)
print("Hold RMB to aim, LMB to shoot")
print("============================")