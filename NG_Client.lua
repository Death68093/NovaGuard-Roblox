local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local config = require(ReplicatedStorage:WaitForChild("NG_Config"))


local NG_Pass = ReplicatedStorage:WaitForChild("Ng_Pass_Event")
local NG_Fail = ReplicatedStorage:WaitForChild("Ng_Fail_Event") 
local NG_Check = ReplicatedStorage:WaitForChild("Ng_Check_Event")
local NG_Exists = ReplicatedStorage:WaitForChild("NG_Exists_Event")
local NG_Find = ReplicatedStorage:WaitForChild("NG_Find_Event")
local NG_GetVal = ReplicatedStorage:WaitForChild("NG_GetVal_Event")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Watermark
local function showImage(assetId)
    if PlayerGui:FindFirstChild("AntiCheatImage") then
        PlayerGui.AntiCheatImage:Destroy()
    end

    local image = Instance.new("ImageLabel")
    image.Name = "AntiCheatImage"
    image.Parent = PlayerGui
    image.Size = UDim2.new(0, 150, 0, 150)  -- width/height in pixels
    image.Position = UDim2.new(0, 10, 1, -160) -- bottom-left corner
    image.AnchorPoint = Vector2.new(0, 0) -- position relative to top-left of UI
    image.BackgroundTransparency = 1
    image.Image = "rbxassetid://" .. tostring(assetId)
    image.ZIndex = 10
end
showImage(120126554390458)

local ItemsInCoreGui = #CoreGui:GetChildren()
local ItemsInPlayerGui = #PlayerGui:GetChildren()
local lastPosition = nil
local jumpCount = 0
local lastCheck = tick()

NG_Check.OnClientInvoke = function(config)
    NG_Exists:FireServer(player)

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local reason = ""

    -- Humanoid exists
    if config.CheckHumanoid then
        if not humanoid then
            task.wait(5)
            character = player.Character or player.CharacterAdded:Wait()
            humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                reason = "No Humanoid Detected"
                NG_Fail:FireServer(player, reason)
                return "FAIL"
            end
        elseif humanoid:GetState() == Enum.HumanoidStateType.Dead then
            reason = "No Humanoid Detected"
            NG_Fail:FireServer(player, reason)
            return "FAIL"
        end
    end

    -- Speed check
    if config.CheckSpeed then
        if humanoid.WalkSpeed > config.MaxSpeed then
            reason = "Speed Detected"
            NG_Fail:FireServer(player, reason)
            return "FAIL"
        end
    end

    -- Jump check
    if config.CheckJump then
        if humanoid.JumpPower > config.MaxJumpPower or humanoid.JumpHeight > config.MaxJumpHeight then
            reason = "Jump Detected"
            NG_Fail:FireServer(player, reason)
            return "FAIL"
        end
    end

    -- CoreGui check
    if config.CheckCoreGui then
        local items = #CoreGui:GetChildren()
        if items ~= ItemsInCoreGui then
            reason = "CoreGui Modified"
            NG_Fail:FireServer(player, reason)
            return "FAIL"
        end
    end

    -- PlayerGui check
    if config.CheckPlayerGui then
        local items = #PlayerGui:GetChildren()
        if items ~= ItemsInPlayerGui then
            reason = "PlayerGui Modified"
            NG_Fail:FireServer(player, reason)
            return "FAIL"
        end
    end

    -- LocalScript / Backpack check
    if config.CheckForLocalScript then
        local found = false
        local playerScripts = player:WaitForChild("PlayerScripts")
        for _, obj in ipairs(playerScripts:GetDescendants()) do
            if obj:IsA("LocalScript") and obj.Name == "LocalScript" then
                found = true
                break
            end
        end
        if not found then
            local backpack = player:WaitForChild("Backpack")
            for _, obj in ipairs(backpack:GetDescendants()) do
                if obj:IsA("LocalScript") and obj.Name == "LocalScript" then
                    found = true
                    break
                end
            end
        end
        if found then
            NG_Fail:FireServer(player, "LocalScript Detected")
            return "FAIL"
        end
    end

    -- Teleport / position check
    if config.CheckForTP then
        if lastPosition and hrp then
            local delta = (hrp.Position - lastPosition).Magnitude
            local timePassed = tick() - lastCheck
            if delta / timePassed > config.MaxSpeed then
                NG_Fail:FireServer(player, "Teleport Detected")
                return "FAIL"
            end
        end
    end

    -- Fly / noclip detection
    if config.CheckForFly then
        if hrp then
            local ray = Ray.new(hrp.Position, Vector3.new(0, -5, 0))
            local hit = workspace:FindPartOnRayWithIgnoreList(ray, {character})
            if not hit and humanoid.FloorMaterial == Enum.Material.Air then
                NG_Fail:FireServer(player, "Fly/NoClip Detected")
                return "FAIL"
            end
        end
        if humanoid:GetState() == Enum.HumanoidStateType.Flying then
            NG_Fail:FireServer(player, "Fly Detected")
            return "FAIL"
        end
    end


    -- Gravity / camera FOV checks
    if config.CheckForGravity then
        if config.UseServerGravity then
            local serverGravity = NG_GetVal:InvokeServer("Gravity")
            if workspace.Gravity ~= serverGravity then
                NG_Fail:FireServer(player, "Gravity Modified")
                return "FAIL"
            end
        elseif workspace.Gravity ~= config.DefaultGravity then
            NG_Fail:FireServer(player, "Gravity Modified")
            return "FAIL"
        end
    end

    -- Check for FOV changes
    if config.CheckForFOV then
        local cam = workspace.CurrentCamera
        if cam and (cam.FieldOfView < config.MinFOV or cam.FieldOfView > config.MaxFOV) then
            NG_Fail:FireServer(player, "Camera FOV Modified")
            return "FAIL"
        end
    end

    -- Passed all checks
    lastPosition = hrp and hrp.Position or lastPosition
    lastCheck = tick()
    NG_Pass:FireServer(player)
    return "PASS"
end


-- Infinite Jump
    if config.CheckForInfiniteJump then
        local falling = false

        RunService.Heartbeat:Connect(function()
            if not humanoid then return end

            local state = humanoid:GetState()

            if state == Enum.HumanoidStateType.FreeFall then
                falling = true
            elseif state == Enum.HumanoidStateType.Landed then
                falling = false
            elseif falling and state == Enum.HumanoidStateType.Jumping then
                reason = "Infinite Jump Detected"
                NG_Fail:FireServer(player, reason)
                falling = false
            end
        end)
    end


RunService.Heartbeat:Connect(function()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not hrp then return end

    -- Spider / wall climbing
    if Config.CheckForSpider then
        if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
            local isValidClimb = false
            local directions = {
                Vector3.new(1,0,0),
                Vector3.new(-1,0,0),
                Vector3.new(0,0,1),
                Vector3.new(0,0,-1)
            }

            for _, dir in ipairs(directions) do
                local ray = Ray.new(hrp.Position, dir * 2)
                local part = workspace:FindPartOnRayWithIgnoreList(ray, {character})
                if part and part:IsA("TrussPart") then
                    isValidClimb = true
                    break
                end
            end

            if not isValidClimb then
                NG_Fail:FireServer(player, "Spider Climb Detected")
            end
        end
    end

    -- Platform / flying check
    if Config.CheckForPlatform and humanoid.FloorMaterial == Enum.Material.Air then
        local ray = Ray.new(hrp.Position, Vector3.new(0, -5, 0))
        local part = workspace:FindPartOnRayWithIgnoreList(ray, {character})
        if part then
            NG_Find:FireServer("Platform", part)
        end
    end
end)
