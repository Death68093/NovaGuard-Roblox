-- NG_Admin (LocalScript)
-- Full admin GUI & interactions (requests data via NG_AdminInvoke; sends actions via NG_AdminAction)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local HttpService = game:GetService("HttpService")

local NG_AdminAction = ReplicatedStorage:WaitForChild("NG_AdminAction")
local NG_AdminInvoke = ReplicatedStorage:WaitForChild("NG_AdminInvoke")
local NG_Config = require(ReplicatedStorage:WaitForChild("NG_Config"))

local function isAdmin()
    for _, id in ipairs(NG_Config.Admins or {}) do
        if Player.UserId == id then return true end
    end
    return false
end
if not isAdmin() then return end

-- Simple utility for creating UI elements
local function new(class, props)
    local o = Instance.new(class)
    if props then for k,v in pairs(props) do o[k] = v end end
    return o
end

-- ScreenGui
local screen = new("ScreenGui", {Name = "NG_AdminPanel", ResetOnSpawn = false, Parent = PlayerGui})

-- Main window
local win = new("Frame", {
    Parent = screen,
    Size = UDim2.new(0, 780, 0, 520),
    Position = UDim2.new(0.5, -390, 0.5, -260),
    BackgroundColor3 = Color3.fromRGB(30,30,30)
})
local title = new("TextLabel", {Parent = win, Size = UDim2.new(1,0,0,36), Text = "NovaGuard — Admin Panel", BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), TextScaled = true})

-- Left: player list & controls
local left = new("Frame", {Parent = win, Position = UDim2.new(0,10,0,46), Size = UDim2.new(0,360,1,-56), BackgroundColor3 = Color3.fromRGB(36,36,36)})
local playerScroll = new("ScrollingFrame", {Parent = left, Size = UDim2.new(1,-10,1,-10), Position = UDim2.new(0,5,0,5), CanvasSize = UDim2.new(0,0,0,0), BackgroundColor3 = Color3.fromRGB(40,40,40)})
local plistLayout = new("UIListLayout", {Parent = playerScroll, Padding = UDim.new(0,6)})
local searchBox = new("TextBox", {Parent = left, Size = UDim2.new(1,-20,0,28), Position = UDim2.new(0,10,0,5), Text = "", PlaceholderText = "Search players..."})

-- Right: tabs for logs, flags, history, tuning, review
local right = new("Frame", {Parent = win, Position = UDim2.new(0,380,0,46), Size = UDim2.new(1,-390,1,-56), BackgroundColor3 = Color3.fromRGB(28,28,28)})
local tabButtons = {}
local tabs = {}

local function makeTab(name)
    local btn = new("TextButton", {Parent = right, Size = UDim2.new(0,120,0,28), Text = name, BackgroundColor3 = Color3.fromRGB(50,50,50)})
    table.insert(tabButtons, btn)
    local pane = new("Frame", {Parent = right, Size = UDim2.new(1, -20, 1, -40), Position = UDim2.new(0,10,0,40), BackgroundTransparency = 1, Visible = false})
    tabs[name] = pane
    return btn, pane
end

local btnLogs, paneLogs = makeTab("Logs")
local btnFlags, paneFlags = makeTab("Flags")
local btnHistory, paneHistory = makeTab("History")
local btnTuning, paneTuning = makeTab("Tuning")
local btnReview, paneReview = makeTab("Review")
local btnEvidence, paneEvidence = makeTab("Evidence")

-- activate first tab
for i,btn in ipairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        for _,p in pairs(tabs) do p.Visible = false end
        tabs[btn.Text].Visible = true
    end)
end
tabButtons[1].MouseButton1Click()

