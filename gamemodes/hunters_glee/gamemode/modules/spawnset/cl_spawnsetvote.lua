local spawnSetVote = {}
local surface_SetAlphaMultiplier = surface.SetAlphaMultiplier
local input = input

local godHud = terminator_Extras.godHud
local decrees = godHud.decrees

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

-- Also sets panel.wrappedText and panel.textWidth
local function layoutGodText( panel, text, font, padX, padY )
    local wrapWidth = panel:GetWide() - ( padX * 2 )
    panel.wrappedText = terminator_Extras.glee_HL2Hud.WrapText( text, font, wrapWidth )

    local textWidth, textHeight = godHud.MeasureText( panel.wrappedText, font )
    panel.textWidth = textWidth
    panel:SetTall( math.ceil( textHeight + ( padY * 2 ) + godHud.shadowOffsetY ) )

end

local function newTextData( font, doCenter )
    return {
        font = font,
        doCenter = doCenter,
        shadowColor = decrees.shadowColor,
        shadowOffsetX = godHud.shadowOffsetX,
        shadowOffsetY = godHud.shadowOffsetY,
    }
end

function spawnSetVote:CreateVotePanel()
    -- hold to vote bind
    local holdToVote = "+showscores"

    -- plays clacky sounds when you hover buttons
    local pressableThink = GAMEMODE.shopStandards.pressableThink
    -- all done sound!
    local voteDoneSound = "buttons/lever4.wav"

    local hasAllTheVoteKeys = true
    local keyToVote = input.LookupBinding( holdToVote )
    if keyToVote then
        keyToVote = input.GetKeyCode( keyToVote )
        if keyToVote and keyToVote > 0 then
            for _, cmd in ipairs( voters ) do
                local clientsSlotKey = input.LookupBinding( cmd )
                if clientsSlotKey then
                    clientsSlotKey = input.GetKeyCode( clientsSlotKey )
                    if not clientsSlotKey or clientsSlotKey <= 0 then
                        hasAllTheVoteKeys = false
                        break

                    end
                else
                    hasAllTheVoteKeys = false
                    break

                end
            end
        else
            hasAllTheVoteKeys = false

        end
    else
        hasAllTheVoteKeys = false

    end

    local options = spawnSetVote.options
    local voteEnd = spawnSetVote.voteEnd
    local openedAt = CurTime()

    local arrival = decrees.arrival
    local boxPaddingX = decrees.boxPaddingX
    local boxPaddingY = decrees.boxPaddingY
    local boxGap = decrees.boxGap

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

    godHud.PlaySound( godHud.textArrivalSounds, math.random( 110, 130 ), CHAN_STATIC, 0.3 )

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
    function header:PerformLayout( w )
        -- two digits wide, so the title doesn't shift as it counts down
        local countdownWidth, countdownHeight = godHud.MeasureText( "00", decrees.fonts.large )
        countdownWidth = countdownWidth + boxPaddingX * 2
        countdown:SetWide( countdownWidth )

        title.wrappedText = terminator_Extras.glee_HL2Hud.WrapText( titleText, decrees.fonts.medium, w - countdownWidth )
        local _, titleHeight = godHud.MeasureText( title.wrappedText, decrees.fonts.medium )
        title.textHeight = titleHeight

        self:SetTall( math.ceil( math.max( countdownHeight, titleHeight ) + godHud.shadowOffsetY ) )

    end

    local titleGhostSettings = decrees.ghosts.medium
    local titleGhostData = newTextData( decrees.fonts.medium, false )
    -- copies, DrawGhosts writes their alpha
    titleGhostData.textColor = ColorAlpha( decrees.textColor, 255 )
    titleGhostData.shadowColor = ColorAlpha( decrees.shadowColor, 255 )

    local titleData = newTextData( decrees.fonts.medium, false )
    titleData.textColor = decrees.textColor

    title.wrappedText = titleText
    title.textHeight = 0
    title.ghosts = godHud.BuildGhosts( titleGhostSettings )
    title.materialised = 0

    function title:Think()
        if not self.ghosts then return end

        local elapsed = CurTime() - openedAt
        godHud.AdvanceGhosts( self.ghosts, elapsed, titleGhostSettings )
        self.materialised = godHud.GhostsMaterialised( elapsed, titleGhostSettings )

        if self.materialised >= 1 then
            self.ghosts = nil

        end
    end

    function title:Paint( _, h )
        local leftX = 0
        local topY = ( h - self.textHeight ) / 2

        titleGhostData.font = decrees.fonts.medium
        titleGhostData.text = self.wrappedText
        titleData.font = decrees.fonts.medium
        titleData.text = self.wrappedText

        if self.ghosts then
            godHud.DrawGhosts( self.ghosts, titleGhostSettings, titleGhostData, leftX, topY )

        end

        titleData.posX = leftX
        titleData.posY = topY

        -- squared, so it stays hidden while the ghosts are spread out
        surface_SetAlphaMultiplier( self.materialised ^ 2 )
        surface.drawShadowedTextBetterData( titleData )
        surface_SetAlphaMultiplier( 1 )

        return true

    end


    local countdownData = newTextData( decrees.fonts.large, true )
    countdownData.text = "00"

    countdown.jitterX = 0
    countdown.jitterY = 0

    function countdown:Think()
        local untilDoneRaw = spawnSetVote.voteEnd - CurTime()
        local untilDone = math.ceil( untilDoneRaw )
        untilDone = math.max( untilDone, 0 ) -- no -0 time...

        countdownData.text = tostring( untilDone )

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
            godHud.DoJitter( self )

        end
    end

    function countdown:Paint( w )
        if self.flashing then
            countdownData.textColor = decrees.textUrgentColor

        else
            countdownData.textColor = decrees.textColor

        end

        countdownData.font = decrees.fonts.large
        countdownData.posX = ( w / 2 ) + self.jitterX
        countdownData.posY = self.jitterY
        surface.drawShadowedTextBetterData( countdownData )

        return true

    end


    -- all the options!
    for ind, data in ipairs( options ) do
        if ind > 9 then break end -- keyboards only have so many number keys

        local currButton = vgui.Create( "DButton", voteHolder, data.name )
        currButton.name = data.name
        currButton.prettyName = data.prettyName
        currButton.description = data.description
        currButton.ind = ind
        currButton.label = ind .. ": " .. data.prettyName
        currButton.wrappedText = currButton.label
        currButton.jitterX = 0
        currButton.jitterY = 0

        voteHolder.voteOptions[ind] = currButton

        currButton:SetText( "" )
        currButton:Dock( TOP )
        currButton:DockMargin( 0, boxGap, 0, 0 )

        local optionData = newTextData( decrees.fonts.small, false )

        local tooltipText = currButton.description
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
            layoutGodText( self, self.label, decrees.fonts.small, boxPaddingX, boxPaddingY )

        end

        local oldBtnThink = currButton.Think
        function currButton:Think()
            oldBtnThink( self )
            pressableThink( self )

            if spawnSetVote.lastVoted == self.name then
                godHud.DoJitter( self )

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
                godHud.PlaySound( godHud.textLandingSounds, math.random( 40, 60 ) / mul, CHAN_STATIC, 0.4 )

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
            local textColor = decrees.textColor

            if spawnSetVote.lastVoted == self.name then
                state = "chosen"
                textColor = decrees.textChosenColor

            elseif self.pressed then
                state = "pressed"
                textColor = decrees.textHoveredColor

            elseif hovered then
                state = "hovered"
                textColor = decrees.textHoveredColor

            end

            local arrived = godHud.ArrivalProgress( openedAt, self.ind, arrival )
            local slide = ( 1 - arrived ) * arrival.slideDistance

            surface_SetAlphaMultiplier( arrived )

            godHud.DrawBlot( decrees.blot, slide, 0, math.min( w, self.textWidth + ( boxPaddingX * 2 ) ), h, state )

            optionData.text = self.wrappedText
            optionData.textColor = textColor
            optionData.font = decrees.fonts.small
            optionData.posX = slide + boxPaddingX + self.jitterX
            optionData.posY = boxPaddingY + self.jitterY
            surface.drawShadowedTextBetterData( optionData )

            surface_SetAlphaMultiplier( 1 )

            return true

        end
    end

    -- make sure people know how to vote!
    local hintYapper = vgui.Create( "DPanel", voteHolder, "glee_voteinfo_hintyapper" )
    hintYapper:DockMargin( 0, boxGap, 0, 0 )
    hintYapper:Dock( TOP )

    local hintData = newTextData( decrees.fonts.small, false )
    hintData.textColor = decrees.textColor
    hintYapper.hint = ""
    hintYapper.wrappedText = ""
    hintYapper.jitterX = 0
    hintYapper.jitterY = 0

    -- arrives after the last option
    local hintOrder = math.min( #options, 9 ) + 1

    function hintYapper:PerformLayout()
        layoutGodText( self, self.hint, decrees.fonts.small, boxPaddingX, boxPaddingY )

    end

    function hintYapper:Think()
        if spawnSetVote.lastVoted then
            self:Remove()
            return

        end

        godHud.DoJitter( self )

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
        local arrived = godHud.ArrivalProgress( openedAt, hintOrder, arrival )
        local slide = ( 1 - arrived ) * arrival.slideDistance

        surface_SetAlphaMultiplier( arrived )

        godHud.DrawBlot( decrees.blot, slide, 0, math.min( w, self.textWidth + ( boxPaddingX * 2 ) ), h, "idle" )

        hintData.text = self.wrappedText
        hintData.font = decrees.fonts.small
        hintData.posX = slide + boxPaddingX + self.jitterX
        hintData.posY = boxPaddingY + self.jitterY
        surface.drawShadowedTextBetterData( hintData )

        surface_SetAlphaMultiplier( 1 )

        return true

    end
end

local chatWasOpened

hook.Add( "StartChat", "glee_rtmdetect_chatopening", function()
    chatWasOpened = true

end )

hook.Add( "huntersglee_cl_displayhint_poststack", "glee_rtmhint", function( me )
    if not GetGlobalBool( "glee_pleaseshow_rtmtutorialhint", false ) then return end

    if not chatWasOpened then
        local valid, openChatPhrase = GAMEMODE:TranslatedBind( "say" )
        if not valid then
            valid, openChatPhrase = GAMEMODE:TranslatedBind( "messagemode" )

        end
        if not valid then
            valid, openChatPhrase = GAMEMODE:TranslatedBind( "messagemode2" )

        end
        if not valid then chatWasOpened = true return end

        return true, "It's time for a new Misery, maybe a real challenge...\nPress " .. openChatPhrase .. " to open the chat."

    elseif not me:GetNW2Bool( "glee_hasrtm_voted", false ) then
        return true, "It's time for a real challenge.\nBegin a Misery vote.\nType !rtm in chat."

    end
end )
