-- ===============================================
--   ☾ EVENTIDE v2.1 • SAFE BYPASS EDITION
--   No-Crash Custom Bypass
-- ===============================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(math.random(15, 25) / 10)

local getgenv = getgenv or function() return _G end
local env = getgenv()
if env._EV_ACTIVE then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Eventide", Text = "Уже запущен", Duration = 2
    })
    return
end
env._EV_ACTIVE = true

pcall(function()
    local function cleanup(parent)
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name:lower()
                if n:find("eventide") or n:find("hub") or n:find("frame_") or n:find("gamehud") then
                    gui:Destroy()
                end
            end
        end
    end
    cleanup(game:GetService("CoreGui"))
    if gethui then cleanup(gethui()) end
end)

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local TS = game:GetService("TweenService")
local SG = game:GetService("StarterGui")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer
local Cam = WS.CurrentCamera

-- ==================== SAFE BYPASS ENGINE ====================
-- Используем ТОЛЬКО безопасные функции которые не крашат
local Bypass = {}

-- Проверка функций
Bypass.hookmm = hookmetamethod
Bypass.getnc = getnamecallmethod
Bypass.newccl = newcclosure
Bypass.gethui_fn = gethui
Bypass.protectgui = (syn and syn.protect_gui) or protect_gui
Bypass.checkcaller = checkcaller or function() return false end

Bypass.canHook = Bypass.hookmm and Bypass.getnc and Bypass.newccl

-- Определяем executor
local ExecutorName = "Unknown"
pcall(function()
    if identifyexecutor then
        local name = identifyexecutor()
        if type(name) == "string" then ExecutorName = name end
    elseif getexecutorname then
        local name = getexecutorname()
        if type(name) == "string" then ExecutorName = name end
    elseif syn then ExecutorName = "Synapse"
    elseif krnl_ver then ExecutorName = "KRNL"
    elseif fluxus then ExecutorName = "Fluxus"
    end
end)

if not Drawing then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Eventide", Text = "Executor не поддерживает Drawing!", Duration = 5
    })
    env._EV_ACTIVE = nil
    return
end

-- ==================== CONFIG ====================
local CFG = {
    SilentAim = true, SilentAimPart = "Head", FOV = 180,
    AutoPrediction = true, ManualPrediction = 0.14, PredictionMultiplier = 1.0,
    Resolver = true, ResolverSmoothing = true,
    VisibleCheck = false, TeamCheck = false, IgnoreDowned = true,
    ESP = true, Boxes = true, Names = true, Health = true,
    Distance = true, Tracers = false, HeadDot = true,
    MaxDistance = 800,
    ShowFOV = true, ShowPredDot = true, FOVRainbow = false,
    FOVColor = Color3.fromRGB(120, 90, 220),
    Crosshair = false, CrosshairSize = 8, CrosshairGap = 3,
    CrosshairColor = Color3.fromRGB(0, 255, 140),
    ShowDebugInfo = true,
    AntiKick = true,
    RandomizeName = true,
}

local Target = nil
local cachedPred = nil
local ESPObjects = {}
local RainbowHue = 0
local FPS, FPSHistory = 60, {}
local currentPredValue = 0
local PositionHistory = {}
local VelocityHistory = {}
local MAX_HISTORY = 8

-- ==================== UTILS ====================
local function Notify(title, text, duration)
    pcall(function()
        SG:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 3})
    end)
end
local function GetPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and v or 80
end
local function GetRoot(plr)
    local c = plr and plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHead(plr)
    local c = plr and plr.Character
    return c and c:FindFirstChild("Head")
end
local function GetHum(plr)
    local c = plr and plr.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function IsDowned(plr)
    local char = plr and plr.Character
    if not char then return true end
    local be = char:FindFirstChild("BodyEffects")
    if be then
        local ko = be:FindFirstChild("K.O")
        if ko then return ko.Value end
    end
    return false
end
local function IsVisible(target)
    if not CFG.VisibleCheck then return true end
    local root = GetRoot(LP)
    local tHead = GetHead(target)
    if not root or not tHead then return false end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LP.Character, target.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = WS:Raycast(root.Position, (tHead.Position - root.Position), params)
    return not result
end
local function IsValid(plr)
    if plr == LP or not plr or not plr.Parent then return false end
    local char = plr.Character
    if not char then return false end
    local hum = GetHum(plr)
    if not hum or hum.Health <= 0 then return false end
    local head = GetHead(plr)
    if not head then return false end
    if CFG.TeamCheck and plr.Team == LP.Team then return false end
    if CFG.IgnoreDowned and IsDowned(plr) then return false end
    if CFG.VisibleCheck and not IsVisible(plr) then return false end
    return true
end

-- ==================== HISTORY ====================
RS.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local root = GetRoot(plr)
            if root then
                if not PositionHistory[plr] then
                    PositionHistory[plr] = {}
                    VelocityHistory[plr] = {}
                end
                table.insert(PositionHistory[plr], 1, {pos = root.Position, time = tick()})
                table.insert(VelocityHistory[plr], 1, root.AssemblyLinearVelocity)
                if #PositionHistory[plr] > MAX_HISTORY then table.remove(PositionHistory[plr]) end
                if #VelocityHistory[plr] > MAX_HISTORY then table.remove(VelocityHistory[plr]) end
            end
        end
    end
end)
Players.PlayerRemoving:Connect(function(plr)
    PositionHistory[plr] = nil
    VelocityHistory[plr] = nil
end)

-- ==================== PREDICTION ====================
local function CalculatePrediction()
    if CFG.AutoPrediction then
        local ping = GetPing()
        local basePred = ping / 1000 + 0.02
        basePred = math.clamp(basePred, 0.06, 0.25)
        basePred = basePred * CFG.PredictionMultiplier
        currentPredValue = basePred
        return basePred
    else
        currentPredValue = CFG.ManualPrediction
        return CFG.ManualPrediction
    end
