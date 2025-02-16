-- CREDIT TO FALLING WIND BY LOKINDY
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2816536934
-- had to change a ton of stuff to make it more reliable, add the glee touch

local math = math
local CurTime = CurTime

local function getVelocityBulletproof( ent, entTbl )
    local currPos = ent:WorldSpaceCenter()
    local currTime = CurTime()
    local oldPos
    local oldTime
    if ent:Alive() then -- no woosh when players spawn pls
        oldPos = entTbl.GLEE_AliveOldVelocityPos
        oldTime = entTbl.GLEE_AliveLastVelCheckTime
        entTbl.GLEE_AliveOldVelocityPos = currPos
        entTbl.GLEE_AliveLastVelCheckTime = currTime

    else
        oldPos = entTbl.GLEE_DeadOldVelocityPos
        oldTime = entTbl.GLEE_DeadLastVelCheckTime
        entTbl.GLEE_DeadOldVelocityPos = currPos
        entTbl.GLEE_DeadLastVelCheckTime = currTime

    end

    if not ( oldPos and oldTime ) then return end

    local deltaTime = math.abs( currTime - oldTime )

    local vel = currPos - oldPos
    vel = vel / deltaTime -- anchors vel to time, wont blow up when there's lag or anything

    return vel
end

if SERVER then
    resource.AddFile( "sound/fallingwind/glee_woosh0.wav" )
    resource.AddFile( "sound/fallingwind/glee_woosh1.wav" )
    resource.AddFile( "sound/fallingwind/custom/glee_mirrorsedge.wav" )

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
    glee_FallingWind.MinThreshold   = CreateClientConVar( "cl_fallingwind_minthreshold", "650", true, false, "", 0, nil )
    glee_FallingWind.MaxThreshold   = CreateClientConVar( "cl_fallingwind_maxthreshold", "1500", true, false, "", 1, nil )
    glee_FallingWind.VelXFactor     = CreateClientConVar( "cl_fallingwind_vfactorx", "1", true, false, "", 0, 1 )
    glee_FallingWind.VelYFactor     = CreateClientConVar( "cl_fallingwind_vfactory", "1", true, false, "", 0, 1 )
    glee_FallingWind.VelZFactor     = CreateClientConVar( "cl_fallingwind_vfactorz", "1", true, false, "", 0, 1 )

    hook.Add( "InitPostEntity", "glee_InitPostEntity_fallingwind", function()

        print( "FallingWind - Adding custom sounds..." )
        hook.Run( "fallingwind_AddCustomSounds", glee_FallingWind.SoundList )

        local sndCount = table.Count( glee_FallingWind.SoundList ) - 2
        print( "FallingWind - Adding custom sounds finished. Added " .. sndCount .. " sounds in total." )

    end )

    local nextThink = 0
    local vel_Averages = {}
    local average_Extent = 5
    local averagedVelocity = Vector()

    hook.Add( "Think", "glee_Think_fallingwind", function()

        local cur = CurTime()
        if nextThink > cur then return end
        nextThink = cur + math.Rand( 0.005, 0.01 )

        local me = LocalPlayer()
        local myTbl = me:GetTable()

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

        local obsTarg = me:GetObserverTarget()
        local velocity

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
                velocity = bonePhys:GetVelocity() * 1.5

            end
        elseif myObserverMode == OBS_MODE_CHASE and IsValid( obsTarg ) then
            velocity = getVelocityBulletproof( obsTarg, obsTarg:GetTable() )

        elseif myObserverMode == OBS_MODE_ROAMING then
            velocity = me:GetVelocity() * 0.6

        else
            velocity = getVelocityBulletproof( me, myTbl )

        end

        if not velocity then return end -- bulletproof returns nil when first called on an ent

        table.insert( vel_Averages, 1, velocity )

        -- average vel to stop ALL jitters, ALL buggy wind sound
        averagedVelocity.x = 0
        averagedVelocity.y = 0
        averagedVelocity.z = 0
        local count = 0
        local avgCount = 0

        for ind, currVel in pairs( vel_Averages ) do
            count = count + 1
            if count > average_Extent then
                table.remove( vel_Averages, ind )

            else
                avgCount = avgCount + 1
                averagedVelocity.x = averagedVelocity.x + currVel.x
                averagedVelocity.y = averagedVelocity.y + currVel.y
                averagedVelocity.z = averagedVelocity.z + currVel.z

            end
        end

        averagedVelocity = averagedVelocity / avgCount

        local velocityValueSqr = ( averagedVelocity * glee_FallingWind.VelFactorCache ):LengthSqr()

        local velocityProgress = 0
        if ( velocityValueSqr > glee_FallingWind.MinThreshold:GetInt() * glee_FallingWind.MinThreshold:GetInt() ) then

            if not ( glee_FallingWind.Sound:IsPlaying() ) then
                glee_FallingWind.Sound:PlayEx( 0, 100 )
            end
            local velocityValue = ( averagedVelocity * glee_FallingWind.VelFactorCache ):Length()

            velocityProgress = ( velocityValue - glee_FallingWind.MinThreshold:GetInt() ) / glee_FallingWind.MaxThreshold:GetInt()

            util.ScreenShake( me:GetPos(), velocityProgress, 25, 0.125, 0, true )

        end

        glee_FallingWind.Sound:ChangeVolume( glee_FallingWind.Volume:GetFloat() * math.Clamp( velocityProgress, 0, 1 ) )
        glee_FallingWind.Sound:ChangePitch( Lerp( velocityProgress, 40, 140 ) + math.sin( CurTime() ) * 10 )

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