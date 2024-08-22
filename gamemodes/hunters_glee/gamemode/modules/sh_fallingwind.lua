-- copied falling wind, fixed style + a bug with spectating
-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=2816536934

if SERVER then
    resource.AddFile( "sound/fallingwind/glee_woosh0.wav" )
    resource.AddFile( "sound/fallingwind/glee_woosh1.wav" )
    resource.AddFile( "sound/fallingwind/custom/glee_mirrorsedge.wav" )

    util.AddNetworkString( "glee_fallingwind_requestVehicleSpeed" )
    util.AddNetworkString( "glee_fallingwind_sendVehicleSpeed" )
    util.AddNetworkString( "glee_fallingwind_fallingfast" )

    net.Receive( "glee_fallingwind_requestVehicleSpeed", function( _, ply )
        if not IsValid( ply ) then return end
        local vehicle = ply:GetVehicle()
        if not ply:InVehicle() or not IsValid( vehicle ) then return end

        for _ = 1, 15 do
            local parent = vehicle:GetParent()
            if IsValid( parent ) then
                vehicle = parent

            else
                break

            end
        end

        -- print("sv - sending vehicle speed")
        net.Start( "glee_fallingwind_sendVehicleSpeed" )
            -- This gets compressed, but since it's a velocity,
            -- it shouldn't matter much
            net.WriteVector( vehicle:GetVelocity() )

        net.Send( ply )
    end )

    -- panic when falling fast!
    net.Receive( "glee_fallingwind_fallingfast", function( _, ply )
        if not IsValid( ply ) then return end
        local nextPanic = ply.glee_NextVelPanic or 0
        if nextPanic > CurTime() then return end
        ply.glee_NextVelPanic = CurTime() + 0.1

        local vel = ply:GetVelocity()
        local leng = vel:Length()

        if math.abs( vel.z ) <= 400 then return end
        GAMEMODE:GivePanic( ply, leng / 50 )

    end )
end