-- utility: create player entry
local function createPlayerEntry(plr)
    local root = new("Frame", {Parent = playerScroll, Size = UDim2.new(1, -10, 0, 36), BackgroundColor3 = Color3.fromRGB(45,45,45)})
    local name = new("TextLabel", {Parent = root, Text = plr.Name, Size = UDim2.new(0.6,0,1,0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1)})
    local uid = new("TextLabel", {Parent = root, Text = tostring(plr.UserId), Size = UDim2.new(0.4, -10, 1, 0), Position = UDim2.new(0.6, 5, 0, 0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1)})
    local btnKick = new("TextButton", {Parent = root, Text = "Kick", Size = UDim2.new(0,70,0,26), Position = UDim2.new(1,-75,0,5), BackgroundColor3 = Color3.fromRGB(175,50,50)})
    local btnBan = new("TextButton", {Parent = root, Text = "Ban", Size = UDim2.new(0,70,0,26), Position = UDim2.new(1,-150,0,5), BackgroundColor3 = Color3.fromRGB(150,30,30)})
    local btnFlag = new("TextButton", {Parent = root, Text = "Flag", Size = UDim2.new(0,70,0,26), Position = UDim2.new(1,-225,0,5), BackgroundColor3 = Color3.fromRGB(180,140,30)})

    btnKick.MouseButton1Click:Connect(function()
        local reason = "Manual kick"
        NG_AdminAction:FireServer("Kick", plr, reason)
    end)
    btnBan.MouseButton1Click:Connect(function()
        -- simple permanent ban; for temp ban you'd prompt duration
        local reason = "Manual ban"
        NG_AdminAction:FireServer("Ban", plr, nil, reason)
    end)
    btnFlag.MouseButton1Click:Connect(function()
        local reason = "Suspicious activity"
        NG_AdminAction:FireServer("Flag", plr.UserId, reason, {fromAdmin = Player.UserId})
    end)
    return root
end

-- populate player list
local function refreshPlayers(filter)
    for _,child in ipairs(playerScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _,plr in ipairs(Players:GetPlayers()) do
        if not filter or tostring(plr.Name):lower():find(filter:lower()) or tostring(plr.UserId):find(filter) then
            createPlayerEntry(plr)
        end
    end
    -- update canvas size
    local layout = playerScroll:FindFirstChildOfClass("UIListLayout")
    if layout then
        local total = #playerScroll:GetChildren()
        playerScroll.CanvasSize = UDim2.new(0,0,0, total * 42)
    end
end
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    refreshPlayers(searchBox.Text)
end)
Players.PlayerAdded:Connect(function() refreshPlayers(searchBox.Text) end)
Players.PlayerRemoving:Connect(function() refreshPlayers(searchBox.Text) end)
refreshPlayers("")

-- LOGS tab
local logsScroll = new("ScrollingFrame", {Parent = paneLogs, Size = UDim2.new(1,-20,1,-20), Position = UDim2.new(0,10,0,10), BackgroundColor3 = Color3.fromRGB(28,28,28)})
local logsLayout = new("UIListLayout", {Parent = logsScroll, Padding = UDim.new(0,6)})
local function refreshLogs()
    local data = NG_AdminInvoke:InvokeServer("GetLogs")
    if not data then return end
    logsScroll:ClearAllChildren()
    for i,entry in ipairs(data) do
        local lbl = new("TextLabel", {Parent = logsScroll, Size = UDim2.new(1,-20,0,24), Text = ("[%s] %s"):format(os.date("%Y-%m-%d %H:%M:%S", entry.time), tostring(entry.entry)), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), TextXAlignment = Enum.TextXAlignment.Left})
    end
end
-- refresh logs periodically
spawn(function()
    while true do
        pcall(refreshLogs)
        task.wait(5)
    end
end)

