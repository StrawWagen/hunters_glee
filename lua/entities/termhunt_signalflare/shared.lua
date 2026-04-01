AddCSLuaFile()

DEFINE_BASECLASS( "termhunt_flare" )

local GAMEMODE = GAMEMODE or GM

ENT.Category    = "Hunter's Glee"
ENT.PrintName   = "Signal Flare"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Flares"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/plates/plate.mdl"

local className = "termhunt_signalflare"
if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, className, "vgui/hud/killicon/" .. className .. ".png" )

end

--sandbox support
function ENT:SpawnFunction( ply, tr )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 20

    local ent = ents.Create( "termhunt_signalflare" )
    ent:Spawn()
    ent:SetPos( SpawnPos )
    ent:SetOwner( ply )

    return ent

end

if SERVER and terminator_Extras then

    local function angerEverything()
        for _, ent in ents.Iterator() do
            if not ent.ReallyAnger then continue end
            ent:ReallyAnger( 120 )

        end
    end

    local zHeightToStartCalling = 500

    local heli_SpeedLimit = 4000
    local heli_CloseToObstacleSpeedLimit = 250
    local heli_TooFarFromGround = 1250
    local heli_TooCloseToGround = 300

    local callingHeliMaxs = 350
    local callingHeliMins = -callingHeliMaxs

    local tightHeliMaxs = 225
    local tightHeliMins = -tightHeliMaxs

    function ENT:AdditionalThink()
        if self.calledForHeli then return end
        if IsValid( terminator_Extras.glee_CurrentRescueHeli ) then return end

        local myPos = self:GetPos()
        local floorResult = terminator_Extras.getFloorTr( myPos )

        local heightOffGround = floorResult.HitPos:Distance( myPos )

        if heightOffGround < zHeightToStartCalling then return end

        local randDir = VectorRand()
        randDir.z = math.Rand( -0.05, 0.25 ) -- dont call heli upwards

        local traceData = {
            start = myPos,
            endpos = myPos + randDir * 20000,
            mask = MASK_SOLID_BRUSHONLY,
            mins = Vector( callingHeliMins, callingHeliMins, callingHeliMins / 4 ),
            maxs = Vector( callingHeliMaxs, callingHeliMaxs, callingHeliMaxs / 4 ),

        }
        local callTraceResult = util.TraceHull( traceData )
        if not callTraceResult.HitSky then return end

        if callTraceResult.HitPos:Distance( myPos ) < 400 then return end -- too close!

        local heli = terminator_Extras.glee_SpawnTheRescueHeli( callTraceResult.HitPos, callTraceResult.HitNormal, myPos )
        if not IsValid( heli ) then return end

        self.calledForHeli = true

        angerEverything()

    end

    local function makeHeliFriendlyWith( heli, thing )
        if not IsValid( heli ) then return end
        if not IsValid( thing ) then return end
        heli:AddEntityRelationship( thing, D_LI, 99 )

    end

    local function manageHeliSpeedLimit( heli )
        local newSpeed = heli_SpeedLimit

        local heliVel = heli:GetVelocity()
        local heliDir = heliVel:GetNormalized()
        local curSpeed = heliVel:Length()

        if curSpeed <= 150 then
            heliDir = heli:GetForward()

        end

        local helisPos = heli:GetPos()

        local blockedTrData = {
            start = helisPos,
            endpos = helisPos + heliDir * curSpeed * 1.5,
            mask = MASK_SOLID,
            mins = Vector( callingHeliMins, callingHeliMins, callingHeliMins / 4 ),
            maxs = Vector( callingHeliMaxs, callingHeliMaxs, callingHeliMaxs / 4 ),

        }
        local blockedTrResult = util.TraceHull( blockedTrData )
        if blockedTrResult.Hit then
            newSpeed = heli_CloseToObstacleSpeedLimit

        end
        heli:SetKeyValue( "m_flPathMaxSpeed", newSpeed )

    end

    local heli_TryAndRescueDuration = 120
    -- try and find people for 2 minutes
    -- afterwards we switch to flying towards any skybox we can find, or where we spawned

    function terminator_Extras.glee_SpawnTheRescueHeli( spawnPos, faceDir, targetPos )
        local heli = ents.Create( "npc_helicopter" )
        if not IsValid( heli ) then return end

        local track = ents.Create( "path_track" )
        if not IsValid( track ) then
            SafeRemoveEntity( heli )
            return
        end

        heli:SetPos( spawnPos )
        heli:SetAngles( faceDir:Angle() )

        -- fly towards valuable sounds when wandering
        terminator_Extras.RegisterListener( heli )
        function heli:SaveSoundHint( source, valuable, emitterEnt )
            if not valuable then return end
            if IsValid( emitterEnt ) and not emitterEnt:IsPlayer() then return end
            self.lastHeardSoundPos = source

        end


        manageHeliSpeedLimit( heli )
        heli:Fire( "MoveTopSpeed", 1, 0.1 )

        track:SetPos( targetPos )

        heli.ourPathTrack = track
        track.glee_HeliTrack_TargetName = "glee_rescuehelipath_" .. heli:GetCreationID()
        track:SetKeyValue( "targetname", track.glee_HeliTrack_TargetName )

        heli.glee_HeliTrack_TargetName = track.glee_HeliTrack_TargetName


        heli:Spawn()
        heli:Activate()

        heli:SetSubMaterial( 0, "models/glee/rebelheli/combine_helicopter01" )
        for _, ply in player.Iterator() do
            makeHeliFriendlyWith( heli, ply )

        end

        heli:Fire( "SetTrack", track.glee_HeliTrack_TargetName )

        heli.isGleeRescueHeli = true
        heli.giveUpAndRunAwayTime = CurTime() + heli_TryAndRescueDuration
        heli.rescueHeliArrivedFromPos = spawnPos
        heli.originalRescuePos = targetPos
        heli.currentHeliGoal = "rescue"
        heli.nextAngerEverything = CurTime() + 10

        heli.glee_PrettyName = "Rescue Heli"

        local timerName = "glee_rescuehelithink_" .. heli:GetCreationID()
        timer.Create( timerName, 1, 0, function()
            if not IsValid( heli ) then
                timer.Remove( timerName )
                return
            end

            terminator_Extras.glee_RescueHeliThink( heli )

        end )

        -- buff its damage when it decides to shoot
        local hookName = "glee_rescuehelishoot_" .. heli:GetCreationID()
        hook.Add( "EntityTakeDamage", hookName, function( _target, dmgInfo )
            if not IsValid( heli ) then
                hook.Remove( "EntityTakeDamage", hookName )
                return

            end
            local attacker = dmgInfo:GetAttacker()
            if attacker ~= heli then return end
            if not IsValid( attacker ) then return end

            dmgInfo:ScaleDamage( 10 )

        end )

        terminator_Extras.glee_CurrentRescueHeli = heli

        return heli

    end

    local playMusicDistance = 3500^2

    local function heliManageMusic( self )
        local currGoal = self.currentHeliGoal
        local playMusic
        if currGoal == "rescue" and IsValid( self.currentRescueTarget ) and self:GetPos():DistToSqr( self.currentRescueTarget:GetPos() ) < playMusicDistance then
            playMusic = true

        else
            playMusic = false

        end
        if playMusic then
            if not self.heliMusic then
                local allPlayersFilter = RecipientFilter()
                allPlayersFilter:AddAllPlayers()

                local music = CreateSound( self, "hunters_glee/richard_wagner_ride_of_the_valkyries_short.mp3", allPlayersFilter )
                self.heliMusic = music
                music:SetSoundLevel( 98 )
                music:PlayEx( 1, 100 )
                self:CallOnRemove( "stopHeliMusicOnRemove", function()
                    if not self.heliMusic then return end
                    self.heliMusic:Stop()
                    self.heliMusic = nil

                end )
            end
        else
            if self.heliMusic then
                self.heliMusic:Stop()
                self.heliMusic = nil

            end
        end
    end

    local function heliManageRope( self )
        local currGoal = self.currentHeliGoal
        local rapelling = IsValid( self.glee_RappelRopeStartProp )
        if currGoal == "rescue" and IsValid( self.currentRescueTarget ) then
            if not rapelling then
                local distToRescue = self:GetPos():Distance( self.currentRescueTarget:GetPos() )
                if distToRescue < glee_RappelSettings.ropeDropFromVehicleLength then
                    GAMEMODE:DropRappelRopeFromVehicle( self )

                end
            end
        elseif rapelling then
            GAMEMODE:RemoveRappelRopeFromVehicle( self )

        end
    end

    local function heliManageAngering( self )
        if CurTime() < self.nextAngerEverything then return end
        self.nextAngerEverything = CurTime() + 10

        angerEverything()

    end

    local vecUp400 = Vector( 0, 0, 400 )
    local vecUp200 = Vector( 0, 0, 200 )

    function terminator_Extras.glee_RescueHeliThink( self )
        local currentRescueTarget = self.currentRescueTarget
        local myPos = self:GetPos()
        local ourVel = self:GetVelocity()
        local validRescueTarget = IsValid( currentRescueTarget ) and currentRescueTarget:Alive()
        local visibleRescueTarget = validRescueTarget and self:Visible( currentRescueTarget )
        local trySwitchRescueTarget = not validRescueTarget or not visibleRescueTarget
        local badRescueTarget = not validRescueTarget or ( not visibleRescueTarget and myPos:Distance( currentRescueTarget:GetPos() ) > 3500 )
        if badRescueTarget then
            self.currentRescueTarget = nil
            currentRescueTarget = nil

        end
        if trySwitchRescueTarget then
            local closestDist = math.huge
            for _, ply in player.Iterator() do
                if not ply:Alive() then continue end
                local plysPos = ply:GetShootPos()
                local dist = myPos:Distance( plysPos )
                if dist > closestDist then continue end
                if not terminator_Extras.PosCanSeeComplex( myPos, plysPos, self ) then continue end

                currentRescueTarget = ply
                closestDist = dist

            end
            if IsValid( currentRescueTarget ) then
                self.currentRescueTarget = currentRescueTarget

            end
        end
        if visibleRescueTarget then
            self.lastSawARescueTargetPos = currentRescueTarget:GetPos()

        end

        local currEnemy = self:GetEnemy()
        if IsValid( currEnemy ) then
            if currEnemy:IsPlayer() then
                makeHeliFriendlyWith( self, currEnemy )

            end
            if currEnemy.ReallyAnger and not currEnemy:IsAngry() then
                currEnemy:ReallyAnger( 30 )

            end
            if not self:Visible( currEnemy ) then
                self:SetEnemy( NULL )

            end
        end

        local idealMovePos

        local currGoal = self.currentHeliGoal
        -- fly towards originalRescuePos
        -- then once we get close, start flying forwards
        if currGoal == "rescue" then
            -- bail
            if CurTime() > self.giveUpAndRunAwayTime then
                self.currentHeliTask = "rescue_switchToEscape"
                self.currentHeliGoal = "escape"

            elseif self.originalRescuePos then
                self.currentHeliTask = "rescue_flyToFlare"

                local distToOriginalRescuePos = myPos:Distance( self.originalRescuePos )
                if self:VisibleVec( self.originalRescuePos ) and distToOriginalRescuePos < 3000 then
                    self.originalRescuePos = nil

                elseif distToOriginalRescuePos < 1500 then
                    self.originalRescuePos = nil

                else
                    idealMovePos = self.originalRescuePos

                end

            elseif IsValid( currentRescueTarget ) and currentRescueTarget:GetNWEntity( "glee_RappelSourceEnt", NULL ) == self then
                self.currentHeliTask = "rescue_waitForRescueTargetToRappel"
                idealMovePos = myPos

            -- approach rescue target!
            elseif IsValid( currentRescueTarget ) then
                self.currentHeliTask = "rescue_approachRescueTarget"

                local rescueTargetsPos = currentRescueTarget:GetPos()
                local floorOfRescueTarget = terminator_Extras.getFloorTr( rescueTargetsPos ).HitPos
                idealMovePos = floorOfRescueTarget + vecUp400

                -- go way above them if they're on the ground, just a bit above if they're high up
                idealMovePos.z = math.max( idealMovePos.z, rescueTargetsPos.z + 200 )

            -- fly towards last place we saw a rescue target
            elseif self.lastSawARescueTargetPos then
                self.currentHeliTask = "rescue_approachLastSeenRescueTarget"

                local distToLastSaw = myPos:Distance( self.lastSawARescueTargetPos )
                if self:VisibleVec( self.lastSawARescueTargetPos ) and distToLastSaw < 1500 then
                    self.lastSawARescueTargetPos = nil

                elseif distToLastSaw < 800 then
                    self.lastSawARescueTargetPos = nil

                else
                    idealMovePos = self.lastSawARescueTargetPos + vecUp200 + VectorRand() * 200

                end
            -- go towards last sound hint
            elseif self.lastHeardSoundPos then
                self.currentHeliTask = "rescue_approachSoundHint"

                local distToHint = self:Distance( self.lastHeardSoundPos )
                if self:VisibleVec( self.lastHeardSoundPos ) and distToHint < 1500 then
                    self.lastHeardSoundPos = nil

                elseif distToHint < 800 then
                    self.lastHeardSoundPos = nil

                end
                idealMovePos = self.lastHeardSoundPos + vecUp200 + VectorRand() * 200

            -- just wander forward
            else
                self.currentHeliTask = "rescue_wanderForward"
                local curMoveDir = ourVel:GetNormalized()
                local forOffset = curMoveDir * 2000
                local randOffset = VectorRand() * 150
                idealMovePos = myPos + forOffset + randOffset

            end
        -- fly towards any skybox surfaces next to us
        -- if no skybox surfaces, fly towards where we spawned
        elseif currGoal == "escape" then
            local nearestSkyboxPos = self.nearestSkyboxPos
            local attempts = 2
            if not nearestSkyboxPos or not self:VisibleVec( nearestSkyboxPos ) then
                attempts = 10

            end
            local trStruc = {
                start = myPos,
                endpos = nil,
                mask = MASK_SOLID_BRUSHONLY,
                mins = Vector( callingHeliMins, callingHeliMins, callingHeliMins / 4 ),
                maxs = Vector( callingHeliMaxs, callingHeliMaxs, callingHeliMaxs / 4 ),

            }
            for _ = 1, attempts do
                local offset = VectorRand()
                offset.z = math.Rand( -0.25, 0.25 ) -- dont look upwards
                trStruc.endpos = myPos + offset * 20000

                local trResult = util.TraceHull( trStruc )
                if not trResult.HitSky then continue end

                if not nearestSkyboxPos or myPos:Distance( trResult.HitPos ) < myPos:Distance( nearestSkyboxPos ) then
                    nearestSkyboxPos = trResult.HitPos
                    self.nearestSkyboxPos = nearestSkyboxPos

                end
            end
            if nearestSkyboxPos then
                self.currentHeliTask = "rescue_flyToBestSkybox"

                idealMovePos = nearestSkyboxPos
                if myPos:Distance( nearestSkyboxPos ) < 450 then
                    hook.Run( "glee_rescueheliescape", self )
                    SafeRemoveEntityDelayed( self, 0.1 )

                end
            else
                self.currentHeliTask = "rescue_flyToWhereWeArrived"

                idealMovePos = self.rescueHeliArrivedFromPos

            end
        end

        heliManageMusic( self )
        heliManageRope( self )
        heliManageAngering( self )

        -- ideal movepos!
        -- cast rays in front of us, tighter if we're fast
        -- return early if ray is within some distance of ideal movepos
        -- rank all, by closest distance
        -- score bite if too far off the ground
        -- set track's pos to best scoring one, or if all hit, a random offset from us
        if idealMovePos then
            debugoverlay.Line( myPos, idealMovePos, 1, Color( 0, 255, 255 ), true )
            local curSpeed = ourVel:Length()
            local distToIdeal = myPos:Distance( idealMovePos )
            local distance = math.min( curSpeed * 8, heli_SpeedLimit * 2, distToIdeal * 1.5 )
            local moveDir = ourVel:GetNormalized()
            local dirToIdeal = ( idealMovePos - myPos ):GetNormalized()
            local trCheckDir = ( moveDir * 0.5 ) + ( dirToIdeal * 0.5 )

            local traceDataMove = {
                start = myPos,
                endpos = nil,
                mask = MASK_SOLID_BRUSHONLY,
                mins = Vector( tightHeliMins, tightHeliMins, tightHeliMins ),
                maxs = Vector( tightHeliMaxs, tightHeliMaxs, tightHeliMaxs ),

            }
            local function getPenaltyForPos( pos, traceResult )
                local penalty = pos:Distance( idealMovePos )

                local floorTr = terminator_Extras.getFloorTr( pos )
                local floorDist = floorTr.HitPos:Distance( pos )
                if floorDist > heli_TooFarFromGround then
                    penalty = penalty + floorDist * 0.5

                elseif floorDist < heli_TooCloseToGround then
                    penalty = penalty * 1.5

                end
                if traceResult and traceResult.Hit then
                    penalty = penalty * 4

                end
                return penalty

            end

            local count = 30
            local results = {}
            local lastBest = self.heli_lastBestPos
            if lastBest then
                local penalty = getPenaltyForPos( lastBest )
                if self.heli_lastBestPosPenalty then
                    penalty = math.max( penalty, self.heli_lastBestPosPenalty )

                end
                results[penalty * 1.15] = lastBest

            end
            local oneWasClear

            for i = 1, count do
                local currDist = distance
                if i > 2 then
                    currDist = currDist * math.Rand( 0.75, 1.25 )

                else
                    currDist = currDist * 1.25

                end

                -- bigger angle checks the further into the loop we are
                local integral = i / count
                if i > 2 and curSpeed < 500 then
                    integral = 2

                end
                local offset = VectorRand()
                offset:Mul( integral )

                local offsetedDir = trCheckDir + offset
                offsetedDir:Normalize()

                traceDataMove.endpos = myPos + offsetedDir * currDist
                local traceResult = util.TraceHull( traceDataMove )

                if traceResult.StartSolid then continue end
                oneWasClear = true

                local penalty = getPenaltyForPos( traceResult.HitPos, traceResult )

                debugoverlay.Line( myPos, traceResult.HitPos, 1, Color( 255, 0, 0 ), true )

                results[penalty] = traceResult.HitPos

            end

            local bestPos = nil

            if not oneWasClear and self:VisibleVec( idealMovePos ) and distToIdeal < 500 then
                bestPos = idealMovePos
                self.heli_lastBestPos = nil
                self.heli_lastBestPosPenalty = nil

            elseif not oneWasClear then
                for _ = 1, 10 do
                    local offfsettedPos = myPos + VectorRand() * 500
                    if not util.IsInWorld( offfsettedPos ) then continue end

                    bestPos = offfsettedPos

                    self.heli_lastBestPos = nil
                    self.heli_lastBestPosPenalty = nil
                    break

                end
            else
                local smallestPenalty = math.huge
                for penalty, pos in pairs( results ) do
                    if penalty > smallestPenalty then continue end
                    smallestPenalty = penalty
                    bestPos = pos

                end

                self.heli_lastBestPos = bestPos
                self.heli_lastBestPosPenalty = smallestPenalty

            end

            SafeRemoveEntityDelayed( self.ourPathTrack, 0.1 )
            local newTrack = ents.Create( "path_track" )
            newTrack:SetPos( bestPos )
            newTrack:SetKeyValue( "targetname", self.glee_HeliTrack_TargetName )
            self.ourPathTrack = newTrack
            self:Fire( "SetTrack", self.glee_HeliTrack_TargetName )

            manageHeliSpeedLimit( self )

        end
    end

    --terminator_Extras.glee_SpawnTheRescueHeli( Entity(1):GetPos(), VectorRand(), Entity(1):GetEyeTrace().HitPos )
