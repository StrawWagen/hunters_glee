local spawnSetVote = {}
local surface_SetAlphaMultiplier = surface.SetAlphaMultiplier
local input = input

local god = terminator_Extras.glee_Style( "god" )
local godLook = god:Settings() -- the strip, the arrival and the paddings, which have no methods
local hudHelpers = terminator_Extras.glee_HudHelpers

-- 1080p pixels
local panelWidth = 300
local panelTopGap = 250

local titleText = "CHOOSE your Misery..."
local urgentSeconds = 5 -- countdown flashes and clicks from here down

net.Receive( "glee_begin_spawnsetvote", function()
    local voteEnd = net.ReadInt( 20 )
    if not voteEnd then return end

    local tblCount = net.ReadInt( 16 )
    if not tblCount then return end

    local options = {}
    for _ = 1, tblCount do
        local currName = net.ReadString()
        local currPrettyName = net.ReadString()
        local currDescription = net.ReadString()
        local data = { name = currName, prettyName = currPrettyName, description = currDescription }
        table.insert( options, data ) -- order matters

    end
    spawnSetVote.voteEnd = voteEnd
    spawnSetVote.options = options
    spawnSetVote.lastVoted = nil

    spawnSetVote:CreateVotePanel()

end )

-- hotkey voters
local voters = {
    "slot1",
    "slot2",
    "slot3",
    "slot4",
    "slot5",
    "slot6",
    "slot7",
    "slot8",
    "slot9",
}

local function isBound( cmd )
    local binding = input.LookupBinding( cmd )
    if not binding then return false end

    local keyCode = input.GetKeyCode( binding )
    return keyCode and keyCode > 0

end

-- Also sets panel.wrappedText and panel.textWidth
local function layoutGodText( panel, text, fontRole, padX, padY )
    local wrapWidth = panel:GetWide() - ( padX * 2 )
    panel.wrappedText = god:Wrap( text, fontRole, wrapWidth )

    local textWidth, textHeight = god:Measure( panel.wrappedText, fontRole )
    panel.textWidth = textWidth
    panel:SetTall( math.ceil( textHeight + ( padY * 2 ) + godLook.shadowOffsetY ) )

end

-- One line of the vote, a torn strip with panel.wrappedText on it, sliding in as the vote opens.
-- The panel needs layoutGodText run on it, and jitterX / jitterY set.
-- state keys the style's tornStrip colors
local function paintGodLine( panel, openedAt, order, state, fontRole, colorRole, w, h )
    local arrival = godLook.arrival
    local arrived = hudHelpers.ArrivalProgress( openedAt, order, arrival )
    local slide = ( 1 - arrived ) * arrival.slideDistance

    surface_SetAlphaMultiplier( arrived )

    local stripWidth = math.min( w, panel.textWidth + ( godLook.textPaddingX * 2 ) )
    hudHelpers.DrawTornStrip( godLook.tornStrip, slide, 0, stripWidth, h, state, panel )

    god:Draw(
        panel.wrappedText, fontRole,
        slide + godLook.textPaddingX + panel.jitterX, godLook.textPaddingY + panel.jitterY,
        colorRole, false
    )

    surface_SetAlphaMultiplier( 1 )

end

