-- The Medical Tissue Reclaimer's projection, included by shared.lua
-- the kit projects the dead back up, standing where they'll be revived, built from the feet up as you close in
-- while someone's revived, their corpse is pulled into the projection, bone by bone, each taking its glowing bone's place

local reclaimer = SWEP.Reclaimer
local boneSnapFrac = reclaimer.boneSnapFrac
local glowMat = reclaimer.glowMat
local hologramMat = reclaimer.hologramMat
local reclamationColor = reclaimer.reclamationColor
local drawColor = reclaimer.drawColor
local randomSpotOnBone = reclaimer.randomSpotOnBone
local spotPos = reclaimer.spotPos
local drawBeam = reclaimer.drawBeam
local reclamationArc = reclaimer.reclamationArc
local ARC_NO_LIGHT = reclaimer.ARC_NO_LIGHT
local ARC_NO_SOUND = reclaimer.ARC_NO_SOUND
local ARC_PASS_WORLD = reclaimer.ARC_PASS_WORLD
local ARC_NO_DECAL = reclaimer.ARC_NO_DECAL

-- The projection --------------------------------------------------------

local beamUp = Vector( 0, 0, 24 ) -- dead positions are on the floor, pointers aim this far above them
local reachingDist = 300 -- closer than this, the nearest is projected
local pointerLength = 80 -- pointers shorten toward this as they get further. Past pointOutRange, only the nearest gets one
local unprojectSlack = 50 -- once projected, stays so until this much past reachingDist, so the edge doesn't restart the build
local buildTime = 0.8 -- seconds the projection takes to build from the feet up, once it starts

-- cowering, they were just hunted down. By activity, custom player models name their sequences all sorts
local hologramAct = ACT_HL2MP_IDLE_SCARED
local hologramFallbackPose = "idle_all_01"
local centerBone = "ValveBiped.Bip01_Spine2" -- the main beam lands here

-- who this kit projects, since when, for the build, and which way they cower. Its nearest, once they're within reachingDist
-- a new nearest, or walking out and back in, starts the build over
function SWEP:UpdateProjected( nearest, ownerPos )
    local projectDist = reachingDist
    if nearest and nearest.ply == self.glee_projectedDead then
        projectDist = reachingDist + unprojectSlack

    end

    if not nearest or ownerPos:Distance( nearest.pos ) > projectDist then
        self.glee_projectedDead = nil
        return

    end

    if self.glee_projectedDead ~= nearest.ply then
        self.glee_projectedDead = nearest.ply
        self.glee_projectStart = CurTime()
        self.glee_projectAng = Angle( 0, math.Rand( 0, 360 ), 0 )

    end
end

-- where their own shape is read from, eg a big head
-- their corpse, see cl_bonemanip, or them when there's no corpse with this model
local function getShapeSource( dead, mdl )
    local rag = dead:GetRagdollEntity()
    if IsValid( rag ) and rag:GetModel() == mdl then return rag end

    return dead

end

-- gives the hologram or fake corpse their shape, ent has their model so the bones line up
local function copyBoneManips( ent, dead )
    local from = getShapeSource( dead, ent:GetModel() )
    for bone = 0, ent:GetBoneCount() - 1 do
        ent:ManipulateBoneScale( bone, from:GetManipulateBoneScale( bone ) )
        ent:ManipulateBonePosition( bone, from:GetManipulateBonePosition( bone ) )
        ent:ManipulateBoneAngles( bone, from:GetManipulateBoneAngles( bone ) )

    end
end

