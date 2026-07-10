-- ===============================================
--   Da Hood Aim v4 | Auto Config | Modern UI
--   2025 | All Auto | Beautiful Menu
-- ===============================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3)

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local CG = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()

if not Drawing then warn("No Drawing") return end

-- ==================== AUTO CONFIG ====================
local function GetPing()
    local p = 100
    pcall(function() p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return p
end

local function AutoPrediction()
    local ping = GetPing()
    if ping < 60 then return 0.125
    elseif ping < 100 then return 0.145
    elseif ping < 150 then return 0.165
    elseif ping < 200 then return 0.185
    else return 0.210 end
end

local CFG = {
    Enabled = true,
    AimKey = "MB2",
    FOV = 180,
    Pred = AutoPrediction(),
    Part = "Head",
    TeamCheck = false,
    NoDowned = true,
    NoCuffed = true,
    AutoPred = true,
    ShowFOV = true,
    ShowDot = true,
    ShowLine = true,
    ShowESP = true,
    ShowNames = true,
    ShowHP = true,
    ShowDist = true,
    Notify = true,
}

local Alive = true
local Target = nil
local Aiming = false
local Kills = 0

local function Draw(t, p)
    local s, o = pcall(Drawing.new, t)
    if not s then return nil end
    for k, v in pairs(p or {}) do pcall(function() o[k] = v end) end
    return o
end

-- ==================== DA HOOD ====================
local function IsValid(plr)
    if not plr then return false end
    if plr == LP then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.Health <= 0 then return false end
    if not ch:FindFirstChild(CFG.Part) then return false end

    if CFG.TeamCheck then
        local ok, same = pcall(function()
            return plr.Team and LP.Team and plr.Team == LP.Team
        end)
        if ok and same then return false end
    end

    if CFG.NoDowned then
        local ok, down = pcall(function()
            local be = ch:FindFirstChild("BodyEffects")
            if be then
                local ko = be:FindFirstChild("K.O")
                if ko then return ko.Value == true end
            end
            return false
        end)
        if ok and down then return false end
    end

    if CFG.NoCuffed then
        local ok, c = pcall(function()
            return ch:FindFirstChild("Handcuffed") ~= nil
        end)
        if ok and c then return false end
    end

    return true
end

local function GetTarget()
    local best, bestD = nil, CFG.FOV
    local cx = Cam.ViewportSize.X / 2
    local cy = Cam.ViewportSize.Y / 2

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
    return best
end

local function PredictPos()
    if not Target then return nil end
    local ch = Target.Character
    if not ch then return nil end
    local part = ch:FindFirstChild(CFG.Part)
    if not part then return nil end
    local vel = Vector3.zero
    pcall(function()
        local r = ch:FindFirstChild("HumanoidRootPart")
        if r then vel = r.AssemblyLinearVelocity end
    end)
    return part.Position + (vel * CFG.Pred)
end

-- ==================== DRAWINGS ====================
local fov = Draw("Circle", {Thickness=1.5, NumSides=80, Filled=false, Transparency=0.8, Visible=false})
local dot = Draw("Circle", {Thickness=2, NumSides=16, Filled=true, Radius=5, Transparency=1, Visible=false})
local line = Draw("Line", {Thickness=1.5, Transparency=0.8, Visible=false})
local info = Draw("Text", {Size=15, Font=2, Outline=true, Position=Vector2.new(10,10), Visible=false})
local pingText = Draw("Text", {Size=12, Font=2, Outline=true, Position=Vector2.new(10,30), Color=Color3.fromRGB(200,200,200), Visible=false})

local ESP = {}
local function MakeESP(plr)
    if plr == LP or ESP[plr] then return end
    ESP[plr] = {
        dot = Draw("Circle", {Thickness=1, NumSides=12, Filled=true, Radius=4, Transparency=1, Visible=false}),
        name = Draw("Text", {Size=12, Center=true, Outline=true, Font=2, Visible=false}),
        hp = Draw("Text", {Size=11, Center=true, Outline=true, Font=2, Visible=false}),
        dist = Draw("Text", {Size=10, Center=true, Outline=true, Font=2, Color=Color3.fromRGB(180,180,180), Visible=false}),
    }
end
local function KillESP(plr)
    local e = ESP[plr]
    if not e then return end
    for _, v in pairs(e) do pcall(function() v:Remove() end) end
    ESP[plr] = nil
end

-- ==================== HOOKS ====================
local HookOK = false

if hookmetamethod then
    pcall(function()
        local old
        old = hookmetamethod(game, "__index", newcclosure(function(self, k)
            if not Alive or not CFG.Enabled or not Aiming then
                return old(self, k)
            end
            local ok2, isMouse = pcall(function() return self == Mouse end)
            if not ok2 or not isMouse then return old(self, k) end
            local pos = PredictPos()
            if not pos then return old(self, k) end
            if k == "Hit" then return CFrame.new(pos) end
            if k == "Target" then
                if Target and Target.Character then
                    local p = Target.Character:FindFirstChild(CFG.Part)
                    if p then return p end
                end
            end
            if k == "UnitRay" then
                local o = Cam.CFrame.Position
                return Ray.new(o, (pos-o).Unit)
            end
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
            local m = getnamecallmethod()
            local a = {...}
            local pos = PredictPos()
            if not pos then return old2(self, ...) end

            if m == "Raycast" and self == workspace then
                if typeof(a[1]) == "Vector3" then
                    return old2(self, a[1], (pos-a[1]).Unit*5000, select(3, ...))
                end
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

-- ==================== INPUT ====================
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
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

-- ==================== AUTO PREDICTION ====================
spawn(function()
    while Alive do
        if CFG.AutoPred then
            CFG.Pred = AutoPrediction()
        end
        task.wait(3)
    end
end)

-- ==================== RENDER ====================
local rc = RS.RenderStepped:Connect(function()
    if not Alive then return end
    Cam = workspace.CurrentCamera
    local cx = Cam.ViewportSize.X/2
    local cy = Cam.ViewportSize.Y/2

    if CFG.Enabled then GetTarget() else Target = nil end

    if fov then
        fov.Visible = CFG.ShowFOV and CFG.Enabled
        fov.Position = Vector2.new(cx, cy)
        fov.Radius = CFG.FOV
        fov.Color = Aiming and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,50,80)
    end

    local pos = PredictPos()
    if pos and CFG.Enabled then
        local sp, vis = Cam:WorldToViewportPoint(pos)
        if vis then
            if dot and CFG.ShowDot then
                dot.Position = Vector2.new(sp.X, sp.Y)
                dot.Color = Aiming and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,220,50)
                dot.Visible = true
            end
            if line and CFG.ShowLine then
                line.From = Vector2.new(cx, cy)
                line.To = Vector2.new(sp.X, sp.Y)
                line.Color = Aiming and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,100,100)
                line.Visible = true
            end
        else
            if dot then dot.Visible = false end
            if line then line.Visible = false end
        end
    else
        if dot then dot.Visible = false end
        if line then line.Visible = false end
    end

    if info then
        if CFG.Enabled then
            local n = Target and Target.Name or "-"
            local s = Aiming and "LOCKED" or "SCANNING"
            info.Text = s .. "  " .. n .. "  [" .. CFG.Part .. "]"
            info.Color = Aiming and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,220,50)
            info.Visible = true
        else
            info.Visible = false
        end
    end

    if pingText then
        local ping = math.floor(GetPing())
        pingText.Text = "Ping: " .. ping .. "ms | Pred: " .. string.format("%.3f", CFG.Pred)
        pingText.Visible = CFG.Enabled
    end

    for plr, e in pairs(ESP) do
        if not plr or not plr.Parent then
            KillESP(plr)
        elseif CFG.ShowESP and IsValid(plr) then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local sp, vis = Cam:WorldToViewportPoint(head.Position)
                if vis then
                    local dist = 100
                    pcall(function()
                        local mr = LP.Character:FindFirstChild("HumanoidRootPart")
                        if mr then dist = (mr.Position - head.Position).Magnitude end
                    end)
                    if e.dot then
                        e.dot.Position = Vector2.new(sp.X, sp.Y)
                        e.dot.Radius = math.clamp(500/dist, 2, 8)
                        e.dot.Color = (Target==plr) and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,60,80)
                        e.dot.Visible = true
                    end
                    if e.name and CFG.ShowNames then
                        e.name.Text = plr.Name
                        e.name.Position = Vector2.new(sp.X, sp.Y-16)
                        e.name.Color = Color3.new(1,1,1)
                        e.name.Visible = true
                    elseif e.name then e.name.Visible = false end
                    if e.hp and CFG.ShowHP then
                        local hp = 0
                        pcall(function() hp = math.floor(plr.Character:FindFirstChildOfClass("Humanoid").Health) end)
                        e.hp.Text = hp .. " HP"
                        e.hp.Position = Vector2.new(sp.X, sp.Y+10)
                        e.hp.Color = Color3.fromRGB(255,255,100)
                        e.hp.Visible = true
                    elseif e.hp then e.hp.Visible = false end
                    if e.dist and CFG.ShowDist then
                        e.dist.Text = math.floor(dist) .. "m"
                        e.dist.Position = Vector2.new(sp.X, sp.Y+22)
                        e.dist.Visible = true
                    elseif e.dist then e.dist.Visible = false end
                else
                    for _, v in pairs(e) do v.Visible = false end
                end
            else
                for _, v in pairs(e) do v.Visible = false end
            end
        else
            for _, v in pairs(e) do v.Visible = false end
        end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do MakeESP(p) end
