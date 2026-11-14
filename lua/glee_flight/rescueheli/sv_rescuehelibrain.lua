local rescueHeli = terminator_Extras.glee_RescueHeli
local gleeVehicles = terminator_Extras.gleeVehicles
local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator
local gleeFlightHeavies = terminator_Extras.gleeFlightHeavies

local debugging = rescueHeli.Debugging

local heli_RopeOriginOffset = Vector( -7.1, 50.8, -40.5 )

local callingHeliMaxs = rescueHeli.CallingHull
local callingHeliMins = -callingHeliMaxs

local function heliManageRope( self, state )
    local currGoal = state.currentHeliGoal
    local rapelling = IsValid( self.glee_RappelRopeStartProp )

    -- goal is to rescue, valid target too
    if currGoal == "rescue" and IsValid( state.currentRescueTarget ) then
        local nextRappelRope = state.nextRappelRope or 0
        if not rapelling and CurTime() >= nextRappelRope then
            local distToRescue = self:GetPos():Distance( state.currentRescueTarget:GetPos() )
            if distToRescue < glee_RappelSettings.ropeDropFromVehicleLength then
                state.nextRappelRope = CurTime() + 5
                DropRappelRopeFromVehicle( self, heli_RopeOriginOffset )

            end
        end
    -- lost our target, rescued everyone, basically time to leave
    elseif rapelling then
        RemoveRappelRopeFromVehicle( self )

    end
end

local function heliManageAngering( state )
    if CurTime() < state.nextAngerEverything then return end
    state.nextAngerEverything = CurTime() + 10

    rescueHeli.AngerEverything()

end

local function heliManageMissileAttacking( self, state, enemy )
    local nextFire = state.nextMissileFire
    if CurTime() < nextFire then return end

    if enemy:Health() <= 0 then return end

    local hostilesAroundEnemy = 0
    local friendliesAroundEnemy = 0
    for _, thing in ipairs( ents.FindInSphere( enemy:GetPos(), 1250 ) ) do
        if not ( thing:IsPlayer() or thing:IsNPC() or thing:IsNextBot() ) then continue end
        local dispToThing = self:Disposition( thing )
        if dispToThing == D_HT then
            hostilesAroundEnemy = hostilesAroundEnemy + 1

        elseif dispToThing == D_LI then
            friendliesAroundEnemy = friendliesAroundEnemy + 1

        end
    end

    if friendliesAroundEnemy > 0 then return end

    local stronk = gleeFlightHeavies.IsHeavy( enemy )
    -- shoot if lots of enemies, or enemy is tanky
    if not stronk and hostilesAroundEnemy < 2 then return end

    local missiles = state.missiles
    if not missiles or #missiles == 0 then return end
    for _, missile in ipairs( missiles ) do
        if not IsValid( missile ) then continue end
        if not IsValid( missile:GetParent() ) then continue end
        if not terminator_Extras.PosCanSeeComplex( missile:GetPos(), enemy:GetPos(), { self, missile } ) then continue end

        local missilesPreUnparentedPos = missile:GetPos()
        missile:SetParent( NULL )
        missile:SetPos( missilesPreUnparentedPos )
        missile:SetCollisionGroup( COLLISION_GROUP_PROJECTILE )

        local dirToEnemy = terminator_Extras.dirToPos( missilesPreUnparentedPos, enemy:GetPos() )
        missile:SetAngles( dirToEnemy:Angle() )

        terminator_Extras.ParentedDetailFallOff( self, missile )

        missile:MissileActivate()
        state.nextMissileFire = CurTime() + 15
        break

    end
end

local vecUp400 = Vector( 0, 0, 400 )
local vecUp200 = Vector( 0, 0, 200 )

