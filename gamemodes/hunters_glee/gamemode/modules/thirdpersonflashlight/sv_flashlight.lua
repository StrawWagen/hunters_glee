-- ------------------------------------------------------------------- --
-- -------------------- Third Person Flashlight ---------------------- --
-- ------------------------------------------------------------------- --
-- -------------------- By Wheatley ---------------------------------- --
-- ------------------------------------------------------------------- --
-- modified very very heavily by straw and the slop machine

local IsValid = IsValid

local defaultColor = Color( 255, 255, 255 )
local nearz = 10
local minFarz = nearz + 5
local fullBrightFarz = 255 * 2 + 125 -- a plain flashlight's range at full brightness, glows at strength 1

-- what ply's flashlight puts out at their current brightness
local function getLightStats( ply )
	local alpha = ply.glee_FlashlightBrightness or 255

	local farz = alpha * 2
	-- min 125 farz
	farz = farz + 125

	local fov = alpha / 3
	fov = math.Clamp( fov, 60, 90 )

	local farzReturned, fovReturned = hook.Run( "glee_flashlightstats", ply, alpha, farz, fov )
	if fovReturned then
		fov = fovReturned

	end
	if farzReturned then
		farz = farzReturned

	end

	return {
		color = ply.glee_FlashlightColorDefault or defaultColor,
		alpha = alpha,
		farz = farz,
		fov = fov,
	}
end

-- strength scales stats' brightness and range, so a dropped flashlight can fade out
-- returns how big the flashlight's glow should be
function GM:ApplyFlashlightStats( theLight, stats, strength )
	local color = stats.color
	local alpha = stats.alpha * strength
	local farz = math.max( stats.farz * strength, minFarz )
	local fov = stats.fov

	local formatted = Format( "%i %i %i %i", color.r, color.g, color.b, alpha )
	local appliedKey = formatted .. " " .. farz .. " " .. fov
	if theLight.glee_AppliedStatsKey ~= appliedKey then
		theLight.glee_AppliedStatsKey = appliedKey
		theLight:SetKeyValue( "lightfov", fov )
		theLight:SetKeyValue( "farz", farz )
		theLight:SetKeyValue( "lightcolor", formatted )

	end

	return farz / fullBrightFarz

end

local function checkLight( ply, theLight )
	local stats = getLightStats( ply )
	theLight.glee_LightStats = stats -- the dropped flashlight fades from these, its owner's hooks may not apply anymore

	local glowStrength = GAMEMODE:ApplyFlashlightStats( theLight, stats, 1 )
	ply:SetNW2Float( "glee_flashlightglow", glowStrength )

	-- cl_flashlight lights our own first person view with a clientside copy of this light, see there
	local color = stats.color
	ply:SetNW2Vector( "glee_flashlightcolor", Vector( color.r, color.g, color.b ) )
	ply:SetNW2Float( "glee_flashlightbrightness", stats.alpha / 255 )
	ply:SetNW2Float( "glee_flashlightfarz", math.max( stats.farz, minFarz ) )
	ply:SetNW2Float( "glee_flashlightfov", stats.fov )

end

-- the only reference to a player's light, kept on the player so it survives autorefresh
local function getPlayersLight( ply )
	local theLight = ply.glee_Thirdperson_Flashlight
	if not IsValid( theLight ) then return end

	return theLight

end