end

if not CLIENT then return end

local lifetime = 20

local signalFlaresThatPierceFog = {}

local flareMatId = surface.GetTextureID( "effects/strider_bulge_dudv_dx60" )
local flareColor = Color( 255, 255, 255, 50 )

hook.Add( "RenderScreenspaceEffects", "glee_predraw_fogpiercing_signalflares", function()

    if not next( signalFlaresThatPierceFog ) then return end

    local me = LocalPlayer()
    local myShootPos = me:GetShootPos()

    for _, flare in pairs( signalFlaresThatPierceFog ) do

        local sizeMul = 100

        local flaresRealPos = flare:WorldSpaceCenter()
        local pos2d = flaresRealPos:ToScreen()

        if not pos2d.visible then continue end

        local distanceToIt = myShootPos:Distance( flaresRealPos )
        if distanceToIt < 450 then
            sizeMul = sizeMul * 2

        end

        local canSee = terminator_Extras.PosCanSeeComplex( myShootPos, flaresRealPos, me )
        if not canSee then continue end

        local distScalar = math.log( distanceToIt, 4 ) * 5
        local timeToDeath = math.abs( flare:GetDeathTime() - CurTime() )
        local size = math.Clamp( ( timeToDeath / lifetime ) + 1, 0, 1 )
        size = size * sizeMul

        local width = size + -distScalar
        local height = size + -distScalar

        local jitter = width * 0.05

        local jitterx = math.Rand( -jitter, jitter )
        local jittery = math.Rand( -jitter, jitter )

        local halfWidth = width / 2
        local halfHeight = height / 2

        local texturedQuadStructure = {
            texture = flareMatId,
            color   = flareColor,
            x 	= pos2d.x + -halfWidth + jitterx,
            y 	= pos2d.y + -halfHeight + jittery,
            w 	= width,
            h 	= height
        }

        draw.TexturedQuad( texturedQuadStructure )

    end
end )

