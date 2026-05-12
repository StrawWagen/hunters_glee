AddCSLuaFile()
DEFINE_BASECLASS( "player_swapper" )

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Point and Click"
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
ENT.MoveDistMax = 500 -- Max grab distance from the owner's eyes. Makes it not get stuck awkwardly far away.

ENT.OwnerSoundLerp = 0.3 -- How quickly the volume/pitch of the owner sound should change. It scales based on total cost vs CostHighAmount.

ENT.TargetSoundSpeedMin = 300 -- What speed should correspond with minimum pitch/volume. Speeds below this will also get clamped to the minimum.
ENT.TargetSoundSpeedMax = 2000
ENT.TargetSoundPitchMin = 80
ENT.TargetSoundPitchMax = 140
ENT.TargetSoundVolumeMin = 0.35
ENT.TargetSoundVolumeMax = 1

ENT.NPCAllow = true -- Allow NPCs to be picked up.
ENT.NPCCostMult = 0.5 -- Applies to all costs when picking up NPCs.

ENT.NextBotAllow = true -- Allow NextBots to be picked up.
ENT.NextBotCostMult = 0.5 -- Applies to all costs when picking up NextBots.

function ENT:DynamicCooldown( elapsed )
    return math.Clamp( math.pow( elapsed, 1.4 ), 50, 60 * 5 )
end

-- For the current distance from the target's pre-grab position, return the one-time cost.
function ENT:CalcCostTotalDistance( dist )
    if dist <= 100 then return 0 end

    dist = math.min( dist, 8000 )
    dist = math.pow( dist, 0.8 )

    return dist

end

-- For a given +/- xyz velocity, return the spending cost. Will then be multiplied against the delta time (CostInterval).
-- Note: the velocity is calculated from change in position between cost ticks, a better measure than the target's immediate velocity snapshot.
function ENT:CalcCostMovementPerSec( xVel, yVel, zVel )
    local cost = 0
    local horizSpeed = math.sqrt( xVel * xVel + yVel * yVel )

    if horizSpeed > 100 then
        cost = cost + math.pow( horizSpeed / 100, 0.75 )

    end

    if zVel > 100 then
        zVel = math.min( zVel, 2000 )
        cost = cost + math.pow( zVel / 100, 2 )

    end

    return cost

end


