
local function DoFlashlight( state )
    local me = LocalPlayer()
    local timerName = "glee_spectateflashlight" .. LocalPlayer():EntIndex()
    --turn on the light!
    if state == false then
        me.glee_HasDoneSpectateFlashlight = true
        me:EmitSound( "HL2Player.FlashLightOn" )
        timer.Create( timerName, 0, 0, function()
            if me:Health() > 0 then timer.Remove( timerName ) return end
            local dir = me:GetAimVector()
            local start = me:GetShootPos()
            local trResult = util.QuickTrace( start, dir * 150, me:GetObserverTarget() )

            local lightPos = trResult.HitPos + ( -dir * 50 )
            if trResult.StartSolid then
                lightPos = start + dir * 100

            end

            -- need this to stop a super terrible flashing effect
            local dieTime = me:Ping() / 150
            dieTime = math.max( 0.5, dieTime )

            local dlight = DynamicLight( me:EntIndex() + player.GetCount() )
            if dlight then
                me.glee_spectateflashlight = dlight
                dlight.pos = lightPos
                dlight.r = 190
                dlight.g = 255
                dlight.b = 190
                dlight.brightness = 0.8
                dlight.size = 2000
                dlight.dietime = CurTime() + dieTime

            end
        end )
    --turn it off!
    else
        timer.Remove( timerName )
        me:EmitSound( "HL2Player.FlashLightOff" )
        me.glee_spectateflashlight.dietime = 0

    end
end

local flashlightBind
local flashlightButtonCode
local nextFlashlightSwitch = 0

local flashlightState = false

hook.Add( "PlayerButtonDown", "glee_readflashlight", function( ply, button )
    if not flashlightButtonCode then
        flashlightBind = input.LookupBinding( "impulse 100", false )
        -- they unbound it
        if not flashlightBind then return end

        flashlightButtonCode = input.GetKeyCode( flashlightBind )
        return

    end

    if flashlightButtonCode ~= button then return end

    if ply:Health() > 0 then return end
    if nextFlashlightSwitch > CurTime() then return end

    nextFlashlightSwitch = CurTime() + 0.25

    DoFlashlight( flashlightState )
    flashlightState = not flashlightState

end )