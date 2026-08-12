
if not CLIENT then return end

local string_Explode = string.Explode
local ipairs = ipairs

local surface_SetFont = surface.SetFont
local surface_GetTextSize = surface.GetTextSize
local surface_SetTextColor = surface.SetTextColor
local surface_SetTextPos = surface.SetTextPos
local surface_DrawText = surface.DrawText

local defShadowColor = Color( 0, 0, 0 )

function surface.drawShadowedTextBetterData( data )
    local brokenUp = string_Explode( "\n", data.text, false )
    local totalHeight = 0
    local doCenter = data.doCenter
    if doCenter == nil then
        doCenter = true

    end
    for _, text in ipairs( brokenUp ) do

        surface_SetFont( data.font )
        local centeringOffset = 0
        local width, height = surface_GetTextSize( text )
        if doCenter then
            centeringOffset = -( width * 0.5 )

        end

        local shadowColor

        if data.shadowColor then -- use data.shadowColor if you think the default shadow is poo
            shadowColor = data.shadowColor

        else
            -- only do auto shadow color/fading for the default black shadow
            shadowColor = defShadowColor
            local shadowAlpha = data.shadowAlpha or 255
            if data.textColor.a < 255 or data.textColor ~= color_white then
                shadowAlpha = data.textColor.a / 4

            end
            shadowColor.a = shadowAlpha

        end

        local shadowOffsetX = data.shadowOffsetX or 2.5
        local shadowOffsetY = data.shadowOffsetY or 2

        local textX = data.posX + centeringOffset
        local textY = data.posY + totalHeight

        local shadowX = textX + shadowOffsetX
        local shadowY = textY + shadowOffsetY

        surface_SetTextColor( shadowColor )
        surface_SetTextPos( shadowX, shadowY )
        surface_DrawText( text )

        surface_SetTextColor( data.textColor )
        surface_SetTextPos( textX, textY )
        surface_DrawText( text )

        totalHeight = totalHeight + height * 1.2

    end
end

local theDataTbl = {}

function surface.drawShadowedTextBetter( textInitial, font, textColor, posX, posY, doCenter )
    theDataTbl.text         = textInitial
    theDataTbl.font         = font
    theDataTbl.textColor    = textColor
    theDataTbl.posX         = posX
    theDataTbl.posY         = posY
    theDataTbl.doCenter     = doCenter
    surface.drawShadowedTextBetterData( theDataTbl )

end