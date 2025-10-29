--// GODLOCK v20 - OPTIMIZED

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// SETTINGS
local Settings = {
    Aimbot = false,
    FullAuto = false,
    NoRecoil = false,
    WallCheck = false,
    ESP = false,  
    FOV = 200,
    Range = 500,
    ESPRange = math.huge,  
    LockPart = "Head",
    TeamCheckAimbot = true,  
    ESPTeamCheck = true,  
    AimYOffset = 0,
}

--// STATE
local targetPart = nil
local currentTool = nil
local fireRemotes = {}
local noRecoilConn = nil
local fullAutoConn = nil
local isHolding = false

--// UTILITIES
local function getLockPart(char)
    return char:FindFirstChild(Settings.LockPart) or char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
end

local function isEnemyAimbot(plr)  
    if not Settings.TeamCheckAimbot then return true end
    if not LocalPlayer.Team or not plr.Team then return true end
    return LocalPlayer.Team ~= plr.Team
end

local function isEnemyESP(plr)  
    if not Settings.ESPTeamCheck then return true end
    if not LocalPlayer.Team or not plr.Team then return true end
    return LocalPlayer.Team ~= plr.Team
end

-- Optimized visibility check with caching
local visCache = {}
local function isVisible(part)
    if not Settings.WallCheck then return true end
    local now = tick()
    if visCache[part] and now - visCache[part].ts < 0.3 then
        return visCache[part].visible
    end
    local ok, result = pcall(function()
        local origin = Camera.CFrame.Position
        local dir = (part.Position - origin).Unit * 500
        local ray = Ray.new(origin, dir)
        local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character or {}})
        return hit and hit:IsDescendantOf(part.Parent)
    end)
    visCache[part] = {visible = ok and result or false, ts = now}
    return ok and result or false
end

local function getTarget()
    local closest = nil
    local shortest = math.huge
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            if isEnemyAimbot(plr) then
                local part = getLockPart(plr.Character)
                if part and (not Settings.WallCheck or isVisible(part)) then
                    local pos, onScreen = pcall(function()
                        return Camera:WorldToViewportPoint(part.Position)
                    end)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist <= Settings.FOV and dist < shortest then
                            shortest = dist
                            closest = part
                        end
                    end
                end
            end
        end
    end
    return closest
end

--// TOOL & REMOTES
local function updateTool()
    currentTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
end

local function scanRemotes()
    fireRemotes = {}
    local names = {"fire", "shoot", "gun", "bullet", "damage", "hit", "f", "comm"}
    local function scan(obj)
        if not obj then return end
        for _, v in pairs(obj:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                for _, n in pairs(names) do
                    if v.Name:lower():find(n) then
                        table.insert(fireRemotes, v)
                        break
                    end
                end
            end
        end
    end
    pcall(scan, game.ReplicatedStorage)
    pcall(scan, LocalPlayer.PlayerGui)
    if LocalPlayer.Character then pcall(scan, LocalPlayer.Character) end
end

--// NO RECOIL
local function toggleRecoil(on)
    if on and not noRecoilConn then
        noRecoilConn = RunService.Heartbeat:Connect(function()
            if Camera.FieldOfView < 70 then Camera.FieldOfView = 70 end
        end)
    elseif not on and noRecoilConn then
        noRecoilConn:Disconnect()
        noRecoilConn = nil
    end
end

--// ESP
local ESP = {}
local function makeESP(plr)
    if ESP[plr] then return end
    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Filled = false
    box.Color = Color3.fromRGB(255,0,0)
    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Color = Color3.fromRGB(255,0,0)
    ESP[plr] = {box=box, line=line}
end
for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer then makeESP(p) end end
Players.PlayerAdded:Connect(makeESP)
Players.PlayerRemoving:Connect(function(p)
    if ESP[p] then ESP[p].box:Remove(); ESP[p].line:Remove(); ESP[p]=nil end
end)

--// MAIN LOOP OPTIMIZED
RunService.RenderStepped:Connect(function()
    updateTool()
    targetPart = getTarget()
    
    -- Smooth Aimbot
    if Settings.Aimbot and targetPart then
        local ok,pos = pcall(function() return targetPart.Position + Vector3.new(0, Settings.AimYOffset, 0) end)
        if ok then
            local cf = Camera.CFrame
            Camera.CFrame = cf:Lerp(CFrame.lookAt(cf.Position,pos),0.95)
        end
    end

    -- FOV Circle
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 2
        fovCircle.Color = Color3.fromRGB(200,20,20)
        fovCircle.Filled = false
    end
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Radius = Settings.FOV
    fovCircle.Visible = Settings.Aimbot

    -- ESP
    for plr, esp in pairs(ESP) do
        if plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            if isEnemyESP(plr) then
                local root = getLockPart(plr.Character)
                if root then
                    local dist = (Camera.CFrame.Position - root.Position).Magnitude
                    if dist <= Settings.ESPRange then
                        local ok, rootPos, on = pcall(function() return Camera:WorldToViewportPoint(root.Position) end)
                        if ok and on then
                            local head = plr.Character:FindFirstChild("Head")
                            local headPos = head and Camera:WorldToViewportPoint(head.Position) or rootPos
                            local h = math.abs(rootPos.Y - headPos.Y)
                            local w = h/2
                            esp.box.Visible=true
                            esp.box.Size=Vector2.new(w,h)
                            esp.box.Position=Vector2.new(rootPos.X-w/2, math.min(rootPos.Y,headPos.Y))
                            esp.line.Visible=true
                            esp.line.From=Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                            esp.line.To=Vector2.new(rootPos.X, rootPos.Y)
                        else esp.box.Visible=false; esp.line.Visible=false end
                    else esp.box.Visible=false; esp.line.Visible=false end
                end
            else esp.box.Visible=false; esp.line.Visible=false end
        else esp.box.Visible=false; esp.line.Visible=false end
    end
end)

--// FULL AUTO
UserInputService.InputBegan:Connect(function(input)
    if Settings.FullAuto and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
        isHolding=true
        if fullAutoConn then fullAutoConn:Disconnect() end
        fullAutoConn = RunService.Heartbeat:Connect(function()
            if isHolding and targetPart and currentTool then
                currentTool:Activate()
                for _,r in pairs(fireRemotes) do
                    pcall(function() r:FireServer((targetPart.Position-Camera.CFrame.Position).Unit,targetPart) end)
                end
            end
        end)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        isHolding=false
    end
end)

--// INIT
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    updateTool()
    scanRemotes()
end)

updateTool()
scanRemotes()

print("GODLOCK v20 LOADED - FULL OPTIMIZED SAFE")
