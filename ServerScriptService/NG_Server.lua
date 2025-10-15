-- NovaGuard_Server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local config = require(ReplicatedStorage:WaitForChild("Config"))

local RemoteFolder = ReplicatedStorage:FindFirstChild("RemoteFolder")
if not RemoteFolder then
    RemoteFolder = Instance.new("Folder")
    RemoteFolder.Name = "RemoteFolder"
    RemoteFolder.Parent = ReplicatedStorage
end

local function makeRemote(name, rtype)
    if not RemoteFolder:FindFirstChild(name) then
        local remote
        if rtype == "function" then
            remote = Instance.new("RemoteFunction")
        else
            remote = Instance.new("RemoteEvent")
        end
        remote.Name = name
        remote.Parent = RemoteFolder
    end
end

makeRemote("NG_Check", "remote")
makeRemote("NG_Fail", "remote")
makeRemote("NG_GetVals", "function")
makeRemote("NG_Click", "remote")

local checkEvent = RemoteFolder:WaitForChild("NG_Check")
local failEvent = RemoteFolder:WaitForChild("NG_Fail")
local getVals = RemoteFolder:WaitForChild("NG_GetVals")
local click = RemoteFolder:WaitForChild("NG_Click")

-- Fail 
local function fail(check, desc, plr)
    if not plr then return end
    if config.Punishment == "respawn" then
        if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
            plr.Character:FindFirstChildOfClass("Humanoid").Health = 0
        end
    elseif config.Punishment == "kick" then
        plr:Kick(desc or check or "No reason")
    end
    pcall(function() failEvent:FireClient(plr, check, desc) end)
end

local function checkNoClip(player)
    if not config.UseRaycasts then
        warn("[NovaGuard] Please enable raycasts in the config file to check for No Clip!!")
        return
    end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local lastPos = root.Position
    while root.Parent do
        task.wait(config.NoClipTimer)
        local currentPos = root.Position
        local horizontalDelta = Vector3.new(currentPos.X - lastPos.X, 0, currentPos.Z - lastPos.Z)
        if horizontalDelta.Magnitude > 0 then
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Blacklist
            local rayResult = workspace:Raycast(lastPos, horizontalDelta, rayParams)
            if rayResult == nil then
                warn(player.Name .. " flagged for horizontal NoClip!")
                fail("No Clip", "No clip detected horizontally", player)
            end
        end
        lastPos = currentPos
    end
end

local function serverKeyGen(lastKey, sessionKey)

    local x = (lastKey + sessionKey * 7) ^ 1.3
    local y = math.sin(lastKey * 11.7) * 10000
    local z = (sessionKey % 997) * 13
    local raw = math.abs((x + y + z) % 1000000)
    return (raw / 1000000) * 1000
end

local function updateKey(currentKey)
    return ((currentKey * 73) % 91) / 90 * 100
end

local function checkVals(vals, plr)
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- Use server authoritative values if configured
    if config.UseServer then
        if config.CheckSpeed and hum.WalkSpeed ~= vals.speed then
            fail("Speed", "Moving too fast!", plr)
            return
        end
        if config.CheckJump and hum.JumpPower ~= vals.jumpPower then
            fail("Jump", "Jumped too high!", plr)
            return
        end
        if config.CheckGravity and Workspace.Gravity ~= vals.gravity then
            fail("Gravity", "Gravity has been modified", plr)
            return
        end
        if hum.MaxHealth ~= vals.maxHealth then
            fail("Max HP Changed", "You can't have that much health!", plr)
            return
        end
        if hum.Health ~= vals.health then
            fail("Health Changed", "You aren't allowed to have god mode!", plr)
            return
        end
        if hum.JumpHeight ~= vals.jumpHeight then
            fail("Jump", "Jumped too high!", plr)
            return
        end
    else
        -- Manual checks if UseServer is false
        if config.CheckSpeed and config.UserServerSpeed then
            if vals.speed > config.MaxSpeed then
                fail("Speed", "Exceeded max speed!", plr)
                return
            end
        end
        if config.CheckJump and config.UseServerJump then
            if vals.jumpPower > config.MaxJumpPower or vals.jumpHeight > config.MaxJumpHeight then
                fail("Jump", "Jump exceeded allowed limits!", plr)
                return
            end
        end
        if config.CheckGravity and config.UseServerGravity then
            if vals.gravity < config.MinGravity or vals.gravity > config.MaxGravity then
                fail("Gravity", "Gravity modified!", plr)
                return
            end
        end
        -- Additional optional checks
        if config.CheckFly and vals.isFlying then
            fail("Fly", "Flying detected!", plr)
            return
        end
        if config.CheckNoClip and vals.noPhysics then
            fail("NoClip", "NoClip detected!", plr)
            return
        end
    end

    if config.CheckCoreGui then
        
    end
    if config.CheckPlayerGui then
        
    end
end


local playerKeys = {} 

Players.PlayerAdded:Connect(function(player)
    local secretSalt = (config.ServerSalt or 1337)
    local sessionKey = (player.UserId * 2333 + math.floor(tick())) % 1000000
    sessionKey = (sessionKey + secretSalt) % 1000000
    local initialLast = ((player.UserId % 1000) * 37 + math.floor(tick())) % 10000

    playerKeys[player] = { session = sessionKey, last = initialLast }

    player.CharacterAdded:Connect(function(char)
        task.spawn(function()
            while char.Parent do
                task.wait(config.NoClipTimer)
                checkNoClip(player)
            end
        end)

        task.spawn(function()
            while char.Parent do
                task.wait(config.CheckInt)

                local info = playerKeys[player]
                if not info then break end

                local sentKey = serverKeyGen(info.last, info.session)

                local ok, vals = pcall(function()
                    return getVals:InvokeClient(player, sentKey)
                end)

                if not ok then
                    warn("NovaGuard: error invoking client for", player.Name)
                    fail("InvokeError", "Client failed to respond", player)
                    break
                end

                local expectedKey = serverKeyGen(info.last, info.session)

                info.last = updateKey(expectedKey)

                if type(vals) ~= "table" then
                    warn("NovaGuard: bad return from", player.Name)
                    fail("Check Failed", "No data returned", player)
                    break
                end

                if vals.key ~= expectedKey then
                    warn(("NovaGuard: key mismatch for %s (got %s expected %s)"):format(
                        player.Name, tostring(vals.key), tostring(expectedKey)
                    ))
                    fail("Key Mismatch", "Invalid/expired key (You Have Sent a Modified Key)", player)
                    break
                end
                checkVals(vals, player)
            end
        end)
    end)


end)

Players.PlayerRemoving:Connect(function(player)
    playerKeys[player] = nil
end)

