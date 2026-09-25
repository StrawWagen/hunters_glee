--[[------------------------------------
    Builds every registered style, once per registered scale, into the tables handles
    read. Styles are data, see cl_style.lua; this is the only place that reads them.

    Runs once every style is registered, then again on glee_rebuildfonts, when
    cl_huntersglee_highcontrast changes, and when a style or scale registers late.
    glee_hud_stylesrebuilt runs after each build.

    A font spec is a surface.CreateFont table with three differences:

        size        1080p pixels, scaled to the screen and the scale, and multiplied by
                    sizeMul. A function( scale ) gives final pixels instead, skipping all that.
        sizeMul     overrides the style's sizeMul, for this font only
        any value   a function is called at build time, for anything the style file
                    can't know yet

    Unset, font and weight come from the style, and antialias is on.
--]]-------------------------------------

local styles = terminator_Extras.glee_HudStyles
local rootName = terminator_Extras.glee_RootStyleName

-- styleName -> scaleName -> built style. Emptied and refilled by every build, never replaced
terminator_Extras.glee_BuiltStyles = terminator_Extras.glee_BuiltStyles or {}
local builtStyles = terminator_Extras.glee_BuiltStyles

terminator_Extras.glee_HudScales = terminator_Extras.glee_HudScales or {}
local scales = terminator_Extras.glee_HudScales

local highContrastVar = CreateClientConVar( "cl_huntersglee_highcontrast", 0, true, false, "Draw glee's HUD and menus in high contrast?", 0, 1 )

local roleTables = {
    colors  = true,
    fonts   = true,
    metrics = true,
    sounds  = true,
}

-- instructions to the build, never fields of the built style
local notFields = {
    inherits     = true,
    scaled       = true,
    highContrast = true,
}

-- a 2.5px shadow rounded to 3 is a different look
local fractionalMetrics = {
    shadowOffsetX = true,
    shadowOffsetY = true,
}


-- Copies fields onto built, role tables merged into fresh copies, so the style's own
-- tables are never written to
local function layerOver( built, fields )
    for key, value in pairs( fields ) do
        if notFields[key] then continue end

        if roleTables[key] then
            local merged = {}
            for role, entry in pairs( built[key] or {} ) do
                merged[role] = entry

            end
            for role, entry in pairs( value ) do
                merged[role] = entry

            end
            value = merged

        end

        built[key] = value

    end
end

-- The root first, styleName last. A style naming no parent has the root's
local function inheritanceChain( styleName )
    local root = styles[rootName]
    local chain = {}
    local seen = {}
    local name = styleName

    while name do
        local style = styles[name]
        if not style then
            ErrorNoHaltWithStack( "glee_hud: style \"" .. styleName .. "\" inherits \"" .. name .. "\", which isn't registered\n" )
            break

        end
        if seen[name] then
            ErrorNoHaltWithStack( "glee_hud: style \"" .. styleName .. "\" inherits itself, through \"" .. name .. "\"\n" )
            break

        end

        seen[name] = true
        table.insert( chain, 1, style )

        name = style.inherits
        if not name and style ~= root then
            name = rootName

        end
    end

    -- a broken chain still gets every field, from the root
    if chain[1] ~= root then
        table.insert( chain, 1, root )

    end

    return chain

end

local function scaleMetrics( metrics, scale )
    local scaled = {}

    for name, pixels1080 in pairs( metrics ) do
        local pixels = glee_sizeScaledExact( nil, pixels1080 ) * scale
        if not fractionalMetrics[name] then
            pixels = math.Round( pixels )

        end
        scaled[name] = pixels

    end

    return scaled

end

-- Returns the size it was made at
local function createFont( built, fontName, spec )
    local size = spec.size

    if isfunction( size ) then
        size = size( built.scale )

    else
        size = glee_sizeScaled( nil, size ) * ( spec.sizeMul or built.sizeMul ) * built.scale

    end

    local fontData = {
        font      = built.fontName,
        size      = size,
        weight    = built.fontWeight,
        antialias = true,
    }

    for key, value in pairs( spec ) do
        if key == "size" or key == "sizeMul" then continue end

        if isfunction( value ) then
            value = value()

        end
        fontData[key] = value

    end

    surface.CreateFont( fontName, fontData )

    return size

end

-- Swaps built.fonts' specs for font names, and fills built.fontSizes.
-- A font this system didn't make has a name but no size
local function buildFonts( built )
    local fontNames = {}
    local fontSizes = {}

    for fontRole, spec in pairs( built.fonts or {} ) do
        if isstring( spec ) then
            fontNames[fontRole] = spec

        else
            local fontName = "glee_" .. built.styleName .. "_" .. built.scaleName .. "_" .. fontRole
            fontSizes[fontRole] = createFont( built, fontName, spec )
            fontNames[fontRole] = fontName

        end
    end

    built.fonts = fontNames
    built.fontSizes = fontSizes

end

local function buildStyle( styleName, scaleName, scale )
    local function px( pixels1080 )
        return math.Round( glee_sizeScaledExact( nil, pixels1080 ) * scale )

    end

    local highContrast = highContrastVar:GetBool()
    local chain = inheritanceChain( styleName )
    local built = {}

    for _, style in ipairs( chain ) do
        layerOver( built, style )

        if style.scaled then
            layerOver( built, style.scaled( px ) )

        end
    end

    -- after the whole chain, so no style's normal look can undo a parent's high contrast
    if highContrast then
        for _, style in ipairs( chain ) do
            if style.highContrast then
                layerOver( built, style.highContrast )

            end
        end
    end

    built.styleName = styleName
    built.scaleName = scaleName
    built.scale = scale
    built.highContrast = highContrast
    built.metrics = scaleMetrics( built.metrics, scale )
    buildFonts( built )

    return built

end

local function buildAllStyles()
    table.Empty( builtStyles )

    for styleName in pairs( styles ) do
        local byScale = {}
        builtStyles[styleName] = byScale

        for scaleName, getScale in pairs( scales ) do
            byScale[scaleName] = buildStyle( styleName, scaleName, getScale() )

        end
    end

    hook.Run( "glee_hud_stylesrebuilt" )

end

-- For anything registering after the first build. Many registrations, one build
function terminator_Extras.glee_RebuildStylesSoon()
    timer.Create( "glee_hud_rebuildstyles", 0, 1, buildAllStyles )

end

--[[---------------------------------------------------------
    terminator_Extras.glee_RegisterScale
    Adds a scale every style gets built at, like the gui scale the menus follow.
    @param scaleName: What handles and panels will ask for it by.
    @param getScale: Returns the multiplier, read on every build. 1 is 1080p size.
    @return: None
--]]---------------------------------------------------------
function terminator_Extras.glee_RegisterScale( scaleName, getScale )
    scales[scaleName] = getScale

    -- at once, not soon, so a panel made straight after can already draw at it
    buildAllStyles()

end

-- everything drawn with no scale named, and anything that must stay readable whatever
-- the gui scale is set to
scales.fixed = function() return 1 end

buildAllStyles()

hook.Add( "glee_rebuildfonts", "glee_rebuild_hudstyles", buildAllStyles )

cvars.AddChangeCallback( "cl_huntersglee_highcontrast", buildAllStyles, "glee_rebuild_hudstyles" )