end
local function GetSmoothedVelocity(plr)
    local history = VelocityHistory[plr]
    if not history or #history == 0 then
        local root = GetRoot(plr)
        return root and root.AssemblyLinearVelocity or Vector3.zero
    end
    if not CFG.ResolverSmoothing or #history < 2 then return history[1] end
    local totalWeight = 0
    local smoothed = Vector3.zero
    local count = math.min(#history, 5)
    for i = 1, count do
        local weight = ((count - i + 1) / count) ^ 2
        smoothed = smoothed + history[i] * weight
        totalWeight = totalWeight + weight
    end
    if totalWeight > 0 then smoothed = smoothed / totalWeight end
    return smoothed
end
local function GetAcceleration(plr)
    local history = VelocityHistory[plr]
    if not history or #history < 3 then return Vector3.zero end
    return history[1] - history[2]
end
local function GetPredictedHeadPosition(plr)
    if not plr or not plr.Character then return nil end
    local head = GetHead(plr); local root = GetRoot(plr); local hum = GetHum(plr)
    if not head or not root then return nil end
    local headOffset = head.Position - root.Position
    local pred = CalculatePrediction()
    local vel = GetSmoothedVelocity(plr)
    local predictedRoot = root.Position + Vector3.new(vel.X * pred, 0, vel.Z * pred)
    if CFG.Resolver then
        local accel = GetAcceleration(plr)
        predictedRoot = predictedRoot + Vector3.new(accel.X * pred * pred * 0.3, 0, accel.Z * pred * pred * 0.3)
    end
    if hum then
        local state = hum:GetState()
        local gravity = WS.Gravity or 196.2
        if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
            local yPred = vel.Y * pred - 0.5 * gravity * pred * pred
            predictedRoot = Vector3.new(predictedRoot.X, root.Position.Y + yPred, predictedRoot.Z)
        elseif state == Enum.HumanoidStateType.Running then
            predictedRoot = Vector3.new(predictedRoot.X, root.Position.Y, predictedRoot.Z)
        else
            predictedRoot = Vector3.new(predictedRoot.X, root.Position.Y + vel.Y * pred * 0.2, predictedRoot.Z)
        end
    end
    if CFG.Resolver then
        local totalOffset = predictedRoot - root.Position
        local maxAllowed = vel.Magnitude * pred * 1.8 + 3
        if totalOffset.Magnitude > maxAllowed then
            predictedRoot = root.Position + totalOffset.Unit * maxAllowed
        end
    end
    return predictedRoot + headOffset
end
local function GetClosestTarget()
    local closest, bestScore = nil, math.huge
    local sc = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValid(plr) then
            local head = GetHead(plr)
            if head then
                local sp = Cam:WorldToViewportPoint(head.Position)
                if sp.Z > 0 then
                    local fovDist = (Vector2.new(sp.X, sp.Y) - sc).Magnitude
                    if fovDist < CFG.FOV and fovDist < bestScore then
                        bestScore = fovDist; closest = plr
                    end
                end
            end
        end
    end
    return closest
end
RS.Heartbeat:Connect(function()
    Target = GetClosestTarget()
    cachedPred = (Target and CFG.SilentAim) and GetPredictedHeadPosition(Target) or nil
end)

-- ==================== ✅ SAFE HOOK (без крашей) ====================
-- Используем ТОЛЬКО hookmetamethod (безопасно на всех экзекуторах)
-- НЕ используем hookfunction на C-функции (крашит Roblox!)

task.spawn(function()
    task.wait(math.random(30, 50) / 10) -- 3-5 сек задержка
    
    if not Bypass.canHook then
        Notify("Eventide", "⚠ Silent Aim не доступен на этом executor'e", 4)
        return
    end
    
    local hookOK = pcall(function()
        local oldNc
        oldNc = Bypass.hookmm(game, "__namecall", Bypass.newccl(function(self, ...)
            -- ✅ Защита от рекурсии
            if Bypass.checkcaller() then
                return oldNc(self, ...)
            end
            
            local method = Bypass.getnc()
            
            -- SILENT AIM: только Raycast (не FireServer/InvokeServer!)
            if CFG.SilentAim and cachedPred then
                if method == "Raycast" and self == WS then
                    local args = {...}
                    local origin = args[1]
                    if typeof(origin) == "Vector3" then
                        local dir = cachedPred - origin
                        if dir.Magnitude > 0.001 then
                            local newDir = dir.Unit * (typeof(args[2]) == "Vector3" and args[2].Magnitude or 1000)
                            return oldNc(self, origin, newDir, args[3])
                        end
                    end
                end
                
                if method == "FindPartOnRayWithIgnoreList"
                or method == "FindPartOnRayWithWhitelist"
                or method == "FindPartOnRay" then
                    local args = {...}
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        local dir = cachedPred - ray.Origin
                        if dir.Magnitude > 0.001 then
                            args[1] = Ray.new(ray.Origin, dir.Unit * ray.Direction.Magnitude)
                        end
                        return oldNc(self, table.unpack(args))
                    end
                end
            end
            
            -- ✅ SAFE ANTI-KICK через namecall (НЕ hookfunction!)
            if CFG.AntiKick then
                if method == "Kick" and self == LP then
                    warn("[Eventide] Blocked Kick attempt")
                    return nil
                end
            end
            
            return oldNc(self, ...)
        end))
    end)
    
    if hookOK then
        Notify("Eventide", "🛡 Bypass активен", 3)
    else
        Notify("Eventide", "⚠ Hook установить не удалось", 4)
    end
end)

-- ==================== ESP ====================
local function CreateESP(plr)
    if plr == LP or ESPObjects[plr] then return end
    local esp = {
        Box = Drawing.new("Square"), BoxOut = Drawing.new("Square"),
        Name = Drawing.new("Text"), Health = Drawing.new("Text"),
        Distance = Drawing.new("Text"), Tracer = Drawing.new("Line"),
        HPBar = Drawing.new("Square"), HPBarBG = Drawing.new("Square"),
        HeadDot = Drawing.new("Circle"),
    }
    for _, v in pairs(esp) do v.Visible = false end
    esp.Box.Thickness = 1.5; esp.Box.Filled = false
    esp.BoxOut.Thickness = 3; esp.BoxOut.Filled = false
    esp.BoxOut.Color = Color3.new(0,0,0); esp.BoxOut.Transparency = 0.5
    esp.Name.Size = 13; esp.Name.Center = true; esp.Name.Outline = true; esp.Name.Font = 2
    esp.Health.Size = 12; esp.Health.Center = true; esp.Health.Outline = true; esp.Health.Font = 2
    esp.Distance.Size = 11; esp.Distance.Center = true; esp.Distance.Outline = true; esp.Distance.Font = 2
    esp.Distance.Color = Color3.fromRGB(180,180,180)
    esp.Tracer.Thickness = 1.5
    esp.HPBar.Filled = true
    esp.HPBarBG.Filled = true; esp.HPBarBG.Color = Color3.fromRGB(20,20,20)
    esp.HeadDot.Filled = true; esp.HeadDot.Radius = 3; esp.HeadDot.NumSides = 12
    ESPObjects[plr] = esp
end
local function RemoveESP(plr)
    local esp = ESPObjects[plr]
    if not esp then return end
    for _, v in pairs(esp) do pcall(function() v:Remove() end) end
    ESPObjects[plr] = nil
end
for _, plr in ipairs(Players:GetPlayers()) do CreateESP(plr) end
Players.PlayerAdded:Connect(function(p) task.wait(1); CreateESP(p) end)
Players.PlayerRemoving:Connect(RemoveESP)

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5; FOVCircle.NumSides = 64
FOVCircle.Filled = false; FOVCircle.Transparency = 0.9; FOVCircle.Visible = false

local PredDot = Drawing.new("Circle")
PredDot.Filled = true; PredDot.Radius = 5; PredDot.NumSides = 12; PredDot.Visible = false
PredDot.Color = Color3.fromRGB(0, 255, 100)

local PredLine = Drawing.new("Line")
PredLine.Thickness = 1.5; PredLine.Visible = false
PredLine.Color = Color3.fromRGB(0, 255, 255); PredLine.Transparency = 0.6

local CH_Top = Drawing.new("Line"); CH_Top.Thickness = 2
local CH_Bot = Drawing.new("Line"); CH_Bot.Thickness = 2
local CH_Left = Drawing.new("Line"); CH_Left.Thickness = 2
local CH_Right = Drawing.new("Line"); CH_Right.Thickness = 2

local DebugText = Drawing.new("Text")
DebugText.Size = 14; DebugText.Outline = true; DebugText.Font = 2
DebugText.Color = Color3.fromRGB(255, 255, 100); DebugText.Visible = false

RS.RenderStepped:Connect(function(dt)
    table.insert(FPSHistory, 1/dt)
    if #FPSHistory > 30 then table.remove(FPSHistory, 1) end
    local s = 0; for _, v in ipairs(FPSHistory) do s = s + v end
    FPS = math.floor(s / #FPSHistory)
end)

local espTimer = 0
RS.RenderStepped:Connect(function(dt)
    Cam = WS.CurrentCamera
    RainbowHue = (RainbowHue + 0.003) % 1
    local sc = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    FOVCircle.Visible = CFG.ShowFOV
    FOVCircle.Radius = CFG.FOV
    FOVCircle.Position = sc
    FOVCircle.Color = CFG.FOVRainbow and Color3.fromHSV(RainbowHue,1,1) or CFG.FOVColor
    if cachedPred and CFG.ShowPredDot then
        local sp = Cam:WorldToViewportPoint(cachedPred)
        PredDot.Visible = sp.Z > 0
        PredDot.Position = Vector2.new(sp.X, sp.Y)
        if Target and Target.Character then
            local head = GetHead(Target)
            if head then
                local hsp = Cam:WorldToViewportPoint(head.Position)
                if hsp.Z > 0 and sp.Z > 0 then
                    PredLine.Visible = true
                    PredLine.From = Vector2.new(hsp.X, hsp.Y)
                    PredLine.To = Vector2.new(sp.X, sp.Y)
                else PredLine.Visible = false end
            else PredLine.Visible = false end
        else PredLine.Visible = false end
    else PredDot.Visible = false; PredLine.Visible = false end
    if CFG.ShowDebugInfo then
        DebugText.Visible = true
        local ping = math.floor(GetPing())
        local predMs = math.floor(currentPredValue * 1000)
        local targetName = Target and Target.Name or "NONE"
        local velMag = 0
        if Target then
            local root = GetRoot(Target)
            if root then velMag = math.floor(root.AssemblyLinearVelocity.Magnitude) end
        end
        DebugText.Text = string.format("PRED: %dms | PING: %dms | TGT: %s | VEL: %d", predMs, ping, targetName, velMag)
        DebugText.Position = Vector2.new(sc.X - 150, 10)
    else DebugText.Visible = false end
    if CFG.Crosshair then
        local col = CFG.FOVRainbow and Color3.fromHSV(RainbowHue,1,1) or CFG.CrosshairColor
        local ss, g = CFG.CrosshairSize, CFG.CrosshairGap
        CH_Top.Visible=true; CH_Bot.Visible=true; CH_Left.Visible=true; CH_Right.Visible=true
        CH_Top.Color=col; CH_Bot.Color=col; CH_Left.Color=col; CH_Right.Color=col
        CH_Top.From = Vector2.new(sc.X, sc.Y-g-ss); CH_Top.To = Vector2.new(sc.X, sc.Y-g)
        CH_Bot.From = Vector2.new(sc.X, sc.Y+g); CH_Bot.To = Vector2.new(sc.X, sc.Y+g+ss)
        CH_Left.From = Vector2.new(sc.X-g-ss, sc.Y); CH_Left.To = Vector2.new(sc.X-g, sc.Y)
        CH_Right.From = Vector2.new(sc.X+g, sc.Y); CH_Right.To = Vector2.new(sc.X+g+ss, sc.Y)
    else CH_Top.Visible=false; CH_Bot.Visible=false; CH_Left.Visible=false; CH_Right.Visible=false end
    espTimer = espTimer + dt
    if espTimer < 0.033 then return end
    espTimer = 0
    local myRoot = GetRoot(LP)
    for plr, esp in pairs(ESPObjects) do
        pcall(function()
            local hideAll = function() for _, v in pairs(esp) do v.Visible = false end end
            if not CFG.ESP or not plr.Parent then return hideAll() end
            local char = plr.Character
            if not char then return hideAll() end
            local hum = GetHum(plr)
            if not hum or hum.Health <= 0 then return hideAll() end
            local root = GetRoot(plr)
            local head = GetHead(plr)
            if not root or not head then return hideAll() end
            local dist = myRoot and (myRoot.Position - root.Position).Magnitude or 0
            if dist > CFG.MaxDistance then return hideAll() end
            local rp = Cam:WorldToViewportPoint(root.Position)
            local hp2 = Cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            if rp.Z <= 0 then return hideAll() end
            local color = (Target == plr) and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(180, 100, 255)
            local hp = math.floor(hum.Health); local mhp = math.floor(hum.MaxHealth)
            local hpr = math.clamp(hp/math.max(mhp,1), 0, 1)
            local bh = math.abs(rp.Y - hp2.Y) * 2.2
            local bw = bh * 0.55
            local bx = rp.X - bw/2; local by = rp.Y - bh/2
            if CFG.Boxes then
                esp.BoxOut.Visible=true; esp.BoxOut.Position=Vector2.new(bx,by); esp.BoxOut.Size=Vector2.new(bw,bh)
                esp.Box.Visible=true; esp.Box.Position=Vector2.new(bx,by); esp.Box.Size=Vector2.new(bw,bh); esp.Box.Color=color
            else esp.Box.Visible=false; esp.BoxOut.Visible=false end
            if CFG.Health then
                esp.HPBarBG.Visible=true; esp.HPBarBG.Position=Vector2.new(bx-7,by); esp.HPBarBG.Size=Vector2.new(3,bh)
                esp.HPBar.Visible=true
                esp.HPBar.Position=Vector2.new(bx-7, by+bh*(1-hpr))
                esp.HPBar.Size=Vector2.new(3, bh*hpr)
                esp.HPBar.Color=Color3.fromRGB(math.floor(255*(1-hpr)), math.floor(255*hpr), 0)
                esp.Health.Visible=true
                esp.Health.Text = hp.."/"..mhp
                esp.Health.Position = Vector2.new(rp.X, by+bh+2)
                esp.Health.Color = hpr>0.6 and Color3.fromRGB(100,255,100) or hpr>0.3 and Color3.fromRGB(255,255,100) or Color3.fromRGB(255,80,80)
            else esp.HPBar.Visible=false; esp.HPBarBG.Visible=false; esp.Health.Visible=false end
            if CFG.Names then
                esp.Name.Visible=true
                esp.Name.Text=plr.Name..(IsDowned(plr) and " [DOWN]" or "")
                esp.Name.Position=Vector2.new(rp.X, by-16)
                esp.Name.Color=color
            else esp.Name.Visible=false end
            if CFG.Distance then
                esp.Distance.Visible=true
                esp.Distance.Text="["..math.floor(dist).."m]"
                esp.Distance.Position=Vector2.new(rp.X, by+bh+15)
            else esp.Distance.Visible=false end
            if CFG.Tracers then
                esp.Tracer.Visible=true
                esp.Tracer.From=Vector2.new(sc.X, Cam.ViewportSize.Y)
                esp.Tracer.To=Vector2.new(rp.X, rp.Y)
                esp.Tracer.Color=color
            else esp.Tracer.Visible=false end
            if CFG.HeadDot and hp2.Z > 0 then
                esp.HeadDot.Visible=true
                esp.HeadDot.Position=Vector2.new(hp2.X, hp2.Y)
                esp.HeadDot.Color=color
            else esp.HeadDot.Visible=false end
        end)
    end
end)

-- ===============================================
--                    GUI
-- ===============================================
local guiNames = {
    "Frame_"..tostring(math.random(1000,9999)),
    "Container"..tostring(math.random(100,999)),
    "GameHUD_"..tostring(math.random(1000,9999)),
    "MainUI_"..tostring(math.random(1000,9999)),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CFG.RandomizeName and guiNames[math.random(1, #guiNames)] or "Eventide"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999

local parented = false
if not parented then
    pcall(function()
        if Bypass.gethui_fn then
            ScreenGui.Parent = Bypass.gethui_fn()
            parented = true
        end
    end)
end
if not parented then
    pcall(function()
        if Bypass.protectgui then
            Bypass.protectgui(ScreenGui)
            ScreenGui.Parent = game:GetService("CoreGui")
            parented = true
        end
    end)
end
if not parented then
    pcall(function()
        ScreenGui.Parent = game:GetService("CoreGui")
        parented = true
    end)
end
if not parented then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end

local C = {
    BG = Color3.fromRGB(10, 12, 20), BG2 = Color3.fromRGB(14, 16, 26),
    BG3 = Color3.fromRGB(20, 22, 34), Card = Color3.fromRGB(25, 27, 42),
    Border = Color3.fromRGB(40, 42, 65), Accent = Color3.fromRGB(120, 90, 220),
    Accent2 = Color3.fromRGB(180, 100, 220), Green = Color3.fromRGB(0, 230, 140),
    Red = Color3.fromRGB(255, 80, 100), Yellow = Color3.fromRGB(255, 200, 60),
    Text = Color3.fromRGB(240, 240, 255), TextDim = Color3.fromRGB(140, 140, 180),
    Off = Color3.fromRGB(38, 40, 58),
}

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 640, 0, 480)
Main.Position = UDim2.new(0.5, -320, 0.5, -240)
Main.BackgroundColor3 = C.BG
Main.BorderSizePixel = 0
Main.Active = true; Main.Draggable = true; Main.Visible = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Main).Color = C.Border

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 160, 1, 0); Sidebar.BackgroundColor3 = C.BG2
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)
local SbCover = Instance.new("Frame", Sidebar)
SbCover.Size = UDim2.new(0, 12, 1, 0); SbCover.Position = UDim2.new(1, -12, 0, 0)
SbCover.BackgroundColor3 = C.BG2

local LogoIcon = Instance.new("Frame", Sidebar)
LogoIcon.Size = UDim2.new(0, 44, 0, 44); LogoIcon.Position = UDim2.new(0, 16, 0, 18)
LogoIcon.BackgroundColor3 = C.Accent
Instance.new("UICorner", LogoIcon).CornerRadius = UDim.new(0, 10)
local lg = Instance.new("UIGradient", LogoIcon)
lg.Color = ColorSequence.new(C.Accent, C.Accent2); lg.Rotation = 135

local LogoSym = Instance.new("TextLabel", LogoIcon)
LogoSym.Size = UDim2.new(1, 0, 1, 0); LogoSym.BackgroundTransparency = 1
LogoSym.Text = "☾"; LogoSym.TextColor3 = Color3.new(1, 1, 1)
LogoSym.Font = Enum.Font.GothamBlack; LogoSym.TextSize = 24

local LogoTitle = Instance.new("TextLabel", Sidebar)
LogoTitle.Size = UDim2.new(0, 90, 0, 18); LogoTitle.Position = UDim2.new(0, 68, 0, 22)
LogoTitle.BackgroundTransparency = 1; LogoTitle.Text = "EVENTIDE"
LogoTitle.TextColor3 = C.Text; LogoTitle.Font = Enum.Font.GothamBlack
LogoTitle.TextSize = 14; LogoTitle.TextXAlignment = Enum.TextXAlignment.Left

local LogoVer = Instance.new("TextLabel", Sidebar)
LogoVer.Size = UDim2.new(0, 90, 0, 14); LogoVer.Position = UDim2.new(0, 68, 0, 40)
LogoVer.BackgroundTransparency = 1; LogoVer.Text = "v2.1 • Safe"
LogoVer.TextColor3 = C.Accent2; LogoVer.Font = Enum.Font.Gotham
LogoVer.TextSize = 10; LogoVer.TextXAlignment = Enum.TextXAlignment.Left

local DivLine = Instance.new("Frame", Sidebar)
DivLine.Size = UDim2.new(1, -32, 0, 1); DivLine.Position = UDim2.new(0, 16, 0, 88)
DivLine.BackgroundColor3 = C.Border

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, -160, 0, 55); Header.Position = UDim2.new(0, 160, 0, 0)
Header.BackgroundTransparency = 1

