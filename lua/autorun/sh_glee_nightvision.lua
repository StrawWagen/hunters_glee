AddCSLuaFile()

-- Night vision goggles, bought in the shop (see glee_shopitems/sh_nightvision.lua) and kept in weapon slot 6.
-- Left click with them out flips them down or up, that's the only way. Hold V with them out to throw them down,
-- through glee's own weapon dropper.
-- Models and sounds come from Neosun's Cooler Nightvision, workshop 3425531829, copied into glee's own
-- models/glee/nvg, materials/models/glee/nvg and sound/hunters_glee/nvg, so only glee is needed.
-- The .mdl files had their internal name and texture folder paths repointed there.
-- Spawnable as weapons (glee_nvg_*) and as pickups in the entities tab (glee_nvgpickup_*).
-- The server holds who has them on in the player's "glee_nvg_on" NW2String (the weapon class, "" when off),
-- so everyone sees the goggles on that player's head, and the wearer's client draws the vision.
--
-- The vision keeps the map's own lighting and shadows. A faint lamp from the eyes lights pitch black, then
-- the picture is multiplied by gain (grey and green for the normal ones), so dark spots come up and lit spots blow out.

GleeNVG = GleeNVG or {}

-- one entry per goggle weapon class
-- model = worn on the head, also the dropped weapon's model
-- lamp = brightness of the faint light from the eyes, so pitch black still has something to amplify, nil for none
-- lampColor = colour of that light, white if nil
-- gain = the picture is multiplied by this, bigger blows lit areas out sooner
-- saturation = 0 turns the picture grey before the gain, 1 keeps the map's colours
-- bloom = glare around bright spots, nil for none
-- tint = the picture is then multiplied by this, black stays black and blown out white becomes this colour
-- heatColor = draw living npcs, players and nextbots, and every ragdoll, in this colour on top
GleeNVG.kinds = {
    glee_nvg_gpnvg = {
        name = "GPNVG-18 Night Vision",
        model = "models/glee/nvg/nvg_gpnvg.mdl",
        lamp = 0.01, -- was 0.03, washed out up close
        gain = 5,
        saturation = 0,
        bloom = { darken = 0.6, multiply = 2, size = 6, passes = 2 },
        tint = Color( 80, 255, 80 ), -- green
    },
    glee_nvg_t7 = {
        name = "T-7 Thermal",
        model = "models/glee/nvg/nvg_t7.mdl",
        lamp = 0.001,
        gain = 0.6,
        saturation = 0.4, -- dulled colours
        heatColor = Color( 255, 90, 20 ), -- red orange
    },
    glee_nvg_pvs14 = {
        name = "PVS-14 Haptic Vision",
        model = "models/glee/nvg/nvg_pvs14.mdl",
        -- no vision effect, just a light from the eyes that lights the dark in green, the map looks normal otherwise
        lamp = 0.6,
        lampColor = Color( 255, 80, 0 ), -- same green as the GPNVG
        -- the radar is in lua/autorun/sh_glee_nvg_haptic.lua
    },
}

GleeNVG.nwKey = "glee_nvg_on"
GleeNVG.onSound = "hunters_glee/nvg/nvg_on_1.wav"
GleeNVG.offSound = "hunters_glee/nvg/nvg_off_1.wav"

-- where the goggles sit on the head, the nvg mod's numbers, from the "eyes" attachment
GleeNVG.wornOffset = Vector( -4, 0, -2 )
GleeNVG.wornAngle = Angle( 0, 0, 0 )

-- a goggle weapon calls this with its own class name, takes the name and model from GleeNVG.kinds
-- Category and Spawnable go on the class's own table, the spawnmenu lists read that and not the base's
function GleeNVG_SetupSwep( SWEP, class )
    local kind = GleeNVG and GleeNVG.kinds[class]
    if not kind then return end
    SWEP.PrintName = kind.name
    SWEP.WorldModel = kind.model
    SWEP.Category = "Hunter's Glee"
    SWEP.Spawnable = true

    if CLIENT then
        language.Add( class, SWEP.PrintName ) -- no icon, weapon select shows the name

    end
end

