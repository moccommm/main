-- ===============================================
--   Da Hood Safe v11 - PRO HEAD AIM
--   ТОЛЬКО ГОЛОВА | Максимальная точность
--   Anti-Kick | Smart Prediction
-- ===============================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3)

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local CG = game:GetService("CoreGui")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()

if not Drawing then warn("No Drawing") return end

local function GetPing()
    local p = 100
    pcall(function() p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return p
end

local function CalcPred()
    local ping = GetPing() / 1000
    return ping + 0.04
end

local function GetFPS()
    return math.floor(1 / RS.RenderStepped:Wait())
end

local function Notify(t, m, d)
    pcall(function() game.StarterGui:SetCore("SendNotification", {Title=t,Text=m,Duration=d or 3}) end)
end

local function Draw(t, p)
    local s, o = pcall(Drawing.new, t)
    if not s then return nil end
    for k, v in pairs(p or {}) do pcall(function() o[k] = v end) end
    return o
end

local function Tw(obj, props, dur)
    TS:Create(obj, TweenInfo.new(dur or 0.3, Enum.EasingStyle.Quint), props):Play()
end

-- ==================== CONFIG ====================
local CFG = {
    -- Aim Core (HEAD ONLY)
    Enabled = true, AimKey = "MB2", FOV = 180,
    Pred = CalcPred(),
    TeamCheck = false, NoDowned = true, NoCuffed = true, AutoPred = true,
    IgnoreWalls = true,

    -- Advanced HEAD prediction
    SmartPrediction = true,
    VelocityComp = 1.0,
    PredictJump = true, PredictFall = true,
    HeadOffset = 0.0,        -- Смещение прицела вверх/вниз (fine-tune)
    UsePingComp = true,      -- Ping compensation
    PingMultiplier = 1.0,    -- Множитель компенсации пинга
    UseAccel = true,         -- Учёт ускорения
    VelocitySmoothing = 0.6, -- 0-1, чем выше тем плавнее
    MaxPrediction = 0.35,    -- Ограничение макс. предикшна
    ResolverEnabled = true,  -- Resolver для активно движущихся

    TargetPriority = "Distance",

    -- ESP
    ShowFOV = true, ShowDot = true, ShowLine = true,
    ShowESP = true, ShowNames = true, ShowHP = true,
    ShowDist = true, RainbowFOV = false, ShowPredPath = true,
    ShowHeadDot = true,      -- Точка на голове цели

    -- Effects
    Wings = false, WingStyle = "Angel",
    Aura = false, AuraRainbow = false,
    Trail = false, TrailRainbow = false,
    FloatingRings = false, Halo = false,
    BodyGlow = false, Orbs = false,

    -- Bullets
    BulletTrail = false, BulletTrailColor = Color3.fromRGB(255, 55, 85),
    BulletTrailRainbow = false, MuzzleFlash = false,
    HitMarker = false,
}

local Alive = true
local Target = nil
local Aiming = false
local RainbowHue = 0
local ActiveEffects = {}
local VelHistory = {}
local PosHistory = {}   -- История позиций для точного предикшна
local CurrentTab = "Aim"

-- ==================== ADVANCED VELOCITY & POSITION TRACKING ====================
local function UpdateHistory(plr, pos, vel)
    if not VelHistory[plr] then VelHistory[plr] = {} end
    if not PosHistory[plr] then PosHistory[plr] = {} end

    local t = tick()
    table.insert(VelHistory[plr], {vel=vel, time=t})
    table.insert(PosHistory[plr], {pos=pos, time=t})

    if #VelHistory[plr] > 15 then table.remove(VelHistory[plr], 1) end
    if #PosHistory[plr] > 15 then table.remove(PosHistory[plr], 1) end
end

local function GetSmoothedVel(plr)
    if not VelHistory[plr] or #VelHistory[plr] < 3 then return Vector3.zero end
    local sum = Vector3.zero
    local weight = 0
    -- Больший вес недавним данным
    for i, e in ipairs(VelHistory[plr]) do
        local w = i / #VelHistory[plr]
        sum = sum + e.vel * w
        weight = weight + w
    end
    return sum / weight
end

local function GetAccel(plr)
    if not VelHistory[plr] or #VelHistory[plr] < 3 then return Vector3.zero end
    local last = VelHistory[plr][#VelHistory[plr]]
    local prev = VelHistory[plr][#VelHistory[plr]-2]  -- Берём 2 назад для стабильности
    local dt = last.time - prev.time
    if dt <= 0 then return Vector3.zero end
    return (last.vel - prev.vel) / dt
end

-- Resolver - определяет "истинную" позицию цели
local function ResolveTargetPos(plr, currentPos)
    if not CFG.ResolverEnabled then return currentPos end
    if not PosHistory[plr] or #PosHistory[plr] < 5 then return currentPos end

    -- Проверяем стабильность позиций (не телепортируется ли)
    local recent = PosHistory[plr][#PosHistory[plr]]
    local older = PosHistory[plr][#PosHistory[plr] - 4]
    local dt = recent.time - older.time

    if dt > 0 then
        local expectedVel = (recent.pos - older.pos) / dt
        local actualVel = GetSmoothedVel(plr)

        -- Если реальная скорость сильно отличается — используем расчётную
        if (expectedVel - actualVel).Magnitude > 20 then
            return currentPos + (expectedVel * CFG.Pred * 0.5)
        end
    end

    return currentPos
end

-- ==================== CHECKS ====================
local function IsValid(plr)
    if not plr or plr == LP then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    -- ТОЛЬКО ГОЛОВА
    if not ch:FindFirstChild("Head") then return false end

    if CFG.TeamCheck then
        local ok, same = pcall(function() return plr.Team and LP.Team and plr.Team == LP.Team end)
        if ok and same then return false end
    end
    if CFG.NoDowned then
        local ok, d = pcall(function()
            local be = ch:FindFirstChild("BodyEffects")
            if be then local ko = be:FindFirstChild("K.O"); if ko then return ko.Value end end
            return false
        end)
        if ok and d then return false end
    end
    if CFG.NoCuffed then
        local ok, c = pcall(function() return ch:FindFirstChild("Handcuffed") ~= nil end)
        if ok and c then return false end
    end
    return true
end

local function IsHeadVisible(headPos)
    if not CFG.IgnoreWalls then return true end
    local ch = LP.Character
    if not ch then return false end
    local myHead = ch:FindFirstChild("Head")
    if not myHead then return false end

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances = {ch, workspace.CurrentCamera}

    local dir = (headPos - myHead.Position)
    local result = workspace:Raycast(myHead.Position, dir, rp)
    if not result then return true end

    local hit = result.Instance
    if hit and hit.Parent then
        local p = Players:GetPlayerFromCharacter(hit.Parent)
        if p and p ~= LP then return true end
    end
    return math.abs((result.Position - myHead.Position).Magnitude - dir.Magnitude) < 3
end

-- ==================== TARGET SELECTION (HEAD ONLY) ====================
local function GetTarget()
    local cands = {}
    local cx = Cam.ViewportSize.X/2
    local cy = Cam.ViewportSize.Y/2

    for _, p in ipairs(Players:GetPlayers()) do
        if IsValid(p) then
            local head = p.Character:FindFirstChild("Head")
            if head then
                local sp, vis = Cam:WorldToViewportPoint(head.Position)
                if vis then
                    local sd = ((sp.X-cx)^2+(sp.Y-cy)^2)^0.5
                    if sd < CFG.FOV then
                        if not CFG.IgnoreWalls or IsHeadVisible(head.Position) then
                            local hp = 100
                            pcall(function() hp = p.Character:FindFirstChildOfClass("Humanoid").Health end)
                            table.insert(cands, {player=p, sd=sd, hp=hp, head=head})

                            local root = p.Character:FindFirstChild("HumanoidRootPart")
                            if root then
                                UpdateHistory(p, head.Position, root.AssemblyLinearVelocity)
                            end
                        end
                    end
                end
            end
        end
    end

    if #cands == 0 then Target = nil; return nil end
    if CFG.TargetPriority == "HP" then
        table.sort(cands, function(a,b) return a.hp < b.hp end)
    else
        table.sort(cands, function(a,b) return a.sd < b.sd end)
    end
    Target = cands[1].player
    return Target
end

-- ==================== PRECISE HEAD PREDICTION ====================
local function PredictHeadPos()
    if not Target then return nil end
    local ch = Target.Character
    if not ch then return nil end
    local head = ch:FindFirstChild("Head")
    if not head then return nil end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return head.Position end

    -- Базовая позиция головы
    local basePos = head.Position

    -- Применяем resolver
    if CFG.ResolverEnabled then
        basePos = ResolveTargetPos(Target, basePos)
    end

    -- Расчёт скорости
    local rawVel = root.AssemblyLinearVelocity
    local finalVel = rawVel

    if CFG.SmartPrediction then
        local smoothVel = GetSmoothedVel(Target)
        if smoothVel.Magnitude > 0.5 then
            -- Смешиваем текущую и усреднённую с коэффициентом
            local smooth = CFG.VelocitySmoothing
            finalVel = rawVel * (1 - smooth) + smoothVel * smooth
        end
    end

    finalVel = finalVel * CFG.VelocityComp

    -- Ping compensation
    local predTime = CFG.Pred
    if CFG.UsePingComp then
        predTime = predTime * CFG.PingMultiplier
    end
    predTime = math.min(predTime, CFG.MaxPrediction)

    -- Базовое предсказание позиции
    local predicted = basePos + (finalVel * predTime)

    -- Учёт ускорения (для резких манёвров)
    if CFG.UseAccel and CFG.SmartPrediction then
        local accel = GetAccel(Target)
        local accelMag = accel.Magnitude
        if accelMag > 3 and accelMag < 50 then  -- Игнорируем нереалистичные ускорения
            predicted = predicted + (accel * predTime * predTime * 0.5)
        end
    end

    -- Компенсация прыжка
    if CFG.PredictJump then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Jumping then
                -- Скорость прыжка вверх
                predicted = predicted + Vector3.new(0, 25 * predTime, 0)
            elseif state == Enum.HumanoidStateType.Freefall and CFG.PredictFall then
                -- Гравитация
                local gravity = workspace.Gravity or 196.2
                predicted = predicted + Vector3.new(0, -gravity * predTime * predTime * 0.5, 0)
            end
        end
    end

    -- Fine-tune смещение головы
    predicted = predicted + Vector3.new(0, CFG.HeadOffset, 0)

    return predicted
end

-- ==================== INPUT ====================
local lastShoot = 0
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - lastShoot > 0.1 then
            lastShoot = tick()
            if CFG.BulletTrail or CFG.MuzzleFlash then
                local ch = LP.Character
                if ch then
                    local tool = ch:FindFirstChildOfClass("Tool")
                    if tool then
                        local handle = tool:FindFirstChild("Handle")
                        local origin = handle and handle.Position or (ch.Head and ch.Head.Position)
                        if origin then
                            local target = Mouse.Hit.Position
                            if CFG.MuzzleFlash then
                                local flash = Instance.new("Part")
                                flash.Size = Vector3.new(1.5,1.5,1.5); flash.Position = origin
                                flash.Anchored = true; flash.CanCollide = false; flash.Shape = Enum.PartType.Ball
                                flash.Material = Enum.Material.Neon; flash.Color = Color3.fromRGB(255,200,50)
                                flash.Transparency = 0.3; flash.Parent = workspace
                                local l = Instance.new("PointLight",flash); l.Color = flash.Color; l.Brightness = 8; l.Range = 15
                                spawn(function()
                                    for i=0,5 do pcall(function()
                                        flash.Size = Vector3.new(1.5-i*0.25,1.5-i*0.25,1.5-i*0.25)
                                        flash.Transparency = 0.3+i*0.14
                                    end); task.wait(0.02) end
                                    pcall(function() flash:Destroy() end)
                                end)
                            end
                            if CFG.BulletTrail then
                                local dir = (target-origin); local dist = dir.Magnitude
                                if dist < 500 then
                                    local mid = origin + dir/2
                                    local trail = Instance.new("Part")
                                    trail.Size = Vector3.new(0.15,0.15,dist)
                                    trail.CFrame = CFrame.new(mid,target)
                                    trail.Anchored = true; trail.CanCollide = false; trail.Material = Enum.Material.Neon
                                    trail.Color = CFG.BulletTrailRainbow and Color3.fromHSV((tick()*0.3)%1,1,1) or CFG.BulletTrailColor
                                    trail.Parent = workspace
                                    local l = Instance.new("PointLight",trail); l.Color = trail.Color; l.Brightness = 2; l.Range = 6
                                    spawn(function()
                                        for i=0,10 do pcall(function() trail.Transparency = i/10 end); task.wait(0.02) end
                                        pcall(function() trail:Destroy() end)
                                    end)
                                end
                            end
                            if CFG.HitMarker and Target then
                                local size = 20; local cx = Cam.ViewportSize.X/2; local cy = Cam.ViewportSize.Y/2
                                local lines = {}
                                for i=1,4 do lines[i] = Draw("Line",{Thickness=2,Color=Color3.fromRGB(255,50,50),Visible=true}) end
                                lines[1].From=Vector2.new(cx-size,cy-size); lines[1].To=Vector2.new(cx-size/3,cy-size/3)
                                lines[2].From=Vector2.new(cx+size,cy-size); lines[2].To=Vector2.new(cx+size/3,cy-size/3)
                                lines[3].From=Vector2.new(cx-size,cy+size); lines[3].To=Vector2.new(cx-size/3,cy+size/3)
                                lines[4].From=Vector2.new(cx+size,cy+size); lines[4].To=Vector2.new(cx+size/3,cy+size/3)
                                spawn(function() task.wait(0.3); for _,l in ipairs(lines) do pcall(function() l:Remove() end) end end)
                            end
                        end
                    end
                end
            end
        end
    end

    if CFG.AimKey == "MB2" and inp.UserInputType == Enum.UserInputType.MouseButton2 then Aiming = true end
    if CFG.AimKey == "MB1" and inp.UserInputType == Enum.UserInputType.MouseButton1 then Aiming = true end
    if CFG.AimKey == "Q" and inp.KeyCode == Enum.KeyCode.Q then Aiming = true end
    if CFG.AimKey == "E" and inp.KeyCode == Enum.KeyCode.E then Aiming = true end
end)

UIS.InputEnded:Connect(function(inp)
    if CFG.AimKey == "MB2" and inp.UserInputType == Enum.UserInputType.MouseButton2 then Aiming = false end
    if CFG.AimKey == "MB1" and inp.UserInputType == Enum.UserInputType.MouseButton1 then Aiming = false end
    if CFG.AimKey == "Q" and inp.KeyCode == Enum.KeyCode.Q then Aiming = false end
    if CFG.AimKey == "E" and inp.KeyCode == Enum.KeyCode.E then Aiming = false end
end)

spawn(function() while Alive do if CFG.AutoPred then CFG.Pred = CalcPred() end; task.wait(0.5) end end)

-- ==================== HOOKS (HEAD ONLY) ====================
local HookOK = false
if hookmetamethod then
    pcall(function()
        local old
        old = hookmetamethod(game, "__index", newcclosure(function(self, k)
            if not Alive or not CFG.Enabled or not Aiming then return old(self, k) end
            local ok2, isMouse = pcall(function() return self == Mouse end)
            if not ok2 or not isMouse then return old(self, k) end
            local pos = PredictHeadPos(); if not pos then return old(self, k) end
            if k == "Hit" then return CFrame.new(pos) end
            if k == "Target" then
                if Target and Target.Character then
                    local head = Target.Character:FindFirstChild("Head")
                    if head then return head end
                end
            end
            if k == "UnitRay" then return Ray.new(Cam.CFrame.Position, (pos-Cam.CFrame.Position).Unit) end
            if k == "X" then return (Cam:WorldToViewportPoint(pos)).X end
            if k == "Y" then return (Cam:WorldToViewportPoint(pos)).Y end
            return old(self, k)
        end))
        HookOK = true
    end)
    pcall(function()
        local old2
        old2 = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if not Alive or not CFG.Enabled or not Aiming then return old2(self, ...) end
            local m = getnamecallmethod(); local a = {...}
            local pos = PredictHeadPos(); if not pos then return old2(self, ...) end
            if m == "Raycast" and self == workspace then
                if typeof(a[1]) == "Vector3" then return old2(self, a[1], (pos-a[1]).Unit*5000, select(3, ...)) end
            end
            if m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRay" or m == "FindPartOnRayWithWhitelist" then
                if a[1] and typeof(a[1]) == "Ray" then
                    a[1] = Ray.new(a[1].Origin, (pos-a[1].Origin).Unit*5000)
                    return old2(self, unpack(a))
                end
            end
            return old2(self, ...)
        end))
    end)
end

-- ==================== EFFECTS ====================
local function ClearEffect(name)
    if ActiveEffects[name] then pcall(function() ActiveEffects[name]:Destroy() end); ActiveEffects[name] = nil end
end
local function ClearAll() for n in pairs(ActiveEffects) do ClearEffect(n) end end
local function GetChar() return LP.Character end
local function GetRoot() local ch = GetChar(); return ch and ch:FindFirstChild("HumanoidRootPart") end
local function GetTorso() local ch = GetChar(); return ch and (ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")) end
local function GetHead() local ch = GetChar(); return ch and ch:FindFirstChild("Head") end

local function NeonPart(parent, size, color, trans)
    local p = Instance.new("Part"); p.Size = size; p.Material = Enum.Material.Neon
    p.Color = color; p.CanCollide = false; p.Anchored = false
    p.Transparency = trans or 0; p.Parent = parent; return p
end

local function CreateWings()
    ClearEffect("Wings")
    local torso = GetTorso(); if not torso then return end
    local folder = Instance.new("Model"); folder.Name = "MyWings"; folder.Parent = torso
    ActiveEffects["Wings"] = folder
    local styles = {
        Angel={c=Color3.fromRGB(255,255,255),g=Color3.fromRGB(255,215,0),n=8},
        Demon={c=Color3.fromRGB(30,0,0),g=Color3.fromRGB(255,0,0),n=6},
        Fire={c=Color3.fromRGB(255,100,0),g=Color3.fromRGB(255,200,0),n=7},
        Ice={c=Color3.fromRGB(150,200,255),g=Color3.fromRGB(200,230,255),n=7},
        Rainbow={c=Color3.new(1,1,1),g=Color3.new(1,1,1),n=8,r=true},
    }
    local st = styles[CFG.WingStyle] or styles.Angel
    local function MakeWing(side)
        local parts = {}
        for i = 1, st.n do
            local f = NeonPart(folder, Vector3.new(4.5-(i-1)*0.3,0.15,0.15), st.c, 0.1)
            local w = Instance.new("Weld"); w.Part0=torso; w.Part1=f
            w.C0 = CFrame.new(side*(0.3+(i-1)*0.15),0.3+(i-1)*0.15,0.5)*CFrame.Angles(0,math.rad(side*-70),math.rad(side*(20+(i-1)*8)*30/57.3))
            w.Parent = f
            Instance.new("PointLight",f).Color = st.g
            table.insert(parts,{p=f,w=w,bc=w.C0,i=i})
        end
        return parts
    end
    local lw = MakeWing(-1); local rw = MakeWing(1)
    spawn(function() local t=0; while Alive and ActiveEffects["Wings"] and CFG.Wings do
        t=t+0.08; local flap=math.sin(t)*0.3
        for _,f in ipairs(lw) do pcall(function() f.w.C0=f.bc*CFrame.Angles(0,0,flap+math.sin(t+f.i*0.3)*0.15)
            if st.r or CFG.AuraRainbow then f.p.Color=Color3.fromHSV(((tick()*0.2)+(f.i*0.1))%1,1,1) end end) end
        for _,f in ipairs(rw) do pcall(function() f.w.C0=f.bc*CFrame.Angles(0,0,-flap-math.sin(t+f.i*0.3)*0.15)
            if st.r or CFG.AuraRainbow then f.p.Color=Color3.fromHSV(((tick()*0.2)+(f.i*0.1)+0.5)%1,1,1) end end) end
        task.wait(0.03) end end)
end

local function CreateAura()
    ClearEffect("Aura"); local root = GetRoot(); if not root then return end
    local folder = Instance.new("Folder"); folder.Parent = root; ActiveEffects["Aura"] = folder
    local ground = NeonPart(folder, Vector3.new(6,0.1,6), CFG.BulletTrailColor, 0.5)
    ground.Shape = Enum.PartType.Cylinder
    local gw = Instance.new("Weld"); gw.Part0=root; gw.Part1=ground
    gw.C0=CFrame.new(0,-3,0)*CFrame.Angles(0,0,math.rad(90)); gw.Parent=ground
    local att = Instance.new("Attachment",root); att.Parent=folder
    local e = Instance.new("ParticleEmitter"); e.Rate=100; e.Lifetime=NumberRange.new(0.5,1.2)
    e.Speed=NumberRange.new(2,5); e.SpreadAngle=Vector2.new(180,180)
    e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,1)})
    e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.5),NumberSequenceKeypoint.new(1,0)})
    e.Texture="rbxassetid://6823507655"; e.LightEmission=1; e.Color=ColorSequence.new(CFG.BulletTrailColor); e.Parent=att
    local light = Instance.new("PointLight"); light.Brightness=4; light.Range=20; light.Color=CFG.BulletTrailColor; light.Parent=folder
    spawn(function() while Alive and ActiveEffects["Aura"] and CFG.Aura do
        if CFG.AuraRainbow then local c=Color3.fromHSV((tick()*0.15)%1,1,1)
            pcall(function() e.Color=ColorSequence.new(c); light.Color=c; ground.Color=c end) end
        pcall(function() ground.Size = Vector3.new(6+math.sin(tick()*3)*1,0.1,6+math.sin(tick()*3)*1) end)
        task.wait(0.05) end end)
