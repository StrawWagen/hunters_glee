AddCSLuaFile()

-- The night vision pack lying around, from the entities tab. Use it to put the pack in slot 5.
-- Same rules as the goggles pickups (glee_nvgpickup_base): one pair of goggles or one pack at a time.
-- Press E with the pack out to pick which goggles come out, see lua/weapons/glee_nvg_pack.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Night Vision Pack"
ENT.Category = "Hunter's Glee"
ENT.Spawnable = true
ENT.AdminOnly = game.IsDedicated()
ENT.Model = "models/props_junk/cardboard_box004a.mdl"

function ENT:Initialize()
    self:SetModel( self.Model )
    if not SERVER then return end

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
    self:SetUseType( SIMPLE_USE )
    self:PhysWake()

end

function ENT:SpawnFunction( ply, tr, class )
    if not tr.Hit then return end
    local ent = ents.Create( class )
    if not IsValid( ent ) then return end
    ent:SetPos( tr.HitPos + tr.HitNormal * 8 )
    ent:SetAngles( Angle( 0, ply:EyeAngles().y + 180, 0 ) )
    ent:Spawn()
    return ent

end

function ENT:Use( user )
    if not IsValid( user ) or not user:IsPlayer() or self.glee_PickedUp then return end
    if IsValid( user:GetGleeNVG() ) then
        user:PrintMessage( HUD_PRINTCENTER, "You can only carry one pair of goggles." )
        return

    end
    if user:HasWeapon( "glee_nvg_pack" ) then
        user:PrintMessage( HUD_PRINTCENTER, "You're already carrying a pack." )
        return

    end

    local wep = user:Give( "glee_nvg_pack" )
    if not IsValid( wep ) then return end

    self.glee_PickedUp = true
    user:SelectWeapon( wep )
    user:EmitSound( "items/ammo_pickup.wav", 60 )
    self:Remove()

end
