-- ===============================================
--   SAFE HUB v4.0 - UNIVERSAL EDITION
--   Da Hood + Boom Hood Auto-Detect
-- ===============================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local TS = game:GetService("TweenService")
local SG = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer
local Cam = WS.CurrentCamera

-- ==================== АВТООПРЕДЕЛЕНИЕ ИГРЫ ====================
local GAME = "Unknown"
local GAME_ID = game.PlaceId
local GAME_NAME = ""
pcall(function()
    GAME_NAME = game:GetService("MarketplaceService"):GetProductInfo(GAME_ID).Name
end)

-- Da Hood ID: 2788229376
-- Boom Hood ID: 114504016540209 (или похожие)
local nameLower = GAME_NAME:lower()

if GAME_ID == 2788229376 or nameLower:find("da hood") or nameLower:find("дахуд") then
    GAME = "DaHood"
elseif nameLower:find("boom hood") or nameLower:find("bum hood") or nameLower:find("бум") or nameLower:find("boom") or nameLower:find("шлем") or nameLower:find("дуэл") then
    GAME = "BoomHood"
else
    -- Определяем по структуре игры
    if game:GetService("ReplicatedStorage"):FindFirstChild("Events") 
    or WS:FindFirstChild("Live") then
        GAME = "DaHood"
    else
        GAME = "BoomHood"  -- по умолчанию
    end
end

-- ==================== CONFIG (адаптируется под игру) ====================
local CFG = {
    SilentAim = true, 
    SilentAimPart = "Head", 
    SilentAimFOV = 200,
    SilentAimPrediction = GAME == "DaHood" and 0.165 or 0.138,  -- Da Hood медленнее
    SilentAimTeamCheck = false,
    SilentAimNoDowned = true, 
    SilentAimVisibleOnly = false,
    Resolver = true, 
    TargetPriority = "FOV",
    AutoPrediction = false, 
    BulletSpeed = GAME == "DaHood" and 1800 or 1500,
    TriggerBot = false, 
    TriggerDelay = 50,
    
    ESP = true, ESPBoxes = true,
    ESPNames = true, ESPHealth = true, ESPDistance = true,
    ESPTracers = false, ESPTracerFrom = "Bottom",
    ESPWeapon = false, ESPHeadDot = false,
    ESPMaxDist = 1000,
    
    ShowFOV = true, ShowFOVDot = true, FOVRainbow = false,
    FOVColor = GAME == "DaHood" and Color3.fromRGB(255, 50, 100) or Color3.fromRGB(120, 90, 220),
    FOVThickness = 2,
    Crosshair = false, CrosshairSize = 10, CrosshairGap = 4,
    CrosshairColor = Color3.fromRGB(0, 255, 100), CrosshairDot = true,
    
    -- Anti-Kick для Boom Hood
    AntiKick = GAME == "BoomHood",
}

local Target, cachedPred, inHook, oldNamecall = nil, nil, false, nil
local ESPObjects, DrawObjs = {}, {}
local RainbowHue, FPS = 0, 60
local FPSHistory = {}

-- ==================== UTILS ====================
local function Notify(t,m,d)
    pcall(function() SG:SetCore("SendNotification",{Title=t,Text=m,Duration=d or 3}) end)
end
local function NewDraw(t,p)
    local ok,obj = pcall(Drawing.new,t)
    if not ok then return nil end
    for k,v in pairs(p or {}) do pcall(function() obj[k]=v end) end
    return obj
end
local function GetChar() return LP.Character end
local function GetRoot() local c=GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetPos() local r=GetRoot(); return r and r.Position end
local function GetHum(ch) return ch and ch:FindFirstChildOfClass("Humanoid") end
local function GetHP(ch) local h=GetHum(ch); return h and math.floor(h.Health) or 0 end
local function GetMaxHP(ch) local h=GetHum(ch); return h and math.floor(h.MaxHealth) or 100 end
local function GetPing()
    local ok,v=pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.floor(v) or 0
end

-- Универсальная проверка Downed (работает в обеих играх)
local function IsDowned(ch)
    if not ch then return false end
    local ok,r=pcall(function()
        -- Da Hood: BodyEffects/K.O
        local be=ch:FindFirstChild("BodyEffects")
        if be then 
            local ko=be:FindFirstChild("K.O")
            if ko then return ko.Value end 
        end
        -- Boom Hood: аналогично
        local ko2 = ch:FindFirstChild("K.O") or ch:FindFirstChild("Downed")
        if ko2 then return ko2.Value end
        return false
    end)
    return ok and r
end

local function GetWeapon(plr)
    if not plr or not plr.Character then return "None" end
    local tool=plr.Character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or "None"
end
local function IsVisible(plr)
    if not plr or not plr.Character then return false end
    local myPos=GetPos(); local head=plr.Character:FindFirstChild("Head")
    if not myPos or not head then return false end
    local params=RaycastParams.new()
    params.FilterDescendantsInstances={LP.Character,plr.Character}
    params.FilterType=Enum.RaycastFilterType.Exclude
    local hit=WS:Raycast(myPos,head.Position-myPos,params)
    return not hit
end
local function IsValid(plr)
    if plr==LP or not plr or not plr.Parent then return false end
    local ch=plr.Character; if not ch then return false end
    local hum=GetHum(ch); if not hum or hum.Health<=0 then return false end
    local part=ch:FindFirstChild(CFG.SilentAimPart) or ch:FindFirstChild("Head")
    if not part then return false end
    if CFG.SilentAimTeamCheck then
        local ok,same=pcall(function() return plr.Team and LP.Team and plr.Team==LP.Team end)
        if ok and same then return false end
    end
    if CFG.SilentAimNoDowned and IsDowned(ch) then return false end
    if CFG.SilentAimVisibleOnly and not IsVisible(plr) then return false end
    return true
end
local function GetScreenPos(pos)
    local sp,vis=Cam:WorldToViewportPoint(pos)
    return Vector2.new(sp.X,sp.Y),vis,sp.Z
end
local function ScreenCenter() return Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y/2) end

-- ==================== TARGET/PRED ====================
local function GetTarget()
    local myPos=GetPos(); if not myPos then return nil end
    local sc=ScreenCenter(); local best,bs=nil,math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if IsValid(plr) then
            local ch=plr.Character
            local part=ch:FindFirstChild(CFG.SilentAimPart) or ch:FindFirstChild("Head")
            if part then
                local sp,vis=GetScreenPos(part.Position)
                if vis then
                    local fd=(sp-sc).Magnitude
                    if fd<=CFG.SilentAimFOV then
                        local wd=(myPos-part.Position).Magnitude
                        local sc2=CFG.TargetPriority=="Distance" and wd or fd
                        if sc2<bs then bs=sc2; best=plr end
                    end
                end
            end
        end
    end
    return best
