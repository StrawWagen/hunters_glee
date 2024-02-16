
AddCSLuaFile()

if not CLIENT then return end

local color_black = Color( 0, 0, 0 )

local string_Explode = string.Explode
local ipairs = ipairs
local CurTime = CurTime
local table_Count = table.Count
local math_abs = math.abs

local cachedShadowColors = {}
local cachedShadowColorsLastUse = {}

local surface_SetFont = surface.SetFont
local surface_GetTextSize = surface.GetTextSize
local surface_SetTextColor = surface.SetTextColor
local surface_SetTextPos = surface.SetTextPos
local surface_DrawText = surface.DrawText

function surface.drawShadowedTextBetter( textInitial, font, color, posx, posy, doCenter )
    local brokenUp = string_Explode( "\n", textInitial, false )
    local totalHeight = 0
    for _, text in ipairs( brokenUp ) do
        if doCenter == nil then
            doCenter = true

        end

        surface_SetFont( font )
        local centeringOffset = 0
        local width, height = surface_GetTextSize( text )
        if doCenter then
            centeringOffset = -( width * 0.5 )

        end
        local shadowAlpha = 255
        if color.a < 255 or color ~= color_white then
            shadowAlpha = color.a / 4

        end

        local cacheKey = font .. tostring( color )
        local shadowColor = cachedShadowColors[cacheKey]
        cachedShadowColorsLastUse[cacheKey] = CurTime()
        if not shadowColor then
            shadowColor = ColorAlpha( color_black, shadowAlpha )
            cachedShadowColors[cacheKey] = shadowColor

        end

        surface_SetTextColor( shadowColor )
        surface_SetTextPos( posx + centeringOffset + 2.5, posy + 2 + totalHeight )
        surface_DrawText( text )

        surface_SetTextColor( color )
        surface_SetTextPos( posx + centeringOffset, posy + totalHeight )
        surface_DrawText( text )

        totalHeight = totalHeight + height * 1.2

    end
end

local oldCount = 0

timer.Create( "glee_shadowedfunc_cleanupcolors", 1, 0, function()
    local newCount = table_Count( cachedShadowColors )
    if newCount == oldCount then return end
    oldCount = newCount

    local cur = CurTime()

    for cacheKey, _ in pairs( cachedShadowColors ) do
        local lastUsed = cachedShadowColorsLastUse[cacheKey]
        if math_abs( cur - lastUsed ) > 1 then
            cachedShadowColorsLastUse[cacheKey] = nil
            cachedShadowColors[cacheKey] = nil

        end
    end
end )