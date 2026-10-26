AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

local glee_Carrying = terminator_Extras.glee_Carrying

ENT.Anim = "maxwell_dance" -- can also be "maxwell_rotate"

function ENT:Initialize()
	self:SetModel( "models/glee/dingus/dingus.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	self:SetUseType( SIMPLE_USE )
	self:DrawShadow( true )
	self:ResetSequence( self.Anim )

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:Wake()

	end

	self.cat_music = CreateSound( self, "hunters_glee/maxwell_the_cat_theme.wav" )
	self.cat_music:Play()
	self:CallOnRemove( "StopMusic", function()
		if not self.cat_music then return end
		self.cat_music:Stop()
		self.cat_music = nil

	end )
end

local tumbleTime = 3 -- dropped, it tumbles about this long before it lands and dances
-- degrees per second. A spin coasts kick / friction degrees, so one pet alone is about one turn
local petSpinKick = 720
local petSpinFriction = 2 -- per second, exponential
local petSpinStopSpeed = 20
local petSpinFlySpeed = 1440 -- a pet about every third of a second gets there
local flyUpSpeed = 500

-- The wheel's pick, see glee_carrying. Only ever "pet", glee_Carrying answers its PickUpAction itself.
-- Dancing, each pet spins him faster, the way he's already going. Carried or tumbling he just purrs
function ENT:OnUseAction()
	self:EmitSound( "npc/footsteps/softshoe_generic6.wav", 60, math.random( 140, 160 ), 0.6 )
	self:EmitSound( "hunters_glee/purr.ogg", 70, math.random( 120, 140 ), 1, CHAN_ITEM )

	if glee_Carrying.IsCarried( self ) or self:GetMoveType() ~= MOVETYPE_NONE then return true end

	local speed = self.petSpinSpeed
	if speed then
		self.petSpinSpeed = speed + ( speed > 0 and petSpinKick or -petSpinKick )

	else
		self.petSpinSpeed = math.random( 1, 2 ) == 1 and petSpinKick or -petSpinKick
		self.petSpinLast = CurTime()

	end

	if math.abs( self.petSpinSpeed ) >= petSpinFlySpeed then
		local spin = self.petSpinSpeed
		self.petSpinSpeed = nil
		self:Tumble( Vector( 0, 0, flyUpSpeed ), Vector( 0, 0, spin ) )
		self:EmitSound( "hunters_glee/meow/meow" .. math.random( 1, 3 ) .. ".ogg", 75, math.random( 150, 160 ) )

	end

	return true

end

-- frozen on sequence 0's first frame, the viewmodel's copy of it never animates either
function ENT:PauseForCarry()
	timer.Remove( self:GetLandTimerName() )
	self.petSpinSpeed = nil

	if self.cat_music then
		self.cat_music:Stop()

	end

	self:ResetSequence( 0 )
	self:SetCycle( 0 )
	self:SetPlaybackRate( 0 )

end

function ENT:GetLandTimerName()
	return "glee_maxwell_land_" .. self:GetCreationID()

end

function ENT:ResumeAfterCarry( ply, placed )
	if placed then
		self:StartDancing()
		return

	end

	-- so whoever dropped it can throw it
	local velocity = IsValid( ply ) and ply:GetVelocity() or vector_origin
	self:Tumble( velocity )

end

-- Under physics for tumbleTime, then lands upright where it ended up.
-- angleVelocity, optional, is local, degrees per second
function ENT:Tumble( velocity, angleVelocity )
	self:SetMoveType( MOVETYPE_VPHYSICS )

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		-- a pet spin turns only him, not his frozen physics object
		phys:SetPos( self:GetPos() )
		phys:SetAngles( self:GetAngles() )

		phys:EnableMotion( true )
		phys:Wake()
		phys:SetVelocity( velocity )

		if angleVelocity then
			phys:AddAngleVelocity( angleVelocity )

		end
	end

	timer.Create( self:GetLandTimerName(), tumbleTime, 1, function()
		if not IsValid( self ) then return end
		self:Land()

	end )
end

-- After a tumble, upright on whatever's under him, facing anywhere
function ENT:Land()
	self:SetMoveType( MOVETYPE_NONE )

	local groundTr = util.TraceLine( {
		start = self:WorldSpaceCenter(),
		endpos = self:WorldSpaceCenter() - Vector( 0, 0, 4096 ),
		filter = self,
	} )

	self:SetPos( groundTr.HitPos )
	self:SetAngles( Angle( 0, math.random( -180, 180 ), 0 ) )

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetPos( self:GetPos() )
		phys:SetAngles( self:GetAngles() )

	end

	self:StartDancing()

end

-- frozen in place, physics object and all, or it'd drift off without him
function ENT:StartDancing()
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:EnableMotion( false )

	end

	self.Anim = math.random( 1, 2 ) == 1 and "maxwell_dance" or "maxwell_rotate"
	self:ResetSequence( self.Anim )
	self:SetPlaybackRate( 1 )

	if self.cat_music then
		self.cat_music:Play()

	end
end

-- about his own up, slowing till he stops wherever he ends up facing
function ENT:PetSpinThink()
	local speed = self.petSpinSpeed
	if not speed then return end

	local now = CurTime()
	local dt = now - self.petSpinLast
	self.petSpinLast = now

	local ang = self:GetAngles()
	ang:RotateAroundAxis( ang:Up(), speed * dt )
	self:SetAngles( ang )

	speed = speed * math.exp( -petSpinFriction * dt )
	if math.abs( speed ) < petSpinStopSpeed then
		speed = nil

	end
	self.petSpinSpeed = speed

end

function ENT:Think()
	self:PetSpinThink()
	self:NextThink( CurTime() )
	return true

end

hook.Add( "InitPostEntity", "maxwell_glee", function()
	if not GAMEMODE.IsReallyHuntersGlee then return end

	local maxCount = math.random( 1, 2 )
	if math.random( 0, 100 ) <= 1 then
		maxCount = math.random( 3, 6 )

	end

	GAMEMODE:RandomlySpawnEntTbl( "glee_maxwell_dancing", {
		countClasses = { "glee_maxwell_dancing" },
		maxCount = maxCount,
		chance = math.Rand( 1, 10 ),
		minAreaSize = 25,
		radius = math.random( 1000, 10000 ),

	} )
end )