if CLIENT then
    local matCursorArrow = Material( "materials/icon24/hunters_glee_cursor_arrow.png" )
    local matCursorHand = Material( "materials/icon24/hunters_glee_cursor_hand.png" )
    local cursorSizeArrow = 24 * math.max( math.Round( ScrH() / 540 ), 1 ) -- Round to avoid pixel blurring.
    local cursorSizeHand = 24 * math.max( math.Round( ScrH() / 540 ), 1 ) -- Round to avoid pixel blurring.

    terminator_Extras.glee_CL_SetupSent( ENT, "glee_point_and_click", "vgui/hud/killicon/glee_point_and_click.png" )


    local function colorLerpFast( color, from, to, frac )
        color.r = Lerp( frac, from.r, to.r )
        color.g = Lerp( frac, from.g, to.g )
        color.b = Lerp( frac, from.b, to.b )
        color.a = Lerp( frac, from.a, to.a )

    end

    local function correctUVs( u0, v0, u1, v1 )
        local du = 0.5 / 32 -- half pixel anticorrection
        local dv = 0.5 / 32 -- half pixel anticorrection
        u0, v0 = ( 0 - du ) / ( 1 - 2 * du ), ( 0 - dv ) / ( 1 - 2 * dv )
        u1, v1 = ( 1 - du ) / ( 1 - 2 * du ), ( 1 - dv ) / ( 1 - 2 * dv )

        return u0, v0, u1, v1

    end

    function ENT:PostInitializeFunc()
        self:SetNoDraw( true )

    end

    function ENT:GetTargetScreenPos()
        local target = self:GetCurrTarget()
        if not IsValid( target ) then return end

        local scrPos = target:WorldSpaceCenter():ToScreen()
        if not scrPos.visible then return end

        return scrPos.x, scrPos.y

    end

    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local cooldown = math.Round( self:GetGivenScoreAlt() )
        local costColor = self.glee_PointAndClick_CostColor

        if not costColor then
            costColor = Color( 0, 0, 0, 0 )
            self.glee_PointAndClick_CostColor = costColor

        end

        colorLerpFast( costColor, color_white, self.CostHighColor, -scoreGained / self.CostHighAmount )

        -- Draw cursor
        local targetX, targetY = self:GetTargetScreenPos()
        self._glee_PointAndClick_TargetVisible = targetX or false

        if self:IsGrabbing() then
            if targetX then
                surface.SetDrawColor( costColor )
                surface.SetMaterial( matCursorHand )
                surface.DrawTexturedRectUV( targetX, targetY, cursorSizeHand, cursorSizeHand, correctUVs( 0, 0, 1, 1 ) )

            end
        else
            surface.SetDrawColor( 255, 255, 255, 255 )
            surface.SetMaterial( matCursorArrow )
            surface.DrawTexturedRectUV( targetX or ( ScrW() / 2 ), targetY or ( ScrH() / 2 ), cursorSizeArrow, cursorSizeArrow, correctUVs( 0, 0, 1, 1 ) )

        end

        -- Draw cost/cooldown
        local scoreGainedString = "Total Cost: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + glee_sizeScaled( nil, 80 ), true )

        local cooldownMins = math.floor( cooldown / 60 )
        local cooldownSecs = math.floor( cooldown - cooldownMins * 60 )
        local cooldownString = "Cooldown: "

        if cooldownMins > 0 then
            cooldownString = cooldownString .. cooldownMins .. "m "
        end

        cooldownString = cooldownString .. cooldownSecs .. "s"
        surface.drawShadowedTextBetter( cooldownString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + glee_sizeScaled( nil, 80 + 40 ), true )

    end

    function ENT:ClientThink()
        self:SetNoDraw( true )
        self:HandleOwnerSound()
        self:HandleTargetSound()
        self._glee_PointAndClick_IsGhostEnt = true -- Set here instead of in init, as init doesn't run during fullupdate

    end

    function ENT:OwnerlessThink()
        if self:HasReleasedTarget() then
            self:StopOwnerSound()
            self:StopTargetSound()

        end
    end

    function ENT:HighlightNearestTarget()
        if self:IsGrabbing() then return end

        return BaseClass.HighlightNearestTarget( self )

    end

    function ENT:HandleOwnerSound()
        if not self:IsGrabbing() then return end
        if self.player ~= LocalPlayer() then return end

        if not self.glee_PointAndClick_OwnerSoundFrac then
            self.glee_PointAndClick_OwnerSoundFrac = 0

        end

        local oldFrac = self.glee_PointAndClick_OwnerSoundFrac
        local forceUpdate = false

        local snd = self.glee_PointAndClick_OwnerSound
        if not snd and self.player == LocalPlayer() then
            forceUpdate = true
            snd = CreateSound( game.GetWorld(), "ambient/machines/refinery_loop_1.wav" )
            self.glee_PointAndClick_OwnerSound = snd
            snd:SetSoundLevel( 0 )
            snd:PlayEx( 0, 100 )

        end

        if oldFrac >= 1 and not forceUpdate then return end

        local frac = math.Clamp( -self:GetGivenScore() / self.CostHighAmount, 0, 1 )
        frac = Lerp( self.OwnerSoundLerp * FrameTime(), oldFrac, frac )

        self.glee_PointAndClick_OwnerSoundFrac = frac
        snd:ChangeVolume( Lerp( frac, 0, 1 ) )
        snd:ChangePitch( Lerp( frac, 100, 180 ) )

    end

    function ENT:HandleTargetSound()
        if not self:IsGrabbing() then return end

        local target = self:GetCurrTarget()
        if not IsValid( target ) then
            self:StopTargetSound() -- nil-out the sound reference so we don't think it's still playing when they leave and re-enter PVS
            return

        end

        local snd = self.glee_PointAndClick_TargetSound
        if not snd then
            snd = CreateSound( target, "hunters_glee/hl2tweaks/ol07_advisor_00_36_25_loop.wav" )
            self.glee_PointAndClick_TargetSound = snd
            snd:PlayEx( 0, 100 )

        end

        local speed = target:GetVelocity():Length()
        local frac = math.Remap( speed, self.TargetSoundSpeedMin, self.TargetSoundSpeedMax, 0, 1 )

        snd:ChangePitch( Lerp( frac, self.TargetSoundPitchMin, self.TargetSoundPitchMax ) )
        snd:ChangeVolume( Lerp( frac, self.TargetSoundVolumeMin, self.TargetSoundVolumeMax ) )

    end

    function ENT:StopOwnerSound()
        local snd = self.glee_PointAndClick_OwnerSound
        if not snd then return end

        snd:Stop()
        self.glee_PointAndClick_OwnerSound = nil

    end

    function ENT:StopTargetSound()
        local snd = self.glee_PointAndClick_TargetSound
        if not snd then return end

        snd:Stop()
        self.glee_PointAndClick_TargetSound = nil

    end

    function ENT:OnRemove()
        BaseClass.OnRemove( self )

        self:StopOwnerSound()
        self:StopTargetSound()

    end


    -- Hide default crosshair while grabbing.
    local crosshairLookup = { ["CHudCrosshair"] = true } -- Faster than string comparison
    hook.Add( "HUDShouldDraw", "glee_pointandclick_overridecrosshair", function( name )
        if not crosshairLookup[name] then return end

        local ghostEnt = LocalPlayer().ghostEnt
        if not IsValid( ghostEnt ) then return end
        if not ghostEnt._glee_PointAndClick_IsGhostEnt then return end
        if not ghostEnt:IsGrabbing() and ghostEnt._glee_PointAndClick_TargetVisible then return end

        return false

    end )

