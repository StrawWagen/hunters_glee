--[[------------------------------------
    Bakes any drawing into an icon the hud can draw in its own colour.

        hook.Add( "HUDPaint", "my_icon", function()
            if myIcon then return end

            myIcon = terminator_Extras.glee_BakeIcon( "my_icon", 256, 128, function( w, h )
                surface.SetDrawColor( 255, 255, 255, 255 )
                surface.SetMaterial( someMaterial )
                surface.DrawTexturedRect( 0, 0, w, h )

            end )
        end )

        -- then, anywhere
        surface.SetDrawColor( hudColor )
        surface.SetMaterial( myIcon )
        surface.DrawTexturedRect( x, y, w, h )

    The baked icon is white all over, its transparency is the picture,
    so whatever colour it's drawn in tints the whole thing.

    Colour art keeps its shading, light parts solid, dark parts see through.
    The shading spans the icon's own darkest to brightest, a dull photo shades as deep as a crisp one.
    A one colour icon, a glyph or a silhouette, keeps the shape it came in.

    Bake in a 2D render hook like HUDPaint, not a panel's Paint, panels draw offset by where they sit, render targets too.
    Every pixel is read back and redrawn, a hitch the size of the icon. Bake once, keep the material.
--]]-------------------------------------

local MIN_RANGE = 0.15 -- less spread than this, between darkest and brightest, is one colour and compression noise
local LOW_PERCENTILE = 0.05 -- a glint or a whisker doesn't get to set the range
local HIGH_PERCENTILE = 0.95
local MIN_SHADE = 0.15 -- the darkest parts stay faintly there, so a dark subject keeps its outline
local SOLID_ALPHA = 128 -- see through pixels have no real colour, only these set the range

local rtFlags = bit.bor( 4, 8, 256, 512 ) -- clamp s, clamp t, no mips, no lod

-- render targets can't be freed, the same key reuses its own
local function newTarget( key, wide, tall )
    local name = "glee_icon_" .. util.CRC( key )
    local rt = GetRenderTargetEx( name, wide, tall, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, rtFlags, 0, IMAGE_FORMAT_RGBA8888 )
    local mat = CreateMaterial( name, "UnlitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$translucent"] = 1,
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = 1,
    } )

    return rt, mat

end


-- Passes, each on the pushed render target ---------------------------------

-- In full colour, over black.
-- Alpha layers over alpha, so an icon drawn in parts keeps every part
local function drawInColour( wide, tall, drawIcon )
    render.Clear( 0, 0, 0, 0 )
    render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ONE, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD )

    cam.Start2D()
        local ok, err = pcall( drawIcon, wide, tall )
    cam.End2D()

    render.OverrideBlend( false )
    return ok, err

end

--[[---------------------------------------------------------
    readPixels
    @return: alphas and brightnesses, 0 - 255, flat arrays indexed y * wide + x + 1. Brightness is nil where it's fully see through.
    @return: a 0 - 255 histogram of the solid pixels' brightness, and how many there are.
--]]---------------------------------------------------------
local function readPixels( wide, tall )
    render.CapturePixels()

    local alphas, brightnesses = {}, {}
    local histogram, solidCount = {}, 0
    for i = 0, 255 do histogram[i] = 0 end

    local readPixel = render.ReadPixel
    for y = 0, tall - 1 do
        for x = 0, wide - 1 do
            local r, g, b, a = readPixel( x, y )
            local i = y * wide + x + 1
            alphas[i] = a

            if a > 0 then
                -- drawn over black, so its colour was scaled down by its alpha
                local brightness = math.min( math.floor( ( r * 0.299 + g * 0.587 + b * 0.114 ) * 255 / a ), 255 )
                brightnesses[i] = brightness

                if a >= SOLID_ALPHA then
                    histogram[brightness] = histogram[brightness] + 1
                    solidCount = solidCount + 1

                end
            end
        end
    end

    return alphas, brightnesses, histogram, solidCount

end

local function percentile( histogram, count, fraction )
    local wanted = count * fraction
    local seen = 0
    for brightness = 0, 255 do
        seen = seen + histogram[brightness]
        if seen >= wanted then return brightness end

    end

    return 255

end

