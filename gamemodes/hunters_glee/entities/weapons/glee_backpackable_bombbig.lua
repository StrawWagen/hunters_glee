AddCSLuaFile()

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Big Gland Bomb"
SWEP.Purpose = "Squishy. Volatile."
SWEP.Instructions = "Reload to place it down."
SWEP.Slot = 4

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_backpackable_bombbig", "vgui/hud/killicon/termhunt_bombbig.png" )

end

SWEP.CarryEntClass = "termhunt_bombbig"

-- Maxwell's and the radio's pose, the base's
SWEP.HoldType = "duel"
SWEP.ViewModelOffset = Vector( 0, 0, 0 )

-- arms out, palms rolled up
SWEP.ViewModelBoneMods = terminator_Extras.glee_Carrying.ElitesBoneMods( 0, -80.047, 71.204 )

-- too heavy for use to lift, use is held on it to pick it up instead
terminator_Extras.glee_Carrying.RegisterCarryable( "termhunt_bombbig", "glee_backpackable_bombbig", nil, { GleeTooHeavyToLift = true } )

SWEP.SpeedModifier = -100 -- twice the others', it's heavy

-- starting points, needs tuning in game
SWEP.HeldModelPos, SWEP.HeldModelAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 2, 5, 0 ), Angle( 0, 25, 0 ) )
SWEP.HeldModelScale = 0.6

SWEP.WorldModelHandPos, SWEP.WorldModelHandAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( -2, 8, -8 ), Angle( 20, 10, 80 ) )
SWEP.WorldModelHandScale = 0.824

SWEP.WorldModelBackPos = Vector( 4, -8, 0 )
SWEP.WorldModelBackAng = Angle( -40, 0, 0 )

SWEP.PlaceAng = Angle( -45, 90, 0 ) -- facing back at whoever placed it

-- squeeze
function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 0.1 )
    if not SERVER then return end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    owner:EmitSound( "weapons/bugbait/bugbait_squeeze" .. math.random( 1, 3 ) .. ".wav", 75, math.random( 30, 50 ) )
    owner:ViewPunch( Angle( -math.Rand( 4, 8 ), math.Rand( -1, 1 ), 0 ) )

end

SWEP.PlacedSound = {
    pitch = 90,
    sounds = {
        { path = "physics/flesh/flesh_squishy_impact_hard1.wav" },
        { path = "physics/flesh/flesh_squishy_impact_hard2.wav" },
        { path = "physics/flesh/flesh_squishy_impact_hard3.wav" },
    },
}