end


function ENT:SetupDataTablesExtra()
    BaseClass.SetupDataTablesExtra( self )
    self:NetworkVar( "Float", 0, "HoldDist" )

end

function ENT:IsGrabbing()
    return self:GetHoldDist() > 0

end

function ENT:HasReleasedTarget()
    return self:GetHoldDist() <= -1

end


if not SERVER then return end


function ENT:PostInitializeFunc()
    self:SetHoldDist( 0 )
    self:SetGivenScore( -self.PurchaseCost )
    self:SetGivenScoreAlt( self:GetDynamicCooldown() )
    self._glee_PointAndClick_IsGhostEnt = true

end

function ENT:GetNearestTarget()
    local nearestPly
    local nearestDistance = math.huge
    local myPos = self:GetPos()
    local owner = self.player
    local allowNPCs = self.NPCAllow
    local allowNextBots = self.NextBotAllow

    for _, ent in ipairs( ents.FindInSphere( myPos, 2048 ) ) do
        if ent:IsPlayer() or ( allowNPCs and ent:IsNPC() and not ent:IsNextBot() ) or ( allowNextBots and ent:IsNextBot() ) then
            if ent == owner then continue end
            if ent:Health() <= 0 then continue end
            if ent.IsHomeless or ent.isGleeRescueHeli then continue end
            if not IsValid( ent:GetPhysicsObject() ) then continue end
            if hook.Run( "glee_pointandclick_cantarget", self, ent ) == false then continue end

            local distance = myPos:Distance( ent:NearestPoint( myPos ) )
            if distance < nearestDistance then
                nearestPly = ent
                nearestDistance = distance

            end
        end
    end

    return nearestPly

end

function ENT:UpdateGivenScore()
    self:SetGivenScore( "-" .. ( self.PurchaseCost * self:GetCostMult() ) )

end