Players.PlayerAdded:Connect(function(p) task.wait(1) MakeESP(p) end)
Players.PlayerRemoving:Connect(KillESP)

-- ==================== MODERN UI ====================
local G = Instance.new("ScreenGui")
G.Name = "DH_" .. math.random(100000, 999999)
G.ResetOnSpawn = false
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(G) end
    G.Parent = CG
end)
if not G.Parent then pcall(function() G.Parent = LP.PlayerGui end) end

-- Colors
local C = {
    bg = Color3.fromRGB(12, 12, 18),
    card = Color3.fromRGB(22, 22, 32),
    accent = Color3.fromRGB(255, 55, 85),
    accent2 = Color3.fromRGB(0, 210, 120),
    text = Color3.fromRGB(240, 240, 245),
    dim = Color3.fromRGB(120, 120, 140),
    on = Color3.fromRGB(0, 210, 120),
    off = Color3.fromRGB(60, 60, 75),
    slider = Color3.fromRGB(255, 55, 85),
    border = Color3.fromRGB(40, 40, 55),
}

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 320, 0, 0)
Main.Position = UDim2.new(0.5, -160, 0.15, 0)
Main.BackgroundColor3 = C.bg
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.AutomaticSize = Enum.AutomaticSize.Y
Main.Parent = G

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
local str = Instance.new("UIStroke", Main)
str.Color = C.accent
str.Thickness = 1.5
str.Transparency = 0.5