function ENT:Think()
    local myId = self:GetCreationID()

    if not signalFlaresThatPierceFog[myId] then
        signalFlaresThatPierceFog[myId] = self

    end
end

function ENT:OnRemove()
    signalFlaresThatPierceFog[self:GetCreationID()] = nil

end

-- rescue heli spotlight
-- from Dynamic Combine Flashlights by Zelektra
local nextBlinkTime = 0
local blinkInterval = 0.5
local flashlightSprite = Material( "engine/lightsprite" )
local warningLightSprite = Material( "effects/blueflare1" )
local flashlightMaterial = Material( "glee/FlashlightBeam" )

local function CreateProjectedTextureForHelicopter( helicopter )
    if not IsValid( helicopter ) then return end

    if not helicopter.ProjectedTexture then
        helicopter.ProjectedTexture = ProjectedTexture()

    end

    local attachmentIndex = helicopter:LookupAttachment( "Spotlight" )

    if attachmentIndex then
        local attachment = helicopter:GetAttachment( attachmentIndex )
        if attachment then
            helicopter.ProjectedTexture:SetPos( attachment.Pos )
            helicopter.ProjectedTexture:SetAngles( attachment.Ang )

        else
            helicopter.ProjectedTexture:SetPos( helicopter:GetPos() )
            helicopter.ProjectedTexture:SetAngles( helicopter:GetAngles() )

        end
    else
        -- Fallback to helicopter position if attachment is not valid
        helicopter.ProjectedTexture:SetPos( helicopter:GetPos() )
        helicopter.ProjectedTexture:SetAngles( helicopter:GetAngles() )

    end

    helicopter.ProjectedTexture:SetNearZ( 200 )
    helicopter.ProjectedTexture:SetFarZ( 5000 ) -- Increased range for helicopters
    helicopter.ProjectedTexture:SetFOV( 40 )
    helicopter.ProjectedTexture:SetBrightness( 1 )
    helicopter.ProjectedTexture:SetTexture( "effects/spotlight" )
    helicopter.ProjectedTexture:Update()

