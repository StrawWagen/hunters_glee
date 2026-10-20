
AddCSLuaFile()

DEFINE_BASECLASS( "glee_backpackable_base" )

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Maxwell"
SWEP.Slot = 1
SWEP.SlotPos = 7
SWEP.DrawCrosshair = false
SWEP.BounceWeaponIcon = true

-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=2878054450 by bean

if CLIENT then
	terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_backpackable_maxwell", "materials/vgui/hud/killicon/glee_maxwell_weapon.png" )

end

SWEP.Purpose = "I still have nightmares about that cat..."
SWEP.Instructions = "What cat?"

SWEP.Spawnable = false -- glee_maxwell_dancing is, see there
SWEP.Category = "Hunter's Glee"

SWEP.CarryEntClass = "glee_maxwell_dancing"

SWEP.HeldModelPos, SWEP.HeldModelAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 2.168, 1, 4.393 ), Angle( 16.07, 90, -73.677 ) )
SWEP.HeldModelScale = 0.5

SWEP.WorldModelHandPos, SWEP.WorldModelHandAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( -0.644, 8.807, 0 ), Angle( 90, -4.545, -8.801 ) )
SWEP.WorldModelHandScale = 0.824

SWEP.WorldModelBackPos = Vector( 4, -2, 0 )
SWEP.WorldModelBackAng = Angle( 0, 90, 90 )
SWEP.WorldModelBackScale = 0.824

SWEP.PlaceGhostAng = Angle( 90, 115, 0 )
SWEP.PlaceAng = Angle( 0, 115, 0 )

SWEP.Primary.Automatic = true
SWEP.Secondary.Automatic = true

local healInHands = 10
local healOnBack = 5

-- Every 8 seconds, purring even when there's nothing to heal. One timer, held or on the back,
-- so swapping between them doesn't heal any faster
function SWEP:PurrHeal( amount )
	self.NextHeal = self.NextHeal or 0
	if self.NextHeal >= CurTime() then return end

	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	if owner:Health() < owner:GetMaxHealth() then
		local newHealth = math.min( owner:Health() + amount, owner:GetMaxHealth() )
		owner:SetHealth( newHealth )
		owner.glee_LastSetHealthReason = "glee_maxwell_regen"

	end

	owner:EmitSound( "hunters_glee/purr.ogg", 80 )
	self.NextHeal = CurTime() + 8

end

-- -5 panic a second, held or on the back. Gamemode only, there's no panic outside it
function SWEP:CalmPanic()
	self.NextPanicReduce = self.NextPanicReduce or 0
	if GAMEMODE.GivePanic and self.NextPanicReduce < CurTime() then
		GAMEMODE:GivePanic( self:GetOwner(), -5 )
		self.NextPanicReduce = CurTime() + 1

	end
end

function SWEP:OnBackThink()
	self:PurrHeal( healOnBack )
	self:CalmPanic()

end

function SWEP:Think()
	BaseClass.Think( self )

	if not SERVER then return end
	self:PurrHeal( healInHands )
	self:CalmPanic()

end

function SWEP:Deploy()
	local owner = self:GetOwner()
	if IsValid( owner ) then
		owner:DrawViewModel( true )

	end

	return BaseClass.Deploy( self )

end

SWEP.NextCry = 0

function SWEP:PrimaryAttack()
	if CurTime() < self.NextCry then return end
	if not SERVER then return end

	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	owner:EmitSound( "hunters_glee/meow/meow" .. math.random( 1, 3 ) .. ".ogg", 80 )
	self.NextCry = CurTime() + 1

end

function SWEP:SecondaryAttack()
	if CurTime() < self.NextCry then return end
	if not SERVER then return end

	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	owner:EmitSound( "hunters_glee/meow/meow" .. math.random( 1, 3 ) .. ".ogg", 80 )
	self.NextCry = CurTime() + 1

end

if SERVER then
	-- what he does while carried is his entity's, glee_maxwell_dancing
	function SWEP:OnCarryStart( ent )
		ent:PauseForCarry()

	end

	function SWEP:OnCarryEnd( ent, carrier, placed )
		ent:ResumeAfterCarry( carrier, placed )

	end

	function SWEP:OwnerChanged( oldOwner, _newOwner )
		if not IsValid( oldOwner ) then return end
		oldOwner:StopSound( "hunters_glee/purr.ogg" )

	end
end