end
local function GetPredictedPos(plr)
    if not plr or not plr.Character then return nil end
    local ch=plr.Character
    local part=ch:FindFirstChild(CFG.SilentAimPart) or ch:FindFirstChild("Head")
    local root=ch:FindFirstChild("HumanoidRootPart")
    if not part or not root then return nil end
    local vel=root.AssemblyLinearVelocity; local pred=CFG.SilentAimPrediction
    if CFG.AutoPrediction then
        local myPos=GetPos()
        if myPos then pred=pred+((myPos-part.Position).Magnitude/CFG.BulletSpeed)*0.5 end
    end
    local hum=GetHum(ch)
    local predicted=part.Position+Vector3.new(vel.X*pred,0,vel.Z*pred)
    if hum then
        local state=hum:GetState(); local g=WS.Gravity or 196.2
        if state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall then
            local yOff=vel.Y*pred-0.5*g*pred*pred
            predicted=Vector3.new(predicted.X,part.Position.Y+yOff,predicted.Z)
        else
            predicted=Vector3.new(predicted.X,part.Position.Y+vel.Y*pred*0.3,predicted.Z)
        end
    end
    if CFG.Resolver then
        local maxOff=vel.Magnitude*pred*1.5+5
        local off=predicted-part.Position
        if off.Magnitude>maxOff then predicted=part.Position+off.Unit*maxOff end
    end
    return predicted
end

RS.Heartbeat:Connect(function()
    Target=GetTarget()
    cachedPred=(Target and CFG.SilentAim) and GetPredictedPos(Target) or nil
end)

-- ==================== HOOK ====================
-- Задержка для Boom Hood (обход античита)
local function InstallHook()
    if hookmetamethod and getnamecallmethod and newcclosure then
        pcall(function()
            oldNamecall=hookmetamethod(game,"__namecall",newcclosure(function(self,...)
                if inHook then return oldNamecall(self,...) end
                local method=getnamecallmethod(); local args={...}
                
                if CFG.SilentAim and cachedPred then
                    if method=="Raycast" and self==WS then
                        local origin=args[1]
                        if typeof(origin)=="Vector3" then
                            local dir=cachedPred-origin
                            if dir.Magnitude>0.001 then
                                args[2]=dir.Unit*(args[2] and args[2].Magnitude or 1000)
                                return oldNamecall(self,args[1],args[2],args[3])
                            end
                        end
                    end
                    if method=="FindPartOnRayWithIgnoreList" or method=="FindPartOnRayWithWhitelist" or method=="FindPartOnRay" then
                        local ray=args[1]
                        if typeof(ray)=="Ray" then
                            local dir=cachedPred-ray.Origin
                            if dir.Magnitude>0.001 then
                                args[1]=Ray.new(ray.Origin,dir.Unit*ray.Direction.Magnitude)
                            end
                            return oldNamecall(self,table.unpack(args))
                        end
                    end
                end
                
                -- Anti-Kick для Boom Hood
                if CFG.AntiKick and method == "Kick" and self == LP then
                    warn("[Safe Hub] Kick blocked")
                    return nil
                end
                
                return oldNamecall(self,...)
            end))
        end)
        Notify("Silent Aim","Загружен для "..GAME.."!",2)
    end
end

-- Boom Hood: задержка перед hook (обход античита)
if GAME == "BoomHood" then
    task.spawn(function()
        task.wait(math.random(30, 60) / 10)
        InstallHook()
    end)
else
    InstallHook()  -- Da Hood: сразу
end

-- ==================== TRIGGER ====================
task.spawn(function()
    while true do
        task.wait(CFG.TriggerDelay/1000)
        if CFG.TriggerBot and Target then
            pcall(function() mouse1click() end)
        end
    end
end)

-- ==================== ESP ====================
local function MakeESP(plr)
    if plr==LP or ESPObjects[plr] then return end
    ESPObjects[plr]={
        Box=NewDraw("Square",{Visible=false,Filled=false,Thickness=1.5}),
        BoxOut=NewDraw("Square",{Visible=false,Filled=false,Thickness=3,Color=Color3.new(0,0,0),Transparency=0.5}),
        Name=NewDraw("Text",{Visible=false,Center=true,Outline=true,Size=13,Font=2}),
        HP=NewDraw("Text",{Visible=false,Center=true,Outline=true,Size=11,Font=2}),
        Dist=NewDraw("Text",{Visible=false,Center=true,Outline=true,Size=11,Font=2}),
        Weapon=NewDraw("Text",{Visible=false,Center=true,Outline=true,Size=10,Font=2,Color=Color3.fromRGB(200,200,255)}),
        Tracer=NewDraw("Line",{Visible=false,Thickness=1.5}),
        HPBar=NewDraw("Square",{Visible=false,Filled=true}),
        HPBarBG=NewDraw("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(20,20,20)}),
        HeadDot=NewDraw("Circle",{Visible=false,Filled=true,Radius=3,NumSides=12}),
    }
end
local function KillESP(plr)
    local e=ESPObjects[plr]; if not e then return end
    for _,v in pairs(e) do pcall(function() v:Remove() end) end
    ESPObjects[plr]=nil
end
for _,plr in ipairs(Players:GetPlayers()) do MakeESP(plr) end
Players.PlayerAdded:Connect(function(p) task.wait(1); MakeESP(p) end)
Players.PlayerRemoving:Connect(function(p) KillESP(p) end)

DrawObjs.FOV=NewDraw("Circle",{Visible=false,Filled=false,Thickness=2,NumSides=128,Transparency=0.9})
DrawObjs.Dot=NewDraw("Circle",{Visible=false,Filled=true,Radius=5,Transparency=1})
DrawObjs.PredLine=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.fromRGB(0,255,255),Transparency=0.6})
DrawObjs.CH_Top=NewDraw("Line",{Visible=false,Thickness=2})
DrawObjs.CH_Bot=NewDraw("Line",{Visible=false,Thickness=2})
DrawObjs.CH_Left=NewDraw("Line",{Visible=false,Thickness=2})
DrawObjs.CH_Right=NewDraw("Line",{Visible=false,Thickness=2})
DrawObjs.CH_Dot=NewDraw("Circle",{Visible=false,Filled=true,Radius=1.5,NumSides=8})