function spawnSetVote:CreateVotePanel()
    -- hold to vote bind
    local holdToVote = "+showscores"

    -- plays clacky sounds when you hover buttons
    local pressableThink = GAMEMODE.shopStandards.pressableThink
    -- all done sound!
    local voteDoneSound = "buttons/lever4.wav"

    local keyToVote = input.LookupBinding( holdToVote )
    if keyToVote then
        keyToVote = input.GetKeyCode( keyToVote )

    end

    local hasAllTheVoteKeys = isBound( holdToVote )
    if hasAllTheVoteKeys then
        for _, cmd in ipairs( voters ) do
            if not isBound( cmd ) then
                hasAllTheVoteKeys = false
                break

            end
        end
    end

    local options = spawnSetVote.options
    local voteEnd = spawnSetVote.voteEnd
    local openedAt = CurTime()

    local textPaddingX = godLook.textPaddingX
    local textPaddingY = godLook.textPaddingY
    local lineGap = godLook.lineGap

    if IsValid( GAMEMODE.spawnSetVote_VoteHolder ) then
        GAMEMODE.spawnSetVote_VoteHolder:Close()

    end
    local voteHolder = vgui.Create( "DFrame" )
    GAMEMODE.spawnSetVote_VoteHolder = voteHolder
    spawnSetVote.voteHolder = voteHolder

    local hudPadding = terminator_Extras.defaultHudPaddingFromEdge

    voteHolder:SetSize( glee_sizeScaled( nil, panelWidth ), 0 )
    voteHolder:DockMargin( hudPadding, glee_sizeScaled( nil, panelTopGap ), hudPadding, hudPadding )
    voteHolder:DockPadding( 0, 0, 0, 0 )
    voteHolder:Dock( RIGHT )
    voteHolder:SetTitle( "" )
    voteHolder:SetVisible( true )
    voteHolder:SetDraggable( false )
    voteHolder:ShowCloseButton( false )

    god:PlaySound( "arrival", math.random( 110, 130 ), CHAN_STATIC, 0.3 )

    voteHolder.voteOptions = {}
    function voteHolder:Think()
        if voteEnd < CurTime() then
            self:Remove()
            LocalPlayer():EmitSound( voteDoneSound, 60, 80, 0.5 ) -- surface.playsound has no pitch arg
            return

        end

        if keyToVote and input.IsKeyDown( keyToVote ) then
            for ind, cmd in ipairs( voters ) do
                local clientsSlotKey = input.LookupBinding( cmd )
                if clientsSlotKey then
                    clientsSlotKey = input.GetKeyCode( clientsSlotKey )

                end
                if clientsSlotKey and input.IsKeyDown( clientsSlotKey ) and IsValid( self.voteOptions[ind] ) then
                    if not self.pressedToVote then
                        self.voteOptions[ind]:Vote()
                        self.pressedToVote = true

                    end
                    return

                end
            end
            self.pressedToVote = nil
        end
    end
    function voteHolder:Paint()
    end


    -- countdown on the left, what this is on the right
    local header = vgui.Create( "DPanel", voteHolder, "glee_voteinfo_header" )
    header:Dock( TOP )
    function header:Paint()
        return true

    end

    local countdown = vgui.Create( "DPanel", header, "glee_voteinfo_countdown" )
    countdown:Dock( LEFT )

    local title = vgui.Create( "DPanel", header, "glee_voteinfo_label" )
    title:Dock( FILL )

    -- the title wraps to whatever width the countdown leaves it, so both are measured here
    local titleLine = god:NewArrival( "medium", nil, false )

    function header:PerformLayout( w )
        -- two digits wide, so the title doesn't shift as it counts down
        local countdownWidth, countdownHeight = god:Measure( "00", "large" )
        countdownWidth = countdownWidth + textPaddingX * 2
        countdown:SetWide( countdownWidth )

        title.wrappedText = god:Wrap( titleText, "medium", w - countdownWidth )
        local _, titleHeight = god:Measure( title.wrappedText, "medium" )
        title.textHeight = titleHeight

        -- safe every layout pass, see arrivingText:SetText
        titleLine:SetText( title.wrappedText )

        self:SetTall( math.ceil( math.max( countdownHeight, titleHeight ) + godLook.shadowOffsetY ) )

    end

    title.wrappedText = titleText
    title.textHeight = 0

    function title:Think()
        titleLine:Update( CurTime() - openedAt )

    end

    function title:Paint( _, h )
        titleLine:Draw( 0, ( h - self.textHeight ) / 2 )

        return true

    end


    countdown.countText = "00"
    countdown.jitterX = 0
    countdown.jitterY = 0

    function countdown:Think()
        local untilDoneRaw = voteEnd - CurTime()
        local untilDone = math.ceil( untilDoneRaw )
        untilDone = math.max( untilDone, 0 ) -- no -0 time...

        self.countText = tostring( untilDone )

        local urgent = untilDone <= urgentSeconds
        self.flashing = urgent and untilDoneRaw % 1 < 0.1

        if self.flashing then
            if not self.countdownClick then
                local pit = 100 - ( untilDone * 10 )
                LocalPlayer():EmitSound( GAMEMODE.shopStandards.switchSound, 60, pit, 0.5 ) -- surface.playsound has no pitch arg
                self.countdownClick = true

            end
        else
            self.countdownClick = nil

        end

        if untilDone < urgentSeconds then
            god:Jitter( self )

        end
    end

    function countdown:Paint( w )
        local colorRole = "text"
        if self.flashing then
            colorRole = "urgent"

        end

        god:Draw( self.countText, "large", ( w / 2 ) + self.jitterX, self.jitterY, colorRole )

        return true

    end


    -- all the options!
    for ind, data in ipairs( options ) do
        if ind > 9 then break end -- keyboards only have so many number keys

        local currButton = vgui.Create( "DButton", voteHolder, data.name )
        currButton.name = data.name
        currButton.ind = ind
        currButton.label = ind .. ": " .. data.prettyName
        currButton.wrappedText = currButton.label
        currButton.jitterX = 0
        currButton.jitterY = 0

        voteHolder.voteOptions[ind] = currButton

        currButton:SetText( "" )
        currButton:Dock( TOP )
        currButton:DockMargin( 0, lineGap, 0, 0 )

        local tooltipText = data.description
        local multiplier, escaped, remained = GAMEMODE:GetSpawnsetsEscapeMultiplier( currButton.name )
        multiplier = math.Round( multiplier, 2 )
        currButton.multiplier = multiplier

        local escapeYap
        if escaped == 0 then
            escapeYap = "\nNobody has escaped this."

        elseif escaped == 1 then
            escapeYap = "\n" .. escaped .. " has escaped."

        else
            escapeYap = "\n" .. escaped .. " have escaped."

        end

        local remainYap
        if remained == 0 then
            remainYap = "\nNobody has perished to this."

        elseif remained == 1 then
            remainYap = "\n" .. remained .. " soul has perished."

        else
            remainYap = "\n" .. remained .. " souls have perished."

        end

        tooltipText = table.concat( {
            tooltipText,
            escapeYap,
            remainYap,
            "\n" .. multiplier .. "x escape reward.",
        } )

        currButton:SetTooltip( tooltipText )
        currButton:SetTooltipDelay( 0.1 )

        function currButton:PerformLayout()
            layoutGodText( self, self.label, "small", textPaddingX, textPaddingY )

        end

        local oldBtnThink = currButton.Think
        function currButton:Think()
            oldBtnThink( self )
            pressableThink( self )

            if spawnSetVote.lastVoted == self.name then
                god:Jitter( self )

            else
                self.jitterX = 0
                self.jitterY = 0
                self.nextJitter = nil

            end
        end

        function currButton:Vote()
            if voteEnd < CurTime() then return end
            LocalPlayer():ConCommand( "glee_spawnset_castvote " .. self.name )
            spawnSetVote.lastVoted = self.name
            local mul = math.max( self.multiplier, 0.01 )
            for _ = 1, 2 do
                god:PlaySound( "landing", math.random( 40, 60 ) / mul, CHAN_STATIC, 0.4 )

            end
        end

        function currButton:OnMousePressed( keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = true

        end

        function currButton:OnMouseReleased( keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = nil

            self:Vote()

        end

        function currButton:Paint( w, h )
            local hovered = self:IsHovered()
            if not hovered then
                self.pressed = nil

            end

            local state = "idle"
            local colorRole = "text"

            if spawnSetVote.lastVoted == self.name then
                state = "chosen"
                colorRole = "chosen"

            elseif self.pressed then
                state = "pressed"
                colorRole = "hovered"

            elseif hovered then
                state = "hovered"
                colorRole = "hovered"

            end

            paintGodLine( self, openedAt, self.ind, state, "small", colorRole, w, h )

            return true

        end
    end

    -- make sure people know how to vote!
    local hintYapper = vgui.Create( "DPanel", voteHolder, "glee_voteinfo_hintyapper" )
    hintYapper:DockMargin( 0, lineGap, 0, 0 )
    hintYapper:Dock( TOP )

    hintYapper.hint = ""
    hintYapper.wrappedText = ""
    hintYapper.jitterX = 0
    hintYapper.jitterY = 0

    -- arrives after the last option
    local hintOrder = math.min( #options, 9 ) + 1

    function hintYapper:PerformLayout()
        layoutGodText( self, self.hint, "small", textPaddingX, textPaddingY )

    end

    function hintYapper:Think()
        if spawnSetVote.lastVoted then
            self:Remove()
            return

        end

        god:Jitter( self )

        local hint
        local hintStart = "(Open chat"
        local hintEnd = " to vote.)"
        local valid, phrase = GAMEMODE:TranslatedBind( holdToVote )
        if hasAllTheVoteKeys and valid then -- some doofus is gonna have this unbound
            hint = hintStart .. " or press a number while holding " .. string.upper( phrase ) .. hintEnd

        else
            hint = hintStart .. hintEnd

        end

        if hint ~= self.hint then
            self.hint = hint
            self:InvalidateLayout()

        end
    end

    function hintYapper:Paint( w, h )
        paintGodLine( self, openedAt, hintOrder, "idle", "small", "text", w, h )

        return true

    end
end

local chatWasOpened

hook.Add( "StartChat", "glee_rtmdetect_chatopening", function()
    chatWasOpened = true

end )

hook.Add( "huntersglee_cl_displayhint_poststack", "glee_rtmhint", function( me )
    if not GetGlobal2Bool( "glee_pleaseshow_rtmtutorialhint", false ) then return end

    if not chatWasOpened then
        local valid, openChatPhrase = GAMEMODE:TranslatedBind( "say" )
        if not valid then
            valid, openChatPhrase = GAMEMODE:TranslatedBind( "messagemode" )

        end
        if not valid then
            valid, openChatPhrase = GAMEMODE:TranslatedBind( "messagemode2" )

        end
        if not valid then chatWasOpened = true return end

        return true, "You're ready for a new Misery, maybe even a real challenge...\nPress " .. openChatPhrase .. " to open the chat."

    elseif not me:GetNW2Bool( "glee_hasrtm_voted", false ) then
        return true, "You're ready for a real challenge.\nBegin a Misery vote.\nType !rtm in chat."

    end
end )
