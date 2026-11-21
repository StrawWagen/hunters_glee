AddCSLuaFile()

-- A pair of night vision goggles lying around, from the entities tab. Use it to put them in slot 6.
-- Each glee_nvgpickup_* sets ENT.Gives to its glee_nvg_* weapon, and takes that weapon's model.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Night Vision"
ENT.Category = "Hunter's Glee"
ENT.Spawnable = false
ENT.Gives = ""

function ENT:Initialize()
    local stored = weapons.GetStored( self.Gives )
    self:SetModel( stored and stored.WorldModel or "models/glee/nvg/nvg_gpnvg.mdl" )
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

    local wep = user:Give( self.Gives )
    if not IsValid( wep ) then return end

    self.glee_PickedUp = true
    user:EmitSound( "items/ammo_pickup.wav", 60 )
    self:Remove()

end