local HeaderTitle = Instance.new("TextLabel", Header)
HeaderTitle.Size = UDim2.new(0.4, 0, 1, 0); HeaderTitle.Position = UDim2.new(0, 20, 0, 0)
HeaderTitle.BackgroundTransparency = 1; HeaderTitle.Text = "Aimbot"
HeaderTitle.TextColor3 = C.Text; HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 19; HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left

local FPSBox = Instance.new("Frame", Header)
FPSBox.Size = UDim2.new(0, 70, 0, 26); FPSBox.Position = UDim2.new(1, -240, 0.5, -13)
FPSBox.BackgroundColor3 = C.Card
Instance.new("UICorner", FPSBox).CornerRadius = UDim.new(0, 6)
local FPSLbl = Instance.new("TextLabel", FPSBox)
FPSLbl.Size = UDim2.new(1, 0, 1, 0); FPSLbl.BackgroundTransparency = 1
FPSLbl.Text = "60 FPS"; FPSLbl.TextColor3 = C.Green
FPSLbl.Font = Enum.Font.GothamBold; FPSLbl.TextSize = 11

local PingBox = Instance.new("Frame", Header)
PingBox.Size = UDim2.new(0, 70, 0, 26); PingBox.Position = UDim2.new(1, -160, 0.5, -13)
PingBox.BackgroundColor3 = C.Card
Instance.new("UICorner", PingBox).CornerRadius = UDim.new(0, 6)
local PingLbl = Instance.new("TextLabel", PingBox)
PingLbl.Size = UDim2.new(1, 0, 1, 0); PingLbl.BackgroundTransparency = 1
PingLbl.Text = "0 MS"; PingLbl.TextColor3 = C.Yellow
PingLbl.Font = Enum.Font.GothamBold; PingLbl.TextSize = 11

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 32, 0, 32); CloseBtn.Position = UDim2.new(1, -50, 0.5, -16)
CloseBtn.BackgroundColor3 = C.Card; CloseBtn.Text = "×"; CloseBtn.TextColor3 = C.Red
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 22
CloseBtn.BorderSizePixel = 0; CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 7)
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false; Notify("Eventide", "INSERT — открыть", 2) end)