end

local function CreateHalo()
    ClearEffect("Halo"); local head = GetHead(); if not head then return end
    local halo = NeonPart(head, Vector3.new(3,0.15,3), Color3.fromRGB(255,215,0), 0.1)
    halo.Shape = Enum.PartType.Cylinder; ActiveEffects["Halo"] = halo
    local w = Instance.new("Weld"); w.Part0=head; w.Part1=halo
    w.C0=CFrame.new(0,1.5,0)*CFrame.Angles(0,0,math.rad(90)); w.Parent=halo
    Instance.new("PointLight",halo).Color = Color3.fromRGB(255,215,0)
    spawn(function() local t=0; while Alive and ActiveEffects["Halo"] and CFG.Halo do
        t=t+0.05; pcall(function()
            w.C0=CFrame.new(0,1.5+math.sin(t)*0.1,0)*CFrame.Angles(0,math.rad(t*20),math.rad(90))
            if CFG.AuraRainbow then halo.Color=Color3.fromHSV((tick()*0.15)%1,1,1) end
        end); task.wait(0.03) end end)
end

local function CreateGlow()
    ClearEffect("BodyGlow"); local ch = GetChar(); if not ch then return end
    local folder = Instance.new("Folder"); folder.Parent=ch; ActiveEffects["BodyGlow"]=folder
    local hl = Instance.new("Highlight"); hl.FillColor=CFG.BulletTrailColor; hl.FillTransparency=0.5
    hl.OutlineColor=CFG.BulletTrailColor; hl.Adornee=ch; hl.Parent=folder
    spawn(function() while Alive and ActiveEffects["BodyGlow"] and CFG.BodyGlow do
        if CFG.AuraRainbow then local c=Color3.fromHSV((tick()*0.15)%1,1,1)
            pcall(function() hl.FillColor=c; hl.OutlineColor=c end) end
        pcall(function() hl.FillTransparency = math.sin(tick()*3)*0.2+0.5 end)
        task.wait(0.05) end end)
