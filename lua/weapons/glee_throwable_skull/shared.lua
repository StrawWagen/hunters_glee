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

    local owner = self:GetOwner()

    ent.glee_skullThrower = owner
    ent.nextThrowerPickup = CurTime() + 1
    ent.nextPickup = CurTime() + 0.01
    ent:SetModelScale( self.ModelScale )
    ent:Activate()
    ent:SetPhysicsAttacker( owner, 10 )

    if owner:IsPlayer() then
        if owner.GivePlayerSkulls then
            owner:GivePlayerSkulls( -1 )

        end
    else
        SafeRemoveEntityDelayed( self, 0.5 )

    end

    return ent

end

hook.Add( "glee_skull_blockpickup", "glee_dontpickup_thrownskull", function( picker, skull )
    local thrower = skull.glee_skullThrower
    if not IsValid( thrower ) then return end
    if picker ~= thrower then return end

    if skull.nextThrowerPickup < CurTime() then return end

    return true -- block pickup

end )

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