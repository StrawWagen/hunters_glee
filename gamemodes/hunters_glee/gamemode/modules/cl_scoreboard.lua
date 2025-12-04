
surface.CreateFont( "ScoreboardDefault", {
    font    = "Helvetica",
    size    = 22,
    weight    = 800
} )

surface.CreateFont( "ScoreboardDefaultTitle", {
    font    = "Helvetica",
    size    = 32,
    weight    = 800
} )

--
-- This defines a new panel type for the player row. The player row is given a player
-- and then from that point on it pretty much looks after itself. It updates player info
-- in the think function, and removes itself when the player leaves the server.
--
local PLAYER_LINE = {
    Init = function( self )

        self.AvatarButton = self:Add( "DButton" )
        self.AvatarButton:Dock( LEFT )
        self.AvatarButton:SetSize( 32, 32 )
        self.AvatarButton.DoClick = function() self.Player:ShowProfile() end
        self.AvatarButton:SetTooltip( "Open this player's steam profile." )
        self.AvatarButton:SetTooltipDelay( 0 )

        self.Avatar = vgui.Create( "AvatarImage", self.AvatarButton )
        self.Avatar:SetSize( 32, 32 )
        self.Avatar:SetMouseInputEnabled( false )

        self.Name = self:Add( "DLabel" )
        self.Name:Dock( FILL )
        self.Name:SetFont( "ScoreboardDefault" )
        self.Name:SetTextColor( Color( 93, 93, 93 ) )
        self.Name:DockMargin( 8, 0, 0, 0 )

        -- Invisible button overlay for spectating player
        self.SpectateButton = self.Name:Add( "DButton" )
        self.SpectateButton:Dock( FILL )
        self.SpectateButton:SetText( "" )
        self.SpectateButton.Paint = function() end -- Make it invisible
        self.SpectateButton.DoClick = function()
            if IsValid( self.Player ) then
                RunConsoleCommand( "glee_spectate_player", self.Player:SteamID() )
            end
        end

        self.Mute = self:Add( "DImageButton" )
        self.Mute:SetSize( 32, 32 )
        self.Mute:Dock( RIGHT )
        self.Mute:SetTooltip( "Mute/Unmute this player's voicechat" )
        self.Mute:SetTooltipDelay( 0 )

        self.Ping = self:Add( "DLabel" )
        self.Ping:Dock( RIGHT )
        self.Ping:SetWidth( 50 )
        self.Ping:SetFont( "ScoreboardDefault" )
        self.Ping:SetTextColor( Color( 93, 93, 93 ) )
        self.Ping:SetContentAlignment( 5 )
        self.Ping:SetMouseInputEnabled( true )
        self.Ping:SetTooltip( "Player's ping to the server." )
        self.Ping:SetTooltipDelay( 0 )

        self.Skulls = self:Add( "DLabel" )
        self.Skulls:Dock( RIGHT )
        self.Skulls:SetWidth( 50 )
        self.Skulls:SetFont( "ScoreboardDefault" )
        self.Skulls:SetTextColor( Color( 93, 93, 93 ) )
        self.Skulls:SetContentAlignment( 5 )
        self.Skulls:SetMouseInputEnabled( true )
        self.Skulls:SetTooltip( "This player's Skulls" )
        self.Skulls:SetTooltipDelay( 0 )

        self.Score = self:Add( "DLabel" )
        self.Score:Dock( RIGHT )
        self.Score:SetWidth( 50 )
        self.Score:SetFont( "ScoreboardDefault" )
        self.Score:SetTextColor( Color( 93, 93, 93 ) )
        self.Score:SetContentAlignment( 5 )
        self.Score:SetMouseInputEnabled( true )
        self.Score:SetTooltip( "Score.\nEither get close to hunters, or game the Shop" )
        self.Score:SetTooltipDelay( 0 )

        self:Dock( TOP )
        self:DockPadding( 3, 3, 3, 3 )
        self:SetHeight( 32 + 3 * 2 )
        self:DockMargin( 2, 0, 2, 2 )

    end,

    Setup = function( self, pl )

        self.Player = pl

        self.Avatar:SetPlayer( pl )

        self:Think( self )

        --local friend = self.Player:GetFriendStatus()
        --MsgN( pl, " Friend: ", friend )

    end,

    Think = function( self )

        local isObscured = GAMEMODE:IsObscured()

        if not IsValid( self.Player ) then
            self:SetZPos( 9999 ) -- Causes a rebuild
            self:Remove()
            return
        end

        if self.PName == nil or self.PName ~= self.Player:Nick() then
            self.PName = self.Player:Nick()
            self.Name:SetText( self.PName )
        end

        if self.NumScore == nil or self.NumScore ~= self.Player:GetScore() then
            self.NumScore = self.Player:GetScore()
            self.Score:SetText( self.NumScore )
        end

        if self.NumSkulls == nil or self.NumSkulls ~= self.Player:GetSkulls() then
            self.NumSkulls = self.Player:GetSkulls()
            self.Skulls:SetText( self.NumSkulls )
        end

        if self.NumPing == nil or self.NumPing ~= self.Player:Ping() then
            self.NumPing = self.Player:Ping()
            self.Ping:SetText( self.NumPing )
        end

        local zPos = 0
        if self.NumScore then
            zPos = zPos + -self.NumSkulls

        end

        --
        -- Change the icon of the mute button based on state
        --
        if self.Muted == nil or self.Muted ~= self.Player:IsMuted() then

            self.Muted = self.Player:IsMuted()
            if self.Muted then
                self.Mute:SetImage( "icon32/muted.png" )
            else
                self.Mute:SetImage( "icon32/unmuted.png" )
            end

            self.Mute.DoClick = function( _ ) self.Player:SetMuted( not self.Muted ) end
            self.Mute.OnMouseWheeled = function( s, delta )
                self.Player:SetVoiceVolumeScale( self.Player:GetVoiceVolumeScale() + ( delta / 100 * 5 ) )
                s.LastTick = CurTime()
            end

            self.Mute.PaintOver = function( s, w, h )
                if not IsValid( self.Player ) then return end

                local a = 255 - math.Clamp( CurTime() - ( s.LastTick or 0 ), 0, 3 ) * 255
                if a <= 0 then return end

                draw.RoundedBox( 4, 0, 0, w, h, Color( 0, 0, 0, a * 0.75 ) )
                draw.SimpleText( math.ceil( self.Player:GetVoiceVolumeScale() * 100 ) .. "%", "DermaDefaultBold", w / 2, h / 2, Color( 255, 255, 255, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            end

        end

        self:SetZPos( zPos )

    end,

    Paint = function( self, w, h )

        if not IsValid( self.Player ) then
            return
        end

        --
        -- We draw our background a different colour based on the status of the player
        --

        if not self.Player:Alive() and not GAMEMODE:IsObscured() then
            draw.RoundedBox( 4, 0, 0, w, h, Color( 200, 100, 100, 255 ) )
            return

        end

        draw.RoundedBox( 4, 0, 0, w, h, Color( 175, 175, 175, 200 ) )

    end
}

--
-- Convert it from a normal table into a Panel Table based on DPanel
--
PLAYER_LINE = vgui.RegisterTable( PLAYER_LINE, "DPanel" )

--
-- Here we define a new panel table for the scoreboard. It basically consists
-- of a header and a scrollpanel - into which the player lines are placed.
--
local SCORE_BOARD = {
    Init = function( self )

        self.Header = self:Add( "Panel" )
        self.Header:Dock( TOP )
        self.Header:SetHeight( 100 )

        self.Name = self.Header:Add( "DLabel" )
        self.Name:SetFont( "ScoreboardDefaultTitle" )
        self.Name:SetTextColor( color_white )
        self.Name:Dock( TOP )
        self.Name:SetHeight( 40 )
        self.Name:SetContentAlignment( 5 )
        self.Name:SetExpensiveShadow( 2, Color( 0, 0, 0, 200 ) )

        self.Scores = self:Add( "DScrollPanel" )
        self.Scores:Dock( FILL )

    end,

    PerformLayout = function( self )
        self:SetSize( 700, ScrH() - 200 )
        self:SetPos( ScrW() / 2 - 350, 100 )

    end,

    Paint = function( self, w, h )
        --draw.RoundedBox( 4, 0, 0, w, h, Color( 0, 0, 0, 200 ) )

    end,

    Think = function( self, w, h )
        self.Name:SetText( GetHostName() )

        --
        -- Loop through each player, and if one doesn't have a score entry - create it.
        --

        for _, pl in ipairs( player.GetAll() ) do

            if IsValid( pl.ScoreEntry ) then continue end

            pl.ScoreEntry = vgui.CreateFromTable( PLAYER_LINE, pl.ScoreEntry )
            pl.ScoreEntry:Setup( pl )

            self.Scores:AddItem( pl.ScoreEntry )

        end

    end
}

SCORE_BOARD = vgui.RegisterTable( SCORE_BOARD, "EditablePanel" )

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

end

--[[---------------------------------------------------------
    Name: gamemode:HUDDrawScoreBoard( )
    Desc: If you prefer to draw your scoreboard the stupid way (without vgui)
-----------------------------------------------------------]]
function GM:HUDDrawScoreBoard()
end