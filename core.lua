-- ===============================================
--   Da Hood Premium v9 - ULTIMATE
--   PRO Aimbot + ALL Effects + Bullet FX
--   github.com/moccommm/main
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
    return ping + 0.05
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
    Enabled = true, AimKey = "MB2", FOV = 200,
    Pred = CalcPred(), Part = "Head",
    TeamCheck = false, NoDowned = true, NoCuffed = true, AutoPred = true,
    SmartPrediction = true, VelocityComp = 1.0,
    PredictJump = true, PredictFall = true,
    HitboxExpander = false, HitboxSize = 5,
    TargetPriority = "Distance", IgnoreWalls = true,

    ShowFOV = true, ShowDot = true, ShowLine = true,
    ShowESP = true, ShowNames = true, ShowHP = true,
    ShowDist = true, ShowBoxes = true, RainbowFOV = false,
    ShowPredPath = true,

    Wings = false, WingStyle = "Angel",
    Aura = false, AuraRainbow = false,
    Trail = false, TrailRainbow = false,
    Particles = false, ParticleType = "Sparkle",
    FloatingRings = false, Halo = false,
    BodyGlow = false, Sword = false,
    Crown = false, Cape = false, Orbs = false,

    -- Bullet Effects
    BulletTrail = false, BulletTrailColor = Color3.fromRGB(255, 55, 85),
    BulletTrailRainbow = false,
    BulletImpact = false, ImpactType = "Explosion",
    BulletGlow = false,
    KillEffect = false, KillEffectType = "Dissolve",
    MuzzleFlash = false, MuzzleColor = Color3.fromRGB(255, 200, 50),
    TracerBullets = false,
    HitMarker = false,
    HitSound = false,
}

local Alive = true
local Target = nil
local Aiming = false
local RainbowHue = 0
local ActiveEffects = {}
local VelHistory = {}
local CurrentTab = "Aim"

-- ==================== VELOCITY TRACKING ====================
local function UpdateVel(plr, vel)
    if not VelHistory[plr] then VelHistory[plr] = {} end
    table.insert(VelHistory[plr], {vel=vel, time=tick()})
    if #VelHistory[plr] > 10 then table.remove(VelHistory[plr], 1) end
end

local function GetSmoothedVel(plr)
    if not VelHistory[plr] or #VelHistory[plr] < 2 then return Vector3.zero end
    local sum = Vector3.zero
    for _, e in ipairs(VelHistory[plr]) do sum = sum + e.vel end
    return sum / #VelHistory[plr]
end

