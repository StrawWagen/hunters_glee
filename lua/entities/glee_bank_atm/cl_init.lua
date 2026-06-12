include( "shared.lua" )

function ENT:Draw()
    self:DrawModel()

end

if not CLIENT then return end

-- ─── Constants ────────────────────────────────────────────────────────────────

local TRANSACTION_AMOUNTS = { 100, 500, 1000 }

-- ─── GUI state ────────────────────────────────────────────────────────────────

local currentGui = nil

local function closeGui()
    if IsValid( currentGui ) then currentGui:Close() end
    currentGui = nil

end

-- ─── Net helpers ──────────────────────────────────────────────────────────────

local function sendDeposit( atm, amount )
    net.Start( "glee_atm_deposit" )
    net.WriteEntity( atm )
    net.WriteUInt( amount, 32 )
    net.SendToServer()

end

local function sendWithdraw( atm, amount )
    net.Start( "glee_atm_withdraw" )
    net.WriteEntity( atm )
    net.WriteUInt( amount, 32 )
    net.SendToServer()

end

local function sendWithdrawPool( atm )
    net.Start( "glee_atm_withdrawpool" )
    net.WriteEntity( atm )
    net.SendToServer()

end

-- ─── GUI builder ──────────────────────────────────────────────────────────────

local function openAtmGui( atm )
    if not GAMEMODE.ISHUNTERSGLEE then return end
    closeGui()
    if not IsValid( atm ) then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local hud  = terminator_Extras.hl2hud
    local pad  = hud.blockPadding
    local gap  = hud.laneSpacing

    -- ── hudbox factory: static display ──
    local function makeBox( parent, text, font )
        local box = vgui.Create( "glee_hl2hudbox", parent )
        box:SetIconFont( font or "termhuntScoreFont" )
        box:SetTextPadding( pad )
        box:SetNormalBoxColor( hud.colorBackground:Copy() )
        box:SetFlashBoxColor( hud.colorBackgroundUrgent:Copy() )
        box:SetIconColor( hud.colorHappyYellow:Copy() )
        box:SetDoFadeDelays( false )
        box:SetText( text )
        box:AutoSize()
        box:SetState( box.STATE_NORMAL )
        return box

    end

    -- ── hudbox factory: clickable button ──
    local function makeButton( parent, text, onClick )
        local btn = vgui.Create( "glee_hl2hudbox", parent )
        btn:SetMouseInputEnabled( true )
        btn:SetIconFont( "termhuntScoreFont" )
        btn:SetTextPadding( pad )
        btn:SetNormalBoxColor( hud.colorBackground:Copy() )
        btn:SetFlashBoxColor( hud.colorBackgroundUrgent:Copy() )
        btn:SetFlashDuration( 0.12 )
        btn:SetFlashIconColor( hud.colorHappyYellow:Copy() )
        btn:SetIconColor( hud.colorHappyYellow:Copy() )
        btn:SetDoFadeDelays( false )
        btn:SetText( text )
        btn:AutoSize()
        btn:SetState( btn.STATE_NORMAL )

        function btn:AdditionalThink()
            if self:IsHovered() then
                self:SetNormalBoxColor( hud.colorBackgroundUrgent )
            else
                self:SetNormalBoxColor( hud.colorBackground )
            end
            self:SetState( self.STATE_NORMAL )

        end

        function btn:OnMousePressed( mc )
            if mc ~= MOUSE_LEFT then return end
            self:SetState( self.STATE_FLASH )
            onClick()

        end

        return btn

    end

    -- ── Score and bank info boxes ──
    -- Create them first so we can measure widths for frame sizing
    local tempFrame = vgui.Create( "DPanel" )
    tempFrame:SetSize( 0, 0 )

    local scoreBox = makeBox( tempFrame, "Score: " .. ply:GetScore() )
    local bankFunds = ply:GetNW2Int( "Glee_BankFunds", 0 )
    local hasAcc    = ply:GetNW2Bool( "Glee_HasBankAccount", false )
    local bankBox   = makeBox( tempFrame, hasAcc and ( "Bank: " .. bankFunds ) or "Bank: none" )

    -- Deposit and withdraw buttons — auto-size then unify height
    local dBtns = {}
    local wBtns = {}
    for _, amount in ipairs( TRANSACTION_AMOUNTS ) do
        dBtns[#dBtns + 1] = makeButton( tempFrame, "$" .. amount, function() sendDeposit( atm, amount ) end )
        wBtns[#wBtns + 1] = makeButton( tempFrame, "$" .. amount, function() sendWithdraw( atm, amount ) end )

    end

    local btnH = dBtns[1]:GetTall()

    -- Total row width = largest between info row and button rows
    local infoRowW = scoreBox:GetWide() + gap + bankBox:GetWide()
    local btnRowW  = 0
    for _, btn in ipairs( dBtns ) do btnRowW = btnRowW + btn:GetWide() + gap end
    btnRowW = btnRowW - gap  -- remove trailing gap

    local frameW = math.max( infoRowW, btnRowW )

    -- Stretch button widths evenly to fill frameW
    local perBtnW = math.floor( ( frameW - gap * ( #dBtns - 1 ) ) / #dBtns )
    for _, btn in ipairs( dBtns ) do btn:SetWide( perBtnW ) end
    for _, btn in ipairs( wBtns ) do btn:SetWide( perBtnW ) end

    -- Owner check and pool button
    local owner   = atm:GetAtmOwner()
    local isOwner = IsValid( owner ) and owner == ply

    local poolBox, claimBtn
    if isOwner then
        poolBox  = makeBox( tempFrame, "Pool: $" .. atm:GetPoolFunds() )
        claimBtn = makeButton( tempFrame, "Claim Pool", function() sendWithdrawPool( atm ) end )

    end

    -- Measure total frame height
    local totalH = scoreBox:GetTall() + gap   -- info row
                 + btnH + gap                  -- deposit row
                 + btnH                        -- withdraw row

    if isOwner then
        totalH = totalH + gap + poolBox:GetTall()

    end

    tempFrame:Remove()

    -- ── Real frame ──
    local frame = vgui.Create( "DFrame" )
    frame:SetSize( frameW, totalH )
    frame:Center()
    frame:MakePopup()
    frame:SetTitle( "" )
    frame:ShowCloseButton( false )
    frame:SetDraggable( false )

    function frame:Paint() end

    function frame:OnRemove()
        if currentGui ~= self then return end
        currentGui = nil

    end

    -- ── Re-parent everything to the real frame and position ──
    local curY = 0

    scoreBox:SetParent( frame )
    scoreBox:SetPos( 0, curY )

    bankBox:SetParent( frame )
    bankBox:SetPos( scoreBox:GetWide() + gap, curY )

    curY = curY + scoreBox:GetTall() + gap

    for i, btn in ipairs( dBtns ) do
        btn:SetParent( frame )
        btn:SetPos( ( i - 1 ) * ( perBtnW + gap ), curY )

    end
    curY = curY + btnH + gap

    for i, btn in ipairs( wBtns ) do
        btn:SetParent( frame )
        btn:SetPos( ( i - 1 ) * ( perBtnW + gap ), curY )

    end
    curY = curY + btnH

    if isOwner then
        curY = curY + gap
        poolBox:SetParent( frame )
        poolBox:SetPos( 0, curY )

        claimBtn:SetParent( frame )
        claimBtn:SetPos( poolBox:GetWide() + gap, curY )
        claimBtn:SetWide( frameW - poolBox:GetWide() - gap )

        -- Keep pool amount live
        function poolBox:AdditionalThink()
            local funds = IsValid( atm ) and atm:GetPoolFunds() or 0
            self:SetText( "Pool: $" .. funds )
            self:AutoSize()
            self:SetState( self.STATE_NORMAL )

        end

    end

    -- Keep score and bank live
    function scoreBox:AdditionalThink()
        self:SetText( "Score: " .. ( IsValid( ply ) and ply:GetScore() or 0 ) )
        self:AutoSize()
        self:SetState( self.STATE_NORMAL )

    end

    function bankBox:AdditionalThink()
        local funds = IsValid( ply ) and ply:GetNW2Int( "Glee_BankFunds", 0 ) or 0
        local acc   = IsValid( ply ) and ply:GetNW2Bool( "Glee_HasBankAccount", false )
        self:SetText( acc and ( "Bank: " .. funds ) or "Bank: none" )
        self:AutoSize()
        self:SetState( self.STATE_NORMAL )

    end

    -- ── Close on E / use / menu / click-outside / ATM death / distance ──
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

end

-- ─── Net receivers ────────────────────────────────────────────────────────────

net.Receive( "glee_atm_opened", function()
    local atm = net.ReadEntity()
    if not IsValid( atm ) then return end
    openAtmGui( atm )

end )

net.Receive( "glee_atm_transactionresult", function()
    local ok  = net.ReadBool()
    local msg = net.ReadString()
    notification.AddLegacy( msg, ok and NOTIFY_GENERIC or NOTIFY_ERROR, 4 )

end )