end

local function CreateTrail()
    ClearEffect("Trail"); local root = GetRoot(); if not root then return end
    local folder = Instance.new("Folder"); folder.Parent=root; ActiveEffects["Trail"]=folder
    local a0 = Instance.new("Attachment"); a0.Position=Vector3.new(0,2.5,0); a0.Parent=root
    local a1 = Instance.new("Attachment"); a1.Position=Vector3.new(0,-3,0); a1.Parent=root
    local trail = Instance.new("Trail"); trail.Attachment0=a0; trail.Attachment1=a1
    trail.Lifetime=1.2; trail.LightEmission=1; trail.FaceCamera=true
    trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
    trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1.5),NumberSequenceKeypoint.new(1,0)})
    trail.Color=ColorSequence.new(CFG.BulletTrailColor); trail.Texture="rbxassetid://6823507655"
    a0.Parent=folder; a1.Parent=folder; trail.Parent=folder
    spawn(function() while Alive and ActiveEffects["Trail"] and CFG.Trail do
        if CFG.TrailRainbow then local h1=(tick()*0.3)%1; local h2=(h1+0.3)%1
            pcall(function() trail.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(h1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(h2,1,1))}) end)
        end; task.wait(0.05) end end)
end

local function CreateRings()
    ClearEffect("Rings"); local root = GetRoot(); if not root then return end
    local folder = Instance.new("Folder"); folder.Parent=workspace; ActiveEffects["Rings"]=folder
    local rings = {}
    for i = 1, 4 do
        local r = NeonPart(folder, Vector3.new(8-i,0.3,8-i), Color3.fromRGB(120,80,255), 0.2)
        r.Shape=Enum.PartType.Cylinder; r.Anchored=true; rings[i]=r
    end
    spawn(function() local t=0; while Alive and ActiveEffects["Rings"] and CFG.FloatingRings do
        t=t+0.02; local r=GetRoot()
        if r then for i, ring in ipairs(rings) do
            local off = (i-1)*(math.pi/2); local y = math.sin(t*2+off)*2+(i-2)
            pcall(function()
                ring.CFrame = CFrame.new(r.Position+Vector3.new(0,y,0))*CFrame.Angles(math.rad(t*80+i*60),math.rad(t*40),math.rad(90))
                if CFG.AuraRainbow then ring.Color = Color3.fromHSV(((tick()*0.2)+(i*0.15))%1,1,1) end
            end) end end
        task.wait(0.02) end
        for _,r in ipairs(rings) do pcall(function() r:Destroy() end) end
    end)