-- FLAGS tab
local flagsScroll = new("ScrollingFrame", {Parent = paneFlags, Size = UDim2.new(1,-20,1,-20), Position = UDim2.new(0,10,0,10), BackgroundColor3 = Color3.fromRGB(28,28,28)})
local function refreshFlags()
    local data = NG_AdminInvoke:InvokeServer("GetFlags")
    flagsScroll:ClearAllChildren()
    for userId, arr in pairs(data) do
        for idx, f in ipairs(arr) do
            local lbl = new("TextButton", {Parent = flagsScroll, Size = UDim2.new(1,-40,0,30), Text = ("User %s: %s (by %s)"):format(userId, f.reason, tostring(f.reporter)), BackgroundColor3 = Color3.fromRGB(60,60,60)})
            lbl.MouseButton1Click:Connect(function()
                -- Resolve UI: Resolve the flag (admin confirms)
                NG_AdminAction:FireServer("ResolveFlag", tonumber(userId), idx, "Reviewed and resolved by "..Player.Name)
            end)
        end
    end
end
spawn(function()
    while true do
        pcall(refreshFlags)
        task.wait(8)
    end
end)

-- HISTORY tab
local historyScroll = new("ScrollingFrame", {Parent = paneHistory, Size = UDim2.new(1,-20,1,-20), Position = UDim2.new(0,10,0,10), BackgroundColor3 = Color3.fromRGB(28,28,28)})
local function viewPlayerHistory(userId)
    local data = NG_AdminInvoke:InvokeServer("GetPlayerHistory", userId)
    historyScroll:ClearAllChildren()
    for i,entry in ipairs(data) do
        new("TextLabel", {Parent = historyScroll, Size = UDim2.new(1,-20,0,22), Text = ("[%s] %s"):format(os.date("%Y-%m-%d %H:%M:%S", entry.time), tostring(entry.entry)), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1)})
    end
end

-- TUNING tab (detection toggles)
local tuneScroll = new("ScrollingFrame", {Parent = paneTuning, Size = UDim2.new(1,-20,1,-20), Position = UDim2.new(0,10,0,10), BackgroundColor3 = Color3.fromRGB(28,28,28)})
local function refreshTuning()
    local conf = NG_AdminInvoke:InvokeServer("GetDetectionConfig")
    tuneScroll:ClearAllChildren()
    local y = 0
    for k,v in pairs(conf) do
        if type(v) == "boolean" and tostring(k):match("^Check") then
            local btn = new("TextButton", {Parent = tuneScroll, Size = UDim2.new(1,-20,0,28), Position = UDim2.new(0,10,0,y), Text = k.." : "..tostring(v), BackgroundColor3 = Color3.fromRGB(60,60,60)})
            btn.MouseButton1Click:Connect(function()
                local newVal = not v
                NG_AdminAction:FireServer("ToggleDetector", k, newVal)
                task.wait(0.2)
                refreshTuning()
            end)
            y = y + 34
        end
    end
end
spawn(function()
    while true do
        pcall(refreshTuning)
        task.wait(6)
    end
end)

