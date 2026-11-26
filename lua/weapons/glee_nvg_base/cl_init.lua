include( "shared.lua" )

-- the goggles' vision, the lamp, the picture, heat, and the hum
-- only the wearer's client runs it, and only while they're carried, see SetupWear at the bottom

local white = Material( "models/debug/debugwhite" )

local lampFov = 170
local lampFarZDefault = 5000 -- every goggle's light reaches this far unless its vision says otherwise

-- ragdolls are cold bodies rather than warm ones, so they get a flat grey instead of the heat colour.
-- keeping it duller than the living is the point: a corpse on the floor should not read as a person
local ragdollColor = Color( 110, 110, 110 )
local heatScanInterval = 0.25
local heatRangeDefault = 3000 -- hammer units: past this a warm thing stops shading over at all

local runSoundDefaultVolume = 0.35

local function isSeeing( wep, wearer )
    return wep:GetDown() and wearer:Alive()

end


-- Heat -----------------------------------------------------------------------

-- anything warm: living players, npcs and nextbots, and every ragdoll
local function isHot( ent, me )
    if not IsValid( ent ) or ent:IsDormant() or ent:GetNoDraw() then return false end
    if ent == me and not me:ShouldDrawLocalPlayer() then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return ent:IsRagdoll()

end

local heatEnts = {}
local nextHeatScan = 0