RS.RenderStepped:Connect(function(dt)
    table.insert(FPSHistory,1/dt)
    if #FPSHistory>30 then table.remove(FPSHistory,1) end
    local s=0; for _,v in ipairs(FPSHistory) do s=s+v end
    FPS=math.floor(s/#FPSHistory)
end)

local espTimer=0
RS.RenderStepped:Connect(function(dt)
    Cam=WS.CurrentCamera; local sc=ScreenCenter()
    RainbowHue=(RainbowHue+0.003)%1

    if DrawObjs.FOV then
        DrawObjs.FOV.Visible=CFG.ShowFOV
        DrawObjs.FOV.Radius=CFG.SilentAimFOV
        DrawObjs.FOV.Position=sc
        DrawObjs.FOV.Thickness=CFG.FOVThickness
        DrawObjs.FOV.Color=CFG.FOVRainbow and Color3.fromHSV(RainbowHue,1,1) or CFG.FOVColor
    end

    if CFG.Crosshair then
        local col=CFG.FOVRainbow and Color3.fromHSV(RainbowHue,1,1) or CFG.CrosshairColor
        local s,g=CFG.CrosshairSize,CFG.CrosshairGap
        for _,k in ipairs({"CH_Top","CH_Bot","CH_Left","CH_Right"}) do
            DrawObjs[k].Visible=true; DrawObjs[k].Color=col
        end
        DrawObjs.CH_Top.From=Vector2.new(sc.X,sc.Y-g-s); DrawObjs.CH_Top.To=Vector2.new(sc.X,sc.Y-g)
        DrawObjs.CH_Bot.From=Vector2.new(sc.X,sc.Y+g); DrawObjs.CH_Bot.To=Vector2.new(sc.X,sc.Y+g+s)
        DrawObjs.CH_Left.From=Vector2.new(sc.X-g-s,sc.Y); DrawObjs.CH_Left.To=Vector2.new(sc.X-g,sc.Y)
        DrawObjs.CH_Right.From=Vector2.new(sc.X+g,sc.Y); DrawObjs.CH_Right.To=Vector2.new(sc.X+g+s,sc.Y)
        if CFG.CrosshairDot then
            DrawObjs.CH_Dot.Visible=true; DrawObjs.CH_Dot.Position=sc; DrawObjs.CH_Dot.Color=col
        else DrawObjs.CH_Dot.Visible=false end
    else
        for _,k in ipairs({"CH_Top","CH_Bot","CH_Left","CH_Right","CH_Dot"}) do
            DrawObjs[k].Visible=false
        end
    end

    if cachedPred and CFG.ShowFOVDot and DrawObjs.Dot then
        local sp,vis=GetScreenPos(cachedPred)
        DrawObjs.Dot.Visible=vis
        if vis then DrawObjs.Dot.Position=sp; DrawObjs.Dot.Color=Color3.fromRGB(0,255,100) end
    else if DrawObjs.Dot then DrawObjs.Dot.Visible=false end end

    if cachedPred and Target and Target.Character and DrawObjs.PredLine then
        local part=Target.Character:FindFirstChild(CFG.SilentAimPart) or Target.Character:FindFirstChild("Head")
        if part then
            local sp1,v1=GetScreenPos(part.Position); local sp2,v2=GetScreenPos(cachedPred)
            if v1 and v2 then
                DrawObjs.PredLine.Visible=true
                DrawObjs.PredLine.From=sp1; DrawObjs.PredLine.To=sp2
            else DrawObjs.PredLine.Visible=false end
        end
    else if DrawObjs.PredLine then DrawObjs.PredLine.Visible=false end end

    espTimer=espTimer+dt
    if espTimer<0.03 then return end
    espTimer=0
    local myPos=GetPos()

    for plr,e in pairs(ESPObjects) do
        pcall(function()
            local hideAll=function() for _,v in pairs(e) do v.Visible=false end end
            if not plr or not plr.Parent or not CFG.ESP then return hideAll() end
            local ch=plr.Character; if not ch then return hideAll() end
            local hum=GetHum(ch); if not hum or hum.Health<=0 then return hideAll() end
            local root=ch:FindFirstChild("HumanoidRootPart"); local head=ch:FindFirstChild("Head")
            if not root or not head then return hideAll() end
            local dist=myPos and (myPos-root.Position).Magnitude or 0
            if dist>CFG.ESPMaxDist then return hideAll() end
            local rootSP,rootVis,rootZ=GetScreenPos(root.Position)
            local headSP,headVis=GetScreenPos(head.Position+Vector3.new(0,0.5,0))
            if not rootVis or rootZ<=0 then return hideAll() end
            local col=Target==plr and Color3.fromRGB(0,255,120) or CFG.FOVColor
            local hp=GetHP(ch); local mhp=GetMaxHP(ch)
            local hpr=math.clamp(hp/math.max(mhp,1),0,1)
            local bh=math.abs(rootSP.Y-headSP.Y)*2.2; local bw=bh*0.55
            local bx=rootSP.X-bw/2; local by=rootSP.Y-bh/2

            if CFG.ESPBoxes then
                e.BoxOut.Visible=true; e.BoxOut.Position=Vector2.new(bx,by); e.BoxOut.Size=Vector2.new(bw,bh)
                e.Box.Visible=true; e.Box.Position=Vector2.new(bx,by); e.Box.Size=Vector2.new(bw,bh); e.Box.Color=col
            else e.Box.Visible=false; e.BoxOut.Visible=false end

            if CFG.ESPHealth then
                e.HPBarBG.Visible=true; e.HPBarBG.Position=Vector2.new(bx-8,by); e.HPBarBG.Size=Vector2.new(4,bh)
                e.HPBar.Visible=true
                e.HPBar.Position=Vector2.new(bx-8,by+bh*(1-hpr))
                e.HPBar.Size=Vector2.new(4,bh*hpr)
                e.HPBar.Color=Color3.fromRGB(math.floor(255*(1-hpr)),math.floor(255*hpr),0)
            else e.HPBar.Visible=false; e.HPBarBG.Visible=false end

            if CFG.ESPNames then
                e.Name.Visible=true; e.Name.Position=Vector2.new(rootSP.X,by-16)
                e.Name.Text=plr.Name..(IsDowned(ch) and " [DOWN]" or ""); e.Name.Color=col
            else e.Name.Visible=false end

            if CFG.ESPHealth then
                e.HP.Visible=true; e.HP.Position=Vector2.new(rootSP.X,by+bh+2)
                e.HP.Text=hp.."/"..mhp
                e.HP.Color=hpr>0.6 and Color3.fromRGB(100,255,100) or hpr>0.3 and Color3.fromRGB(255,255,100) or Color3.fromRGB(255,80,80)
            else e.HP.Visible=false end

            if CFG.ESPDistance then
                e.Dist.Visible=true; e.Dist.Position=Vector2.new(rootSP.X,by+bh+14)
                e.Dist.Text="["..math.floor(dist).."m]"; e.Dist.Color=Color3.fromRGB(180,180,180)
            else e.Dist.Visible=false end

            if CFG.ESPWeapon then
                e.Weapon.Visible=true; e.Weapon.Position=Vector2.new(rootSP.X,by+bh+26)
                e.Weapon.Text=GetWeapon(plr)
            else e.Weapon.Visible=false end

            if CFG.ESPHeadDot and headVis then
                e.HeadDot.Visible=true; e.HeadDot.Position=headSP; e.HeadDot.Color=col
            else e.HeadDot.Visible=false end

            if CFG.ESPTracers then
                e.Tracer.Visible=true
                local fy=CFG.ESPTracerFrom=="Bottom" and Cam.ViewportSize.Y or CFG.ESPTracerFrom=="Top" and 0 or sc.Y
                e.Tracer.From=Vector2.new(sc.X,fy); e.Tracer.To=rootSP; e.Tracer.Color=col
            else e.Tracer.Visible=false end
        end)
    end
end)

-- ===============================================
--                    GUI
-- ===============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SH_"..math.random(1000,9999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiParent = game:GetService("CoreGui")
pcall(function() if gethui then guiParent=gethui() end end)
pcall(function() ScreenGui.Parent=guiParent end)
if not ScreenGui.Parent then ScreenGui.Parent=LP.PlayerGui end

-- Цвета зависят от игры
local isDaHood = GAME == "DaHood"
local C = {
    BG=Color3.fromRGB(15,15,22), BG2=Color3.fromRGB(20,20,30),
    BG3=Color3.fromRGB(25,25,38), Card=Color3.fromRGB(28,28,42),
    CardH=Color3.fromRGB(35,35,52), Border=Color3.fromRGB(45,45,65),
    Accent = isDaHood and Color3.fromRGB(255,50,100) or Color3.fromRGB(140,100,255),
    Accent2 = isDaHood and Color3.fromRGB(255,150,60) or Color3.fromRGB(90,200,255),
    Green=Color3.fromRGB(0,230,140), Text=Color3.fromRGB(245,245,255),
    TextDim=Color3.fromRGB(150,150,180), TextSub=Color3.fromRGB(100,100,130),
    Red=Color3.fromRGB(255,80,100), Yellow=Color3.fromRGB(255,200,60),
    Off=Color3.fromRGB(40,40,58),
}

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 720, 0, 500)
Main.Position = UDim2.new(0.5, -360, 0.5, -250)
Main.BackgroundColor3 = C.BG
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local mS = Instance.new("UIStroke", Main); mS.Color = C.Border

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.Position = UDim2.new(0, 0, 0, 0)
Sidebar.BackgroundColor3 = C.BG2
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

