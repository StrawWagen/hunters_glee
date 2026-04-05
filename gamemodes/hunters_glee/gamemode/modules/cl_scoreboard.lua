
local PLY_STATUS_ALIVE = 1
local PLY_STATUS_DEAD = 2
local PLY_STATUS_GRIGORI = 3

local COLOR_BORDER = Color( 0, 0, 40, 150 )
local COLOR_BACKGROUND = Color( 37, 37, 37, 240 )
local COLOR_BACKGROUND_DARK = Color( 0, 0, 0, 50 )
local COLOR_ACTION_MENU_BACKGROUND = Color( 37, 37, 37, 240 )
local COLOR_BUTTON = Color( 0, 0, 0, 120 )
local COLOR_BUTTON_HOVERED = Color( 73, 73, 73, 255 )
local COLOR_SCROLL_BACKGROUND = Color( 0, 0, 0, 0 )
local COLOR_SCROLL_BAR = Color( 60, 60, 60, 150 )
local COLOR_DIVIDER = Color( 200, 200, 200, 50 )
local COLOR_LOCALPLAYER_NAME = Color( 43, 136, 28 )
local COLOR_SELECTION_ARROW = Color( 80, 80, 100 )

local COLOR_TEXT = Color( 200, 200, 200 )
local COLOR_SERVER = Color( 255, 255, 255 )
local COLOR_TEXT_SCORE = Color( 255, 255, 255 )
local COLOR_TEXT_SKULLS = Color( 255, 255, 255 )
local COLOR_TEXT_GAMEMODE = Color( 255, 190, 190 )

local COLOR_PING_GOOD = Color( 50, 150, 0 )
local COLOR_PING_OKAY = Color( 150, 150, 0 )
local COLOR_PING_BAD = Color( 150, 50, 0 )

local HOVER_SLIDE_AMOUNT = 30
local HOVER_SLIDE_DURATION = 0.2

local PLY_COLORS = {
    [PLY_STATUS_ALIVE] = {
        BG_UNHOVERED = Color( 0, 0, 0, 150 ),
        BG_HOVERED = Color( 60, 60, 60, 255 ),
        NAME = Color( 255, 255, 255 ),
    },
    [PLY_STATUS_DEAD] = {
        BG_UNHOVERED = Color( 60, 0, 0, 150 ),
        BG_HOVERED = Color( 90, 45, 45 ),
        NAME = Color( 255, 200, 200 ),
    },
    [PLY_STATUS_GRIGORI] = {
        BG_UNHOVERED = Color( 60, 60, 0, 150 ),
        BG_HOVERED = Color( 90, 90, 45 ),
        NAME = Color( 255, 255, 200 ),
    },
}

local PLY_LINE_SPACING = 4
local PLY_INFO_SPACING = 100
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
        TOOLTIP = "Skulls.\nVery valuable.",
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


surface.CreateFont( "ScoreboardServerName", {
    font    = "Roboto",
    size    = 24,
    weight    = 600
} )

surface.CreateFont( "ScoreboardMapName", {
    font    = "Helvetica",
    size    = 16,
    weight    = 400
} )

surface.CreateFont( "ScoreboardGamemodeTitle", {
    font    = "Tahoma",
    size    = 32,
    weight    = 600
} )

surface.CreateFont( "ScoreboardInfoCategory", {
    font    = "Roboto",
    size    = 18,
    weight    = 500
} )

surface.CreateFont( "ScoreboardPlayerCount", {
    font    = "Roboto",
    size    = 16,
    weight    = 400
} )

surface.CreateFont( "ScoreboardPlayerName", {
    font    = "Roboto",
    size    = 22,
    weight    = 400
} )

surface.CreateFont( "ScoreboardPlayerInfo", {
    font    = "Roboto",
    size    = 17,
    weight    = 400
} )

