-- The Medical Tissue Reclaimer's look and beams, included by shared.lua
-- the hud, the kit's model, where its beams leave it, recoil, spots on a body, and drawing one beam
-- cl_projection.lua and cl_draw.lua build on these

local reclaimer = SWEP.Reclaimer
local pointOutRange = reclaimer.pointOutRange
local outOfMaterialText = reclaimer.outOfMaterialText

local beamMat = Material( "sprites/bluelaser1" )
local glowMat = Material( "sprites/light_glow02_add" )
local hologramMat = Material( "models/alyx/emptool_glow" ) -- additive, tinted by colour modulation, like the infernal skeleton's glow
local reclamationColor = Color( 120, 255, 60 ) -- the canister's green
local brokeColor = Color( 120, 120, 120 ) -- can't afford a revive
local drawColor = Color( 0, 0, 0 )


-- Hud -----------------------------------------------------------------------

-- every dead player we could revive, nearest first
function SWEP:RevivablesByDistance()
    local ownerPos = self:GetOwner():GetPos()
    local revivables = {}
    for _, data in ipairs( self:GetGamemodeDeadPlayerData() ) do
        if not IsValid( data.ply ) then continue end
        if not data.pos then continue end
        if not self:CanResurrect( data.ply ) then continue end
        table.insert( revivables, data )

    end

    table.sort( revivables, function( a, b )
        return ownerPos:DistToSqr( a.pos ) < ownerPos:DistToSqr( b.pos )

    end )
    return revivables

end

-- where ply will be revived, nil if we can't revive them
function SWEP:RevivableData( ply )
    if not self:CanResurrect( ply ) then return end

    for _, data in ipairs( self:GetGamemodeDeadPlayerData() ) do
        if data.ply == ply and data.pos then return data end

    end
end

function SWEP:HintPostStack()
    local owner = self:GetOwner()

    if self:IsOutOfMaterial() then
        local msg = outOfMaterialText .. "\nBuy another Medical Tissue Reclaimer in the shop..."
        if owner:Health() >= owner:GetMaxHealth() then
            msg = msg .. "\nOr pick up some Health off the ground..."

        end
        return true, msg

    end

    -- until their first revive, a step at a time. Close enough, the beam's become a projection, see UpdateProjected
    if not owner:GetNW2Bool( "gleereclaimer_resurrected", false ) and self:CanAffordRevive() and self:RevivablesByDistance()[1] then
        if self.glee_projectedDead then
            return true, "Hold primary attack on their projection to reclaim them."

        end
        return true, "The beam leads you to a Death Location."

    end

    if not owner:GetNW2Bool( "gleereclaimer_healedself", false ) and owner:Health() < owner:GetMaxHealth() then return true, "Hold secondary attack to heal yourself!" end
    if not owner:GetNW2Bool( "gleereclaimer_healedother", false ) then
        for _, ply in player.Iterator() do
            if ply == owner then continue end
            local theirHp = ply:Health()
            if theirHp <= 0 then continue end
            if theirHp >= ply:GetMaxHealth() then continue end
            if ply:GetPos():DistToSqr( owner:GetPos() ) > 300^2 then continue end

            return true, "Hold primary attack to heal others!\nIt's much faster than healing yourself."

        end
    end
end

function SWEP:DrawHUD()
    if self:IsReviving() then return end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    if self.PaintPlyHooking then return end
    self.PaintPlyHooking = true

    local ownerWhenHookCreated = owner

    -- nameplates over every revivable dead player in range
    hook.Add( "glee_cl_shouldpaintply_whilealive", self, function( _self, ent )
        local currentOwner = self:GetOwner()
        if currentOwner ~= ownerWhenHookCreated then
            self.PaintPlyHooking = nil
            hook.Remove( "glee_cl_shouldpaintply_whilealive", self )
            return

        end
        local ownersActiveWeapon = currentOwner:GetActiveWeapon()
        if ownersActiveWeapon ~= self then
            self.PaintPlyHooking = nil
            hook.Remove( "glee_cl_shouldpaintply_whilealive", self )
            return

        end

        if ent == LocalPlayer() then return end -- spectating whoever holds it

        local deadDat = self:RevivableData( ent )
        if not deadDat then return end
        if deadDat.pos:DistToSqr( currentOwner:GetPos() ) > pointOutRange^2 then return end

        return deadDat.pos, true, true -- pos override, draw at any distance, and draw even if dead

    end )
