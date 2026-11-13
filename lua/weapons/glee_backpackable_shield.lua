AddCSLuaFile()

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Glee Shield"
SWEP.Author = "dedactedlife & IndefiniteXD"
SWEP.Purpose = "Can save your life, most of the time."
SWEP.Slot = 4

SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = true

SWEP.UseHands = false

local glee_Carrying = terminator_Extras.glee_Carrying

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_backpackable_shield", "materials/entities/glee_backpackable_shield.png" )

end

terminator_Extras.glee_Carrying.RegisterCarryable( "glee_shield", "glee_backpackable_shield", nil, { GleeUseWheelOnly = true } )

SWEP.CarryEntClass = "glee_shield"

SWEP.HeldModelPos, SWEP.HeldModelAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 5, 4.75, 49.5 ), Angle( 0, 0, -180 ) )
--SWEP.HeldModelScale = 10.0

SWEP.ViewModelBoneMods = glee_Carrying.ElitesBoneMods( 0, 0, 0 )

SWEP.WorldModelHandPos, SWEP.WorldModelHandAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 6, 10, 38 ), Angle( 180, 180, 0 ) )
SWEP.WorldModelBackPos = Vector( -26, -7, 2 )
SWEP.WorldModelBackScale = 0.8
SWEP.WorldModelBackAng = Angle( 180, 90, 90 )

SWEP.SpeedModifier = -50
SWEP.PlaceAng = Angle( 0, 0, 0 )
SWEP.PlacedSound = {
    pitch = 80,
    sounds = {
        { path = "physics/metal/metal_computer_impact_hard1.wav" },
        { path = "physics/metal/metal_computer_impact_hard2.wav" },
        { path = "physics/metal/metal_computer_impact_hard3.wav" },
    },
}