local Content = Instance.new("Frame", Main)
Content.Size = UDim2.new(1, -160, 1, -55); Content.Position = UDim2.new(0, 160, 0, 55)
Content.BackgroundTransparency = 1; Content.ClipsDescendants = true

local Tabs = {
    {name="Aimbot", icon="◎"}, {name="Visuals", icon="◈"},
    {name="Bypass", icon="🛡"}, {name="Player", icon="●"}, {name="Settings", icon="⚙"},
}
local TabButtons, TabPages = {}, {}
local CurrentTab = "Aimbot"

for _, tab in ipairs(Tabs) do
    local page = Instance.new("ScrollingFrame", Content)
    page.Name = tab.name; page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = C.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = (tab.name == CurrentTab)
    TabPages[tab.name] = page
    local pad = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0, 15); pad.PaddingLeft = UDim.new(0, 15)
    pad.PaddingRight = UDim.new(0, 15); pad.PaddingBottom = UDim.new(0, 15)
    Instance.new("UIListLayout", page).Padding = UDim.new(0, 10)
end

for i, tab in ipairs(Tabs) do
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(1, -20, 0, 36); btn.Position = UDim2.new(0, 10, 0, 100 + (i-1) * 42)
    btn.BackgroundColor3 = tab.name == CurrentTab and C.Card or C.BG2
    btn.BorderSizePixel = 0; btn.Text = ""; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    TabButtons[tab.name] = btn
    local ind = Instance.new("Frame", btn); ind.Name = "Ind"
    ind.Size = UDim2.new(0, 3, 0.6, 0); ind.Position = UDim2.new(0, 0, 0.2, 0)
    ind.BackgroundColor3 = C.Accent; ind.Visible = tab.name == CurrentTab
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    local ic = Instance.new("TextLabel", btn); ic.Name = "Ic"
    ic.Size = UDim2.new(0, 30, 1, 0); ic.Position = UDim2.new(0, 12, 0, 0)
    ic.BackgroundTransparency = 1; ic.Text = tab.icon
    ic.TextColor3 = tab.name == CurrentTab and C.Accent or C.TextDim
    ic.Font = Enum.Font.GothamBold; ic.TextSize = 15
    local lb = Instance.new("TextLabel", btn); lb.Name = "Lb"
    lb.Size = UDim2.new(1, -50, 1, 0); lb.Position = UDim2.new(0, 45, 0, 0)
    lb.BackgroundTransparency = 1; lb.Text = tab.name
    lb.TextColor3 = tab.name == CurrentTab and C.Text or C.TextDim
    lb.Font = Enum.Font.GothamBold; lb.TextSize = 11
    lb.TextXAlignment = Enum.TextXAlignment.Left
    btn.MouseButton1Click:Connect(function()
        CurrentTab = tab.name; HeaderTitle.Text = tab.name
        for n, p in pairs(TabPages) do p.Visible = (n == tab.name) end
        for n, b in pairs(TabButtons) do
            local a = (n == tab.name)
            b.BackgroundColor3 = a and C.Card or C.BG2
            local i2 = b:FindFirstChild("Ic"); if i2 then i2.TextColor3 = a and C.Accent or C.TextDim end
            local l2 = b:FindFirstChild("Lb"); if l2 then l2.TextColor3 = a and C.Text or C.TextDim end
            local d2 = b:FindFirstChild("Ind"); if d2 then d2.Visible = a end
        end
    end)
