AddCSLuaFile()

SWEP.Base = "glee_simple_base_throwing"

SWEP.PrintName = "Skulls"
SWEP.Category = "Hunter's Glee"
SWEP.UseHands = true

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_throwable_skull", "materials/vgui/hud/glee_throwable_skull.png" )

end

SWEP.Slot = 5
SWEP.ViewModel = Model( "models/weapons/c_grenade.mdl" )
SWEP.Spawnable = true
SWEP.Purpose = "Throw rocks at people!"
SWEP.Instructions = "Aim for the head!"

SWEP.IdleHoldType = "slam"
SWEP.ThrowingHoldType = "melee"

SWEP.ProjectileClass = "termhunt_skull_pickup"

SWEP.ModelScale = 1
SWEP.ModelMaterial = nil
SWEP.ThrowVelMul = 0.85

SWEP.WorldModel = "models/gibs/hgibs.mdl"
SWEP.OffsetWorldModel = true
SWEP.WMPosOffset = Vector( 0, 2, 0 )
SWEP.WMAngOffset = Angle( 0, 180, -90 )

SWEP.HeldModel = SWEP.WorldModel
SWEP.HeldModelPosOffset = Vector( -22, 1.5, -21 )
SWEP.HeldModelAngOffset = Angle( -90, 180, 0 )

SWEP.AutoSwitchFrom = true
SWEP.AutoSwitchTo = false

function SWEP:ShouldDropOnDie()
    return false

end

function SWEP:EmitThrowSound()
    self:EmitSound( "WeaponFrag.Throw", 75, 120, 1, CHAN_WEAPON, SND_CHANGE_PITCH )

end

function SWEP:CreateEntity()
    local ent = ents.Create( self.ProjectileClass )
    if not IsValid( ent ) then return end

    ent:SetModel( self.WorldModel )
    ent:Spawn()

    ent.nextPickup = CurTime() + 1
    ent:SetModelScale( self.ModelScale )
    ent:Activate()
    ent:SetPhysicsAttacker( self:GetOwner(), 10 )

    local owner = self:GetOwner()
    if owner:IsPlayer() then
        if owner.GivePlayerSkulls then
            owner:GivePlayerSkulls( -1 )

        end
    else
        SafeRemoveEntityDelayed( self, 0.5 )

    end

    return ent

end

if GAMEMODE.IsReallyHuntersGlee then
    SWEP.InfiniteAmmo = false
    function SWEP:StillHasAmmo( owner )
        return owner:GetSkulls() > 0

    end

    function SWEP:CustomAmmoDisplay()
        local owner = self:GetOwner()
        return { Draw = true, PrimaryClip = owner:GetSkulls() }

    end

else
    SWEP.InfiniteAmmo = true
    function SWEP:CustomAmmoDisplay()
        return { Draw = false }

    end
end