-- each kit only projects its nearest, so it keeps one model, made over into whoever that is
-- removed in OnRemove
function SWEP:GetHologram( dead )
    local holo = self.glee_hologram
    if not IsValid( holo ) then
        holo = ClientsideModel( dead:GetModel(), RENDERGROUP_TRANSLUCENT )
        if not IsValid( holo ) then return end

        holo:SetNoDraw( true )
        self.glee_hologram = holo

    end

    local mdl = dead:GetModel()
    if holo.glee_dead == dead and holo:GetModel() == mdl then return holo end

    holo.glee_dead = dead
    holo.glee_posedFrame = nil -- see poseHologram
    holo:SetModel( mdl )
    holo:SetSkin( dead:GetSkin() )
    for _, bodyGroup in pairs( dead:GetBodyGroups() ) do
        holo:SetBodygroup( bodyGroup.id, dead:GetBodygroup( bodyGroup.id ) )

    end

    copyBoneManips( holo, dead )
    holo.glee_hiddenCount = nil -- the copy shows every bone again, see giveWayToCorpse

    local pose = holo:SelectWeightedSequence( hologramAct )
    if pose < 0 then
        pose = holo:LookupSequence( hologramFallbackPose )

    end
    if pose >= 0 then
        holo:ResetSequence( pose )

    end

    local _, maxs = holo:GetModelBounds()
    holo.glee_height = maxs.z

    return holo

end

-- before reading its bones or drawing it
-- once a frame, it's held to the kit, see HeldProjection, so every view that frame has it in the same place
local function poseHologram( holo, pos, ang )
    local frame = FrameNumber()
    if holo.glee_posedFrame == frame then return end
    holo.glee_posedFrame = frame

    holo:SetPos( pos )
    holo:SetAngles( ang )
    holo:FrameAdvance()
    holo:SetupBones() -- bones are stale after moving it

end

local function getBonePos( holo, boneId )
    if not boneId then return end

    local matrix = holo:GetBoneMatrix( boneId )
    if not matrix then return end

    return matrix:GetTranslation()

end

-- each bone going in cuts the projection out for a beat, then it jitters back, like the infernal skeleton's glow when hurt
-- so every snap gets a moment with nothing glowing over it. Set by reclaimBones
local crackCutTime = 0.05
local crackJitterTime = 0.15
local crackJitterSize = 2 -- units, shrinks to nothing over crackJitterTime
local jitterMatrix = Matrix()
local jitterOffset = Vector()

-- posed at pos and ang by poseHologram
-- built 0 to 1, how far up from the feet it's been built, a line glows across the build
-- returns how high it's built
local function drawHologram( holo, pos, ang, color, built, bright )
    local up = ang:Up()
    local builtHeight = holo.glee_height * built

    local building = built < 1
    local oldClipping
    if building then
        -- keeps what's below the build line
        oldClipping = render.EnableClipping( true )
        local normal = -up
        render.PushCustomClipPlane( normal, normal:Dot( pos + up * builtHeight ) )

    end

    local sinceCrack = CurTime() - ( holo.glee_crackedAt or 0 )
    if sinceCrack >= crackCutTime then
        local jittering = sinceCrack < crackCutTime + crackJitterTime
        if jittering then
            local size = crackJitterSize * ( 1 - ( sinceCrack - crackCutTime ) / crackJitterTime )
            jitterOffset:SetUnpacked( math.Rand( -size, size ), math.Rand( -size, size ), math.Rand( -size, size ) )
            jitterMatrix:SetTranslation( jitterOffset )
            cam.PushModelMatrix( jitterMatrix )

        end

        render.MaterialOverride( hologramMat )
        render.SetColorModulation( color.r / 255 * bright, color.g / 255 * bright, color.b / 255 * bright )
        holo:DrawModel()
        render.SetColorModulation( 1, 1, 1 )
        render.MaterialOverride( nil )

        if jittering then
            cam.PopModelMatrix()

        end
    end

    if building then
        render.PopCustomClipPlane()
        render.EnableClipping( oldClipping )

        local scanPos = pos + up * builtHeight
        drawColor.r, drawColor.g, drawColor.b = color.r, color.g, color.b
        drawColor.a = 255 * bright
        render.SetMaterial( glowMat )
        -- quads are one sided, so one facing each way
        render.DrawQuadEasy( scanPos, up, 48, 48, drawColor )
        render.DrawQuadEasy( scanPos, -up, 48, 48, drawColor )

    end

    return builtHeight