function ENT:CalculateCanPlace()
    if not self:HasEnoughToPurchase() then return false, self.noPurchaseReason_TooPoor end

    local target = self:GetCurrTarget()
    if not IsValid( target ) then return false, "You need to aim at a living " .. ( self.NextBotAllow and "(or mechanical) " or "" ) .. "being." end
    if target.glee_PointAndClick_Ent then return false, "That person is already being grabbed!" end

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
    GAMEMODE:BlameForFallDamage( target, owner, self )

    self.glee_PointAndClick_Target = target
    self.glee_PointAndClick_CostPerSec = self.CostPerSec
    self.glee_PointAndClick_StartTime = CurTime()
    self.glee_PointAndClick_PrevCostTime = CurTime()
    self.glee_PointAndClick_PrevCostPos = target:WorldSpaceCenter()
    self.glee_PointAndClick_StartPos = target:WorldSpaceCenter()
    self.glee_PointAndClick_AccumCost = self.PurchaseCost

    target.glee_PointAndClick_Ent = self

    self:SetHoldDist( math.Clamp( target:WorldSpaceCenter():Distance( owner:EyePos() ), 1, self.MoveDistMax ) )
    self:SetPos( target:WorldSpaceCenter() )
    target:EmitSound( "npc/advisor/advisorheadvx06.wav", 77, 100, 1 )

end

function ENT:GetCostMult()
    local target = self:GetCurrTarget()
    if not IsValid( target ) then return 1 end
    if target:IsNextBot() then return self.NextBotCostMult end
    if target:IsNPC() then return self.NPCCostMult end

    return 1

end

function ENT:CostTick( force )
    local owner = self.player
    if not IsValid( owner ) then return end

    local now = CurTime()
    local prevTime = self.glee_PointAndClick_PrevCostTime
    if not force and now < prevTime + self.CostInterval then return end

    local dt = now - prevTime
    local costPerSec = math.min( self.glee_PointAndClick_CostPerSec + self.CostPerSecPerSec * dt, self.CostPerSecMax )
    local costMult = self:GetCostMult()
    local target = self.glee_PointAndClick_Target
    local bonusCost = 0

    self.glee_PointAndClick_PrevCostTime = now
    self.glee_PointAndClick_CostPerSec = costPerSec -- Store new cost rate before applying dynamic costs

    if IsValid( target ) then
        local prevPos = self.glee_PointAndClick_PrevCostPos
        local curPos = target:WorldSpaceCenter()
        self.glee_PointAndClick_PrevCostPos = curPos

        costPerSec = costPerSec + self:CalcCostMovementPerSec(
            ( curPos[1] - prevPos[1] ) / dt,
            ( curPos[2] - prevPos[2] ) / dt,
            ( curPos[3] - prevPos[3] ) / dt
        )

        bonusCost = bonusCost + self:CalcCostTotalDistance( curPos:Distance( self.glee_PointAndClick_StartPos ) )

    end

    local costDelta = math.Round( costPerSec * costMult * dt )
    local accumCost = self.glee_PointAndClick_AccumCost + costDelta
    bonusCost = bonusCost * costMult

    self.glee_PointAndClick_AccumCost = accumCost
    self:SetGivenScore( "-" .. ( accumCost + bonusCost ) )
    self:SetGivenScoreAlt( self:GetDynamicCooldown() )
    owner:GivePlayerScore( -costDelta )

end

function ENT:GetDynamicCooldown()
    return self:DynamicCooldown( CurTime() - ( self.glee_PointAndClick_StartTime or CurTime() ) )

end

function ENT:ApplyDynamicCooldown()
    if not self.itemIdentifier then return end
    local owner = self.player
    if not IsValid( owner ) then return end

    GAMEMODE:doShopCooldown( owner, self.itemIdentifier, self:GetDynamicCooldown() )

end