local sbFix = Instance.new("Frame", Sidebar)
sbFix.Size = UDim2.new(0, 10, 1, 0)
sbFix.Position = UDim2.new(1, -10, 0, 0)
sbFix.BackgroundColor3 = C.BG2
sbFix.BorderSizePixel = 0

local LogoIcon = Instance.new("Frame", Sidebar)
LogoIcon.Size = UDim2.new(0, 42, 0, 42)
LogoIcon.Position = UDim2.new(0, 15, 0, 14)
LogoIcon.BackgroundColor3 = C.Accent
LogoIcon.BorderSizePixel = 0
Instance.new("UICorner", LogoIcon).CornerRadius = UDim.new(0, 10)
local lg = Instance.new("UIGradient", LogoIcon)
lg.Color = ColorSequence.new(C.Accent, C.Accent2)
lg.Rotation = 45

local LogoSymbol = Instance.new("TextLabel", LogoIcon)
LogoSymbol.Size = UDim2.new(1, 0, 1, 0)
LogoSymbol.BackgroundTransparency = 1
LogoSymbol.Text = isDaHood and "◆" or "☾"
LogoSymbol.TextColor3 = Color3.new(1,1,1)
LogoSymbol.Font = Enum.Font.GothamBlack
LogoSymbol.TextSize = 22

local LogoTitle = Instance.new("TextLabel", Sidebar)
LogoTitle.Size = UDim2.new(0, 110, 0, 18)
LogoTitle.Position = UDim2.new(0, 65, 0, 18)
LogoTitle.BackgroundTransparency = 1
LogoTitle.Text = "SAFE HUB"
LogoTitle.TextColor3 = C.Text
LogoTitle.Font = Enum.Font.GothamBlack
LogoTitle.TextSize = 13
LogoTitle.TextXAlignment = Enum.TextXAlignment.Left

local LogoVer = Instance.new("TextLabel", Sidebar)
LogoVer.Size = UDim2.new(0, 110, 0, 14)
LogoVer.Position = UDim2.new(0, 65, 0, 36)
LogoVer.BackgroundTransparency = 1
LogoVer.Text = "v4.0 • " .. GAME
LogoVer.TextColor3 = C.Accent2
LogoVer.Font = Enum.Font.Gotham
LogoVer.TextSize = 10
LogoVer.TextXAlignment = Enum.TextXAlignment.Left

local sbDiv = Instance.new("Frame", Sidebar)
sbDiv.Size = UDim2.new(1, -30, 0, 1)
sbDiv.Position = UDim2.new(0, 15, 0, 78)
sbDiv.BackgroundColor3 = C.Border
sbDiv.BorderSizePixel = 0

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, -180, 0, 55)
Header.Position = UDim2.new(0, 180, 0, 0)
Header.BackgroundColor3 = C.BG
Header.BorderSizePixel = 0

local HTitle = Instance.new("TextLabel", Header)
HTitle.Size = UDim2.new(0.4, 0, 1, 0)
HTitle.Position = UDim2.new(0, 20, 0, 0)
HTitle.BackgroundTransparency = 1
HTitle.Text = "Aimbot"
HTitle.TextColor3 = C.Text
HTitle.Font = Enum.Font.GothamBold
HTitle.TextSize = 18
HTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Game indicator
local GameBox = Instance.new("Frame", Header)
GameBox.Size = UDim2.new(0, 90, 0, 26)
GameBox.Position = UDim2.new(1, -350, 0.5, -13)
GameBox.BackgroundColor3 = C.Card
GameBox.BorderSizePixel = 0
Instance.new("UICorner", GameBox).CornerRadius = UDim.new(0, 6)
local GameLbl = Instance.new("TextLabel", GameBox)
GameLbl.Size = UDim2.new(1, 0, 1, 0)
GameLbl.BackgroundTransparency = 1
GameLbl.Text = "🎮 " .. GAME
GameLbl.TextColor3 = C.Accent
GameLbl.Font = Enum.Font.GothamBold
GameLbl.TextSize = 10

