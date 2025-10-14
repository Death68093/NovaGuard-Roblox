local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local ws = game:GetService("Workspace")
local config = require(ReplicatedStorage:WaitForChild("Config"))
local lastKey = 10

local RemoteFolder = ReplicatedStorage:FindFirstChild("RemoteFolder")
if not RemoteFolder then
    RemoteFolder = Instance.new("Folder")
    RemoteFolder.Name = "RemoteFolder"
    RemoteFolder.Parent = ReplicatedStorage
end

-- Create Remotes
local function makeRemote(name, type)
    if not RemoteFolder:FindFirstChild(name) then
        local remote
        if type == "function" then
            remote = Instance.new("RemoteFunction")
        else
            remote = Instance.new("RemoteEvent")
        end
        remote.Name = name
        remote.Parent = RemoteFolder
    end
end

makeRemote("NG_Check", "remote")
local checkEvent = RemoteFolder:WaitForChild("NG_Check")

makeRemote("NG_Fail", "remote")
local failEvent = RemoteFolder:WaitForChild("NG_Fail")

makeRemote("NG_GetVals", "function")
local getVals = RemoteFolder:WaitForChild("NG_GetVals")



local function fail(check, desc, plr)
    if config.Punishment == "respawn" then
        plr.Character.Humanoid.Health = 0
    end
    if config.Punishment == "kick" then
        plr:Kick(check, desc)
    end
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
                print(player.Name .. " flagged for horizontal NoClip!")
                fail("No Clip", "No clip detected horizontally", player)
            end
        end

        lastPos = currentPos
    end
end


players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        while task.wait(config.NoClipTimer) do
            checkNoClip(player)
        end
        while task.wait(config.CheckInt) do
            checkEvent:FireAllClient()
            lastKey
            local vals = getVals:InvokeAllClients()
        end
    end)
end)

