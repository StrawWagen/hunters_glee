include( "shared.lua" )

-- the goggles, clientside: the wearer's vision and lamp, and the goggles on everyone's head
-- every hook here bails on one NW2String read when the local player hasn't got goggles on

local LocalPlayer = LocalPlayer

local wornModels = setmetatable( {}, { __mode = "k" } ) -- [ply] = the goggles model on their head
local heatEnts = {}
local nextHeatScan = 0
local heatScanInterval = 0.25

local lamp
local lampBrightness
local lampColor
local lampFarZ
local lampFov = 170
local lampFarZDefault = 5000 -- every goggle's light reaches this far unless its vision says otherwise

local white = Material( "models/debug/debugwhite" )

-- ragdolls are cold bodies rather than warm ones, so they get a flat grey instead of the heat colour.
-- keeping it duller than the living is the point: a corpse on the floor should not read as a person
local ragdollColor = Color( 110, 110, 110 )

-- not drawn in the hand, they're on your head when flipped down
function SWEP:DrawWorldModel()
    if IsValid( self:GetOwner() ) then return end
    self:DrawModel()

end

local function localVision()
    local me = LocalPlayer()
    if not IsValid( me ) then return end
    return me:GetGleeNVGOn()

end

-- the light from the eyes, only the wearer has it, everyone else sees the map as it is
local function removeLamp()
    if IsValid( lamp ) then lamp:Remove() end
    lamp = nil

end

hook.Add( "PreRender", "glee_nvg_lamp", function()
    local vision = localVision()
    local brightness = vision and vision.lamp
    if not brightness then
        if lamp then removeLamp() end
        return

    end

    local color = vision.lampColor or color_white
    local farZ = vision.lampFarZ or lampFarZDefault
    if not IsValid( lamp ) or lampBrightness ~= brightness or lampColor ~= color or lampFarZ ~= farZ then
        removeLamp()
        lamp = ProjectedTexture()
        lamp:SetTexture( "effects/flashlight/square" )
        lamp:SetFOV( lampFov )
        lamp:SetFarZ( farZ )
        lamp:SetBrightness( brightness )
        lamp:SetColor( color )
        lamp:SetConstantAttenuation( 0.5 )
        lamp:SetEnableShadows( false )
        lampBrightness = brightness
        lampColor = color
        lampFarZ = farZ

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
        render.SetBlend( 1 )

        -- two passes, warm first then the grey dead, since the colour modulation is one setting for
        -- the whole draw call
        for pass = 1, 2 do
            local ragdolls = pass == 2
            local shade = ragdolls and ragdollColor or color

            for _, ent in ipairs( heatEnts ) do
                if IsValid( ent ) and ( ent:IsRagdoll() == ragdolls ) then
                    -- modulated here rather than once per pass: each model carries the shade
                    render.SetColorModulation( shade.r / 255, shade.g / 255, shade.b / 255 )
                    ent:DrawModel()
                    render.SetColorModulation( 1, 1, 1 )

                end
            end
        end

        render.SetColorModulation( 1, 1, 1 )
        render.MaterialOverride()
        render.SuppressEngineLighting( false )
    cam.End3D()

end

local colorMod = {
    ["$pp_colour_addr"] = 0,
    ["$pp_colour_addg"] = 0,
    ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"] = 1,
    ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0,
}

hook.Add( "RenderScreenspaceEffects", "glee_nvg_vision", function()
    local vision = localVision()
    if not vision then return end

    -- saturation, then gain, the map's own light and shadows stay, just brighter
    local gain = vision.gain
    if gain then
        colorMod["$pp_colour_contrast"] = gain
        colorMod["$pp_colour_colour"] = vision.saturation or 0
        DrawColorModify( colorMod )

    end

    local bloom = vision.bloom
    if bloom then
        DrawBloom( bloom.darken, bloom.multiply, bloom.size, bloom.size, bloom.passes, 1, 1, 1, 1 )

    end

    -- multiply the screen by the tint, black stays black, white becomes the tint
    local tint = vision.tint
    if tint then
        cam.Start2D()
            render.OverrideBlend( true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD )
            surface.SetDrawColor( tint.r, tint.g, tint.b, 255 )
            surface.DrawRect( 0, 0, ScrW(), ScrH() )
            render.OverrideBlend( false )
        cam.End2D()

    end

    -- after the gain and tint, so warm things keep their exact colour
    if vision.heatColor then drawHeat( LocalPlayer(), vision.heatColor ) end

end )

-- the goggles on the head of everyone who has them flipped down, placed like the nvg mod does
-- terminator_Extras parents them to the eyes attachment and draws them, and hides them from whoever is inside that player
local wornOffset = Vector( -4, 0, -2 ) -- from the "eyes" attachment
local wornAngle = Angle( 0, 0, 0 )
local wornKey = "glee_nvg_worn"

local function refreshWorn( ply )
    local _, _, stored = ply:GetGleeNVGOn()
    local model = stored and stored.WorldModel
    if wornModels[ply] == model then return end

    wornModels[ply] = nil
    terminator_Extras.RemoveMyExtraModels( ply, wornKey )
    if not model then return end

    wornModels[ply] = model
    terminator_Extras.AttachMyExtraModels( ply, {
        { model = model, attachment = "eyes", pos = wornOffset, ang = wornAngle, hideWhenDead = true },
    }, wornKey )

end

hook.Add( "Think", "glee_nvg_worn", function()
    for _, ply in ipairs( player.GetAll() ) do
        refreshWorn( ply )
    end

end )

-- goggles that hum while they're down: any vision table with .runSound gets a loop on its own
-- channel, started when that class is the one flipped down and stopped when it comes back up.
-- the haptic does its own, gated on the radar instead of the goggles, so it doesn't set this
local runSoundChannel = nil
local runSoundPath = nil
local runSoundPending = false
local runSoundDefaultVolume = 0.35

local function stopRunSound()
    if runSoundChannel then runSoundChannel:Stop() end
    runSoundChannel = nil
    runSoundPath = nil

end

local function startRunSound( path, volume )
    if runSoundPending then return end
    runSoundPending = true

    sound.PlayFile( path, "noblock", function( channel, errID, errStr )
        runSoundPending = false
        if not channel then
            MsgN( "[glee] nvg run loop failed: ", errID, " ", errStr )
            return

        end
        -- flipped up while the file was loading: drop it instead of humming to nobody
        if runSoundPath ~= path then return end
        runSoundChannel = channel
        channel:SetVolume( volume or runSoundDefaultVolume )
        channel:Play()

    end )
end

hook.Add( "Think", "glee_nvg_runsound", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then
        stopRunSound()
        return

    end

    local vision = ply:GetGleeNVGOn()
    local path = vision and vision.runSound
    if not path then
        stopRunSound()
        return

    end

    if runSoundPath == path then
        -- already humming: only restart it if the file ran out before the goggles did
        if runSoundChannel and runSoundChannel:GetState() == ( GMOD_CHANNEL_STOPPED or 0 ) then
            runSoundChannel = nil
            startRunSound( path, vision.runSoundVolume )

        end
        return

    end

    -- a different pair went on: swap the loop rather than stacking two
    stopRunSound()
    runSoundPath = path
    startRunSound( path, vision.runSoundVolume )

end )
