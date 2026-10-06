-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=3812596923
-- a SLAM stuck onto something by modules/stickyslams, falls to the ground when that something dies
-- any damage sets it off

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Sticky SLAM"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH -- the glow draws in the translucent pass

function ENT:SetupDataTables()
    self:NetworkVar( "Entity", 0, "SlamOwner" )

    -- where we sit on what we're stuck to, bone is -1 when we're parented to it as a whole
    self:NetworkVar( "Int", 0, "StuckBone" )
    self:NetworkVar( "Vector", 0, "StuckPos" )
    self:NetworkVar( "Angle", 0, "StuckAng" )

end

if CLIENT then
    -- where the server put us on ply, done by hand because the local player's bones aren't set up in first person,
    -- and player angles have pitch on the client, but not on the server
    local function poseOnPlayer( slam, ply )
        local bone = slam:GetStuckBone()
        if bone < 0 then
            local serverAng = Angle( 0, ply:GetAngles().y, 0 )
            return LocalToWorld( slam:GetStuckPos(), slam:GetStuckAng(), ply:GetPos(), serverAng )

        end

        ply:SetupBones()
        local matrix = ply:GetBoneMatrix( bone )
        if not matrix then return end

        return LocalToWorld( slam:GetStuckPos(), slam:GetStuckAng(), matrix:GetTranslation(), matrix:GetAngles() )

    end

    local function stuckPlayer( slam )
        local parent = slam:GetParent()
        if not IsValid( parent ) or not parent:IsPlayer() then return end

        return parent

    end

    local cullPadding = Vector( 16, 16, 16 )

    -- our real pos can be nowhere near where we draw, keep the culling box on the drawn pos
    function ENT:Think()
        local ply = stuckPlayer( self )
        local pos = ply and poseOnPlayer( self, ply )
        if pos then
            self:SetRenderBoundsWS( pos - cullPadding, pos + cullPadding )
            self.glee_movedRenderBounds = true

        elseif self.glee_movedRenderBounds then
            self:SetRenderBounds( self:GetModelBounds() )
            self.glee_movedRenderBounds = nil

        end
    end

    function ENT:Draw()
        local ply = stuckPlayer( self )
        if not ply then
            self:DrawModel()
            return

        end

        local pos, ang = poseOnPlayer( self, ply )
        if not pos then return end

        self:SetRenderOrigin( pos )
        self:SetRenderAngles( ang )
        self:DrawModel()
        self:SetRenderOrigin()
        self:SetRenderAngles()

    end

    -- the stock satchel's blinking light, an additive sprites/redglow1 at scale 0.2, with kRenderFxStrobeFast
    -- forced additive here, so it doesn't depend on how the sprite's own vmt blends
    local glowMaterial = CreateMaterial( "glee_stickyslam_glow", "UnlitGeneric", {
        ["$basetexture"] = "sprites/redglow1",
        ["$additive"] = 1,
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = 1,
    } )
    local glowSize = glowMaterial:Width() * 0.2

    -- the engine's kRenderFxStrobeFast, on whenever this is positive
    local function strobeFast( ent )
        return math.sin( CurTime() * 16 + ent:EntIndex() * 363 )

    end

    function ENT:DrawTranslucent()
        if strobeFast( self ) < 0 then return end

        local pos
        local ply = stuckPlayer( self )
        if ply then
            pos = poseOnPlayer( self, ply )

        else
            pos = self:GetPos()

        end
        if not pos then return end

        render.SetMaterial( glowMaterial )
        render.DrawSprite( pos, glowSize, glowSize, color_white )

    end

    return

end

local blastDamage = 150
local blastRadius = 150
local maxDetonateSoonDelay = 0.25
local triggeredDetonateDelay = 0.1 -- so the click can be heard

function ENT:Initialize()
    self:SetModel( "models/weapons/w_slam.mdl" )
    self:SetMoveType( MOVETYPE_NONE )
    -- solid so bullets can find it, debris so it doesn't get in anyone's way
    self:SetSolid( SOLID_OBB )
    self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    self:SetStuckBone( -1 )

end

local function fallOffCallbackName( slam )
    return "glee_stickySlamFallOff_" .. slam:GetCreationID()

end