local function GetAccel(plr)
    if not VelHistory[plr] or #VelHistory[plr] < 2 then return Vector3.zero end
    local last = VelHistory[plr][#VelHistory[plr]]
    local prev = VelHistory[plr][#VelHistory[plr]-1]
    local dt = last.time - prev.time
    if dt <= 0 then return Vector3.zero end
    return (last.vel - prev.vel) / dt
end

-- ==================== CHECKS ====================
local function IsValid(plr)
    if not plr or plr == LP then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not ch:FindFirstChild(CFG.Part) then return false end

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

local function IsVisible(pos)
    if not CFG.IgnoreWalls then return true end
    local ch = LP.Character
    if not ch then return false end
    local head = ch:FindFirstChild("Head")
    if not head then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances = {ch}
    local result = workspace:Raycast(head.Position, (pos - head.Position), rp)
    if not result then return true end
    local hit = result.Instance
    if hit and hit.Parent then
        local p = Players:GetPlayerFromCharacter(hit.Parent)
        if p and p ~= LP then return true end
    end
    return math.abs((result.Position - head.Position).Magnitude - (pos - head.Position).Magnitude) < 3
end

-- ==================== TARGETING ====================
local function GetTarget()
    local cands = {}
    local cx = Cam.ViewportSize.X/2
    local cy = Cam.ViewportSize.Y/2

    for _, p in ipairs(Players:GetPlayers()) do
        if IsValid(p) then
            local part = p.Character:FindFirstChild(CFG.Part)
            if part then
                local sp, vis = Cam:WorldToViewportPoint(part.Position)
                if vis then
                    local sd = ((sp.X-cx)^2+(sp.Y-cy)^2)^0.5
                    if sd < CFG.FOV then
                        if not CFG.IgnoreWalls or IsVisible(part.Position) then
                            local wd = 100
                            pcall(function() local mr = LP.Character:FindFirstChild("HumanoidRootPart"); if mr then wd = (mr.Position-part.Position).Magnitude end end)
                            local hp = 100
                            pcall(function() hp = p.Character:FindFirstChildOfClass("Humanoid").Health end)
                            table.insert(cands, {player=p, sd=sd, wd=wd, hp=hp})
                            local root = p.Character:FindFirstChild("HumanoidRootPart")
                            if root then UpdateVel(p, root.AssemblyLinearVelocity) end
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

local function PredictPos()
    if not Target then return nil end
    local ch = Target.Character
    if not ch then return nil end
    local part = ch:FindFirstChild(CFG.Part)
    if not part then return nil end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return part.Position end

    local vel = root.AssemblyLinearVelocity
    if CFG.SmartPrediction then
        local sv = GetSmoothedVel(Target)
        if sv.Magnitude > 0.5 then vel = vel*0.6 + sv*0.4 end
    end
    vel = vel * CFG.VelocityComp
    local predicted = part.Position + (vel * CFG.Pred)

    if CFG.SmartPrediction then
        local accel = GetAccel(Target)
        if accel.Magnitude > 5 then
            predicted = predicted + (accel * CFG.Pred * CFG.Pred * 0.5)
        end
    end

    if CFG.PredictJump then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Jumping then
                predicted = predicted + Vector3.new(0, 3, 0) * CFG.Pred
            elseif state == Enum.HumanoidStateType.Freefall and CFG.PredictFall then
                predicted = predicted + Vector3.new(0, -(workspace.Gravity or 196.2) * CFG.Pred * CFG.Pred * 0.5, 0)
            end
        end
    end
    return predicted
end

-- ==================== HITBOX ====================
local function ExpandHitbox(plr)
    if not CFG.HitboxExpander then return end
    pcall(function()
        local head = plr.Character:FindFirstChild("Head")
        if head then
            head.Size = Vector3.new(CFG.HitboxSize, CFG.HitboxSize, CFG.HitboxSize)
            head.Transparency = 0.7
            head.Material = Enum.Material.ForceField
        end
    end)
end

local function ResetHitbox(plr)
    pcall(function()
        local head = plr.Character:FindFirstChild("Head")
        if head then head.Size = Vector3.new(2,1,1); head.Transparency = 0; head.Material = Enum.Material.Plastic end
    end)
end

spawn(function()
    while Alive do
        if CFG.HitboxExpander then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and IsValid(p) then ExpandHitbox(p) end
            end
        end
        task.wait(0.5)
    end
end)

-- ==================== BULLET EFFECTS ====================
local function CreateBulletTrail(origin, target)
    if not CFG.BulletTrail then return end

    local dir = (target - origin)
    local dist = dir.Magnitude
    local mid = origin + dir/2

    local trail = Instance.new("Part")
    trail.Size = Vector3.new(0.15, 0.15, dist)
    trail.CFrame = CFrame.new(mid, target)
    trail.Anchored = true
    trail.CanCollide = false
    trail.Material = Enum.Material.Neon

    if CFG.BulletTrailRainbow then
        trail.Color = Color3.fromHSV((tick()*0.3)%1, 1, 1)
    else
        trail.Color = CFG.BulletTrailColor
    end

    trail.Parent = workspace

    -- Glow
    if CFG.BulletGlow then
        local light = Instance.new("PointLight", trail)
        light.Color = trail.Color
        light.Brightness = 3
        light.Range = 8
    end

    -- Particles on trail
    local att = Instance.new("Attachment", trail)
    local emitter = Instance.new("ParticleEmitter", att)
    emitter.Rate = 200
    emitter.Lifetime = NumberRange.new(0.2, 0.5)
    emitter.Speed = NumberRange.new(1, 3)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.LightEmission = 1
    emitter.Texture = "rbxassetid://6823507655"
    emitter.Color = ColorSequence.new(trail.Color)

    -- Fade out
    spawn(function()
        for i = 0, 10 do
            pcall(function()
                trail.Transparency = i / 10
                trail.Size = Vector3.new(0.15 - (i*0.01), 0.15 - (i*0.01), dist)
            end)
            task.wait(0.03)
        end
        pcall(function() trail:Destroy() end)
    end)
end

local function CreateImpactEffect(position, normal)
    if not CFG.BulletImpact then return end

    if CFG.ImpactType == "Explosion" then
        local exp = Instance.new("Part")
        exp.Size = Vector3.new(1, 1, 1)
        exp.Position = position
        exp.Anchored = true
        exp.CanCollide = false
        exp.Shape = Enum.PartType.Ball
        exp.Material = Enum.Material.Neon
        exp.Color = CFG.BulletTrailColor
        exp.Transparency = 0.3
        exp.Parent = workspace

        local light = Instance.new("PointLight", exp)
        light.Color = CFG.BulletTrailColor
        light.Brightness = 5
        light.Range = 15

        -- Expand and fade
        spawn(function()
            for i = 0, 15 do
                pcall(function()
                    local s = 1 + i * 0.5
                    exp.Size = Vector3.new(s, s, s)
                    exp.Transparency = 0.3 + (i / 15) * 0.7
                    light.Brightness = 5 - (i / 15) * 5
                end)
                task.wait(0.02)
            end
            pcall(function() exp:Destroy() end)
        end)

        -- Sparks
        local att = Instance.new("Attachment")
        att.Position = Vector3.zero
        att.Parent = exp

        local sparks = Instance.new("ParticleEmitter", att)
        sparks.Rate = 0
        sparks.Speed = NumberRange.new(10, 25)
        sparks.SpreadAngle = Vector2.new(180, 180)
        sparks.Lifetime = NumberRange.new(0.3, 0.8)
        sparks.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0),
        })
        sparks.LightEmission = 1
        sparks.Texture = "rbxassetid://2273224484"
        sparks.Color = ColorSequence.new(CFG.BulletTrailColor)
        sparks:Emit(20)

    elseif CFG.ImpactType == "Electric" then
        local bolt = Instance.new("Part")
        bolt.Size = Vector3.new(0.5, 0.5, 0.5)
        bolt.Position = position
        bolt.Anchored = true
        bolt.CanCollide = false
        bolt.Shape = Enum.PartType.Ball
        bolt.Material = Enum.Material.Neon
        bolt.Color = Color3.fromRGB(100, 200, 255)
        bolt.Parent = workspace

        local light = Instance.new("PointLight", bolt)
        light.Color = Color3.fromRGB(100, 200, 255)
        light.Brightness = 8
        light.Range = 20

        -- Lightning particles
        local att = Instance.new("Attachment", bolt)
        local e = Instance.new("ParticleEmitter", att)
        e.Rate = 0
        e.Speed = NumberRange.new(15, 30)
        e.SpreadAngle = Vector2.new(180, 180)
        e.Lifetime = NumberRange.new(0.1, 0.3)
        e.Size = NumberSequence.new(1)
        e.LightEmission = 1
        e.Texture = "rbxassetid://6823507655"
        e.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
        e:Emit(30)

        Debris:AddItem(bolt, 0.5)

    elseif CFG.ImpactType == "Fire" then
        local fire = Instance.new("Part")
        fire.Size = Vector3.new(1, 1, 1)
        fire.Position = position
        fire.Anchored = true
        fire.CanCollide = false
        fire.Transparency = 1
        fire.Parent = workspace

        local fireE = Instance.new("Fire", fire)
        fireE.Size = 5
        fireE.Heat = 10
        fireE.Color = Color3.fromRGB(255, 100, 0)

        Debris:AddItem(fire, 1)

    elseif CFG.ImpactType == "Ice" then
        for i = 1, 5 do
            local shard = Instance.new("Part")
            shard.Size = Vector3.new(0.3, math.random(5, 15)/10, 0.3)
            shard.Position = position + Vector3.new(math.random(-10,10)/10, math.random(0,10)/10, math.random(-10,10)/10)
            shard.Anchored = true
            shard.CanCollide = false
            shard.Material = Enum.Material.Ice
            shard.Color = Color3.fromRGB(150, 200, 255)
            shard.Transparency = 0.3
            shard.Parent = workspace
            Debris:AddItem(shard, 1)
        end
    end
