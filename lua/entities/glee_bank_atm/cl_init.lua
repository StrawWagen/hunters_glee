include( "shared.lua" )

-- TODO: terminator_Extras.glee_CL_SetupSent


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
    if not GAMEMODE.IsReallyHuntersGlee then return end
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
        box:SetFlashDuration( 0.12 )
        box:SetFlashIconColor( hud.colorHappyYellow:Copy() ) -- the box defaults this to red
        box:SetDoFadeDelays( false )
        return box

    end

    local bankHeadingRow = vgui.Create( "glee_hl2hudheading" )
    bankHeadingRow:SetText( "Bank:" )

    --[[---------------------------------------------------------
        Bank balance count-up (number-only row, full-width)
    -----------------------------------------------------------]]
    local bankBox = vgui.Create( "glee_hl2hudscorecount" )
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
    local accountPurchaseWait = 1

    -- Returns whether they can transact, and starts buying them an account when they
    -- can't. Neither button does anything without one, so both double as the way in.
    -- The shop prints its own refusal in chat, hence the wait on a failed attempt.
    local function requireAccount()
        if ply:GetNW2Bool( "Glee_HasBankAccount", false ) then return true end

        nextTransactionTime = CurTime() + accountPurchaseWait
        RunConsoleCommand( "termhunt_purchase", "bankopenaccount" )

    end

    local depositRow = makeActionRow( "DEPOSIT", function()
        if CurTime() < nextTransactionTime then return end
        if not requireAccount() then return end

        local cooldown      = ply:Alive() and atm.TransactionCooldown or atm.TransactionCooldownDead
        nextTransactionTime = CurTime() + cooldown
        sendDeposit( atm )
    end )
    local withdrawRow = makeActionRow( "WITHDRAW", function()
        if CurTime() < nextTransactionTime then return end
        if not requireAccount() then return end

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
    local frame = vgui.Create( "glee_hl2frame" )
    frame:SetSize( frameW, totalH )
    frame:Center()

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
    self.rocketFlameSize = 0

end

--[[---------------------------------------------------------
    Rocket landing burn

    Adapted from wiremod's WireLib.ThrusterEffectDraw.fire_smoke. Magnitude there is
    the thruster's live thrust; here it's the flame's length in units, eased toward
    its target, and that easing is what reads as the engines spinning up and cutting.
-----------------------------------------------------------]]

local matHeatWave = Material( "sprites/heatwave" )
local matFire     = Material( "effects/fire_cloud1" )

local flameLength   = 120 -- how far the flame reaches at full thrust
local flameSpinUp   = 6  -- higher lights the engines faster
local flameTooSmall = 1  -- below this there's nothing worth drawing, or emitting from

local nozzleOffset = Vector( 0, 0, 0 )

local smokeInterval = 0.015
local smokeSpread   = 200

local colorCore    = Color( 0, 0, 255, 128 )
local colorMid     = Color( 255, 255, 255, 128 )
local colorTip     = Color( 255, 255, 255, 0 )
local colorHeatMid = Color( 255, 255, 255, 255 )
local colorHeatTip = Color( 0, 0, 0, 0 )

-- Draw hooks can run more than once a frame ( mirrors, water ), so the easing is
-- pinned to the frame rather than the view, or the spin-up outruns the descent.
-- Think calls this too, so the emitter is still let go of when nobody is watching.
function ENT:UpdateRocketFlame()
    local frame = FrameNumber()
    if self.rocketFlameFrame ~= frame then
        self.rocketFlameFrame = frame

        local target = self:GetRocketBurning() and flameLength or 0
        self.rocketFlameSize = Lerp( FrameTime() * flameSpinUp, self.rocketFlameSize, target )

        if self.rocketFlameSize < flameTooSmall then
            self:StopRocketSmoke()

        end
    end

    return self.rocketFlameSize

end

function ENT:DrawRocketFlame( magnitude )
    local origin = self:LocalToWorld( nozzleOffset )
    local normal = -self:GetUp()

    local scroll = CurTime() * -10

    render.SetMaterial( matFire )
    render.StartBeam( 3 )
        render.AddBeam( origin, magnitude / 3, scroll, colorCore )
        render.AddBeam( origin + normal * magnitude, magnitude / 2, scroll + 1, colorMid )
        render.AddBeam( origin + normal * magnitude * 2, magnitude / 2, scroll + 3, colorTip )
    render.EndBeam()

    scroll = scroll * 0.5

    render.UpdateRefractTexture()
    render.SetMaterial( matHeatWave )
    render.StartBeam( 3 )
        render.AddBeam( origin, 8, scroll, colorCore )
        render.AddBeam( origin + normal * magnitude, 32, scroll + 2, colorHeatMid )
        render.AddBeam( origin + normal * magnitude * 2, 48, scroll + 5, colorHeatTip )
    render.EndBeam()

    scroll = scroll * 1.3

    render.SetMaterial( matFire )
    render.StartBeam( 3 )
        render.AddBeam( origin, 8, scroll, colorCore )
        render.AddBeam( origin + normal * magnitude, 16, scroll + 1, colorMid )
        render.AddBeam( origin + normal * magnitude * 2, 16, scroll + 3, colorTip )
    render.EndBeam()

end

function ENT:RocketSmoke( magnitude )
    local cur = CurTime()
    if ( self.nextRocketSmoke or 0 ) > cur then return end
    self.nextRocketSmoke = cur + smokeInterval

    local origin = self:LocalToWorld( nozzleOffset ) + VectorRand() * 10

    local emitter = self.rocketEmitter
    if not emitter then
        emitter = ParticleEmitter( origin )
        if not emitter then return end

        self.rocketEmitter = emitter

    end

    local currSmokeSpread = smokeSpread + magnitude
    if magnitude >= ( flameLength - 0.1 ) then
        currSmokeSpread = currSmokeSpread * 4

    end

    emitter:SetPos( origin )

    local normal = -self:GetUp()

    -- any two directions across the exhaust, to spread the plume off its own axis
    local orth1 = Vector( normal.z, normal.x, normal.y )
    orth1 = ( orth1 - normal * normal:Dot( orth1 ) ):GetNormalized()
    local orth2 = normal:Cross( orth1 )

    for _ = 1, 4 do
        local particle = emitter:Add( "particles/smokey", origin )
        if not particle then return end

        particle:SetCollide( true )
        particle:SetBounce( 0.01 )
        particle:SetVelocity( normal * math.Rand( magnitude * 15, magnitude * 25 ) + orth1 * math.Rand( -currSmokeSpread, currSmokeSpread ) + orth2 * math.Rand( -currSmokeSpread, currSmokeSpread ) )
        particle:SetAirResistance( 60 )
        particle:SetDieTime( 2.0 )
        particle:SetStartAlpha( 200 )
        particle:SetEndAlpha( 0 )
        particle:SetStartSize( math.Rand( 16, 24 ) )
        particle:SetEndSize( math.Rand( 10 + magnitude, 30 + magnitude ) )
        particle:SetRoll( math.Rand( -0.2, 0.2 ) )
        particle:SetColor( 200, 200, 210 )

    end
end

function ENT:StopRocketSmoke()
    if not self.rocketEmitter then return end

    self.rocketEmitter:Finish()
    self.rocketEmitter = nil

end

local jetSound     = "Phx.Jet2"
local jetPitchIdle = 135 -- barely lit
local jetPitchFull = 65  -- straining against the whole ATM, so it sits low and heavy

function ENT:StopRocketSound()
    if not self.rocketJet then return end

    self.rocketJet:Stop()
    self.rocketJet = nil

end

-- Driven from the flame's magnitude, so the engine's pitch and its size can't drift
-- apart. Lower pitch is harder work.
function ENT:UpdateRocketSound()
    local magnitude = self.rocketFlameSize

    if magnitude < flameTooSmall then
        self:StopRocketSound()
        return

    end

    local jet = self.rocketJet
    if not jet then
        jet = CreateSound( self, jetSound )
        if not jet then return end

        self.rocketJet = jet
        jet:PlayEx( 0, jetPitchIdle )

    end

    local working = magnitude / flameLength

    jet:ChangePitch( Lerp( working, jetPitchIdle, jetPitchFull ) )
    jet:ChangeVolume( working )

end

function ENT:OnRemove()
    self:StopRocketSmoke()
    self:StopRocketSound()

end

function ENT:DrawTranslucent()
    -- a burrowing ATM never lights its engines, so this is what keeps it out of here
    if not self:GetRocketBurning() then
        self:StopRocketSmoke()
        return

    end

    local magnitude = self:UpdateRocketFlame()
    if magnitude < flameTooSmall then return end

    self:DrawRocketFlame( magnitude )
    self:RocketSmoke( magnitude )

end

--[[---------------------------------------------------------
    ATM music management
-----------------------------------------------------------]]

local checkDist = 2000^2

function ENT:Think()
    -- ahead of the music's throttle; the burn has to keep spinning up and stay in
    -- pitch whether or not anyone happens to be looking at it
    self:UpdateRocketFlame()
    self:UpdateRocketSound()

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

    local state = self:GetState()
    if state == "broken" then
        self.nextAtmMusicThink = math.huge
        if self.oldAtmMusic then
            self.oldAtmMusic:ChangePitch( 0, 5 )
            self.oldAtmMusic:FadeOut( 10 )

        end
    elseif state == "usable" then

        local path
        local volume = 1

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

        if GAMEMODE.IsMusicPlaying and GAMEMODE:IsMusicPlaying() then
            volume = 0.1

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
            music:PlayEx( volume, 100 )

            self.oldAtmMusic = music
            self:CallOnRemove( "glee_atm_stopmusic", function()
                local musicRemoving = self.oldAtmMusic
                if not musicRemoving then return end
                musicRemoving:Stop()

            end )
        else
            self.oldAtmMusic:ChangeVolume( volume )

        end
    end
end

