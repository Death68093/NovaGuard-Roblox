-- NG_Server (ServerScriptService)
-- Full admin backend: logs, bans, flags, evidence, detection config, audit, review queue

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- DataStores
local logStore = DataStoreService:GetDataStore("NovaGuardLogs")
local banStore = DataStoreService:GetDataStore("NovaGuardBans")
local flagStore = DataStoreService:GetDataStore("NovaGuardFlags")
local auditStore = DataStoreService:GetDataStore("NovaGuardAudit")
local configStore = DataStoreService:GetDataStore("NovaGuardConfig")
local evidenceStore = DataStoreService:GetDataStore("NovaGuardEvidence")

-- Config module (should exist in ReplicatedStorage.Modules.NG_Config)
local config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NG_Config"))

-- Helpers: create remotes if missing
local function getOrCreateRemote(name, rtype)
    local obj = ReplicatedStorage:FindFirstChild(name)
    if not obj then
        if rtype == "RemoteEvent" then obj = Instance.new("RemoteEvent")
        elseif rtype == "RemoteFunction" then obj = Instance.new("RemoteFunction")
        else error("Invalid remote type: "..tostring(rtype)) end
        obj.Name = name
        obj.Parent = ReplicatedStorage
    end
    return obj
end

local NG_AdminAction = getOrCreateRemote("NG_AdminAction", "RemoteEvent")
local NG_AdminInvoke = getOrCreateRemote("NG_AdminInvoke", "RemoteFunction")
local NG_Pass = getOrCreateRemote("Ng_Pass_Event", "RemoteEvent")
local NG_Fail = getOrCreateRemote("Ng_Fail_Event", "RemoteEvent")
local NG_Check = getOrCreateRemote("Ng_Check_Event", "RemoteEvent")
local NG_Exists = getOrCreateRemote("NG_Exists_Event", "RemoteEvent")
local NG_Find = getOrCreateRemote("NG_Find_Event", "RemoteEvent")
local NG_GetVal = getOrCreateRemote("NG_GetVal_Event", "RemoteFunction")

-- Local caches (kept synced to DataStore)
local logs = {}
local bans = {}        -- bans[userId] = { reason, time, expires (optional) }
local flags = {}       -- flags[userId] = { reason, reporter, time, extra, resolved = bool }
local audit = {}
local detectionConfig = {} -- copy of config booleans/thresholds
local evidence = {}    -- evidence[userId] = { {time, type, data}, ... }
local reviewQueue = {} -- list of userIds flagged and pending


local function safeLoad(store, key, default)
    local ok, res = pcall(function() return store:GetAsync(key) end)
    if ok and res ~= nil then return res end
    return default
end


local function safeSave(store, key, value)
    local ok, err = pcall(function() store:SetAsync(key, value) end)
    if not ok then
        warn("DataStore save failed for "..tostring(key)..": "..tostring(err))
    end
    return ok
end


logs = safeLoad(logStore, "Logs", {})
bans = safeLoad(banStore, "Bans", {})
flags = safeLoad(flagStore, "Flags", {})
audit = safeLoad(auditStore, "Audit", {})
detectionConfig = safeLoad(configStore, "DetectionConfig", nil) or {} -- may be empty; we'll fallback to module
evidence = safeLoad(evidenceStore, "Evidence", {})


local function now()
    return os.time()
end

local function addLog(entry)
    local t = {time = now(), entry = entry}
    table.insert(logs, 1, t) -- newest first
    safeSave(logStore, "Logs", logs)
end

local function addAudit(adminPlayer, action, details)
    local rec = {time = now(), admin = (adminPlayer and adminPlayer.UserId) or "system", action = action, details = details}
    table.insert(audit, 1, rec)
    safeSave(auditStore, "Audit", audit)
end


local function addEvidence(userId, evType, data)
    evidence[tostring(userId)] = evidence[tostring(userId)] or {}
    local arr = evidence[tostring(userId)]
    table.insert(arr, 1, {time = now(), type = evType, data = data})
    -- cap per-player evidence to reasonable number (e.g., 200)
    if #arr > 200 then
        for i = #arr, 201, -1 do table.remove(arr, i) end
    end
    safeSave(evidenceStore, "Evidence", evidence)
end

-- flagging / review queue
local function addFlag(reporter, userId, reason, extra)
    flags[tostring(userId)] = flags[tostring(userId)] or {}
    local f = {reason = reason, reporter = reporter.UserId, time = now(), extra = extra, resolved = false}
    table.insert(flags[tostring(userId)], 1, f)
    reviewQueue[userId] = reviewQueue[userId] or true
    safeSave(flagStore, "Flags", flags)
    addLog(("Flag added: %s flagged %s: %s"):format(reporter.Name, tostring(userId), reason))
    addAudit(reporter, "Flag", {target = userId, reason = reason})
end

