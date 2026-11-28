--[[------------------------------------
    Icons in the hud's colour, whatever colours they came in.

        local icon = terminator_Extras.glee_MaterialIcon( "entities/item_battery.png" )

        hook.Add( "HUDPaint", "my_icon", function()
            icon:Bake()

        end )

        -- then in a panel's Paint, in its content colour
        icon:Draw( x, y, w, h, contentColor )

    Baking is glee_hud/cl_iconbake.lua's, see there for how the colour comes out of them.
    This file picks what to bake, materials, and each weapon's best picture of itself.

    Each bakes once, the first time it's asked, and is kept forever, a render target can't be freed.
--]]-------------------------------------

local RT_TALL = 128 -- every baked pixel is read back, keep it near the size they're drawn
local MAX_ASPECT = 4 -- anything wider is squashed
local WEAPON_ASPECT = 2 -- weapon selection boxes are about twice as wide as they are tall


-- Baked icons ---------------------------------------------------------------

-- _original is a material drawn as it is if the bake fills its corners, nil to always tint.
-- _trim crops it to what was drawn, for glyphs, whose box has room above and below for other letters
local bakedIcon = {}
bakedIcon.__index = bakedIcon

local function newBakedIcon( key, wide, tall, drawIcon, original )
    return setmetatable( {
        _key = key,
        _wide = wide,
        _tall = tall,
        _aspect = wide / tall,
        _drawIcon = drawIcon,
        _original = original,
        _baked = false,
    }, bakedIcon )

end

function bakedIcon:Bake()
    if self._baked then return end
    self._baked = true

    local tinted, tintable, bounds = terminator_Extras.glee_BakeIcon( self._key, self._wide, self._tall, self._drawIcon )
    self._tinted = tinted
    self._tintable = tintable or self._original == nil
    self._ink = bounds

    if self._trim and bounds then
        self._bounds = bounds
        self._aspect = ( self._wide * ( bounds.u1 - bounds.u0 ) ) / ( self._tall * ( bounds.v1 - bounds.v0 ) )

    end
end

-- Width over height
function bakedIcon:Aspect()
    return self._aspect

end

-- Where its picture starts, past any see through margin, as fractions of the size it's drawn at
function bakedIcon:InkTopLeft()
    local ink = self._ink
    if not ink or self._bounds then return 0, 0 end -- trimmed already starts at its ink

    return ink.u0, ink.v0

end

-- color is already faded, an icon that can't be tinted only takes its alpha
function bakedIcon:Draw( x, y, w, h, color )
    if not self._tinted then return end -- not baked yet, or the bake errored

    if self._tintable then
        surface.SetDrawColor( color )
        surface.SetMaterial( self._tinted )

    else
        surface.SetDrawColor( 255, 255, 255, color.a )
        surface.SetMaterial( self._original )

    end

    local bounds = self._bounds
    if bounds then
        surface.DrawTexturedRectUV( x, y, w, h, bounds.u0, bounds.v0, bounds.u1, bounds.v1 )

    else
        surface.DrawTexturedRect( x, y, w, h )

    end
end


-- Materials -----------------------------------------------------------------

local materialIcons = {} -- false for paths that don't load

--[[---------------------------------------------------------
    terminator_Extras.glee_MaterialIcon
    @param path: A material path, like "entities/item_battery.png".
    @return: The icon, the same one for the same path. nil if it doesn't load.
--]]---------------------------------------------------------
function terminator_Extras.glee_MaterialIcon( path )
    local icon = materialIcons[path]
    if icon ~= nil then return icon or nil end

    local mat = Material( path, "smooth" )
    if mat:IsError() then
        materialIcons[path] = false
        return

    end

    local aspect = math.Clamp( mat:Width() / mat:Height(), 1 / MAX_ASPECT, MAX_ASPECT )
    local wide = math.Round( RT_TALL * aspect )

    icon = newBakedIcon( "mat:" .. path, wide, RT_TALL, function( w, h )
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.SetMaterial( mat )
        surface.DrawTexturedRect( 0, 0, w, h )

    end, mat )

    materialIcons[path] = icon
    return icon

end


-- Lua weapons ---------------------------------------------------------------

-- Every SWEP inherits base's DrawWeaponSelection, drawing "SWEP" unless it set its own WepSelectIcon
local function drawsOwnSelection( wep )
    local drawSelection = wep.DrawWeaponSelection
    if not drawSelection then return false end

    local base = weapons.GetStored( "weapon_base" )
    if not base or drawSelection ~= base.DrawWeaponSelection then return true end

    return wep.WepSelectIcon ~= base.WepSelectIcon

end

-- Without the bounce, and without the info box, that draws beside it
local function drawSelection( wep, wide, tall )
    local bounce, infoBox = wep.BounceWeaponIcon, wep.DrawWeaponInfoBox
    wep.BounceWeaponIcon = false
    wep.DrawWeaponInfoBox = false

    local ok, err = pcall( wep.DrawWeaponSelection, wep, 0, 0, wide, tall, 255 )

    wep.BounceWeaponIcon = bounce
    wep.DrawWeaponInfoBox = infoBox
    if not ok then error( err, 0 ) end

