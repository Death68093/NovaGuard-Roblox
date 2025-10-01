-- Config for NovaGuard

local Config = {}

Config.CheckInterval = 5 -- How often to run checks (seconds)
Config.CheckTimeout = 3 -- When the Server checks the client (if the client doesn't respond) how man seconds until the check fails

-- Thresholds
Config.MaxSpeed = 16
Config.SpeedBuffer = 1.1 -- Small exception to speed in case of lag
Config.MaxJumpHeight = 7.2
Config.MaxJumpPower = 50
Config.CheckCooldown = 5 -- In Seconds
Config.MinFOV = 70 -- Minimum FOV, Default FOV is 70
Config.MaxFOV = 70 -- Maximum FOV, Default FOV is 70
Config.MinGravity = 196.2 -- Default Gravity is 196.2
Config.MaxGravity = 196.2 -- Default Gravity is 196.2
Config.UseServerGravity = true -- Check if Client gravity = Server gravity
Config.DefaultGravity = 196.2 -- Set to your game's default gravity if not using server gravity



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
Config.CheckForInfiniteJump = true -- Check For Ininite Jump
Config.CheckForNoclip = true -- Check For Noclip
Config.CheckForSpider = true -- Check For Spider (walking on walls/ceilings, like an invisible truss)
Config.CheckForPlatform = true -- Check For Platform (standing on invisible platform) (flying)

-- Checks settings
Config.CheckFlyState = true -- True = Check for humanoid:GetState() == "flying"


Config.WhitelistedUserIds = {
    -- Add UserIds here to whitelist them from checks/punishments
    --[[ 
    Example: 
    123456789 = {
        Reason = "I am the game owner"
    },
    987654321 = {
        Reason = "I am a trusted admin"
        checks = { -- Optional, leave out to whitelist from all checks
            "CheckSpeed",
            "CheckJump",
            "CheckForFly",
            "CheckForFOV"
        }
    },
    ]]--
}


-- Who will have access to the admin panel?
Config.Admins = {
--[[ Enter Id's of your admins (command seperated)
E.g:
123456789,
987654321
]]--
}

-- Punishments
Config.AutoKick = true

--[[ logging (currently prints to server; replace with datastore/webhook)]]
Config.LogPrefix = "[NovaGuard]"

-- Misc
Config.ShowWaterMark = true --[[ Show the "Protected By: NovaGuard" logo (  hide to keep the anticheat a secret :)  ) ]]

Config.AdminKeybind = Enum.KeyCode.Z  -- [[Just change the Z to whatever key you prefer :) will only work for admins set in Config.Admins]]

return Config