end

local function Section(parent, title)
    local w = Instance.new("Frame", parent)
    w.Size = UDim2.new(1, 0, 0, 40); w.BackgroundColor3 = C.BG2
    w.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", w).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", w).Color = C.Border
    local bar = Instance.new("Frame", w)
    bar.Size = UDim2.new(0, 3, 0, 20); bar.Position = UDim2.new(0, 10, 0, 8)
    bar.BackgroundColor3 = C.Accent
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local tl = Instance.new("TextLabel", w)
    tl.Size = UDim2.new(1, -30, 0, 36); tl.Position = UDim2.new(0, 20, 0, 0)
    tl.BackgroundTransparency = 1; tl.Text = title; tl.TextColor3 = C.Text
    tl.Font = Enum.Font.GothamBold; tl.TextSize = 12; tl.TextXAlignment = Enum.TextXAlignment.Left
    local c = Instance.new("Frame", w)
    c.Size = UDim2.new(1, 0, 0, 0); c.Position = UDim2.new(0, 0, 0, 36)
    c.BackgroundTransparency = 1; c.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new("UIListLayout", c).Padding = UDim.new(0, 4)
    local pa = Instance.new("UIPadding", c)
    pa.PaddingLeft = UDim.new(0, 12); pa.PaddingRight = UDim.new(0, 12); pa.PaddingBottom = UDim.new(0, 10)
    return c
