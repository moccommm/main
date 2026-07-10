-- ===============================================
--   Da Hood Premium v7 - IMBA Effects
--   Real Wings | Sword | Aura | Everything
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
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()

if not Drawing then warn("No Drawing") return end

local function GetPing()
    local p = 100
    pcall(function() p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return p
end

local function AutoPred()
    local ping = GetPing()
    if ping < 60 then return 0.125
    elseif ping < 100 then return 0.145
    elseif ping < 150 then return 0.165
    elseif ping < 200 then return 0.185
    else return 0.210 end
end

local CFG = {
    Enabled = true, AimKey = "MB2", FOV = 180, Pred = AutoPred(),
    Part = "Head", TeamCheck = false, NoDowned = true, NoCuffed = true, AutoPred = true,
    ShowFOV = true, ShowDot = true, ShowLine = true, ShowESP = true,
    ShowNames = true, ShowHP = true, ShowDist = true, ShowBoxes = true, RainbowFOV = false,
    -- Effects
    Wings = false, WingStyle = "Angel",
    Aura = false, AuraColor = Color3.fromRGB(255, 55, 85),
    AuraRainbow = false, Trail = false, TrailRainbow = false,
    Particles = false, ParticleType = "Sparkle",
    FloatingRings = false, RingColor = Color3.fromRGB(120, 80, 255),
    BodyGlow = false, GlowColor = Color3.fromRGB(255, 55, 85),
    Halo = false, HaloColor = Color3.fromRGB(255, 215, 0),
    Sword = false, Crown = false, Cape = false,
    Orbs = false, GodMode = false,
}

local Alive = true
local Target = nil
local Aiming = false
local RainbowHue = 0
local ActiveEffects = {}
local CurrentTab = "Aim"

local function Draw(t, p)
    local s, o = pcall(Drawing.new, t)
    if not s then return nil end
    for k, v in pairs(p or {}) do pcall(function() o[k] = v end) end
    return o
end

local function Tw(obj, props, dur)
    TS:Create(obj, TweenInfo.new(dur or 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local function Notify(title, text, dur)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = dur or 3})
    end)
end

-- ==================== DA HOOD CHECKS ====================
local function IsValid(plr)
    if not plr or plr == LP then return false end
    local ch = plr.Character; if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return false end
    if not ch:FindFirstChild(CFG.Part) then return false end
    if CFG.TeamCheck then
        local ok, same = pcall(function() return plr.Team and LP.Team and plr.Team == LP.Team end)
        if ok and same then return false end
    end
    if CFG.NoDowned then
        local ok, down = pcall(function()
            local be = ch:FindFirstChild("BodyEffects")
            if be then local ko = be:FindFirstChild("K.O"); if ko then return ko.Value == true end end
            return false
        end)
        if ok and down then return false end
    end
    if CFG.NoCuffed then
        local ok, c = pcall(function() return ch:FindFirstChild("Handcuffed") ~= nil end)
        if ok and c then return false end
    end
    return true
end

local function GetTarget()
    local best, bestD = nil, CFG.FOV
    local cx = Cam.ViewportSize.X / 2; local cy = Cam.ViewportSize.Y / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if IsValid(p) then
            local part = p.Character:FindFirstChild(CFG.Part)
            if part then
                local sp, vis = Cam:WorldToViewportPoint(part.Position)
                if vis then
                    local d = ((sp.X-cx)^2 + (sp.Y-cy)^2)^0.5
                    if d < bestD then bestD = d; best = p end
                end
            end
        end
    end
    Target = best
end

local function PredictPos()
    if not Target then return nil end
    local ch = Target.Character; if not ch then return nil end
    local part = ch:FindFirstChild(CFG.Part); if not part then return nil end
    local vel = Vector3.zero
    pcall(function() local r = ch:FindFirstChild("HumanoidRootPart"); if r then vel = r.AssemblyLinearVelocity end end)
    return part.Position + (vel * CFG.Pred)
end

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

