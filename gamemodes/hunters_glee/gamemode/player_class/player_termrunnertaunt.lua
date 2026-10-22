AddCSLuaFile()

--
-- This is designed so you can call it like
--
-- tauntcam = TauntCamera()
--
-- Then you have your own copy.
--
function GLEE_TauntCamera()
    local CAM = {}

    local WasOn                    = false

    local CustomAngles            = angle_zero

    local InLerp                = 0
    local OutLerp                = 1

    --
    -- Draw the local player if we're active in any way
    --
    CAM.ShouldDrawLocalPlayer = function( _, _, on )
        return on or OutLerp < 1

    end

    --
    -- Implements the third person, rotation view (with lerping in/out)
    --
    CAM.CalcView = function( _, view, ply, on )

        if not ply:Alive() or not IsValid( ply:GetViewEntity() ) or ply:GetViewEntity() ~= ply then on = false end

        if WasOn ~= on then
            if on then
                InLerp = 0
                GAMEMODE:ResetOrbitDistance() -- each taunt starts from the default, not the last one's zoom

            end
            if not on then OutLerp = 0 end

            WasOn = on

        end

        if not on and OutLerp >= 1 then
            CustomAngles = view.angles * 1
            PlayerLockAngles = nil
            InLerp = 0
            return

        end

        if PlayerLockAngles == nil then return end

        -- the spectate camera's orbit, see cl_orbitcamera, around their eyes
        local TargetOrigin = GAMEMODE:GetOrbitOrigin( ply, view.origin, CustomAngles )

        if InLerp < 1 then
            InLerp = InLerp + FrameTime() * 5.0
            view.origin = LerpVector( InLerp, view.origin, TargetOrigin )
            view.angles = LerpAngle( InLerp, PlayerLockAngles, CustomAngles )
            return true

        end

        if OutLerp < 1 then
            OutLerp = OutLerp + FrameTime() * 3.0
            view.origin = LerpVector( 1-OutLerp, view.origin, TargetOrigin )
            view.angles = LerpAngle( 1-OutLerp, PlayerLockAngles, CustomAngles )
            return true

        end

        view.angles = CustomAngles * 1
        view.origin = TargetOrigin
        return true

    end

    --
    -- Freezes the player in position and uses the input from the user command to
    -- rotate the custom third person camera
    --
    CAM.CreateMove = function( _, cmd, ply, on )
        if not ply:Alive() then on = false end
        if not on then return end

        if PlayerLockAngles == nil then
            PlayerLockAngles = CustomAngles * 1
        end

        --
        -- Rotate our view
        --
        CustomAngles.pitch    = CustomAngles.pitch    + cmd:GetMouseY() * 0.01
        CustomAngles.yaw    = CustomAngles.yaw        - cmd:GetMouseX() * 0.01

        --
        -- Lock the player's controls and angles
        --
        cmd:SetViewAngles( CustomAngles )

        return true

    end

    return CAM

end