end

local function RemoveProjectedTextureForHelicopter( helicopter )
    if not helicopter.ProjectedTexture then return end
    helicopter.ProjectedTexture:Remove()
    helicopter.ProjectedTexture = nil

end

local function DrawHelicopterBeams( bDepth, bSkybox )
    if bSkybox then return end
    if bDepth then return end

    for _, npc in ipairs( ents.FindByClass( "npc_helicopter" ) ) do
        if npc.spotlightOn == false then return end

        -- Get the muzzle attachment
        local attachmentIndex = npc:LookupAttachment( "Spotlight" )
        if attachmentIndex == 0 then return end

        local attachment = npc:GetAttachment( attachmentIndex )
        if not attachment then return end

        local attachmentsForward = attachment.Ang:Forward()
        local startPos = attachment.Pos + ( attachmentsForward * 5 ) - ( attachment.Ang:Up() * 4 )
        local endPos = startPos + attachmentsForward * 2000

        -- Calculate dot product for scaling and visibility
        local dir = attachment.Ang:Forward() * -1
        local viewDir = ( startPos - EyePos() ):GetNormalized()
        local dotProduct = dir:Dot( viewDir )
        dotProduct = math.Clamp( dotProduct, 0, 1 ) -- Clamp to avoid very small or very large sizes

        local flaslightSpriteCheckResult = util.TraceLine( {
            start = EyePos(),
            endpos = startPos,
            filter = { npc, LocalPlayer() }
        } )

        if dotProduct > 0 and not flaslightSpriteCheckResult.Hit then -- Only draw for visible sprites
            local size = dotProduct * 400 -- Adjust base size multiplier as needed

            render.SetMaterial( flashlightSprite )
            render.DrawSprite( startPos, size, size, Color( 255, 255, 255, 255 * dotProduct ) )

        end

        local spotlightCheck = util.TraceLine( {
            start = startPos,
            endpos = endPos,
            filter = { npc },
            mask = MASK_OPAQUE
        } )

        render.SetMaterial( flashlightMaterial )
        render.DrawBeam( startPos, spotlightCheck.HitPos, 1000, 0, spotlightCheck.Fraction, Color( 255, 255, 255, ( 255 * 5 ) * ( 1 - dotProduct ) ) )

        if blinkState == true then
            local attachmentIndexWarn1 = npc:LookupAttachment( "Light_Red0" )
            if attachmentIndexWarn1 == 0 then return end

            local attachmentWarn1 = npc:GetAttachment( attachmentIndexWarn1 )
            if not attachmentWarn1 then return end

            local startPosWarn = attachmentWarn1.Pos

            render.SetMaterial( warningLightSprite )
            render.DrawSprite( startPosWarn, 50, 50, Color( 255, 0, 0, 50 ) )

            local attachmentIndexWarn2 = npc:LookupAttachment( "Light_Red1" )
            if attachmentIndexWarn2 == 0 then return end

            local attachmentWarn2 = npc:GetAttachment( attachmentIndexWarn2 )
            if not attachmentWarn2 then return end

            local startPosWarn2 = attachmentWarn2.Pos

            render.DrawSprite( startPosWarn2, 50, 50, Color( 0, 255, 0, 50 ) )

            local attachmentIndexWarn3 = npc:LookupAttachment( "Light_Red2" )
            if attachmentIndexWarn3 == 0 then return end

            local attachmentWarn3 = npc:GetAttachment( attachmentIndexWarn3 )
            if not attachmentWarn3 then return end

            local startPosWarn3 = attachmentWarn3.Pos

            render.DrawSprite( startPosWarn3, 50, 50, Color( 255, 0, 0, 50 ) )

        end

        if CurTime() > nextBlinkTime then
            nextBlinkTime = CurTime() + blinkInterval
            if blinkState == false then blinkState = true else blinkState = false end

        end
    end
end

local function CheckHelicopterLightLevel()
    for _, helicopter in ipairs( ents.FindByClass( "npc_helicopter" ) ) do
        -- Check the light level around the helicopter.
        local lightLevel = render.ComputeLighting( helicopter:GetPos(), Vector( 0, 0, 1 ) ):Length()

        if lightLevel < 0.4 then
            CreateProjectedTextureForHelicopter( helicopter )
            helicopter.spotlightOn = true

        else
            RemoveProjectedTextureForHelicopter( helicopter )
            helicopter.spotlightOn = false

        end
    end
end

hook.Add( "PostDrawTranslucentRenderables", "DrawHelicopterBeams", DrawHelicopterBeams )
hook.Add( "Think", "CheckHelicopterLightLevel", CheckHelicopterLightLevel )