UIS.InputBegan:Connect(function(inp, gpe) if gpe then return end
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

spawn(function() while Alive do if CFG.AutoPred then CFG.Pred = AutoPred() end; task.wait(3) end end)

-- ==================== VISUAL EFFECTS ====================
local function ClearEffect(name)
    if ActiveEffects[name] then
        pcall(function() ActiveEffects[name]:Destroy() end)
        ActiveEffects[name] = nil
    end
end

local function ClearAllEffects()
    for name in pairs(ActiveEffects) do ClearEffect(name) end
end

local function GetChar() return LP.Character end
local function GetRoot() local ch = GetChar(); return ch and ch:FindFirstChild("HumanoidRootPart") end
local function GetTorso() local ch = GetChar(); return ch and (ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")) end
local function GetHead() local ch = GetChar(); return ch and ch:FindFirstChild("Head") end
local function GetArm(side) local ch = GetChar(); return ch and (ch:FindFirstChild(side.."Hand") or ch:FindFirstChild(side.." Arm")) end

-- === HELPER: Create neon part ===
local function NeonPart(parent, size, color, transparency)
    local p = Instance.new("Part")
    p.Size = size
    p.Material = Enum.Material.Neon
    p.Color = color
    p.CanCollide = false
    p.Anchored = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Transparency = transparency or 0
    p.Parent = parent
    return p
end

-- === EPIC WINGS (Real 3D wings from parts) ===
local function CreateWings()
    ClearEffect("Wings")
    local torso = GetTorso()
    if not torso then return end

    local folder = Instance.new("Model")
    folder.Name = "PremiumWings"
    folder.Parent = torso
    ActiveEffects["Wings"] = folder

    local styles = {
        Angel = {color = Color3.fromRGB(255, 255, 255), glowColor = Color3.fromRGB(255, 215, 0), feathers = 8},
        Demon = {color = Color3.fromRGB(30, 0, 0), glowColor = Color3.fromRGB(255, 0, 0), feathers = 6},
        Dragon = {color = Color3.fromRGB(0, 100, 50), glowColor = Color3.fromRGB(0, 255, 100), feathers = 5},
        Butterfly = {color = Color3.fromRGB(150, 50, 255), glowColor = Color3.fromRGB(255, 100, 255), feathers = 4},
        Fire = {color = Color3.fromRGB(255, 100, 0), glowColor = Color3.fromRGB(255, 200, 0), feathers = 7},
        Ice = {color = Color3.fromRGB(150, 200, 255), glowColor = Color3.fromRGB(200, 230, 255), feathers = 7},
        Rainbow = {color = Color3.fromRGB(255, 255, 255), glowColor = Color3.fromRGB(255, 255, 255), feathers = 8, rainbow = true},
    }

    local style = styles[CFG.WingStyle] or styles.Angel

    -- Create feathers for each wing
    local function CreateWing(side, angleOffset)
        local wingParts = {}
        for i = 1, style.feathers do
            local length = 4.5 - (i - 1) * 0.3
            local width = 0.15
            local feather = NeonPart(folder, Vector3.new(length, width, 0.15), style.color, 0.1)

            local weld = Instance.new("Weld")
            weld.Part0 = torso
            weld.Part1 = feather

            -- Position feathers in fan shape
            local baseAngle = math.rad(20 + (i - 1) * 8)
            local xOff = side * (0.3 + (i - 1) * 0.15)
            local yOff = 0.3 + (i - 1) * 0.15
            local zOff = 0.5

            weld.C0 = CFrame.new(xOff, yOff, zOff) * CFrame.Angles(0, math.rad(side * -70), math.rad(side * (baseAngle * 30 + angleOffset)))
            weld.Parent = feather

            -- Add glow effect
            local light = Instance.new("PointLight")
            light.Color = style.glowColor
            light.Brightness = 1
            light.Range = 4
            light.Parent = feather

            table.insert(wingParts, {part = feather, weld = weld, baseC0 = weld.C0, index = i})
        end
        return wingParts
    end

    local leftWing = CreateWing(-1, 0)
    local rightWing = CreateWing(1, 0)

    -- Animation
    spawn(function()
        local t = 0
        while Alive and ActiveEffects["Wings"] and CFG.Wings do
            t = t + 0.08
            local flap = math.sin(t) * 0.3

            for _, f in ipairs(leftWing) do
                pcall(function()
                    local extra = math.sin(t + f.index * 0.3) * 0.15
                    f.weld.C0 = f.baseC0 * CFrame.Angles(0, 0, flap + extra)

                    if style.rainbow or CFG.AuraRainbow then
                        local h = ((tick() * 0.2) + (f.index * 0.1)) % 1
                        f.part.Color = Color3.fromHSV(h, 1, 1)
                    end
                end)
            end
            for _, f in ipairs(rightWing) do
                pcall(function()
                    local extra = math.sin(t + f.index * 0.3) * 0.15
                    f.weld.C0 = f.baseC0 * CFrame.Angles(0, 0, -flap - extra)

                    if style.rainbow or CFG.AuraRainbow then
                        local h = ((tick() * 0.2) + (f.index * 0.1) + 0.5) % 1
                        f.part.Color = Color3.fromHSV(h, 1, 1)
                    end
                end)
            end
            task.wait(0.03)
        end
    end)

    -- Particles between wings
    if style.rainbow then
        local particleFolder = Instance.new("Attachment", torso)
        particleFolder.Position = Vector3.new(0, 1, 0.5)
        local emitter = Instance.new("ParticleEmitter", particleFolder)
        emitter.Rate = 30
        emitter.Lifetime = NumberRange.new(0.5, 1)
        emitter.Speed = NumberRange.new(1, 3)
        emitter.SpreadAngle = Vector2.new(30, 30)
        emitter.Texture = "rbxassetid://6823507655"
        emitter.LightEmission = 1
        emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
        emitter.Color = ColorSequence.new(style.glowColor)
        emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
        particleFolder.Parent = folder
    end
end

-- === EPIC AURA ===
local function CreateAura()
    ClearEffect("Aura")
    local root = GetRoot()
    if not root then return end

    local folder = Instance.new("Folder")
    folder.Name = "PremiumAura"
    folder.Parent = root
    ActiveEffects["Aura"] = folder

    -- Ground effect (light circle under player)
    local ground = NeonPart(folder, Vector3.new(6, 0.1, 6), CFG.AuraColor, 0.5)
    ground.Shape = Enum.PartType.Cylinder
    local groundWeld = Instance.new("Weld")
    groundWeld.Part0 = root
    groundWeld.Part1 = ground
    groundWeld.C0 = CFrame.new(0, -3, 0) * CFrame.Angles(0, 0, math.rad(90))
    groundWeld.Parent = ground

    -- Inner aura particles
    local att = Instance.new("Attachment", root)
    att.Position = Vector3.new(0, 0, 0)
    att.Parent = folder

    local inner = Instance.new("ParticleEmitter")
    inner.Rate = 100
    inner.Lifetime = NumberRange.new(0.5, 1.2)
    inner.Speed = NumberRange.new(2, 5)
    inner.SpreadAngle = Vector2.new(180, 180)
    inner.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1)
    })
    inner.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
    inner.Texture = "rbxassetid://6823507655"
    inner.LightEmission = 1
    inner.LightInfluence = 0
    inner.Color = ColorSequence.new(CFG.AuraColor)
    inner.Parent = att

    -- Outer glow
    local outer = Instance.new("ParticleEmitter")
    outer.Rate = 50
    outer.Lifetime = NumberRange.new(1, 2)
    outer.Speed = NumberRange.new(0.5, 2)
    outer.SpreadAngle = Vector2.new(180, 180)
    outer.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)})
    outer.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 1)})
    outer.Texture = "rbxassetid://6823507655"
    outer.LightEmission = 0.8
    outer.LightInfluence = 0
    outer.Color = ColorSequence.new(CFG.AuraColor)
    outer.Parent = att

    -- Rising sparks
    local sparks = Instance.new("ParticleEmitter")
    sparks.Rate = 25
    sparks.Lifetime = NumberRange.new(1.5, 2.5)
    sparks.Speed = NumberRange.new(4, 8)
    sparks.SpreadAngle = Vector2.new(30, 30)
    sparks.Acceleration = Vector3.new(0, 5, 0)
    sparks.Texture = "rbxassetid://2273224484"
    sparks.LightEmission = 1
    sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
    sparks.Color = ColorSequence.new(CFG.AuraColor)
    sparks.Rotation = NumberRange.new(0, 360)
    sparks.RotSpeed = NumberRange.new(100, 300)
    sparks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
    sparks.Parent = att

    -- Point lights
    local light = Instance.new("PointLight")
    light.Brightness = 4
    light.Range = 20
    light.Color = CFG.AuraColor
    light.Parent = root

    light.Parent = folder

    spawn(function()
        while Alive and ActiveEffects["Aura"] and CFG.Aura do
            if CFG.AuraRainbow then
                local col = Color3.fromHSV((tick() * 0.15) % 1, 1, 1)
                pcall(function()
                    inner.Color = ColorSequence.new(col)
                    outer.Color = ColorSequence.new(col)
                    sparks.Color = ColorSequence.new(col)
                    light.Color = col
                    ground.Color = col
                end)
            end
            -- Pulse ground
            local pulse = math.sin(tick() * 3) * 0.5 + 0.5
            pcall(function() ground.Size = Vector3.new(6 + pulse * 2, 0.1, 6 + pulse * 2) end)
            task.wait(0.05)
        end
    end)
end

-- === EPIC TRAIL ===
local function CreateTrail()
    ClearEffect("Trail")
    local root = GetRoot()
    if not root then return end

    local folder = Instance.new("Folder")
    folder.Name = "PremiumTrail"
    folder.Parent = root
    ActiveEffects["Trail"] = folder

    local att0 = Instance.new("Attachment"); att0.Position = Vector3.new(0, 2.5, 0); att0.Parent = root
    local att1 = Instance.new("Attachment"); att1.Position = Vector3.new(0, -3, 0); att1.Parent = root

    local trail = Instance.new("Trail")
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Lifetime = 1.2
    trail.MinLength = 0.1
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.FaceCamera = true
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1)
    })
    trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, CFG.AuraColor),
        ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
    })
    trail.Texture = "rbxassetid://6823507655"

    att0.Parent = folder; att1.Parent = folder; trail.Parent = folder

    spawn(function()
        while Alive and ActiveEffects["Trail"] and CFG.Trail do
            if CFG.TrailRainbow then
                local h1 = (tick() * 0.3) % 1; local h2 = (h1 + 0.3) % 1
                pcall(function()
                    trail.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(h1, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(h2, 1, 1)),
                    })
                end)
            end
            task.wait(0.05)
        end
    end)
end