end


-- Reclaiming the corpse -------------------------------------------------
-- while being revived, the corpse is pulled into the projection a bone at a time, each frozen there with a crack, see boneSnapFrac
-- like cl_souls, ragdoll bones are moved through their physics objects
-- every client reclaims its own copy of the corpse, so a corpse's progress is kept on it, shared by every kit reviving it

local boneBreakSounds = {
    Sound( "physics/body/body_medium_break2.wav" ),
    Sound( "physics/body/body_medium_break3.wav" ),
    Sound( "physics/body/body_medium_break4.wav" ),
}
local fleshSounds = {
    Sound( "physics/flesh/flesh_squishy_impact_hard1.wav" ),
    Sound( "physics/flesh/flesh_squishy_impact_hard2.wav" ),
    Sound( "physics/flesh/flesh_squishy_impact_hard3.wav" ),
    Sound( "physics/flesh/flesh_squishy_impact_hard4.wav" ),
}

-- with no kit reviving it for this long, the corpse is let go. Covers a cancelled revive, and a kit we stopped seeing
local reclaimHoldTime = 0.25
local reclaimedRagdolls = setmetatable( {}, { __mode = "k" } )
local fakeCorpses = setmetatable( {}, { __mode = "k" } ) -- to the dead player each stands in for

-- freezes one of the corpse's physics objects onto the hologram's matching bone, returns whether it could
local function moveBoneToHologram( rag, holo, boneIndex )
    local ragsObj = rag:GetPhysicsObjectNum( boneIndex )
    if not IsValid( ragsObj ) then return false end

    local matrix = holo:GetBoneMatrix( rag:TranslatePhysBoneToBone( boneIndex ) )
    if not matrix then return false end

    ragsObj:EnableMotion( false )
    ragsObj:SetPos( matrix:GetTranslation() )
    ragsObj:SetAngles( matrix:GetAngles() )
    return true

end


-- Fake corpses ----------------------------------------------------------
-- a fake corpse's bones grow back in groups, one per physics object, with the bones that ride on it, eg fingers
-- physics object index -> the bones in its group, per model
local growGroupsCache = {}

local function getGrowGroups( fake )
    local mdl = fake:GetModel()
    local groups = growGroupsCache[mdl]
    if groups then return groups end

    groups = {}
    for bone = 0, fake:GetBoneCount() - 1 do
        local physIndex = math.max( fake:TranslateBoneToPhysBone( bone ), 0 ) -- bones on no physics object grow with the root
        groups[physIndex] = groups[physIndex] or {}
        table.insert( groups[physIndex], bone )

    end

    growGroupsCache[mdl] = groups
    return groups

end

-- grown 0 to 1, of the scale that bone has in their shape, see copyBoneManips
local function scaleGrowGroup( fake, physIndex, grown )
    local group = getGrowGroups( fake )[physIndex]
    if not group then return end

    local dead = fake:GetOwner()
    if not IsValid( dead ) then return end

    local from = getShapeSource( dead, fake:GetModel() )
    for _, bone in ipairs( group ) do
        fake:ManipulateBoneScale( bone, from:GetManipulateBoneScale( bone ) * grown )

    end
end

-- eases each group in from when it started growing, see fakeCorpseGrowTime
local fakeCorpseGrowTime = 0.15

local function growFakeCorpse( fake, finishNow )
    local growStarts = fake.glee_growStarts
    if not growStarts then return end

    local now = CurTime()
    for physIndex, started in pairs( growStarts ) do
        local grown = finishNow and 1 or math.Clamp( ( now - started ) / fakeCorpseGrowTime, 0, 1 )
        scaleGrowGroup( fake, physIndex, grown )
        if grown >= 1 then
            growStarts[physIndex] = nil

        end
    end
end