-- REVIEW tab: shows flagged queue & quick actions
local reviewScroll = new("ScrollingFrame", {Parent = paneReview, Size = UDim2.new(1,-20,1,-20), Position = UDim2.new(0,10,0,10), BackgroundColor3 = Color3.fromRGB(28,28,28)})
local function refreshReview()
    local queue = NG_AdminInvoke:InvokeServer("GetReviewQueue")
    reviewScroll:ClearAllChildren()
    local y = 0
    for userId,_ in pairs(queue or {}) do
        local row = new("Frame", {Parent = reviewScroll, Size = UDim2.new(1,-20,0,36), Position = UDim2.new(0,10,0,y), BackgroundColor3 = Color3.fromRGB(50,50,50)})
        new("TextLabel", {Parent = row, Size = UDim2.new(0.6,0,1,0), Text = "User "..tostring(userId), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1)})
        local kick = new("TextButton", {Parent = row, Size = UDim2.new(0,80,0,28), Position = UDim2.new(0.6,10,0,4), Text = "Kick"})
        local ban = new("TextButton", {Parent = row, Size = UDim2.new(0,80,0,28), Position = UDim2.new(0.6,100,0,4), Text = "Ban"})
        local view = new("TextButton", {Parent = row, Size = UDim2.new(0,80,0,28), Position = UDim2.new(0.6,190,0,4), Text = "View"})
        kick.MouseButton1Click:Connect(function()
            local pl = Players:GetPlayerByUserId(tonumber(userId))
            if pl then NG_AdminAction:FireServer("Kick", pl, "Review kick") end
        end)
        ban.MouseButton1Click:Connect(function()
            local pl = Players:GetPlayerByUserId(tonumber(userId))
            if pl then NG_AdminAction:FireServer("Ban", pl, nil, "Review ban") end
        end)
        view.MouseButton1Click:Connect(function()
            -- open evidence tab with this user's evidence
            local ev = NG_AdminInvoke:InvokeServer("GetEvidence", tonumber(userId))
            paneEvidence.Visible = true
            tabs["Evidence"].Visible = true
            -- populate evidence pane
            local evScroll = paneEvidence:FindFirstChild("EvScroll")
            if not evScroll then
                evScroll = new("ScrollingFrame", {Name = "EvScroll", Parent = paneEvidence, Size = UDim2.new(1,-20,1,-20), Position = UDim2.new(0,10,0,10), BackgroundColor3 = Color3.fromRGB(20,20,20)})
            else
                evScroll:ClearAllChildren()
            end
            for _, item in ipairs(ev) do
                new("TextLabel", {Parent = evScroll, Size = UDim2.new(1,-20,0,22), Text = ("[%s] %s"):format(os.date("%Y-%m-%d %H:%M:%S", item.time), tostring(item.type .. " - " .. (item.data and HttpService:JSONEncode(item.data) or ""))), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1)})
            end
        end)
        y = y + 40
    end
end
spawn(function()
    while true do
        pcall(refreshReview)
        task.wait(8)
    end
end)

-- EVIDENCE tab stub (populated from review view or direct query)
paneEvidence.Visible = false

-- Mass action UI (example)
local massBtn = new("TextButton", {Parent = win, Text = "Bulk: Kick Flagged", Size = UDim2.new(0,150,0,30), Position = UDim2.new(0,10,1,-40)})
massBtn.MouseButton1Click:Connect(function()
    local flagsData = NG_AdminInvoke:InvokeServer("GetFlags")
    local ids = {}
    for uid,_ in pairs(flagsData) do table.insert(ids, tonumber(uid)) end
    NG_AdminAction:FireServer("MassAction", ids, "Kick", "Bulk flagged kick")
end)

-- Panic Mode toggle
local panicBtn = new("TextButton", {Parent = win, Text = "Panic Mode", Size = UDim2.new(0,120,0,30), Position = UDim2.new(0,170,1,-40)})
panicBtn.MouseButton1Click:Connect(function()
    NG_AdminAction:FireServer("PanicMode")
end)
local releasePanicBtn = new("TextButton", {Parent = win, Text = "Release Panic", Size = UDim2.new(0,120,0,30), Position = UDim2.new(0,300,1,-40)})
releasePanicBtn.MouseButton1Click:Connect(function()
    NG_AdminAction:FireServer("ReleasePanic")
end)

-- Test / staging toggle (client-side only)
local testMode = false
local testBtn = new("TextButton", {Parent = win, Text = "Toggle Test Mode", Size = UDim2.new(0,120,0,30), Position = UDim2.new(0,440,1,-40)})
testBtn.MouseButton1Click:Connect(function()
    testMode = not testMode
    if testMode then
        addLogLocal("Test mode enabled") -- optional client-side note; real logs call server
    end
end)

-- small helper for client local test logs (not persisted)
function addLogLocal(msg)
    print("[NG_Admin TEST] "..msg)
end

-- Dragging window
local dragging, dragInput, dragStart, startPos
win.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = win.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
win.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Keybind to toggle (Config.AdminKeybind)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == NG_Config.AdminKeybind then
        screen.Enabled = not screen.Enabled
    end
end)
screen.Enabled = false