-- === PARTICLES ===
local function CreateParticles()
    ClearEffect("Particles")
    local root = GetRoot(); if not root then return end
    local folder = Instance.new("Folder"); folder.Name = "PremiumParticles"; folder.Parent = root
    ActiveEffects["Particles"] = folder

    local att = Instance.new("Attachment"); att.Parent = folder

    if CFG.ParticleType == "Sparkle" then
        local sparkle = Instance.new("Sparkles", folder); sparkle.SparkleColor = CFG.AuraColor
    elseif CFG.ParticleType == "Fire" then
        local fire = Instance.new("Fire", folder); fire.Size = 8; fire.Heat = 15
        fire.Color = Color3.fromRGB(255, 100, 0); fire.SecondaryColor = Color3.fromRGB(255, 200, 0)
    elseif CFG.ParticleType == "Smoke" then
        local s = Instance.new("Smoke", folder); s.Size = 4; s.Opacity = 0.4; s.Color = Color3.fromRGB(100, 0, 200)
    elseif CFG.ParticleType == "Hearts" then
        local e = Instance.new("ParticleEmitter", att); e.Rate = 20; e.Lifetime = NumberRange.new(1, 2)
        e.Speed = NumberRange.new(3, 7); e.SpreadAngle = Vector2.new(60, 60); e.Texture = "rbxassetid://7648093838"
        e.Size = NumberSequence.new(0.8); e.LightEmission = 1
        e.Color = ColorSequence.new(Color3.fromRGB(255, 50, 100))
        e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
    elseif CFG.ParticleType == "Stars" then
        local e = Instance.new("ParticleEmitter", att); e.Rate = 30; e.Lifetime = NumberRange.new(1, 2)
        e.Speed = NumberRange.new(2, 6); e.SpreadAngle = Vector2.new(180, 180); e.Texture = "rbxassetid://2273224484"
        e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
        e.LightEmission = 1; e.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
        e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(100, 300)
    elseif CFG.ParticleType == "Lightning" then
        local e = Instance.new("ParticleEmitter", att); e.Rate = 15; e.Lifetime = NumberRange.new(0.3, 0.6)
        e.Speed = NumberRange.new(8, 15); e.SpreadAngle = Vector2.new(180, 180)
        e.Texture = "rbxassetid://2273224484"; e.Size = NumberSequence.new(1.5)
        e.LightEmission = 1; e.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
    end
end

-- === EPIC FLOATING RINGS ===
local function CreateRings()
    ClearEffect("Rings")
    local root = GetRoot(); if not root then return end
    local folder = Instance.new("Folder"); folder.Name = "PremiumRings"; folder.Parent = workspace
    ActiveEffects["Rings"] = folder

    local rings = {}
    for i = 1, 4 do
        local ring = NeonPart(folder, Vector3.new(8 - i, 0.3, 8 - i), CFG.RingColor, 0.2)
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true

        local light = Instance.new("PointLight")
        light.Color = CFG.RingColor
        light.Brightness = 2
        light.Range = 6
        light.Parent = ring

        rings[i] = ring
    end

    spawn(function()
        local t = 0
        while Alive and ActiveEffects["Rings"] and CFG.FloatingRings do
            t = t + 0.02
            local r = GetRoot()
            if r then
                for i, ring in ipairs(rings) do
                    local offset = (i - 1) * (math.pi / 2)
                    local yOff = math.sin(t * 2 + offset) * 2 + (i - 2)
                    local angle = t * 80 + (i * 60)

                    pcall(function()
                        ring.CFrame = CFrame.new(r.Position + Vector3.new(0, yOff, 0))
                            * CFrame.Angles(math.rad(angle * (i % 2 == 0 and 1 or -1)), math.rad(angle * 0.5), math.rad(90))

                        if CFG.AuraRainbow then
                            local col = Color3.fromHSV(((tick() * 0.2) + (i * 0.15)) % 1, 1, 1)
                            ring.Color = col
                            ring:FindFirstChildOfClass("PointLight").Color = col
                        else
                            ring.Color = CFG.RingColor
                        end
                    end)
                end
            end
            task.wait(0.02)
        end
        for _, ring in ipairs(rings) do pcall(function() ring:Destroy() end) end
    end)
end

-- === HALO ===
local function CreateHalo()
    ClearEffect("Halo")
    local head = GetHead(); if not head then return end

    local halo = NeonPart(head, Vector3.new(3, 0.15, 3), CFG.HaloColor, 0.1)
    halo.Shape = Enum.PartType.Cylinder
    ActiveEffects["Halo"] = halo

    local weld = Instance.new("Weld")
    weld.Part0 = head; weld.Part1 = halo
    weld.C0 = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
    weld.Parent = halo

    local light = Instance.new("PointLight")
    light.Color = CFG.HaloColor; light.Brightness = 4; light.Range = 12
    light.Parent = halo

    -- Halo particles
    local att = Instance.new("Attachment", halo)
    local e = Instance.new("ParticleEmitter", att)
    e.Rate = 40; e.Lifetime = NumberRange.new(0.5, 1); e.Speed = NumberRange.new(0.5, 1.5)
    e.SpreadAngle = Vector2.new(360, 360); e.Texture = "rbxassetid://6823507655"
    e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
    e.LightEmission = 1; e.Color = ColorSequence.new(CFG.HaloColor)
    e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})

    spawn(function()
        local t = 0
        while Alive and ActiveEffects["Halo"] and CFG.Halo do
            t = t + 0.05
            pcall(function()
                weld.C0 = CFrame.new(0, 1.5 + math.sin(t) * 0.1, 0) * CFrame.Angles(0, math.rad(t * 20), math.rad(90))

                if CFG.AuraRainbow then
                    local col = Color3.fromHSV((tick() * 0.15) % 1, 1, 1)
                    halo.Color = col; light.Color = col
                    e.Color = ColorSequence.new(col)
                end
            end)
            task.wait(0.03)
        end
    end)
end

-- === BODY GLOW ===
local function CreateBodyGlow()
    ClearEffect("BodyGlow")
    local ch = GetChar(); if not ch then return end

    local folder = Instance.new("Folder"); folder.Name = "PremiumGlow"; folder.Parent = ch
    ActiveEffects["BodyGlow"] = folder

    local hl = Instance.new("Highlight")
    hl.FillColor = CFG.GlowColor
    hl.FillTransparency = 0.5
    hl.OutlineColor = CFG.GlowColor
    hl.OutlineTransparency = 0
    hl.Adornee = ch
    hl.Parent = folder

    spawn(function()
        while Alive and ActiveEffects["BodyGlow"] and CFG.BodyGlow do
            if CFG.AuraRainbow then
                local col = Color3.fromHSV((tick() * 0.15) % 1, 1, 1)
                pcall(function() hl.FillColor = col; hl.OutlineColor = col end)
            end
            local pulse = math.sin(tick() * 3) * 0.2 + 0.5
            pcall(function() hl.FillTransparency = pulse end)
            task.wait(0.05)
        end
    end)
end