local function heliLookForFlares( self, state )
    local myPos = self:GetPos()
    local flares = {}
    local allFlares = ents.FindByClass( "termhunt_flare" )
    local allSignalFlares = ents.FindByClass( "termhunt_signalflare" )
    terminator_Extras.tableAdd( flares, allFlares )
    terminator_Extras.tableAdd( flares, allSignalFlares )

    if #flares > 0 then
        local positions = {}
        for _, flare in ipairs( flares ) do
            positions[flare] = flare:GetPos()

        end
        table.sort( flares, function( a, b )
            return myPos:Distance( positions[a] ) < myPos:Distance( positions[b] )

        end )
        for i = 1, math.min( #flares, 5 ) do
            local flare = flares[i]
            if not IsValid( flare ) then continue end
            if not self:Visible( flare ) then continue end
            state.lastSawAFlarePos = positions[flare] + vecUp200

            if debugging:GetBool() then
                debugoverlay.Line( myPos, state.lastSawAFlarePos, 1, Color( 255, 0, 255 ), true )

            end
            return

        end
    end
end

function rescueHeli.Think( self )
    local state = self.glee_RescueHeliState
    local rescueTarget = state.currentRescueTarget
    local lastSwitchRescueTarget = state.lastSwitchRescueTarget or 0
    local myPos = self:GetPos()
    local ourVel = gleeFlightNavigator.UpdateVelocity( self )

    -- keep everyone's standing current; divine_chosen can be gained or lost mid round
    for _, ply in player.Iterator() do
        rescueHeli.UpdatePlayerRelationship( self, ply )

    end

    local validRescueTarget = IsValid( rescueTarget ) and rescueTarget:Alive()
    local visibleRescueTarget = validRescueTarget and self:Visible( rescueTarget )
    local oldValidSpeedyRescueTarget = validRescueTarget and ( CurTime() - lastSwitchRescueTarget ) > 20 and rescueTarget:GetVelocity():Length() >= 400
    local trySwitchRescueTarget = not validRescueTarget or not visibleRescueTarget or oldValidSpeedyRescueTarget
    local obscuredRescueTarget = validRescueTarget and not visibleRescueTarget and myPos:Distance( rescueTarget:GetPos() ) > 3500
    local rescuedRescueTarget = validRescueTarget and gleeVehicles.IsRiding( rescueTarget, self )
    local badRescueTarget = not validRescueTarget or obscuredRescueTarget or rescuedRescueTarget

    if validRescueTarget and visibleRescueTarget then
        state.lastSawARescueTargetPos = rescueTarget:GetPos()

    end
    if badRescueTarget then
        state.currentRescueTarget = nil
        state.lastSwitchRescueTarget = 0
        rescueTarget = nil

    end
    if trySwitchRescueTarget then
        local closestDist = math.huge
        for _, ply in player.Iterator() do
            if not ply:Alive() then continue end
            if rescueHeli.WontRescue( self, ply ) then continue end
            local plysPos = ply:GetShootPos()
            local dist = myPos:Distance( plysPos )
            if dist > closestDist then continue end
            if not terminator_Extras.PosCanSeeComplex( myPos, plysPos, self ) then continue end
            if gleeVehicles.IsRiding( ply, self ) then continue end

            rescueTarget = ply
            closestDist = dist

        end
        if IsValid( rescueTarget ) then
            state.currentRescueTarget = rescueTarget
            state.lastSwitchRescueTarget = CurTime()

        end
    end

    local currEnemy = self:GetEnemy()
    if IsValid( currEnemy ) then
        if currEnemy.ReallyAnger and not currEnemy:IsAngry() then
            currEnemy:ReallyAnger( 30 )

        end

        rescueHeli.MakeFeudWith( self, currEnemy )

        local enemysPos = currEnemy:GetPos()

        local visibleEnem = self:Visible( currEnemy )
        local facingEnemy = self:GetForward():Dot( ( enemysPos - myPos ):GetNormalized() ) > 0.97

        if not visibleEnem then
            self:SetEnemy( NULL )

        elseif facingEnemy then
            heliManageMissileAttacking( self, state, currEnemy )

        end
    end

    -- after the relationship updates and feuds above, they'd knock it back down
    gleeFlightHeavies.PrioritizeKnownHeavies( self )

    local idealMovePos
    local skysTheLimit
    local currentTargPosName
    local wandering

    local currGoal = state.currentHeliGoal
    -- fly towards originalRescuePos
    -- then once we get close
    -- start flying to rescue target
    -- OR fly to where we last saw one
    -- OR fly to sound hint
    if currGoal == "rescue" then
        local noPlayersNeedRescuing = true
        local someoneRescuable = nil
        for _, ply in player.Iterator() do
            if not ply:Alive() then continue end
            if rescueHeli.WontRescue( self, ply ) then continue end
            someoneRescuable = true

            if gleeVehicles.IsRiding( ply, self ) then continue end
            noPlayersNeedRescuing = false
            break

        end
        -- bail
        if CurTime() > state.giveUpAndRunAwayTime then
            state.currentHeliTask = "rescue_switchToEscape"
            state.currentHeliGoal = "escape"
            huntersGlee_AnnounceDramatic( player.GetAll(), 502, 5, "Rescue is leaving, it's been here too long..." )
            if GAMEMODE.IsReallyHuntersGlee then
                GAMEMODE:SendMusic( "tracks/heliLateLeave" )

            end
        elseif self:Health() < self:GetMaxHealth() * 0.5 then
            state.currentHeliTask = "rescue_switchToEscape"
            state.currentHeliGoal = "escape"
            huntersGlee_AnnounceDramatic( player.GetAll(), 502, 5, "Rescue op SCRAMBLED, too much resistance!" )

        elseif noPlayersNeedRescuing then
            state.currentHeliTask = "rescue_switchToEscape"
            state.currentHeliGoal = "escape"
            if someoneRescuable then
                huntersGlee_AnnounceDramatic( player.GetAll(), 502, 5, "Rescue is departing!\nAll souls aboard!" )
                local function isAboard( ply )
                    return gleeVehicles.IsRiding( ply, self )

                end
                if GAMEMODE.IsReallyHuntersGlee and GAMEMODE:IsBoonable( isAboard ) then
                    GAMEMODE:SendMusic( "tracks/heliLeaveAllSoulsBoonSoon" )

                end

            else
                huntersGlee_AnnounceDramatic( player.GetAll(), 502, 5, "Rescue is departing!\nThere's nobody left to save..." )

            end
        elseif gleeVehicles.AllSeatsFull( self ) then
            state.currentHeliTask = "rescue_switchToEscape"
            state.currentHeliGoal = "escape"
            huntersGlee_AnnounceDramatic( player.GetAll(), 502, 5, "Rescue is pulling out!\nIt's full..." )

        elseif IsValid( rescueTarget ) and rescueTarget:GetNWEntity( "glee_RappelSourceEnt", NULL ) == self then
            state.currentHeliTask = "rescue_waitForRescueTargetToRappel"
            idealMovePos = myPos

        -- approach rescue target!
        elseif IsValid( rescueTarget ) then
            state.currentHeliTask = "rescue_approachRescueTarget"

            local rescueTargetsPos = rescueTarget:GetPos()
            local floorOfRescueTarget = terminator_Extras.getFloorTr( rescueTargetsPos ).HitPos
            idealMovePos = floorOfRescueTarget + vecUp400

            -- go way above them if they're on the ground, just a bit above if they're high up
            idealMovePos.z = math.max( idealMovePos.z, rescueTargetsPos.z + 200 )

        elseif state.originalRescuePos then
            currentTargPosName = "originalRescuePos"
            state.currentHeliTask = "rescue_flyToFlare"

            local distToOriginalRescuePos = myPos:Distance( state.originalRescuePos )
            if self:VisibleVec( state.originalRescuePos ) and distToOriginalRescuePos < 3000 then
                state.originalRescuePos = nil

            elseif distToOriginalRescuePos < 1500 then
                state.originalRescuePos = nil

            else
                idealMovePos = state.originalRescuePos

            end

        -- fly towards last place we saw a rescue target
        elseif state.lastSawARescueTargetPos then
            currentTargPosName = "lastSawARescueTargetPos"
            state.currentHeliTask = "rescue_approachLastSeenRescueTarget"

            heliLookForFlares( self, state )

            local distToLastSaw = myPos:Distance( state.lastSawARescueTargetPos )
            if self:VisibleVec( state.lastSawARescueTargetPos ) and distToLastSaw < 1500 then
                state.lastSawARescueTargetPos = nil

            elseif distToLastSaw < 800 then
                state.lastSawARescueTargetPos = nil

            else
                idealMovePos = state.lastSawARescueTargetPos + vecUp200 + VectorRand() * 200

            end
        -- a flare was shot up, and we saw it, check it out!
        elseif state.lastSawAFlarePos then
            currentTargPosName = "lastSawAFlarePos"
            state.currentHeliTask = "rescue_approachLastSeenFlare"

            local distToFlare = myPos:Distance( state.lastSawAFlarePos )
            if self:VisibleVec( state.lastSawAFlarePos ) and distToFlare < 1500 then
                state.lastSawAFlarePos = nil

            elseif distToFlare < 800 then
                state.lastSawAFlarePos = nil

            else
                idealMovePos = state.lastSawAFlarePos + vecUp200 + VectorRand() * 200

            end
        -- go towards last sound hint
        elseif state.lastHeardSoundPos then
            currentTargPosName = "lastHeardSoundPos"
            state.currentHeliTask = "rescue_approachSoundHint"

            heliLookForFlares( self, state )

            idealMovePos = state.lastHeardSoundPos + vecUp200 + VectorRand() * 200

            local distToHint = myPos:Distance( state.lastHeardSoundPos )
            if self:VisibleVec( state.lastHeardSoundPos ) and distToHint < 1500 then
                state.lastHeardSoundPos = nil

            elseif distToHint < 800 then
                state.lastHeardSoundPos = nil

            end

        -- nothing to go on, hang around where players have been
        else
            wandering = true
            state.currentHeliTask = "rescue_wander"

            heliLookForFlares( self, state )

            idealMovePos = gleeFlightNavigator.WanderPos( self )

        end
    -- fly towards any skybox surfaces next to us
    -- if no skybox surfaces, fly towards where we spawned
    elseif currGoal == "escape" then
        local escapePos
        local nearestSkyboxPos = state.nearestSkyboxPos
        local nearestSkyboxDir = state.nearestSkyboxDir
        local attempts = 12
        local trStruc = {
            start = myPos,
            endpos = nil,
            mask = MASK_NPCSOLID_BRUSHONLY,
            mins = Vector( callingHeliMins, callingHeliMins, callingHeliMins / 4 ),
            maxs = Vector( callingHeliMaxs, callingHeliMaxs, callingHeliMaxs / 4 ),

        }

        -- first dir is towards where we're going
        local dir = ourVel:GetNormalized()
        local offset

        for _ = 1, attempts do
            offset = dir * 40000
            trStruc.endpos = myPos + offset

            local trResult = util.TraceHull( trStruc )

            -- followup ones are random directions
            dir = VectorRand()
            dir.z = math.Rand( -0.25, 0.25 ) -- dont look upwards
            dir:Normalize()

            if not trResult.HitSky then continue end

            local myDistToNew = myPos:Distance( trResult.HitPos )
            if gleeFlightNavigator.RayHitsTriggerPush( myPos, offset ) then -- STRONGLY avoid trigger_push(es)
                myDistToNew = myDistToNew * 10

            end

            if not nearestSkyboxPos or myDistToNew < myPos:Distance( nearestSkyboxPos ) then
                if debugging:GetBool() then
                    debugoverlay.Line( myPos, trResult.HitPos, 1, Color( 255, 255, 0 ), true )

                end
                nearestSkyboxPos = trResult.HitPos
                state.nearestSkyboxPos = nearestSkyboxPos
                nearestSkyboxDir = trResult.Normal
                state.nearestSkyboxDir = nearestSkyboxDir

            end
        end
        if nearestSkyboxPos then
            if debugging:GetBool() then
                debugoverlay.Line( myPos, nearestSkyboxPos, 1, Color( 255, 100, 0 ) )

            end
            state.currentHeliTask = "rescue_flyToBestSkybox"

            idealMovePos = nearestSkyboxPos + nearestSkyboxDir * 2000
            escapePos = nearestSkyboxPos
            skysTheLimit = true

        else
            local arrivedFromPos = state.rescueHeliArrivedFromPos
            if debugging:GetBool() then
                debugoverlay.Line( myPos, arrivedFromPos, 1, Color( 100, 255, 0 ) )

            end
            state.currentHeliTask = "rescue_flyToWhereWeArrived"

            idealMovePos = Vector( arrivedFromPos.x, arrivedFromPos.y, arrivedFromPos.z )
            escapePos = idealMovePos

        end

        if escapePos then
            local distAdd = ourVel:Length() / 1.5 -- at 1000 speed, add 750
            local startAddingDistSpeed = 400
            distAdd = math.max( 0, distAdd - startAddingDistSpeed )
            distAdd = distAdd + ( gleeFlightNavigator.GetUnstuckDist( self ) * 4 ) -- if stuck and not moving, add more dist
            if myPos:Distance( escapePos ) < 300 + distAdd then
                gleeVehicles.Depart( self )

            end
        end
    end

    heliManageRope( self, state )
    heliManageAngering( state )

    if debugging:GetBool() then
        debugoverlay.Text( myPos, state.currentHeliTask, 1 )

    end

    if idealMovePos then
        local lostProgress = gleeFlightNavigator.Steer( self, idealMovePos, skysTheLimit )
        if lostProgress and currentTargPosName then
            state[currentTargPosName] = nil

        elseif lostProgress and wandering then
            gleeFlightNavigator.RestartWander( self )

        end
    end
end