end

local function CreateMuzzleFlash(position)
    if not CFG.MuzzleFlash then return end

    local flash = Instance.new("Part")
    flash.Size = Vector3.new(2, 2, 2)
    flash.Position = position
    flash.Anchored = true
    flash.CanCollide = false
    flash.Shape = Enum.PartType.Ball
    flash.Material = Enum.Material.Neon
    flash.Color = CFG.MuzzleColor
    flash.Transparency = 0.3
    flash.Parent = workspace

    local light = Instance.new("PointLight", flash)
    light.Color = CFG.MuzzleColor
    light.Brightness = 10
    light.Range = 25

    spawn(function()
        for i = 0, 5 do
            pcall(function()
                flash.Size = Vector3.new(2-i*0.3, 2-i*0.3, 2-i*0.3)
                flash.Transparency = 0.3 + i*0.14
            end)
            task.wait(0.02)
        end
        pcall(function() flash:Destroy() end)
    end)
end

local function CreateHitMarker()
    if not CFG.HitMarker then return end

    local size = 20
    local cx = Cam.ViewportSize.X / 2
    local cy = Cam.ViewportSize.Y / 2

    local lines = {}
    for i = 1, 4 do
        local l = Draw("Line", {
            Thickness = 2,
            Color = Color3.fromRGB(255, 50, 50),
            Visible = true,
        })
        lines[i] = l
    end

    -- X shape
    lines[1].From = Vector2.new(cx-size, cy-size)
    lines[1].To = Vector2.new(cx-size/3, cy-size/3)
    lines[2].From = Vector2.new(cx+size, cy-size)
    lines[2].To = Vector2.new(cx+size/3, cy-size/3)
    lines[3].From = Vector2.new(cx-size, cy+size)
    lines[3].To = Vector2.new(cx-size/3, cy+size/3)
    lines[4].From = Vector2.new(cx+size, cy+size)
    lines[4].To = Vector2.new(cx+size/3, cy+size/3)

    spawn(function()
        task.wait(0.3)
        for _, l in ipairs(lines) do
            pcall(function() l:Remove() end)
        end
    end)