-- for players with nothing left to reclaim, dissolved, gibbed, or just gone, a stand in that's grown back instead
-- set up like cl_souls' souls, kept on the dead player so every kit shares it
local function getFakeCorpse( dead, holo )
    local mdl = dead:GetModel()
    local fake = dead.glee_reclaimerFakeCorpse
    if IsValid( fake ) and fake:GetModel() == mdl then
        -- an autorefresh empties fakeCorpses but leaves the fake on the player, and unlisted it'd be treated as a real corpse
        fakeCorpses[fake] = dead
        return fake

    end

    SafeRemoveEntity( fake )

    fake = ClientsideRagdoll( mdl, RENDERGROUP_OPAQUE )
    if not IsValid( fake ) then return end

    fake:SetOwner( dead )
    fake:SetSkin( dead:GetSkin() )
    for _, bodyGroup in pairs( dead:GetBodyGroups() ) do
        fake:SetBodygroup( bodyGroup.id, dead:GetBodygroup( bodyGroup.id ) )

    end

    function fake.GetPlayerColor( self )
        local owner = self:GetOwner()
        if not IsValid( owner ) then return vector_origin end

        return owner:GetPlayerColor()

    end

    copyBoneManips( fake, dead )

    -- nothing there until it's grown, frozen on the projection to grow from
    for physIndex in pairs( getGrowGroups( fake ) ) do
        scaleGrowGroup( fake, physIndex, 0 )

    end
    for boneIndex = 0, fake:GetPhysicsObjectCount() - 1 do
        moveBoneToHologram( fake, holo, boneIndex )

    end

    fake:SetNoDraw( false )

    fake.glee_grown = {} -- physics object indexes whose groups have been grown
    fakeCorpses[fake] = dead
    dead.glee_reclaimerFakeCorpse = fake
    dead:CallOnRemove( "glee_reclaimerfakecorpse", function( ent )
        SafeRemoveEntity( ent.glee_reclaimerFakeCorpse )

    end )

    return fake

end

-- what's left of them to reclaim, or a fake corpse to grow when nothing is
-- nil when there's a ragdoll that won't line up with the projection
local function getCorpse( dead, holo )
    local rag = dead:GetRagdollEntity()
    if IsValid( rag ) then
        if rag:GetModel() ~= holo:GetModel() then return end
        return rag

    end

    return getFakeCorpse( dead, holo )

end


-- The order bones go in -------------------------------------------------
-- see newReclaimOrder
-- each physics object's parent, the one it hangs off, -1 for the root. Per model
local physParentsCache = {}

local function getPhysParents( rag )
    local mdl = rag:GetModel()
    local parents = physParentsCache[mdl]
    if parents then return parents end

    parents = {}
    for physIndex = 0, rag:GetPhysicsObjectCount() - 1 do
        parents[physIndex] = -1

        -- up the skeleton, past bones with no physics object of their own, eg a clavicle
        local bone = rag:GetBoneParent( rag:TranslatePhysBoneToBone( physIndex ) )
        while bone >= 0 do
            local parentPhys = rag:TranslateBoneToPhysBone( bone )
            if parentPhys >= 0 and parentPhys ~= physIndex then
                parents[physIndex] = parentPhys
                break

            end
            bone = rag:GetBoneParent( bone )

        end
    end

    physParentsCache[mdl] = parents
    return parents

end

