--[[------------------------------------
    How big a panel's contents want to be, for a parent sizing itself around them.

    A panel that knows says so through GetContentWidth and GetContentHeight. Anything
    else is taken at its current size.
--]]-------------------------------------

function terminator_Extras.glee_ContentWidth( panel )
    if panel.GetContentWidth then return panel:GetContentWidth() end

    return panel:GetWide()

end

function terminator_Extras.glee_ContentHeight( panel )
    if panel.GetContentHeight then return panel:GetContentHeight() end

    return panel:GetTall()

end

local contentWidth = terminator_Extras.glee_ContentWidth
local contentHeight = terminator_Extras.glee_ContentHeight

local stackingDocks = {
    [TOP]    = true,
    [BOTTOM] = true,
    [FILL]   = true,
}

--[[---------------------------------------------------------
    terminator_Extras.glee_DockedContentSize
    The size a panel's docked children come to, their margins in, its padding out.
    @param panel: The parent.
    @return: The widest child, and the children stacked. Only TOP, BOTTOM and FILL
        children count, and a FILL child's height is what it wants, not what it's given.
--]]---------------------------------------------------------
function terminator_Extras.glee_DockedContentSize( panel )
    local widest = 0
    local stacked = 0

    for _, child in ipairs( panel:GetChildren() ) do
        if not stackingDocks[child:GetDock()] then continue end
        if not child:IsVisible() then continue end

        local left, top, right, bottom = child:GetDockMargin()
        widest = math.max( widest, contentWidth( child ) + left + right )
        stacked = stacked + contentHeight( child ) + top + bottom

    end

    return widest, stacked

end
