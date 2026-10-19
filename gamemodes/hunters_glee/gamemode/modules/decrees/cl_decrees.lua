--[[
    Decrees: full screen lines in the godlyDecree style, one after another, optionally ending in a choice.

        GAMEMODE:ShowDecree( {
            "Welcome.\nTo the hunt!",
            "Time to choose...",

            choices = { -- optional, side by side, left to right
                { "The Infernal Horde", function() end },
                { "Hunter's Glee", function() net.Start( "..." ) net.SendToServer() end },
            },
            muffle = true, -- optional, muffles the world while it's up
            onClose = function() end, -- optional, runs however it ended
        } )

    Only draws. Anything the server needs to hear about, the caller sends itself.
    A decree shown while another is up waits its turn.
]]

local GAMEMODE = GAMEMODE or GM

local decree = terminator_Extras.glee_Style( "godlyDecree" )

local clickImpatience = 0.30 -- seconds of animation a click skips
local autoAdvanceDelay = 3 -- seconds a landed line stays before the next
local choiceDriftRate = 0.5 -- fraction of the way to the cursor covered per second, while hovered
local choiceReturnTime = 0.1 -- seconds to snap back, once it isn't

local queued = {}
local showing

-- with more than one monitor the cursor can leave the game, and vgui keeps hovering whatever it left from
local function cursorOnScreen()
    if not system.HasFocus() then return false end

    local x, y = input.GetCursorPos()
    return x >= 0 and y >= 0 and x < ScrW() and y < ScrH()

end

-- one choice, its text arrives like a line, and it can only be picked once landed
local function choicePanel( parent, text, onChosen )
    local choice = vgui.Create( "DButton", parent )
    choice:SetText( "" )

    choice.elapsed = 0
    choice.lastThink = CurTime()
    choice.jitterX = 0
    choice.jitterY = 0
    choice.drift = Vector( 0, 0, 0 )
    choice.returnSpeed = 0
    choice.line = decree:NewArrival( "choice", "triumphant" )
    choice.line:SetText( text )

    -- the middle of the text, which is what drifts toward the cursor
    local function textAnchor()
        return choice:GetWide() / 2, choice:GetTall() / 2

    end

    local function hovering()
        return choice:IsHovered() and cursorOnScreen()

    end

    local function updateDrift( delta )
        if hovering() then
            local cursorX, cursorY = choice:CursorPos()
            local anchorX, anchorY = textAnchor()
            local toCursor = Vector( cursorX - anchorX, cursorY - anchorY, 0 )

            choice.drift = choice.drift + ( toCursor - choice.drift ) * math.min( delta * choiceDriftRate, 1 )
            choice.returnSpeed = 0
            return

        end

        local driftLength = choice.drift:Length()
        if driftLength <= 0 then return end

        -- linear, so every snap back takes choiceReturnTime however far it drifted
        if choice.returnSpeed <= 0 then
            choice.returnSpeed = driftLength / choiceReturnTime

        end

        local step = choice.returnSpeed * delta
        if step >= driftLength then
            choice.drift = Vector( 0, 0, 0 )

        else
            choice.drift = choice.drift * ( ( driftLength - step ) / driftLength )

        end
    end

    choice.Think = function()
        decree:Jitter( choice )

        local delta = math.Clamp( CurTime() - choice.lastThink, 0, 0.1 )
        choice.lastThink = CurTime()
        choice.elapsed = choice.elapsed + delta

        updateDrift( delta )

        local appeared, justLanded = choice.line:Update( choice.elapsed )
        for _ = 1, appeared do
            decree:PlaySound( "arrival", math.random( 90, 110 ), CHAN_STATIC )

        end
        if justLanded then
            decree:PlaySound( "landing", math.random( 50, 60 ), CHAN_BODY )

        end
    end

    choice.Paint = function() end

    -- drawn by the parent, so drifting text isn't clipped to this choice. x and y are its position in the parent
    function choice:DrawText( x, y )
        local colorRole = ( self.line.landed and hovering() ) and "boon" or "text"
        local anchorX, anchorY = textAnchor()
        -- Draw takes the top of the first line
        local _, textHeight = terminator_Extras.glee_HudHelpers.MeasureText( text, decree:Font( "choice" ) )
        local topY = anchorY - textHeight / 2

        self.line:Draw( x + anchorX + self.drift.x + self.jitterX, y + topY + self.drift.y + self.jitterY, colorRole )

    end

    choice.DoClick = function()
        if not choice.line.landed then return end
        if not cursorOnScreen() then return end
        onChosen()

    end

    return choice

end