-- the physics objects, starting from startIndex and spreading out along the skeleton, a random way each time
-- a list, the first to go in first
local function spreadingOrder( rag, startIndex )
    local parents = getPhysParents( rag )
    local count = rag:GetPhysicsObjectCount()
    local order = {}
    local ordered = {}
    local frontier = { startIndex }

    while #frontier > 0 do
        local physIndex = table.remove( frontier, math.random( #frontier ) )
        if not ordered[physIndex] then
            ordered[physIndex] = true
            table.insert( order, physIndex )

            for other = 0, count - 1 do
                local touching = parents[other] == physIndex or parents[physIndex] == other
                if touching and not ordered[other] then
                    table.insert( frontier, other )

                end
            end
        end
    end

    -- any the skeleton didn't join up
    for physIndex = 0, count - 1 do
        if not ordered[physIndex] then
            table.insert( order, physIndex )

        end
    end

    return order

end

-- a real corpse starts anywhere, a hand, a foot, its head. A fake one grows out from the torso
local function newReclaimOrder( rag )
    if fakeCorpses[rag] then
        return spreadingOrder( rag, 0 )

    end
    return spreadingOrder( rag, math.random( 0, rag:GetPhysicsObjectCount() - 1 ) )

end


-- The projection giving way ---------------------------------------------
-- each bone the corpse puts into the projection is hidden there, so the snapping corpse isn't drawn over by its glow
-- shrunk, not scaled to 0, the corpse's bones still read their angles off the projection's, see moveBoneToHologram
local hiddenScale = 0.01

-- the first count of rag's reclaim order hidden on holo, the rest at their usual shape
local function giveWayToCorpse( holo, rag, count )
    local order = rag.glee_reclaimOrder
    if holo.glee_hiddenCount == count and holo.glee_hiddenOrder == order then return end
    holo.glee_hiddenCount = count
    holo.glee_hiddenOrder = order

    local from = getShapeSource( holo.glee_dead, holo:GetModel() )
    local groups = getGrowGroups( rag ) -- same model as holo, see getCorpse, so the same bones
    for pos, physIndex in ipairs( order ) do
        local scale = pos <= count and hiddenScale or 1
        for _, bone in ipairs( groups[physIndex] or {} ) do
            holo:ManipulateBoneScale( bone, from:GetManipulateBoneScale( bone ) * scale )

        end
    end
end

-- every bone shown again, for when holo's no longer being revived
local function restoreHologram( holo )
    if not holo.glee_hiddenCount then return end
    holo.glee_hiddenCount = nil
    holo.glee_hiddenOrder = nil

    if IsValid( holo.glee_dead ) then
        copyBoneManips( holo, holo.glee_dead )

    end
end


-- Letting go ------------------------------------------------------------
-- frozen physics objects are stubborn, they need waking as well as unfreezing, like cl_souls does
local function releaseRagdoll( rag )
    -- a fake corpse's ungrown bones are frozen from the start, and would hold up the grown ones
    local releasing = {}
    if fakeCorpses[rag] then
        for physIndex = 0, rag:GetPhysicsObjectCount() - 1 do
            table.insert( releasing, physIndex )

        end
        growFakeCorpse( rag, true ) -- nobody's growing it now

    else
        local order = rag.glee_reclaimOrder or {}
        for pos = 1, rag.glee_reclaimNextBone or 0 do
            table.insert( releasing, order[pos] )

        end
    end

    for _, physIndex in ipairs( releasing ) do
        local ragsObj = rag:GetPhysicsObjectNum( physIndex )
        if IsValid( ragsObj ) then
            ragsObj:EnableMotion( true )
            ragsObj:Wake()

        end
    end

    rag.glee_reclaimNextBone = nil

end

hook.Add( "Think", "glee_reclaimer_releasecorpses", function()
    -- fake corpses go once who they stood in for is up again
    for fake, dead in pairs( fakeCorpses ) do
        if not IsValid( fake ) then
            fakeCorpses[fake] = nil

        elseif not IsValid( dead ) or dead:Health() > 0 then
            fake:Remove()
            fakeCorpses[fake] = nil

        end
    end

    if not next( reclaimedRagdolls ) then return end

    local now = CurTime()
    for rag in pairs( reclaimedRagdolls ) do
        if not IsValid( rag ) then
            reclaimedRagdolls[rag] = nil

        elseif rag.glee_reclaimHeldUntil < now then
            releaseRagdoll( rag )
            reclaimedRagdolls[rag] = nil

        end
    end
end )


-- Tendrils --------------------------------------------------------------
-- the kit reaches for the next few bones due with tendrils, and drags them in, see drawTendrils
-- a visual flourish, the server knows nothing of them
local tendrilCount = 3
local tendrilWindow = 0.25 -- of the revive, before its bone goes in, a tendril tightens from faint to taut
local tendrilFaintest = 0.15 -- alpha, the furthest from going in
local tendrilWidth = 1
local tendrilWrithe = 6 -- how fast they writhe

-- whether the bone at pos in rag's reclaim order has a tendril on it
-- a fake corpse has none, only grown bones an interrupted revive left loose get dragged back
local function hasTendril( rag, pos, reclaimedCount )
    if pos <= reclaimedCount or pos > reclaimedCount + tendrilCount then return false end
    if not fakeCorpses[rag] then return true end

    return rag.glee_grown[rag.glee_reclaimOrder[pos]] == true

end

-- the bones not in yet drift toward their spots on the projection, harder the further the revive's got
-- the ones with tendrils on are dragged, the rest barely move
local pullRate = 3 -- at the end of the revive, the share of the way to its spot a loose bone is sent per second
local tendrilPull = 3 -- times pullRate, a bone with a tendril on
local looseBonePull = 0.3 -- times pullRate, the rest
local pullSteer = 8 -- how quickly a loose bone's velocity turns toward that, per second

-- the bones in rag's reclaim order after reclaimedCount
local function pullLooseBones( rag, holo, reclaimedCount, reviveFrac )
    local frame = FrameNumber()
    if rag.glee_reclaimPullFrame == frame then return end -- drawn in more than one view, don't pull twice
    rag.glee_reclaimPullFrame = frame

    local steer = math.min( pullSteer * FrameTime(), 1 )
    local order = rag.glee_reclaimOrder
    for pos = reclaimedCount + 1, #order do
        local physIndex = order[pos]
        local ragsObj = rag:GetPhysicsObjectNum( physIndex )
        local matrix = IsValid( ragsObj ) and holo:GetBoneMatrix( rag:TranslatePhysBoneToBone( physIndex ) )
        if matrix then
            local pull = hasTendril( rag, pos, reclaimedCount ) and tendrilPull or looseBonePull
            local wanted = ( matrix:GetTranslation() - ragsObj:GetPos() ) * pullRate * pull * reviveFrac
            ragsObj:Wake()
            ragsObj:SetVelocity( LerpVector( steer, ragsObj:GetVelocity(), wanted ) )

        end
    end
end

local tendrilBeam = {} -- see drawBeam

-- from the prongs to the bones with tendrils on, see hasTendril. Stopped by walls like the beams
local function drawTendrils( wep, rag, reclaimedCount, reviveFrac )
    local startPos, kitAng = wep:BeamStart()
    if not startPos then return end

    local startDir = kitAng:Forward()
    local tips = wep:ProngTips()
    local order = rag.glee_reclaimOrder
    local boneCount = #order
    rag.glee_tendrilSpots = rag.glee_tendrilSpots or {} -- where on each bone its tendril grabs, kept so it doesn't jump

    for pos = reclaimedCount + 1, math.min( reclaimedCount + tendrilCount, boneCount ) do
        if not hasTendril( rag, pos, reclaimedCount ) then continue end

        local physIndex = order[pos]
        local spot = rag.glee_tendrilSpots[physIndex]
        if not spot then
            spot = randomSpotOnBone( rag, rag:TranslatePhysBoneToBone( physIndex ) )
            rag.glee_tendrilSpots[physIndex] = spot

        end

        local endPos = spotPos( rag, spot )
        if endPos then
            local untilIn = boneSnapFrac( pos - 1, boneCount ) - reviveFrac
            local taut = math.Clamp( 1 - untilIn / tendrilWindow, tendrilFaintest, 1 )
            tendrilBeam.startPos = tips[( pos - 1 ) % math.max( #tips, 1 ) + 1] or startPos
            tendrilBeam.startDir = startDir
            tendrilBeam.endPos = endPos
            tendrilBeam.color = reclamationColor
            tendrilBeam.width = tendrilWidth * ( 0.5 + taut )
            tendrilBeam.tipAlpha = nil
            tendrilBeam.alpha = taut
            tendrilBeam.bend = 0.35 + 0.25 * math.sin( CurTime() * tendrilWrithe + pos )
            tendrilBeam.tipWidth = nil
            tendrilBeam.simple = nil
            drawBeam( tendrilBeam )

        end
    end
end


-- Bones going in --------------------------------------------------------
-- the last stretch of bones go in with an arc from the prongs, building up to the jolt when they stand, see StartReviveJolt
local snapArcFrac = 0.85 -- of the way through the revive, bones going in after this arc

-- a bone of boneCount going in at bonePos, bleeds, kicks the kit, and arcs to it if it's late enough
local function boneGoesIn( wep, bonePos, boneIndex, boneCount )
    local blood = EffectData()
    blood:SetOrigin( bonePos )
    blood:SetColor( BLOOD_COLOR_RED )
    blood:SetNormal( VectorRand() )
    util.Effect( "BloodImpact", blood )

    wep:Jostle()
    if boneSnapFrac( boneIndex, boneCount ) < snapArcFrac then return end

    local tips = wep:ProngTips()
    local tip = tips[math.random( math.max( #tips, 1 ) )]
    if not tip then return end

    reclamationArc( tip, ( bonePos - tip ):GetNormalized(), bonePos, 0.4, ARC_NO_SOUND + ARC_NO_LIGHT + ARC_NO_DECAL + ARC_PASS_WORLD )

end

-- call every frame the revive goes on, even once every bone's in, or the corpse is let go
-- reviveFrac is 0 to 1 of the way through the revive, every bone due by then goes in, jostling wep
-- simple, far away, see beamLod. No tendrils, the corpse still goes back together
local function reclaimBones( wep, dead, holo, reviveFrac, simple )
    local rag = getCorpse( dead, holo )
    if not rag then return end -- the revive carries on without one

    local isFake = fakeCorpses[rag] ~= nil
    if isFake then
        growFakeCorpse( rag )

    end

    -- not held from the last frame or so, it's catching up, eg back in range, or someone new to spectate
    -- the bones already due go in quietly, a burst of every crack at once reads as a glitch
    local catchingUp = not reclaimedRagdolls[rag]

    rag.glee_reclaimHeldUntil = CurTime() + reclaimHoldTime
    reclaimedRagdolls[rag] = true

    local reclaimedCount = rag.glee_reclaimNextBone or 0
    local boneCount = rag:GetPhysicsObjectCount()
    local dueCount = 0
    while dueCount < boneCount and boneSnapFrac( dueCount, boneCount ) <= reviveFrac do
        dueCount = dueCount + 1

    end

    -- bones already cracked once this revive go back in quietly, after a let go and re-press
    -- less due than that, the progress bar ran out and this is a new revive
    local crackedCount = rag.glee_reclaimCracked or 0
    if dueCount < crackedCount then
        crackedCount = 0

        -- still held from the last one, what it put in comes back out to go in again
        if reclaimedCount > 0 then
            releaseRagdoll( rag )
            reclaimedCount = 0

        end
    end

    -- a new revive picks a new start, as its first bone goes in. A re-press keeps the one it had
    local startsOver = reclaimedCount == 0 and crackedCount == 0 and dueCount > 0
    if startsOver or not rag.glee_reclaimOrder then
        rag.glee_reclaimOrder = newReclaimOrder( rag )

    end
    local order = rag.glee_reclaimOrder

    -- the projection swings with the kit, so the bones already in follow it, not where it was when they went in
    for pos = 1, reclaimedCount do
        moveBoneToHologram( rag, holo, order[pos] )

    end

    -- near the end, a frame can be late for more than one
    while reclaimedCount < dueCount do
        local physIndex = order[reclaimedCount + 1]
        local bonePos -- somewhere inside the bone, where it cracks and bleeds
        if moveBoneToHologram( rag, holo, physIndex ) then
            local bone = rag:TranslatePhysBoneToBone( physIndex )
            bonePos = spotPos( holo, randomSpotOnBone( holo, bone ) )

        end

        -- a fake's groups grow the first time they go in, and stay grown, even through a whole new revive
        local growsNow = bonePos and isFake and not rag.glee_grown[physIndex]
        if growsNow then
            rag.glee_grown[physIndex] = true
            rag.glee_growStarts = rag.glee_growStarts or {}
            rag.glee_growStarts[physIndex] = CurTime()
            if not catchingUp then
                sound.Play( fleshSounds[math.random( #fleshSounds )], bonePos, 70, math.random( 90, 110 ) )
                boneGoesIn( wep, bonePos, reclaimedCount, boneCount )
                holo.glee_crackedAt = CurTime()

            end
        elseif bonePos and reclaimedCount >= crackedCount and not catchingUp then
            sound.Play( boneBreakSounds[math.random( #boneBreakSounds )], bonePos, 70, math.random( 90, 110 ) )
            boneGoesIn( wep, bonePos, reclaimedCount, boneCount )
            holo.glee_crackedAt = CurTime()

        end
        reclaimedCount = reclaimedCount + 1

    end

    rag.glee_reclaimNextBone = reclaimedCount
    rag.glee_reclaimCracked = math.max( crackedCount, reclaimedCount )

    giveWayToCorpse( holo, rag, reclaimedCount )
    pullLooseBones( rag, holo, reclaimedCount, reviveFrac )
    if not simple then
        drawTendrils( wep, rag, reclaimedCount, reviveFrac )

    end

end


-- The revive's jolt -----------------------------------------------------
-- arcs into the projection's chest as the revived stand up, see SendReviveJolt

-- the projection's chest, where they're about to stand. nil if this kit wasn't projecting them
function SWEP:ProjectedChest( dead )
    local holo = self.glee_hologram
    if not IsValid( holo ) or holo.glee_dead ~= dead then return end

    return getBonePos( holo, holo:LookupBone( centerBone ) )

end

function SWEP:StartReviveJolt( revived )
    self:ShutProngs() -- spread wide all revive, they slam shut as the jolt goes in

    local startPos, kitAng = self:BeamStart()
    if not startPos then return end

    local chest = self:ProjectedChest( revived )
    if not chest then return end

    -- one arc carries the sound and light, the rest would only stack them
    local barrelDir = kitAng:Forward()
    reclamationArc( startPos, barrelDir, chest, 1.5, ARC_PASS_WORLD + ARC_NO_DECAL )
    for _, tip in ipairs( self:ProngTips() ) do
        reclamationArc( tip, barrelDir, chest, 1, ARC_NO_SOUND + ARC_NO_LIGHT + ARC_PASS_WORLD + ARC_NO_DECAL )

    end
end

net.Receive( "glee_reclaimer_revivejolt", function()
    local wep = net.ReadEntity()
    local revived = net.ReadEntity()
    if not IsValid( wep ) or not IsValid( revived ) then return end
    if not wep.StartReviveJolt then return end -- not a kit, the index went to something else on our end

    wep:StartReviveJolt( revived )

end )


-- What the other files use --------------------------------------------------

reclaimer.beamUp = beamUp
reclaimer.reachingDist = reachingDist
reclaimer.pointerLength = pointerLength
reclaimer.buildTime = buildTime
reclaimer.centerBone = centerBone
reclaimer.poseHologram = poseHologram
reclaimer.getBonePos = getBonePos
reclaimer.drawHologram = drawHologram
reclaimer.reclaimBones = reclaimBones
reclaimer.restoreHologram = restoreHologram