local StatFPS = Instance.new("Frame", Header)
StatFPS.Size = UDim2.new(0, 75, 0, 26)
StatFPS.Position = UDim2.new(1, -255, 0.5, -13)
StatFPS.BackgroundColor3 = C.Card
StatFPS.BorderSizePixel = 0
Instance.new("UICorner", StatFPS).CornerRadius = UDim.new(0, 6)
local FPSLbl = Instance.new("TextLabel", StatFPS)
FPSLbl.Size = UDim2.new(1, 0, 1, 0)
FPSLbl.BackgroundTransparency = 1
FPSLbl.Text = "FPS 60"
FPSLbl.TextColor3 = C.Green
FPSLbl.Font = Enum.Font.GothamBold
FPSLbl.TextSize = 11

local StatPing = Instance.new("Frame", Header)
StatPing.Size = UDim2.new(0, 75, 0, 26)
StatPing.Position = UDim2.new(1, -175, 0.5, -13)
StatPing.BackgroundColor3 = C.Card
StatPing.BorderSizePixel = 0
Instance.new("UICorner", StatPing).CornerRadius = UDim.new(0, 6)
local PingLbl = Instance.new("TextLabel", StatPing)
PingLbl.Size = UDim2.new(1, 0, 1, 0)
PingLbl.BackgroundTransparency = 1
PingLbl.Text = "PING 0"
PingLbl.TextColor3 = C.Yellow
PingLbl.Font = Enum.Font.GothamBold
PingLbl.TextSize = 11

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -50, 0.5, -16)
CloseBtn.BackgroundColor3 = C.Card
CloseBtn.Text = "×"
CloseBtn.TextColor3 = C.Red
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 20
CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 7)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = false
    Notify("Menu", "INSERT to show", 2)
end)

local ContentArea = Instance.new("Frame", Main)
ContentArea.Size = UDim2.new(1, -180, 1, -55)
ContentArea.Position = UDim2.new(0, 180, 0, 55)
ContentArea.BackgroundColor3 = C.BG
ContentArea.BorderSizePixel = 0
ContentArea.ClipsDescendants = true

local Tabs = {
    {name="Aimbot",  icon="◎"},
    {name="Visuals", icon="◈"},
    {name="Player",  icon="●"},
    {name="Settings",icon="⚙"},
}

local TabButtons = {}
local TabPages = {}
local CurrentTab = "Aimbot"

for _, tab in ipairs(Tabs) do
    local page = Instance.new("ScrollingFrame", ContentArea)
    page.Name = tab.name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Position = UDim2.new(0, 0, 0, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = C.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = (tab.name == CurrentTab)
    TabPages[tab.name] = page
    local pad = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0, 15); pad.PaddingLeft = UDim.new(0, 15)
    pad.PaddingRight = UDim.new(0, 15); pad.PaddingBottom = UDim.new(0, 15)
end

for i, tab in ipairs(Tabs) do
    local btn = Instance.new("TextButton", Sidebar)
    btn.Name = tab.name .. "Btn"
    btn.Size = UDim2.new(1, -20, 0, 38)
    btn.Position = UDim2.new(0, 10, 0, 90 + (i-1) * 44)
    btn.BackgroundColor3 = tab.name == CurrentTab and C.Card or C.BG2
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    TabButtons[tab.name] = btn
    local indicator = Instance.new("Frame", btn)
    indicator.Name = "Indicator"
    indicator.Size = UDim2.new(0, 3, 0.6, 0)
    indicator.Position = UDim2.new(0, 0, 0.2, 0)
    indicator.BackgroundColor3 = C.Accent
    indicator.BorderSizePixel = 0
    indicator.Visible = tab.name == CurrentTab
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
    local icon = Instance.new("TextLabel", btn)
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 30, 1, 0)
    icon.Position = UDim2.new(0, 12, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = tab.icon
    icon.TextColor3 = tab.name == CurrentTab and C.Accent or C.TextDim
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 16
    local lbl = Instance.new("TextLabel", btn)
    lbl.Name = "Lbl"
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 45, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = tab.name
    lbl.TextColor3 = tab.name == CurrentTab and C.Text or C.TextDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    btn.MouseButton1Click:Connect(function()
        CurrentTab = tab.name
        HTitle.Text = tab.name
        for n, p in pairs(TabPages) do p.Visible = (n == tab.name) end
        for n, b in pairs(TabButtons) do
            local active = (n == tab.name)
            local bIcon = b:FindFirstChild("Icon")
            local bLbl = b:FindFirstChild("Lbl")
            local bInd = b:FindFirstChild("Indicator")
            TS:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = active and C.Card or C.BG2}):Play()
            if bLbl then TS:Create(bLbl, TweenInfo.new(0.2), {TextColor3 = active and C.Text or C.TextDim}):Play() end
            if bIcon then TS:Create(bIcon, TweenInfo.new(0.2), {TextColor3 = active and C.Accent or C.TextDim}):Play() end
            if bInd then bInd.Visible = active end
        end
    end)
    btn.MouseEnter:Connect(function()
        if CurrentTab ~= tab.name then
            TS:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.Card}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if CurrentTab ~= tab.name then
            TS:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.BG2}):Play()
        end
    end)
end

local function CreateSection(parent, title)
    local wrap = Instance.new("Frame", parent)
    wrap.Size = UDim2.new(1, 0, 0, 40)
    wrap.BackgroundColor3 = C.BG2
    wrap.BorderSizePixel = 0
    wrap.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, 8)
    local ws = Instance.new("UIStroke", wrap); ws.Color = C.Border
    local accentBar = Instance.new("Frame", wrap)
    accentBar.Size = UDim2.new(0, 3, 0, 20)
    accentBar.Position = UDim2.new(0, 10, 0, 7)
    accentBar.BackgroundColor3 = C.Accent
    accentBar.BorderSizePixel = 0
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)
    local titleLbl = Instance.new("TextLabel", wrap)
    titleLbl.Size = UDim2.new(1, -30, 0, 34)
    titleLbl.Position = UDim2.new(0, 20, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = C.Text
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    local content = Instance.new("Frame", wrap)
    content.Size = UDim2.new(1, 0, 0, 0)
    content.Position = UDim2.new(0, 0, 0, 34)
    content.BackgroundTransparency = 1
    content.AutomaticSize = Enum.AutomaticSize.Y
    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 3)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", content)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    return content
end

