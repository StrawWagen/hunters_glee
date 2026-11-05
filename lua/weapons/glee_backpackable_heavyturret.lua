AddCSLuaFile()

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Heavy Sentry Turret"
SWEP.Purpose = "Mobile Death."
SWEP.Instructions = "Hold RELOAD to place."
SWEP.Slot = 4

SWEP.Spawnable = true
SWEP.Category = "Hunter's Glee"

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_backpackable_heavyturret", "materials/vgui/hud/killicon/glee_heavyturret.png" )

end

SWEP.CarryEntClass = "glee_heavyturret"

-- Maxwell's and the big bomb's pose, the base's
SWEP.HoldType = "duel"
SWEP.ViewModelOffset = Vector( -1, 0, -4 )

-- arms out, palms rolled up
SWEP.ViewModelBoneMods = terminator_Extras.glee_Carrying.ElitesBoneMods( 0, -80.047, 71.204 )

SWEP.SpeedModifier = -150 -- it's heavy

-- starting points, needs tuning in game
SWEP.HeldModelPos, SWEP.HeldModelAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 4, 2, 4 ), Angle( 0, -5, -75 ) )
SWEP.HeldModelScale = 0.6

SWEP.WorldModelHandPos, SWEP.WorldModelHandAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 5, 10, 5 ), Angle( 0, 0, 0 ) )

SWEP.WorldModelBackPos = Vector( 5, -3, 0 )
SWEP.WorldModelBackAng = Angle( 0, 0, -90 )

SWEP.PlaceDistance = 115
SWEP.PlaceAng = Angle( 0, 0, 180 ) -- its model's upside down
SWEP.PlacedSound = {
    pitch = 70,
    sounds = {
        { path = "physics/metal/metal_computer_impact_bullet1.wav" },
        { path = "physics/metal/metal_computer_impact_bullet2.wav" },
        { path = "physics/metal/metal_computer_impact_bullet3.wav" },
    },
}

-- see ENT:GetBulletAttacker
function SWEP:OnCarryEnd( ent, carrier, placed )
    if not placed or not IsValid( carrier ) then return end
    ent.glee_LastPlacer = carrier

end