-- GetBonePosition hands back the entity's origin when the server's bone cache is stale
local function bonePose( target, bone )
    local pos, ang = target:GetBonePosition( bone )
    if not pos then return end
    if pos ~= target:GetPos() then return pos, ang end

    local matrix = target:GetBoneMatrix( bone )
    if not matrix then return end

    return matrix:GetTranslation(), matrix:GetAngles()

end

-- nil for models with nothing FollowBone can use, like most props
local function nearestFollowableBone( target, pos )
    local nearestBone, nearestDist, nearestPos, nearestAng

    for bone = 0, target:GetBoneCount() - 1 do
        -- FollowBone needs a bone with a parent, that the model's mesh actually uses
        if target:GetBoneParent( bone ) < 0 then continue end
        if not target:BoneHasFlag( bone, BONE_USED_BY_VERTEX_LOD0 ) then continue end

        local bonePos, boneAng = bonePose( target, bone )
        if not bonePos then continue end

        local dist = bonePos:DistToSqr( pos )
        if nearestDist and dist >= nearestDist then continue end

        nearestBone = bone
        nearestDist = dist
        nearestPos = bonePos
        nearestAng = boneAng

    end

    return nearestBone, nearestPos, nearestAng

end

-- sticks to target at our current pos, riding its nearest bone if it has one
function ENT:StickTo( target )
    local pos, ang = self:GetPos(), self:GetAngles()
    local bone, bonePos, boneAng = nearestFollowableBone( target, pos )

    local localPos, localAng
    if bone then
        localPos, localAng = WorldToLocal( pos, ang, bonePos, boneAng )
        self:FollowBone( target, bone )
        self:SetStuckBone( bone )

    else
        localPos, localAng = WorldToLocal( pos, ang, target:GetPos(), target:GetAngles() )
        self:SetParent( target )

    end
    self:SetLocalPos( localPos )
    self:SetLocalAngles( localAng )
    self:SetStuckPos( localPos )
    self:SetStuckAng( localAng )

    -- props break, npcs get removed when they die
    target:CallOnRemove( fallOffCallbackName( self ), function()
        if not IsValid( self ) then return end
        self:FallOff()

    end )
end

function ENT:FallOff()
    local target = self:GetParent()
    if not IsValid( target ) then return end

    target:RemoveCallOnRemove( fallOffCallbackName( self ) )

    local pos, ang = self:GetPos(), self:GetAngles()
    self:SetParent()
    self:RemoveEffects( EF_FOLLOWBONE )
    self:SetStuckBone( -1 )
    self:SetPos( pos )
    self:SetAngles( ang )

    self:PhysicsInit( SOLID_VPHYSICS )

    local physObj = self:GetPhysicsObject()
    if IsValid( physObj ) then
        physObj:Wake()

    end
end

local function isCreature( ent )
    return ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()

end

-- dead players stick around as spectators, so they never get removed
function ENT:Think()
    local target = self:GetParent()
    if IsValid( target ) and isCreature( target ) and target:Health() <= 0 then
        self:FallOff()

    end

    self:NextThink( CurTime() + 0.1 )
    return true

end

-- only the first call counts, so this can only blow once
function ENT:DetonateAfter( delay )
    if self.glee_detonateQueued then return end
    self.glee_detonateQueued = true

    timer.Simple( delay, function()
        if not IsValid( self ) then return end
        self:Detonate()

    end )
end

-- the owner's detonator
function ENT:Trigger()
    if self.glee_detonateQueued then return end

    self:EmitSound( "weapons/slam/buttonclick.wav" )
    self:DetonateAfter( triggeredDetonateDelay )

end

-- random delay, so a cluster of SLAMs doesn't all go off in one tick
function ENT:DetonateSoon()
    self:DetonateAfter( math.Rand( 0, maxDetonateSoonDelay ) )

end

function ENT:OnTakeDamage()
    self:DetonateSoon()

end

-- use DetonateAfter, this blows every time it's called
function ENT:Detonate()
    local attacker = self:GetSlamOwner()
    if not IsValid( attacker ) then
        attacker = self

    end

    terminator_Extras.GleeFancySplode( self:GetPos(), blastDamage, blastRadius, attacker, self )
    self:Remove()

end

function ENT:OnRemove()
    local target = self:GetParent()
    if not IsValid( target ) then return end

    target:RemoveCallOnRemove( fallOffCallbackName( self ) )

end
