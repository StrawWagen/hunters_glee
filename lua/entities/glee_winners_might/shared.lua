AddCSLuaFile()
DEFINE_BASECLASS( "player_swapper" )

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Winner's Might"
ENT.Author      = "TwoLemons"
ENT.Purpose     = "Picks up living players"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )
ENT.OnlyNetworkToOwner = false

ENT.PurchaseCost = 100
ENT.CostPerSec = 1
ENT.CostPerSecPerSec = 1
ENT.CostPerSecMax = 100
ENT.CostInterval = 1.5
ENT.CostHighColor = Color( 255, 100, 100, 255 )
ENT.CostHighAmount = 800

ENT.MoveStrengthMult = 30
ENT.MoveStrengthMax = 8000
ENT.MoveStrengthDownMult = 0.15 -- After the speed clamp, multiplies vertical force if it's pointing downwards. 0 to disable this feature.
ENT.MoveDampingMult = 2

ENT.FallResistActive = 0.5 -- Resistance mult against fall damage while actively being grabbed.
ENT.FallResistAfter = 0.5 -- Resistance mult that lingers once let go.
ENT.FallResistAfterDuration = 10 -- How long the post-grab resistance should last for.

ENT.TargetSoundSpeedMin = 300 -- What speed should correspond with minimum pitch/volume. Speeds below this will also get clamped to the minimum.
ENT.TargetSoundSpeedMax = 2000
ENT.TargetSoundPitchMin = 80 / 100 -- 0-1 scale for pitch bc of IGModAudioChannel.
ENT.TargetSoundPitchMax = 140 / 100
ENT.TargetSoundVolumeMin = 0.5 -- Volume can go above 1 bc of IGModAudioChannel.
ENT.TargetSoundVolumeMax = 2

ENT.IndicatorColorOuter = Color( 0, 0, 0, 255 )
ENT.IndicatorColorInner = Color( 255, 255, 255, 255 )
ENT.IndicatorColorLine = Color( 255, 255, 255, 255 )
ENT.IndicatorRadiusOuter = 10
ENT.IndicatorRadiusInner = 8

function ENT:DynamicCooldown( elapsed )
    return math.Clamp( math.pow( elapsed, 1.4 ), 50, 60 * 5 )
end


