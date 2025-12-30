AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

ENT.Anim = "maxwell_dance" -- can also be "maxwell_rotate"

function ENT:Initialize()
	self:SetModel( "models/glee/dingus/dingus.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_VPHYSICS )
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

function ENT:StartTouch( ent )
	if not IsValid( ent ) then return end
	if not ent:IsPlayer() then return end

	local wep = ent:Give( "glee_maxwell_weapon" )
	ent:SelectWeapon( "glee_maxwell_weapon" )
	undo.ReplaceEntity( wep, self )
	SafeRemoveEntity( self )

end

function ENT:Think()
	self:NextThink( CurTime() )
	return true

end