-- === EPIC SWORD ===
local function CreateSword()
    ClearEffect("Sword")
    local arm = GetArm("Right"); if not arm then return end

    local folder = Instance.new("Model"); folder.Name = "PremiumSword"; folder.Parent = arm
    ActiveEffects["Sword"] = folder

    -- Blade
    local blade = NeonPart(folder, Vector3.new(0.3, 4, 0.1), Color3.fromRGB(200, 230, 255), 0.1)
    local bladeWeld = Instance.new("Weld")
    bladeWeld.Part0 = arm; bladeWeld.Part1 = blade
    bladeWeld.C0 = CFrame.new(0, -2, 0)
    bladeWeld.Parent = blade

    -- Handle
    local handle = NeonPart(folder, Vector3.new(0.4, 1, 0.4), Color3.fromRGB(80, 40, 20), 0)
    handle.Material = Enum.Material.Wood
    local handleWeld = Instance.new("Weld")
    handleWeld.Part0 = arm; handleWeld.Part1 = handle
    handleWeld.C0 = CFrame.new(0, 0.5, 0)
    handleWeld.Parent = handle

    -- Guard
    local guard = NeonPart(folder, Vector3.new(1, 0.2, 0.3), Color3.fromRGB(255, 215, 0), 0)
    local guardWeld = Instance.new("Weld")
    guardWeld.Part0 = arm; guardWeld.Part1 = guard
    guardWeld.C0 = CFrame.new(0, 0, 0)
    guardWeld.Parent = guard

    -- Light on blade
    local light = Instance.new("PointLight", blade)
    light.Color = Color3.fromRGB(150, 200, 255); light.Brightness = 3; light.Range = 8

    -- Fire particles on blade
    local att = Instance.new("Attachment", blade)
    att.Position = Vector3.new(0, 0, 0)
    local e = Instance.new("ParticleEmitter", att)
    e.Rate = 60; e.Lifetime = NumberRange.new(0.3, 0.8); e.Speed = NumberRange.new(1, 3)
    e.SpreadAngle = Vector2.new(180, 180); e.Texture = "rbxassetid://6823507655"
    e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})
    e.LightEmission = 1; e.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
    e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})

    spawn(function()
        while Alive and ActiveEffects["Sword"] and CFG.Sword do
            if CFG.AuraRainbow then
                local col = Color3.fromHSV((tick() * 0.15) % 1, 1, 1)
                pcall(function()
                    blade.Color = col; light.Color = col
                    e.Color = ColorSequence.new(col)
                end)
            end
            task.wait(0.05)
        end
    end)
end

-- === CROWN ===
local function CreateCrown()
    ClearEffect("Crown")
    local head = GetHead(); if not head then return end

    local folder = Instance.new("Model"); folder.Name = "PremiumCrown"; folder.Parent = head
    ActiveEffects["Crown"] = folder

    -- Base ring
    local base = NeonPart(folder, Vector3.new(2.4, 0.4, 2.4), Color3.fromRGB(255, 215, 0), 0)
    base.Shape = Enum.PartType.Cylinder
    local baseWeld = Instance.new("Weld")
    baseWeld.Part0 = head; baseWeld.Part1 = base
    baseWeld.C0 = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
    baseWeld.Parent = base

    -- Spikes
    for i = 0, 4 do
        local angle = math.rad(i * 72)
        local spike = NeonPart(folder, Vector3.new(0.3, 1.2, 0.3), Color3.fromRGB(255, 215, 0), 0)
        local spikeWeld = Instance.new("Weld")
        spikeWeld.Part0 = head; spikeWeld.Part1 = spike
        spikeWeld.C0 = CFrame.new(math.cos(angle) * 1, 1.4, math.sin(angle) * 1)
        spikeWeld.Parent = spike

        -- Gems on top
        local gem = NeonPart(folder, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 50, 100), 0)
        gem.Shape = Enum.PartType.Ball
        local gemWeld = Instance.new("Weld")
        gemWeld.Part0 = head; gemWeld.Part1 = gem
        gemWeld.C0 = CFrame.new(math.cos(angle) * 1, 2, math.sin(angle) * 1)
        gemWeld.Parent = gem
    end

    local light = Instance.new("PointLight", head)
    light.Color = Color3.fromRGB(255, 215, 0); light.Brightness = 2; light.Range = 8
    light.Parent = folder
end

-- === EPIC CAPE ===
local function CreateCape()
    ClearEffect("Cape")
    local torso = GetTorso(); if not torso then return end

    local folder = Instance.new("Model"); folder.Name = "PremiumCape"; folder.Parent = torso
    ActiveEffects["Cape"] = folder

    -- Cape parts (multiple segments)
    local segments = {}
    for i = 1, 5 do
        local seg = NeonPart(folder, Vector3.new(2.5 - i * 0.2, 1, 0.1), CFG.AuraColor, 0.3)
        seg.Material = Enum.Material.Fabric

        local weld = Instance.new("Weld")
        weld.Part0 = torso; weld.Part1 = seg
        weld.C0 = CFrame.new(0, -(i - 1) * 0.8 + 0.5, 0.7 + (i - 1) * 0.1)
        weld.Parent = seg

        table.insert(segments, {part = seg, weld = weld, baseC0 = weld.C0})
    end

    spawn(function()
        local t = 0
        while Alive and ActiveEffects["Cape"] and CFG.Cape do
            t = t + 0.1
            for i, s in ipairs(segments) do
                pcall(function()
                    local sway = math.sin(t + i * 0.5) * 0.1
                    s.weld.C0 = s.baseC0 * CFrame.Angles(sway, 0, 0)

                    if CFG.AuraRainbow then
                        s.part.Color = Color3.fromHSV(((tick() * 0.15) + i * 0.05) % 1, 1, 1)
                    end
                end)
            end
            task.wait(0.03)
        end
    end)
end

