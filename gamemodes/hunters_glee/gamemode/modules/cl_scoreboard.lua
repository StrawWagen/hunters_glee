
local glee_sizeScaled = glee_sizeScaled

local GAMEMODE_URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=2848253104"

local PLY_STATUS_ALIVE = 1
local PLY_STATUS_DEAD = 2
local PLY_STATUS_GRIGORI = 3
local PLY_STATUS_ESCAPED = 4

local COLOR_BORDER = Color( 0, 0, 40, 150 )
local COLOR_HEADER = Color( 37, 37, 37, 220 )
local COLOR_BACKGROUND = Color( 37, 37, 37, 240 )
local COLOR_BACKGROUND_DARK = Color( 0, 0, 0, 50 )
local COLOR_ACTION_MENU_BACKGROUND = Color( 37, 37, 37, 240 )
local COLOR_BUTTON = Color( 0, 0, 0, 120 )
local COLOR_BUTTON_HOVERED = Color( 73, 73, 73, 255 )
local COLOR_SCROLL_BACKGROUND = Color( 0, 0, 0, 0 )
local COLOR_SCROLL_BAR = Color( 60, 60, 60, 150 )
local COLOR_DIVIDER = Color( 80, 80, 80, 240 )
local COLOR_LOCALPLAYER_NAME = Color( 43, 136, 28 )
local COLOR_SELECTION_ARROW = Color( 80, 80, 100 )

local white = Color( 255, 255, 255 )
local COLOR_TEXT = white
local COLOR_SERVER = white
local COLOR_TEXT_SCORE = white
local COLOR_TEXT_SKULLS = white
local COLOR_TEXT_GAMEMODE = white

local COLOR_PING_GOOD = Color( 50, 150, 0 )
local COLOR_PING_OKAY = Color( 150, 150, 0 )
local COLOR_PING_BAD = Color( 150, 50, 0 )

local HOVER_SLIDE_AMOUNT = glee_sizeScaled( 30 )
local HOVER_SLIDE_DURATION = 0.1

local BORDER_RADIUS_MAIN = glee_sizeScaled( nil, 0 ) -- 4
local BORDER_RADIUS_ACTION_MENU = glee_sizeScaled( nil, 0 ) -- 2

local PLY_COLORS = {
    [PLY_STATUS_ALIVE] = {
        BG_UNHOVERED = Color( 0, 0, 0, 150 ),
        BG_HOVERED = Color( 60, 60, 60, 255 ),
        NAME = Color( 255, 255, 255 ),
    },
    [PLY_STATUS_DEAD] = {
        BG_UNHOVERED = Color( 75, 0, 0, 150 ),
        BG_HOVERED = Color( 100, 50, 50 ),
        NAME = Color( 255, 200, 200 ),
    },
    [PLY_STATUS_GRIGORI] = {
        BG_UNHOVERED = Color( 75, 75, 0, 150 ),
        BG_HOVERED = Color( 100, 100, 50 ),
        NAME = Color( 255, 255, 200 ),
    },
    [PLY_STATUS_ESCAPED] = {
        BG_UNHOVERED = Color( 0, 55, 75, 150 ),
        BG_HOVERED = Color( 50, 87, 100 ),
        NAME = Color( 200, 255, 255 ),
    },
}

local PLY_LINE_SPACING = glee_sizeScaled( nil, 4 )
local PLY_INFO_SPACING = glee_sizeScaled( 100 )
local PLY_INFOS = { -- From right to left on the scoreboard.
    {
        NAME = "Ping",
        GETTER = function( ply )
            local ping = ply:Ping()
            local color = COLOR_PING_GOOD
            if ping >= 80 then color = COLOR_PING_OKAY end
            if ping >= 150 then color = COLOR_PING_BAD end

            return tostring( ping ), color
        end,
    },
    {
        NAME = "Score",
        TOOLTIP = "Score.\nEither get close to hunters, or game the Shop.",
        GETTER = function( ply )
            return tostring( ply:GetScore() ), COLOR_TEXT_SCORE
        end,
    },
    {
        NAME = "Skulls",
        TOOLTIP = "Skulls.\nEach one is something dead.",
        GETTER = function( ply )
            return tostring( ply:GetSkulls() ), COLOR_TEXT_SKULLS
        end,
    },
    {
        NAME = "Rank",
        GETTER = function( ply )
            local teamID = ply:Team()
            return team.GetName( teamID ), team.GetColor( teamID )
        end,
    },
}

