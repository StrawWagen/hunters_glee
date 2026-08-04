AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName   = "Crate Beacon"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Puts a supply crate on the HUD of everyone near it. Shoot it off."
ENT.Category    = "Hunter's Glee"
ENT.Spawnable   = true
ENT.AdminOnly   = game.IsDedicated()
ENT.Model       = "models/props_lab/reciever01b.mdl"


function ENT:SetupDataTables()
    self:NetworkVar( "Int", "ChargedUntil" )
    if SERVER then
        self:SetChargedUntil( CurTime() + 1 )

    end
end

-- cl_plynames module draws a name panel for anything with a Nick
function ENT:Nick()
    if self:GetChargedUntil() < CurTime() then return end
    return "!!!"

end

local beaconColor = Vector( 255, 190, 0 ) / 255
function ENT:GetPlayerColor()
    if self:GetChargedUntil() < CurTime() then return end
    return beaconColor

end


if not SERVER then return end

-- a couple of shots, it exists to be taken off the crate
ENT.BeaconHealth = 10

-- vel of battery when this breaks
local batteryPop = Vector( 0, 0, 110 )

function ENT:Initialize()
    self:SetModel( self.Model )
    self:PhysicsInit( SOLID_VPHYSICS )

    -- the panel hides anything on 0 health, and prints Health/GetMaxHealth when looked at
    self:SetMaxHealth( self.BeaconHealth )
    self:SetHealth( self.BeaconHealth )

    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) then return end

    phys:SetMass( 15 )

end

function ENT:DropBattery()
    local battery = ents.Create( "item_battery" )
    if not IsValid( battery ) then return end

    battery:SetPos( self:WorldSpaceCenter() )
    battery:SetAngles( AngleRand() )
    battery:Spawn()

    local phys = battery:GetPhysicsObject()
    if not IsValid( phys ) then return end

    phys:SetVelocity( VectorRand() * 30 + batteryPop )

end

function ENT:Break()
    self:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav", 75, 90 )

    local sparks = EffectData()
    sparks:SetOrigin( self:WorldSpaceCenter() )
    sparks:SetMagnitude( 2 )
    sparks:SetScale( 1 )
    sparks:SetRadius( 2 )
    util.Effect( "Sparks", sparks )

    self:DropBattery()

    SafeRemoveEntity( self )

end

function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )

    self:SetHealth( self:Health() - dmg:GetDamage() )
    if self:Health() > 0 then return end

    self:Break()

end
