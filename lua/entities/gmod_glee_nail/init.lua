
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile()

include( "shared.lua" )

/*---------------------------------------------------------
   Name: Initialize
   Desc: First function called. Use to set up your entity
---------------------------------------------------------*/
function ENT:Initialize()

    self:SetUseType( CONTINUOUS_USE )

    self:SetModel( "models/crossbow_bolt.mdl" )
    self.DoNotDuplicate = true

end

function ENT:Attach( pos, ang, ent, bone )
    self:SetPos( pos )
    self:SetAngles( ang )
    self:SetParentPhysNum( bone )
    self:SetParent( ent )

end

local invis = Color( 255, 255, 255, 0 )

function ENT:UpdateConstraints()
    local ent = self.mainEnt
    if not IsValid( ent ) then return end

    local phys = ent:GetPhysicsObject()

    if not phys then return end
    if not phys:IsValid() then return end

    local frozen = not phys:IsMotionEnabled()
    local aSolidAnchor = nil

    -- find world nails
    if ent.huntersglee_breakablenails then
        for _, nail in pairs( ent.huntersglee_breakablenails ) do
            if nail.secondEnt:IsWorld() then
                aSolidAnchor = true

            end
        end
    end
    if aSolidAnchor and not frozen then
        phys:EnableMotion( false )

    elseif not aSolidAnchor and frozen then
        phys:EnableMotion( true )

    end
end

function ENT:Detach()
    local fake = ents.Create( "prop_physics" )
    fake:SetModel( "models/Items/CrossbowRounds.mdl" )
    fake:SetPos( self:GetPos() )
    fake:SetAngles( self:GetAngles() )
    fake:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    fake:Spawn()

    fake:SetRenderMode( RENDERMODE_TRANSCOLOR )
    fake:SetColor( invis )

    local obj = fake:GetPhysicsObject()
    obj:ApplyForceCenter( self:GetForward() * -1000 )
    obj:SetMaterial( "Metal" )

    self:SetParent( fake )
    self:DeleteOnRemove( fake )

    self:UpdateConstraints()

end

function ENT:Strain()
    self:EmitSound( "physics/metal/metal_box_strain" .. math.random( 1, 4 ) .. ".wav", 80, 100, 1, CHAN_STATIC )

end

function ENT:Break()

    SafeRemoveEntity( self.realConstraint )

    local Sparks = EffectData()
    Sparks:SetOrigin( self:GetPos() )
    Sparks:SetMagnitude( 2 )
    Sparks:SetScale( 1 )
    Sparks:SetRadius( 6 )
    util.Effect( "Sparks", Sparks )

    self:EmitSound( "physics/metal/metal_box_strain" .. math.random( 1, 4 ) .. ".wav", 80, 200, 1, CHAN_STATIC )

    if IsValid( self.mainEnt ) then
        self:unregister( self.mainEnt )
        self:EmitSound( "physics/metal/metal_box_impact_hard" .. math.random( 1, 3 ) .. ".wav", 80, math.random( 70, 90 ), 1, CHAN_STATIC )
        util.ScreenShake( self:GetPos(), 10, 20, 0.1, 700 )

    end

    self:Detach()

    SafeRemoveEntityDelayed( self, 10 )

end

hook.Add( "EntityTakeDamage", "nail_break_when_nailed_damaged", function( target, dmg )
    local nails = target.huntersglee_breakablenails

    if not nails then return end

    -- stupid bug, bot crushes off all nails at once
    if dmg:IsDamageType( DMG_CRUSH ) and IsValid( dmg:GetAttacker() ) and dmg:GetAttacker().isTerminatorHunterBased and IsValid( dmg:GetInflictor() ) and dmg:GetInflictor().isTerminatorHunterBased then return end

    -- randomly break nails, if lots of damage then break reliably
    local damage = dmg:GetDamage()

    if dmg:IsExplosionDamage() then
        damage = damage * 4

    end

    while damage > 0 do
        local bite = math.random( 1, 150 )
        tempDamage = damage - bite
        local randNail, nailsKey = table.Random( nails )
        if IsValid( randNail ) then
            if tempDamage > 0 then
                randNail:Break()
                dmg:ScaleDamage( 0.1 ) -- nails absorb damage!
                damage = tempDamage

            else
                randNail:Strain()
                dmg:ScaleDamage( 0 )
                break

            end
        else
            if table.Count( nails ) > 0 then
                table.remove( nails, nailsKey )

            else
                target.huntersglee_breakablenails = nil
                break

            end
        end
    end
end )

-- doesn't seem to work
function ENT:Use( user )
    if not user:IsPlayer() then return end

    self:Break()

end