end

local function CreateOrbs()
    ClearEffect("Orbs"); local root = GetRoot(); if not root then return end
    local folder = Instance.new("Folder"); folder.Parent=workspace; ActiveEffects["Orbs"]=folder
    local orbs = {}
    for i = 1, 6 do
        local o = NeonPart(folder, Vector3.new(0.8,0.8,0.8), CFG.BulletTrailColor, 0.2)
        o.Shape=Enum.PartType.Ball; o.Anchored=true; orbs[i]=o
        local a0=Instance.new("Attachment",o); a0.Position=Vector3.new(0.4,0,0)
        local a1=Instance.new("Attachment",o); a1.Position=Vector3.new(-0.4,0,0)
        local tr=Instance.new("Trail",o); tr.Attachment0=a0; tr.Attachment1=a1
        tr.Lifetime=0.5; tr.LightEmission=1; tr.Color=ColorSequence.new(CFG.BulletTrailColor)
        tr.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
    end
    spawn(function() local t=0; while Alive and ActiveEffects["Orbs"] and CFG.Orbs do
        t=t+0.03; local r=GetRoot()
        if r then for i,o in ipairs(orbs) do
            local ang = t+(i-1)*(math.pi*2/#orbs); local y = math.sin(t*2+i)*1.5
            pcall(function()
                o.CFrame = CFrame.new(r.Position.X+math.cos(ang)*4, r.Position.Y+y, r.Position.Z+math.sin(ang)*4)
                if CFG.AuraRainbow then o.Color = Color3.fromHSV((tick()*0.2+i*0.15)%1,1,1) end
            end) end end
        task.wait(0.02) end
        for _,o in ipairs(orbs) do pcall(function() o:Destroy() end) end
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

LP.CharacterAdded:Connect(function() task.wait(2); ClearAll(); UpdateEffects() end)
spawn(function() while Alive do UpdateEffects(); task.wait(1) end end)

-- ==================== DRAWINGS ====================
local fov = Draw("Circle", {Thickness=2,NumSides=100,Filled=false,Transparency=0.8,Visible=false})
local dot = Draw("Circle", {Thickness=2,NumSides=20,Filled=true,Radius=6,Transparency=1,Visible=false})
local line = Draw("Line", {Thickness=1.5,Transparency=0.8,Visible=false})
local info = Draw("Text", {Size=16,Font=2,Outline=true,Position=Vector2.new(10,10),Visible=false})
local pingTxt = Draw("Text", {Size=12,Font=2,Outline=true,Position=Vector2.new(10,32),Color=Color3.fromRGB(180,180,200),Visible=false})
local watermark = Draw("Text", {Size=18,Font=2,Outline=true,Color=Color3.fromRGB(255,55,85),Visible=true})
local predLine = Draw("Line", {Thickness=2,Color=Color3.fromRGB(0,255,255),Transparency=0.6,Visible=false})
local headDot = Draw("Circle", {Thickness=2,NumSides=16,Filled=true,Radius=4,Color=Color3.fromRGB(0,255,120),Transparency=1,Visible=false})

local ESP = {}
local function MakeESP(plr)
    if plr==LP or ESP[plr] then return end
    ESP[plr] = {
        dot=Draw("Circle",{Thickness=1,NumSides=14,Filled=true,Radius=4,Transparency=1,Visible=false}),
        name=Draw("Text",{Size=12,Center=true,Outline=true,Font=2,Visible=false}),
        hp=Draw("Text",{Size=11,Center=true,Outline=true,Font=2,Visible=false}),
        dist=Draw("Text",{Size=10,Center=true,Outline=true,Font=2,Color=Color3.fromRGB(180,180,180),Visible=false}),
    }
end
local function KillESP(plr)
    local e=ESP[plr]; if not e then return end
    for _,v in pairs(e) do pcall(function() v:Remove() end) end
    ESP[plr]=nil; VelHistory[plr]=nil; PosHistory[plr]=nil
end

-- ==================== RENDER ====================
local rc = RS.RenderStepped:Connect(function()
    if not Alive then return end
    Cam = workspace.CurrentCamera
    local cx=Cam.ViewportSize.X/2; local cy=Cam.ViewportSize.Y/2
    RainbowHue = (RainbowHue+0.003)%1
    local rainbow = Color3.fromHSV(RainbowHue,1,1)

    if CFG.Enabled then GetTarget() else Target=nil end

    if watermark then
        watermark.Position=Vector2.new(Cam.ViewportSize.X-220,10)
        watermark.Text="🎯 HEAD AIM v11"
        watermark.Color=CFG.RainbowFOV and rainbow or Color3.fromRGB(255,55,85)
        watermark.Visible=true
    end

    if fov then
        fov.Visible=CFG.ShowFOV and CFG.Enabled
        fov.Position=Vector2.new(cx,cy); fov.Radius=CFG.FOV
        fov.Color=CFG.RainbowFOV and rainbow or (Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,55,85))
    end

    -- Показываем куда целится (предикшн)
    local pos = PredictHeadPos()
    if pos and CFG.Enabled then
        local sp,vis = Cam:WorldToViewportPoint(pos)
        if vis then
            if dot and CFG.ShowDot then dot.Position=Vector2.new(sp.X,sp.Y); dot.Color=Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50); dot.Visible=true end
            if line and CFG.ShowLine then line.From=Vector2.new(cx,cy); line.To=Vector2.new(sp.X,sp.Y); line.Color=Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(100,100,120); line.Visible=true end

            -- Показываем реальную позицию головы + предикшн линию
            if CFG.ShowPredPath and Target and Target.Character and predLine then
                local head = Target.Character:FindFirstChild("Head")
                if head then
                    local csp,cv = Cam:WorldToViewportPoint(head.Position)
                    if cv then
                        predLine.From=Vector2.new(csp.X,csp.Y); predLine.To=Vector2.new(sp.X,sp.Y); predLine.Visible=true

                        -- Точка на реальной голове
                        if headDot and CFG.ShowHeadDot then
                            headDot.Position = Vector2.new(csp.X, csp.Y)
                            headDot.Color = Color3.fromRGB(255, 100, 100)
                            headDot.Visible = true
                        end
                    else
                        predLine.Visible=false
                        if headDot then headDot.Visible=false end
                    end
                end
            else
                if predLine then predLine.Visible=false end
                if headDot then headDot.Visible=false end
            end
        else
            if dot then dot.Visible=false end; if line then line.Visible=false end
            if predLine then predLine.Visible=false end; if headDot then headDot.Visible=false end
        end
    else
        if dot then dot.Visible=false end; if line then line.Visible=false end
        if predLine then predLine.Visible=false end; if headDot then headDot.Visible=false end
    end

    if info then
        if CFG.Enabled then
            local vel = Target and GetSmoothedVel(Target).Magnitude or 0
            info.Text=(Aiming and "🎯 LOCKED" or "🔍 SCAN").."  HEAD  "..(Target and Target.Name or "-").." | Vel: "..string.format("%.1f",vel)
            info.Color=Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50)
            info.Visible=true
        else info.Visible=false end
    end
    if pingTxt then
        pingTxt.Text="Ping: "..math.floor(GetPing()).."ms | Pred: "..string.format("%.3fs",CFG.Pred).." | Offset: "..string.format("%.2f",CFG.HeadOffset)
        pingTxt.Visible=CFG.Enabled
    end

    for plr,e in pairs(ESP) do
        if not plr or not plr.Parent then KillESP(plr)
        elseif CFG.ShowESP and IsValid(plr) then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local sp,vis = Cam:WorldToViewportPoint(head.Position)
                if vis then
                    local dist=100; pcall(function() local mr=LP.Character:FindFirstChild("HumanoidRootPart"); if mr then dist=(mr.Position-head.Position).Magnitude end end)
                    if e.dot then e.dot.Position=Vector2.new(sp.X,sp.Y); e.dot.Radius=math.clamp(500/dist,2,8); e.dot.Color=(Target==plr) and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,60,80); e.dot.Visible=true end
                    if e.name and CFG.ShowNames then e.name.Text=plr.Name; e.name.Position=Vector2.new(sp.X,sp.Y-18); e.name.Visible=true elseif e.name then e.name.Visible=false end
                    if e.hp and CFG.ShowHP then local hp=0; pcall(function() hp=math.floor(plr.Character:FindFirstChildOfClass("Humanoid").Health) end); e.hp.Text=hp.." HP"; e.hp.Position=Vector2.new(sp.X,sp.Y+10); e.hp.Color=Color3.fromRGB(255,255,100); e.hp.Visible=true elseif e.hp then e.hp.Visible=false end
                    if e.dist and CFG.ShowDist then e.dist.Text=math.floor(dist).."m"; e.dist.Position=Vector2.new(sp.X,sp.Y+22); e.dist.Visible=true elseif e.dist then e.dist.Visible=false end
                else for _,v in pairs(e) do v.Visible=false end end
            else for _,v in pairs(e) do v.Visible=false end end
        else for _,v in pairs(e) do v.Visible=false end end
    end