local pad = Instance.new("UIPadding", Main)
pad.PaddingLeft = UDim.new(0,14)
pad.PaddingRight = UDim.new(0,14)
pad.PaddingTop = UDim.new(0,10)
pad.PaddingBottom = UDim.new(0,12)

Instance.new("UIListLayout", Main).Padding = UDim.new(0,5)

-- UI Builders
local function Tween(obj, props, dur)
    TweenService:Create(obj, TweenInfo.new(dur or 0.25, Enum.EasingStyle.Quint), props):Play()
end

local function Header(text, sub)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,50)
    f.BackgroundColor3 = C.accent
    f.BorderSizePixel = 0
    f.Parent = Main
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

    local g = Instance.new("UIGradient", f)
    g.Color = ColorSequence.new(C.accent, Color3.fromRGB(180,30,80))
    g.Rotation = 45

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,0,28)
    t.Position = UDim2.new(0,12,0,6)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = Color3.new(1,1,1)
    t.Font = Enum.Font.GothamBlack
    t.TextSize = 17
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = f

    if sub then
        local s = Instance.new("TextLabel")
        s.Size = UDim2.new(1,0,0,14)
        s.Position = UDim2.new(0,12,0,30)
        s.BackgroundTransparency = 1
        s.Text = sub
        s.TextColor3 = Color3.fromRGB(255,200,210)
        s.Font = Enum.Font.Gotham
        s.TextSize = 10
        s.TextXAlignment = Enum.TextXAlignment.Left
        s.Parent = f
    end
end

local function Sep(text)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,22)
    f.BackgroundTransparency = 1
    f.Parent = Main

    local l = Instance.new("Frame")
    l.Size = UDim2.new(0.3,0,0,1)
    l.Position = UDim2.new(0,0,0.5,0)
    l.BackgroundColor3 = C.border
    l.BorderSizePixel = 0
    l.Parent = f

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0.4,0,1,0)
    t.Position = UDim2.new(0.3,0,0,0)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = C.dim
    t.Font = Enum.Font.GothamBold
    t.TextSize = 10
    t.Parent = f

    local r = Instance.new("Frame")
    r.Size = UDim2.new(0.3,0,0,1)
    r.Position = UDim2.new(0.7,0,0.5,0)
    r.BackgroundColor3 = C.border
    r.BorderSizePixel = 0
    r.Parent = f