end


-- The kit's look --------------------------------------------------------
-- a gravity gun with a health kit strapped on, see MyExtraModels in the terminator addon's readme
-- pos and ang are local to the attachment, tune them in game, autorefresh works

local vmKitExtras = {
    {
        model = "models/items/healthkit.mdl",
        bone = "Base", -- drawn in the viewmodel's own fov, where its attachments, moved into the world's, would be off
        pos = Vector( 0, -1, -7 ),
        ang = Angle( 120, 90, 0 ),
        scale = 0.75,
    },
    {
        model = "models/healthvial.mdl",
        bone = "Base",
        pos = Vector( 0, 0, 0 ),
        ang = Angle( 0, 0, 0 ),
        scale = 1.5,
    }
}
local wmKitExtras = {
    {
        model = "models/items/healthkit.mdl",
        attachment = "core",
        pos = Vector( -14, 2, 0 ),
        ang = Angle( 180, 30, -90 ),
        scale = 0.6,
    },
    {
        model = "models/healthvial.mdl",
        attachment = "core",
        pos = Vector( -12, 3, 0 ),
        ang = Angle( 90, 0, 0 ),
        scale = 0.9,
    }
}

-- the prongs part while there's a body to project, then spread wide as it's revived
-- they part a little aimed at someone to heal, or turning onto the medic, and spread while healing
-- of the way open, the "active" pose param on both models
local prongOpenAimedHealable = 0.25
local prongOpenProjecting = 0.35
local prongOpenSelfAimed = 0.5
local prongOpenHealingSelf = 0.75
local prongOpenHealingOther = 1
local prongOpenSpeed = 3 -- of the way open per second
local prongShutSpeed = 1.5

-- slams them shut, eg as the revived stand up
function SWEP:ShutProngs()
    self.glee_prongOpen = 0

end

-- eases the prongs toward open or shut, once a frame, see DrawBeams
-- reviveFrac, 0 to 1 of the way through reviving who's projected, nil when nobody is being
function SWEP:UpdateProngs( projecting, reviveFrac, aimedHealable )
    local frame = FrameNumber()
    if self.glee_prongFrame == frame then return end
    self.glee_prongFrame = frame

    local target = 0
    if projecting then
        target = Lerp( reviveFrac or 0, prongOpenProjecting, 1 )

    end
    if aimedHealable then
        target = math.max( target, prongOpenAimedHealable )

    end
    target = math.max( target, self:ShownSelfAim() * prongOpenSelfAimed )

    local healTarget = self:GetHealTarget()
    if IsValid( healTarget ) then
        target = math.max( target, healTarget == self:GetOwner() and prongOpenHealingSelf or prongOpenHealingOther )

    end

    local open = self.glee_prongOpen or 0
    local speed = target > open and prongOpenSpeed or prongShutSpeed
    self.glee_prongOpen = math.Approach( open, target, speed * FrameTime() )

end

-- gmod's physgun is these same models, glowing in its owner's weapon colour
-- so the kit draws with its own copies of their materials, glowing reclamation green, see materials/tissue_reclaimer
-- overridden only for the draw, the viewmodel is shared with every other weapon
-- the unlit copies are for when it's out of material
local vmGlowMat = Material( "tissue_reclaimer/v_reclaimer_sheet" )
local wmGlowMat = Material( "tissue_reclaimer/w_reclaimer_sheet" )
local vmUnlitMat = Material( "tissue_reclaimer/v_reclaimer_sheet_unlit" )
local wmUnlitMat = Material( "tissue_reclaimer/w_reclaimer_sheet_unlit" )
local wmGlowSlots = { 0, 1 } -- w_physics's material slots that use w_physics_sheet2, on its glowing skin