local function showChoices( popup, choices, close )
    local panels = {}
    local picked

    for index, choice in ipairs( choices ) do
        local text, onPicked = choice[1], choice[2]

        local panel = choicePanel( popup, text, function()
            if picked then return end
            picked = true

            if onPicked then onPicked() end
            close()

        end )

        if index < #choices then
            panel:Dock( LEFT )
            panel:SetWide( popup:GetWide() / #choices )

        else
            panel:Dock( FILL )

        end
        panels[index] = panel

    end

    popup.PaintOver = function()
        for _, panel in ipairs( panels ) do
            if not IsValid( panel ) then continue end

            local x, y = panel:GetPos()
            panel:DrawText( x, y )

        end
    end
end

local open

function GAMEMODE:ShowDecree( def )
    if IsValid( showing ) then
        queued[#queued + 1] = def
        return

    end

    open( def )

end

open = function( def )
    termHuntCloseTheShop()

    local me = LocalPlayer()
    if def.muffle and me.SetDSP then
        me:SetDSP( 15, true )

    end

    local popup, width, height = GAMEMODE:CreateScreenFillingPopup()
    popup:SetDraggable( false )
    popup.Paint = function() end
    showing = popup

    -- the panel as the identifier means gmod drops this hook itself once the panel is gone
    hook.Add( "HUDShouldDraw", popup, function() return false end )

    local closed
    local function close()
        if closed then return end
        closed = true

        decree:PlaySound( "arrival", math.random( 90, 110 ), CHAN_STATIC )
        decree:PlaySound( "arrival", math.random( 70, 80 ), CHAN_STATIC )
        decree:PlaySound( "arrival", math.random( 50, 60 ), CHAN_STATIC )

        popup:Remove()

    end

    -- the DFrame's X calls this
    popup.Close = close

    -- here, not in close, so a decree removed any other way still unmuffles and moves the queue on
    function popup:OnRemove()
        if def.muffle and me.SetDSP then
            me:SetDSP( 1, true )

        end

        showing = nil

        if def.onClose then def.onClose() end

        local nextDef = table.remove( queued, 1 )
        if nextDef then open( nextDef ) end

    end

    local lineButton = vgui.Create( "DButton", popup )
    lineButton:Dock( FILL )
    lineButton:SetText( "" )

    lineButton.index = 0
    lineButton.nextPress = 0
    lineButton.nextFlash = 0
    lineButton.lastThink = CurTime()
    lineButton.elapsed = 0
    lineButton.clickPlsGoFaster = 0
    lineButton.jitterX = 0 -- Jitter fills these in, Paint just needs them to exist on frame one
    lineButton.jitterY = 0
    lineButton.line = decree:NewArrival( "huge" )

    local function showLine()
        lineButton.line:SetText( def[lineButton.index] )
        lineButton.elapsed = 0
        lineButton.clickPlsGoFaster = 0
        lineButton.nextAutomatic = nil

    end

    local function nextLine()
        lineButton.index = lineButton.index + 1
        if def[lineButton.index] then showLine() return end

        if def.choices then
            lineButton:Remove()
            showChoices( popup, def.choices, close )
            return

        end

        close()

    end

    lineButton.Think = function()
        if not system.HasFocus() then
            lineButton.nextAutomatic = CurTime() + 5
            lineButton.nextPress = CurTime() + 0.2
            if lineButton.nextFlash < CurTime() then
                lineButton.nextFlash = CurTime() + 1
                system.FlashWindow()

            end

        elseif lineButton.nextAutomatic and lineButton.nextAutomatic < CurTime() then
            nextLine()
            return

        end

        decree:Jitter( lineButton )

        -- a minimised window stops thinking, don't let it come back already materialised
        local delta = math.Clamp( CurTime() - lineButton.lastThink, 0, 0.1 )
        lineButton.lastThink = CurTime()

        lineButton.elapsed = lineButton.elapsed + delta + lineButton.clickPlsGoFaster
        lineButton.clickPlsGoFaster = 0

        local appeared, justLanded = lineButton.line:Update( lineButton.elapsed )
        for _ = 1, appeared do
            decree:PlaySound( "arrival", math.random( 90, 110 ), CHAN_STATIC )

        end

        if justLanded then
            lineButton.nextAutomatic = CurTime() + autoAdvanceDelay
            decree:PlaySound( "landing", math.random( 50, 60 ), CHAN_BODY )

        end
    end

    lineButton.Paint = function()
        local centreX = ( width / 2 ) + lineButton.jitterX
        local topY = ( height / 2 ) + -256 + lineButton.jitterY

        lineButton.line:Draw( centreX, topY )

    end

    lineButton.DoClick = function()
        if not lineButton.line.landed then lineButton.clickPlsGoFaster = lineButton.clickPlsGoFaster + clickImpatience return end
        if lineButton.nextPress > CurTime() then return end
        nextLine()

    end

    -- a decree with no lines goes straight to its choices
    nextLine()

end
