AddCSLuaFile()

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Gas Can"
SWEP.Purpose = "There's still some gas in this."
SWEP.Instructions = "Primary on a vehicle to fuel it. Reload to place it down."
SWEP.Slot = 4

if CLIENT then
    language.Add( "glee_backpackable_gascan", SWEP.PrintName )

end

-- the same models sv_gasmanager treats as gas
local gasModels = {
    ["models/props_junk/gascan001a.mdl"] = true,
    ["models/props_junk/metalgascan.mdl"] = true,
}

SWEP.HoldType = "physgun" -- both hands together out front, like the turret's
SWEP.ViewModelOffset = Vector( 8, 0, 0 )

-- the turret's pose, upper arms swung in towards each other, palms facing in
SWEP.ViewModelBoneMods = terminator_Extras.glee_Carrying.ElitesBoneMods( -8, 0, 0 )

terminator_Extras.glee_Carrying.RegisterCarryable( "prop_physics", "glee_backpackable_gascan", function( ent )
    return gasModels[ent:GetModel()]

end )

-- starting points, needs tuning in game
SWEP.HeldModelPos, SWEP.HeldModelAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 10, 4, 4 ), Angle( 6, -90, 140 ) )
SWEP.HeldModelScale = 0.7

SWEP.WorldModelHandPos, SWEP.WorldModelHandAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 8, 5, 5 ), Angle( 180, 90, 0 ) )
SWEP.WorldModelHandScale = 0.824

SWEP.WorldModelBackPos = Vector( 4, -6, 0 )
SWEP.WorldModelBackAng = Angle( 0, 90, 75 )

SWEP.PlaceAng = Angle( 0, 90, 0 ) -- facing back at whoever placed it

local fuelReach = 100

-- Fuels the vehicle they're aiming at, if it's waiting for gas, using up the can and this weapon
function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 0.5 )
    if not SERVER then return end
    if not GAMEMODE.FuelVehicle then return end -- the gamemode's vehicles, nothing to fuel outside it

    local owner = self:GetOwner()
    local gas = self:GetCarriedEnt()
    if not IsValid( gas ) then return end

    local shootPos = owner:GetShootPos()
    local tr = util.TraceLine( {
        start = shootPos,
        endpos = shootPos + owner:GetAimVector() * fuelReach,
        filter = { owner, gas },
    } )

    -- a vehicle's wheels and seats are its children, the gas goes in the vehicle
    local veh = tr.Entity
    while IsValid( veh ) and not veh.glee_IsWaitingForGas do
        veh = veh:GetParent()

    end
    if not IsValid( veh ) then return end

    if not GAMEMODE:FuelVehicle( veh, gas ) then return end

    -- the can's used up, let go of first so the switch away isn't held up by the hands being full
    self:StopCarrying()

    local previous = owner:GetPreviousWeapon()
    if IsValid( previous ) and previous:IsWeapon() and previous ~= self then
        owner:SelectWeapon( previous:GetClass() )

    end

    SafeRemoveEntity( self )

end

if not SERVER then return end

-- Handed out without one, a can like the gas spawner's. The gamemode counts it as gas by its model
function SWEP:CreateCarryEnt( pos )
    local models = table.GetKeys( gasModels )

    local gas = ents.Create( "prop_physics" )
    if not IsValid( gas ) then return end

    gas:SetModel( models[math.random( #models )] )
    gas:SetPos( pos )
    gas:Spawn()

    return gas

end
