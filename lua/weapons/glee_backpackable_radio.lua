AddCSLuaFile()

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Radio"
SWEP.Purpose = "Play some good music, wherever you go."
SWEP.Instructions = "Primary to tune. Reload to place it down."
SWEP.Slot = 4

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_backpackable_radio", "materials/entities/swepts_radio_old.png" )

end

SWEP.CarryEntClass = "swepts_radio_old"

SWEP.HeldModelPos, SWEP.HeldModelAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 2.168, 2, 4.393 ), Angle( 30, 170, -120 ) )
SWEP.HeldModelScale = 0.5

SWEP.WorldModelHandPos, SWEP.WorldModelHandAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 4, 8.807, -2 ), Angle( 170, -4.545, -8.801 ) )
SWEP.WorldModelBackPos = Vector( 4, -1.5, 0 )
SWEP.WorldModelBackAng = Angle( 90, 0, 90 )

SWEP.PlaceAng = Angle( 0, 180, 0 ) -- facing back at whoever placed it
SWEP.PlacedSound = {
    pitch = 80,
    sounds = {
        { path = "physics/metal/metal_computer_impact_hard1.wav" },
        { path = "physics/metal/metal_computer_impact_hard2.wav" },
        { path = "physics/metal/metal_computer_impact_hard3.wav" },
    },
}

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 0.5 )
    if not SERVER then return end

    local radio = self:GetCarriedEnt()
    if not IsValid( radio ) then return end

    radio:OpenTunerFor( self:GetOwner() )

end
