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

	self:SetTrigger( true )
	self:UseTriggerBounds( true, 24 )

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

local pickupCooldown = 3 -- after it's let go, or whoever let go would pick it straight back up
local tumbleTime = 3 -- dropped, it tumbles about this long before it lands and dances

-- Walked into, he's picked up, once the cooldown since he was let go is up
function ENT:Touch( ent )
	if not ent:IsPlayer() then return end
	if ( self.nextPickup or 0 ) > CurTime() then return end

	glee_Carrying.Carry( ent, self )

end

-- frozen on sequence 0's first frame, the viewmodel's copy of it never animates either
function ENT:PauseForCarry()
	timer.Remove( self:GetLandTimerName() )

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
	self.nextPickup = CurTime() + pickupCooldown

	if placed then
		self:StartDancing()
		return

	end

	-- tumbles under physics, so whoever dropped it can throw it, then lands upright where it ended up
	self:SetMoveType( MOVETYPE_VPHYSICS )

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:EnableMotion( true )
		phys:Wake()

		if IsValid( ply ) then
			phys:SetVelocity( ply:GetVelocity() )

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

function ENT:Think()
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