-- a goggle pickup calls this with its own class and the weapon it gives
function GleeNVG_SetupPickup( ENT, class, gives )
    local kind = GleeNVG and GleeNVG.kinds[gives]
    if not kind then return end
    ENT.PrintName = kind.name
    ENT.Model = kind.model
    ENT.Gives = gives
    ENT.Category = "Hunter's Glee"
    ENT.Spawnable = true

    if CLIENT then
        language.Add( class, ENT.PrintName ) -- no icon

    end
end

local plyMeta = FindMetaTable( "Player" )

-- the goggle weapon this player is carrying, nil if none. only one can be carried at a time
function plyMeta:GetGleeNVG()
    for class in pairs( GleeNVG.kinds ) do
        local wep = self:GetWeapon( class )
        if IsValid( wep ) then return wep end

    end
end

-- the kind table of the goggles this player has flipped down, nil if off
function plyMeta:GetGleeNVGOn()
    if not self:Alive() then return end
    local class = self:GetNW2String( GleeNVG.nwKey, "" )
    if class == "" then return end
    return GleeNVG.kinds[class], class

end

if SERVER then
    local toggleCooldown = 0.4

    function plyMeta:SetGleeNVGOn( class, quiet )
        class = class or ""
        local old = self:GetNW2String( GleeNVG.nwKey, "" )
        if old == class then return end

        self:SetNW2String( GleeNVG.nwKey, class )
        if quiet then return end

        local snd = class == "" and GleeNVG.offSound or GleeNVG.onSound
        self:EmitSound( snd, 60, math.random( 95, 105 ), 0.8 )

    end

    -- flip the goggles in the inventory down, or back up. called by the goggles' left click
    function plyMeta:ToggleGleeNVG()
        if not self:Alive() then return end
        local nextToggle = self.glee_NextNVGToggle or 0
        if nextToggle > CurTime() then return end

        local wep = self:GetGleeNVG()
        if not IsValid( wep ) then self:SetGleeNVGOn( nil, true ) return end

        self.glee_NextNVGToggle = CurTime() + toggleCooldown
        if self:GetNW2String( GleeNVG.nwKey, "" ) ~= "" then
            self:SetGleeNVGOn( nil )

        else
            self:SetGleeNVGOn( wep:GetClass() )

        end
    end

    hook.Add( "PlayerDeath", "glee_nvg_off", function( ply ) ply:SetGleeNVGOn( nil, true ) end )
    hook.Add( "PlayerSpawn", "glee_nvg_off", function( ply ) ply:SetGleeNVGOn( nil, true ) end )

    -- only one pair of goggles in the inventory, whatever the kind
    hook.Add( "PlayerCanPickupWeapon", "glee_nvg_onlyone", function( ply, wep )
        if not GleeNVG.kinds[wep:GetClass()] then return end
        if IsValid( ply:GetGleeNVG() ) then return false end

    end )

    -- goggles that left the inventory, thrown, stripped or removed, can't stay on
    timer.Create( "glee_nvg_validate", 0.5, 0, function()
        for _, ply in player.Iterator() do
            local class = ply:GetNW2String( GleeNVG.nwKey, "" )
            if class ~= "" and not ply:HasWeapon( class ) then
                ply:SetGleeNVGOn( nil, true )

            end
        end
    end )

    return

end

-- clientside from here

local LocalPlayer = LocalPlayer

local wornModels = {} -- [ply] = ClientsideModel
local heatEnts = {}
local nextHeatScan = 0
local heatScanInterval = 0.25

local lamp
local lampBrightness
local lampColor
local lampFov = 170
local lampFarZ = 2048

local white = Material( "models/debug/debugwhite" )

local function localKind()
    local me = LocalPlayer()
    if not IsValid( me ) then return end
    return me:GetGleeNVGOn()

end

-- the faint light from the eyes, only the wearer has it, everyone else sees the map as it is
local function removeLamp()
    if not IsValid( lamp ) then lamp = nil return end
    lamp:Remove()
    lamp = nil

end

