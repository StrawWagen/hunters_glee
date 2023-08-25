
AddCSLuaFile()

if not CLIENT then return end

local color_black = Color( 0, 0, 0 )

function surface.drawShadowedTextBetter( textInitial, font, color, posx, posy, doCenter )
    local brokenUp = string.Explode( "\n", textInitial, false )
    local totalHeight = 0
    for _, text in ipairs( brokenUp ) do
        if doCenter == nil then
            doCenter = true

        end

        surface.SetFont( font )
        local centeringOffset = 0
        local width, height = surface.GetTextSize( text )
        if doCenter then
            centeringOffset = -( width * 0.5 )

        end
        local shadowAlpha = 255
        if color.a < 255 or color ~= color_white then
            shadowAlpha = color.a / 4

        end
        local shadowColor = ColorAlpha( color_black, shadowAlpha )

        surface.SetTextColor( shadowColor )
        surface.SetTextPos( posx + centeringOffset + 2.5, posy + 2 + totalHeight )
        surface.DrawText( text )

        surface.SetTextColor( color )
        surface.SetTextPos( posx + centeringOffset, posy + totalHeight )
        surface.DrawText( text )

        totalHeight = totalHeight + height * 1.2

    end
end