end

local function Toggle(name, key)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,34)
    f.BackgroundColor3 = C.card
    f.BorderSizePixel = 0
    f.Parent = Main
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7,-10,1,0)
    lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = C.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    -- Switch
    local sw = Instance.new("Frame")
    sw.Size = UDim2.new(0,44,0,22)
    sw.Position = UDim2.new(1,-56,0.5,-11)
    sw.BorderSizePixel = 0
    sw.Parent = f
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,18,0,18)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.Parent = sw
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = f

    local function upd()
        if CFG[key] then
            Tween(sw, {BackgroundColor3 = C.on})
            Tween(knob, {Position = UDim2.new(1,-20,0.5,-9)})
        else
            Tween(sw, {BackgroundColor3 = C.off})
            Tween(knob, {Position = UDim2.new(0,2,0.5,-9)})
        end
    end
    upd()

    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        upd()
    end)
end

local function Slider(name, key, mn, mx, dec)
    dec = dec or 0

    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,46)
    f.BackgroundColor3 = C.card
    f.BorderSizePixel = 0
    f.Parent = Main
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-20,0,20)
    lbl.Position = UDim2.new(0,14,0,4)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = C.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,-28,0,8)
    bar.Position = UDim2.new(0,14,0,30)
    bar.BackgroundColor3 = C.off
    bar.BorderSizePixel = 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = C.slider
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,14,0,14)
    circle.BackgroundColor3 = Color3.new(1,1,1)
    circle.BorderSizePixel = 0
    circle.Parent = bar
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)

    local function upd()
        local p = math.clamp((CFG[key]-mn)/(mx-mn),0,1)
        fill.Size = UDim2.new(p,0,1,0)
        circle.Position = UDim2.new(p,-7,0.5,-7)
        local v = dec>0 and string.format("%."..dec.."f", CFG[key]) or tostring(math.floor(CFG[key]))
        lbl.Text = name .. "  " .. v
    end
    upd()

    local drag = false
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local p = math.clamp((i.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
            local v = mn+(mx-mn)*p
            if dec > 0 then CFG[key] = math.floor(v*10^dec)/10^dec
            else CFG[key] = math.floor(v) end
            upd()
        end
    end)

    return upd
end

local function BtnRow(items)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,30)
    row.BackgroundTransparency = 1
    row.Parent = Main

    for i, item in ipairs(items) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1/#items, -4, 1, 0)
        b.Position = UDim2.new((i-1)*(1/#items), 2, 0, 0)
        b.BackgroundColor3 = item.col or C.card
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = item.name
        b.BorderSizePixel = 0
        b.Parent = row
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)

        b.MouseEnter:Connect(function() Tween(b, {BackgroundColor3 = C.accent}, 0.15) end)
        b.MouseLeave:Connect(function() Tween(b, {BackgroundColor3 = item.col or C.card}, 0.15) end)
        b.MouseButton1Click:Connect(item.cb)
    end
end

local function StatusCard()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,55)
    f.BackgroundColor3 = C.card
    f.BorderSizePixel = 0
    f.Parent = Main
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

    local hookLbl = Instance.new("TextLabel")
    hookLbl.Size = UDim2.new(0.5,0,0,20)
    hookLbl.Position = UDim2.new(0,12,0,6)
    hookLbl.BackgroundTransparency = 1
    hookLbl.Font = Enum.Font.GothamBold
    hookLbl.TextSize = 11
    hookLbl.TextXAlignment = Enum.TextXAlignment.Left
    hookLbl.Parent = f

    if HookOK then
        hookLbl.Text = "Hook: Active"
        hookLbl.TextColor3 = C.on
    else
        hookLbl.Text = "Hook: Failed"
        hookLbl.TextColor3 = C.accent
    end

    local pingLbl = Instance.new("TextLabel")
    pingLbl.Size = UDim2.new(0.5,0,0,20)
    pingLbl.Position = UDim2.new(0.5,0,0,6)
    pingLbl.BackgroundTransparency = 1
    pingLbl.Font = Enum.Font.Gotham
    pingLbl.TextSize = 11
    pingLbl.TextColor3 = C.dim
    pingLbl.TextXAlignment = Enum.TextXAlignment.Right
    pingLbl.Parent = f

    local predLbl = Instance.new("TextLabel")
    predLbl.Size = UDim2.new(1,-24,0,20)
    predLbl.Position = UDim2.new(0,12,0,28)
    predLbl.BackgroundTransparency = 1
    predLbl.Font = Enum.Font.Gotham
    predLbl.TextSize = 10
    predLbl.TextColor3 = C.dim
    predLbl.TextXAlignment = Enum.TextXAlignment.Left
    predLbl.Parent = f

    spawn(function()
        while Alive do
            local ping = math.floor(GetPing())
            pingLbl.Text = "Ping: " .. ping .. "ms"
            predLbl.Text = "Auto Prediction: " .. string.format("%.3f", CFG.Pred) .. " | Part: " .. CFG.Part
            task.wait(1)
        end
    end)
