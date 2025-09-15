local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NG_Config"))

-- Events
local NG_Pass = ReplicatedStorage:WaitForChild("Ng_Pass_Event")
local NG_Fail = ReplicatedStorage:WaitForChild("Ng_Fail_Event")
local NG_Check = ReplicatedStorage:WaitForChild("Ng_Check_Event")
local NG_Exists = ReplicatedStorage:WaitForChild("NG_Exists_Event")
local NG_Find = ReplicatedStorage:WaitForChild("NG_Find_Event")
local NG_GetVal = ReplicatedStorage:WaitForChild("NG_GetVal_Event")



-- How often to run checks (seconds)
local CHECK_INTERVAL = 5

-- Listen for client pass/fail
NG_Pass.OnServerEvent:Connect(function(player)
	print(config.LogPrefix .. player.Name .. " passed their anti-cheat check")
end)

NG_Fail.OnServerEvent:Connect(function(player, reason)
	warn(config.LogPrefix .. player.Name .. " failed anti-cheat check: " .. tostring(reason))

	-- Punish
	if config.AutoKick then
		player:Kick(config.LogPrefix .. "Failed anti-cheat check: " .. tostring(reason))
	end
end)

-- Loop to send checks with random interval
task.spawn(function()
	Players = game:GetService("Players")
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function()
				NG_Check:InvokeClient(player, config)
			end)
		end
		-- Wait base interval plus random offset (0–2 seconds)
		task.wait(CHECK_INTERVAL + math.random())
	end
end)

NG_Exists.OnServerEvent:Connect(function(player)
	local requiredFiles = {
		"NG_Server",
		"NG_Client",
		"NG_Config"
	}

	local missing = {}

	-- Check PlayerScripts for modules
	local success, playerScripts = pcall(function()
		return player:WaitForChild("PlayerScripts")
	end)

	if not success then
		NG_Fail:FireServer(player, "PlayerScripts missing")
		if config.AutoKick then
			player:Kick(config.LogPrefix .. "PlayerScripts missing")
		end
		return
	end

	for _, fileName in ipairs(requiredFiles) do
		if not playerScripts:FindFirstChild(fileName) then
			table.insert(missing, fileName)
		end
	end

	if #missing > 0 then
		local reason = "Missing anti-cheat files: " .. table.concat(missing, ", ") .. "\nIf you did not cause this, please contact the game owner."
		NG_Fail:FireServer(player, reason)
		if config.AutoKick then
			player:Kick(config.LogPrefix .. reason)
		end
	end
end)

NG_Find.OnServerEvent:Connect(function(player, checkType, data)
    if checkType == "Platform" then
        local part = data
        if not part or not part:IsDescendantOf(workspace) then
            warn(config.LogPrefix .. player.Name .. " detected on fake platform")
            if config.AutoKick then
                player:Kick(config.LogPrefix .. "Illegal platform detected")
            end
        end
    elseif checkType == "Spider" then
        local part = data
        if not part or not part:IsDescendantOf(workspace) then
            warn(config.LogPrefix .. player.Name .. " attempted to climb a fake wall/truss")
            if config.AutoKick then
                player:Kick(config.LogPrefix .. " Illegal wall climb detected")
            end
        end
    end
end)

NG_GetVal.OnServerInvoke = function(player, valType)
	if valType == "Gravity" then
		return workspace.Gravity
	end
end