if CLIENT then
    local function makeDiamondPoly( centerX, centerY, radius )
        return {
            { x = centerX, y = centerY - radius, },
            { x = centerX + radius, y = centerY, },
            { x = centerX, y = centerY + radius, },
            { x = centerX - radius, y = centerY, },
        }

    end

    function ENT:PostInitializeFunc()
        self:SetNoDraw( true )
        self.indicatorPolyOuter = makeDiamondPoly( ScrW() / 2, ScrH() / 2, glee_sizeScaled( nil, self.IndicatorRadiusOuter ) )
        self.indicatorPolyInner = makeDiamondPoly( ScrW() / 2, ScrH() / 2, glee_sizeScaled( nil, self.IndicatorRadiusInner ) )

    end

    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local cooldown = math.Round( self:GetGivenScoreAlt() )
        local textColor = ( scoreGained <= -self.CostHighAmount ) and self.CostHighColor or color_white

        local scoreGainedString = "Total Cost: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", textColor, screenMiddleW, screenMiddleH + glee_sizeScaled( nil, 60 ), true, 255 )

        local cooldownMins = math.floor( cooldown / 60 )
        local cooldownSecs = math.floor( cooldown - cooldownMins * 60 )
        local cooldownString = "Cooldown: "

        if cooldownMins > 0 then
            cooldownString = cooldownString .. cooldownMins .. "m "
        end

        cooldownString = cooldownString .. cooldownSecs .. "s"
        surface.drawShadowedTextBetter( cooldownString, "scoreGainedOnPlaceFont", textColor, screenMiddleW, screenMiddleH + glee_sizeScaled( nil, 60 + 40 ), true, 255 )

        if self:IsGrabbing() then
            draw.NoTexture()

            local target = self:GetCurrTarget()
            if IsValid( target ) then
                local scrPos = target:WorldSpaceCenter():ToScreen()
                surface.SetDrawColor( self.IndicatorColorLine )
                surface.DrawLine( scrPos.x, scrPos.y, ScrW() / 2, ScrH() / 2 )

            end

            surface.SetDrawColor( self.IndicatorColorOuter )
            surface.DrawPoly( self.indicatorPolyOuter )

            surface.SetDrawColor( self.IndicatorColorInner )
            surface.DrawPoly( self.indicatorPolyInner )

        end

    end

    function ENT:ClientThink()
        self:SetNoDraw( true )
        self:HandleOwnerSound()
        self:HandleTargetSound()
        self._glee_WinnersMight_IsGhostEnt = true -- Set here instead of in init, as init doesn't run during fullupdate

    end

    function ENT:HandleOwnerSound()
        if not self:IsGrabbing() then return end
        if self.player ~= LocalPlayer() then return end

        if not self.glee_WinnersMight_StartTime then
            self.glee_WinnersMight_StartTime = CurTime()

        end

        local snd = self.glee_WinnersMight_OwnerSound
        if not snd and self.player == LocalPlayer() then
            snd = CreateSound( game.GetWorld(), "ambient/machines/refinery_loop_1.wav" )
            self.glee_WinnersMight_OwnerSound = snd
            snd:SetSoundLevel( 0 )
            snd:PlayEx( 0, 100 )

        end

        local elapsed = CurTime() - self.glee_WinnersMight_StartTime
        snd:ChangeVolume( Lerp( elapsed / 40, 0, 1 ) )
        snd:ChangePitch( Lerp( elapsed / 60, 100, 180 ) )

    end

    function ENT:HandleTargetSound()
        if not self:IsGrabbing() then return end

        -- Update sound
        local snd = self.glee_WinnersMight_TargetSound
        if IsValid( snd ) then
            local target = self:GetCurrTarget()
            if not IsValid( target ) then return end

            local speed = target:GetVelocity():Length()
            local frac = math.Remap( speed, self.TargetSoundSpeedMin, self.TargetSoundSpeedMax, 0, 1 )

            snd:SetPos( target:WorldSpaceCenter() )
            snd:SetPlaybackRate( Lerp( frac, self.TargetSoundPitchMin, self.TargetSoundPitchMax ) )
            snd:SetVolume( Lerp( frac, self.TargetSoundVolumeMin, self.TargetSoundVolumeMax ) )
            return

        end

        if self.glee_WinnersMight_LoadingTargetSound then return end

        self.glee_WinnersMight_LoadingTargetSound = true

        -- Create sound
        sound.PlayFile( "sound/hunters_glee/hl2tweaks/ol07_advisor_00_36_25_loop.wav", "mono 3d noplay noblock", function( x )
            self.glee_WinnersMight_LoadingTargetSound = nil
            if not IsValid( x ) then return end

            self.glee_WinnersMight_TargetSound = x
            self:HandleTargetSound() -- Initialize the pitch/volume
            x:EnableLooping( true )
            x:Play()

        end )
    end

    function ENT:OnRemove()
        BaseClass.OnRemove( self )

        local snd = self.glee_WinnersMight_OwnerSound
        if snd then
            snd:Stop()
            self.glee_WinnersMight_OwnerSound = nil

        end

        snd = self.glee_WinnersMight_TargetSound
        if IsValid( snd ) then
            snd:Stop()
            self.glee_WinnersMight_TargetSound = nil

        end
    end


    -- Hide default crosshair while grabbing.
    local crosshairLookup = { ["CHudCrosshair"] = true } -- Faster than string comparison
    hook.Add( "HUDShouldDraw", "glee_winnersmight_overridecrosshair", function( name )
        if not crosshairLookup[name] then return end

        local ghostEnt = LocalPlayer().ghostEnt
        if not IsValid( ghostEnt ) then return end
        if not ghostEnt._glee_WinnersMight_IsGhostEnt then return end
        if not ghostEnt:IsGrabbing() then return end

        return false

    end )

    -- TODO: 3D effects?

end


function ENT:SetupDataTablesExtra()
    BaseClass.SetupDataTablesExtra( self )
    self:NetworkVar( "Float", 0, "HoldDist" )

end

function ENT:GetDynamicCooldown()
    return self:DynamicCooldown( CurTime() - ( self.glee_WinnersMight_StartTime or CurTime() ) )

end

function ENT:IsGrabbing()
    return self:GetHoldDist() > 0

end


if not SERVER then return end


function ENT:PostInitializeFunc()
    self:SetHoldDist( 0 )
    self:SetGivenScore( -self.PurchaseCost )
    self:SetGivenScoreAlt( self:GetDynamicCooldown() )

end

function ENT:GetNearestTarget()
    local nearestPly
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all applicable door entities within a radius of 2048 units
    local plys = ents.FindInSphere( myPos, 2048 )
    for _, ply in ipairs( plys ) do
        if ply:IsPlayer() then
            if ply == self.player then continue end
            if ply:Health() <= 0 then continue end

            local distance = myPos:Distance( ply:NearestPoint( myPos ) )
            if distance < nearestDistance then
                nearestPly = ply
                nearestDistance = distance

            end
        end
    end

    return nearestPly

end

function ENT:UpdateGivenScore()
    self:SetGivenScore( "-" .. self.PurchaseCost )

end

function ENT:CalculateCanPlace()
    local target = self:GetCurrTarget()
    if not IsValid( target ) then return false, "You need to aim at a living player." end

    return true

end