-- dropped, nobody's ammo is in it, so it glows
function SWEP:IsGlowing()
    return not ( IsValid( self:GetOwner() ) and self:GetOutOfMaterial() )

end

function SWEP:DrawWorldModel( flags )
    self:SetPoseParameter( "active", self.glee_prongOpen or 0 )
    self:InvalidateBoneCache() -- the beams may have read its attachments already this frame

    local mat = self:IsGlowing() and wmGlowMat or wmUnlitMat
    for _, slot in ipairs( wmGlowSlots ) do
        render.MaterialOverrideByIndex( slot, mat )

    end
    self:DrawModel( flags )
    for _, slot in ipairs( wmGlowSlots ) do
        render.MaterialOverrideByIndex( slot, nil )

    end

    terminator_Extras.DrawMyExtraModels( self, wmKitExtras, flags )

end

function SWEP:PreDrawViewModel( vm )
    vm:SetPoseParameter( "active", self.glee_prongOpen or 0 )
    vm:InvalidateBoneCache() -- the beams read its attachments already this frame
    render.MaterialOverrideByIndex( 0, self:IsGlowing() and vmGlowMat or vmUnlitMat )

end

function SWEP:PostDrawViewModel( vm )
    render.MaterialOverrideByIndex( 0, nil )
    terminator_Extras.DrawMyExtraModels( vm, vmKitExtras )

end


-- Where the beams leave the kit -----------------------------------------
-- the main beams from the barrel, the rays from the prongs' tips
-- like the flashlight module, see cl_flashlight.lua

local vmBeamAttachment = "muzzle"
local wmBeamAttachment = "core"
local vmProngTips = { "fork1t", "fork2t" }
-- w_physics has no attachments but core, so the world model has no tips, its rays leave from the beam start instead
local noProngTips = {}

-- seeing through owner's eyes, with their viewmodel, ours or a spectated player's
local function isSeenInFirstPerson( owner )
    local me = LocalPlayer()
    if owner == me then
        return not me:ShouldDrawLocalPlayer() and me:GetObserverMode() == OBS_MODE_NONE

    end
    return me:GetObserverMode() == OBS_MODE_IN_EYE and me:GetObserverTarget() == owner

end

-- the viewmodel we're seeing the kit as, nil when it's the world model
function SWEP:SeenViewModel()
    if not isSeenInFirstPerson( self:GetOwner() ) then return end

    local vm = LocalPlayer():GetViewModel()
    if IsValid( vm ) then return vm end

end

-- where one of the kit's attachments is this frame, on vm, or on the world model without one
-- a viewmodel's attachments come out already moved into the world's fov, unlike its bones
-- only good while rendering, the viewmodel's placed for this frame by then, offsets from GetViewModelPosition and all
-- unlike cl_flashlight.lua, which runs before that, and has to carry it to this frame's eyes
local function getKitAttachment( wep, vm, name )
    local ent = vm or wep
    local attach = ent:GetAttachment( ent:LookupAttachment( name ) )
    if not attach then return end

    return attach.Pos, attach.Ang

end

-- BeamStart and ProngTips are found once a frame, for the viewmodel and the world model apart
-- a frame draws more than one view, eg water reflections, which can see the world model while our eyes see the viewmodel
-- what they return is shared until the next frame, don't change it

-- where the beams leave the kit, and the kit's angles, for holding beams relative to it
function SWEP:BeamStart()
    local vm = self:SeenViewModel()
    local starts = self.glee_beamStarts
    if not starts then
        starts = { vm = {}, wm = {} }
        self.glee_beamStarts = starts

    end

    local cached = vm and starts.vm or starts.wm
    local frame = FrameNumber()
    if cached.frame == frame then return cached.pos, cached.ang end
    cached.frame = frame

    local pos, ang
    if vm then
        pos, ang = getKitAttachment( self, vm, vmBeamAttachment )

    end
    if not pos then
        pos, ang = getKitAttachment( self, nil, wmBeamAttachment )

    end

    cached.pos, cached.ang = pos, ang
    return pos, ang

