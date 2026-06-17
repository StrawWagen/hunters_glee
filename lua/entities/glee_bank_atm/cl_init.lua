include( "shared.lua" )

--[[---------------------------------------------------------
    GUI state
-----------------------------------------------------------]]

local currentGui = nil

local function closeGui()
    if IsValid( currentGui ) then currentGui:Close() end
    currentGui = nil

end

--[[---------------------------------------------------------
    Net helpers
-----------------------------------------------------------]]

local function sendDeposit( atm )
    net.Start( "glee_atm_deposit" )
    net.WriteEntity( atm )
    net.SendToServer()

end

local function sendWithdraw( atm )
    net.Start( "glee_atm_withdraw" )
    net.WriteEntity( atm )
    net.SendToServer()

end

local function sendClaimOwnerCut( atm )
    net.Start( "glee_atm_claimownercut" )
    net.WriteEntity( atm )
    net.SendToServer()

end

--[[---------------------------------------------------------
    GUI builder
-----------------------------------------------------------]]

local function openAtmGui( atm )
    if not GAMEMODE.ISHUNTERSGLEE then return end
    closeGui()
    if not IsValid( atm ) then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local hud         = terminator_Extras.glee_HL2Hud
    local pad         = hud.blockPadding
    local gap         = hud.laneSpacing
    local switchSound = GAMEMODE.shopStandards.switchSound

    local transactionMax     = atm.TransactionAmount
    local deadTransactionMax = atm.DeadTransactionAmount

    local owner   = atm:GetAtmOwner()
    local isOwner = IsValid( owner ) and owner == ply

    --[[---------------------------------------------------------
        Measure font for layout math
    -----------------------------------------------------------]]
    surface.SetFont( "glee_mediumHL2Font" )
    local _, fontH = surface.GetTextSize( "A" )
    local rowH = fontH + pad * 2   -- matches glee_hl2hudbox AutoSize height formula

    local function textW( str )
        return ( surface.GetTextSize( str ) )

    end

    --[[---------------------------------------------------------
        Shared glee_hl2hudbox setup
    -----------------------------------------------------------]]
    local function baseHudBox()
        local box = vgui.Create( "glee_hl2hudbox" )
        box:SetIconFont( "glee_mediumHL2Font" )
        box:SetTextPadding( pad )
        box:SetNormalBoxColor( hud.colorBackground:Copy() )
        box:SetFlashBoxColor( hud.colorBackgroundUrgent:Copy() )
        box:SetFlashDuration( 0.12 )
        box:SetFlashIconColor( hud.colorHappyYellow:Copy() )
        box:SetIconColor( hud.colorHappyYellow:Copy() )
        box:SetDoFadeDelays( false )
        return box

    end

    --[[---------------------------------------------------------
        "Bank:" heading: auto-sized hudbox anchored inside a transparent row
        The transparent container is docked TOP (full-width) so the dock layout works.
        The visible hudbox is positioned at (0,0) inside it, sized only to its text.
    -----------------------------------------------------------]]
    local bankHeadingRow = vgui.Create( "DPanel" )
    bankHeadingRow:SetTall( rowH )
    bankHeadingRow:SetMouseInputEnabled( false )
    function bankHeadingRow:Paint() end

    local bankHeadingBox = baseHudBox()
    bankHeadingBox:SetParent( bankHeadingRow )
    bankHeadingBox:SetText( "Bank:" )
    bankHeadingBox:AutoSize()   -- width = textW("Bank:") + pad*4, height = rowH
    bankHeadingBox:SetPos( 0, 0 )
    function bankHeadingBox:AdditionalThink()
        self:SetState( self.STATE_NORMAL )

    end

    --[[---------------------------------------------------------
        Bank balance count-up (number-only row, full-width)
    -----------------------------------------------------------]]
    local bankBox = vgui.Create( "glee_hl2hudscorecount" )
    bankBox:SetIconFont( "glee_mediumHL2Font" )
    bankBox:SetTextPadding( pad )
    bankBox:SetNormalBoxColor( hud.colorBackground:Copy() )
    bankBox:SetFlashBoxColor( hud.colorBackgroundUrgent:Copy() )
    bankBox:SetIconColor( hud.colorHappyYellow:Copy() )
    bankBox:SetDoFadeDelays( false )
    bankBox:SetLabel( "" )        -- "Bank:" is the heading row above
    bankBox:SetNilLabel( "none" )
    bankBox:SetCountFunc( function( p )
        if not IsValid( p ) then return nil end
        if not p:GetNW2Bool( "Glee_HasBankAccount", false ) then return nil end
        return p:GetNW2Int( "Glee_BankFunds", 0 )

    end )
    local hasAccount    = ply:GetNW2Bool( "Glee_HasBankAccount", false )
    local startingFunds = hasAccount and ply:GetNW2Int( "Glee_BankFunds", 0 ) or nil
    bankBox:SetStartingCount( startingFunds )
    bankBox:SetAutoManage( true )
    bankBox:ManageHudState( ply, CurTime(), true, false )
    bankBox:SetTooltip( "Your account's funds" )

    --[[---------------------------------------------------------
        Action row: glee_hl2hudbox with label-left / amount-right paint
        Uses draw.SimpleText just like glee_hl2hudbox does — no DLabel, no DockMargin.
        Amount is stored in row._amountText and updated by each row's AdditionalThink.
    -----------------------------------------------------------]]
    local function makeActionRow( labelText, onClick )
        local row = baseHudBox()
        row:SetMouseInputEnabled( true )
        row:SetText( "" )   -- suppress the centered-text branch in base Paint
        row:SetTall( rowH )

        row._labelText  = labelText
        row._amountText = ""
        row._hoveredOld = false

        local basePaint = row.Paint
        function row:Paint( w, h )
            basePaint( self, w, h )   -- draws background + manages alpha/flash
            if self._stateAlpha <= 0 then return end

            local innerPad = self._textPadding * 2   -- matches AutoSize: pad*4 total → pad*2 each side
            local midY     = h * 0.5
            local dIcon    = self._drawIcon           -- set by basePaint this frame

            draw.SimpleText( self._labelText,  self._font, innerPad,     midY, dIcon, TEXT_ALIGN_LEFT,  TEXT_ALIGN_CENTER )
            draw.SimpleText( self._amountText, self._font, w - innerPad, midY, dIcon, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

        end

        function row:AdditionalThink()
            local hovered = self:IsHovered()
            if hovered ~= self._hoveredOld then
                local pitch = hovered and 90 or 80
                LocalPlayer():EmitSound( switchSound, 60, pitch, 0.12 )
                self._hoveredOld = hovered

            end
            self:SetNormalBoxColor( hovered and hud.colorBackgroundUrgent or hud.colorBackground )
            self:SetState( self.STATE_NORMAL )

        end

        function row:OnMousePressed( mc )
            if mc ~= MOUSE_LEFT then return end
            self:SetState( self.STATE_FLASH )
            surface.PlaySound( "common/wpn_select.wav" )
            onClick()

        end

        return row

    end

    --[[---------------------------------------------------------
        Build action rows
    -----------------------------------------------------------]]
    local nextTransactionTime = 0

    local depositRow = makeActionRow( "DEPOSIT", function()
        if CurTime() < nextTransactionTime then return end
        if not ply:GetNW2Bool( "Glee_HasBankAccount", false ) then
            ply:EmitSound( "buttons/button10.wav", 75, 100, 0.25 )
            return

        end
        local cooldown      = ply:Alive() and atm.TransactionCooldown or atm.TransactionCooldownDead
        nextTransactionTime = CurTime() + cooldown
        sendDeposit( atm )
    end )
    local withdrawRow = makeActionRow( "WITHDRAW", function()
        if CurTime() < nextTransactionTime then return end
        if not ply:GetNW2Bool( "Glee_HasBankAccount", false ) then
            ply:EmitSound( "buttons/button10.wav", 75, 100, 0.25 )
            return

        end
        local cooldown      = ply:Alive() and atm.TransactionCooldown or atm.TransactionCooldownDead
        nextTransactionTime = CurTime() + cooldown
        sendWithdraw( atm )
    end )
    local ownerRow
    if isOwner then
        ownerRow = makeActionRow( "Owner's Cut", function() sendClaimOwnerCut( atm ) end )
        ownerRow:SetTooltip( "Claim your cut before someone destroys the ATM." )

    end

    --[[---------------------------------------------------------
        Frame sizing
        Action rows: label at x=pad*2, amount at x=w-pad*2, so total inner content
        needs: textW(widestLabel) + gap + textW("1000000") + pad*4 (pad*2 each side)
    -----------------------------------------------------------]]
    local widestLabel = math.max(
        textW( "DEPOSIT" ),
        textW( "WITHDRAW" ),
        isOwner and textW( "Owner's Cut" ) or 0
    )
    local actionRowMinW = widestLabel + gap + textW( "1000000" ) + pad * 4

    -- Bank number row: text is centered; pad*4 gives pad*2 breathing on each side
    local bankRowMinW = textW( "99999999 -1000" ) + pad * 4

    local contentW = math.max( actionRowMinW, bankRowMinW )
    local frameW   = contentW + pad * 2

    -- bankHeading + gap + bankBox + double gap + action rows
    local numActionRows = isOwner and 3 or 2
    local totalH = pad * 2
        + rowH
        + gap + bankBox:GetTall()
        + gap * 2
        + rowH * numActionRows
        + gap * ( numActionRows - 1 )

    --[[---------------------------------------------------------
        Frame
    -----------------------------------------------------------]]
    local frame = vgui.Create( "DFrame" )
    frame:SetSize( frameW, totalH )
    frame:Center()
    frame:MakePopup()
    frame:SetTitle( "" )
    frame:ShowCloseButton( false )
    frame:SetDraggable( false )
    frame:DockPadding( pad, pad, pad, pad )

    function frame:Paint( w, h )
        draw.RoundedBox( hud.boxCornerRadius, 0, 0, w, h, hud.colorBackgroundDark )

    end

    function frame:Think()
        hook.Run( "glee_cl_pleasepainttopleft_for", "score", 0.5 )

    end

    function frame:OnRemove()
        if currentGui ~= self then return end
        currentGui = nil

    end

    --[[---------------------------------------------------------
        Dock panels into the frame
    -----------------------------------------------------------]]
    local function dockTop( panel, topGap )
        panel:SetParent( frame )
        panel:Dock( TOP )
        if topGap then panel:DockMargin( 0, topGap, 0, 0 ) end

    end

    dockTop( bankHeadingRow )
    dockTop( bankBox, gap )

    dockTop( depositRow, gap * 2 )
    local baseDepositThink = depositRow.AdditionalThink
    function depositRow:AdditionalThink()
        baseDepositThink( self )
        if not IsValid( ply ) then return end

        local canDeposit, reason = atm:CanDeposit( ply )
        if canDeposit then
            local cap = ply:Alive() and transactionMax or deadTransactionMax
            self._amountText = "-" .. math.min( ply:GetScore(), cap )
            self:SetTooltip( "Deposit score." )

        else
            self._amountText = ""
            self:SetTooltip( reason )

        end

        local isOnCooldown = CurTime() < nextTransactionTime
        self:SetIconColor( isOnCooldown and hud.colorUnHappyYellow or hud.colorHappyYellow )
        if isOnCooldown then self:SetNormalBoxColor( hud.colorBackground ) end

    end

    dockTop( withdrawRow, gap )
    local baseWithdrawThink = withdrawRow.AdditionalThink
    function withdrawRow:AdditionalThink()
        baseWithdrawThink( self )
        if not IsValid( ply ) then return end

        local canWithdraw, reason = atm:CanWithdraw( ply )
        if canWithdraw then
            local cap         = ply:Alive() and transactionMax or deadTransactionMax
            local bankFunds   = ply:GetNW2Int( "Glee_BankFunds", 0 )
            local minFunds    = gleefunc_BankMinFunds()
            local withdrawAmt = math.min( cap, math.max( 0, bankFunds - minFunds ) )
            self._amountText  = "+" .. withdrawAmt
            self:SetTooltip( "Withdraw score." )

        else
            self._amountText = ""
            self:SetTooltip( reason )

        end

        local isOnCooldown = CurTime() < nextTransactionTime
        self:SetIconColor( isOnCooldown and hud.colorUnHappyYellow or hud.colorHappyYellow )
        if isOnCooldown then self:SetNormalBoxColor( hud.colorBackground ) end

    end

    if isOwner then
        dockTop( ownerRow, gap )

        local baseOwnerThink = ownerRow.AdditionalThink
        function ownerRow:AdditionalThink()
            baseOwnerThink( self )
            local cut        = IsValid( atm ) and atm:GetOwnersCut() or 0
            self._amountText = tostring( cut )

        end
    end

    --[[---------------------------------------------------------
        Close on E / use / menu / click-outside / ATM death / distance
    -----------------------------------------------------------]]
    terminator_Extras.easyClosePanel( frame )
    local easyThink = frame.Think

    function frame:Think()
        easyThink( self )

        if not IsValid( atm ) or atm:GetState() ~= "usable" then
            self:Close()
            return

        end

        if not IsValid( ply ) then return end
        if ply:GetPos():DistToSqr( atm:GetPos() ) > 512 ^ 2 then
            self:Close()

        end
    end

    currentGui = frame
    LocalPlayer().glee_AtmGui = frame

end

--[[---------------------------------------------------------
    Net receivers
-----------------------------------------------------------]]

net.Receive( "glee_atm_opened", function()
    local atm = net.ReadEntity()
    if not IsValid( atm ) then return end
    openAtmGui( atm )

end )

function ENT:Initialize()
    self.nextAtmMusicThink = 0

end

--[[---------------------------------------------------------
    ATM music management
-----------------------------------------------------------]]

local checkDist = 2000^2

function ENT:Think()
    if self.nextAtmMusicThink > CurTime() then return end
    self.nextAtmMusicThink = CurTime() + 0.1

    if self:IsDormant() then
        self.nextAtmMusicThink = CurTime() + 1

        if self.oldAtmMusic then
            self.oldAtmMusic:Stop()
            self.oldAtmMusic = nil
            self.currentAtmMusic = nil

        end
    end

    if self:GetPos():DistToSqr( EyePos() ) > checkDist then
        self.nextAtmMusicThink = CurTime() + 1
        return

    end

    local path

    if self:IsDormant() then
        path = ""

    -- in-gui music
    elseif IsValid( LocalPlayer().glee_AtmGui ) then
        path = "hunters_glee/music/VACANT/gleetm.wav"
        is3d = false

    -- from-atm music
    else
        path = "hunters_glee/music/VACANT/gleetm-hum_AMP.wav"
        is3d = true

    end

    if self.currentAtmMusic ~= path then
        if self.oldAtmMusic then
            self.oldAtmMusic:Stop()

        end

        if path == "" then return end

        self.currentAtmMusic = path
        local source = LocalPlayer()
        if is3d then
            source = self

        end
        local music = CreateSound( source, path )
        music:SetSoundLevel( 70 )
        music:PlayEx( 1, 100 )

        self.oldAtmMusic = music
        self:CallOnRemove( "glee_atm_stopmusic", function()
            local musicRemoving = self.oldAtmMusic
            if not musicRemoving then return end
            musicRemoving:Stop()

        end )
    end
end

