
AddCSLuaFile()

if not CLIENT then return end

local string_Explode = string.Explode
local ipairs = ipairs

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

        surface_SetTextColor( 0, 0, 0, shadowAlpha )
        surface_SetTextPos( posx + centeringOffset + 2.5, posy + 2 + totalHeight )
        surface_DrawText( text )

        surface_SetTextColor( color )
        surface_SetTextPos( posx + centeringOffset, posy + totalHeight )
        surface_DrawText( text )

        totalHeight = totalHeight + height * 1.2

    end
end