function ENT:Place()
    if not SERVER then return end

    local owner = self.player
    if not IsValid( owner ) then return end

    local target = self:GetCurrTarget()
    local score = self:GetGivenScore()

    if owner.GivePlayerScore and score then
        owner:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( owner, score )

    end

    GAMEMODE:AddMischievousness( owner, 3, "picked up a player" )

    self.glee_WinnersMight_Target = target
    self.glee_WinnersMight_CostPerSec = self.CostPerSec
    self.glee_WinnersMight_StartTime = CurTime()
    self.glee_WinnersMight_PrevCostTime = CurTime()
    self.glee_WinnersMight_TotalCost = self.PurchaseCost

    target.glee_WinnersMight_Ent = self
    target.glee_WinnersMight_FallResistActive = self.FallResistActive

    self:SetHoldDist( math.max( target:WorldSpaceCenter():Distance( owner:EyePos() ), 1 ) )
    self:SetPos( target:WorldSpaceCenter() )
    self:EmitSound( "npc/advisor/advisor_blast6.wav", 77, 100, 1 )

end

function ENT:CostTick( force )
    local owner = self.player
    if not IsValid( owner ) then return end

    local now = CurTime()
    local prevTime = self.glee_WinnersMight_PrevCostTime
    if not force and now < prevTime + self.CostInterval then return end

    local dt = now - prevTime
    local costPerSec = math.min( self.glee_WinnersMight_CostPerSec + self.CostPerSecPerSec * dt, self.CostPerSecMax )

    self.glee_WinnersMight_PrevCostTime = now
    self.glee_WinnersMight_CostPerSec = costPerSec

    local costDelta = math.Round( costPerSec * dt )
    local totalCost = self.glee_WinnersMight_TotalCost + costDelta

    self.glee_WinnersMight_TotalCost = totalCost
    self:SetGivenScore( "-" .. totalCost )
    self:SetGivenScoreAlt( self:GetDynamicCooldown() )
    owner:GivePlayerScore( -costDelta )

end

function ENT:ApplyDynamicCooldown()
    if not self.itemIdentifier then return end
    local owner = self.player
    if not IsValid( owner ) then return end

    GAMEMODE:doShopCooldown( owner, self.itemIdentifier, self:GetDynamicCooldown() )

end

function ENT:ReleaseTarget()
    local baseOwner = self.player
    if IsValid( baseOwner ) then
        self:TellPlyToClearHighlighter()
        baseOwner.placableTargeted = nil
        baseOwner.ghostEnt = nil
        self:SetOwner( NULL )

    end

    local target = self.glee_WinnersMight_Target
    if not IsValid( target ) then return end

    target.glee_WinnersMight_Ent = nil
    target.glee_WinnersMight_FallResistActive = nil
    target.glee_WinnersMight_FallResistAfter = self.FallResistAfter
    target.glee_WinnersMight_FallResistAfterEndTime = CurTime() + self.FallResistAfterDuration

end

function ENT:ModifiableThink()
    if not self:IsGrabbing() then
        return BaseClass.ModifiableThink( self )

    end

    local owner = self.player
    local target = self.glee_WinnersMight_Target

    if not IsValid( owner ) or not IsValid( target ) or not owner:KeyDown( IN_ATTACK ) or owner:GetScore() <= 0 then
        self:CostTick( true )
        self:ApplyDynamicCooldown()
        self:ReleaseTarget()
        SafeRemoveEntity( self )
        return

    end

    local curPos = target:WorldSpaceCenter()
    local goalPos = owner:EyePos() + owner:GetAimVector() * self:GetHoldDist()
    local toGoal = goalPos - curPos
    local dist = toGoal:Length()
    local velToAdd = -target:GetVelocity() * self.MoveDampingMult

    if dist > 0.001 then
        local speed = math.min( dist * self.MoveStrengthMult, self.MoveStrengthMax )
        local moveVel = toGoal * ( speed / dist )
        local downMult = self.MoveStrengthDownMult

        if downMult ~= 0 and moveVel[3] < 0 then
            moveVel[3] = moveVel[3] * downMult

        end

        velToAdd = velToAdd + moveVel

    end

    -- Ground is way too sticky in player movement
    if target:IsOnGround() and velToAdd[3] > 0 then
        velToAdd = velToAdd + Vector( 0, 0, 300 / FrameTime() )
    end

    -- Anti-grav
    local gravMult = target:GetGravity()
    if gravMult == 0 then gravMult = 1 end -- Source moment
    velToAdd = velToAdd - physenv.GetGravity() * gravMult

    target:SetVelocity( velToAdd * FrameTime() )
    self:CostTick()
    self:NextThink( CurTime() )
    self:SetPos( curPos ) -- Folllow player for sounds and PVS

    return true

end


hook.Add( "EntityTakeDamage", "glee_winnersmight_fallresist", function( target, dmg )
    if not dmg:IsFallDamage() then return end
    if not target:IsPlayer() then return end

    local afterResist = target.glee_WinnersMight_FallResistAfter
    if afterResist and CurTime() <= target.glee_WinnersMight_FallResistAfterEndTime then
        dmg:ScaleDamage( 1 - afterResist )

    end

    local activeResist = target.glee_WinnersMight_FallResistActive
    if activeResist and IsValid( target.glee_WinnersMight_Ent ) then
        dmg:ScaleDamage( 1 - activeResist )

    end

    if dmg:GetDamage() < 1 then return true end

end )
