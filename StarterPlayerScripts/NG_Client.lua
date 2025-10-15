local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local usi = game:GetService("UserInputService")
local click = ReplicatedStorage:WaitForChild("RemoteFolder"):WaitForChild("NG_Click")
local plr = Players.LocalPlayer
local getVals = ReplicatedStorage:WaitForChild("RemoteFolder"):WaitForChild("NG_GetVals")

getVals.OnClientInvoke = function(key)
    local char = plr.Character
    if not char then
        return { key = key }
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then
        return { key = key }
    end

    local gravity = workspace.Gravity
    local humState = hum:GetState()

    return {
        speed = hum.WalkSpeed,
        jumpPower = hum.JumpPower,
        jumpHeight = hum.JumpHeight,
        velocity = hrp.AssemblyLinearVelocity,
        position = hrp.Position,
        orientation = hrp.Orientation,
        rotation = hrp.Rotation,
        health = hum.Health,
        maxHealth = hum.MaxHealth,
        isJumping = humState == Enum.HumanoidStateType.Jumping,
        isFalling = humState == Enum.HumanoidStateType.Freefall,
        isSitting = humState == Enum.HumanoidStateType.Seated,
        noPhysics = humState == Enum.HumanoidStateType.RunningNoPhysics or humState == Enum.HumanoidStateType.StrafingNoPhysics,
        equippedTool = char:FindFirstChildOfClass("Tool") and char:FindFirstChildOfClass("Tool").Name or nil,
        gravity = gravity,
        isClimbing = humState == Enum.HumanoidStateType.Climbing,
        isSwimming = humState == Enum.HumanoidStateType.Swimming,
        isFlying = hrp.Velocity.Y > 0 and humState == Enum.HumanoidStateType.Freefall,
        key = key
    }
end


usi.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input == Enum.UserInputType.MouseButton1 then
        click:FireServer()
    end
end)