local function resolveFlag(adminPlayer, userId, index, resolutionNote)
    if not flags[tostring(userId)] then return false end
    local arr = flags[tostring(userId)]
    local idx = tonumber(index)
    if not arr[idx] then return false end
    arr[idx].resolved = true
    arr[idx].resolvedBy = adminPlayer.UserId
    arr[idx].resolutionNote = resolutionNote
    safeSave(flagStore, "Flags", flags)
    addLog(("Flag resolved: %s resolved flag on %s (#%d)"):format(adminPlayer.Name, tostring(userId), idx))
    addAudit(adminPlayer, "ResolveFlag", {target = userId, index = idx, note = resolutionNote})
    return true
end

-- ban
local function setBan(userId, reason, durationSeconds, adminPlayer)
    local entry = {reason = reason, time = now(), expires = nil}
    if durationSeconds and durationSeconds > 0 then
        entry.expires = now() + durationSeconds
    end
    bans[tostring(userId)] = entry
    safeSave(banStore, "Bans", bans)
    addLog(("Ban set: %s -> %s (duration=%s)"):format((adminPlayer and adminPlayer.Name) or "system", tostring(userId), tostring(durationSeconds)))
    addAudit(adminPlayer, "Ban", {target = userId, reason = reason, duration = durationSeconds})
end

local function clearBan(userId, adminPlayer)
    bans[tostring(userId)] = nil
    safeSave(banStore, "Bans", bans)
    addLog(("Ban cleared: %s cleared ban on %s"):format((adminPlayer and adminPlayer.Name) or "system", tostring(userId)))
    addAudit(adminPlayer, "Unban", {target = userId})
end

local function isBanned(userId)
    local b = bans[tostring(userId)]
    if not b then return false end
    if b.expires and b.expires <= now() then
        bans[tostring(userId)] = nil
        safeSave(banStore, "Bans", bans)
        return false
    end
    return true, b
end

-- admin check (by Config.Admins)
local function isAdmin(player)
    if not player then return false end
    for _, id in ipairs(config.Admins or {}) do
        if player.UserId == id then return true end
    end
    return false
end

-- PlayerAdded: enforce bans
Players.PlayerAdded:Connect(function(plr)
    local banned, binfo = isBanned(plr.UserId)
    if banned then
        local reason = binfo.reason or "Banned"
        -- Do not log again here to avoid recursion; kick
        pcall(function() plr:Kick("Banned: "..tostring(reason)) end)
        return
    end
    -- deliver player-history push (optional): we add an audit/log entry for join
    addLog(("Player joined: %s (%s)"):format(plr.Name, plr.UserId))
end)

-- AdminAction (RemoteEvent) -- actions triggered from client
NG_AdminAction.OnServerEvent:Connect(function(adminPlayer, action, payload1, payload2, payload3)
    if not isAdmin(adminPlayer) then
        warn("Non-admin tried admin action: "..tostring(adminPlayer and adminPlayer.Name))
        return
    end

    -- payloads vary by action
    if action == "Kick" then
        local target = payload1
        local reason = payload2 or "No reason provided"
        if target and target.Parent then
            addLog(adminPlayer.Name.." kicked "..target.Name.." | "..reason)
            addAudit(adminPlayer, "Kick", {target = target.UserId, reason = reason})
            pcall(function() target:Kick("Kicked by admin: "..adminPlayer.Name.." | "..reason) end)
        end

    elseif action == "Ban" then
        local target = payload1
        local duration = tonumber(payload2) -- seconds, nil for permanent
        local reason = payload3 or "No reason provided"
        if target then
            setBan(target.UserId, reason, duration, adminPlayer)
            pcall(function() if target.Parent then target:Kick("Banned by admin: "..adminPlayer.Name.." | "..reason) end end)
        end

    elseif action == "Unban" then
        local userId = tonumber(payload1)
        if userId then clearBan(userId, adminPlayer) end

    elseif action == "TempBan" then
        local target = payload1
        local seconds = tonumber(payload2) or 0
        local reason = payload3 or "No reason provided"
        if target then
            setBan(target.UserId, reason, seconds, adminPlayer)
            pcall(function() if target.Parent then target:Kick("Temp-banned: "..reason) end end)
        end

    elseif action == "Flag" then
        local targetUserId = tonumber(payload1)
        local reason = payload2 or "flagged"
        local extra = payload3
        if targetUserId then
            -- allow admin flagging on behalf of reviewer
            addFlag(adminPlayer, targetUserId, reason, extra)
        end

    elseif action == "ResolveFlag" then
        local targetUserId = tonumber(payload1)
        local index = payload2
        local note = payload3 or ""
        resolveFlag(adminPlayer, targetUserId, index, note)

    elseif action == "AddEvidence" then
        -- payload1 = targetUserId, payload2 = evType, payload3 = data (table)
        addEvidence(tostring(payload1), payload2, payload3)
        addAudit(adminPlayer, "AddEvidence", {target = tostring(payload1), type = payload2})

    elseif action == "ToggleDetector" then
        local detectorKey = payload1
        local newVal = payload2
        detectionConfig[detectorKey] = newVal
        safeSave(configStore, "DetectionConfig", detectionConfig)
        addAudit(adminPlayer, "ToggleDetector", {detector = detectorKey, value = newVal})
        addLog(("Detector toggled: %s = %s by %s"):format(detectorKey, tostring(newVal), adminPlayer.Name))

    elseif action == "MassAction" then
        -- payload1 = {userIds} or players, payload2 = actionType, payload3 = reason/duration
        local targets = payload1
        local act = payload2
        local arg = payload3
        if type(targets) == "table" then
            for _, t in ipairs(targets) do
                -- try to resolve player object
                local pl = nil
                if type(t) == "number" then pl = Players:GetPlayerByUserId(t) end
                if typeof(t) == "Instance" and t:IsA("Player") then pl = t end
                if act == "Kick" and pl then
                    addLog(adminPlayer.Name.." mass-kicked "..pl.Name.." | "..tostring(arg))
                    pcall(function() pl:Kick("Mass action kick: "..tostring(arg)) end)
                elseif act == "Ban" and pl then
                    setBan(pl.UserId, tostring(arg), nil, adminPlayer)
                    pcall(function() pl:Kick("Banned by admin (mass): "..tostring(arg)) end)
                end
            end
        end
        addAudit(adminPlayer, "MassAction", {action = act, targets = targets, arg = arg})
    elseif action == "PanicMode" then
        -- Panic: store a flag and optionally perform game state changes (developer must implement safe state hooks)
        detectionConfig.__panic = true
        safeSave(configStore, "DetectionConfig", detectionConfig)
        addAudit(adminPlayer, "PanicModeEnable", {})
        addLog(adminPlayer.Name.." enabled PANIC MODE")
        -- (hook example): fire a BindableEvent or call a function to lock features. dev must implement actual game locking.
        -- ReplicatedStorage:FindFirstChild("NovaGuardPanic") and fire it if present.
        local panicBE = ReplicatedStorage:FindFirstChild("NovaGuardPanic")
        if panicBE and panicBE:IsA("BindableEvent") then
            panicBE:Fire(true)
        end
    elseif action == "ReleasePanic" then
        detectionConfig.__panic = nil
        safeSave(configStore, "DetectionConfig", detectionConfig)
        addAudit(adminPlayer, "PanicModeDisable", {})
        addLog(adminPlayer.Name.." disabled PANIC MODE")
        local panicBE = ReplicatedStorage:FindFirstChild("NovaGuardPanic")
        if panicBE and panicBE:IsA("BindableEvent") then
            panicBE:Fire(false)
        end
    elseif action == "MarkFalsePositive" then
        local userId = tonumber(payload1)
        local note = payload2 or ""
        addAudit(adminPlayer, "MarkFP", {target = userId, note = note})
        addLog(("FalsePositive marked by %s on %s: %s"):format(adminPlayer.Name, tostring(userId), note))
    else
        warn("Unknown admin action: "..tostring(action))
    end
end)