end
local function Toggle(parent, label, key, cb)
    local f = Instance.new("Frame", parent); f.Size = UDim2.new(1, 0, 0, 30); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.7, 0, 1, 0); l.BackgroundTransparency = 1; l.Text = label
    l.TextColor3 = C.Text; l.Font = Enum.Font.Gotham; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left
    local sw = Instance.new("Frame", f)
    sw.Size = UDim2.new(0, 36, 0, 20); sw.Position = UDim2.new(1, -40, 0.5, -10)
    sw.BackgroundColor3 = CFG[key] and C.Accent or C.Off
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
    local kn = Instance.new("Frame", sw)
    kn.Size = UDim2.new(0, 14, 0, 14)
    kn.Position = CFG[key] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    kn.BackgroundColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(1, 0, 1, 0); b.BackgroundTransparency = 1; b.Text = ""; b.AutoButtonColor = false
    b.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        TS:Create(sw, TweenInfo.new(0.2), {BackgroundColor3 = CFG[key] and C.Accent or C.Off}):Play()
        TS:Create(kn, TweenInfo.new(0.2), {Position = CFG[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)}):Play()
        if cb then cb(CFG[key]) end
    end)
end
local function Slider(parent, label, key, mn, mx, dec, cb)
    dec = dec or 0
    local f = Instance.new("Frame", parent); f.Size = UDim2.new(1, 0, 0, 44); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.6, 0, 0, 18); l.BackgroundTransparency = 1; l.Text = label
    l.TextColor3 = C.Text; l.Font = Enum.Font.Gotham; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    local v = Instance.new("TextLabel", f)
    v.Size = UDim2.new(0.4, 0, 0, 18); v.Position = UDim2.new(0.6, 0, 0, 0)
    v.BackgroundTransparency = 1; v.TextColor3 = C.Accent
    v.Font = Enum.Font.GothamBold; v.TextSize = 11; v.TextXAlignment = Enum.TextXAlignment.Right
    local tr = Instance.new("Frame", f)
    tr.Size = UDim2.new(1, 0, 0, 6); tr.Position = UDim2.new(0, 0, 0, 24); tr.BackgroundColor3 = C.Off
    Instance.new("UICorner", tr).CornerRadius = UDim.new(1, 0)
    local fi = Instance.new("Frame", tr); fi.BackgroundColor3 = C.Accent
    Instance.new("UICorner", fi).CornerRadius = UDim.new(1, 0)
    local th = Instance.new("Frame", tr)
    th.Size = UDim2.new(0, 14, 0, 14); th.BackgroundColor3 = Color3.new(1, 1, 1); th.ZIndex = 5
    Instance.new("UICorner", th).CornerRadius = UDim.new(1, 0)
    local function Upd()
        local p = math.clamp((CFG[key]-mn)/(mx-mn), 0, 1)
        fi.Size = UDim2.new(p, 0, 1, 0); th.Position = UDim2.new(p, -7, 0.5, -7)
        v.Text = dec > 0 and string.format("%."..dec.."f", CFG[key]) or tostring(math.floor(CFG[key]))
    end
    Upd()
    local drag = false
    tr.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local p = math.clamp((i.Position.X - tr.AbsolutePosition.X)/tr.AbsoluteSize.X, 0, 1)
            local raw = mn + (mx-mn)*p
            CFG[key] = dec > 0 and math.floor(raw*10^dec+0.5)/10^dec or math.floor(raw+0.5)
            Upd(); if cb then cb(CFG[key]) end
        end
    end)
