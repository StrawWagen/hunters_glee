if SERVER then
	AddCSLuaFile()
else
	SWEP.PrintName = "Maxwell"
	SWEP.Slot = 2
	SWEP.SlotPos = 7
	SWEP.DrawCrosshair = false
	SWEP.BounceWeaponIcon = true
end

-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=2878054450 by bean

if CLIENT then
	terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_maxwell_weapon", "materials/vgui/hud/killicon/glee_maxwell_weapon.png" )

end

SWEP.Purpose = "I still have nightmares about that cat..."
SWEP.Instructions = "What cat?"

SWEP.Base = "weapon_base"

SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "Hunter's Glee"
SWEP.HoldType = "duel"
SWEP.ViewModelFOV = 70
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_pist_elite.mdl"
SWEP.WorldModel = "models/weapons/w_c4.mdl"
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = false
SWEP.ViewModelBoneMods = {
	["ValveBiped.Bip01_R_UpperArm"] = { scale = Vector(1, 1, 1), pos = Vector(-3.385, -1.29, 0.507), angle = Angle(0, 0, 0) },
	["v_weapon.elite_right"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["ValveBiped.Bip01_L_UpperArm"] = { scale = Vector(1, 1, 1), pos = Vector(-1.254, -0.774, 0), angle = Angle(0, 0, 0) },
	["ValveBiped.Bip01_L_Hand"] = { scale = Vector(1, 1, 1), pos = Vector(0, 0, 0), angle = Angle(0, 0, -80.047) },
	["v_weapon.elite_left"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, -30), angle = Angle(0, 0, 0) },
	["ValveBiped.Bip01_R_Hand"] = { scale = Vector(1, 1, 1), pos = Vector(0, 0, 0), angle = Angle(0, 0, 71.204) }

}
SWEP.VElements = {
	["catty"] = { type = "Model", model = "models/glee/dingus/dingus.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(2.168, 1, 4.393), angle = Angle(16.07, 90, -73.677), size = Vector(0.5, 0.5, 0.5), color = Color(255, 255, 255, 255), material = "", skin = 0, bodygroup = {} }

}
SWEP.WElements = {
	["catty"] = { type = "Model", model = "models/glee/dingus/dingus.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(-0.644, 8.807, 0), angle = Angle(90, -4.545, -8.801), size = Vector(0.824, 0.824, 0.824), color = Color(255, 255, 255, 255), material = "", skin = 0, bodygroup = {} }
}
SWEP.Slot = 4
SWEP.SlotPos = 8
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

function SWEP:Think()
	if not SERVER then return end
	self.NextHeal = self.NextHeal or 0
	if self.NextHeal < CurTime() then

		local owner = self:GetOwner()
		if not IsValid( owner ) then return end

		if owner:Health() < owner:GetMaxHealth() then
			local newHealth = math.min( owner:Health() + 10, owner:GetMaxHealth() )
			owner:SetHealth( newHealth )

		end

		owner:EmitSound( "hunters_glee/purr.ogg", 80 )
		self.NextHeal = CurTime() + 8

	end
	self.NextPanicReduce = self.NextPanicReduce or 0
	if GAMEMODE.GivePanic and self.NextPanicReduce < CurTime() then
		GAMEMODE:GivePanic( self:GetOwner(), -5 )
		self.NextPanicReduce = CurTime() + 1

	end
end

function SWEP:Holster()
	return true

end

function SWEP:OnRemove()
	if not self.TransformTimerName then return end
	timer.Remove( self.TransformTimerName )

end

function SWEP:OnDrop()
	if not SERVER then return end

	self:TransformIfNotOwned()

end

function SWEP:Equip()
	if not self.TransformTimerName then return end

	timer.Remove( self.TransformTimerName )
	self.TransformTimerName = nil
	self.HasTransformed = false

end

function SWEP:DrawWorldModel()
end

function SWEP:Deploy()
	local owner = self:GetOwner()
	if not IsValid( owner ) then return end
	owner:DrawViewModel( true )

end

function SWEP:Reload()
end

function SWEP:PrimaryAttack()
	if CurTime() < self.NextCry then return end
	if not SERVER then return end

	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	owner:EmitSound( "hunters_glee/meow/meow" .. math.random( 1, 3 ) .. ".ogg", 80 )
	self.NextCry = CurTime() + 1

end

SWEP.NextCry = 0

function SWEP:SecondaryAttack()
	if CurTime() < self.NextCry then return end
	if not SERVER then return end

	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	owner:EmitSound( "hunters_glee/meow/meow" .. math.random( 1, 3 ) .. ".ogg", 80 )
	self.NextCry = CurTime() + 1

end

--[[
	SWEP Construction Kit base code
	Created by Clavus
	Available for public use, thread at:
	facepunch.com/threads/1032378

	DESCRIPTION:
	This script is meant for experienced scripters
	that KNOW WHAT THEY ARE DOING. Don't come to me
	with basic Lua questions.

	Just copy into your SWEP or SWEP base of choice
	and merge with your own code.

	The SWEP.VElements, SWEP.WElements and
	SWEP.ViewModelBoneMods tables are all optional
	and only have to be visible to the client.
--]]

function SWEP:Initialize()
	self:SetHoldType( "duel" )

	if SERVER then
		self:TransformIfNotOwned()

	end

	if not CLIENT then return end

	-- Create a new table for every weapon instance
	self.VElements = table.FullCopy( self.VElements )
	self.WElements = table.FullCopy( self.WElements )
	self.ViewModelBoneMods = table.FullCopy( self.ViewModelBoneMods )

	self:CreateModels( self.VElements )
	self:CreateModels( self.WElements )

	-- Init view model bone build function
	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	local vm = owner:GetViewModel()
	if not IsValid( vm ) then return end

	self:ResetBonePositions( vm )

	-- Init viewmodel visibility
	if self.ShowViewModel == nil or self.ShowViewModel then
		vm:SetColor( Color( 255, 255, 255, 255 ) )

	else
		-- We set the alpha to 1 instead of 0 because else ViewModelDrawn stops being called
		vm:SetColor( Color( 255, 255, 255, 1 ) )
		-- Stopped working in GMod 13, apply debug material to prevent drawing
		vm:SetMaterial( "Debug/hsv" )

	end
end

function SWEP:Holster()
	if not CLIENT then return true end

	local owner = self:GetOwner()
	if not IsValid( owner ) then return true end

	local vm = owner:GetViewModel()
	if not IsValid( vm ) then return true end

	self:ResetBonePositions( vm )
	return true

end

function SWEP:OnRemove()
	self:Holster()

end

if SERVER then
	function SWEP:TransformIfNotOwned()
		self.TransformTimerName = "glee_maxwell_transform_" .. self:EntIndex() .. "_" .. CurTime()
		self.HasTransformed = false

		local wep = self
		timer.Create( self.TransformTimerName, 3, 1, function()
			if not IsValid( wep ) then return end
			if wep.HasTransformed then return end
			if IsValid( wep:GetOwner() ) then return end

			wep.HasTransformed = true

			local maxwell = ents.Create( "glee_maxwell_dancing" )
			if not IsValid( maxwell ) then return end

			maxwell:SetPos( wep:GetPos() )
			maxwell:SetAngles( Angle( 0, math.random( -180, 180 ), 0 ) )
			maxwell.Anim = math.random( 1, 2 ) == 1 and "maxwell_dance" or "maxwell_rotate"
			maxwell:Spawn()
			SafeRemoveEntity( wep )

			undo.ReplaceEntity( wep, maxwell )

		end )
	end

	function SWEP:OwnerChanged( oldOwner, _newOwner )
		if not IsValid( oldOwner ) then return end
		oldOwner:StopSound( "hunters_glee/purr.ogg" )

	end

	hook.Add( "InitPostEntity", "CrapVidCam_glee", function()
		if not GAMEMODE.IsReallyHuntersGlee then return end

		-- keep 5 sent_balls spawned in the map
		local spawnCount = 5

		-- only enabled in x % of rounds
		local enabledChance = math.Rand( 1, 15 )

		-- won't spawn in areas thinner/smaller than this
		local minAreaSize = 25

		-- optional, radius from players to spawn within
		local radius = math.random( 1000, 10000 ) -- defaults to 5000 when nil

		GAMEMODE:RandomlySpawnEnt( "glee_maxwell_weapon", spawnCount, enabledChance, minAreaSize, radius )

	end )
end

if CLIENT then

	-- NEVER leave clients with fucked up bones please
	function SWEP:EnsureBonesAreReset( vm )
		vm.BonePositionBreaker = self
		local originalOwner = self:GetOwner()
		local timerName = "glee_ResetBonePositions" .. self:GetCreationID()
		timer.Create( timerName, 0.1, 1, function()
			if not IsValid( self ) then timer.Remove( timerName ) return end
			if not IsValid( vm ) then timer.Remove( timerName ) return end
			local ourOwner = self:GetOwner()
			local breaker = vm.BonePositionBreaker -- us, probably

			if ourOwner == originalOwner and breaker == self then -- still owned by us
				return

			elseif ourOwner ~= originalOwner and breaker == self then -- bones are still broken
				self:ResetBonePositions( vm )
				vm.BonePositionBreaker = nil
				timer.Remove( timerName )

			end
		end )
	end

	SWEP.vRenderOrder = nil

	function SWEP:ViewModelDrawn()
		local owner = self:GetOwner()
		if not IsValid( owner ) then return end

		local vm = owner:GetViewModel()
		if not IsValid( vm ) then return end
		if not self.VElements then return end

		self:UpdateBonePositions( vm )

		if not self.vRenderOrder then
			-- We build a render order because sprites need to be drawn after models
			self.vRenderOrder = {}

			for k, v in pairs( self.VElements ) do
				if v.type == "Model" then
					table.insert( self.vRenderOrder, 1, k )
				elseif v.type == "Sprite" or v.type == "Quad" then
					table.insert( self.vRenderOrder, k )
				end
			end
		end

		for _, name in ipairs( self.vRenderOrder ) do
			local v = self.VElements[name]
			if not v then self.vRenderOrder = nil break end
			if v.hide then continue end

			local model = v.modelEnt
			local sprite = v.spriteMaterial

			if not v.bone then continue end

			local pos, ang = self:GetBoneOrientation( self.VElements, v, vm )
			if not pos then continue end

			if v.type == "Model" and IsValid( model ) then
				model:SetPos( pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
				ang:RotateAroundAxis( ang:Up(), v.angle.y )
				ang:RotateAroundAxis( ang:Right(), v.angle.p )
				ang:RotateAroundAxis( ang:Forward(), v.angle.r )

				model:SetAngles( ang )
				local matrix = Matrix()
				matrix:Scale( v.size )
				model:EnableMatrix( "RenderMultiply", matrix )

				if v.material == "" then
					model:SetMaterial( "" )
				elseif model:GetMaterial() ~= v.material then
					model:SetMaterial( v.material )
				end

				if v.skin and v.skin ~= model:GetSkin() then
					model:SetSkin( v.skin )
				end

				if v.bodygroup then
					for bg_k, bg_v in pairs( v.bodygroup ) do
						if model:GetBodygroup( bg_k ) == bg_v then continue end
						model:SetBodygroup( bg_k, bg_v )

					end
				end

				render.SetColorModulation( v.color.r / 255, v.color.g / 255, v.color.b / 255 )
				render.SetBlend( v.color.a / 255 )
				model:DrawModel()
				render.SetBlend( 1 )
				render.SetColorModulation( 1, 1, 1 )

			elseif v.type == "Sprite" and sprite then
				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				render.SetMaterial( sprite )
				render.DrawSprite( drawpos, v.size.x, v.size.y, v.color )

			elseif v.type == "Quad" and v.draw_func then
				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				ang:RotateAroundAxis( ang:Up(), v.angle.y )
				ang:RotateAroundAxis( ang:Right(), v.angle.p )
				ang:RotateAroundAxis( ang:Forward(), v.angle.r )

				cam.Start3D2D( drawpos, ang, v.size )
					v.draw_func( self )
				cam.End3D2D()
			end
		end
	end

	SWEP.wRenderOrder = nil

	function SWEP:DrawWorldModel()
		if self.ShowWorldModel == nil or self.ShowWorldModel then
			self:DrawModel()

		end

		if not self.WElements then return end

		if not self.wRenderOrder then
			self.wRenderOrder = {}

			for k, v in pairs( self.WElements ) do
				if v.type == "Model" then
					table.insert( self.wRenderOrder, 1, k )

				elseif v.type == "Sprite" or v.type == "Quad" then
					table.insert( self.wRenderOrder, k )

				end
			end
		end

		local owner = self:GetOwner()
		local bone_ent = IsValid( owner ) and owner or self

		for _, name in pairs( self.wRenderOrder ) do
			local v = self.WElements[name]
			if not v then self.wRenderOrder = nil break end
			if v.hide then continue end

			local pos, ang
			if v.bone then
				pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent )

			else
				pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent, "ValveBiped.Bip01_R_Hand" )

			end

			if not pos then continue end

			local model = v.modelEnt
			local sprite = v.spriteMaterial

			if v.type == "Model" and IsValid( model ) then
				model:SetPos( pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
				ang:RotateAroundAxis( ang:Up(), v.angle.y )
				ang:RotateAroundAxis( ang:Right(), v.angle.p )
				ang:RotateAroundAxis( ang:Forward(), v.angle.r )

				model:SetAngles( ang )
				local matrix = Matrix()
				matrix:Scale( v.size )
				model:EnableMatrix( "RenderMultiply", matrix )

				if v.material == "" then
					model:SetMaterial( "" )
				elseif model:GetMaterial() ~= v.material then
					model:SetMaterial( v.material )

				end

				if v.skin and v.skin ~= model:GetSkin() then
					model:SetSkin( v.skin )

				end

				if v.bodygroup then
					for bg_k, bg_v in pairs( v.bodygroup ) do
						if model:GetBodygroup( bg_k ) ~= bg_v then
							model:SetBodygroup( bg_k, bg_v )

						end
					end
				end

				render.SetColorModulation( v.color.r / 255, v.color.g / 255, v.color.b / 255 )
				render.SetBlend( v.color.a / 255 )
				model:DrawModel()
				render.SetBlend( 1 )
				render.SetColorModulation( 1, 1, 1 )

			elseif v.type == "Sprite" and sprite then
				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				render.SetMaterial( sprite )
				render.DrawSprite( drawpos, v.size.x, v.size.y, v.color )

			elseif v.type == "Quad" and v.draw_func then
				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				ang:RotateAroundAxis( ang:Up(), v.angle.y )
				ang:RotateAroundAxis( ang:Right(), v.angle.p )
				ang:RotateAroundAxis( ang:Forward(), v.angle.r )

				cam.Start3D2D( drawpos, ang, v.size )
					v.draw_func( self )
				cam.End3D2D()

			end

		end

	end

	function SWEP:GetBoneOrientation( basetab, tab, ent, bone_override )
		local pos, ang

		if tab.rel and tab.rel ~= "" then
			local v = basetab[tab.rel]
			if not v then return end

			-- Note: If there exists an element with the same name as a bone
			-- you can get in an infinite loop.
			pos, ang = self:GetBoneOrientation( basetab, v, ent )
			if not pos then return end

			pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			ang:RotateAroundAxis( ang:Up(), v.angle.y )
			ang:RotateAroundAxis( ang:Right(), v.angle.p )
			ang:RotateAroundAxis( ang:Forward(), v.angle.r )
		else
			local bone = ent:LookupBone( bone_override or tab.bone )
			if not bone then return end

			pos, ang = Vector( 0, 0, 0 ), Angle( 0, 0, 0 )
			local m = ent:GetBoneMatrix( bone )
			if m then
				pos, ang = m:GetTranslation(), m:GetAngles()

			end

			local owner = self:GetOwner()
			if IsValid( owner ) and owner:IsPlayer() and ent == owner:GetViewModel() and self.ViewModelFlip then
				ang.r = -ang.r -- Fixes mirrored models

			end

		end

		return pos, ang

	end

	function SWEP:CreateModels( tab )
		if not tab then return end

		-- Create the clientside models here because Garry says we can't do it in the render hook
		for _, v in pairs( tab ) do
			local isValidModel = v.type == "Model" and v.model and v.model ~= ""
				and ( not IsValid( v.modelEnt ) or v.createdModel ~= v.model )
				and string.find( v.model, ".mdl" ) and file.Exists( v.model, "GAME" )

			if isValidModel then
				v.modelEnt = ClientsideModel( v.model, RENDER_GROUP_VIEW_MODEL_OPAQUE )
				if IsValid( v.modelEnt ) then
					v.modelEnt:SetPos( self:GetPos() )
					v.modelEnt:SetAngles( self:GetAngles() )
					v.modelEnt:SetParent( self )
					v.modelEnt:SetNoDraw( true )
					v.createdModel = v.model
				else
					v.modelEnt = nil

				end
				continue

			end

			local isValidSprite = v.type == "Sprite" and v.sprite and v.sprite ~= ""
				and ( not v.spriteMaterial or v.createdSprite ~= v.sprite )
				and file.Exists( "materials/" .. v.sprite .. ".vmt", "GAME" )

			if isValidSprite then
				local name = v.sprite .. "-"
				local params = { ["$basetexture"] = v.sprite }
				-- Make sure we create a unique name based on the selected options
				local tocheck = { "nocull", "additive", "vertexalpha", "vertexcolor", "ignorez" }
				for _, j in pairs( tocheck ) do
					if v[j] then
						params["$" .. j] = 1
						name = name .. "1"
					else
						name = name .. "0"

					end

				end

				v.createdSprite = v.sprite
				v.spriteMaterial = CreateMaterial( name, "UnlitGeneric", params )

			end
		end
	end

	local allbones
	local hasGarryFixedBoneScalingYet = false

	function SWEP:UpdateBonePositions( vm )
		if not self.ViewModelBoneMods then
			self:ResetBonePositions( vm )
			return

		end

		if not vm:GetBoneCount() then return end

		self:EnsureBonesAreReset( vm )

		-- WORKAROUND: We need to check all model names
		local loopthrough = self.ViewModelBoneMods
		if not hasGarryFixedBoneScalingYet then
			allbones = {}
			for i = 0, vm:GetBoneCount() do
				local bonename = vm:GetBoneName( i )
				if self.ViewModelBoneMods[bonename] then
					allbones[bonename] = self.ViewModelBoneMods[bonename]
				else
					allbones[bonename] = {
						scale = Vector( 1, 1, 1 ),
						pos = Vector( 0, 0, 0 ),
						angle = Angle( 0, 0, 0 )
					}

				end

			end
			loopthrough = allbones

		end

		for k, v in pairs( loopthrough ) do
			local bone = vm:LookupBone( k )
			if not bone then continue end

			-- WORKAROUND for bone scaling
			local s = Vector( v.scale.x, v.scale.y, v.scale.z )
			local p = Vector( v.pos.x, v.pos.y, v.pos.z )
			local ms = Vector( 1, 1, 1 )
			if not hasGarryFixedBoneScalingYet then
				local cur = vm:GetBoneParent( bone )
				while cur >= 0 do
					local pscale = loopthrough[vm:GetBoneName( cur )].scale
					ms = ms * pscale
					cur = vm:GetBoneParent( cur )

				end

			end

			s = s * ms

			if vm:GetManipulateBoneScale( bone ) ~= s then
				vm:ManipulateBoneScale( bone, s )

			end
			if vm:GetManipulateBoneAngles( bone ) ~= v.angle then
				vm:ManipulateBoneAngles( bone, v.angle )

			end
			if vm:GetManipulateBonePosition( bone ) ~= p then
				vm:ManipulateBonePosition( bone, p )

			end

		end

	end

	function SWEP:ResetBonePositions( vm )
		if not vm:GetBoneCount() then return end

		for i = 0, vm:GetBoneCount() do
			vm:ManipulateBoneScale( i, Vector( 1, 1, 1 ) )
			vm:ManipulateBoneAngles( i, Angle( 0, 0, 0 ) )
			vm:ManipulateBonePosition( i, Vector( 0, 0, 0 ) )

		end

		vm.BonePositionBreaker = nil

	end

	--[[
		Global utility code

		Fully copies the table, meaning all tables inside this table are copied too
		and so on (normal table.Copy copies only their reference).
		Does not copy entities of course, only copies their reference.
		WARNING: do not use on tables that contain themselves somewhere down the line
		or you'll get an infinite loop
	--]]
	function table.FullCopy( tab )
		if not tab then return nil end

		local res = {}
		for k, v in pairs( tab ) do
			if type( v ) == "table" then
				res[k] = table.FullCopy( v )
			elseif type( v ) == "Vector" then
				res[k] = Vector( v.x, v.y, v.z )
			elseif type( v ) == "Angle" then
				res[k] = Angle( v.p, v.y, v.r )
			else
				res[k] = v

			end

		end

		return res

	end

end