local function setupFonts()
    local theFont = GAMEMODE and GAMEMODE.GLEE_FONT or "Arial"
    surface.CreateFont( "ScoreboardServerName", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 24 ),
        weight    = 500
    } )

    surface.CreateFont( "ScoreboardMapName", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 16 ),
        weight    = 500
    } )

    surface.CreateFont( "ScoreboardGamemodeTitle", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 32 ),
        weight    = 1000
    } )

    surface.CreateFont( "ScoreboardInfoCategory", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 18 ),
        weight    = 500
    } )

    surface.CreateFont( "ScoreboardPlayerCount", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 16 ),
        weight    = 500
    } )

    surface.CreateFont( "ScoreboardPlayerName", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 22 ),
        weight    = 500
    } )

    surface.CreateFont( "ScoreboardPlayerInfo", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 17 ),
        weight    = 500
    } )

    surface.CreateFont( "ScoreboardPlayerAction", {
        font    = theFont,
        size    = glee_sizeScaled( nil, 18 ),
        weight    = 500
    } )
end
setupFonts()
hook.Add( "glee_rebuildfonts", "glee_scoreboard_setup_fonts", setupFonts )


local plyInfoNudge = 0 -- Additional x offset that needs to be added to ply info in PLAYER_LINE for alignment.
local discordConvar = GetConVar( "glee_discord_url" )


local function isViewingActionsForPly( ply )
    if not IsValid( g_ScoreboardPlyActionMenu ) then return false end
    return g_ScoreboardPlyActionMenu.Player == ply
end


