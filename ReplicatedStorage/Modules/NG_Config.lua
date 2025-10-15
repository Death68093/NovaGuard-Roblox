local Config = {}

Config.SecretSalt = 23452 -- Set to a random number, used for script validation

Config.CheckInt = 5 -- How often to verify files (in seconds), and most checks
Config.FailTime = 3 -- How long until check fails

-- Check Toggles
Config.CheckSpeed = true
Config.CheckJump = true
Config.CheckInfJump = true
Config.CheckWorkspace = true
Config.CheckCoreGui = true
Config.CheckPlayerGui = true
Config.CheckAutoClick = true
Config.CheckFly = true
Config.CheckNoClip = true
Config.LagSwitch = true
Config.CheckRootParts = true
Config.CheckGravity = true


-- Check Settings
Config.NoClipTimer = 1 -- How often to check for no-clip (in seconds) do not set this higher as it will cause false positives High values will cause lag
Config.FlyCheckTimer = 1 -- How often to check for flying (in seconds) High values will cause lag
Config.FlyHeight = 20 -- How high to flag flying (studs)

Config.UseServer = true -- If true > Use Server Values for all checks, If false > Must set each check manually
Config.UseServerGravity = true 
Config.UserServerSpeed = true
Config.UseServerJump = true
Config.UseServerJump = true

Config.MaxSpeed = 16
Config.MaxJumpPower = 70
Config.MaxJumpHeight = 7.2
Config.MinGravity = 196.2
Config.MaxGravity = 196.2

Config.UseFlyRaycast = true -- Check Fly using raycast (can be performance intensive)

Config.UseRaycasts = true -- Disable to turn off all raycasts (disabled Noclip Check)

-- Punishments
Config.Punishment = "respawn" -- (respawn, kick, ban) Punishment for failed check

-- Admins  (Use Player ID's)
Config.Admins = {}


-- ==== END OF SETTINGS ==== --

-- Functions
Config.toggleState = function(check, plr)
    local found = table.find(Config.Admins, plr)
    if found then
        if Config[check] ~= nil and type(Config[check]) == "boolean" then
		Config[check] = not Config[check]
        return Config[check]
	    end
    else
        return "No Permission"
    end
end


return Config