local function Toggle(parent, label, key, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 30); f.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(0.7, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = C.Text
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local sw = Instance.new("Frame", f)
    sw.Size = UDim2.new(0, 34, 0, 18); sw.Position = UDim2.new(1, -38, 0.5, -9)
    sw.BackgroundColor3 = CFG[key] and C.Accent or C.Off; sw.BorderSizePixel = 0
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", sw)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = CFG[key] and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
    knob.BackgroundColor3 = Color3.new(1,1,1); knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.AutoButtonColor = false
    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        TS:Create(sw, TweenInfo.new(0.2), {BackgroundColor3 = CFG[key] and C.Accent or C.Off}):Play()
        TS:Create(knob, TweenInfo.new(0.2), {Position = CFG[key] and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
        if cb then cb(CFG[key]) end
    end)
end

local function Slider(parent, label, key, mn, mx, dec, cb)
    dec = dec or 0
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 44); f.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(0.6, 0, 0, 18); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = C.Text
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local val = Instance.new("TextLabel", f)
    val.Size = UDim2.new(0.4, 0, 0, 18); val.Position = UDim2.new(0.6, 0, 0, 0)
    val.BackgroundTransparency = 1; val.TextColor3 = C.Accent
    val.Font = Enum.Font.GothamBold; val.TextSize = 11
    val.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("Frame", f)
    track.Size = UDim2.new(1, 0, 0, 6); track.Position = UDim2.new(0, 0, 0, 24)
    track.BackgroundColor3 = C.Off; track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = C.Accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 14, 0, 14); thumb.BackgroundColor3 = Color3.new(1,1,1)
    thumb.BorderSizePixel = 0; thumb.ZIndex = 5
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    local function Update()
        local p = math.clamp((CFG[key]-mn)/(mx-mn), 0, 1)
        fill.Size = UDim2.new(p, 0, 1, 0)
        thumb.Position = UDim2.new(p, -7, 0.5, -7)
        val.Text = dec > 0 and string.format("%."..dec.."f", CFG[key]) or tostring(math.floor(CFG[key]))
    end
    Update()
    local drag = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local p = math.clamp((i.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
            local raw = mn + (mx-mn) * p
            CFG[key] = dec > 0 and math.floor(raw*10^dec+0.5)/10^dec or math.floor(raw+0.5)
            Update()
            if cb then cb(CFG[key]) end
        end
    end)
end

local function Dropdown(parent, label, options, key, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 30); f.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(0.4, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = C.Text
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local sel = Instance.new("TextButton", f)
    sel.Size = UDim2.new(0.55, 0, 0, 24); sel.Position = UDim2.new(0.45, 0, 0.5, -12)
    sel.BackgroundColor3 = C.Off; sel.TextColor3 = C.Text
    sel.Font = Enum.Font.GothamBold; sel.TextSize = 10
    sel.Text = tostring(CFG[key]) .. "  ▼"
    sel.BorderSizePixel = 0; sel.AutoButtonColor = false
    Instance.new("UICorner", sel).CornerRadius = UDim.new(0, 6)
    local dropFrame = Instance.new("Frame", ScreenGui)
    dropFrame.Size = UDim2.new(0, 150, 0, #options * 26 + 4)
    dropFrame.BackgroundColor3 = C.BG3
    dropFrame.BorderSizePixel = 0; dropFrame.Visible = false; dropFrame.ZIndex = 100
    Instance.new("UICorner", dropFrame).CornerRadius = UDim.new(0, 6)
    local ds = Instance.new("UIStroke", dropFrame); ds.Color = C.Accent
    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton", dropFrame)
        ob.Size = UDim2.new(1, -4, 0, 24); ob.Position = UDim2.new(0, 2, 0, (i-1)*26 + 2)
        ob.BackgroundColor3 = C.BG3; ob.Text = opt; ob.TextColor3 = C.Text
        ob.Font = Enum.Font.Gotham; ob.TextSize = 11
        ob.BorderSizePixel = 0; ob.ZIndex = 101; ob.AutoButtonColor = false
        Instance.new("UICorner", ob).CornerRadius = UDim.new(0, 4)
        ob.MouseEnter:Connect(function() TS:Create(ob, TweenInfo.new(0.1), {BackgroundColor3 = C.Accent}):Play() end)
        ob.MouseLeave:Connect(function() TS:Create(ob, TweenInfo.new(0.1), {BackgroundColor3 = C.BG3}):Play() end)
        ob.MouseButton1Click:Connect(function()
            CFG[key] = opt; sel.Text = opt .. "  ▼"; dropFrame.Visible = false
            if cb then cb(opt) end
        end)
    end
    sel.MouseButton1Click:Connect(function()
        if dropFrame.Visible then dropFrame.Visible = false
        else
            local pos = sel.AbsolutePosition; local sz = sel.AbsoluteSize
            dropFrame.Position = UDim2.new(0, pos.X, 0, pos.Y + sz.Y + 4)
            dropFrame.Size = UDim2.new(0, sz.X, 0, #options * 26 + 4)
            dropFrame.Visible = true
        end
    end)
end

local function Button(parent, label, cb, color)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = color or C.Off
    btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 11
    btn.Text = label; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseEnter:Connect(function() TS:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.Accent}):Play() end)
    btn.MouseLeave:Connect(function() TS:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = color or C.Off}):Play() end)
    btn.MouseButton1Click:Connect(cb)
end

local function ColorSwatch(parent, label, key)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 30); f.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(0.6, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = C.Text
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local sw = Instance.new("TextButton", f)
    sw.Size = UDim2.new(0, 40, 0, 20); sw.Position = UDim2.new(1, -44, 0.5, -10)
    sw.BackgroundColor3 = CFG[key]; sw.Text = ""; sw.BorderSizePixel = 0; sw.AutoButtonColor = false
    Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", sw).Color = C.Border
    local colors = {
        Color3.fromRGB(255,50,100), Color3.fromRGB(255,150,0),
        Color3.fromRGB(255,255,0), Color3.fromRGB(0,255,100),
        Color3.fromRGB(0,200,255), Color3.fromRGB(140,100,255),
        Color3.fromRGB(255,100,255), Color3.fromRGB(255,255,255),
    }
    sw.MouseButton1Click:Connect(function()
        local idx = 1
        for i, c in ipairs(colors) do
            if c == CFG[key] then idx = i + 1; break end
        end
        if idx > #colors then idx = 1 end
        CFG[key] = colors[idx]; sw.BackgroundColor3 = colors[idx]
    end)
end

local function Label(parent, text, color)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 18); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = color or C.TextDim
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