end
local function Dropdown(parent, label, options, key)
    local f = Instance.new("Frame", parent); f.Size = UDim2.new(1, 0, 0, 30); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.4, 0, 1, 0); l.BackgroundTransparency = 1; l.Text = label
    l.TextColor3 = C.Text; l.Font = Enum.Font.Gotham; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    local sel = Instance.new("TextButton", f)
    sel.Size = UDim2.new(0.55, 0, 0, 24); sel.Position = UDim2.new(0.45, 0, 0.5, -12)
    sel.BackgroundColor3 = C.Off; sel.TextColor3 = C.Text
    sel.Font = Enum.Font.GothamBold; sel.TextSize = 10
    sel.Text = tostring(CFG[key]).."  ▼"; sel.BorderSizePixel = 0; sel.AutoButtonColor = false
    Instance.new("UICorner", sel).CornerRadius = UDim.new(0, 6)
    local df = Instance.new("Frame", ScreenGui)
    df.BackgroundColor3 = C.BG3; df.Visible = false; df.ZIndex = 100
    Instance.new("UICorner", df).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", df).Color = C.Accent
    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton", df)
        ob.Size = UDim2.new(1, -4, 0, 24); ob.Position = UDim2.new(0, 2, 0, (i-1)*26 + 2)
        ob.BackgroundColor3 = C.BG3; ob.Text = opt; ob.TextColor3 = C.Text
        ob.Font = Enum.Font.Gotham; ob.TextSize = 11; ob.ZIndex = 101; ob.AutoButtonColor = false
        Instance.new("UICorner", ob).CornerRadius = UDim.new(0, 4)
        ob.MouseButton1Click:Connect(function() CFG[key] = opt; sel.Text = opt.."  ▼"; df.Visible = false end)
    end
    sel.MouseButton1Click:Connect(function()
        if df.Visible then df.Visible = false else
            local pos = sel.AbsolutePosition; local sz = sel.AbsoluteSize
            df.Position = UDim2.new(0, pos.X, 0, pos.Y + sz.Y + 4)
            df.Size = UDim2.new(0, sz.X, 0, #options * 26 + 4); df.Visible = true
        end
    end)
end
local function Button(parent, label, cb, color)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 30); b.BackgroundColor3 = color or C.Off
    b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.Text = label; b.BorderSizePixel = 0; b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
end
local function Label(parent, text, color)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1, 0, 0, 16); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = color or C.TextDim
    l.Font = Enum.Font.Gotham; l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left
end

-- Заполнение табов
do
    local p = TabPages["Aimbot"]
    local s1 = Section(p, "☾ SILENT AIM")
    Toggle(s1, "Enable Silent Aim", "SilentAim")
    Toggle(s1, "Auto Prediction", "AutoPrediction")
    Toggle(s1, "Resolver", "Resolver")
    Toggle(s1, "Velocity Smoothing", "ResolverSmoothing")
    Toggle(s1, "Visible Check", "VisibleCheck")
    Toggle(s1, "Team Check", "TeamCheck")
    Toggle(s1, "Ignore Downed", "IgnoreDowned")
    Slider(s1, "FOV", "FOV", 30, 500)
    Slider(s1, "Manual Prediction", "ManualPrediction", 0.05, 0.3, 3)
    Slider(s1, "Prediction Multiplier", "PredictionMultiplier", 0.5, 2.0, 2)
    Dropdown(s1, "Hit Part", {"Head","HumanoidRootPart","UpperTorso"}, "SilentAimPart")
    local s2 = Section(p, "⚡ WEAPON PRESETS")
    Button(s2, "🔫 Pistol", function() CFG.PredictionMultiplier=0.95; Notify("Eventide","Pistol",2) end)
    Button(s2, "⚡ AR/SMG", function() CFG.PredictionMultiplier=1.0; Notify("Eventide","AR",2) end)
    Button(s2, "🎯 Sniper", function() CFG.PredictionMultiplier=1.15; Notify("Eventide","Sniper",2) end)
    Button(s2, "💥 Shotgun", function() CFG.PredictionMultiplier=0.85; Notify("Eventide","Shotgun",2) end)
    local s3 = Section(p, "CROSSHAIR")
    Toggle(s3, "Custom Crosshair", "Crosshair")
    Slider(s3, "Size", "CrosshairSize", 2, 30)
    Slider(s3, "Gap", "CrosshairGap", 0, 15)
end
do
    local p = TabPages["Visuals"]
    local s1 = Section(p, "ESP")
    Toggle(s1, "Enable ESP", "ESP"); Toggle(s1, "Boxes", "Boxes")
    Toggle(s1, "Names", "Names"); Toggle(s1, "Health Bar", "Health")
    Toggle(s1, "Distance", "Distance"); Toggle(s1, "Head Dot", "HeadDot")
    Toggle(s1, "Tracers", "Tracers")
    Slider(s1, "Max Distance", "MaxDistance", 100, 5000)
    local s2 = Section(p, "FOV")
    Toggle(s2, "Show FOV Circle", "ShowFOV")
    Toggle(s2, "Show Prediction Dot", "ShowPredDot")
    Toggle(s2, "Rainbow", "FOVRainbow")
    Toggle(s2, "Show Debug Info", "ShowDebugInfo")
end
do
    local p = TabPages["Bypass"]
    local s0 = Section(p, "🛡 BYPASS STATUS")
    local statusBox = Instance.new("Frame", s0)
    statusBox.Size = UDim2.new(1, 0, 0, 100); statusBox.BackgroundColor3 = C.BG3
    Instance.new("UICorner", statusBox).CornerRadius = UDim.new(0, 6)
    local statusLbl = Instance.new("TextLabel", statusBox)
    statusLbl.Size = UDim2.new(1, -20, 1, -10); statusLbl.Position = UDim2.new(0, 10, 0, 5)
    statusLbl.BackgroundTransparency = 1; statusLbl.TextColor3 = C.Text
    statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 11
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left; statusLbl.TextYAlignment = Enum.TextYAlignment.Top
    statusLbl.Text = string.format(
        "🖥 Executor: %s\n%s hookmetamethod\n%s newcclosure\n%s protect_gui\n%s Anti-Kick (namecall)",
        ExecutorName,
        Bypass.hookmm and "✓" or "✗",
        Bypass.newccl and "✓" or "✗",
        Bypass.protectgui and "✓" or "✗",
        Bypass.canHook and CFG.AntiKick and "✓" or "✗"
    )
    local s1 = Section(p, "🛡 PROTECTION")
    Toggle(s1, "Anti-Kick", "AntiKick")
    Toggle(s1, "Randomize GUI Name", "RandomizeName")
    local s2 = Section(p, "ℹ SAFE MODE INFO")
    Label(s2, "v2.1 использует ТОЛЬКО безопасные", C.Text)
    Label(s2, "методы (без hookfunction на C-funcs)", C.Text)
    Label(s2, "")
    Label(s2, "✓ hookmetamethod (safe)", C.Green)
    Label(s2, "✓ newcclosure (safe)", C.Green)
    Label(s2, "✓ Delayed init (3-5s)", C.Green)
    Label(s2, "✓ Random GUI name", C.Green)
    Label(s2, "✓ checkcaller protection", C.Green)
    Label(s2, "")
    Label(s2, "✗ hookfunction on Kick (crashes!)", C.Red)
    Label(s2, "✗ hookfunction on Teleport (crashes!)", C.Red)
