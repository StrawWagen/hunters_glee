AddCSLuaFile()

SWEP.Base = "weapon_terminatorfists_term"
DEFINE_BASECLASS( SWEP.Base )

SWEP.PrintName = "Infernal Skeleton Fists"
SWEP.Spawnable = false
SWEP.Author = "StrawWagen"
SWEP.Purpose = "Innate weapon that the infernal skeleton uses"

local className = "weapon_infernalskeleton_fists"
if CLIENT then
    language.Add( className, SWEP.PrintName )
    killicon.Add( className, "vgui/hud/killicon/" .. className .. ".png", color_white )

end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    local owner = self:GetOwner()

    local act = ACT_GMOD_GESTURE_RANGE_ZOMBIE
    local seq = owner:SelectWeightedSequence( act )

    local seqSpeed = owner.zamb_MeleeAttackSpeed or 1
    local additionalDelay = owner.zamb_MeleeAttackAdditionalDelay or 0
    local meleeTime = owner:SequenceDuration( seq ) / seqSpeed
    local nextMeleeTime = CurTime() + ( ( meleeTime - 0.1 ) * seqSpeed ) + additionalDelay
    self:SetNextPrimaryFire( nextMeleeTime )
    -- play anim next tick
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        if not IsValid( owner ) then return end
        if not owner.DoGesture then return end
        owner:DoGesture( act, seqSpeed, owner.NoAnimLayering or false )

    end )

    local hitframeMul = owner.zamb_MeleeAttackHitFrameMul or 1

    local dmgTime = ( ( meleeTime - 0.7 ) / seqSpeed ) * hitframeMul

    -- deal damage
    timer.Simple( dmgTime, function()
        if not IsValid( self ) then return end
        if not IsValid( owner ) then return end
        if not owner:IsSolid() then return end
        if owner.RunTask and owner:RunTask( "BlockClawSwipe" ) then return end
        self:DealDamage()

        self:SetClip1( self:Clip1() - 1 )
        self:SetLastShootTime()

    end )
end

local entMeta = FindMetaTable( "Entity" )

function SWEP:HoldTypeThink()
    local owner = entMeta.GetOwner( self )
    if not IsValid( owner ) then return end

    local myTbl = entMeta.GetTable( self )
    local holdType = "fist"

    myTbl.doFistsTime = doFistsTime
    local oldHoldType = myTbl.oldHoldType

    if not oldHoldType or oldHoldType ~= holdType then
        self:SetHoldType( holdType )
        myTbl.oldHoldType = holdType

    end
end

-- so our holdtype doesnt override the npc's anim translations
function SWEP:TranslateActivity()
end