-- The drawn part, as fractions of the whole, nil if nothing was drawn
local function inkBounds( alphas, wide, tall )
    local left, top, right, bottom = wide, tall, -1, -1
    for y = 0, tall - 1 do
        for x = 0, wide - 1 do
            if alphas[y * wide + x + 1] > 0 then
                left = math.min( left, x )
                right = math.max( right, x )
                top = math.min( top, y )
                bottom = math.max( bottom, y )

            end
        end
    end

    if right < 0 then return end
    return { u0 = left / wide, v0 = top / tall, u1 = ( right + 1 ) / wide, v1 = ( bottom + 1 ) / tall }

end

local function cornersClear( alphas, wide, tall )
    local corners = { 1, wide, ( tall - 1 ) * wide + 1, tall * wide }
    for _, i in ipairs( corners ) do
        if alphas[i] < SOLID_ALPHA then return true end

    end

    return false

end

-- Colour to white, leaving the alpha
local function whiten( wide, tall )
    render.OverrideAlphaWriteEnable( true, false )

    cam.Start2D()
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.DrawRect( 0, 0, wide, tall )
    cam.End2D()

    render.OverrideAlphaWriteEnable( true, true )

end

-- Alpha from brightness, light solid, dark see through, leaving the colour
local function shade( alphas, brightnesses, wide, tall, darkest, range )
    render.OverrideColorWriteEnable( true, false )
    render.OverrideBlend( true, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD ) -- written as it is, not over what's there

    local function shaded( i )
        local brightness = brightnesses[i]
        if not brightness then return 0 end

        local light = math.Clamp( ( brightness - darkest ) / range, 0, 1 )
        return math.Round( alphas[i] * ( MIN_SHADE + ( 1 - MIN_SHADE ) * light ) )

    end

    cam.Start2D()
        -- runs of the same alpha go as one rect
        for y = 0, tall - 1 do
            local row = y * wide
            local runStart, runAlpha = 0, shaded( row + 1 )

            for x = 1, wide do
                local alpha = x < wide and shaded( row + x + 1 ) or nil
                if alpha ~= runAlpha then
                    -- see through was already cleared see through
                    if runAlpha > 0 then
                        surface.SetDrawColor( 255, 255, 255, runAlpha )
                        surface.DrawRect( runStart, y, x - runStart, 1 )

                    end
                    runStart, runAlpha = x, alpha

                end
            end
        end
    cam.End2D()

    render.OverrideBlend( false )
    render.OverrideColorWriteEnable( false )

end


--[[---------------------------------------------------------
    terminator_Extras.glee_BakeIcon
    @param key: Names the render target, the same key bakes over the same one.
    @param wide, tall: The bake's size in pixels, every one of them is read back.
    @param drawIcon: function( wide, tall ), draws the icon from 0, 0. Can error, it's other addons' code.
    @return: The baked material, white, drawn in any colour.
    @return: false if the drawing filled its corners. A tinted opaque picture is a solid block, draw the original instead.
    @return: The drawn part, { u0, v0, u1, v1 } for surface.DrawTexturedRectUV, nil if nothing was drawn.
        For drawings that don't fill their own box, like a font's glyph, sitting on its baseline.
--]]---------------------------------------------------------
function terminator_Extras.glee_BakeIcon( key, wide, tall, drawIcon )
    local rt, mat = newTarget( key, wide, tall )

    render.PushRenderTarget( rt )
    render.OverrideAlphaWriteEnable( true, true )

    local ok, err = drawInColour( wide, tall, drawIcon )
    local alphas, brightnesses, histogram, solidCount = readPixels( wide, tall )
    local tintable = cornersClear( alphas, wide, tall )
    local bounds = inkBounds( alphas, wide, tall )

    if tintable then
        whiten( wide, tall )

        local darkest = percentile( histogram, solidCount, LOW_PERCENTILE )
        local range = percentile( histogram, solidCount, HIGH_PERCENTILE ) - darkest
        if solidCount > 0 and range >= MIN_RANGE * 255 then
            shade( alphas, brightnesses, wide, tall, darkest, range )

        end
    end

    render.OverrideAlphaWriteEnable( false )
    render.PopRenderTarget()

    -- after the pop, an error with the target still pushed would draw the whole screen into it
    if not ok then ErrorNoHalt( "GLEE: drawing an icon failed\n" .. tostring( err ) .. "\n" ) end

    return mat, tintable, bounds

end