if CLIENT then
    glee_FallingWind = {}
    glee_FallingWind.Sound          = nil
    glee_FallingWind.SoundList      = {}
    glee_FallingWind.Enable         = CreateClientConVar( "cl_fallingwind_enable", "1", true, false, "", 0, 1 )
    glee_FallingWind.SoundID        = CreateClientConVar( "cl_fallingwind_soundid", "fallingwind/glee_woosh0.wav", true, false, "" )
    glee_FallingWind.StopVehicle    = CreateClientConVar( "cl_fallingwind_stop_in_vehicle", "0", true, false, "", 0, 1 )
    glee_FallingWind.DoShake        = CreateClientConVar( "cl_fallingwind_shake", "1", true, false, "", 0, 1 )
    glee_FallingWind.Volume         = CreateClientConVar( "cl_fallingwind_volume", "0.75", true, false, "", 0, 1 )
    glee_FallingWind.MinThreshold   = 526 -- exact number that mp_falldamage 1 starts damaging at
    glee_FallingWind.MaxThreshold   = CreateClientConVar( "cl_fallingwind_maxthreshold", "1500", true, false, "", 1, nil )
    glee_FallingWind.VelXFactor     = CreateClientConVar( "cl_fallingwind_vfactorx", "1", true, false, "", 0, 1 )
    glee_FallingWind.VelYFactor     = CreateClientConVar( "cl_fallingwind_vfactory", "1", true, false, "", 0, 1 )
    glee_FallingWind.VelZFactor     = CreateClientConVar( "cl_fallingwind_vfactorz", "1", true, false, "", 0, 1 )
    glee_FallingWind.LocalPlayer_VehicleCache = true
    glee_FallingWind.LocalPlayer_VehicleSpeedCache = nil
    glee_FallingWind.VelFactorCache = nil

    local nextSend = 0

    net.Receive( "glee_fallingwind_sendVehicleSpeed", function()
        local vehicleSpeed = net.ReadVector()
        if not vehicleSpeed then return end
        -- print("cl - got vehicle velocity")
        glee_FallingWind.LocalPlayer_VehicleSpeedCache = vehicleSpeed

    end )

    hook.Add( "InitPostEntity", "glee_InitPostEntity_fallingwind", function()

        print( "FallingWind - Adding custom sounds..." )
        hook.Run( "fallingwind_AddCustomSounds", glee_FallingWind.SoundList )

        local sndCount = table.Count( glee_FallingWind.SoundList ) - 2
        print( "FallingWind - Adding custom sounds finished. Added " .. sndCount .. " sounds in total." )

    end )

    hook.Add( "Think", "glee_Think_fallingwind", function()

        local me = LocalPlayer()

        if not glee_FallingWind.Enable:GetBool() or not IsValid( me ) then return end

        if not glee_FallingWind.Sound then

            if string.len( glee_FallingWind.SoundID:GetString() ) == 1 then
                if glee_FallingWind.SoundID:GetInt() == 1 then
                    glee_FallingWind.SoundID:SetString( "fallingwind/glee_woosh1.wav" )
                elseif glee_FallingWind.SoundID:GetInt() == 2 then
                    glee_FallingWind.SoundID:SetString( "fallingwind/custom/glee_mirrorsedge.wav" )
                else
                    glee_FallingWind.SoundID:Revert()
                end
            end

            glee_FallingWind.Sound = CreateSound( me, glee_FallingWind.SoundID:GetString() )
        end

        if not glee_FallingWind.VelFactorCache then
            glee_FallingWind.VelFactorCache = Vector( glee_FallingWind.VelXFactor:GetFloat(), glee_FallingWind.VelYFactor:GetFloat(), glee_FallingWind.VelZFactor:GetFloat() )
        end

        -- Stop sound when in noclip
        local noclipping = me:GetMoveType() == MOVETYPE_NOCLIP and not me:InVehicle()
        local doStop = noclipping
        if doStop then
            glee_FallingWind.Sound:Stop()
            return
        end

        -- We first get the velocity of the player entity, in case everything else returns false
        local Velocity = me:GetVelocity()

        -- Check if the player ragdoll is valid, if so use velocity of
        -- one of it's bones instead of the player.
        local rgObj = me:GetRagdollEntity()
        local myObserverMode = me:GetObserverMode()
        if not me:Alive() and myObserverMode == OBS_MODE_DEATHCAM and IsValid( rgObj ) and rgObj:GetPhysicsObjectCount() > 0 then
            local bonePhys = nil
            local boneNamesToTry = {
                "ValveBiped.Bip01_Head1",
                "ValveBiped.Bip01_Neck1",
                "ValveBiped.Bip01_Spine2",
                "ValveBiped.Bip01_Pelvis"
            }

            -- find a bone
            for _,boneName in pairs( boneNamesToTry ) do
                if IsValid( bonePhys ) then continue end

                local boneID = rgObj:LookupBone( boneName )
                if not boneID then continue end

                local bonePhysObjID = rgObj:TranslateBoneToPhysBone( boneID )
                if bonePhysObjID == -1 then continue end

                -- Get the physics object of the bone using the bone's ID in the ragdoll object
                bonePhys = rgObj:GetPhysicsObjectNum( bonePhysObjID )

                if IsValid( bonePhys ) then
                    break
                end
            end

            -- got a bone to pick!
            if IsValid( bonePhys ) then
                -- Ragdolls terminal velocity is around 1038, while the player's is 3500. scale properly
                Velocity = bonePhys:GetVelocity() * 1.5
            end
        elseif myObserverMode == OBS_MODE_CHASE and IsValid( me:GetObserverTarget() ) then
            Velocity = me:GetObserverTarget():GetVelocity()

        elseif myObserverMode == OBS_MODE_ROAMING then
            Velocity = Velocity * 0.5

        -- Check if the player is inside a vehicle, if so use it's velocity instead
        elseif me:InVehicle() and IsValid( me:GetVehicle() ) then
            glee_FallingWind.LocalPlayer_VehicleCache = true

            local nextOne = glee_FallingWind.nextCacheRequest or 0
            if nextOne < CurTime() then
                glee_FallingWind.nextCacheRequest = CurTime() + 0.1
                -- Request velocity of the vehicle to the server
                net.Start( "glee_fallingwind_requestVehicleSpeed" )
                -- print("cl - requesting vehicle speed")
                net.SendToServer()

            end

            -- Only use the velocity after we get it
            if glee_FallingWind.LocalPlayer_VehicleSpeedCache then
                Velocity = glee_FallingWind.LocalPlayer_VehicleSpeedCache

            end
        end

        if glee_FallingWind.LocalPlayer_VehicleCache and not me:InVehicle() then
            -- If the player exists the vehicle at high speed, that speed will be stored
            -- when they enter another vehicle, causing a bit of the sound to be heard
            glee_FallingWind.LocalPlayer_VehicleCache = false
            glee_FallingWind.LocalPlayer_VehicleSpeedCache = nil

        end

        local VelocityValueSqr =  ( Velocity * glee_FallingWind.VelFactorCache ):LengthSqr()
        local VelocityProgress = 0

        if ( VelocityValueSqr > glee_FallingWind.MinThreshold * glee_FallingWind.MinThreshold ) then
            if nextSend < CurTime() then
                nextSend = CurTime() + 0.25
                net.Start( "glee_fallingwind_fallingfast" )
                net.SendToServer()

            end

            if not ( glee_FallingWind.Sound:IsPlaying() ) then
                glee_FallingWind.Sound:PlayEx( 0, 100 )
            end
            local VelocityValue = ( Velocity * glee_FallingWind.VelFactorCache ):Length()

            VelocityProgress = ( VelocityValue - glee_FallingWind.MinThreshold ) / glee_FallingWind.MaxThreshold:GetInt()

            util.ScreenShake( me:GetPos(), VelocityProgress, 25, 0.125, 0, true )
        end

        glee_FallingWind.Sound:ChangeVolume( glee_FallingWind.Volume:GetFloat() * math.Clamp( VelocityProgress, 0, 1 ) )
        glee_FallingWind.Sound:ChangePitch( Lerp( VelocityProgress, 40, 140 ) + math.sin( CurTime() ) * 10 )

    end )

    -- Add sounds
    table.insert( glee_FallingWind.SoundList, {
        file_path = "fallingwind/glee_woosh0.wav",
        name = "Portal 2",
        author = "Liokindy"
    } )
    table.insert( glee_FallingWind.SoundList, {
        file_path = "fallingwind/glee_woosh1.wav",
        name = "Portal 1",
        author = "Liokindy"
    } )
    table.insert( glee_FallingWind.SoundList, {
        file_path = "fallingwind/custom/glee_mirrorsedge.wav", -- Path to the sound
        name = "Mirror's Edge", -- Name to show in the list
        author = "Liokindy" -- Author name, not used right now
    } )


    -- Con-Vars
    cvars.AddChangeCallback( "cl_fallingwind_soundid", function()
        -- Make the sound regenerate
        if ( glee_FallingWind.Sound ) then
            glee_FallingWind.Sound:Stop()
            glee_FallingWind.Sound = nil
        end
    end )
    cvars.AddChangeCallback( glee_FallingWind.VelXFactor:GetName(), function()
        glee_FallingWind.VelFactorCache = Vector( glee_FallingWind.VelXFactor:GetFloat(), glee_FallingWind.VelYFactor:GetFloat(), glee_FallingWind.VelZFactor:GetFloat() )
    end )
    cvars.AddChangeCallback( glee_FallingWind.VelYFactor:GetName(), function()
        glee_FallingWind.VelFactorCache = Vector( glee_FallingWind.VelXFactor:GetFloat(), glee_FallingWind.VelYFactor:GetFloat(), glee_FallingWind.VelZFactor:GetFloat() )
    end )
    cvars.AddChangeCallback( glee_FallingWind.VelZFactor:GetName(), function()
        glee_FallingWind.VelFactorCache = Vector( glee_FallingWind.VelXFactor:GetFloat(), glee_FallingWind.VelYFactor:GetFloat(), glee_FallingWind.VelZFactor:GetFloat() )
    end )
end