local function scanHeat( me )
    if nextHeatScan > CurTime() then return end
    nextHeatScan = CurTime() + heatScanInterval

    heatEnts = {}
    for _, ent in ents.Iterator() do
        if isHot( ent, me ) then heatEnts[#heatEnts + 1] = ent end

    end
end

-- warm things fade with distance, gone by range
local function drawHeat( me, color, range )
    scanHeat( me )
    if #heatEnts <= 0 then return end

    local eyePos = me:EyePos()
    cam.Start3D()
        -- hooks drawing earlier in the frame can leave blend, depth, cull and colour state behind
        -- start from the engine's defaults, so none of it clips, tints or blends the heat
        render.SetStencilEnable( false )
        render.SetScissorRect( 0, 0, 0, 0, false )
        render.OverrideDepthEnable( false, false )
        render.OverrideColorWriteEnable( false, false )
        render.OverrideAlphaWriteEnable( false, false )
        render.OverrideBlend( false )
        render.CullMode( MATERIAL_CULLMODE_CCW )
        render.DepthRange( 0, 1 )
        render.SuppressEngineLighting( true )
        render.ResetModelLighting( 1, 1, 1 )

        -- two passes, warm first then the grey dead, since the colour modulation is one setting for
        -- the whole draw call
        for pass = 1, 2 do
            local ragdolls = pass == 2
            local shade = ragdolls and ragdollColor or color
            local red, green, blue = shade.r / 255, shade.g / 255, shade.b / 255

            for _, ent in ipairs( heatEnts ) do
                if IsValid( ent ) and ent:IsRagdoll() == ragdolls then
                    local fade = 1 - ( ent:WorldSpaceCenter() - eyePos ):Length() / range
                    if fade > 0 then
                        -- per entity, not once per pass
                        -- an entity's own draw code can reset these to defaults when it's done
                        render.MaterialOverride( white )
                        render.SetColorModulation( red, green, blue )
                        render.SetBlend( fade )
                        ent:DrawModel()

                    end
                end
            end
        end

        render.SetBlend( 1 )
        render.SetColorModulation( 1, 1, 1 )
        render.MaterialOverride()
        render.SuppressEngineLighting( false )
    cam.End3D()

end


-- Corner occlusion -----------------------------------------------------------

-- the goggles read as a tube, the picture dims towards the edges, darkest in the corners
-- one-pixel strips down the ramp, so the fade is a gradient and not a band
local vignetteAlpha = 255 -- black

-- how dark a strip is, from how many pixels in from the edge it sits
local function edgeAlpha( out, half, start, finish )
    local reach = 1 - out / half

    if reach >= finish then return vignetteAlpha end
    if reach <= start then return 0 end

    local t = ( reach - start ) / ( finish - start )
    return math.floor( vignetteAlpha * t * t + 0.5 )

end

-- { start = 0.5, finish = 0.8 } fades in from halfway out, and is solid black over the last fifth
-- both are shares of the way from the middle of the screen to its edge
local function drawVignette( vignette )
    local start = math.Clamp( vignette.start or 0.5, 0, 1 )
    local finish = math.Clamp( vignette.finish or 1, 0, 1 )
    if finish <= start then return end

    local w, h = ScrW(), ScrH()
    local halfW, halfH = w * 0.5, h * 0.5

    -- solid from the edge in to finish, then the ramp, which runs out at start
    local solidX = math.floor( halfW * ( 1 - finish ) )
    local solidY = math.floor( halfH * ( 1 - finish ) )
    local rampX = math.floor( halfW * ( 1 - start ) )
    local rampY = math.floor( halfH * ( 1 - start ) )

    cam.Start2D()
        -- each set runs the whole other axis, so the four corners take one of each and come out
        -- darker than either edge on its own
        if solidX > 0 then
            surface.SetDrawColor( 0, 0, 0, vignetteAlpha )
            surface.DrawRect( 0, 0, solidX, h )
            surface.DrawRect( w - solidX, 0, solidX, h )

        end

        for out = solidX, rampX - 1 do
            surface.SetDrawColor( 0, 0, 0, edgeAlpha( out, halfW, start, finish ) )
            surface.DrawRect( out, 0, 1, h )
            surface.DrawRect( w - 1 - out, 0, 1, h )

        end

        if solidY > 0 then
            surface.SetDrawColor( 0, 0, 0, vignetteAlpha )
            surface.DrawRect( 0, 0, w, solidY )
            surface.DrawRect( 0, h - solidY, w, solidY )

        end

        for out = solidY, rampY - 1 do
            surface.SetDrawColor( 0, 0, 0, edgeAlpha( out, halfH, start, finish ) )
            surface.DrawRect( 0, out, w, 1 )
            surface.DrawRect( 0, h - 1 - out, w, 1 )

        end
    cam.End2D()

end


-- The picture ----------------------------------------------------------------

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

local function drawVision( vision, wearer )
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
    if vision.heatColor then drawHeat( wearer, vision.heatColor, vision.heatRange or heatRangeDefault ) end

    -- last, in front of everything seen through the tube
    if vision.vignette then drawVignette( vision.vignette ) end

end


-- Putting them on ------------------------------------------------------------

function SWEP.SetupWear( wear )
    local wearer = wear.wearer

    -- the light from the eyes, only the wearer has it, everyone else sees the map as it is
    local lamp
    local lampBrightness, lampColor, lampFarZ

    local function removeLamp()
        if IsValid( lamp ) then lamp:Remove() end
        lamp = nil

    end
    wear:OnRemove( removeLamp )

    wear:Hook( "PreRender", function( wep )
        local vision = wep.GleeNVG
        local brightness = vision.lamp
        if not brightness or not isSeeing( wep, wearer ) then
            removeLamp()
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

        lamp:SetPos( wearer:EyePos() )
        lamp:SetAngles( wearer:EyeAngles() )
        lamp:Update()

    end )

    wear:Hook( "RenderScreenspaceEffects", function( wep )
        if not isSeeing( wep, wearer ) then return end
        drawVision( wep.GleeNVG, wearer )

    end )

    -- the hum, a vision with runSound loops it on its own channel while they're down
    local runChannel
    local runPath
    local runPending = false

    local function stopRunSound()
        if runChannel then runChannel:Stop() end
        runChannel = nil
        runPath = nil

    end
    wear:OnRemove( stopRunSound )

    local function startRunSound( path, volume )
        if runPending then return end
        runPending = true

        sound.PlayFile( path, "noblock", function( channel, errID, errStr )
            runPending = false
            if not channel then
                MsgN( "[glee] nvg run loop failed: ", errID, " ", errStr )
                return

            end
            -- flipped up, or taken off, while the file was loading
            if runPath ~= path then
                channel:Stop()
                return

            end
            runChannel = channel
            channel:SetVolume( volume or runSoundDefaultVolume )
            channel:Play()

        end )
    end

    wear:Hook( "Think", function( wep )
        local vision = wep.GleeNVG
        local path = isSeeing( wep, wearer ) and vision.runSound
        if not path then
            stopRunSound()
            return

        end

        if runPath == path then
            -- the file ran out before the goggles did
            if runChannel and runChannel:GetState() == GMOD_CHANNEL_STOPPED then
                runChannel = nil
                startRunSound( path, vision.runSoundVolume )

            end
            return

        end

        stopRunSound()
        runPath = path
        startRunSound( path, vision.runSoundVolume )

    end )
end