-- AdminInvoke (RemoteFunction) - queries from client admin GUI
NG_AdminInvoke.OnServerInvoke = function(adminPlayer, query, param)
    if not isAdmin(adminPlayer) then return nil end

    if query == "GetLogs" then
        return logs
    elseif query == "GetFlags" then
        return flags
    elseif query == "GetBans" then
        return bans
    elseif query == "GetDetectionConfig" then
        -- merge config module with detectionConfig overrides
        local combined = {}
        for k,v in pairs(config) do combined[k] = v end
        for k,v in pairs(detectionConfig) do combined[k] = v end
        return combined
    elseif query == "GetEvidence" then
        return evidence[tostring(param)] or {}
    elseif query == "GetPlayerHistory" then
        local uid = tostring(param)
        local history = {}
        -- collect logs mentioning the userId or name (simple scan)
        for _, l in ipairs(logs) do
            if tostring(l.entry):find(tostring(uid)) then table.insert(history, l) end
        end
        return history
    elseif query == "SearchLogs" then
        -- param = {term=string, userId=number, fromTime=number, toTime=number}
        local res = {}
        for _, l in ipairs(logs) do
            local e = l.entry
            local t = l.time
            local match = true
            if param.term and not tostring(e):lower():find(tostring(param.term):lower()) then match = false end
            if param.userId and not tostring(e):find(tostring(param.userId)) then match = false end
            if param.fromTime and t < param.fromTime then match = false end
            if param.toTime and t > param.toTime then match = false end
            if match then table.insert(res, l) end
        end
        return res
    elseif query == "GetReviewQueue" then
        return reviewQueue
    elseif query == "GetAudit" then
        return audit
    else
        return nil
    end
end

-- Hook anti-cheat events to auto-log evidence
NG_Fail.OnServerEvent:Connect(function(player, token, reason)
    addLog(("AutoFail: %s failed check: %s"):format(player.Name, tostring(reason)))
    addEvidence(player.UserId, "AutoFail", {reason = reason, token = token})
end)

NG_Find.OnServerEvent:Connect(function(player, token, checkType, data)
    addLog(("AutoFind: %s reported %s"):format(player.Name, tostring(checkType)))
    addEvidence(player.UserId, "AutoFind", {type = checkType, part = (data and data.Name) or nil})
end)

-- NOTE: For heavy DataStore usage in busy games, use batched/queue writes and exponential backoff. This code is straightforward and synchronous.