end

local function PlayHitSound()
    if not CFG.HitSound then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://160432334"
        sound.Volume = 0.5
        sound.Parent = workspace
        sound:Play()
        Debris:AddItem(sound, 1)
    end)
end

local function CreateKillEffect(character)
    if not CFG.KillEffect then return end
    if not character then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pos = root.Position

    if CFG.KillEffectType == "Dissolve" then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                spawn(function()
                    for i = 0, 20 do
                        pcall(function()
                            part.Transparency = i / 20
                            part.Size = part.Size * 0.98
                            part.Color = Color3.fromHSV((tick()*0.5+i*0.05)%1, 1, 1)
                            part.Material = Enum.Material.Neon
                        end)
                        task.wait(0.03)
                    end
                end)
            end
        end

    elseif CFG.KillEffectType == "Explode" then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                pcall(function()
                    part.Anchored = false
                    part:BreakJoints()
                    local dir = (part.Position - pos).Unit + Vector3.new(0, 2, 0)
                    part.AssemblyLinearVelocity = dir * math.random(30, 80)
                    part.Material = Enum.Material.Neon
                    part.Color = CFG.BulletTrailColor
                end)
            end
        end

        -- Explosion particles
        local exp = Instance.new("Part")
        exp.Size = Vector3.new(1,1,1)
        exp.Position = pos
        exp.Anchored = true
        exp.CanCollide = false
        exp.Transparency = 1
        exp.Parent = workspace

        local att = Instance.new("Attachment", exp)
        local e = Instance.new("ParticleEmitter", att)
        e.Rate = 0
        e.Speed = NumberRange.new(20, 50)
        e.SpreadAngle = Vector2.new(180, 180)
        e.Lifetime = NumberRange.new(0.5, 1.5)
        e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0)})
        e.LightEmission = 1
        e.Texture = "rbxassetid://6823507655"
        e.Color = ColorSequence.new(CFG.BulletTrailColor)
        e:Emit(50)

        Debris:AddItem(exp, 2)

    elseif CFG.KillEffectType == "Lightning" then
        for i = 1, 8 do
            local bolt = Instance.new("Part")
            bolt.Size = Vector3.new(0.2, math.random(5, 15), 0.2)
            bolt.Position = pos + Vector3.new(math.random(-5,5), math.random(5,20), math.random(-5,5))
            bolt.Anchored = true
            bolt.CanCollide = false
            bolt.Material = Enum.Material.Neon
            bolt.Color = Color3.fromRGB(100, 200, 255)
            bolt.Parent = workspace

            local light = Instance.new("PointLight", bolt)
            light.Brightness = 5
            light.Range = 15
            light.Color = Color3.fromRGB(100, 200, 255)

            Debris:AddItem(bolt, 0.5)
        end

    elseif CFG.KillEffectType == "Freeze" then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.Material = Enum.Material.Ice
                    part.Color = Color3.fromRGB(150, 200, 255)
                    part.Anchored = true
                end)
            end
        end

        -- Ice explosion after delay
        spawn(function()
            task.wait(1)
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part:BreakJoints()
                        part.Anchored = false
                        local dir = (part.Position - pos).Unit
                        part.AssemblyLinearVelocity = dir * 50
                    end)
                end
            end
        end)
    end
end

-- Monitor kills
local function WatchForKills()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Died:Connect(function()
                    if CFG.KillEffect then
                        CreateKillEffect(plr.Character)
                    end
                end)
            end
        end
    end
end

WatchForKills()
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(ch)
        task.wait(1)
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Died:Connect(function()
                if CFG.KillEffect then CreateKillEffect(ch) end
            end)
        end
    end)
end)