end

-- ==================== BUILD UI ====================
Header("DA HOOD", "Silent Aim + ESP | Auto Config | v4")

Sep("AIMBOT")
Toggle("Silent Aim", "Enabled")
Toggle("Auto Prediction", "AutoPred")
Slider("FOV", "FOV", 30, 500)
Slider("Prediction", "Pred", 0.05, 0.3, 3)

Sep("HIT PART")
BtnRow({
    {name = "HEAD", col = Color3.fromRGB(200,40,60), cb = function() CFG.Part = "Head" end},
    {name = "TORSO", col = Color3.fromRGB(40,80,200), cb = function() CFG.Part = "UpperTorso" end},
    {name = "ROOT", col = Color3.fromRGB(80,80,100), cb = function() CFG.Part = "HumanoidRootPart" end},
})

Sep("AIM KEY")
BtnRow({
    {name = "RMB", col = C.card, cb = function() CFG.AimKey = "MB2" end},
    {name = "LMB", col = C.card, cb = function() CFG.AimKey = "MB1" end},
    {name = "Q", col = C.card, cb = function() CFG.AimKey = "Q" end},
    {name = "E", col = C.card, cb = function() CFG.AimKey = "E" end},
})

Sep("FILTERS")
Toggle("Team Check", "TeamCheck")
Toggle("Ignore Downed", "NoDowned")
Toggle("Ignore Cuffed", "NoCuffed")

Sep("VISUALS")
Toggle("FOV Circle", "ShowFOV")
Toggle("Target Dot", "ShowDot")
Toggle("Target Line", "ShowLine")
Toggle("ESP Dots", "ShowESP")
Toggle("Show Names", "ShowNames")
Toggle("Show HP", "ShowHP")
Toggle("Show Distance", "ShowDist")

Sep("STATUS")
StatusCard()

-- Footer
local foot = Instance.new("TextLabel")
foot.Size = UDim2.new(1,0,0,16)
foot.BackgroundTransparency = 1
foot.TextColor3 = Color3.fromRGB(80,80,90)
foot.Font = Enum.Font.Gotham
foot.TextSize = 9
foot.Text = "INSERT = hide  |  DELETE = unload  |  Hold RMB = aim"
foot.Parent = Main

-- ==================== HOTKEYS ====================
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Insert or inp.KeyCode == Enum.KeyCode.RightShift then
        G.Enabled = not G.Enabled
    end
end)

spawn(function()
    while Alive do
        if UIS:IsKeyDown(Enum.KeyCode.Delete) then
            Alive = false
            pcall(function() rc:Disconnect() end)
            for p in pairs(ESP) do KillESP(p) end
            if fov then pcall(function() fov:Remove() end) end
            if dot then pcall(function() dot:Remove() end) end
            if line then pcall(function() line:Remove() end) end
            if info then pcall(function() info:Remove() end) end
            if pingText then pcall(function() pingText:Remove() end) end
            if G then pcall(function() G:Destroy() end) end
            print("[+] Unloaded")
            break
        end
        task.wait(0.5)
    end
end)

print("=== DA HOOD AIM v4 ===")
print("Hook: " .. (HookOK and "OK" or "FAIL"))
print("Ping: " .. math.floor(GetPing()) .. "ms")
print("Pred: " .. string.format("%.3f", CFG.Pred))
print("INSERT = menu")
print("DELETE = unload")
print("======================")