-- === ORBITING ORBS ===
local function CreateOrbs()
    ClearEffect("Orbs")
    local root = GetRoot(); if not root then return end

    local folder = Instance.new("Folder"); folder.Name = "PremiumOrbs"; folder.Parent = workspace
    ActiveEffects["Orbs"] = folder

    local orbs = {}
    for i = 1, 6 do
        local orb = NeonPart(folder, Vector3.new(0.8, 0.8, 0.8), CFG.AuraColor, 0.2)
        orb.Shape = Enum.PartType.Ball
        orb.Anchored = true

        local light = Instance.new("PointLight", orb)
        light.Color = CFG.AuraColor; light.Brightness = 2; light.Range = 5

        -- Trail on orb
        local att0 = Instance.new("Attachment", orb); att0.Position = Vector3.new(0.4, 0, 0)
        local att1 = Instance.new("Attachment", orb); att1.Position = Vector3.new(-0.4, 0, 0)
        local trail = Instance.new("Trail", orb)
        trail.Attachment0 = att0; trail.Attachment1 = att1
        trail.Lifetime = 0.5; trail.LightEmission = 1
        trail.Color = ColorSequence.new(CFG.AuraColor)
        trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

        orbs[i] = orb
    end

    spawn(function()
        local t = 0
        while Alive and ActiveEffects["Orbs"] and CFG.Orbs do
            t = t + 0.03
            local r = GetRoot()
            if r then
                for i, orb in ipairs(orbs) do
                    local angle = t + (i - 1) * (math.pi * 2 / #orbs)
                    local radius = 4
                    local yOff = math.sin(t * 2 + i) * 1.5

                    pcall(function()
                        orb.CFrame = CFrame.new(
                            r.Position.X + math.cos(angle) * radius,
                            r.Position.Y + yOff,
                            r.Position.Z + math.sin(angle) * radius
                        )

                        if CFG.AuraRainbow then
                            local col = Color3.fromHSV((tick() * 0.2 + i * 0.15) % 1, 1, 1)
                            orb.Color = col
                            orb:FindFirstChildOfClass("PointLight").Color = col
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
    if CFG.Trail then if not ActiveEffects["Trail"] then CreateTrail() end else ClearEffect("Trail") end
    if CFG.Particles then if not ActiveEffects["Particles"] then CreateParticles() end else ClearEffect("Particles") end
    if CFG.FloatingRings then if not ActiveEffects["Rings"] then CreateRings() end else ClearEffect("Rings") end
    if CFG.Halo then if not ActiveEffects["Halo"] then CreateHalo() end else ClearEffect("Halo") end
    if CFG.BodyGlow then if not ActiveEffects["BodyGlow"] then CreateBodyGlow() end else ClearEffect("BodyGlow") end
    if CFG.Sword then if not ActiveEffects["Sword"] then CreateSword() end else ClearEffect("Sword") end
    if CFG.Crown then if not ActiveEffects["Crown"] then CreateCrown() end else ClearEffect("Crown") end
    if CFG.Cape then if not ActiveEffects["Cape"] then CreateCape() end else ClearEffect("Cape") end
    if CFG.Orbs then if not ActiveEffects["Orbs"] then CreateOrbs() end else ClearEffect("Orbs") end
end

-- === GOD MODE PRESET ===
local function EnableGodMode()
    CFG.Wings = true; CFG.WingStyle = "Rainbow"
    CFG.Aura = true; CFG.AuraRainbow = true
    CFG.Trail = true; CFG.TrailRainbow = true
    CFG.Particles = true; CFG.ParticleType = "Stars"
    CFG.FloatingRings = true
    CFG.Halo = true; CFG.BodyGlow = true
    CFG.Sword = true; CFG.Crown = true
    CFG.Cape = true; CFG.Orbs = true
    UpdateEffects()
    Notify("GOD MODE", "All effects enabled!", 3)
end

LP.CharacterAdded:Connect(function() task.wait(2); ClearAllEffects(); UpdateEffects() end)
spawn(function() while Alive do UpdateEffects(); task.wait(1) end end)

-- ==================== DRAWINGS ====================
local fov = Draw("Circle", {Thickness=2, NumSides=100, Filled=false, Transparency=0.8, Visible=false})
local dot = Draw("Circle", {Thickness=2, NumSides=20, Filled=true, Radius=6, Transparency=1, Visible=false})
local line = Draw("Line", {Thickness=1.5, Transparency=0.8, Visible=false})
local info = Draw("Text", {Size=16, Font=2, Outline=true, Position=Vector2.new(10,10), Visible=false})
local pingTxt = Draw("Text", {Size=12, Font=2, Outline=true, Position=Vector2.new(10,32), Color=Color3.fromRGB(180,180,200), Visible=false})
local watermark = Draw("Text", {Size=18, Font=2, Outline=true, Color=Color3.fromRGB(255,55,85), Visible=true})

local ESP = {}
local function MakeESP(plr)
    if plr == LP or ESP[plr] then return end
    ESP[plr] = {
        dot = Draw("Circle", {Thickness=1, NumSides=14, Filled=true, Radius=4, Transparency=1, Visible=false}),
        name = Draw("Text", {Size=12, Center=true, Outline=true, Font=2, Visible=false}),
        hp = Draw("Text", {Size=11, Center=true, Outline=true, Font=2, Visible=false}),
        dist = Draw("Text", {Size=10, Center=true, Outline=true, Font=2, Color=Color3.fromRGB(180,180,180), Visible=false}),
    }
end
local function KillESP(plr) local e = ESP[plr]; if not e then return end
    for _, v in pairs(e) do pcall(function() v:Remove() end) end; ESP[plr] = nil end

local rc = RS.RenderStepped:Connect(function()
    if not Alive then return end
    Cam = workspace.CurrentCamera
    local cx = Cam.ViewportSize.X/2; local cy = Cam.ViewportSize.Y/2
    RainbowHue = (RainbowHue + 0.003) % 1
    local rainbow = Color3.fromHSV(RainbowHue, 1, 1)

    if CFG.Enabled then GetTarget() else Target = nil end

    if watermark then
        watermark.Position = Vector2.new(Cam.ViewportSize.X - 220, 10)
        watermark.Text = "DA HOOD PREMIUM v7"
        watermark.Color = CFG.RainbowFOV and rainbow or Color3.fromRGB(255,55,85)
        watermark.Visible = true
    end

    if fov then
        fov.Visible = CFG.ShowFOV and CFG.Enabled
        fov.Position = Vector2.new(cx, cy); fov.Radius = CFG.FOV
        fov.Color = CFG.RainbowFOV and rainbow or (Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,55,85))
    end

    local pos = PredictPos()
    if pos and CFG.Enabled then
        local sp, vis = Cam:WorldToViewportPoint(pos)
        if vis then
            if dot and CFG.ShowDot then dot.Position = Vector2.new(sp.X,sp.Y); dot.Color = Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50); dot.Visible = true end
            if line and CFG.ShowLine then line.From = Vector2.new(cx,cy); line.To = Vector2.new(sp.X,sp.Y); line.Color = Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(100,100,120); line.Visible = true end
        else if dot then dot.Visible = false end; if line then line.Visible = false end end
    else if dot then dot.Visible = false end; if line then line.Visible = false end end

    if info then if CFG.Enabled then info.Text = (Aiming and "LOCKED" or "SCANNING").."  "..(Target and Target.Name or "-"); info.Color = Aiming and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,220,50); info.Visible = true else info.Visible = false end end
    if pingTxt then pingTxt.Text = "Ping: "..math.floor(GetPing()).."ms | Pred: "..string.format("%.3f",CFG.Pred).." | "..CFG.Part; pingTxt.Visible = CFG.Enabled end

    for plr, e in pairs(ESP) do
        if not plr or not plr.Parent then KillESP(plr)
        elseif CFG.ShowESP and IsValid(plr) then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local sp, vis = Cam:WorldToViewportPoint(head.Position)
                if vis then
                    local dist = 100
                    pcall(function() local mr = LP.Character:FindFirstChild("HumanoidRootPart"); if mr then dist = (mr.Position-head.Position).Magnitude end end)
                    if e.dot then e.dot.Position = Vector2.new(sp.X,sp.Y); e.dot.Radius = math.clamp(500/dist,2,8); e.dot.Color = (Target==plr) and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,60,80); e.dot.Visible = true end
                    if e.name and CFG.ShowNames then e.name.Text = plr.Name; e.name.Position = Vector2.new(sp.X,sp.Y-18); e.name.Visible = true elseif e.name then e.name.Visible = false end
                    if e.hp and CFG.ShowHP then local hp = 0; pcall(function() hp = math.floor(plr.Character:FindFirstChildOfClass("Humanoid").Health) end); e.hp.Text = hp.." HP"; e.hp.Position = Vector2.new(sp.X,sp.Y+10); e.hp.Color = Color3.fromRGB(255,255,100); e.hp.Visible = true elseif e.hp then e.hp.Visible = false end
                    if e.dist and CFG.ShowDist then e.dist.Text = math.floor(dist).."m"; e.dist.Position = Vector2.new(sp.X,sp.Y+22); e.dist.Visible = true elseif e.dist then e.dist.Visible = false end
                else for _, v in pairs(e) do v.Visible = false end end
            else for _, v in pairs(e) do v.Visible = false end end
        else for _, v in pairs(e) do v.Visible = false end end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do MakeESP(p) end
Players.PlayerAdded:Connect(function(p) task.wait(1) MakeESP(p) end)
Players.PlayerRemoving:Connect(KillESP)

-- ==================== UI ====================
local G = Instance.new("ScreenGui")
G.Name = "DHP_"..math.random(10000,99999); G.ResetOnSpawn = false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(G) end; G.Parent = CG end)
if not G.Parent then pcall(function() G.Parent = LP.PlayerGui end) end

local Theme = {
    bg = Color3.fromRGB(10,10,16), sidebar = Color3.fromRGB(14,14,22),
    card = Color3.fromRGB(20,20,30), cardHover = Color3.fromRGB(28,28,42),
    accent = Color3.fromRGB(255,55,85), accent2 = Color3.fromRGB(120,80,255),
    green = Color3.fromRGB(0,220,130), text = Color3.fromRGB(235,235,245),
    dim = Color3.fromRGB(100,100,130), on = Color3.fromRGB(0,220,130), off = Color3.fromRGB(50,50,65),
}

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,480,0,540); Main.Position = UDim2.new(0.5,-240,0.5,-270)
Main.BackgroundColor3 = Theme.bg; Main.BorderSizePixel = 0; Main.ClipsDescendants = true
Main.Active = true; Main.Draggable = true; Main.Parent = G
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)

