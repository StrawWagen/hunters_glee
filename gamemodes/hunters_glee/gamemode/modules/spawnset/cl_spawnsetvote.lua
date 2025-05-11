local spawnSetVote = {}
local draw_RoundedBox = draw.RoundedBox
local input = input

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

function spawnSetVote:CreateVotePanel()

    local holdToVote = "+showscores"
    local pressableThink = GAMEMODE.shopStandards.pressableThink
    local voteDoneSound = "buttons/lever4.wav"

    local cantAffordOverlay =   GAMEMODE.shopStandards.cantAffordOverlay
    local notHoveredOverlay =   GAMEMODE.shopStandards.notHoveredOverlay
    local pressedItemOverlay =  GAMEMODE.shopStandards.pressedItemOverlay

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

    local _, height = glee_sizeScaled( 1920, 1080 )
    local scale = height / 1080

    local whiteIdentifierLineWidth = height / GAMEMODE.shopStandards.whiteIdentifierLineWidthDiv
    local buttonMargin = height / 100

    local options = spawnSetVote.options
    local voteEnd = spawnSetVote.voteEnd

    if IsValid( GAMEMODE.spawnSetVote_VoteHolder ) then
        GAMEMODE.spawnSetVote_VoteHolder:Close()

    end
    local voteHolder = vgui.Create( "DFrame" )
    GAMEMODE.spawnSetVote_VoteHolder = voteHolder
    spawnSetVote.voteHolder = voteHolder

    local hudPadding = terminator_Extras.defaultHudPaddingFromEdge

    voteHolder:SetSize( 300 * scale, 0 )
    voteHolder:DockMargin( hudPadding, 250 * scale, hudPadding, hudPadding )
    voteHolder:DockPadding( 0, 0, 0, 0 )
    voteHolder:Dock( RIGHT )
    voteHolder:SetTitle( "" )
    voteHolder:SetVisible( true )
    voteHolder:SetDraggable( false )
    voteHolder:ShowCloseButton( false )

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
    function voteHolder:Paint( w, h )
        flash = self.Flash
        if self.Flash then
            self.Flash = nil
            draw_RoundedBox( 0, 0, 0, w, h, GAMEMODE.shopStandards.pressedItemOverlay )

        end
    end


    local infoLabel = vgui.Create( "DLabel", voteHolder, "glee_voteinfo_label" )

    infoLabel:SetSize( 10 * scale, 0 ) -- scaling these just in case
    infoLabel:SetAutoStretchVertical( true )
    infoLabel:Dock( TOP )
    infoLabel:SetTextInset( whiteIdentifierLineWidth, whiteIdentifierLineWidth )

    infoLabel:SetTextColor( GAMEMODE.shopStandards.white )
    infoLabel:SetFont( "termhuntShopItemFontShadowed" )

    infoLabel:SetContentAlignment( 8 )
    infoLabel:SetWrap( true )
    infoLabel:SetText( "Vote to change up the hunt..." )


    local countdownLabel = vgui.Create( "DLabel", voteHolder, "glee_voteinfo_countdown" )

    countdownLabel:SetSize( 10 * scale, 0 )
    countdownLabel:SetAutoStretchVertical( true )
    countdownLabel:Dock( TOP )
    countdownLabel:SetTextInset( whiteIdentifierLineWidth, whiteIdentifierLineWidth )

    countdownLabel:SetTextColor( GAMEMODE.shopStandards.white )
    countdownLabel:SetFont( "termhuntShopScoreFontShadowed" )

    countdownLabel:SetContentAlignment( 7 )
    countdownLabel:SetWrap( true )
    countdownLabel:SetText( "00" )

    local oldCountThink = countdownLabel.Think
    function countdownLabel:Think()
        local untilDoneRaw = spawnSetVote.voteEnd - CurTime()
        local untilDone = math.ceil( untilDoneRaw )
        untilDone = math.max( untilDone, 0 ) -- no -0 time...

        countdownLabel:SetText( untilDone )

        if untilDone <= 5 and untilDoneRaw % 1 < 0.1 then
            countdownLabel:SetTextColor( GAMEMODE.shopStandards.red )
            if not self.countdownClick then
                local pit = 100 - ( untilDone * 10 )
                LocalPlayer():EmitSound( GAMEMODE.shopStandards.switchSound, 60, pit, 0.5 ) -- surface.playsound has no pitch arg
                self.countdownClick = true

            end
        else
            countdownLabel:SetTextColor( GAMEMODE.shopStandards.white )
            self.countdownClick = nil

        end
        oldCountThink( countdownLabel )

    end


    for ind, data in ipairs( options ) do
        if ind >= 9 then return end

        local currButton = vgui.Create( "DButton", voteHolder, data.name )
        currButton.name = data.name
        currButton.prettyName = data.prettyName
        currButton.description = data.description
        currButton.ind = ind

        voteHolder.voteOptions[ind] = currButton

        currButton:SetTextColor( GAMEMODE.shopStandards.white )

        currButton:SetTextInset( whiteIdentifierLineWidth * 2, 0 )
        currButton:SetWrap( true )
        currButton:SetAutoStretchVertical( true )
        currButton:Dock( TOP )
        currButton:DockMargin( 0, buttonMargin, 0, 0 )
        currButton:DockPadding( 0, buttonMargin, 0, buttonMargin )

        currButton:SetFont( "termhuntShopItemFont" )
        currButton:SetText( ind .. ": " .. currButton.prettyName )

        currButton:SetTooltip( currButton.description )
        currButton:SetTooltipDelay( 0.1 )

        local oldBtnThink = currButton.Think
        function currButton:Think()
            oldBtnThink( self )
            pressableThink( self )

        end

        function currButton:Vote()
            if voteEnd < CurTime() then return end
            LocalPlayer():ConCommand( "glee_spawnset_castvote " .. self.name )
            LocalPlayer():EmitSound( GAMEMODE.shopStandards.switchSound, 60, 50, 0.24 ) -- surface.playsound has no pitch arg
            spawnSetVote.lastVoted = self.name
            self.wasVoted = true

        end

        currButton.OnMousePressed = function( self, keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = true

        end

        currButton.OnMouseReleased = function( self, keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = nil

            self:Vote()

        end

        function currButton:Paint( w, h )
            draw_RoundedBox( 0, 0, 0, w, h, GAMEMODE.shopStandards.backgroundColor )
            draw_RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, h, GAMEMODE.shopStandards.whiteFaded )

            self.myOverlayColor = nil

            if self.wasVoted and spawnSetVote.lastVoted == self.name then
                self.myOverlayColor = cantAffordOverlay
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            elseif not self:IsHovered() then
                self.pressed = nil
                self.myOverlayColor = notHoveredOverlay
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            elseif self.pressed then
                self.myOverlayColor = pressedItemOverlay
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            end

        end
    end

    local hintYapper = vgui.Create( "DLabel", voteHolder, "glee_voteinfo_hintyapper" )

    hintYapper:SetSize( 10, 0 )
    hintYapper:SetAutoStretchVertical( true )
    hintYapper:DockMargin( 0, buttonMargin, 0, 0 )
    hintYapper:Dock( TOP )
    hintYapper:SetTextInset( whiteIdentifierLineWidth, whiteIdentifierLineWidth )

    hintYapper:SetTextColor( GAMEMODE.shopStandards.white )
    hintYapper:SetFont( "termhuntShopItemFontShadowed" )

    hintYapper:SetContentAlignment( 7 )
    hintYapper:SetWrap( true )
    hintYapper:SetText( "" )

    local oldHintThink = hintYapper.Think
    function hintYapper:Think()
        if spawnSetVote.lastVoted then
            self:Remove()
            return

        end

        local hint = ""
        local hintStart = "Open chat"
        local hintEnd = " to vote."
        local valid, phrase = GAMEMODE:TranslatedBind( holdToVote )
        if hasAllTheVoteKeys and valid then -- some doofus is gonna have this unbound
            hint = hintStart .. " or press a number while holding " .. string.upper( phrase ) .. " " .. hintEnd

        else
            hint = hintStart .. hintEnd

        end

        self:SetText( hint )

        oldHintThink( hintYapper )

    end
end