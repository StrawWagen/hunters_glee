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

    A glee_frame sizing itself around docked glee panels, in whatever style the local
    player's state calls for, at the gui scale.
-----------------------------------------------------------]]

local function openAtmGui( atm )
    if not GAMEMODE.IsReallyHuntersGlee then return end
    closeGui()
    if not IsValid( atm ) then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local transactionMax     = atm.TransactionAmount
    local deadTransactionMax = atm.DeadTransactionAmount

    local owner   = atm:GetAtmOwner()
    local isOwner = IsValid( owner ) and owner == ply

    local frame = vgui.Create( "glee_frame" )
    local gap   = frame:Style():Metric( "laneSpacing" )

    local function dockTop( panel, topGap )
        panel:Dock( TOP )
        if topGap then panel:DockMargin( 0, topGap, 0, 0 ) end

    end

    local bankHeading = vgui.Create( "glee_heading", frame )
    bankHeading:SetText( "Bank:" )
    dockTop( bankHeading )

    --[[---------------------------------------------------------
        Bank balance count-up (number-only row, full-width)
    -----------------------------------------------------------]]
    local bankBox = vgui.Create( "glee_countbox", frame )
    bankBox:SetDoFadeDelays( false )
    bankBox:SetLabel( "" )        -- "Bank:" is the heading row above
    bankBox:SetNilLabel( "none" )
    bankBox:SetReservedText( "99999999 -1000" )
    bankBox:SetCountFunc( function( p )
        if not IsValid( p ) then return nil end
        return p:BankFunds()

    end )
    bankBox:SetStartingCount( ply:BankFunds() )
    bankBox:SetAutoManage( true )
    bankBox:ManageHudState( ply, CurTime(), true, false )
    dockTop( bankBox, gap )

    --[[---------------------------------------------------------
        Action rows
    -----------------------------------------------------------]]
    local nextTransactionTime = 0
    local accountPurchaseWait = 1

    local function onCooldown()
        return CurTime() < nextTransactionTime

    end

    local function startCooldown()
        local cooldown = ply:Alive() and atm.TransactionCooldown or atm.TransactionCooldownDead
        nextTransactionTime = CurTime() + cooldown

    end

    -- Returns whether they can transact, and starts buying them an account when they
    -- can't. Neither button does anything without one, so both double as the way in.
    -- The shop prints its own refusal in chat, hence the wait on a failed attempt.
    local function requireAccount()
        if ply:BankHasAccount() then return true end

        nextTransactionTime = CurTime() + accountPurchaseWait
        RunConsoleCommand( "termhunt_purchase", "bankopenaccount" )

    end

    local function makeActionRow( label, topGap )
        local row = vgui.Create( "glee_row", frame )
        row:SetLabel( label )
        row:SetReservedValue( "1000000" )
        dockTop( row, topGap )

        return row

    end

    local depositRow = makeActionRow( "DEPOSIT", gap * 2 )

    function depositRow:DoClick()
        if not requireAccount() then return end

        startCooldown()
        sendDeposit( atm )

    end

    function depositRow:AdditionalThink()
        if not IsValid( ply ) then return end

        local canDeposit, reason = atm:CanDeposit( ply )
        if canDeposit then
            local cap = ply:Alive() and transactionMax or deadTransactionMax
            self:SetValue( "-" .. math.min( ply:GetScore(), cap ) )
            self:SetTooltip( "Deposit score." )

        else
            self:SetValue( "" )
            self:SetTooltip( reason )

        end

        self:SetDisabled( onCooldown() )

    end

    local withdrawRow = makeActionRow( "WITHDRAW", gap )

    function withdrawRow:DoClick()
        if not requireAccount() then return end

        startCooldown()
        sendWithdraw( atm )

    end

    function withdrawRow:AdditionalThink()
        if not IsValid( ply ) then return end

        local canWithdraw, reason = atm:CanWithdraw( ply )
        if canWithdraw then
            local cap         = ply:Alive() and transactionMax or deadTransactionMax
            local bankFunds   = ply:BankFunds()
            local minFunds    = GAMEMODE:GetBankMinFunds()
            local withdrawAmt = math.min( cap, math.max( 0, bankFunds - minFunds ) )
            self:SetValue( "+" .. withdrawAmt )
            self:SetTooltip( "Withdraw score." )

        else
            self:SetValue( "" )
            self:SetTooltip( reason )

        end

        self:SetDisabled( onCooldown() )

    end

    if isOwner then
        local ownerRow = makeActionRow( "Owner's Cut", gap )
        ownerRow:SetTooltip( "Claim your cut before someone destroys the ATM." )

        function ownerRow:DoClick()
            sendClaimOwnerCut( atm )

        end

        function ownerRow:AdditionalThink()
            local cut = IsValid( atm ) and atm:GetOwnersCut() or 0
            self:SetValue( tostring( cut ) )

        end
    end

    frame:SizeToContents()
    frame:Center()

    --[[---------------------------------------------------------
        Close on E / use / menu / click-outside / ATM death / distance
    -----------------------------------------------------------]]
    function frame:Think()
        hook.Run( "glee_cl_pleasepainttopleft_for", "score", 0.5 )

        if not IsValid( atm ) or atm:GetState() ~= "usable" then
            self:Close()
            return

        end

        if not IsValid( ply ) then return end
        if ply:Alive() and ply:GetPos():DistToSqr( atm:GetPos() ) > 512 ^ 2 then
            self:Close()

        end
    end

    function frame:OnRemove()
        if currentGui ~= self then return end
        currentGui = nil

    end

    terminator_Extras.easyClosePanel( frame )

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