local borderStroke = Instance.new("UIStroke", Main)
borderStroke.Thickness = 1.5; borderStroke.Transparency = 0.4
spawn(function() while Alive do borderStroke.Color = Color3.fromHSV((tick()*0.1)%1,0.7,1); task.wait(0.03) end end)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1,0,0,50); topBar.BackgroundColor3 = Theme.sidebar
topBar.BorderSizePixel = 0; topBar.Parent = Main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0,14)
local topFix = Instance.new("Frame"); topFix.Size = UDim2.new(1,0,0,14); topFix.Position = UDim2.new(0,0,1,-14)
topFix.BackgroundColor3 = Theme.sidebar; topFix.BorderSizePixel = 0; topFix.Parent = topBar

local logoLbl = Instance.new("TextLabel")
logoLbl.Size = UDim2.new(0,250,1,0); logoLbl.Position = UDim2.new(0,16,0,0)
logoLbl.BackgroundTransparency = 1; logoLbl.Text = "🔥 DA HOOD PREMIUM"
logoLbl.TextColor3 = Theme.accent; logoLbl.Font = Enum.Font.GothamBlack; logoLbl.TextSize = 16
logoLbl.TextXAlignment = Enum.TextXAlignment.Left; logoLbl.Parent = topBar

local verLbl = Instance.new("TextLabel")
verLbl.Size = UDim2.new(0,50,0,20); verLbl.Position = UDim2.new(1,-70,0.5,-10)
verLbl.BackgroundColor3 = Theme.accent; verLbl.TextColor3 = Color3.new(1,1,1)
verLbl.Font = Enum.Font.GothamBold; verLbl.TextSize = 10; verLbl.Text = "v7.0"
verLbl.BorderSizePixel = 0; verLbl.Parent = topBar
Instance.new("UICorner", verLbl).CornerRadius = UDim.new(1,0)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,-20,0,36); tabBar.Position = UDim2.new(0,10,0,54)
tabBar.BackgroundColor3 = Theme.card; tabBar.BorderSizePixel = 0; tabBar.Parent = Main
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0,8)
Instance.new("UIListLayout", tabBar).FillDirection = Enum.FillDirection.Horizontal

local allTabs = {"Aim", "ESP", "Effects", "Presets", "Settings"}
local tabFrames = {}; local tabButtons = {}

for _, tabName in ipairs(allTabs) do
    local tb = Instance.new("TextButton"); tb.Size = UDim2.new(1/#allTabs,0,1,0); tb.BackgroundTransparency = 1
    tb.Text = tabName; tb.TextColor3 = (tabName==CurrentTab) and Theme.accent or Theme.dim
    tb.Font = Enum.Font.GothamBold; tb.TextSize = 12; tb.BorderSizePixel = 0; tb.Parent = tabBar
    tabButtons[tabName] = tb
end

local scrollArea = Instance.new("Frame")
scrollArea.Size = UDim2.new(1,-20,1,-100); scrollArea.Position = UDim2.new(0,10,0,94)
scrollArea.BackgroundTransparency = 1; scrollArea.ClipsDescendants = true; scrollArea.Parent = Main

for _, tabName in ipairs(allTabs) do
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,1,0); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = Theme.accent
    scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Visible = (tabName==CurrentTab); scroll.Parent = scrollArea
    tabFrames[tabName] = scroll
    Instance.new("UIListLayout", scroll).Padding = UDim.new(0,6)
    local p = Instance.new("UIPadding", scroll); p.PaddingTop = UDim.new(0,4); p.PaddingBottom = UDim.new(0,4)
end

for tabName, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        CurrentTab = tabName
        for n, f in pairs(tabFrames) do f.Visible = (n==tabName) end
        for n, b in pairs(tabButtons) do Tw(b, {TextColor3 = (n==tabName) and Theme.accent or Theme.dim}, 0.2) end
    end)
end

local function Sep(parent, text)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,22); f.BackgroundTransparency = 1; f.Parent = parent
    local l1 = Instance.new("Frame",f); l1.Size = UDim2.new(0.2,0,0,1); l1.Position = UDim2.new(0,0,0.5,0); l1.BackgroundColor3 = Color3.fromRGB(40,40,55); l1.BorderSizePixel = 0
    local t = Instance.new("TextLabel",f); t.Size = UDim2.new(0.6,0,1,0); t.Position = UDim2.new(0.2,0,0,0); t.BackgroundTransparency = 1; t.Text = string.upper(text); t.TextColor3 = Theme.dim; t.Font = Enum.Font.GothamBold; t.TextSize = 10
    local l2 = Instance.new("Frame",f); l2.Size = UDim2.new(0.2,0,0,1); l2.Position = UDim2.new(0.8,0,0.5,0); l2.BackgroundColor3 = Color3.fromRGB(40,40,55); l2.BorderSizePixel = 0
end

local function Toggle(parent, name, key, icon)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,38); f.BackgroundColor3 = Theme.card; f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
    f.MouseEnter:Connect(function() Tw(f,{BackgroundColor3=Theme.cardHover},0.15) end)
    f.MouseLeave:Connect(function() Tw(f,{BackgroundColor3=Theme.card},0.15) end)

    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0.7,0,1,0); lbl.Position = UDim2.new(0,16,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = (icon or "").."  "..name; lbl.TextColor3 = Theme.text
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = f

    local sw = Instance.new("Frame"); sw.Size = UDim2.new(0,46,0,24); sw.Position = UDim2.new(1,-60,0.5,-12); sw.BorderSizePixel = 0; sw.Parent = f
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,20,0,20); knob.BorderSizePixel = 0; knob.BackgroundColor3 = Color3.new(1,1,1); knob.Parent = sw
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = f
    local function upd()
        if CFG[key] then Tw(sw,{BackgroundColor3=Theme.on},0.2); Tw(knob,{Position=UDim2.new(1,-22,0.5,-10)},0.2)
        else Tw(sw,{BackgroundColor3=Theme.off},0.2); Tw(knob,{Position=UDim2.new(0,2,0.5,-10)},0.2) end
    end
    upd()
    btn.MouseButton1Click:Connect(function() CFG[key] = not CFG[key]; upd(); UpdateEffects() end)
end

local function Slider(parent, name, key, mn, mx, dec)
    dec = dec or 0
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,50); f.BackgroundColor3 = Theme.card; f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,-20,0,22); lbl.Position = UDim2.new(0,16,0,4)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = Theme.text; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = f
    local bar = Instance.new("Frame"); bar.Size = UDim2.new(1,-32,0,8); bar.Position = UDim2.new(0,16,0,32)
    bar.BackgroundColor3 = Theme.off; bar.BorderSizePixel = 0; bar.Parent = f; Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame"); fill.BorderSizePixel = 0; fill.Parent = bar; Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local grad = Instance.new("UIGradient", fill); grad.Color = ColorSequence.new(Theme.accent2, Theme.accent)
    local circle = Instance.new("Frame"); circle.Size = UDim2.new(0,16,0,16); circle.BackgroundColor3 = Color3.new(1,1,1); circle.BorderSizePixel = 0; circle.ZIndex = 5; circle.Parent = bar
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)
    local function upd() local p = math.clamp((CFG[key]-mn)/(mx-mn),0,1); fill.Size = UDim2.new(p,0,1,0); circle.Position = UDim2.new(p,-8,0.5,-8)
        lbl.Text = name.."    "..(dec>0 and string.format("%."..dec.."f",CFG[key]) or tostring(math.floor(CFG[key]))) end
    upd()
    local drag = false
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local p = math.clamp((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1); local v = mn+(mx-mn)*p
        if dec>0 then CFG[key] = math.floor(v*10^dec)/10^dec else CFG[key] = math.floor(v) end; upd() end end)