-- ========== AIMBOT ==========
do
    local page = TabPages["Aimbot"]
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 10); layout.SortOrder = Enum.SortOrder.LayoutOrder

    local s1 = CreateSection(page, "SILENT AIM")
    Toggle(s1, "Enable Silent Aim", "SilentAim")
    Toggle(s1, "Resolver", "Resolver")
    Toggle(s1, "Auto Prediction", "AutoPrediction")
    Toggle(s1, "Visible Only", "SilentAimVisibleOnly")
    Slider(s1, "FOV", "SilentAimFOV", 30, 500)
    Slider(s1, "Prediction", "SilentAimPrediction", 0.05, 0.3, 3)
    Slider(s1, "Bullet Speed", "BulletSpeed", 500, 3000)
    Dropdown(s1, "Hit Part", {"Head","HumanoidRootPart","UpperTorso","Torso"}, "SilentAimPart")
    Dropdown(s1, "Priority", {"FOV","Distance"}, "TargetPriority")

    local s2 = CreateSection(page, "FILTERS")
    Toggle(s2, "Team Check", "SilentAimTeamCheck")
    Toggle(s2, "Ignore Downed", "SilentAimNoDowned")

    local s3 = CreateSection(page, "TRIGGER BOT")
    Toggle(s3, "Enable Trigger Bot", "TriggerBot")
    Slider(s3, "Delay (ms)", "TriggerDelay", 10, 500)

    -- Пресеты зависят от игры
    local s4 = CreateSection(page, "WEAPON PRESETS ("..GAME..")")
    if isDaHood then
        Button(s4, "🔫 Pistol", function()
            CFG.SilentAimPrediction=0.145; CFG.BulletSpeed=1500
            Notify("Preset","Da Hood Pistol",2)
        end)
        Button(s4, "⚡ AR / SMG", function()
            CFG.SilentAimPrediction=0.15; CFG.BulletSpeed=1300
            Notify("Preset","Da Hood AR",2)
        end)
        Button(s4, "🎯 Sniper", function()
            CFG.SilentAimPrediction=0.17; CFG.BulletSpeed=1000
            Notify("Preset","Da Hood Sniper",2)
        end)
        Button(s4, "💥 Shotgun", function()
            CFG.SilentAimPrediction=0.13; CFG.BulletSpeed=800
            Notify("Preset","Da Hood Shotgun",2)
        end)
    else
        -- Boom Hood presets (другие тайминги)
        Button(s4, "🔫 Pistol (BH)", function()
            CFG.SilentAimPrediction=0.13; CFG.BulletSpeed=1500
            Notify("Preset","Boom Hood Pistol",2)
        end)
        Button(s4, "⚡ AR / SMG (BH)", function()
            CFG.SilentAimPrediction=0.138; CFG.BulletSpeed=1300
            Notify("Preset","Boom Hood AR",2)
        end)
        Button(s4, "🎯 Sniper (BH)", function()
            CFG.SilentAimPrediction=0.155; CFG.BulletSpeed=1000
            Notify("Preset","Boom Hood Sniper",2)
        end)
        Button(s4, "💥 Shotgun (BH)", function()
            CFG.SilentAimPrediction=0.125; CFG.BulletSpeed=800
            Notify("Preset","Boom Hood Shotgun",2)
        end)
    end

    local s5 = CreateSection(page, "CROSSHAIR")
    Toggle(s5, "Custom Crosshair", "Crosshair")
    Toggle(s5, "Center Dot", "CrosshairDot")
    Slider(s5, "Size", "CrosshairSize", 2, 30)
    Slider(s5, "Gap", "CrosshairGap", 0, 15)
    ColorSwatch(s5, "Color", "CrosshairColor")
end

-- ========== VISUALS ==========
do
    local page = TabPages["Visuals"]
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 10); layout.SortOrder = Enum.SortOrder.LayoutOrder
    local s1 = CreateSection(page, "ESP MAIN")
    Toggle(s1, "Enable ESP", "ESP")
    Toggle(s1, "Boxes", "ESPBoxes")
    Toggle(s1, "Names", "ESPNames")
    Toggle(s1, "Health", "ESPHealth")
    Toggle(s1, "Distance", "ESPDistance")
    Toggle(s1, "Weapon", "ESPWeapon")
    Toggle(s1, "Head Dot", "ESPHeadDot")
    Slider(s1, "Max Distance", "ESPMaxDist", 100, 5000)
    local s2 = CreateSection(page, "TRACERS")
    Toggle(s2, "Enable Tracers", "ESPTracers")
    Dropdown(s2, "Origin", {"Bottom","Middle","Top"}, "ESPTracerFrom")
    local s3 = CreateSection(page, "FOV CIRCLE")
    Toggle(s3, "Show FOV Circle", "ShowFOV")
    Toggle(s3, "Show Prediction Dot", "ShowFOVDot")
    Toggle(s3, "Rainbow", "FOVRainbow")
    Slider(s3, "Thickness", "FOVThickness", 1, 5)
    ColorSwatch(s3, "Color", "FOVColor")
end

-- ========== PLAYER ==========
do
    local page = TabPages["Player"]
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 10); layout.SortOrder = Enum.SortOrder.LayoutOrder
    local s1 = CreateSection(page, "YOUR STATS")
    local infoBox = Instance.new("Frame", s1)
    infoBox.Size = UDim2.new(1, 0, 0, 100); infoBox.BackgroundColor3 = C.BG3
    infoBox.BorderSizePixel = 0
    Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 6)
    local infoLbl = Instance.new("TextLabel", infoBox)
    infoLbl.Size = UDim2.new(1, -20, 1, -10); infoLbl.Position = UDim2.new(0, 10, 0, 5)
    infoLbl.BackgroundTransparency = 1; infoLbl.TextColor3 = C.Text
    infoLbl.Font = Enum.Font.Gotham; infoLbl.TextSize = 11
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left; infoLbl.TextYAlignment = Enum.TextYAlignment.Top
    infoLbl.Text = "..."
    task.spawn(function()
        while ScreenGui.Parent do
            pcall(function()
                infoLbl.Text = string.format(
                    "Game: %s\nName: %s\nHealth: %d/%d\nPing: %dms\nFPS: %d",
                    GAME, LP.Name, GetHP(GetChar()), GetMaxHP(GetChar()), GetPing(), FPS
                )
            end)
            task.wait(0.5)
        end
    end)
    local s2 = CreateSection(page, "TARGET INFO")
    local tBox = Instance.new("Frame", s2)
    tBox.Size = UDim2.new(1, 0, 0, 100); tBox.BackgroundColor3 = C.BG3
    tBox.BorderSizePixel = 0
    Instance.new("UICorner", tBox).CornerRadius = UDim.new(0, 6)
    local tLbl = Instance.new("TextLabel", tBox)
    tLbl.Size = UDim2.new(1, -20, 1, -10); tLbl.Position = UDim2.new(0, 10, 0, 5)
    tLbl.BackgroundTransparency = 1; tLbl.TextColor3 = C.TextDim
    tLbl.Font = Enum.Font.Gotham; tLbl.TextSize = 11
    tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.TextYAlignment = Enum.TextYAlignment.Top
    tLbl.Text = "No target"
    task.spawn(function()
        while ScreenGui.Parent do
            pcall(function()
                if Target and Target.Character then
                    local myPos = GetPos()
                    local root = Target.Character:FindFirstChild("HumanoidRootPart")
                    local dist = myPos and root and (myPos-root.Position).Magnitude or 0
                    tLbl.Text = string.format(
                        "Target: %s\nHealth: %d\nDistance: %dm\nWeapon: %s",
                        Target.Name, GetHP(Target.Character), math.floor(dist), GetWeapon(Target)
                    )
                    tLbl.TextColor3 = C.Green
                else
                    tLbl.Text = "No target selected"; tLbl.TextColor3 = C.TextDim
                end
            end)
            task.wait(0.3)
        end
    end)
    local s3 = CreateSection(page, "PLAYER LIST")
    local list = Instance.new("ScrollingFrame", s3)
    list.Size = UDim2.new(1, 0, 0, 200); list.BackgroundColor3 = C.BG3
    list.BorderSizePixel = 0; list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = C.Accent
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", list).CornerRadius = UDim.new(0, 6)
    local ll = Instance.new("UIListLayout", list); ll.Padding = UDim.new(0, 2)
    local lp = Instance.new("UIPadding", list)
    lp.PaddingTop = UDim.new(0,4); lp.PaddingLeft = UDim.new(0,4); lp.PaddingRight = UDim.new(0,4)
    local function Refresh()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local row = Instance.new("Frame", list)
                row.Size = UDim2.new(1, -8, 0, 26); row.BackgroundColor3 = C.Card
                row.BorderSizePixel = 0
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
                local nl = Instance.new("TextLabel", row)
                nl.Size = UDim2.new(0.65, 0, 1, 0); nl.Position = UDim2.new(0, 8, 0, 0)
                nl.BackgroundTransparency = 1; nl.Text = plr.Name; nl.TextColor3 = C.Text
                nl.Font = Enum.Font.Gotham; nl.TextSize = 10; nl.TextXAlignment = Enum.TextXAlignment.Left
                local hpl = Instance.new("TextLabel", row)
                hpl.Size = UDim2.new(0.35, -8, 1, 0); hpl.Position = UDim2.new(0.65, 0, 0, 0)
                hpl.BackgroundTransparency = 1
                hpl.Text = plr.Character and GetHP(plr.Character).."hp" or "-"
                hpl.TextColor3 = C.Green; hpl.Font = Enum.Font.GothamBold; hpl.TextSize = 10
                hpl.TextXAlignment = Enum.TextXAlignment.Right
            end
        end
    end
    task.spawn(function()
        while ScreenGui.Parent do pcall(Refresh); task.wait(2) end
    end)
    Button(s3, "Refresh List", Refresh)