end)

for _,p in ipairs(Players:GetPlayers()) do MakeESP(p) end
Players.PlayerAdded:Connect(function(p) task.wait(1); MakeESP(p) end)
Players.PlayerRemoving:Connect(KillESP)

-- ==================== UI ====================
local G = Instance.new("ScreenGui")
G.Name="DHP_"..math.random(10000,99999); G.ResetOnSpawn=false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(G) end; G.Parent=CG end)
if not G.Parent then pcall(function() G.Parent=LP.PlayerGui end) end

local Th = {
    bg=Color3.fromRGB(10,10,16), card=Color3.fromRGB(20,20,30),
    cardH=Color3.fromRGB(28,28,42), accent=Color3.fromRGB(255,55,85),
    accent2=Color3.fromRGB(120,80,255), green=Color3.fromRGB(0,220,130),
    text=Color3.fromRGB(235,235,245), dim=Color3.fromRGB(100,100,130),
    on=Color3.fromRGB(0,220,130), off=Color3.fromRGB(50,50,65),
}

local Main=Instance.new("Frame")
Main.Size=UDim2.new(0,500,0,580); Main.Position=UDim2.new(0.5,-250,0.5,-290)
Main.BackgroundColor3=Th.bg; Main.BorderSizePixel=0; Main.ClipsDescendants=true
Main.Active=true; Main.Draggable=true; Main.Parent=G
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,14)