end

local function BtnRow(parent, items)
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1; row.Parent = parent
    for i, item in ipairs(items) do
        local b = Instance.new("TextButton"); b.Size = UDim2.new(1/#items,-4,1,0); b.Position = UDim2.new((i-1)*(1/#items),2,0,0)
        b.BackgroundColor3 = item.col or Theme.card; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold
        b.TextSize = 11; b.Text = item.name; b.BorderSizePixel = 0; b.Parent = row
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        b.MouseEnter:Connect(function() Tw(b,{BackgroundColor3=Theme.accent},0.15) end)
        b.MouseLeave:Connect(function() Tw(b,{BackgroundColor3=item.col or Theme.card},0.15) end)
        b.MouseButton1Click:Connect(function() item.cb(); UpdateEffects() end)
    end
end

local function BigButton(parent, name, callback, color)
    local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,50); b.BackgroundColor3 = color or Theme.accent
    b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBlack; b.TextSize = 16
    b.Text = name; b.BorderSizePixel = 0; b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,10)
    local grad = Instance.new("UIGradient", b)
    grad.Color = ColorSequence.new(color or Theme.accent, Color3.fromRGB(color and color.R*100 or 180, color and color.G*100 or 30, color and color.B*100 or 80))
    grad.Rotation = 45
    b.MouseButton1Click:Connect(callback)
    return b
end

-- ==================== BUILD TABS ====================
-- AIM
local aim = tabFrames["Aim"]
Sep(aim,"Aimbot")
Toggle(aim,"Silent Aim","Enabled","🎯")
Toggle(aim,"Auto Prediction","AutoPred","⚡")
Slider(aim,"FOV Size","FOV",30,500)
Slider(aim,"Prediction","Pred",0.05,0.3,3)
Sep(aim,"Hit Part")
BtnRow(aim,{
    {name="🎯 HEAD",col=Color3.fromRGB(200,40,60),cb=function() CFG.Part="Head" end},
    {name="🫁 TORSO",col=Color3.fromRGB(40,80,200),cb=function() CFG.Part="UpperTorso" end},
    {name="🦴 ROOT",col=Color3.fromRGB(80,80,100),cb=function() CFG.Part="HumanoidRootPart" end},
})
Sep(aim,"Aim Key")
BtnRow(aim,{
    {name="RMB",col=Theme.card,cb=function() CFG.AimKey="MB2" end},
    {name="LMB",col=Theme.card,cb=function() CFG.AimKey="MB1" end},
    {name="Q",col=Theme.card,cb=function() CFG.AimKey="Q" end},
    {name="E",col=Theme.card,cb=function() CFG.AimKey="E" end},
})
Sep(aim,"Filters")
Toggle(aim,"Team Check","TeamCheck","👥")
Toggle(aim,"Ignore Downed","NoDowned","💀")
Toggle(aim,"Ignore Cuffed","NoCuffed","🔗")

-- ESP
local espTab = tabFrames["ESP"]
Sep(espTab,"ESP Elements")
Toggle(espTab,"ESP Enabled","ShowESP","👁")
Toggle(espTab,"Show Names","ShowNames","📝")
Toggle(espTab,"Show HP","ShowHP","❤️")
Toggle(espTab,"Show Distance","ShowDist","📏")
Sep(espTab,"Aim Visuals")
Toggle(espTab,"FOV Circle","ShowFOV","⭕")
Toggle(espTab,"Target Dot","ShowDot","🔴")
Toggle(espTab,"Target Line","ShowLine","📍")
Toggle(espTab,"Rainbow FOV","RainbowFOV","🌈")

-- EFFECTS
local fx = tabFrames["Effects"]
Sep(fx,"👑 EPIC EFFECTS")
Toggle(fx,"Wings","Wings","🪽")
Sep(fx,"Wing Style")
BtnRow(fx,{
    {name="Angel",col=Color3.fromRGB(255,215,0),cb=function() CFG.WingStyle="Angel"; ClearEffect("Wings") end},
    {name="Demon",col=Color3.fromRGB(150,0,0),cb=function() CFG.WingStyle="Demon"; ClearEffect("Wings") end},
    {name="Dragon",col=Color3.fromRGB(0,150,100),cb=function() CFG.WingStyle="Dragon"; ClearEffect("Wings") end},
})
BtnRow(fx,{
    {name="Butterfly",col=Color3.fromRGB(200,100,255),cb=function() CFG.WingStyle="Butterfly"; ClearEffect("Wings") end},
    {name="Fire",col=Color3.fromRGB(255,100,0),cb=function() CFG.WingStyle="Fire"; ClearEffect("Wings") end},
    {name="Ice",col=Color3.fromRGB(100,200,255),cb=function() CFG.WingStyle="Ice"; ClearEffect("Wings") end},
    {name="🌈Rainbow",col=Color3.fromRGB(255,50,150),cb=function() CFG.WingStyle="Rainbow"; ClearEffect("Wings") end},
})

Sep(fx,"Body Effects")
Toggle(fx,"Aura Particles","Aura","✨")
Toggle(fx,"Body Glow","BodyGlow","💡")
Toggle(fx,"Halo","Halo","😇")
Toggle(fx,"Trail","Trail","🌊")
Toggle(fx,"Cape","Cape","🧥")

Sep(fx,"Extras")
Toggle(fx,"Sword","Sword","⚔️")
Toggle(fx,"Crown","Crown","👑")
Toggle(fx,"Floating Rings","FloatingRings","💫")
Toggle(fx,"Orbiting Orbs","Orbs","🔮")

Sep(fx,"Colors")
Toggle(fx,"🌈 Rainbow Everything","AuraRainbow")
Toggle(fx,"Rainbow Trail","TrailRainbow")

Sep(fx,"Particles")
Toggle(fx,"Particles","Particles","⭐")
BtnRow(fx,{
    {name="✨Sparkle",col=Color3.fromRGB(255,215,0),cb=function() CFG.ParticleType="Sparkle"; ClearEffect("Particles") end},
    {name="🔥Fire",col=Color3.fromRGB(255,80,0),cb=function() CFG.ParticleType="Fire"; ClearEffect("Particles") end},
    {name="⚡Lightning",col=Color3.fromRGB(150,200,255),cb=function() CFG.ParticleType="Lightning"; ClearEffect("Particles") end},
})
BtnRow(fx,{
    {name="💨Smoke",col=Color3.fromRGB(100,0,200),cb=function() CFG.ParticleType="Smoke"; ClearEffect("Particles") end},
    {name="❤️Hearts",col=Color3.fromRGB(255,50,100),cb=function() CFG.ParticleType="Hearts"; ClearEffect("Particles") end},
    {name="⭐Stars",col=Color3.fromRGB(255,200,0),cb=function() CFG.ParticleType="Stars"; ClearEffect("Particles") end},
})

-- PRESETS
local presets = tabFrames["Presets"]
Sep(presets, "🔥 EPIC PRESETS 🔥")

BigButton(presets, "👑 GOD MODE 👑", function()
    EnableGodMode()
end, Color3.fromRGB(255, 100, 50))

BigButton(presets, "😇 ANGEL", function()
    CFG.Wings = true; CFG.WingStyle = "Angel"
    CFG.Halo = true; CFG.HaloColor = Color3.fromRGB(255, 215, 0)
    CFG.Aura = true; CFG.AuraColor = Color3.fromRGB(255, 255, 200)
    CFG.BodyGlow = true; CFG.GlowColor = Color3.fromRGB(255, 255, 200)
    CFG.ParticleType = "Sparkle"; CFG.Particles = true
    UpdateEffects()
    Notify("Preset", "Angel activated", 2)
end, Color3.fromRGB(255, 215, 0))

