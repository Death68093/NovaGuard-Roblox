
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

local config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NG_Config"))

local NG_Pass = ReplicatedStorage:WaitForChild("Ng_Pass_Event")
local NG_Fail = ReplicatedStorage:WaitForChild("Ng_Fail_Event")
local NG_Check = ReplicatedStorage:WaitForChild("Ng_Check_Event")
local NG_Exists = ReplicatedStorage:WaitForChild("NG_Exists_Event")
local NG_Find = ReplicatedStorage:WaitForChild("NG_Find_Event")
local NG_GetVal = ReplicatedStorage:WaitForChild("NG_GetVal_Event")

-- baseline counts (used for CoreGui/PlayerGui checks)
local initialCoreGuiCount = #CoreGui:GetChildren()
local initialPlayerGuiCount = #PlayerGui:GetChildren()

local monitoring = false
local currentToken = nil
local currentConf = nil
local monitorStart = 0
local MONITOR_TIME = 4.5 -- seconds of dynamic monitoring before sending PASS
local falling = false
local lastPos = nil
local lastTime = nil

-- Update refs on respawn
player.CharacterAdded:Connect(function(character)
    char = character
    hum = char:WaitForChild("Humanoid")
    hrp = char:WaitForChild("HumanoidRootPart")
end)

-- checks that don't need heartbeat monitoring
local function runImmediateChecks(token, conf)
    -- Humanoid existence
    if conf.CheckHumanoid then
        if not hum or hum:GetState() == Enum.HumanoidStateType.Dead then
            return "No Humanoid Detected"
        end
    end

    -- Speed
    if conf.CheckSpeed and hum.WalkSpeed > conf.MaxSpeed then
        return "Speed Detected"
    end

    -- Jump
    if conf.CheckJump and (hum.JumpPower > conf.MaxJumpPower or hum.JumpHeight > conf.MaxJumpHeight) then
        return "Jump Detected"
    end

    -- CoreGui / PlayerGui
    if conf.CheckCoreGui then
        if #CoreGui:GetChildren() ~= initialCoreGuiCount then
            return "CoreGui Modified"
        end
    end
    if conf.CheckPlayerGui then
        if #PlayerGui:GetChildren() ~= initialPlayerGuiCount then
            return "PlayerGui Modified"
        end
    end

    -- LocalScript / Backpack check
    if conf.CheckForLocalScript then
        local found = false
        local ok, playerScripts = pcall(function() return player:WaitForChild("PlayerScripts", 2) end)
        if ok and playerScripts then
            for _, obj in ipairs(playerScripts:GetDescendants()) do
                if obj:IsA("LocalScript") and obj.Name == "LocalScript" then
                    found = true
                    break
                end
            end
        end
        if not found then
            local ok2, backpack = pcall(function() return player:WaitForChild("Backpack", 2) end)
            if ok2 and backpack then
                for _, obj in ipairs(backpack:GetDescendants()) do
                    if obj:IsA("LocalScript") then
                        found = true
                        break
                    end
                end
            end
        end
        if found then return "LocalScript Detected" end
    end

    -- Gravity / FOV immediate checks
    if conf.CheckForGravity then
        local serverGravity = conf.UseServerGravity and NG_GetVal:InvokeServer("Gravity") or conf.DefaultGravity
        if Workspace.Gravity < conf.MinGravity or Workspace.Gravity > conf.MaxGravity then
            return "Gravity Modified"
        end
        if conf.UseServerGravity and Workspace.Gravity ~= serverGravity then
            return "Gravity Mismatch"
        end
    end

    if conf.CheckForFOV then
        local cam = Workspace.CurrentCamera
        if cam and (cam.FieldOfView < conf.MinFOV or cam.FieldOfView > conf.MaxFOV) then
            return "Camera FOV Modified"
        end
    end

    return nil -- passed immediate checks
end

-- Start a monitoring session
local function startMonitoring(token, conf)
    -- cancel previous
    monitoring = false
    currentToken = token
    currentConf = conf
    monitorStart = tick()
    falling = false
    lastPos = hrp and hrp.Position or nil
    lastTime = tick()

    -- tell server we have the client files (token-validated)
    pcall(function() NG_Exists:FireServer(token) end)

    monitoring = true
end

-- stop monitoring (used after pass/fail)
local function stopMonitoring()
    monitoring = false
    currentToken = nil
    currentConf = nil
    monitorStart = 0
end

-- Single heartbeat connection for all dynamic checks
RunService.Heartbeat:Connect(function(dt)
    if not monitoring or not currentConf or not currentToken then return end
    local conf = currentConf
    local token = currentToken

    -- Infinite jump detection
    if conf.CheckForInfiniteJump then
        if hum then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.FreeFall then
                falling = true
            elseif state == Enum.HumanoidStateType.Landed then
                falling = false
            elseif falling and state == Enum.HumanoidStateType.Jumping then
                pcall(function() NG_Fail:FireServer(token, "Infinite Jump Detected") end)
                stopMonitoring()
                return
            end
        end
    end

    -- Fly / noclip detection
    if conf.CheckForFly or conf.CheckForNoclip then
        if hrp then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {char}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), raycastParams)
            if not result and hum and hum.FloorMaterial == Enum.Material.Air then
                pcall(function() NG_Fail:FireServer(token, "Fly/NoClip Detected") end)
                stopMonitoring()
                return
            end
        end
    end

    -- Spider / platform detection
    if conf.CheckForSpider and hum and hum:GetState() == Enum.HumanoidStateType.Climbing then
        local valid = false
        local dirs = {Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1)}
        for _, dir in ipairs(dirs) do
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {char}
            rp.FilterType = Enum.RaycastFilterType.Blacklist
            local r = Workspace:Raycast(hrp.Position, dir * 2, rp)
            if r and r.Instance and r.Instance:IsA("TrussPart") then
                valid = true
                break
            end
        end
        if not valid then
            pcall(function() NG_Find:FireServer(token, "Spider", nil) end)
            stopMonitoring()
            return
        end
    end

    if conf.CheckForPlatform and hrp and hum and hum.FloorMaterial == Enum.Material.Air then
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {char}
        rp.FilterType = Enum.RaycastFilterType.Blacklist
        local r = Workspace:Raycast(hrp.Position, Vector3.new(0,-5,0), rp)
        if r and r.Instance then
            pcall(function() NG_Find:FireServer(token, "Platform", r.Instance) end)
            stopMonitoring()
            return
        end
    end

    -- Teleport / speed-over-distance check
    if conf.CheckForTP and hrp and lastPos then
        local now = tick()
        local delta = (hrp.Position - lastPos).Magnitude
        local timePassed = now - lastTime
        if timePassed > 0 and (delta / timePassed) > conf.MaxSpeed then
            pcall(function() NG_Fail:FireServer(token, "Teleport Detected") end)
            stopMonitoring()
            return
        end
        lastPos = hrp.Position
        lastTime = now
    end

    -- If we've monitored long enough, send PASS
    if tick() - monitorStart >= MONITOR_TIME then
        pcall(function() NG_Pass:FireServer(token) end)
        stopMonitoring()
        return
    end
end)

-- Handle incoming check tokens
NG_Check.OnClientEvent:Connect(function(token, conf)
    if not token or not conf then return end
    -- run immediate checks
    local failReason = runImmediateChecks(token, conf)
    if failReason then
        pcall(function() NG_Fail:FireServer(token, failReason) end)
        return
    end

    -- start monitoring, then the heartbeat will send PASS/FAIL
    startMonitoring(token, conf)
end)