--
-- A simple context menu for actions to do when clicking on a player in the scoreboard.
--
local PLAYER_ACTION_MENU = {
    Init = function( self )
        self:DockPadding( 0, 0, 0, 0 )
        self:SetSize( glee_sizeScaled( 300, 1000 ) ) -- Large temporary height, gets auto-adjusted in Setup.

        self.HoverSlide = self:Add( "DPanel" )
        self.HoverSlide:SetWidth( 0 )
        self.HoverSlide:Dock( LEFT )

        -- Remove if the player clicks anywhere else. (HasFocus is broken, have to do it manually)
        hook.Add( "PlayerButtonDown", "glee_scoreboard_pam_autoclose", function( ply, btn )
            if ply ~= LocalPlayer() then return end -- Shouldn't ever happen, but just in case...
            if btn < MOUSE_FIRST or btn > MOUSE_LAST then return end
            if not IsValid( g_ScoreboardPlyActionMenu ) then return end
            if g_ScoreboardPlyActionMenu:IsHovered() then return end
            if g_ScoreboardPlyActionMenu:IsChildHovered( false ) then return end

            g_ScoreboardPlyActionMenu:Remove()
        end )

        -- Remove listener on panel remove
        local _Remove = self.Remove
        self.Remove = function( s )
            hook.Remove( "PlayerButtonDown", "glee_scoreboard_pam_autoclose" )
            _Remove( s )
        end
    end,

    Setup = function( self, ply )
        self.Player = ply
        if self:Think( self ) == false then return end

        local padding = glee_sizeScaled( nil, 4 )
        local labelHeight = glee_sizeScaled( nil, 24 )

        local function addOption( text, callback )
            local label = self:Add( "DLabel" )
            label:SetFont( "ScoreboardPlayerAction" )
            label:SetTextColor( COLOR_TEXT )
            label:SetHeight( labelHeight )
            label:SetMouseInputEnabled( true )
            label:DockMargin( padding, padding, padding, 0 )
            label:Dock( TOP )

            -- Static vs dynamic text
            if type( text ) == "string" then
                label:SetText( " " .. text )
            else
                local _Think = label.Think
                label.Think = function()
                    if not IsValid( ply ) then return end

                    label:SetText( " " .. text() )
                    _Think( label )
                end
            end

            label.DoClick = function()
                if not IsValid( ply ) then return end
                callback()
            end

            label.Paint = function( _, w, h )
                surface.SetDrawColor( label:IsHovered() and COLOR_BUTTON_HOVERED or COLOR_BUTTON )
                surface.DrawRect( 0, 0, w, h )
            end
        end

        addOption( "Open Steam Profile", function()
            ply:ShowProfile()
        end )

        addOption( "Copy Name", function()
            SetClipboardText( ply:Nick() )
        end )

        addOption( "Copy SteamID", function()
            SetClipboardText( ply:SteamID() )
        end )

        addOption(
            function()
                return ply:IsMuted() and "Unmute" or "Mute"
            end,
            function()
                ply:SetMuted( not ply:IsMuted() )
            end
        )

        if ply:Alive() and not LocalPlayer():Alive() then
            addOption( "Spectate", function()
                RunConsoleCommand( "glee_spectate_player", ply:UserID() )
            end )
        end

        -- vgui child count is weird. Also :SizeToChildren() is broken, yippee!
        self:SetHeight( ( #self:GetChildren() - 1 ) * ( padding + labelHeight ) + padding )
    end,

    Think = function( self )
        local ply = self.Player

        if not IsValid( ply ) or g_ScoreboardPlyActionMenu ~= self then
            self:Remove()
            return false
        end
    end,

    Paint = function( _, w, h )
        local borderRadius = BORDER_RADIUS_ACTION_MENU

        surface.SetDrawColor( COLOR_BORDER )
        surface.DrawOutlinedRect( 0, 0, w, h, borderRadius )

        surface.SetDrawColor( COLOR_ACTION_MENU_BACKGROUND )
        surface.DrawRect( borderRadius, borderRadius, w - borderRadius * 2, h - borderRadius * 2 )
    end
}

--
-- Convert it from a normal table into a Panel Table based on DPanel
--
PLAYER_ACTION_MENU = vgui.RegisterTable( PLAYER_ACTION_MENU, "DPanel" )


local PLAYER_LINE = {
    Init = function( self )
        local selfObj = self

        self:Dock( TOP )
        self:DockPadding( glee_sizeScaled( 3 ), 0, 0, 0 )
        self:DockMargin( 0, PLY_LINE_SPACING, 0, 0 )
        self:SetHeight( glee_sizeScaled( nil, 32 + 4 ) )
        self:SetMouseInputEnabled( true )
        self:SetText( "" )

        self.HoverSlide = self:Add( "DPanel" )
        self.HoverSlide:SetWidth( 0 )
        self.HoverSlide:Dock( LEFT )
        self.HoverSlide:SetMouseInputEnabled( false )
        self.HoverSlide.Paint = function( _, w, h )
            if not isViewingActionsForPly( selfObj.Player ) then return end

            local tipRadius = glee_sizeScaled( nil, 10 )
            local padding = glee_sizeScaled( 3 )
            local lineThickness = glee_sizeScaled( nil, 6 )
            local lineLength = w - padding * 2 - tipRadius

            draw.NoTexture()
            surface.SetDrawColor( COLOR_SELECTION_ARROW )
            surface.DrawRect( padding, h / 2 - lineThickness / 2, lineLength, lineThickness )
            surface.DrawPoly( {
                { x = padding + lineLength, y = h / 2 - tipRadius },
                { x = padding + lineLength + tipRadius, y = h / 2 },
                { x = padding + lineLength, y = h / 2 + tipRadius },
            } )
        end

        local avatarSize = glee_sizeScaled( nil, 32 )
        local muteSize = glee_sizeScaled( nil, 32 )
        local namePadding = glee_sizeScaled( 8 )

        self.AvatarButton = self:Add( "DPanel" )
        self.AvatarButton:Dock( LEFT )
        self.AvatarButton:SetWidth( avatarSize )
        self.AvatarButton:SetMouseInputEnabled( false )
        self.AvatarButton.Paint = function() end

        self.Avatar = vgui.Create( "AvatarImage", self.AvatarButton )
        self.Avatar:SetSize( avatarSize, avatarSize )
        self.Avatar:SetPos( 0, self:GetTall() / 2 - avatarSize / 2 )
        self.Avatar:SetMouseInputEnabled( false )

        self.Name = self:Add( "DLabel" )
        self.Name:Dock( FILL )
        self.Name:SetPaintBackground( false )
        self.Name:SetFont( "ScoreboardPlayerName" )
        self.Name:DockMargin( namePadding, 0, 0, 0 )
        self.Name:SetContentAlignment( 4 )
        self.Name:SetMouseInputEnabled( false )

        self.Mute = self:Add( "DImageButton" )
        self.Mute.isScoreboardMuteButton = true
        self.Mute:SetSize( muteSize, muteSize )
        self.Mute:Dock( RIGHT )
        self.Mute:DockMargin( 0, 0, PLY_INFO_SPACING * #PLY_INFOS + muteSize + namePadding, 0 )
        self.Mute:SetTooltip( "Mute/Unmute this player's voicechat\nScroll to adjust volume" )
        self.Mute:SetTooltipDelay( 0 )
    end,

    Setup = function( self, ply )
        self.Player = ply
        self.Avatar:SetPlayer( ply )
        self:Think( self )
    end,

    Think = function( self )
        local ply = self.Player

        if not IsValid( ply ) then
            self:SetZPos( 9999 ) -- Causes a rebuild
            self:Remove()
            return
        end

        if self.PName == nil or self.PName ~= ply:Nick() then
            self.PName = ply:Nick()
            self.Name:SetText( self.PName )
        end

        -- Change the icon of the mute button based on state
        if self.Muted == nil or self.Muted ~= ply:IsMuted() then
            self.Muted = ply:IsMuted()
            if self.Muted then
                self.Mute:SetImage( "icon32/muted.png" )
            else
                self.Mute:SetImage( "icon32/unmuted.png" )
            end

            self.Mute.DoClick = function( _ ) ply:SetMuted( not self.Muted ) end
            self.Mute.OnMouseWheeled = function( s, delta )
                ply:SetVoiceVolumeScale( ply:GetVoiceVolumeScale() + ( delta / 100 * 5 ) )
                s.LastTick = CurTime()
            end

            self.Mute.PaintOver = function( s, w, h )
                if not IsValid( ply ) then return end

                local a = 255 - math.Clamp( CurTime() - ( s.LastTick or 0 ), 0, 3 ) * 255
                if a <= 0 then return end

                draw.RoundedBox( glee_sizeScaled( nil, 4 ), 0, 0, w, h, Color( 0, 0, 0, a * 0.75 ) )
                draw.SimpleText( math.ceil( ply:GetVoiceVolumeScale() * 100 ) .. "%", "DermaDefaultBold", w / 2, h / 2, Color( 255, 255, 255, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            end
        end

        -- Set order based on skulls, then points.
        self:SetZPos( -1000 * ply:GetSkulls() - ply:GetScore() / 100 )

        -- Hover slide.
        local hoverProgress = self._hoverProgress or 0
        local slideOut = self:IsHovered() or isViewingActionsForPly( ply )
        local hoverDelta = ( slideOut and 1 or -0.5 ) * FrameTime() / HOVER_SLIDE_DURATION

        hoverProgress = math.Clamp( hoverProgress + hoverDelta, 0, 1 )

        if self._hoverProgress ~= hoverProgress then
            self._hoverProgress = hoverProgress
            self.HoverSlide:SetWidth( hoverProgress * HOVER_SLIDE_AMOUNT )
        end
    end,

    Paint = function( self, w, h )
        local ply = self.Player
        if not IsValid( ply ) then return end

        local status = PLY_STATUS_ALIVE

        if ply:Alive() and ply:HasStatusEffect( "divine_chosen" ) then
            status = PLY_STATUS_GRIGORI
        end

        if not ply:Alive() and ply:GetNWInt( "glee_spectateteam" ) == GAMEMODE.TEAM_ESCAPED then
            status = PLY_STATUS_ESCAPED
        elseif not GAMEMODE:IsObscured() and not ply:Alive() then
            status = PLY_STATUS_DEAD
        end

        -- Dynamic background and name color
        local colorInfo = PLY_COLORS[status]
        local hovered = self:IsHovered() -- TODO: Also hovered if name panel is hovered?
        local bgColor = colorInfo[hovered and "BG_HOVERED" or "BG_UNHOVERED"]
        local nameColor = ply == LocalPlayer() and COLOR_LOCALPLAYER_NAME or colorInfo.NAME

        if self._nameColor ~= nameColor then
            self._nameColor = nameColor
            self.Name:SetTextColor( nameColor )
        end

        surface.SetDrawColor( bgColor )
        surface.DrawRect( 0, 0, w, h )

        -- Draw player info
        local x = w - PLY_INFO_SPACING * 0.5 + plyInfoNudge
        local y = h / 2

        for _, info in ipairs( PLY_INFOS ) do
            local str, color = info.GETTER( ply )

            draw.SimpleText( str, "ScoreboardPlayerInfo", x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            x = x - PLY_INFO_SPACING
        end
    end,

    DoClick = function( self )
        if IsValid( g_ScoreboardPlyActionMenu ) then g_ScoreboardPlyActionMenu:Remove() end
        g_ScoreboardPlyActionMenu = vgui.CreateFromTable( PLAYER_ACTION_MENU )
        g_ScoreboardPlyActionMenu:SetPos( input.GetCursorPos() )
        g_ScoreboardPlyActionMenu:MakePopup()
        g_ScoreboardPlyActionMenu:SetKeyboardInputEnabled( false )
        g_ScoreboardPlyActionMenu:Setup( self.Player )
    end
}

--
-- Convert it from a normal table into a Panel Table based on DPanel
--
PLAYER_LINE = vgui.RegisterTable( PLAYER_LINE, "DButton" )


--
-- Here we define a new panel table for the scoreboard. It basically consists
-- of a header and a scrollpanel - into which the player lines are placed.
--
local SCORE_BOARD = {
    Init = function( self )
        local mainPadding = glee_sizeScaled( 16 ) -- left/right padding applied to outermost elements.
        local plyListPadding = glee_sizeScaled( nil, 8 ) -- padding applied to the scrollable player list.
        local headerPadding = glee_sizeScaled( nil, 8 ) -- top/bottom padding for header text

        self:SetSize( glee_sizeScaled( 1100, 720 ) )
        self:SetPos( ScrW() / 2 - self:GetWide() / 2, ScrH() / 2 - self:GetTall() / 2 )
        self:DockPadding( mainPadding, 0, mainPadding, 0 )

        -- Header
        self.Header = self:Add( "Panel" )
        self.Header:Dock( TOP )
        self.Header:SetHeight( glee_sizeScaled( nil, 60 ) )

        self.Header.Paint = function( _, w, _h )
            draw.SimpleText( GetHostName(), "ScoreboardServerName", w / 2, headerPadding, COLOR_SERVER, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        end

        -- TODO: Replace with a custom image for extra fancy gamemode title?
        self.HeaderLeft = self.Header:Add( "DLabel" )
        self.HeaderLeft:Dock( LEFT )
        self.HeaderLeft:SetWidth( glee_sizeScaled( 200 ) )
        self.HeaderLeft:SetPaintBackground( false )
        self.HeaderLeft:SetContentAlignment( 4 )
        self.HeaderLeft:SetFont( "ScoreboardGamemodeTitle" )
        self.HeaderLeft:SetTextColor( COLOR_TEXT_GAMEMODE )
        self.HeaderLeft:SetText( "Hunter's Glee" )
        self.HeaderLeft:SetMouseInputEnabled( true )
        self.HeaderLeft:SetTooltip( "Get some glee" )
        self.HeaderLeft:SetTooltipDelay( 0 )
        self.HeaderLeft.DoClick = function() gui.OpenURL( GAMEMODE_URL ) end

        self.HeaderRight = self.Header:Add( "DPanel" )
        self.HeaderRight:Dock( RIGHT )
        self.HeaderRight:SetWidth( glee_sizeScaled( 200 ) )
        self.HeaderRight:SetPaintBackground( false )

        self:InvalidateLayout( true ) -- Update header width from docking

        self.MapLabel = self.Header:Add( "DLabel" )
        self.MapLabel:SetSize( glee_sizeScaled( 200, 20 ) ) -- v Manual dock since auto would get misaligned by the sizes of left/right headers
        self.MapLabel:SetPos( self.Header:GetWide() / 2 - self.MapLabel:GetWide() / 2, self.Header:GetTall() - self.MapLabel:GetTall() - headerPadding )
        self.MapLabel:SetPaintBackground( false )
        self.MapLabel:SetContentAlignment( 2 )
        self.MapLabel:SetFont( "ScoreboardMapName" )
        self.MapLabel:SetTextColor( COLOR_TEXT )
        self.MapLabel:SetText( game.GetMap() )
        self.MapLabel:SetMouseInputEnabled( true )
        self.MapLabel:SetTooltip( "" )
        self.MapLabel:SetTooltipDelay( 0 )

        local discordSize = glee_sizeScaled( nil, 32 )
        self.DiscordButton = self.HeaderRight:Add( "DImageButton" )
        self.DiscordButton:SetPos( self.HeaderRight:GetWide() - discordSize, discordSize / 2 )
        self.DiscordButton:SetImage( "icon32/glee_discord_32.png" )
        self.DiscordButton:SetSize( discordSize, discordSize )
        self.DiscordButton:SetVisible( false )
        self.DiscordButton:SetTooltip( "Join the server's Discord" )
        self.DiscordButton:SetTooltipDelay( 0 )

        if discordSize ~= 32 then
            self.DiscordButton:SetStretchToFit( true )
        end

        self.DiscordButton.DoClick = function()
            local url = discordConvar:GetString()
            if url == "" then return end

            gui.OpenURL( url )
        end

        self.CategoryLabelHolder = self:Add( "Panel" )
        self.CategoryLabelHolder:SetHeight( glee_sizeScaled( nil, 40 ) )
        self.CategoryLabelHolder:DockPadding( plyListPadding, 0, plyListPadding, plyListPadding )
        self.CategoryLabelHolder:Dock( TOP )

        local function applyPlyInfoProperties( label )
            label:SetPaintBackground( false )
            label:SetContentAlignment( 2 )
            label:SetFont( "ScoreboardInfoCategory" )
            label:SetTextColor( COLOR_TEXT )
            label:SetWidth( PLY_INFO_SPACING )
            label:DockMargin( 0, 0, 0, 0 )
        end

        self.PlyCountLabel = self.CategoryLabelHolder:Add( "DLabel" )
        applyPlyInfoProperties( self.PlyCountLabel )
        self.PlyCountLabel:SetContentAlignment( 1 )
        self.PlyCountLabel:SetText( "Players" )
        self.PlyCountLabel:Dock( LEFT )

        for _, info in ipairs( PLY_INFOS ) do
            local label = self.CategoryLabelHolder:Add( "DLabel" )
            applyPlyInfoProperties( label )
            label:SetText( info.NAME )
            label:Dock( RIGHT )

            if info.TOOLTIP then
                label:SetTooltip( info.TOOLTIP )
                label:SetTooltipDelay( 0 )
                label:SetMouseInputEnabled( true )
            end
        end


        -- Player list
        local scoreCornerRadius = glee_sizeScaled( nil, 4 )

        self.Scores = self:Add( "DScrollPanel" )
        self.Scores:DockPadding( 0, 0, 0, 0 )
        self.Scores:GetCanvas():DockPadding( plyListPadding, plyListPadding - PLY_LINE_SPACING, plyListPadding, plyListPadding )
        self.Scores:Dock( TOP )

        self.Scores.Paint = function( _, w, h )
            draw.RoundedBox( scoreCornerRadius, 0, 0, w, h, COLOR_BACKGROUND_DARK )
        end


        -- Scroll secret stuff
        local scrollSecretReq = 50
        local scrollSecretDecay = 5

        local scrollSecretTime = CurTime()
        local scrollSecretVal = 0

        local function scrollSecretClear()
            scrollSecretVal = 0
            scrollSecretTime = CurTime()

            if IsValid( self.Scores.ScrollSecret ) then
                self.Scores.ScrollSecret:Remove()
                self.Scores.ScrollSecret = nil
            end
        end

        local function scrollSecretDone()
            if IsValid( self.Scores.ScrollSecret ) then return end

            local plyPanel = self.Scores:GetCanvas():GetChildren()[1]
            local height = plyPanel:GetTall()
            local leftPadding = plyPanel:GetDockPadding()

            local panel = self.Scores:Add( "DPanel" )
            self.Scores.ScrollSecret = panel
            panel:Dock( TOP )
            panel:SetHeight( height )
            panel:SetZPos( -1000000 )
            panel.Paint = function() end

            local btn = panel:Add( "DImageButton" )
            btn:SetImage( "icon32/glee_two_lemons_32.png" )
            btn:SetPos( leftPadding, height / 2 - 32 / 2 )
            btn:SizeToContents()
            btn:SetTooltip( "Scoreboard made by Two Lemons" )
            btn:SetTooltipDelay( 1 )
            btn.DoClick = function() gui.OpenURL( "https://github.com/legokidlogan" ) end
        end

        local function scrollSecretDelta( delta )
            if delta <= 0 then
                scrollSecretClear()
                return
            end

            local now = CurTime()
            local timeSince = now - scrollSecretTime

            if timeSince >= 1 then
                scrollSecretClear()
                return
            end

            scrollSecretVal = math.max( 0, scrollSecretVal + delta - timeSince * scrollSecretDecay )
            scrollSecretTime = now

            if scrollSecretVal >= scrollSecretReq then
                scrollSecretDone()
            end
        end


        -- Don't scroll when mouse-wheeling a mute button, since it has special behavior.
        local _OnMouseWheeled = self.Scores.OnMouseWheeled
        self.Scores.OnMouseWheeled = function( s, delta )
            local hov = vgui.GetHoveredPanel()
            if not hov then return end
            if hov.isScoreboardMuteButton then return end

            scrollSecretDelta( delta )
            _OnMouseWheeled( s, delta )
        end

        local scrollBar = self.Scores:GetVBar()
        scrollBar:SetHideButtons( true )
        scrollBar:SetWidth( glee_sizeScaled( 10 ) )

        scrollBar.Paint = function( _, w, h )
            surface.SetDrawColor( COLOR_SCROLL_BACKGROUND )
            surface.DrawRect( 0, 0, w, h )
        end

        local scrollBarGrip = scrollBar.btnGrip

        scrollBarGrip.Paint = function( _, w, h )
            draw.RoundedBox( glee_sizeScaled( 6 ), 0, 0, glee_sizeScaled( w - 2 ), h, COLOR_SCROLL_BAR )
        end
    end,

    PerformLayout = function( _self )
    end,

    Paint = function( self, w, h )
        local borderRadius = BORDER_RADIUS_MAIN
        local headerHeight = self.Header:GetTall()

        surface.SetDrawColor( COLOR_BORDER )
        surface.DrawOutlinedRect( 0, 0, w, h, borderRadius )

        surface.SetDrawColor( COLOR_HEADER )
        surface.DrawRect( borderRadius, borderRadius, w - borderRadius * 2, headerHeight - borderRadius )

        surface.SetDrawColor( COLOR_BACKGROUND )
        surface.DrawRect( borderRadius, headerHeight + 1, w - borderRadius * 2, h - borderRadius - headerHeight - 1 )

        surface.SetDrawColor( COLOR_DIVIDER )
        surface.DrawRect( borderRadius, headerHeight, w - borderRadius * 2, 1 )
    end,

    Think = function( self )
        local panelCreated = false

        -- Loop through each player, and if one doesn't have a score entry - create it.
        for _, ply in ipairs( player.GetAll() ) do
            if IsValid( ply.ScoreEntry ) then continue end

            local entry = vgui.CreateFromTable( PLAYER_LINE, self.Scores )

            ply.ScoreEntry = entry
            entry:Setup( ply )
            entry:Dock( TOP )

            panelCreated = true
        end

        local plyCount = player.GetCount()

        if panelCreated or plyCount ~= self._plyCount then
            self._plyCount = plyCount
            self.PlyCountLabel:SetText( "Players: " .. plyCount .. "/" .. game.MaxPlayers() )

            -- Resize Scores to fit its contents, to a limit.
            self.Scores:GetCanvas():InvalidateLayout( true ) -- Resize to fit contents
            self.Scores:SetHeight( math.min( self.Scores:GetCanvas():GetTall(), glee_sizeScaled( nil, 590 ) ) )
            self.Scores:PerformLayout() -- Update VBar

            -- Calculate info nudge, since the scrollbar pushes things over a little.
            local scrollBar = self.Scores:GetVBar()
            plyInfoNudge = scrollBar.Enabled and scrollBar:GetWide() or 0
        end

        self.MapLabel:SetTooltip( os.date( "!Map uptime: %H:%M:%S", CurTime() ) )
        self.DiscordButton:SetVisible( discordConvar:GetString() ~= "" )
    end
}

SCORE_BOARD = vgui.RegisterTable( SCORE_BOARD, "EditablePanel" )


-- auto-refresh
if IsValid( g_Scoreboard ) then
    g_Scoreboard:Remove()
    g_Scoreboard = nil

    for _, ply in ipairs( player.GetAll() ) do
        if IsValid( ply.ScoreEntry ) then
            ply.ScoreEntry:Remove()
            ply.ScoreEntry = nil
        end
    end
end

if IsValid( g_ScoreboardPlyActionMenu ) then
    g_ScoreboardPlyActionMenu:Remove()
    g_ScoreboardPlyActionMenu = nil
end


--[[---------------------------------------------------------
    Name: gamemode:ScoreboardShow( )
    Desc: Sets the scoreboard to visible
-----------------------------------------------------------]]
function GM:ScoreboardShow()
    if not IsValid( g_Scoreboard ) then
        g_Scoreboard = vgui.CreateFromTable( SCORE_BOARD )
    end

    if IsValid( g_Scoreboard ) then
        g_Scoreboard:Show()
        g_Scoreboard:MakePopup()
        g_Scoreboard:SetKeyboardInputEnabled( false )
    end
end

--[[---------------------------------------------------------
    Name: gamemode:ScoreboardHide( )
    Desc: Hides the scoreboard
-----------------------------------------------------------]]
function GM:ScoreboardHide()
    if IsValid( g_Scoreboard ) then
        g_Scoreboard:Hide()
    end

    if IsValid( g_ScoreboardPlyActionMenu ) then
        g_ScoreboardPlyActionMenu:Remove()
    end
end

--[[---------------------------------------------------------
    Name: gamemode:HUDDrawScoreBoard( )
    Desc: If you prefer to draw your scoreboard the stupid way (without vgui)
-----------------------------------------------------------]]
function GM:HUDDrawScoreBoard()
end