end

local selectionIcons = {}

-- Baked from the one the local player holds, it has to be held the first time it's baked
local function selectionIcon( class )
    local icon = selectionIcons[class]
    if icon then return icon end

    icon = newBakedIcon( "wep:" .. class, RT_TALL * WEAPON_ASPECT, RT_TALL, function( w, h )
        local wep = LocalPlayer():GetWeapon( class )
        if not IsValid( wep ) then return end

        -- some draw a placeholder the first time while they set themselves up, M9K's base does,
        -- and this is baked once, so the first draw is thrown away
        drawSelection( wep, w, h )
        render.Clear( 0, 0, 0, 0 )
        drawSelection( wep, w, h )

    end )

    selectionIcons[class] = icon
    return icon

end


-- Engine weapons ------------------------------------------------------------

-- The engine draws its weapons' selection icons as a character of a scheme font, named in the weapon's script.
-- Lua can't read the scheme, so these are the scheme fonts we know the face of.
-- Any other draws as Arial, a wrong letter's worse than the spawn icon
local hl2GlyphFonts = {
    WeaponIcons = true,
    WeaponIconsSelected = true,
    WeaponIconsSmall = true,
}

local GLYPH_FONT = "glee_weaponGlyphs"
surface.CreateFont( GLYPH_FONT, {
    font = "HalfLife2",
    size = RT_TALL,
    antialias = true,
} )

-- A texture data entry's character, nil unless it's a glyph in a font we know
local function knownGlyph( entry )
    if not entry or not hl2GlyphFonts[entry.font] or entry.character == nil then return end

    return tostring( entry.character )

end

-- Every key comes back lowercase
local function readTextureData( path )
    local raw = file.Read( path, "GAME" )
    if not raw then return end

    raw = string.gsub( raw, "%[%$[%w_]+%]", "" ) -- platform conditionals, like [$WIN32]
    return util.KeyValuesToTable( raw ).texturedata

end

-- Engine weapons whose script lua can't see, the engine still reads it.
-- Their WeaponIcons character
local hiddenGlyphs = {
    weapon_slam = "o",
}

-- The weapon script's selection character
local function scriptGlyph( class )
    if hiddenGlyphs[class] then return hiddenGlyphs[class] end

    local textureData = readTextureData( "scripts/" .. class .. ".txt" )
    return knownGlyph( textureData and textureData.weapon )

end

-- The engine hud's own pickup icons, the battery and the health kit
local hudTextures
local function hudGlyph( class )
    hudTextures = hudTextures or readTextureData( "scripts/hud_textures.txt" ) or {}
    return knownGlyph( hudTextures[class] )

end

local glyphIcons = {} -- false for classes with no glyph

local function glyphIcon( class )
    local icon = glyphIcons[class]
    if icon ~= nil then return icon or nil end

    local glyph = scriptGlyph( class ) or hudGlyph( class )
    if not glyph then
        glyphIcons[class] = false
        return

    end

    surface.SetFont( GLYPH_FONT )
    local wide, tall = surface.GetTextSize( glyph )

    icon = newBakedIcon( "glyph:" .. class, wide, tall, function()
        draw.SimpleText( glyph, GLYPH_FONT, 0, 0, color_white )

    end )
    icon._trim = true

    glyphIcons[class] = icon
    return icon

end


-- Picking one ---------------------------------------------------------------

local function spawnIcon( class )
    local stored = weapons.GetStored( class )
    local path = stored and stored.IconOverride or "entities/" .. class .. ".png"

    return terminator_Extras.glee_MaterialIcon( path )

end

--[[---------------------------------------------------------
    terminator_Extras.glee_WeaponIcon
    The first of these the weapon has:
        SWEP.glee_NoticePickupIcon, a material path, for weapons whose selection art doesn't suit the hud. false has no pickup notice at all.
        Its own DrawWeaponSelection, once the local player has held one.
        The engine's selection icon, for engine weapons, or its pickup icon, for engine items.
        Its spawn icon.
    @param class: The weapon's class.
    @return: The icon, nil if it has none of them.
--]]---------------------------------------------------------
function terminator_Extras.glee_WeaponIcon( class )
    local stored = weapons.GetStored( class )
    local override = stored and stored.glee_NoticePickupIcon
    if override then return terminator_Extras.glee_MaterialIcon( override ) end

    if selectionIcons[class] then return selectionIcons[class] end

    local wep = LocalPlayer():GetWeapon( class )
    if IsValid( wep ) and drawsOwnSelection( wep ) then return selectionIcon( class ) end

    -- a lua weapon has no script, no need to look
    local glyph = not stored and glyphIcon( class )
    return glyph or spawnIcon( class )

end
