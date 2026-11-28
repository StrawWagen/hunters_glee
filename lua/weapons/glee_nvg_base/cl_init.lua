include( "shared.lua" )

-- the goggles' vision, the lamp, the picture, and the hum
-- only the wearer's client runs it, and only while they're carried, see SetupWear at the bottom

local lampFov = 170
local lampFarZDefault = 5000 -- every goggle's light reaches this far unless its vision says otherwise

local runSoundDefaultVolume = 0.35


-- Flipping -------------------------------------------------------------------

-- flipping sweeps a black bar across the eyes, top to bottom going down, bottom to top going up
-- the picture swaps while the bar covers the screen
-- the bar always heads for where they're flipped to, so spamming the flip holds it mid screen

local flipWipeTime = 0.15 -- seconds for the bar to cross the whole screen
local flipWipeFade = 0.3 -- the soft edge above and below the bar, a share of the screen's height

-- glee_FlipShare, 0 flipped up, 1 down, between while the bar's crossing
local function advanceFlip( wep, wearer )
    local target = wep:GetDown() and 1 or 0
    if not wearer:Alive() then
        wep.glee_FlipShare = target
        return

    end

    wep.glee_FlipShare = math.Approach( wep.glee_FlipShare or 0, target, FrameTime() / flipWipeTime )

end

-- the bar's past halfway, the vision's on. everything the goggles do checks this, not GetDown
function SWEP:IsGleeSeeing( wearer )
    return ( self.glee_FlipShare or 0 ) > 0.5 and wearer:Alive()

end

-- where the bar's solid part starts, and how tall its soft edges are, in pixels
-- the bar and its edges sit just above the screen at 0, the solid part covers it at 0.5, just below at 1
local function flipWipeTop( share )
    local h = ScrH()
    local fade = h * flipWipeFade
    return Lerp( share, -( h + fade ), h + fade ), fade

end

-- pixels down from where the goggles' frame rests, the vignette and anything drawn on the hud
-- the frame rides just above the bar, the goggles slide down over the eyes with it, and back up
-- 0 once they're down, offset everything screen anchored by this
function SWEP:GleeFlipOffset()
    local top, fade = flipWipeTop( self.glee_FlipShare or 0 )
    return top - ScrH() - fade

end


-- Corner occlusion -----------------------------------------------------------

-- the goggles read as one round tube, the picture darkens towards its edge
-- rings of vertex coloured triangles, the same way as the gamemode's tunnel vision, panic/cl_tunnelvision.lua

-- each ring's a polygon this many sided, fewer and the corners show in the gradient on wide tubes
local vignetteSegments = 128

-- out from start to finish, a share of the way there and how dark, smooths the edge
local vignetteRings = {
    { share = 0, alpha = 0 },
    { share = 0.4, alpha = 0.2 },
    { share = 0.75, alpha = 0.6 },
    { share = 1, alpha = 1 },
    { alpha = 1 }, -- no share, past every corner of the screen
}

local vignetteCos, vignetteSin = {}, {}
for seg = 0, vignetteSegments do
    local ang = seg / vignetteSegments * math.pi * 2
    vignetteCos[seg] = math.cos( ang )
    vignetteSin[seg] = math.sin( ang )

end

local vignetteShares = {}

-- the shape's edge at a share of 1, in pixels out from the middle, per segment
local vignetteEdgeX, vignetteEdgeY = {}, {}

-- a superellipse, roundness 2 is a circle, higher pushes it out towards a square's corners
-- spanX, spanY = pixels a share of 1 reaches, sideways and up
local function shapeVignette( spanX, spanY, roundness )
    for seg = 0, vignetteSegments do
        local cos, sin = vignetteCos[seg], vignetteSin[seg]
        local scale = ( math.abs( cos ) ^ roundness + math.abs( sin ) ^ roundness ) ^ ( -1 / roundness )
        vignetteEdgeX[seg] = cos * scale * spanX
        vignetteEdgeY[seg] = sin * scale * spanY

    end
end

local function vignetteVertex( x, y, alpha )
    mesh.Position( x, y, 0 )
    mesh.Color( 0, 0, 0, alpha * 255 )
    mesh.AdvanceVertex()

end