surface.CreateFont( "ScoreboardPlayerAction", {
    font    = "Roboto",
    size    = 18,
    weight    = 400
} )


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
        self:SetSize( 300, 1000 ) -- Large temporary height, gets auto-adjusted in Setup.

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

        local padding = 4
        local labelHeight = 24

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
        local borderRadius = 0

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
        self:DockPadding( 3, 0, 0, 0 )
        self:DockMargin( 0, PLY_LINE_SPACING, 0, 0 )
        self:SetHeight( 32 + 4 )
        self:SetMouseInputEnabled( true )
        self:SetText( "" )

        self.HoverSlide = self:Add( "DPanel" )
        self.HoverSlide:SetWidth( 0 )
        self.HoverSlide:Dock( LEFT )
        self.HoverSlide:SetMouseInputEnabled( false )
        self.HoverSlide.Paint = function( _, w, h )
            if not isViewingActionsForPly( selfObj.Player ) then return end

            local tipRadius = 10
            local padding = 3
            local lineThickness = 6
            local lineLength = w - padding * 2 - tipRadius

            draw.NoTexture()
            surface.SetDrawColor( COLOR_SELECTION_ARROW )
            surface.DrawRect( padding, h / 2 - lineThickness / 2, lineLength, 6 )
            surface.DrawPoly( {
                { x = padding + lineLength, y = h / 2 - tipRadius },
                { x = padding + lineLength + tipRadius, y = h / 2 },
                { x = padding + lineLength, y = h / 2 + tipRadius },
            } )
        end

        self.AvatarButton = self:Add( "DPanel" )
        self.AvatarButton:Dock( LEFT )
        self.AvatarButton:SetWidth( 32 )
        self.AvatarButton:SetMouseInputEnabled( false )
        self.AvatarButton.Paint = function() end

        self.Avatar = vgui.Create( "AvatarImage", self.AvatarButton )
        self.Avatar:SetSize( 32, 32 )
        self.Avatar:SetPos( 0, self:GetTall() / 2 - 32 / 2 )
        self.Avatar:SetMouseInputEnabled( false )

        self.Name = self:Add( "DLabel" )
        self.Name:Dock( FILL )
        self.Name:SetPaintBackground( false )
        self.Name:SetFont( "ScoreboardPlayerName" )
        self.Name:DockMargin( 8, 0, 0, 0 )
        self.Name:SetContentAlignment( 4 )
        self.Name:SetMouseInputEnabled( false )

        self.Mute = self:Add( "DImageButton" )
        self.Mute.isScoreboardMuteButton = true
        self.Mute:SetSize( 32, 32 )
        self.Mute:Dock( RIGHT )
        self.Mute:DockMargin( 0, 0, PLY_INFO_SPACING * #PLY_INFOS + 32 + 8, 0 )
        self.Mute:SetTooltip( "Mute/Unmute this player's voicechat" )
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

                draw.RoundedBox( 4, 0, 0, w, h, Color( 0, 0, 0, a * 0.75 ) )
                draw.SimpleText( math.ceil( ply:GetVoiceVolumeScale() * 100 ) .. "%", "DermaDefaultBold", w / 2, h / 2, Color( 255, 255, 255, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            end
        end

        -- Set order based on skulls, then points.
        self:SetZPos( -1000000 * ply:GetSkulls() - ply:GetScore() )

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

        if not GAMEMODE:IsObscured() and not ply:Alive() then
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
        local mainPadding = 16 -- left/right padding applied to outermost elements.
        local plyListPadding = 8 -- padding applied to the scrollable player list.

        self:SetSize( 1100, 720 )
        self:SetPos( ScrW() / 2 - self:GetWide() / 2, ScrH() / 2 - self:GetTall() / 2 )
        self:DockPadding( mainPadding, 0, mainPadding, 0 )

        -- Header
        self.Header = self:Add( "Panel" )
        self.Header:Dock( TOP )
        self.Header:SetHeight( 60 )

        self.Header.Paint = function( _, w, h )
            local padding = 8

            draw.SimpleText( GetHostName(), "ScoreboardServerName", w / 2, padding, COLOR_SERVER, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
            draw.SimpleText( game.GetMap(), "ScoreboardMapName", w / 2, h - padding, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
        end

        -- TODO: Replace with a custom image for extra fancy gamemode title?
        self.HeaderLeft = self.Header:Add( "DLabel" )
        self.HeaderLeft:Dock( LEFT )
        self.HeaderLeft:SetWidth( 200 )
        self.HeaderLeft:SetPaintBackground( false )
        self.HeaderLeft:SetContentAlignment( 4 )
        self.HeaderLeft:SetFont( "ScoreboardGamemodeTitle" )
        self.HeaderLeft:SetTextColor( COLOR_TEXT_GAMEMODE )
        self.HeaderLeft:SetText( "Hunter's Glee" )
        self.HeaderLeft:SetMouseInputEnabled( true )
        self.HeaderLeft:SetTooltip( "Get some glee" )
        self.HeaderLeft:SetTooltipDelay( 0 )
        self.HeaderLeft.DoClick = function() gui.OpenURL( "https://steamcommunity.com/sharedfiles/filedetails/?id=2848253104" ) end

        self.HeaderRight = self.Header:Add( "DPanel" )
        self.HeaderRight:Dock( RIGHT )
        self.HeaderRight:SetPaintBackground( false )

        self.DiscordButton = self.HeaderRight:Add( "DImageButton" )
        self.DiscordButton:SetPos( self.HeaderRight:GetWide() / 2, self.HeaderRight:GetTall() / 2 )
        self.DiscordButton:SetImage( "icon32/glee_discord_32.png" )
        self.DiscordButton:SizeToContents()
        self.DiscordButton:SetVisible( false )
        self.DiscordButton:SetTooltip( "Join the server's Discord" )
        self.DiscordButton:SetTooltipDelay( 0 )

        self.DiscordButton.DoClick = function()
            local url = discordConvar:GetString()
            if url == "" then return end

            gui.OpenURL( url )
        end

        self.CategoryLabelHolder = self:Add( "Panel" )
        self.CategoryLabelHolder:SetHeight( 40 )
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
        local scoreCornerRadius = 4

        self.Scores = self:Add( "DScrollPanel" )
        self.Scores:DockPadding( 0, 0, 0, 0 )
        self.Scores:GetCanvas():DockPadding( plyListPadding, plyListPadding - PLY_LINE_SPACING, plyListPadding, plyListPadding )
        self.Scores:Dock( TOP )

        self.Scores.Paint = function( _, w, h )
            draw.RoundedBox( scoreCornerRadius, 0, 0, w, h, COLOR_BACKGROUND_DARK )
        end

        -- Don't scroll when mouse-wheeling a mute button, since it has special behavior.
        local _OnMouseWheeled = self.Scores.OnMouseWheeled
        self.Scores.OnMouseWheeled = function( ... )
            local hov = vgui.GetHoveredPanel()
            if not hov then return end
            if hov.isScoreboardMuteButton then return end

            _OnMouseWheeled( ... )
        end

        local scrollBar = self.Scores:GetVBar()
        scrollBar:SetHideButtons( true )
        scrollBar:SetWidth( 10 )

        scrollBar.Paint = function( _, w, h )
            surface.SetDrawColor( COLOR_SCROLL_BACKGROUND )
            surface.DrawRect( 0, 0, w, h )
        end

        local scrollBarGrip = scrollBar.btnGrip

        scrollBarGrip.Paint = function( _, w, h )
            draw.RoundedBox( 6, 0, 0, w - 2, h, COLOR_SCROLL_BAR )
        end
    end,

    PerformLayout = function( _self )
    end,

    Paint = function( self, w, h )
        local borderRadius = 0

        surface.SetDrawColor( COLOR_BORDER )
        surface.DrawOutlinedRect( 0, 0, w, h, borderRadius )

        surface.SetDrawColor( COLOR_BACKGROUND )
        surface.DrawRect( borderRadius, borderRadius, w - borderRadius * 2, h - borderRadius * 2 )

        surface.SetDrawColor( COLOR_DIVIDER )
        surface.DrawRect( borderRadius, self.Header:GetTall(), w - borderRadius * 2, 1 )
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
            self.Scores:SetHeight( math.min( self.Scores:GetCanvas():GetTall(), 590 ) )
            self.Scores:PerformLayout() -- Update VBar

            -- Calculate info nudge, since the scrollbar pushes things over a little.
            local scrollBar = self.Scores:GetVBar()
            plyInfoNudge = scrollBar.Enabled and scrollBar:GetWide() or 0
        end

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