end

-- ========== SETTINGS ==========
do
    local page = TabPages["Settings"]
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 10); layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local s0 = CreateSection(page, "🎮 GAME INFO")
    Label(s0, "Detected: " .. GAME, C.Accent)
    Label(s0, "Game: " .. GAME_NAME, C.Text)
    Label(s0, "PlaceId: " .. tostring(GAME_ID), C.TextDim)
    Label(s0, "")
    if GAME == "DaHood" then
        Label(s0, "✅ Da Hood config loaded", C.Green)
        Label(s0, "Prediction: 0.165 (default)", C.TextDim)
        Label(s0, "Bullet Speed: 1800", C.TextDim)
    else
        Label(s0, "✅ Boom Hood config loaded", C.Green)
        Label(s0, "Prediction: 0.138 (default)", C.TextDim)
        Label(s0, "Bullet Speed: 1500", C.TextDim)
        Label(s0, "Anti-Kick: enabled", C.Green)
        Label(s0, "Hook Delay: 3-6 sec", C.Yellow)
    end
    
    local s1 = CreateSection(page, "HOTKEYS")
    Label(s1, "INSERT — toggle GUI", C.Text)
    Label(s1, "F2 — toggle Silent Aim", C.Text)
    Label(s1, "F3 — toggle ESP", C.Text)
    Label(s1, "DELETE — unload cheat", C.Red)
    
    local s2 = CreateSection(page, "ABOUT")
    Label(s2, "SAFE HUB v4.0 Universal", C.Accent)
    Label(s2, "Da Hood + Boom Hood Support", C.Green)
    Label(s2, "")
    Label(s2, "SAFE FEATURES:", C.Text)
    Label(s2, "✓ Silent Aim (Raycast hook)", C.Green)
    Label(s2, "✓ Auto Game Detection", C.Green)
    Label(s2, "✓ ESP (Drawing library)", C.Green)
    Label(s2, "✓ Trigger Bot", C.Green)
    Label(s2, "✓ Custom Crosshair", C.Green)
    Label(s2, "✓ Anti-Kick (Boom Hood)", C.Green)
    Label(s2, "")
    Label(s2, "REMOVED (detected):", C.Red)
    Label(s2, "✗ Chams / Highlights", C.TextDim)
    Label(s2, "✗ FullBright / NoFog", C.TextDim)
    
    local s3 = CreateSection(page, "DANGER ZONE")
    Button(s3, "UNLOAD CHEAT", function()
        for _, o in pairs(DrawObjs) do pcall(function() o:Remove() end) end
        for p in pairs(ESPObjects) do KillESP(p) end
        pcall(function() ScreenGui:Destroy() end)
        Notify("Cheat","Unloaded",3)
    end, C.Red)
end

-- ==================== HOTKEYS ====================
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Insert then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
    if inp.KeyCode == Enum.KeyCode.F2 then
        CFG.SilentAim = not CFG.SilentAim
        Notify("Silent Aim", CFG.SilentAim and "ON" or "OFF", 2)
    end
    if inp.KeyCode == Enum.KeyCode.F3 then
        CFG.ESP = not CFG.ESP
        Notify("ESP", CFG.ESP and "ON" or "OFF", 2)
    end
    if inp.KeyCode == Enum.KeyCode.Delete then
        for _, o in pairs(DrawObjs) do pcall(function() o:Remove() end) end
        for p in pairs(ESPObjects) do KillESP(p) end
        pcall(function() ScreenGui:Destroy() end)
        Notify("Cheat","Unloaded",3)
    end
end)

-- ==================== STAT UPDATE ====================
task.spawn(function()
    while ScreenGui.Parent do
        pcall(function()
            FPSLbl.Text = "FPS " .. FPS
            FPSLbl.TextColor3 = FPS>40 and C.Green or FPS>20 and C.Yellow or C.Red
            local ping = GetPing()
            PingLbl.Text = "PING " .. ping
            PingLbl.TextColor3 = ping<100 and C.Green or ping<200 and C.Yellow or C.Red
        end)
        task.wait(0.5)
    end
end)

Notify("SAFE HUB v4.0", "🎮 Загружен для "..GAME.."! INSERT — меню", 5)
print("============================================")
print("  SAFE HUB v4.0 - Universal Edition")
print("  Game: "..GAME.." | " .. GAME_NAME)
print("  INSERT=menu F2=SA F3=ESP DEL=unload")
print("============================================")