getVals.OnClientInvoke = function()
    local gravity = workspace.Gravity
    local rootVelocity = hrp.Velocity
    local humState = hum:GetState()

    return {
        -- Movement
        speed = hum.WalkSpeed,
        jumpPower = hum.JumpPower,
        jumpHeight = (hum.JumpPower ^ 2) / (2 * gravity),
        velocity = hrp.Velocity,
        position = hrp.Position,
        orientation = hrp.Orientation,
        rotation = hrp.Rotation,

        -- Status
        health = hum.Health,
        maxHealth = hum.MaxHealth,
        isJumping = humState == Enum.HumanoidStateType.Jumping,
        isFalling = humState == Enum.HumanoidStateType.Freefall,
        isSitting = humState == Enum.HumanoidStateType.Seated,
        noPhysics = humState == Enum.HumanoidStateType.RunningNoPhysics or humState == Enum.HumanoidStateType.StrafingNoPhysics,

        -- Tools / Inventory
        equippedTool = plr.Character:FindFirstChildOfClass("Tool") and plr.Character:FindFirstChildOfClass("Tool").Name or nil,

        -- Misc
        gravity = gravity,
        isClimbing = humState == Enum.HumanoidStateType.Climbing,
        isSwimming = humState == Enum.HumanoidStateType.Swimming,
        isFlying = hrp.Velocity.Y > 0 and humState == Enum.HumanoidStateType.Freefall 
    }
end
