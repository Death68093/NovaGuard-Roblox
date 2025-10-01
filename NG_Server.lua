-- ServerScript (place in ServerScriptService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NG_Config"))

-- Remotes
local function getOrCreateRemote(name, type)
    local obj = ReplicatedStorage:FindFirstChild(name)
    if not obj then
        if type == "RemoteEvent" then
            obj = Instance.new("RemoteEvent")
        elseif type == "RemoteFunction" then
            obj = Instance.new("RemoteFunction")
        else
            error("Invalid type for remote: " .. tostring(type))
        end
        obj.Name = name
        obj.Parent = ReplicatedStorage
    end
    return obj
end

local NG_Pass = getOrCreateRemote("Ng_Pass_Event", "RemoteEvent")
local NG_Fail = getOrCreateRemote("Ng_Fail_Event", "RemoteEvent")
local NG_Check = getOrCreateRemote("Ng_Check_Event", "RemoteEvent")
local NG_Exists = getOrCreateRemote("NG_Exists_Event", "RemoteEvent")
local NG_Find = getOrCreateRemote("NG_Find_Event", "RemoteEvent")
local NG_GetVal = getOrCreateRemote("NG_GetVal_Event", "RemoteFunction")


local CHECK_INTERVAL = config.CheckInterval or 5
local CHECK_TIMEOUT = config.CheckTimeout or 3 -- seconds until server treats a check as timed-out/fail
local outstandingChecks = {} -- outstandingChecks[player] = { token = "...", started = os.clock() }

-- Clean up on leave
Players.PlayerRemoving:Connect(function(plr) outstandingChecks[plr] = nil end)

-- Validate token helper
local function validToken(player, token)
    if not player or not token then return false end
    local o = outstandingChecks[player]
    return o and o.token == token
end

-- Token-validated pass/fail handlers
NG_Pass.OnServerEvent:Connect(function(player, token)
    if validToken(player, token) then
        print(config.LogPrefix .. player.Name .. " passed their anti-cheat check")
        outstandingChecks[player] = nil
    else
        warn(config.LogPrefix .. "Ignored NG_Pass from " .. player.Name .. " (invalid/stale token)")
    end
end)

NG_Fail.OnServerEvent:Connect(function(player, token, reason)
    if validToken(player, token) then
        warn(config.LogPrefix .. player.Name .. " failed anti-cheat check: " .. tostring(reason))
        outstandingChecks[player] = nil
        if config.AutoKick then
            pcall(function() player:Kick(config.LogPrefix .. "Failed anti-cheat check: " .. tostring(reason)) end)
        end
    else
        warn(config.LogPrefix .. "Ignored NG_Fail from " .. player.Name .. " (invalid/stale token)")
    end
end)

-- NG_Find must include token as first param after the implicit player
NG_Find.OnServerEvent:Connect(function(player, token, checkType, data)
    if not validToken(player, token) then
        warn(config.LogPrefix .. "Ignored NG_Find from " .. player.Name .. " (invalid/stale token)")
        return
    end

    if checkType == "Platform" then
        local part = data
        if not part or not part:IsDescendantOf(workspace) then
            warn(config.LogPrefix .. player.Name .. " detected on fake platform")
            if config.AutoKick then pcall(function() player:Kick(config.LogPrefix .. "Illegal platform detected") end) end
        end
    elseif checkType == "Spider" then
        local part = data
        if not part or not part:IsDescendantOf(workspace) then
            warn(config.LogPrefix .. player.Name .. " attempted to climb a fake wall/truss")
            if config.AutoKick then pcall(function() player:Kick(config.LogPrefix .. "Illegal wall climb detected") end) end
        end
    end
end)

-- NG_Exists must also include token
NG_Exists.OnServerEvent:Connect(function(player, token)
    if not validToken(player, token) then
        warn(config.LogPrefix .. "Ignored NG_Exists from " .. player.Name .. " (invalid/stale token)")
        return
    end

    local requiredFiles = { "NG_Server", "NG_Client", "NG_Config" }
    local missing = {}

    local success, playerScripts = pcall(function() return player:WaitForChild("PlayerScripts", 5) end)
    if not success or not playerScripts then
        if config.AutoKick then pcall(function() player:Kick(config.LogPrefix .. "PlayerScripts missing") end) end
        outstandingChecks[player] = nil
        return
    end

    for _, fileName in ipairs(requiredFiles) do
        if not playerScripts:FindFirstChild(fileName) then
            table.insert(missing, fileName)
        end
    end

    if #missing > 0 then
        local reason = "Missing anti-cheat files: " .. table.concat(missing, ", ")
        warn(config.LogPrefix .. player.Name .. " - " .. reason)
        outstandingChecks[player] = nil
        if config.AutoKick then pcall(function() player:Kick(config.LogPrefix .. reason) end) end
    end
end)

-- NG_GetVal
NG_GetVal.OnServerInvoke = function(player, valType)
    if valType == "Gravity" then return workspace.Gravity end
end

-- Main loop: generate tokens + fire clients
task.spawn(function()
    while true do
        for _, player in ipairs(Players:GetPlayers()) do
            if player and player.Parent then
                local token = HttpService:GenerateGUID(false)
                outstandingChecks[player] = { token = token, started = os.clock() }
                -- Send token + config; client must reply using the same token
                NG_Check:FireClient(player, token, config)
            end
        end

        task.wait(CHECK_INTERVAL + math.random())

        -- sweep for timeouts
        local now = os.clock()
        for player, info in pairs(outstandingChecks) do
            if now - info.started >= CHECK_TIMEOUT then
                warn(config.LogPrefix .. player.Name .. " did not respond to anti-cheat check (timeout)")
                outstandingChecks[player] = nil
                if config.AutoKick then
                    pcall(function() player:Kick(config.LogPrefix .. "No response to anti-cheat check (timeout)") end)
                end
            end
        end
    end
end)