local bs=Instance.new("UIStroke",Main); bs.Thickness=1.5; bs.Transparency=0.4
spawn(function() while Alive do bs.Color=Color3.fromHSV((tick()*0.1)%1,0.7,1); task.wait(0.03) end end)

local topBar=Instance.new("Frame"); topBar.Size=UDim2.new(1,0,0,50); topBar.BackgroundColor3=Color3.fromRGB(14,14,22)
topBar.BorderSizePixel=0; topBar.Parent=Main; Instance.new("UICorner",topBar).CornerRadius=UDim.new(0,14)
local tf=Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,14); tf.Position=UDim2.new(0,0,1,-14)
tf.BackgroundColor3=Color3.fromRGB(14,14,22); tf.BorderSizePixel=0; tf.Parent=topBar

local logo=Instance.new("TextLabel"); logo.Size=UDim2.new(0,300,1,0); logo.Position=UDim2.new(0,16,0,0)
logo.BackgroundTransparency=1; logo.Text="🎯 HEAD AIM PRO"; logo.TextColor3=Th.accent
logo.Font=Enum.Font.GothamBlack; logo.TextSize=15; logo.TextXAlignment=Enum.TextXAlignment.Left; logo.Parent=topBar

local ver=Instance.new("TextLabel"); ver.Size=UDim2.new(0,50,0,20); ver.Position=UDim2.new(1,-70,0.5,-10)
ver.BackgroundColor3=Th.accent; ver.TextColor3=Color3.new(1,1,1); ver.Font=Enum.Font.GothamBold
ver.TextSize=10; ver.Text="v11"; ver.BorderSizePixel=0; ver.Parent=topBar
Instance.new("UICorner",ver).CornerRadius=UDim.new(1,0)

local tabBar=Instance.new("Frame"); tabBar.Size=UDim2.new(1,-20,0,36); tabBar.Position=UDim2.new(0,10,0,54)
tabBar.BackgroundColor3=Th.card; tabBar.BorderSizePixel=0; tabBar.Parent=Main
Instance.new("UICorner",tabBar).CornerRadius=UDim.new(0,8)
Instance.new("UIListLayout",tabBar).FillDirection=Enum.FillDirection.Horizontal

local allTabs={"Aim","Precision","Bullets","ESP","Effects","Info"}
local tabFrames={}; local tabButtons={}

for _,tn in ipairs(allTabs) do
    local tb=Instance.new("TextButton"); tb.Size=UDim2.new(1/#allTabs,0,1,0); tb.BackgroundTransparency=1
    tb.Text=tn; tb.TextColor3=(tn==CurrentTab) and Th.accent or Th.dim
    tb.Font=Enum.Font.GothamBold; tb.TextSize=11; tb.BorderSizePixel=0; tb.Parent=tabBar
    tabButtons[tn]=tb
end

local scrollArea=Instance.new("Frame"); scrollArea.Size=UDim2.new(1,-20,1,-100)
scrollArea.Position=UDim2.new(0,10,0,94); scrollArea.BackgroundTransparency=1
scrollArea.ClipsDescendants=true; scrollArea.Parent=Main

for _,tn in ipairs(allTabs) do
    local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,0,1,0)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=3
    scroll.ScrollBarImageColor3=Th.accent; scroll.CanvasSize=UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Visible=(tn==CurrentTab); scroll.Parent=scrollArea
    tabFrames[tn]=scroll
    Instance.new("UIListLayout",scroll).Padding=UDim.new(0,6)
    local p=Instance.new("UIPadding",scroll); p.PaddingTop=UDim.new(0,4); p.PaddingBottom=UDim.new(0,4)
end

for tn,btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        CurrentTab=tn
        for n,f in pairs(tabFrames) do f.Visible=(n==tn) end
        for n,b in pairs(tabButtons) do Tw(b,{TextColor3=(n==tn) and Th.accent or Th.dim},0.2) end
    end)
end

local function Sep(parent,text)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,22); f.BackgroundTransparency=1; f.Parent=parent
    local l=Instance.new("Frame",f); l.Size=UDim2.new(0.2,0,0,1); l.Position=UDim2.new(0,0,0.5,0); l.BackgroundColor3=Color3.fromRGB(40,40,55); l.BorderSizePixel=0
    local t=Instance.new("TextLabel",f); t.Size=UDim2.new(0.6,0,1,0); t.Position=UDim2.new(0.2,0,0,0); t.BackgroundTransparency=1; t.Text=string.upper(text); t.TextColor3=Th.dim; t.Font=Enum.Font.GothamBold; t.TextSize=10
    local r=Instance.new("Frame",f); r.Size=UDim2.new(0.2,0,0,1); r.Position=UDim2.new(0.8,0,0.5,0); r.BackgroundColor3=Color3.fromRGB(40,40,55); r.BorderSizePixel=0