end
do
    local p = TabPages["Player"]
    local s1 = Section(p, "YOUR INFO")
    local ib = Instance.new("Frame", s1)
    ib.Size = UDim2.new(1, 0, 0, 80); ib.BackgroundColor3 = C.BG3
    Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 6)
    local il = Instance.new("TextLabel", ib)
    il.Size = UDim2.new(1, -20, 1, -10); il.Position = UDim2.new(0, 10, 0, 5)
    il.BackgroundTransparency = 1; il.TextColor3 = C.Text
    il.Font = Enum.Font.Gotham; il.TextSize = 11
    il.TextXAlignment = Enum.TextXAlignment.Left; il.TextYAlignment = Enum.TextYAlignment.Top
    task.spawn(function()
        while ScreenGui.Parent do
            pcall(function()
                local ch = LP.Character; local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                il.Text = string.format("👤 %s\n❤️ %d/%d HP\n📶 %dms | ⚡ %d FPS\n🎯 Pred: %dms",
                    LP.Name, hum and math.floor(hum.Health) or 0, hum and math.floor(hum.MaxHealth) or 100,
                    math.floor(GetPing()), FPS, math.floor(currentPredValue * 1000))
            end)
            task.wait(0.5)
        end
    end)
    local s2 = Section(p, "TARGET")
    local tb = Instance.new("Frame", s2)
    tb.Size = UDim2.new(1, 0, 0, 80); tb.BackgroundColor3 = C.BG3
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    local tl = Instance.new("TextLabel", tb)
    tl.Size = UDim2.new(1, -20, 1, -10); tl.Position = UDim2.new(0, 10, 0, 5)
    tl.BackgroundTransparency = 1; tl.TextColor3 = C.TextDim
    tl.Font = Enum.Font.Gotham; tl.TextSize = 11
    tl.TextXAlignment = Enum.TextXAlignment.Left; tl.TextYAlignment = Enum.TextYAlignment.Top
    tl.Text = "No target"
    task.spawn(function()
        while ScreenGui.Parent do
            pcall(function()
                if Target and Target.Character then
                    local root = GetRoot(Target); local hum = GetHum(Target); local myR = GetRoot(LP)
                    local dist = (myR and root) and (myR.Position - root.Position).Magnitude or 0
                    local vel = root and math.floor(root.AssemblyLinearVelocity.Magnitude) or 0
                    tl.Text = string.format("🎯 %s\n❤️ %d HP | 📏 %dm\n💨 Velocity: %d\n✓ Locked",
                        Target.Name, hum and math.floor(hum.Health) or 0, math.floor(dist), vel)
                    tl.TextColor3 = C.Green
                else tl.Text = "🔍 Searching..."; tl.TextColor3 = C.TextDim end
            end)
            task.wait(0.2)
        end
    end)
end
do
    local p = TabPages["Settings"]
    local s1 = Section(p, "HOTKEYS")
    Label(s1, "INSERT — open/close menu", C.Text)
    Label(s1, "F2 — Silent Aim on/off", C.Text)
    Label(s1, "F3 — ESP on/off", C.Text)
    Label(s1, "END — unload", C.Red)
    local s2 = Section(p, "ABOUT")
    Label(s2, "☾ EVENTIDE v2.1", C.Accent)
    Label(s2, "Safe Bypass Edition", C.Accent2)
    Label(s2, "Executor: "..ExecutorName, C.Green)
    local s3 = Section(p, "UNLOAD")
    Button(s3, "🗑 UNLOAD", function()
        for _, o in pairs({FOVCircle, PredDot, PredLine, CH_Top, CH_Bot, CH_Left, CH_Right, DebugText}) do
            pcall(function() o:Remove() end)
        end
        for p2 in pairs(ESPObjects) do RemoveESP(p2) end
        pcall(function() ScreenGui:Destroy() end)
        env._EV_ACTIVE = nil
        Notify("Eventide", "Unloaded", 3)
    end, C.Red)
end

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Insert then Main.Visible = not Main.Visible end
    if inp.KeyCode == Enum.KeyCode.F2 then
        CFG.SilentAim = not CFG.SilentAim
        Notify("Silent Aim", CFG.SilentAim and "✓ ON" or "✗ OFF", 2)
    end
    if inp.KeyCode == Enum.KeyCode.F3 then
        CFG.ESP = not CFG.ESP
        Notify("ESP", CFG.ESP and "✓ ON" or "✗ OFF", 2)
    end
    if inp.KeyCode == Enum.KeyCode.End then
        for _, o in pairs({FOVCircle, PredDot, PredLine, CH_Top, CH_Bot, CH_Left, CH_Right, DebugText}) do
            pcall(function() o:Remove() end)
        end
        for p in pairs(ESPObjects) do RemoveESP(p) end
        pcall(function() ScreenGui:Destroy() end)
        env._EV_ACTIVE = nil
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        pcall(function()
            FPSLbl.Text = FPS .. " FPS"
            FPSLbl.TextColor3 = FPS > 40 and C.Green or FPS > 20 and C.Yellow or C.Red
            local ping = math.floor(GetPing())
            PingLbl.Text = ping .. " MS"
            PingLbl.TextColor3 = ping < 100 and C.Green or ping < 200 and C.Yellow or C.Red
        end)
        task.wait(0.5)
    end
end)

Notify("☾ EVENTIDE v2.1", "Safe Bypass loaded ["..ExecutorName.."]", 4)