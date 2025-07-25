AddCSLuaFile()

SWEP.PrintName = "Medkit"
SWEP.Author = "robotboy655 & MaxOfS2D"
SWEP.Purpose = "Heal people with your primary attack, or yourself with the secondary."
SWEP.Category = "Hunter's Glee"

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_medkit.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_medkit.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.HoldType = "slam"

SWEP.Primary.ClipSize = math.huge
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.OwnerHealAmount = 8
SWEP.HealAmount = 20 -- Maximum heal amount per use
SWEP.MaxAmmo = math.huge -- Maxumum ammo

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "termhunt_medkit", "materials/vgui/hud/termhunt_medkit.png" )
    function SWEP:HintPostStack()
        local owner = self:GetOwner()
        if not owner:GetNW2Bool( "gleemedkit_healedself", false ) and owner:Health() < owner:GetMaxHealth() then return true, "Secondary attack to heal yourself!" end
        if not owner:GetNW2Bool( "gleemedkit_healedother", false ) and #player.GetAll() > 1 then
            local players = player.GetAll()
            local canHeal
            for _, ply in ipairs( players ) do
                if ply == owner then continue end
                local theirHp = ply:Health()
                if theirHp <= 0 then continue end
                if theirHp >= ply:GetMaxHealth() then continue end
                if ply:GetPos():DistToSqr( owner:GetPos() ) > 300^2 then continue end

                canHeal = true

            end
            if canHeal then
                return true, "Primary attack to heal others!\nIt's much faster than healing yourself."

            end
        end
    end
end

local HealSound = Sound( "HealthKit.Touch" )
local DenySound = Sound( "WallHealth.Deny" )

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    self:HealJuice( 200 )

end

function SWEP:HealJuice( juiceAmnt )
    self:SetClip1( self:Clip1() + juiceAmnt )


end

function SWEP:PrimaryAttack()

    if CLIENT then return end

    if self:GetOwner():IsPlayer() then
        self:GetOwner():LagCompensation( true )
    end

    local tr = util.TraceLine( {
        start = self:GetOwner():GetShootPos(),
        endpos = self:GetOwner():GetShootPos() + self:GetOwner():GetAimVector() * 64,
        filter = self:GetOwner()
    } )

    if self:GetOwner():IsPlayer() then
        self:GetOwner():LagCompensation( false )
    end

    local ent = tr.Entity

    local need = self.HealAmount * 2 -- healing other players is super efficient 
    if IsValid( ent ) then need = math.min( ent:GetMaxHealth() - ent:Health(), need ) end

    if IsValid( ent ) and self:Clip1() >= need and ( ent:IsPlayer() or ent:IsNPC() ) and ent:Health() < ent:GetMaxHealth() then

        self:TakePrimaryAmmo( need )

        ent:SetHealth( math.min( ent:GetMaxHealth(), ent:Health() + need ) )
        ent:EmitSound( HealSound )

        self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

        self:SetNextPrimaryFire( CurTime() + self:SequenceDuration() + 0.5 )
        self:GetOwner():SetAnimation( PLAYER_ATTACK1 )

        if self:GetOwner().GivePlayerScore and ent:IsPlayer() then
            self:GetOwner():GivePlayerScore( 8 )

        end

        self:GetOwner():SetNW2Bool( "gleemedkit_healedother", true )

        -- Even though the viewmodel has looping IDLE anim at all times, we need this to make fire animation work in multiplayer
        timer.Create( "weapon_idle" .. self:EntIndex(), self:SequenceDuration(), 1, function() if ( IsValid( self ) ) then self:SendWeaponAnim( ACT_VM_IDLE ) end end )

    else

        self:GetOwner():EmitSound( DenySound )
        self:SetNextPrimaryFire( CurTime() + 0.1 )

    end

end

function SWEP:SecondaryAttack()

    if CLIENT then return end

    local ent = self:GetOwner()

    local need = self.OwnerHealAmount
    if IsValid( ent ) then need = math.min( ent:GetMaxHealth() - ent:Health(), self.OwnerHealAmount ) end

    if IsValid( ent ) and self:Clip1() >= need and ent:Health() < ent:GetMaxHealth() then

        self:GetOwner():SetNW2Bool( "gleemedkit_healedself", true )

        self:TakePrimaryAmmo( need )

        ent:SetHealth( math.min( ent:GetMaxHealth(), ent:Health() + need ) )
        ent:EmitSound( HealSound )

        self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

        self:SetNextSecondaryFire( CurTime() + self:SequenceDuration() + 0.5 )
        self:GetOwner():SetAnimation( PLAYER_ATTACK1 )

        timer.Create( "weapon_idle" .. self:EntIndex(), self:SequenceDuration(), 1, function() if ( IsValid( self ) ) then self:SendWeaponAnim( ACT_VM_IDLE ) end end )

    else

        ent:EmitSound( DenySound )
        self:SetNextSecondaryFire( CurTime() + 1 )

    end

end

function SWEP:OnRemove()

    timer.Stop( "medkit_ammo" .. self:EntIndex() )
    timer.Stop( "weapon_idle" .. self:EntIndex() )

end

function SWEP:Holster()

    timer.Stop( "weapon_idle" .. self:EntIndex() )

    return true

end

function SWEP:CustomAmmoDisplay()

    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Clip1()

    return self.AmmoDisplay

end

local juiceToGive = {
    item_healthkit = 25,
    item_healthvial = 10,

}

hook.Add( "PlayerCanPickupItem", "glee_medkit_absorbsitems", function( ply, item )
    local itemsClass = item:GetClass()
    local toGive = juiceToGive[ itemsClass ]
    if not toGive then return end

    local plysWep = ply:GetWeapon( "termhunt_medkit" )
    if not IsValid( plysWep ) then return end

    if ply:Health() < ply:GetMaxHealth() then return end

    if item.glee_AbsorbedByPly then return end
    item.glee_AbsorbedByPly = true

    timer.Simple( 0, function()
        plysWep:SetClip1( plysWep:Clip1() + toGive )
        local pit = 100 + ( 200 / toGive )
        ply:EmitSound( "items/medshot4.wav", 55, pit, 1, CHAN_BODY )
        SafeRemoveEntity( item )

    end )
end )