end

local function Toggle(parent,name,key,icon)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,38); f.BackgroundColor3=Th.card; f.BorderSizePixel=0; f.Parent=parent
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
    f.MouseEnter:Connect(function() Tw(f,{BackgroundColor3=Th.cardH},0.15) end)
    f.MouseLeave:Connect(function() Tw(f,{BackgroundColor3=Th.card},0.15) end)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.7,0,1,0); lbl.Position=UDim2.new(0,16,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=(icon or "").."  "..name; lbl.TextColor3=Th.text
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local sw=Instance.new("Frame"); sw.Size=UDim2.new(0,46,0,24); sw.Position=UDim2.new(1,-60,0.5,-12); sw.BorderSizePixel=0; sw.Parent=f
    Instance.new("UICorner",sw).CornerRadius=UDim.new(1,0)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,20,0,20); knob.BorderSizePixel=0; knob.BackgroundColor3=Color3.new(1,1,1); knob.Parent=sw
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=f
    local function upd()
        if CFG[key] then Tw(sw,{BackgroundColor3=Th.on},0.2); Tw(knob,{Position=UDim2.new(1,-22,0.5,-10)},0.2)
        else Tw(sw,{BackgroundColor3=Th.off},0.2); Tw(knob,{Position=UDim2.new(0,2,0.5,-10)},0.2) end
    end; upd()
    btn.MouseButton1Click:Connect(function() CFG[key]=not CFG[key]; upd(); UpdateEffects() end)
end

local function Slider(parent,name,key,mn,mx,dec)
    dec=dec or 0
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,50); f.BackgroundColor3=Th.card; f.BorderSizePixel=0; f.Parent=parent
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-20,0,22); lbl.Position=UDim2.new(0,16,0,4)
    lbl.BackgroundTransparency=1; lbl.TextColor3=Th.text; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,-32,0,8); bar.Position=UDim2.new(0,16,0,32)
    bar.BackgroundColor3=Th.off; bar.BorderSizePixel=0; bar.Parent=f; Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)
    local fill=Instance.new("Frame"); fill.BorderSizePixel=0; fill.Parent=bar; Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
    Instance.new("UIGradient",fill).Color=ColorSequence.new(Th.accent2,Th.accent)
    local c=Instance.new("Frame"); c.Size=UDim2.new(0,16,0,16); c.BackgroundColor3=Color3.new(1,1,1); c.BorderSizePixel=0; c.ZIndex=5; c.Parent=bar
    Instance.new("UICorner",c).CornerRadius=UDim.new(1,0)
    local function upd() local p=math.clamp((CFG[key]-mn)/(mx-mn),0,1); fill.Size=UDim2.new(p,0,1,0); c.Position=UDim2.new(p,-8,0.5,-8)
        lbl.Text=name.."    "..(dec>0 and string.format("%."..dec.."f",CFG[key]) or tostring(math.floor(CFG[key]))) end
    upd()
    local drag=false
    bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local p=math.clamp((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1); local v=mn+(mx-mn)*p
        if dec>0 then CFG[key]=math.floor(v*10^dec)/10^dec else CFG[key]=math.floor(v) end; upd() end end)
end