hook.Add( "PreRender", "glee_nvg_lamp", function()
    local kind = localKind()
    local brightness = kind and kind.lamp
    if not brightness then
        if lamp then removeLamp() end
        return

    end

    local color = kind.lampColor or color_white
    if not IsValid( lamp ) or lampBrightness ~= brightness or lampColor ~= color then
        removeLamp()
        lamp = ProjectedTexture()
        lamp:SetTexture( "effects/flashlight/square" )
        lamp:SetFOV( lampFov )
        lamp:SetFarZ( lampFarZ )
        lamp:SetBrightness( brightness )
        lamp:SetColor( color )
        lamp:SetConstantAttenuation( 0.5 )
        lamp:SetEnableShadows( false )
        lampBrightness = brightness
        lampColor = color

    end

    local me = LocalPlayer()
    lamp:SetPos( me:EyePos() )
    lamp:SetAngles( me:EyeAngles() )
    lamp:Update()

end )

-- anything warm: living players, npcs and nextbots, and every ragdoll
local function isHot( ent, me )
    if not IsValid( ent ) or ent:IsDormant() or ent:GetNoDraw() then return false end
    if ent == me and not me:ShouldDrawLocalPlayer() then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return ent:IsRagdoll()

end

local function scanHeat( me )
    if nextHeatScan > CurTime() then return end
    nextHeatScan = CurTime() + heatScanInterval

    heatEnts = {}
    for _, ent in ipairs( ents.GetAll() ) do
        if isHot( ent, me ) then heatEnts[#heatEnts + 1] = ent end

    end
end

local function drawHeat( me, color )
    scanHeat( me )
    if #heatEnts <= 0 then return end

    cam.Start3D()
        render.SuppressEngineLighting( true )
        render.ResetModelLighting( 1, 1, 1 )
        render.MaterialOverride( white )
        render.SetColorModulation( color.r / 255, color.g / 255, color.b / 255 )
        render.SetBlend( 1 )

        for _, ent in ipairs( heatEnts ) do
            if IsValid( ent ) then ent:DrawModel() end

        end

        render.SetColorModulation( 1, 1, 1 )
        render.MaterialOverride()
        render.SuppressEngineLighting( false )
    cam.End3D()

end

hook.Add( "RenderScreenspaceEffects", "glee_nvg_vision", function()
    local kind = localKind()
    if not kind then return end
    local me = LocalPlayer()

    -- grey (or not), then gain, the map's own light and shadows stay, just brighter
    local gain = kind.gain
    if gain then
        DrawColorModify( {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0,
            ["$pp_colour_contrast"] = gain,
            ["$pp_colour_colour"] = kind.saturation or 0,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        } )
    end

    local bloom = kind.bloom
    if bloom then
        DrawBloom( bloom.darken, bloom.multiply, bloom.size, bloom.size, bloom.passes, 1, 1, 1, 1 )

    end

    -- multiply the screen by the tint, black stays black, white becomes the tint
    local tint = kind.tint
    if tint then
        cam.Start2D()
            render.OverrideBlend( true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD )
            surface.SetDrawColor( tint.r, tint.g, tint.b, 255 )
            surface.DrawRect( 0, 0, ScrW(), ScrH() )
            render.OverrideBlend( false )
        cam.End2D()

    end


    -- after the gain and tint, so warm things keep their exact colour
    if kind.heatColor then drawHeat( me, kind.heatColor ) end

end )

-- the goggles on the head of everyone who has them flipped down, placed like the nvg mod does
local function removeWorn( ply )
    local mdl = wornModels[ply]
    if IsValid( mdl ) then mdl:Remove() end
    wornModels[ply] = nil

end

hook.Add( "PostPlayerDraw", "glee_nvg_worn", function( ply )
    local kind = ply:GetGleeNVGOn()
    if not kind or ( ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() ) then
        if wornModels[ply] then removeWorn( ply ) end
        return

    end

    local mdl = wornModels[ply]
    if not IsValid( mdl ) or mdl:GetModel() ~= kind.model then
        removeWorn( ply )
        mdl = ClientsideModel( kind.model )
        if not IsValid( mdl ) then return end
        mdl:SetNoDraw( true )
        wornModels[ply] = mdl

    end

    local att = ply:GetAttachment( ply:LookupAttachment( "eyes" ) )
    if not att then return end

    local pos, ang = LocalToWorld( GleeNVG.wornOffset, GleeNVG.wornAngle, att.Pos, att.Ang )
    mdl:SetPos( pos )
    mdl:SetAngles( ang )
    mdl:SetupBones()
    mdl:DrawModel()

end )

hook.Add( "EntityRemoved", "glee_nvg_worn", function( ent )
    if wornModels[ent] then removeWorn( ent ) end

end )