local function TPF_SetupProjectedTexture( ply )
	local theLight = ents.Create( "env_projectedtexture" )
	if not IsValid( theLight ) then return end

	local attachmentId = ply:LookupAttachment( "eyes" )
	local theFlashlightPos = ply:GetShootPos()
	local theFlashlightAngles = ply:EyeAngles()
	if attachmentId > 0 then
		local attachDat = ply:GetAttachment( attachmentId )
		if attachDat then
			theFlashlightPos = attachDat.Pos
			theFlashlightAngles = attachDat.Ang

		end
	end

	theFlashlightPos = theFlashlightPos + theFlashlightAngles:Forward() * 15

	theLight:SetPos( theFlashlightPos )
	theLight:SetAngles( theFlashlightAngles )

	theLight:SetKeyValue( "enableshadows", 1 )
	theLight:SetKeyValue( "shadowquality", 0 )
	theLight:SetKeyValue( "nearz", nearz )
	checkLight( ply, theLight )
	theLight:Spawn()
	theLight:Input( "SpotlightTexture", NULL, NULL, "effects/flashlight001" )
	-- owned, not parented. cl_flashlight places it every frame, a parent's angles shift mid frame and jitter it
	theLight:SetOwner( ply )

	ply.glee_Thirdperson_Flashlight = theLight

	timer.Simple( 0, function()
		if not IsValid( ply ) then return end
		if not ply:Alive() then return end

		ply:EmitSound( "HL2Player.FlashLightOn" )

	end )
end

local function TPF_RemoveProjectedTexture( ply )
	local theLight = getPlayersLight( ply )
	if not theLight then return end

	SafeRemoveEntity( theLight )
	ply.glee_Thirdperson_Flashlight = nil

	timer.Simple( 0, function()
		if not IsValid( ply ) then return end
		if not ply:Alive() then return end

		ply:EmitSound( "HL2Player.FlashLightOff" )

	end )
end

local lampHands = { "anim_attachment_RH", "anim_attachment_LH" }

local function lampDropPos( ply )
	for _, name in ipairs( lampHands ) do
		local attachmentId = ply:LookupAttachment( name )
		if attachmentId > 0 then
			local attachDat = ply:GetAttachment( attachmentId )
			if attachDat then return attachDat.Pos end

		end
	end

	return ply:GetShootPos()

end

-- hands ply's light over to a glee_dropped_flashlight, which burns it out
-- one per player, dropping another replaces the last
local function TPF_DropFlashlight( ply )
	local theLight = getPlayersLight( ply )
	if not theLight then return end

	ply.glee_Thirdperson_Flashlight = nil
	SafeRemoveEntity( ply.glee_DroppedFlashlight )

	local dropped = ents.Create( "glee_dropped_flashlight" )
	if not IsValid( dropped ) then
		SafeRemoveEntity( theLight )
		return

	end
	ply.glee_DroppedFlashlight = dropped

	dropped:SetPos( lampDropPos( ply ) )
	dropped:SetAngles( ply:EyeAngles() )
	dropped:Spawn()
	dropped:Activate() -- scales its physics to the lamp's model scale
	dropped:TakeLight( theLight )

	local physObj = dropped:GetPhysicsObject()
	if IsValid( physObj ) then
		physObj:SetVelocity( ply:GetVelocity() )

	end
end

hook.Add( "PlayerDisconnected", "TPF_HookPlayerDisconnects", TPF_RemoveProjectedTexture )

hook.Add( "PostPlayerDeath", "glee_flashlight_drop", TPF_DropFlashlight )

hook.Add( "glee_PreStripWeapons", "glee_flashlight_drop", TPF_DropFlashlight )

hook.Add( "PlayerEnteredVehicle", "glee_flashlight_turnoff", TPF_RemoveProjectedTexture )

hook.Add( "PreCleanupMap", "glee_flashlight_turnoff", function()
	for _, currPly in ipairs( player.GetAll() ) do
		TPF_RemoveProjectedTexture( currPly )

	end
end )

hook.Add( "PlayerSwitchFlashlight", "TPF_HookFlashlightEnabled", function( ply, _ )
	if not ply:Alive() then return end

	if not getPlayersLight( ply ) then
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

local meta = FindMetaTable( "Player" )

function meta:Glee_FlashlightIsOn()
	return getPlayersLight( self ) ~= nil

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

	local theLight = getPlayersLight( self )
	if not theLight then return end

	checkLight( self, theLight )

end