local function BtnRow(parent,items)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,32); row.BackgroundTransparency=1; row.Parent=parent
    for i,item in ipairs(items) do
        local b=Instance.new("TextButton"); b.Size=UDim2.new(1/#items,-4,1,0); b.Position=UDim2.new((i-1)*(1/#items),2,0,0)
        b.BackgroundColor3=item.col or Th.card; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold
        b.TextSize=11; b.Text=item.name; b.BorderSizePixel=0; b.Parent=row
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
        b.MouseEnter:Connect(function() Tw(b,{BackgroundColor3=Th.accent},0.15) end)
        b.MouseLeave:Connect(function() Tw(b,{BackgroundColor3=item.col or Th.card},0.15) end)
        b.MouseButton1Click:Connect(function() item.cb(); UpdateEffects() end)
    end
end

-- BUILD TABS
local aim=tabFrames["Aim"]
Sep(aim,"🎯 HEAD AIM (Only Head)")
Toggle(aim,"Silent Aim","Enabled","🎯")
Toggle(aim,"Auto Prediction","AutoPred","⚡")
Slider(aim,"FOV","FOV",30,500)
Slider(aim,"Prediction","Pred",0.05,0.4,3)
Sep(aim,"Aim Key")
BtnRow(aim,{{name="RMB",col=Th.card,cb=function() CFG.AimKey="MB2" end},{name="LMB",col=Th.card,cb=function() CFG.AimKey="MB1" end},{name="Q",col=Th.card,cb=function() CFG.AimKey="Q" end},{name="E",col=Th.card,cb=function() CFG.AimKey="E" end}})
Sep(aim,"Filters")
Toggle(aim,"Team Check","TeamCheck","👥")
Toggle(aim,"Ignore Downed","NoDowned","💀")
Toggle(aim,"Ignore Cuffed","NoCuffed","🔗")
Toggle(aim,"Ignore Walls","IgnoreWalls","🧱")

local prec=tabFrames["Precision"]
Sep(prec,"🎯 Precision Settings")
Toggle(prec,"Smart Prediction","SmartPrediction","🧠")
Toggle(prec,"Predict Jump","PredictJump","🦘")
Toggle(prec,"Predict Fall","PredictFall","⬇️")
Toggle(prec,"Use Acceleration","UseAccel","📈")
Toggle(prec,"Ping Compensation","UsePingComp","🌐")
Toggle(prec,"Resolver","ResolverEnabled","🔧")
Sep(prec,"Fine Tune")
Slider(prec,"Head Offset (Y)","HeadOffset",-1,1,2)
Slider(prec,"Velocity Comp","VelocityComp",0.5,2,2)
Slider(prec,"Ping Multiplier","PingMultiplier",0.5,2,2)
Slider(prec,"Velocity Smoothing","VelocitySmoothing",0,1,2)
Slider(prec,"Max Prediction","MaxPrediction",0.1,0.5,2)
Sep(prec,"Target Priority")
BtnRow(prec,{{name="Distance",col=Color3.fromRGB(40,120,200),cb=function() CFG.TargetPriority="Distance" end},{name="Low HP",col=Color3.fromRGB(200,40,60),cb=function() CFG.TargetPriority="HP" end}})
Sep(prec,"Presets")
BtnRow(prec,{
    {name="💯 PERFECT",col=Color3.fromRGB(0,180,80),cb=function()
        CFG.SmartPrediction=true; CFG.PredictJump=true; CFG.PredictFall=true
        CFG.UseAccel=true; CFG.UsePingComp=true; CFG.ResolverEnabled=true
        CFG.VelocityComp=1.0; CFG.PingMultiplier=1.0; CFG.VelocitySmoothing=0.6
        CFG.HeadOffset=0; CFG.MaxPrediction=0.35; CFG.AutoPred=true
        Notify("Preset","Perfect settings applied",2)
    end},
    {name="⚡ FAST",col=Color3.fromRGB(200,150,0),cb=function()
        CFG.SmartPrediction=false; CFG.UseAccel=false
        CFG.VelocitySmoothing=0.3; CFG.PingMultiplier=1.0
        Notify("Preset","Fast (lower latency)",2)
    end},
})

local bul=tabFrames["Bullets"]
Sep(bul,"🔫 Bullet Effects")
Toggle(bul,"Bullet Trail","BulletTrail","💫")
Toggle(bul,"Rainbow Trail","BulletTrailRainbow","🌈")
Toggle(bul,"Muzzle Flash","MuzzleFlash","🔥")
Toggle(bul,"Hit Marker","HitMarker","✖️")

local espT=tabFrames["ESP"]
Sep(espT,"ESP")
Toggle(espT,"ESP","ShowESP","👁")
Toggle(espT,"Names","ShowNames","📝")
Toggle(espT,"HP","ShowHP","❤️")
Toggle(espT,"Distance","ShowDist","📏")
Sep(espT,"Aim Visuals")
Toggle(espT,"FOV Circle","ShowFOV","⭕")
Toggle(espT,"Target Dot","ShowDot","🔴")
Toggle(espT,"Target Line","ShowLine","📍")
Toggle(espT,"Prediction Path","ShowPredPath","📐")
Toggle(espT,"Head Marker","ShowHeadDot","🎯")
Toggle(espT,"Rainbow FOV","RainbowFOV","🌈")

local fx=tabFrames["Effects"]
Sep(fx,"Character Effects")
Toggle(fx,"Wings","Wings","🪽")
BtnRow(fx,{
    {name="Angel",col=Color3.fromRGB(255,215,0),cb=function() CFG.WingStyle="Angel"; ClearEffect("Wings") end},
    {name="Demon",col=Color3.fromRGB(150,0,0),cb=function() CFG.WingStyle="Demon"; ClearEffect("Wings") end},
    {name="Fire",col=Color3.fromRGB(255,100,0),cb=function() CFG.WingStyle="Fire"; ClearEffect("Wings") end},
    {name="🌈",col=Color3.fromRGB(255,50,150),cb=function() CFG.WingStyle="Rainbow"; ClearEffect("Wings") end},
})
Toggle(fx,"Aura","Aura","✨")
Toggle(fx,"Glow","BodyGlow","💡")
Toggle(fx,"Halo","Halo","😇")
Toggle(fx,"Trail","Trail","🌊")
Toggle(fx,"Rainbow Trail","TrailRainbow","🌈")
Toggle(fx,"Rings","FloatingRings","💫")
Toggle(fx,"Orbs","Orbs","🔮")
Toggle(fx,"Rainbow All","AuraRainbow","🌈")

local infoT=tabFrames["Info"]
Sep(infoT,"How to use")
local hlp=Instance.new("TextLabel"); hlp.Size=UDim2.new(1,0,0,140); hlp.BackgroundColor3=Th.card
hlp.TextColor3=Color3.new(1,1,1); hlp.Font=Enum.Font.Gotham; hlp.TextSize=11; hlp.TextWrapped=true
hlp.Text="🎯 ТОЛЬКО ГОЛОВА (Head Only)\n\n💯 Для максимальной точности:\n1. Включи PERFECT в Precision tab\n2. Проверь Auto Prediction\n3. Настрой Head Offset если чуть выше/ниже\n\nCyan линия = предсказанная позиция\nКрасная точка = реальная голова\nЗеленая точка = куда попадёшь\n\nЕсли промахиваешь высоко → Head Offset -0.1\nЕсли промахиваешь низко → Head Offset +0.1"
hlp.BorderSizePixel=0; hlp.Parent=infoT; Instance.new("UICorner",hlp).CornerRadius=UDim.new(0,8)

Sep(infoT,"Status")
local sf=Instance.new("Frame"); sf.Size=UDim2.new(1,0,0,70); sf.BackgroundColor3=Th.card; sf.BorderSizePixel=0; sf.Parent=infoT
Instance.new("UICorner",sf).CornerRadius=UDim.new(0,10)
local hl=Instance.new("TextLabel"); hl.Size=UDim2.new(0.5,0,0,22); hl.Position=UDim2.new(0,14,0,8)
hl.BackgroundTransparency=1; hl.Font=Enum.Font.GothamBold; hl.TextSize=12
hl.TextXAlignment=Enum.TextXAlignment.Left; hl.Text=HookOK and "Hook: Active" or "Hook: Failed"
hl.TextColor3=HookOK and Th.green or Th.accent; hl.Parent=sf
local pl=Instance.new("TextLabel"); pl.Size=UDim2.new(0.5,-14,0,22); pl.Position=UDim2.new(0.5,0,0,8)
pl.BackgroundTransparency=1; pl.Font=Enum.Font.Gotham; pl.TextSize=11
pl.TextColor3=Th.dim; pl.TextXAlignment=Enum.TextXAlignment.Right; pl.Parent=sf
local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-28,0,20); tl.Position=UDim2.new(0,14,0,32)
tl.BackgroundTransparency=1; tl.Font=Enum.Font.Gotham; tl.TextSize=10
tl.TextColor3=Th.dim; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=sf
spawn(function() while Alive do
    pl.Text="Ping: "..math.floor(GetPing()).."ms"
    local vel = Target and GetSmoothedVel(Target).Magnitude or 0
    tl.Text="Target: "..(Target and Target.Name or "none").." | Vel: "..string.format("%.1f",vel)
    task.wait(0.5) end end)

Sep(infoT,"Controls")
local ct=Instance.new("TextLabel"); ct.Size=UDim2.new(1,0,0,60); ct.BackgroundColor3=Th.card
ct.TextColor3=Th.dim; ct.Font=Enum.Font.Gotham; ct.TextSize=11; ct.TextWrapped=true
ct.Text="INSERT = Hide/Show menu\nDELETE = Unload script\nHold aim key = activate aim"
ct.BorderSizePixel=0; ct.Parent=infoT
Instance.new("UICorner",ct).CornerRadius=UDim.new(0,8)

UIS.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.Insert or inp.KeyCode==Enum.KeyCode.RightShift then G.Enabled=not G.Enabled end
end)

spawn(function()
    while Alive do
        if UIS:IsKeyDown(Enum.KeyCode.Delete) then
            Alive=false; ClearAll()
            pcall(function() rc:Disconnect() end)
            for p in pairs(ESP) do KillESP(p) end
            for _,o in pairs({fov,dot,line,info,pingTxt,watermark,predLine,headDot}) do if o then pcall(function() o:Remove() end) end end
            if G then pcall(function() G:Destroy() end) end
            Notify("Head Aim","Unloaded",2); break
        end
        task.wait(0.5)
    end
end)

Notify("Head Aim v11","PRO precision loaded",3)
print("=== HEAD AIM PRO v11 ===")
print("Hook: "..(HookOK and "OK" or "FAIL"))
print("HEAD ONLY - Max Precision")
print("========================")