BigButton(presets, "😈 DEMON", function()
    CFG.Wings = true; CFG.WingStyle = "Demon"
    CFG.Aura = true; CFG.AuraColor = Color3.fromRGB(255, 0, 0)
    CFG.BodyGlow = true; CFG.GlowColor = Color3.fromRGB(255, 0, 0)
    CFG.ParticleType = "Fire"; CFG.Particles = true
    CFG.Trail = true
    UpdateEffects()
    Notify("Preset", "Demon activated", 2)
end, Color3.fromRGB(180, 0, 0))

BigButton(presets, "🐉 DRAGON", function()
    CFG.Wings = true; CFG.WingStyle = "Dragon"
    CFG.Aura = true; CFG.AuraColor = Color3.fromRGB(0, 200, 100)
    CFG.Sword = true
    CFG.Orbs = true
    UpdateEffects()
    Notify("Preset", "Dragon activated", 2)
end, Color3.fromRGB(0, 150, 100))

BigButton(presets, "🌈 RAINBOW", function()
    CFG.Wings = true; CFG.WingStyle = "Rainbow"
    CFG.AuraRainbow = true
    CFG.Aura = true; CFG.Trail = true; CFG.TrailRainbow = true
    CFG.FloatingRings = true
    CFG.ParticleType = "Stars"; CFG.Particles = true
    UpdateEffects()
    Notify("Preset", "Rainbow activated", 2)
end, Color3.fromRGB(200, 50, 200))

BigButton(presets, "🔥 FIRE LORD", function()
    CFG.Wings = true; CFG.WingStyle = "Fire"
    CFG.Aura = true; CFG.AuraColor = Color3.fromRGB(255, 100, 0)
    CFG.ParticleType = "Fire"; CFG.Particles = true
    CFG.Crown = true; CFG.Cape = true
    UpdateEffects()
    Notify("Preset", "Fire Lord activated", 2)
end, Color3.fromRGB(255, 100, 0))

BigButton(presets, "❄️ ICE KING", function()
    CFG.Wings = true; CFG.WingStyle = "Ice"
    CFG.Aura = true; CFG.AuraColor = Color3.fromRGB(150, 200, 255)
    CFG.ParticleType = "Lightning"; CFG.Particles = true
    CFG.Crown = true
    CFG.BodyGlow = true; CFG.GlowColor = Color3.fromRGB(150, 200, 255)
    UpdateEffects()
    Notify("Preset", "Ice King activated", 2)
end, Color3.fromRGB(100, 180, 255))

BigButton(presets, "❌ REMOVE ALL", function()
    for _, key in ipairs({"Wings","Aura","Trail","Particles","FloatingRings","Halo","BodyGlow","Sword","Crown","Cape","Orbs","AuraRainbow","TrailRainbow"}) do
        CFG[key] = false
    end
    ClearAllEffects()
    Notify("Preset", "All effects removed", 2)
end, Color3.fromRGB(80, 80, 80))

-- SETTINGS
local set = tabFrames["Settings"]
Sep(set,"Status")
local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(1,0,0,70); statusFrame.BackgroundColor3 = Theme.card; statusFrame.BorderSizePixel = 0; statusFrame.Parent = set
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0,10)

local hookLbl = Instance.new("TextLabel"); hookLbl.Size = UDim2.new(0.5,0,0,22); hookLbl.Position = UDim2.new(0,14,0,8)
hookLbl.BackgroundTransparency = 1; hookLbl.Font = Enum.Font.GothamBold; hookLbl.TextSize = 12
hookLbl.TextXAlignment = Enum.TextXAlignment.Left; hookLbl.Text = HookOK and "Hook: Active" or "Hook: Failed"
hookLbl.TextColor3 = HookOK and Theme.green or Theme.accent; hookLbl.Parent = statusFrame

local pingLbl = Instance.new("TextLabel"); pingLbl.Size = UDim2.new(0.5,-14,0,22); pingLbl.Position = UDim2.new(0.5,0,0,8)
pingLbl.BackgroundTransparency = 1; pingLbl.Font = Enum.Font.Gotham; pingLbl.TextSize = 11
pingLbl.TextColor3 = Theme.dim; pingLbl.TextXAlignment = Enum.TextXAlignment.Right; pingLbl.Parent = statusFrame

local predLbl = Instance.new("TextLabel"); predLbl.Size = UDim2.new(1,-28,0,20); predLbl.Position = UDim2.new(0,14,0,34)
predLbl.BackgroundTransparency = 1; predLbl.Font = Enum.Font.Gotham; predLbl.TextSize = 10
predLbl.TextColor3 = Theme.dim; predLbl.TextXAlignment = Enum.TextXAlignment.Left; predLbl.Parent = statusFrame

spawn(function() while Alive do
    pingLbl.Text = "Ping: "..math.floor(GetPing()).."ms"
    predLbl.Text = "Pred: "..string.format("%.3f",CFG.Pred).." | Part: "..CFG.Part.." | Key: "..CFG.AimKey
    task.wait(1) end end)

Sep(set,"Prediction")
BtnRow(set,{
    {name="Low",col=Color3.fromRGB(0,150,80),cb=function() CFG.Pred=0.125; CFG.AutoPred=false end},
    {name="Normal",col=Color3.fromRGB(180,160,0),cb=function() CFG.Pred=0.165; CFG.AutoPred=false end},
    {name="High",col=Color3.fromRGB(200,100,0),cb=function() CFG.Pred=0.185; CFG.AutoPred=false end},
    {name="Max",col=Color3.fromRGB(200,40,40),cb=function() CFG.Pred=0.220; CFG.AutoPred=false end},
})

Sep(set,"Info")
local infoLbl = Instance.new("TextLabel"); infoLbl.Size = UDim2.new(1,0,0,60); infoLbl.BackgroundColor3 = Theme.card
infoLbl.TextColor3 = Theme.dim; infoLbl.Font = Enum.Font.Gotham; infoLbl.TextSize = 10; infoLbl.TextWrapped = true
infoLbl.Text = "INSERT = Hide Menu | DELETE = Unload\nHold Aim Key to activate aim\n\ngithub.com/moccommm/main"
infoLbl.BorderSizePixel = 0; infoLbl.Parent = set; Instance.new("UICorner", infoLbl).CornerRadius = UDim.new(0,8)

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Insert or inp.KeyCode == Enum.KeyCode.RightShift then G.Enabled = not G.Enabled end
end)

spawn(function()
    while Alive do
        if UIS:IsKeyDown(Enum.KeyCode.Delete) then
            Alive = false
            ClearAllEffects()
            pcall(function() rc:Disconnect() end)
            for p in pairs(ESP) do KillESP(p) end
            if fov then pcall(function() fov:Remove() end) end
            if dot then pcall(function() dot:Remove() end) end
            if line then pcall(function() line:Remove() end) end
            if info then pcall(function() info:Remove() end) end
            if pingTxt then pcall(function() pingTxt:Remove() end) end
            if watermark then pcall(function() watermark:Remove() end) end
            if G then pcall(function() G:Destroy() end) end
            Notify("Da Hood Premium","Unloaded",2)
            break
        end
        task.wait(0.5)
    end
end)

Notify("Da Hood Premium v7","Loaded! Check Presets tab",3)
print("=== DA HOOD PREMIUM v7 ===")
print("Hook: "..(HookOK and "OK" or "FAIL"))
print("EPIC EFFECTS + PRESETS")
print("Try GOD MODE preset!")
print("===========================")