-- Detect shooting for bullet effects
local lastShootTime = 0

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end

    -- Shooting detection (LMB)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - lastShootTime > 0.1 then
            lastShootTime = tick()

            if CFG.BulletTrail or CFG.BulletImpact or CFG.MuzzleFlash then
                local ch = LP.Character
                if ch then
                    local tool = ch:FindFirstChildOfClass("Tool")
                    if tool then
                        local handle = tool:FindFirstChild("Handle")
                        local origin = handle and handle.Position or (ch.Head and ch.Head.Position) or Vector3.zero
                        local target = Mouse.Hit.Position

                        if CFG.MuzzleFlash then CreateMuzzleFlash(origin) end
                        if CFG.BulletTrail then CreateBulletTrail(origin, target) end
                        if CFG.BulletImpact then CreateImpactEffect(target, Vector3.new(0,1,0)) end
                        if CFG.HitMarker and Target then CreateHitMarker() end
                        if CFG.HitSound and Target then PlayHitSound() end
                    end
                end
            end
        end
    end

    -- Aim keys
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

spawn(function() while Alive do if CFG.AutoPred then CFG.Pred = CalcPred() end; task.wait(1) end end)

-- ==================== HOOKS ====================
local HookOK = false
if hookmetamethod then
    pcall(function()
        local old
        old = hookmetamethod(game, "__index", newcclosure(function(self, k)
            if not Alive or not CFG.Enabled or not Aiming then return old(self, k) end
            local ok2, isMouse = pcall(function() return self == Mouse end)
            if not ok2 or not isMouse then return old(self, k) end
            local pos = PredictPos(); if not pos then return old(self, k) end
            if k == "Hit" then return CFrame.new(pos) end
            if k == "Target" then if Target and Target.Character then local p = Target.Character:FindFirstChild(CFG.Part); if p then return p end end end
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
            local pos = PredictPos(); if not pos then return old2(self, ...) end
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

-- ==================== CHARACTER EFFECTS ====================
local function ClearEffect(name)
    if ActiveEffects[name] then pcall(function() ActiveEffects[name]:Destroy() end); ActiveEffects[name] = nil end
end
local function ClearAllEffects() for n in pairs(ActiveEffects) do ClearEffect(n) end end
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
    local folder = Instance.new("Model"); folder.Name = "Wings"; folder.Parent = torso
    ActiveEffects["Wings"] = folder
    local styles = {
        Angel={c=Color3.fromRGB(255,255,255),g=Color3.fromRGB(255,215,0),n=8},
        Demon={c=Color3.fromRGB(30,0,0),g=Color3.fromRGB(255,0,0),n=6},
        Dragon={c=Color3.fromRGB(0,100,50),g=Color3.fromRGB(0,255,100),n=5},
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
    local halo = NeonPart(head, Vector3.new(3,0.15,3), CFG.HaloColor, 0.1)
    halo.Shape = Enum.PartType.Cylinder; ActiveEffects["Halo"] = halo
    local w = Instance.new("Weld"); w.Part0=head; w.Part1=halo
    w.C0=CFrame.new(0,1.5,0)*CFrame.Angles(0,0,math.rad(90)); w.Parent=halo
    Instance.new("PointLight",halo).Color = CFG.HaloColor
    spawn(function() local t=0; while Alive and ActiveEffects["Halo"] and CFG.Halo do
        t=t+0.05; pcall(function()
            w.C0=CFrame.new(0,1.5+math.sin(t)*0.1,0)*CFrame.Angles(0,math.rad(t*20),math.rad(90))
            if CFG.AuraRainbow then local c=Color3.fromHSV((tick()*0.15)%1,1,1); halo.Color=c end
        end); task.wait(0.03) end end)
end

local function CreateGlow()
    ClearEffect("BodyGlow"); local ch = GetChar(); if not ch then return end
    local folder = Instance.new("Folder"); folder.Parent=ch; ActiveEffects["BodyGlow"]=folder
    local hl = Instance.new("Highlight"); hl.FillColor=CFG.GlowColor; hl.FillTransparency=0.5
    hl.OutlineColor=CFG.GlowColor; hl.Adornee=ch; hl.Parent=folder
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
    trail.Color=ColorSequence.new(CFG.BulletTrailColor)
    trail.Texture="rbxassetid://6823507655"
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
        local r = NeonPart(folder, Vector3.new(8-i,0.3,8-i), CFG.RingColor, 0.2)
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

LP.CharacterAdded:Connect(function() task.wait(2); ClearAllEffects(); UpdateEffects() end)
spawn(function() while Alive do UpdateEffects(); task.wait(1) end end)

-- ==================== DRAWINGS ====================
local fov = Draw("Circle", {Thickness=2,NumSides=100,Filled=false,Transparency=0.8,Visible=false})
local dot = Draw("Circle", {Thickness=2,NumSides=20,Filled=true,Radius=6,Transparency=1,Visible=false})
local line = Draw("Line", {Thickness=1.5,Transparency=0.8,Visible=false})
local info = Draw("Text", {Size=16,Font=2,Outline=true,Position=Vector2.new(10,10),Visible=false})
local pingTxt = Draw("Text", {Size=12,Font=2,Outline=true,Position=Vector2.new(10,32),Color=Color3.fromRGB(180,180,200),Visible=false})
local watermark = Draw("Text", {Size=18,Font=2,Outline=true,Color=Color3.fromRGB(255,55,85),Visible=true})
local predLine = Draw("Line", {Thickness=2,Color=Color3.fromRGB(0,255,255),Transparency=0.6,Visible=false})

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
    ESP[plr]=nil; VelHistory[plr]=nil
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
        watermark.Position=Vector2.new(Cam.ViewportSize.X-250,10)
        watermark.Text="DA HOOD ULTIMATE v9"
        watermark.Color=CFG.RainbowFOV and rainbow or Color3.fromRGB(255,55,85)
        watermark.Visible=true
    end

    if fov then
        fov.Visible=CFG.ShowFOV and CFG.Enabled
        fov.Position=Vector2.new(cx,cy); fov.Radius=CFG.FOV
        fov.Color=CFG.RainbowFOV and rainbow or (Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,55,85))
    end

    local pos = PredictPos()
    if pos and CFG.Enabled then
        local sp,vis = Cam:WorldToViewportPoint(pos)
        if vis then
            if dot and CFG.ShowDot then dot.Position=Vector2.new(sp.X,sp.Y); dot.Color=Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50); dot.Visible=true end
            if line and CFG.ShowLine then line.From=Vector2.new(cx,cy); line.To=Vector2.new(sp.X,sp.Y); line.Color=Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(100,100,120); line.Visible=true end
            if CFG.ShowPredPath and Target and Target.Character and predLine then
                local cur = Target.Character:FindFirstChild(CFG.Part)
                if cur then
                    local csp,cv = Cam:WorldToViewportPoint(cur.Position)
                    if cv then predLine.From=Vector2.new(csp.X,csp.Y); predLine.To=Vector2.new(sp.X,sp.Y); predLine.Visible=true
                    else predLine.Visible=false end
                end
            end
        else
            if dot then dot.Visible=false end; if line then line.Visible=false end; if predLine then predLine.Visible=false end
        end
    else
        if dot then dot.Visible=false end; if line then line.Visible=false end; if predLine then predLine.Visible=false end
    end

    if info then
        if CFG.Enabled then info.Text=(Aiming and "LOCKED" or "SCANNING").."  "..(Target and Target.Name or "-"); info.Color=Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50); info.Visible=true
        else info.Visible=false end
    end
    if pingTxt then pingTxt.Text="Ping: "..math.floor(GetPing()).."ms | Pred: "..string.format("%.3fs",CFG.Pred).." | "..CFG.Part; pingTxt.Visible=CFG.Enabled end

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
logo.BackgroundTransparency=1; logo.Text="🔥 DA HOOD ULTIMATE"; logo.TextColor3=Th.accent
logo.Font=Enum.Font.GothamBlack; logo.TextSize=15; logo.TextXAlignment=Enum.TextXAlignment.Left; logo.Parent=topBar

local ver=Instance.new("TextLabel"); ver.Size=UDim2.new(0,50,0,20); ver.Position=UDim2.new(1,-70,0.5,-10)
ver.BackgroundColor3=Th.accent; ver.TextColor3=Color3.new(1,1,1); ver.Font=Enum.Font.GothamBold
ver.TextSize=10; ver.Text="v9.0"; ver.BorderSizePixel=0; ver.Parent=topBar
Instance.new("UICorner",ver).CornerRadius=UDim.new(1,0)

local tabBar=Instance.new("Frame"); tabBar.Size=UDim2.new(1,-20,0,36); tabBar.Position=UDim2.new(0,10,0,54)
tabBar.BackgroundColor3=Th.card; tabBar.BorderSizePixel=0; tabBar.Parent=Main
Instance.new("UICorner",tabBar).CornerRadius=UDim.new(0,8)
Instance.new("UIListLayout",tabBar).FillDirection=Enum.FillDirection.Horizontal

local allTabs={"Aim","Advanced","Bullets","ESP","Effects","Settings"}
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

-- UI Helpers
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

-- ==================== BUILD TABS ====================
-- AIM
local aim=tabFrames["Aim"]
Sep(aim,"Aimbot")
Toggle(aim,"Silent Aim","Enabled","🎯")
Toggle(aim,"Auto Prediction","AutoPred","⚡")
Slider(aim,"FOV","FOV",30,500)
Slider(aim,"Prediction","Pred",0.05,0.5,3)
Sep(aim,"Hit Part")
BtnRow(aim,{{name="HEAD",col=Color3.fromRGB(200,40,60),cb=function() CFG.Part="Head" end},{name="TORSO",col=Color3.fromRGB(40,80,200),cb=function() CFG.Part="UpperTorso" end},{name="ROOT",col=Color3.fromRGB(80,80,100),cb=function() CFG.Part="HumanoidRootPart" end}})
Sep(aim,"Aim Key")
BtnRow(aim,{{name="RMB",col=Th.card,cb=function() CFG.AimKey="MB2" end},{name="LMB",col=Th.card,cb=function() CFG.AimKey="MB1" end},{name="Q",col=Th.card,cb=function() CFG.AimKey="Q" end},{name="E",col=Th.card,cb=function() CFG.AimKey="E" end}})
Sep(aim,"Filters")
Toggle(aim,"Team Check","TeamCheck","👥")
Toggle(aim,"Ignore Downed","NoDowned","💀")
Toggle(aim,"Ignore Cuffed","NoCuffed","🔗")
Toggle(aim,"Ignore Walls","IgnoreWalls","🧱")

-- ADVANCED
local adv=tabFrames["Advanced"]
Sep(adv,"Smart Prediction")
Toggle(adv,"Smart Velocity","SmartPrediction","🧠")
Toggle(adv,"Predict Jump","PredictJump","🦘")
Toggle(adv,"Predict Fall","PredictFall","⬇️")
Slider(adv,"Velocity Comp","VelocityComp",0.5,2,2)
Sep(adv,"Hitbox")
Toggle(adv,"Hitbox Expander","HitboxExpander","📦")
Slider(adv,"Hitbox Size","HitboxSize",1,20,1)
Sep(adv,"Target Priority")
BtnRow(adv,{{name="Distance",col=Color3.fromRGB(40,120,200),cb=function() CFG.TargetPriority="Distance" end},{name="Low HP",col=Color3.fromRGB(200,40,60),cb=function() CFG.TargetPriority="HP" end}})
Sep(adv,"Visuals")
Toggle(adv,"Prediction Path","ShowPredPath","📐")

-- BULLETS (NEW!)
local bul=tabFrames["Bullets"]
Sep(bul,"🔫 Bullet Trail")
Toggle(bul,"Bullet Trail","BulletTrail","💫")
Toggle(bul,"Rainbow Trail","BulletTrailRainbow","🌈")
Toggle(bul,"Bullet Glow","BulletGlow","💡")

Sep(bul,"💥 Impact Effect")
Toggle(bul,"Impact Effect","BulletImpact","💥")
BtnRow(bul,{
    {name="💥Explosion",col=Color3.fromRGB(255,100,0),cb=function() CFG.ImpactType="Explosion" end},
    {name="⚡Electric",col=Color3.fromRGB(100,200,255),cb=function() CFG.ImpactType="Electric" end},
    {name="🔥Fire",col=Color3.fromRGB(255,80,0),cb=function() CFG.ImpactType="Fire" end},
    {name="❄️Ice",col=Color3.fromRGB(150,200,255),cb=function() CFG.ImpactType="Ice" end},
})

Sep(bul,"🔥 Muzzle Flash")
Toggle(bul,"Muzzle Flash","MuzzleFlash","🔥")

Sep(bul,"🎯 Hit Feedback")
Toggle(bul,"Hit Marker","HitMarker","✖️")
Toggle(bul,"Hit Sound","HitSound","🔊")

Sep(bul,"💀 Kill Effect")
Toggle(bul,"Kill Effect","KillEffect","💀")
BtnRow(bul,{
    {name="✨Dissolve",col=Color3.fromRGB(200,100,255),cb=function() CFG.KillEffectType="Dissolve" end},
    {name="💥Explode",col=Color3.fromRGB(255,80,0),cb=function() CFG.KillEffectType="Explode" end},
    {name="⚡Lightning",col=Color3.fromRGB(100,200,255),cb=function() CFG.KillEffectType="Lightning" end},
    {name="❄️Freeze",col=Color3.fromRGB(150,200,255),cb=function() CFG.KillEffectType="Freeze" end},
})

-- ESP
local espTab=tabFrames["ESP"]
Sep(espTab,"ESP")
Toggle(espTab,"ESP","ShowESP","👁")
Toggle(espTab,"Names","ShowNames","📝")
Toggle(espTab,"HP","ShowHP","❤️")
Toggle(espTab,"Distance","ShowDist","📏")
Sep(espTab,"Aim Visuals")
Toggle(espTab,"FOV Circle","ShowFOV","⭕")
Toggle(espTab,"Target Dot","ShowDot","🔴")
Toggle(espTab,"Target Line","ShowLine","📍")
Toggle(espTab,"Rainbow FOV","RainbowFOV","🌈")

-- EFFECTS
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

Sep(fx,"Presets")
BtnRow(fx,{
    {name="👑 GOD",col=Color3.fromRGB(255,100,50),cb=function()
        CFG.Wings=true; CFG.WingStyle="Rainbow"; CFG.Aura=true; CFG.AuraRainbow=true
        CFG.Trail=true; CFG.TrailRainbow=true; CFG.Halo=true; CFG.BodyGlow=true
        CFG.FloatingRings=true; CFG.Orbs=true; CFG.BulletTrail=true; CFG.BulletTrailRainbow=true
        CFG.BulletImpact=true; CFG.KillEffect=true; CFG.MuzzleFlash=true; CFG.HitMarker=true
        UpdateEffects(); Notify("GOD MODE","Everything enabled!",3)
    end},
    {name="❌ OFF",col=Color3.fromRGB(80,80,80),cb=function()
        for _,k in ipairs({"Wings","Aura","Trail","Halo","BodyGlow","FloatingRings","Orbs","AuraRainbow","TrailRainbow","BulletTrail","BulletImpact","KillEffect","MuzzleFlash","HitMarker","HitSound","BulletGlow","BulletTrailRainbow"}) do CFG[k]=false end
        ClearAllEffects(); Notify("Effects","All off",2)
    end},
})

-- SETTINGS
local set=tabFrames["Settings"]
Sep(set,"Status")
local sf=Instance.new("Frame"); sf.Size=UDim2.new(1,0,0,70); sf.BackgroundColor3=Th.card; sf.BorderSizePixel=0; sf.Parent=set
Instance.new("UICorner",sf).CornerRadius=UDim.new(0,10)
local hl=Instance.new("TextLabel"); hl.Size=UDim2.new(0.5,0,0,22); hl.Position=UDim2.new(0,14,0,8)
hl.BackgroundTransparency=1; hl.Font=Enum.Font.GothamBold; hl.TextSize=12
hl.TextXAlignment=Enum.TextXAlignment.Left; hl.Text=HookOK and "Hook: Active" or "Hook: Failed"
hl.TextColor3=HookOK and Th.green or Th.accent; hl.Parent=sf
local pl=Instance.new("TextLabel"); pl.Size=UDim2.new(0.5,-14,0,22); pl.Position=UDim2.new(0.5,0,0,8)
pl.BackgroundTransparency=1; pl.Font=Enum.Font.Gotham; pl.TextSize=11
pl.TextColor3=Th.dim; pl.TextXAlignment=Enum.TextXAlignment.Right; pl.Parent=sf
local prl=Instance.new("TextLabel"); prl.Size=UDim2.new(1,-28,0,20); prl.Position=UDim2.new(0,14,0,34)
prl.BackgroundTransparency=1; prl.Font=Enum.Font.Gotham; prl.TextSize=10
prl.TextColor3=Th.dim; prl.TextXAlignment=Enum.TextXAlignment.Left; prl.Parent=sf

spawn(function() while Alive do
    pl.Text="Ping: "..math.floor(GetPing()).."ms"
    prl.Text="Pred: "..string.format("%.3f",CFG.Pred).." | "..CFG.Part.." | "..CFG.AimKey
    task.wait(1) end end)

Sep(set,"Info")
local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,0,0,60); il.BackgroundColor3=Th.card
il.TextColor3=Th.dim; il.Font=Enum.Font.Gotham; il.TextSize=10; il.TextWrapped=true
il.Text="INSERT = Hide | DELETE = Unload\nHold Aim Key to aim\ngithub.com/moccommm/main"
il.BorderSizePixel=0; il.Parent=set; Instance.new("UICorner",il).CornerRadius=UDim.new(0,8)

-- ==================== HOTKEYS ====================
UIS.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.Insert or inp.KeyCode==Enum.KeyCode.RightShift then G.Enabled=not G.Enabled end
end)

spawn(function()
    while Alive do
        if UIS:IsKeyDown(Enum.KeyCode.Delete) then
            Alive=false; ClearAllEffects()
            for _,p in ipairs(Players:GetPlayers()) do if p~=LP then pcall(function() ResetHitbox(p) end) end end
            pcall(function() rc:Disconnect() end)
            for p in pairs(ESP) do KillESP(p) end
            for _,o in pairs({fov,dot,line,info,pingTxt,watermark,predLine}) do if o then pcall(function() o:Remove() end) end end
            if G then pcall(function() G:Destroy() end) end
            Notify("Da Hood Ultimate","Unloaded",2); break
        end
        task.wait(0.5)
    end
end)

Notify("Da Hood Ultimate v9","Loaded! New: Bullet Effects tab",3)
print("=== DA HOOD ULTIMATE v9 ===")
print("Hook: "..(HookOK and "OK" or "FAIL"))
print("NEW: Bullet Trail + Impact + Kill Effects")
print("INSERT = menu | DELETE = unload")
print("============================")