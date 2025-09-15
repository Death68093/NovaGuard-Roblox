-- Config for NovaGuard

local Config = {}

-- Thresholds
Config.MaxSpeed = 16
Config.MaxJumpHeight = 7.2
Config.MaxJumpPower = 50
Config.CheckCooldown = 5 -- In Seconds
Config.MinFOV = 70 -- Minimum FOV, Default FOV is 70
Config.MaxFOV = 70 -- Maximum FOV, Default FOV is 70

-- Checks
Config.CheckHumanoid = true -- Check if player's humanoid exists
Config.CheckSpeed = true -- Check For Speed Hacks
Config.CheckJump = true -- Check for changes to JumpPower/JumpHeight
Config.CheckCoreGui = true -- Check for changes to CoreGui (common for cheats/clients)
Config.CheckPlayerGui = true -- Check for changes to PlayerGui
Config.CheckForLocalScript = true -- Checks for anything named exactly "LocalScript" (most likely for executer use)
Config.CheckForTP = true -- Check for teleportation
Config.CheckForFly = true -- Check For Flying
Config.CheckForFOV = true -- Check for FOV Changes
Config.CheckForGravity = true -- Check For Gravity Changes
Config.CheckForInfiniteJump = true

-- Punishments
Config.AutoKick = true

-- logging (currently prints to server; replace with datastore/webhook as desired)
Config.LogPrefix = "[NovaGuard]"

-- Misc
Config.ShowWaterMark = true -- Show the "Protected By: NovaGuard" logo

return Config
