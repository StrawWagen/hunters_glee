-- ------------------------------------------------------------------- --
-- -------------------- Third Person Flashlight ---------------------- --
-- ------------------------------------------------------------------- --
-- -------------------- By Wheatley ---------------------------------- --
-- ------------------------------------------------------------------- --
-- modified very very heavily by straw

local IsValid = IsValid
local thrPFlash = thrPFlash or {}

local function checkLight( ply, theLight )
	local newColor = ply.glee_FlashlightColorDefault or Color( 255, 255, 255 )
	local alpha = ply.glee_FlashlightBrightness or 255
	newColor.a = alpha

	local formatted = Format( "%i %i %i %i", newColor.r, newColor.g, newColor.b, alpha )

	local oldFormatted = theLight.flashlight_OldColor
	if oldFormatted and oldFormatted == formatted then return end

	ply.glee_FlashlightColorDefault = newColor

	local farz = alpha * 2
	-- min 125 farz
	farz = farz + 125

	local fov = alpha / 3.4
	fov = math.Clamp( fov, 60, 80 )

	local farzReturned, fovReturned = hook.Run( "glee_flashlightstats", ply, alpha, farz, fov )
	if fovReturned then
		fov = fovReturned

	end
	if farzReturned then
		farz = farzReturned

	end

	theLight:SetKeyValue( "lightfov", fov )
	theLight:SetKeyValue( "farz", farz )

	theLight:SetKeyValue( "lightcolor", formatted )
	theLight.flashlight_OldColor = formatted

end

local function TPF_SetupProjectedTexture( ply )
	if SERVER then
		local theLight = ents.Create( "env_projectedtexture" )
		if not IsValid( theLight ) then return end
		thrPFlash[ ply ] = theLight

		local attachmentId = ply:LookupAttachment( "eyes" )
		local theFlashlightPos = ply:GetShootPos()
		local theFlashlightAngles = ply:EyeAngles()
		if attachmentId then
			local attachDat = ply:GetAttachment( attachmentId )
			theFlashlightPos = attachDat.Pos
			theFlashlightAngles = attachDat.Ang

		end
		theLight:SetPos( theFlashlightPos )
		theLight:SetAngles( theFlashlightAngles )

		theLight:SetKeyValue( "enableshadows", 0 )
		theLight:SetKeyValue( "nearz", 10 )
		checkLight( ply, theLight )
		theLight:Spawn()
		theLight:Input( "SpotlightTexture", NULL, NULL, "effects/flashlight001" )
		if attachmentId then
			theLight:SetParent( ply, attachmentId )

		else
			theLight:SetParent( ply )

		end
		theLight:SetTransmitWithParent( true )

		ply.glee_Thirdperson_Flashlight = theLight

		timer.Simple( 0, function()
			if not IsValid( ply ) then return end
			if not ply:Alive() then return end

			ply:EmitSound( "HL2Player.FlashLightOn" )

		end )
	end
end

local function TPF_RemoveProjectedTexture( ply )
	local theirFlash = thrPFlash[ ply ] or ply.glee_Thirdperson_Flashlight
	if IsValid( theirFlash ) then
		SafeRemoveEntity( theirFlash )
		thrPFlash[ ply ] = nil
		if not IsValid( ply ) then return end

		ply.glee_Thirdperson_Flashlight = nil

		timer.Simple( 0, function()
			if not IsValid( ply ) then return end
			if not ply:Alive() then return end

			ply:EmitSound( "HL2Player.FlashLightOff" )

		end )
	end
end

hook.Add( "PlayerDisconnected", "TPF_HookPlayerDisconnects", TPF_RemoveProjectedTexture )

hook.Add( "PlayerDeath", "glee_flashight_turnoff", TPF_RemoveProjectedTexture )

hook.Add( "PlayerEnteredVehicle", "glee_flashight_turnoff", TPF_RemoveProjectedTexture )

hook.Add( "PreCleanupMap", "glee_flashight_turnoff", function()
	for _, currPly in ipairs( player.GetAll() ) do
		TPF_RemoveProjectedTexture( currPly )

	end
end )

hook.Add( "PlayerSwitchFlashlight", "TPF_HookFlashlightEnabled", function( ply, _ )
	if not ply:Alive() then return end

	if not IsValid( thrPFlash[ ply ] ) then
		local hookRes = hook.Run( "glee_PlayerSwitchFlashlight", ply, true )
		if hookRes == false then return false end

		TPF_SetupProjectedTexture( ply )
		return false

	else
		local hookRes = hook.Run( "glee_PlayerSwitchFlashlight", ply, false )
		if hookRes == false then return false end

		TPF_RemoveProjectedTexture( ply )
		return false

	end
end )

local function checkFlashlight( ply )
	local currFlash = thrPFlash[ ply ]
	if not IsValid( currFlash ) then return end

end

hook.Add( "glee_sv_validgmthink", "glee_manageflashlights", function( players )
	for _, currPly in ipairs( players ) do
		checkFlashlight( currPly )

	end
end )

local meta = FindMetaTable( "Player" )

function meta:Glee_FlashlightIsOn()
	return IsValid( thrPFlash[ self ] )

end

function meta:Glee_Flashlight( newState )
	local oldState = self:Glee_FlashlightIsOn()
	if oldState == newState then return end

	if oldState == false and newState == true then
		TPF_SetupProjectedTexture( self )

	elseif oldState == true and newState == false then
		TPF_RemoveProjectedTexture( self )

	end
end

function meta:SetFlashlightBrightness( brightness )
	self.glee_FlashlightBrightness = brightness
	if not self:Glee_FlashlightIsOn() then return end
	checkLight( self, thrPFlash[self] )

end