-- { start = 0.5, finish = 0.8 } starts darkening halfway out, and is solid black past four fifths
-- aspect = "square", as wide as tall, start and finish are shares of the way to the screen's nearer edge
--          "full", stretched to the screen, shares of the way to each edge, a border round it
-- roundness = 2 for round, 4 a rounded square, higher gets squarer. the corners poke out past start and finish
-- offsetY, pixels down from the screen's middle, see GleeFlipOffset
local function drawVignette( vignette, offsetY )
    local start = math.Clamp( vignette.start or 0.5, 0, 1 )
    local finish = math.Clamp( vignette.finish or 1, 0, 1 )
    if finish <= start then return end

    local w, h = ScrW(), ScrH()
    local centerX, centerY = w * 0.5, h * 0.5 + offsetY
    local spanX, spanY = w * 0.5, h * 0.5
    if vignette.aspect ~= "full" then
        local shorter = math.min( spanX, spanY )
        spanX, spanY = shorter, shorter

    end
    shapeVignette( spanX, spanY, vignette.roundness or 2 )

    for index, ring in ipairs( vignetteRings ) do
        local share = ring.share
        vignetteShares[index] = share and start + ( finish - start ) * share or ( w + h ) / math.min( spanX, spanY )

    end

    cam.Start2D()
        cam.IgnoreZ( true ) -- the viewmodel's still in the depth buffer, it'd cut its shape out of the dark
        render.SetColorMaterial()
        mesh.Begin( MATERIAL_TRIANGLES, ( #vignetteRings - 1 ) * vignetteSegments * 2 )
        for index = 1, #vignetteRings - 1 do
            local innerAlpha, outerAlpha = vignetteRings[index].alpha, vignetteRings[index + 1].alpha
            local innerShare, outerShare = vignetteShares[index], vignetteShares[index + 1]

            for seg = 0, vignetteSegments - 1 do
                local edgeAX, edgeAY = vignetteEdgeX[seg], vignetteEdgeY[seg]
                local edgeBX, edgeBY = vignetteEdgeX[seg + 1], vignetteEdgeY[seg + 1]

                local innerAX, innerAY = centerX + edgeAX * innerShare, centerY + edgeAY * innerShare
                local innerBX, innerBY = centerX + edgeBX * innerShare, centerY + edgeBY * innerShare
                local outerAX, outerAY = centerX + edgeAX * outerShare, centerY + edgeAY * outerShare
                local outerBX, outerBY = centerX + edgeBX * outerShare, centerY + edgeBY * outerShare

                vignetteVertex( innerAX, innerAY, innerAlpha )
                vignetteVertex( outerAX, outerAY, outerAlpha )
                vignetteVertex( outerBX, outerBY, outerAlpha )

                vignetteVertex( innerAX, innerAY, innerAlpha )
                vignetteVertex( outerBX, outerBY, outerAlpha )
                vignetteVertex( innerBX, innerBY, innerAlpha )

            end
        end
        mesh.End()
        cam.IgnoreZ( false )
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

-- hooks drawing earlier in the frame can leave stencil, scissor, depth, colour, blend and cull state behind
-- starts from the engine's defaults, so none of it clips or blends the goggles' own passes
local function resetRenderState()
    render.SetStencilEnable( false )
    render.SetScissorRect( 0, 0, 0, 0, false )
    render.OverrideDepthEnable( false, false )
    render.OverrideColorWriteEnable( false, false )
    render.OverrideAlphaWriteEnable( false, false )
    render.OverrideBlend( false )
    render.CullMode( MATERIAL_CULLMODE_CCW )
    render.DepthRange( 0, 1 )

end

local function drawVision( wep, wearer )
    local vision = wep.GleeNVG
    resetRenderState()

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

    -- the goggles' own, see DrawGleeVision in shared.lua
    if wep.DrawGleeVision then wep:DrawGleeVision( wearer ) end

    -- last, in front of everything seen through the tube
    local vignette = wep:CurrentVignette()
    if vignette then drawVignette( vignette, wep:GleeFlipOffset() ) end

end

-- a strip across the screen, fading from fromAlpha at the top to toAlpha at the bottom
local function wipeStrip( w, top, bottom, fromAlpha, toAlpha )
    vignetteVertex( 0, top, fromAlpha )
    vignetteVertex( w, top, fromAlpha )
    vignetteVertex( w, bottom, toAlpha )
    vignetteVertex( 0, bottom, toAlpha )

end

local function drawFlipWipe( wep, wearer )
    local share = wep.glee_FlipShare or 0
    if share <= 0 or share >= 1 or not wearer:Alive() then return end

    resetRenderState()

    local w = ScrW()
    local top, fade = flipWipeTop( share )
    local bottom = top + ScrH()

    cam.Start2D()
        cam.IgnoreZ( true ) -- same as the vignette, the viewmodel's depth would cut through it
        render.SetColorMaterial()
        mesh.Begin( MATERIAL_QUADS, 3 )
            wipeStrip( w, top - fade, top, 0, 1 )
            wipeStrip( w, top, bottom, 1, 1 )
            wipeStrip( w, bottom, bottom + fade, 1, 0 )
        mesh.End()
        cam.IgnoreZ( false )
    cam.End2D()

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

    wear:Hook( "Think", function( wep )
        advanceFlip( wep, wearer )

    end )
    -- the share only moves while they're worn, taken off they're flipped up, see OwnerChanged in init.lua
    wear:OnRemove( function()
        local wep = wear.weapon
        if IsValid( wep ) then wep.glee_FlipShare = 0 end

    end )

    wear:Hook( "PreRender", function( wep )
        local vision = wep.GleeNVG
        local brightness = vision.lamp
        if not brightness or not wep:IsGleeSeeing( wearer ) then
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
        if wep:IsGleeSeeing( wearer ) then drawVision( wep, wearer ) end
        drawFlipWipe( wep, wearer )

    end )

    -- the goggles' own, drawn into the world, before the picture's made from it, see DrawGleeWorld in shared.lua
    wear:Hook( "PostDrawTranslucentRenderables", function( wep, drawingDepth, drawingSkybox )
        if drawingDepth or drawingSkybox then return end
        if not wep.DrawGleeWorld or not wep:IsGleeSeeing( wearer ) then return end
        wep:DrawGleeWorld( wearer )

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
        local path = wep:IsGleeSeeing( wearer ) and vision.runSound
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