function ENT:ReleaseTarget()
    self:CostTick( true )
    self:ApplyDynamicCooldown()
    self:SetHoldDist( -1 )

    local baseOwner = self.player
    if IsValid( baseOwner ) then
        self:TellPlyToClearHighlighter()
        baseOwner.placableTargeted = nil
        baseOwner.ghostEnt = nil
        self:SetOwner( NULL )

    end

    local target = self.glee_PointAndClick_Target
    if not IsValid( target ) then return end

    target.glee_PointAndClick_Ent = nil
    target:EmitSound( "npc/advisor/advisor_blast6.wav", 80, 100, 1 )
    target:EmitSound( "npc/advisor/advisor_blast6.wav", 80, 120, 1 )

    if target:IsOnGround() then
        GAMEMODE:ClearFallDamageBlame( target )

    end
end

function ENT:ModifiableThink()
    if self:HasReleasedTarget() then return end -- Shouldn't get here in that state, but just in case.

    if not self:IsGrabbing() then
        return BaseClass.ModifiableThink( self )

    end

    local owner = self.player
    local target = self.glee_PointAndClick_Target

    if not IsValid( owner ) or not IsValid( target ) or not owner:KeyDown( IN_ATTACK ) or owner:GetScore() <= 0 then
        self:ReleaseTarget() -- After this, the owner is lost, and :OwnerlessThink() takes over.
        return

    end

    local curPos = target:WorldSpaceCenter()
    local goalPos = owner:EyePos() + owner:GetAimVector() * self:GetHoldDist()
    local toGoal = goalPos - curPos
    local dist = toGoal:Length()

    local nextbotLoco = target:IsNextBot() and target.loco
    local curVel = nextbotLoco and nextbotLoco:GetVelocity() or target:GetVelocity()
    local velToAdd = -curVel * self.MoveDampingMult

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
        if nextbotLoco then
            target:SetPos( target:GetPos() + Vector( 0, 0, 20 ) )

        else
            velToAdd = velToAdd + Vector( 0, 0, 300 / FrameTime() )

        end
    end

    -- Anti-grav
    local gravMult = target:GetGravity()
    if gravMult == 0 then gravMult = 1 end -- Source moment
    velToAdd = velToAdd - physenv.GetGravity() * gravMult

    if nextbotLoco then
        nextbotLoco:SetVelocity( curVel + velToAdd * FrameTime() )

    else
        target:SetVelocity( velToAdd * FrameTime() )

    end

    self:CostTick()
    self:NextThink( CurTime() )
    self:SetPos( curPos ) -- Folllow player for sounds and PVS

    return true

end

function ENT:OwnerlessThink()
    if not self:HasReleasedTarget() then return end
    local target = self.glee_PointAndClick_Target
    local cleanupTime = self.glee_PointAndClick_CleanupTime

    -- Wait for cleanup, or do it instantly if the target is invalid.
    if not IsValid( target ) or ( cleanupTime or math.huge ) <= CurTime() then
        SafeRemoveEntity( self ) -- Finally done!
        return

    end

    -- Once the target lands or dies, delay the removal so killicons can network properly.
    if not self.glee_PointAndClick_CleanupTime and ( target:IsOnGround() or target:Health() <= 0 ) then
        self.glee_PointAndClick_CleanupTime = CurTime() + 3

    end

    -- Do nothing if target has been released but hasn't landed yet.
    -- Otherwise, fall damage blame and killicons will break!
    self:NextThink( CurTime() )
    return true

end


hook.Add( "glee_falldamageblame_hitground", "glee_pointandclick_falldamageblame", function( target, attacker, inflictor )
    if not IsValid( inflictor ) then return end
    if not inflictor._glee_PointAndClick_IsGhostEnt then return end
    if not IsValid( attacker ) then return end
    if not attacker:IsPlayer() then return end

    GAMEMODE:BlameForFallDamage( target, attacker, inflictor ) -- Re-apply blame (they're still being grabbed!)

end )

hook.Add( "PlayerDeath", "glee_pointandclick_clearblame", function( target, inflictor )
    if not IsValid( inflictor ) then return end
    if not inflictor._glee_PointAndClick_IsGhostEnt then return end

    GAMEMODE:ClearFallDamageBlame( target ) -- Clear blame, since the other hook re-applies before we can tell if they're dead or not

end )
