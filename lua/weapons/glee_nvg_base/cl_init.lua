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

-- warm things thin out with distance instead of jumping from solid to gone, so a crowd across the
-- map no longer paints the horizon
local function drawHeat( me, color, range )
    scanHeat( me )
    if #heatEnts <= 0 then return end

    local eyePos = me:EyePos()
    cam.Start3D()
        -- the 3D state belongs to the frame, not to this pass: hooks that draw things earlier in it can
        -- leave blend, depth, cull and colour behind, and clear them only when they run again, a frame
        -- later. start from the engine's own defaults so nothing spawned elsewhere can clip, tint or
        -- blend the heat
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
                        -- set again per entity rather than once for the pass: model drawing in this
                        -- pack tends to hand these back as defaults instead of what it found, which
                        -- leaves every one drawn after it in the wrong colour or the wrong material
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

-- the goggles read as a tube: the picture dims towards the frame, and the corners, where two edges
-- meet, are darker than either of them. one-pixel strips down the ramp and a plain slab past it, so
-- the fade is a gradient and not a band
local vignetteAlpha = 255 -- black

-- how dark a pixel is, from how far out it sits: out of half the screen, so 0 is the middle and the
-- edge itself is 1
local function edgeAlpha( out, half, start, finish )
    local reach = 1 - out / half

    if reach >= finish then return vignetteAlpha end
    if reach <= start then return 0 end

    local t = ( reach - start ) / ( finish - start )
    return math.floor( vignetteAlpha * t * t + 0.5 )

end

-- start is where the fade begins and finish where it is solid black, both shares of the way from the
-- middle of the screen to its edge: { start = 0.5, finish = 0.8 } fades in from halfway out and is
-- black over the last fifth
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


-- The wheel ------------------------------------------------------------------

local OUTER_RADIUS_1080P = 300

-- built as it opens, so the labels say what picking them does right now
-- goggles with more on their wheel add theirs to this, see glee_nvg_pvs14
-- each key is handled by OnWheelPick, init.lua
function SWEP:GetWheelActions()
    return {
        { key = "flip", label = self:GetDown() and "Flip up" or "Flip down" },
    }
end

-- asks the server to run one of the goggles' actions, by key, see OnWheelPick
local function sendPick( key )
    net.Start( "glee_nvg_wheelpick" )
        net.WriteString( key )
    net.SendToServer()

end

-- held open while attack is, letting go picks
-- shares glee_Carrying.CurrentWheel, so only one wheel's ever open
local function openWheel( wearer, wep, actions )
    local carrying = terminator_Extras.glee_Carrying

    local oldWheel = carrying.CurrentWheel
    if IsValid( oldWheel ) then oldWheel:Remove() end

    local wheel = vgui.Create( "glee_wheel" )
    if not IsValid( wheel ) then return end
    local outer = wheel:Style():Scaled( OUTER_RADIUS_1080P )

    wheel:SetSize( outer * 2, outer * 2 )
    wheel:SetItems( actions )
    wheel:Center()

    function wheel:GetItemStatus()
        return IsValid( wep ) and wearer:GetActiveWeapon() == wep

    end

    function wheel:OnItemSelected( item )
        sendPick( item.key )
        self:Close()

    end

    hook.Add( "Think", wheel, function( self )
        if IsValid( wep ) and wearer:Alive() and wearer:GetActiveWeapon() == wep then return end
        self:Close()

    end )

    wheel:HoldAim()
    wearer:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    carrying.CurrentWheel = wheel
    return wheel

end


-- Putting them on ------------------------------------------------------------

function SWEP.SetupWear( wear )
    local wearer = wear.wearer

    -- CreateMove, not PrimaryAttack, that never runs clientside in singleplayer
    local attackWasDown = false
    local wasActive, cameToHand = false, 0
    local wheel

    -- a click that lands as they come to hand is not for them: it is the same click that asked for the
    -- swap, as picking a weapon off a slot bar is, and it used to flip these on its way through
    local settleTime = 0.2

    wear:Hook( "CreateMove", function( wep, cmd )
        local active = wearer:GetActiveWeapon() == wep
        if active and not wasActive then cameToHand = CurTime() end
        wasActive = active

        local attackDown = cmd:KeyDown( IN_ATTACK )
        if attackDown == attackWasDown then return end
        attackWasDown = attackDown

        -- releasing always comes through: a wheel opened on the press still has to close
        if not attackDown then
            if IsValid( wheel ) then wheel:Release() end
            wheel = nil
            return

        end

        if not active or CurTime() - cameToHand < settleTime then return end
        -- the cursor is a panel's, so the click is going to that and not to what's in hand: the slot
        -- bar picks with it, and the click that picks the tool used to reach these first
        if vgui.CursorVisible() or gui.IsGameUIVisible() then return end
        if not wearer:Alive() or wearer:InVehicle() then return end

        -- one action just runs, several open the wheel, as glee_carrying's use does
        local actions = wep:GetWheelActions()
        if #actions == 1 then
            sendPick( actions[1].key )
            return

        end

        wheel = openWheel( wearer, wep, actions )

    end )

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