end

-- where the rays leave, empty if none of the tips could be found
function SWEP:ProngTips()
    local vm = self:SeenViewModel()
    if not vm then return noProngTips end

    local tips = self.glee_prongTips
    local frame = FrameNumber()
    if tips and self.glee_prongTipsFrame == frame then return tips end
    self.glee_prongTipsFrame = frame

    tips = tips or {}
    self.glee_prongTips = tips

    local count = 0
    for _, name in ipairs( vmProngTips ) do
        local pos = getKitAttachment( self, vm, name )
        if pos then
            count = count + 1
            tips[count] = pos

        end
    end
    for index = #tips, count + 1, -1 do
        tips[index] = nil

    end

    return tips

end


-- Recoil ----------------------------------------------------------------
-- the kit twitches in the medic's hands every time a bone goes in, a touch on top of the server's shoves
-- only the viewmodel twitches, see GetViewModelPosition

local jostleDecay = 8 -- how fast a kick settles, per second
local jostleKickPos = 0.4 -- units, along the viewmodel's own axes
local jostleKickAng = 1.5 -- degrees

-- what's left of every kick so far, nil before the first
function SWEP:CurrentJostle()
    local jostlePos = self.glee_jostlePos
    if not jostlePos then return end

    local left = math.exp( -( CurTime() - self.glee_jostleTime ) * jostleDecay )
    return jostlePos * left, self.glee_jostleAng * left

end

function SWEP:Jostle()
    local jostlePos, jostleAng = self:CurrentJostle()
    jostlePos = jostlePos or Vector( 0, 0, 0 )
    jostleAng = jostleAng or Angle( 0, 0, 0 )

    local kickAng = Angle( math.Rand( -1, 1 ), math.Rand( -1, 1 ), math.Rand( -1, 1 ) ) * jostleKickAng
    self.glee_jostlePos = jostlePos + VectorRand() * jostleKickPos
    self.glee_jostleAng = jostleAng + kickAng
    self.glee_jostleTime = CurTime()

end

function SWEP:ApplyJostle( pos, ang )
    local jostlePos, jostleAng = self:CurrentJostle()
    if not jostlePos then return pos, ang end

    return LocalToWorld( jostlePos, jostleAng, pos, ang )

end

-- Spots on a body -------------------------------------------------------
-- a bone's position is its joint, the shoulder for an upper arm
-- so rays and blood land somewhere inside the bone instead, in its hitbox

-- per model, its hitboxes in list, and by the bone they're on in byBone
-- each { bone, mins, maxs }, in the bone's own space
local hitboxesCache = {}

local function getHitboxes( ent )
    local mdl = ent:GetModel()
    local hitboxes = hitboxesCache[mdl]
    if hitboxes then return hitboxes end

    hitboxes = { list = {}, byBone = {} }
    local hitboxSet = 0
    for hitbox = 0, ( ent:GetHitBoxCount( hitboxSet ) or 0 ) - 1 do
        local mins, maxs = ent:GetHitBoxBounds( hitbox, hitboxSet )
        if mins then
            local box = { bone = ent:GetHitBoxBone( hitbox, hitboxSet ), mins = mins, maxs = maxs }
            table.insert( hitboxes.list, box )
            hitboxes.byBone[box.bone] = box

        end
    end

    hitboxesCache[mdl] = hitboxes
    return hitboxes

end

local function randomInBox( box )
    local mins, maxs = box.mins, box.maxs
    return Vector( math.Rand( mins.x, maxs.x ), math.Rand( mins.y, maxs.y ), math.Rand( mins.z, maxs.z ) )

end

-- somewhere inside bone, see spotPos. Its joint when it has no hitbox
local function randomSpotOnBone( ent, bone )
    local box = getHitboxes( ent ).byBone[bone]
    return { bone = bone, offset = box and randomInBox( box ) or vector_origin }

end

-- somewhere inside any of ent's bones, nil if it has none
local function randomSpot( ent )
    local list = getHitboxes( ent ).list
    if #list > 0 then
        local box = list[math.random( #list )]
        return { bone = box.bone, offset = randomInBox( box ) }

    end

    local boneCount = ent:GetBoneCount()
    if boneCount <= 0 then return end
    return { bone = math.random( 0, boneCount - 1 ), offset = vector_origin }

end

-- where spot is on ent right now, it moves with its bone. nil if the bone isn't set up
local function spotPos( ent, spot )
    local matrix = ent:GetBoneMatrix( spot.bone )
    if not matrix then return end

    return LocalToWorld( spot.offset, angle_zero, matrix:GetTranslation(), matrix:GetAngles() )

end


-- Holding the aim to the kit --------------------------------------------
-- each beam re-aims every few frames, and in between is held where it was, relative to the kit
-- a still kit stays on target, a swung one throws its projection off course until it re-aims

local reaimFrames = { 1, 3 }
local rayCount = 5 -- the rays besides the main beam, to random spots every re-aim

-- how far off true each aim lands, and how much the middle of a beam shakes every frame
local jitterMin, jitterMax = 1, 2

local function jitter()
    return VectorRand():GetNormalized() * math.Rand( jitterMin, jitterMax )

end

-- takes the goal, a little off, when it's time to re-aim, otherwise moves the last aim along with the kit
-- takes one table, aim. It's every frame, so its caller keeps one and refills every field each call, nil for the default:
--   dead, who it's for, each dead player's aim is held on its own
--   kitPos, kitAng, where the kit is now, see BeamStart
--   goalPos, where the projection should stand
--   goalAng, which way it should face. Defaults to angle_zero
--   goalDir, the way the beams should leave the kit
--   body, to pick spots on for the rays, nil for none
-- returns where dead's beams start, where their projection stands and faces, the way the beams leave the kit,
-- and the spots on body the rays go to, see spotPos, nil without a body
function SWEP:HeldProjection( aim )
    local dead = aim.dead
    local kitPos = aim.kitPos
    local kitAng = aim.kitAng
    local body = aim.body

    self.glee_heldProjections = self.glee_heldProjections or {}

    local held = self.glee_heldProjections[dead]
    if not held then
        held = {}
        self.glee_heldProjections[dead] = held

    end

    local frame = FrameNumber()
    if not held.start or held.nextFrame <= frame then
        held.start = jitter()
        held.pos, held.ang = WorldToLocal( aim.goalPos + jitter(), aim.goalAng or angle_zero, kitPos, kitAng )
        held.dir = WorldToLocal( aim.goalDir, angle_zero, vector_origin, kitAng )
        held.nextFrame = frame + math.random( reaimFrames[1], reaimFrames[2] )

        held.raySpots = nil
        if body then
            held.raySpots = {}
            for ray = 1, rayCount do
                held.raySpots[ray] = randomSpot( body ) -- nil without any bones, and the list stays empty

            end
        end
    end

    local heldStart = LocalToWorld( held.start, angle_zero, kitPos, kitAng )
    local heldPos, heldAng = LocalToWorld( held.pos, held.ang, kitPos, kitAng )
    local heldDir = LocalToWorld( held.dir, angle_zero, vector_origin, kitAng )
    return heldStart, heldPos, heldAng, heldDir, held.raySpots

end


-- Drawing one beam ------------------------------------------------------

local beamSegments = 12
local beamWidth = 3
local rayWidth = 1.5
local diffuseWidth = 16 --the main beam's last segment flares out to this, diffusing into the projection

-- beams stop at the world, traced every this many segments. The curve between is checked as a straight line
local wallCheckSegments = 2
local splashSize = 8 -- per unit of beam width
local wallTraceResult = {}
local wallTrace = { mask = MASK_SOLID_BRUSHONLY, output = wallTraceResult }

-- other players' kits, far from our eyes, are a pixel or two wide, so their beams simplify and then stop
local beamLod = {
    simpleDist = 1000, -- past this, just the main beams, simple ones, see drawBeam
    simpleSlack = 100, -- either side of simpleDist, once a kit's beams switch they stay until this far back, so the edge doesn't flicker
    cullDist = 5000, -- past this, none at all
    simpleSegments = 4,
}

-- the clean curve, before jitter, so a beam grazing a corner doesn't flicker between cut and not
-- reused by every beam, only the first beamPointCount are this beam's
local beamPoints = {}
local beamFracs = {}

-- where a beam meets a wall, fade 0 to 1 is how faded out the beam is there, it shrinks with it
local function drawSplash( pos, normal, color, fade, width )
    local size = width * splashSize * fade * math.Rand( 0.8, 1.2 )
    if size <= 0 then return end

    drawColor.r, drawColor.g, drawColor.b = color.r, color.g, color.b
    drawColor.a = 255 * fade
    render.SetMaterial( glowMat )
    render.DrawQuadEasy( pos + normal * 0.5, normal, size, size, drawColor, math.Rand( 0, 360 ) )
    render.DrawSprite( pos + normal * 0.75, size * 0.5, size * 0.5, drawColor )

end

-- drawBeam's, for the fields left nil
local beamDefaults = {
    tipAlpha = 1, -- it fades toward its tip, to this. 1 is solid all the way
    alpha = 1, -- the whole beam's
    bend = 0.5, -- how far it carries on along startDir before turning, times its length
}

local jitterOffset = Vector() -- reused for every point

-- leaves the kit along the aim, then bends toward endPos, or stops at a wall
-- takes one table, beam. It's drawn every frame, so each caller keeps one of its own and refills every field each call, nil for the default:
--   startPos, startDir, endPos, color, width, required
--   tipAlpha, alpha, bend, see beamDefaults
--   tipWidth, if given, its last segment flares out to this, then tapers away into whatever's at endPos. Not at a wall
--   simple, for far away, see beamLod. Fewer segments, one wall trace, no jitter
-- returns whether it made it to endPos
local function drawBeam( beam )
    local startPos = beam.startPos
    local endPos = beam.endPos
    local color = beam.color
    local width = beam.width
    local tipWidth = beam.tipWidth
    local simple = beam.simple
    local tipAlpha = beam.tipAlpha or beamDefaults.tipAlpha
    local alpha = beam.alpha or beamDefaults.alpha

    local length = startPos:Distance( endPos )
    local control = startPos + beam.startDir * length * ( beam.bend or beamDefaults.bend )
    local scroll = CurTime() * 2 -- material flowing out of the kit

    local segments = simple and beamLod.simpleSegments or beamSegments
    local checkEvery = simple and segments or wallCheckSegments

    local beamPointCount = 0
    local hitWall = false
    local checkedPos, checkedFrac = startPos, 0
    for segment = 0, segments do
        local frac = segment / segments
        local point = math.QuadraticBezier( frac, startPos, control, endPos )
        beamPointCount = beamPointCount + 1
        beamPoints[beamPointCount] = point
        beamFracs[beamPointCount] = frac

        local checkHere = segment > 0 and ( segment % checkEvery == 0 or segment == segments )
        if checkHere then
            wallTrace.start = checkedPos
            wallTrace.endpos = point
            util.TraceLine( wallTrace )

            -- starting solid is the kit pushed into a wall, let the beam out rather than cut it at the kit
            if wallTraceResult.Hit and not wallTraceResult.StartSolid then
                -- the trace spans more than one segment, drop the points already past the wall
                local cutFrac = Lerp( wallTraceResult.Fraction, checkedFrac, frac )
                while beamPointCount > 1 and beamFracs[beamPointCount] >= cutFrac do -- the kit's point always stays
                    beamPointCount = beamPointCount - 1

                end

                beamPointCount = beamPointCount + 1
                beamPoints[beamPointCount] = wallTraceResult.HitPos
                beamFracs[beamPointCount] = cutFrac
                hitWall = true
                break

            end
            checkedPos, checkedFrac = point, frac

        end
    end

    -- the flared last segment is its own beam. Widening one point of a beam twists it into a ribbon
    local flaring = tipWidth and not hitWall and beamPointCount > 2
    local thinCount = flaring and beamPointCount - 1 or beamPointCount

    drawColor.r, drawColor.g, drawColor.b = color.r, color.g, color.b
    render.SetMaterial( beamMat )
    render.StartBeam( thinCount )
    local point, frac
    for index = 1, thinCount do
        point = beamPoints[index]
        frac = beamFracs[index]
        -- the ends stay put, on the kit and on the body or wall
        if not simple and index > 1 and index < beamPointCount then
            jitterOffset:SetUnpacked( math.Rand( -1, 1 ), math.Rand( -1, 1 ), math.Rand( -1, 1 ) )
            jitterOffset:Normalize()
            jitterOffset:Mul( math.Rand( jitterMin, jitterMax ) )
            point:Add( jitterOffset ) -- the point's this beam's own, done with once it's added

        end

        drawColor.a = 255 * alpha * ( 1 - frac * ( 1 - tipAlpha ) )
        render.AddBeam( point, width, frac * length / 32 - scroll, drawColor )

    end
    render.EndBeam()

    if flaring then
        local tipFrac = beamFracs[beamPointCount]
        render.StartBeam( 2 )
        render.AddBeam( point, tipWidth, frac * length / 32 - scroll, drawColor )
        drawColor.a = 255 * alpha * ( 1 - tipFrac * ( 1 - tipAlpha ) )
        render.AddBeam( beamPoints[beamPointCount], 0, tipFrac * length / 32 - scroll, drawColor ) -- tapering away into it
        render.EndBeam()

    end

    if hitWall then
        drawSplash( beamPoints[beamPointCount], wallTraceResult.HitNormal, color, drawColor.a / 255, width )

    end
    return not hitWall

end


-- Arcs ------------------------------------------------------------------
-- material jolting out of the kit, where the tissue goes back in hard. See eff_term_goodarc in the terminator addon

local arcColor = Angle( reclamationColor.r, reclamationColor.g, reclamationColor.b )

local ARC_NO_LIGHT = 1
local ARC_NO_SOUND = 16
local ARC_PASS_WORLD = 32
local ARC_NO_DECAL = 128

-- leaves along startDir, then turns onto endPos
-- flags, eff_term_goodarc's. The kit's own sounds and lights are usually enough, so most arcs pass ARC_NO_SOUND and ARC_NO_LIGHT
local function reclamationArc( startPos, startDir, endPos, scale, flags )
    -- every setting set, see eff_term_goodarc
    local fx = EffectData()
        fx:SetOrigin( startPos )
        fx:SetStart( endPos )
        fx:SetNormal( startDir )
        fx:SetScale( scale )
        fx:SetMagnitude( 8 ) -- segments
        fx:SetRadius( 6 * scale ) -- jitter
        fx:SetAngles( arcColor )
        fx:SetDamageType( 2 ) -- branches
        fx:SetEntity( NULL )
        fx:SetFlags( flags )
    util.Effect( "eff_term_goodarc", fx )

end


-- What the other files use --------------------------------------------------

reclaimer.glowMat = glowMat
reclaimer.hologramMat = hologramMat
reclaimer.reclamationColor = reclamationColor
reclaimer.brokeColor = brokeColor
reclaimer.drawColor = drawColor
reclaimer.randomSpot = randomSpot
reclaimer.randomSpotOnBone = randomSpotOnBone
reclaimer.spotPos = spotPos
reclaimer.beamWidth = beamWidth
reclaimer.rayWidth = rayWidth
reclaimer.diffuseWidth = diffuseWidth
reclaimer.beamLod = beamLod
reclaimer.drawBeam = drawBeam
reclaimer.reclamationArc = reclamationArc
reclaimer.ARC_NO_LIGHT = ARC_NO_LIGHT
reclaimer.ARC_NO_SOUND = ARC_NO_SOUND
reclaimer.ARC_PASS_WORLD = ARC_PASS_WORLD
reclaimer.ARC_NO_DECAL = ARC_NO_DECAL
