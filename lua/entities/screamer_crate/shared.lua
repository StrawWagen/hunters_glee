AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Screaming crate"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Screaming item crate spawner"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

sound.Add( {
    name = "horrific_crate_scream",
    channel = CHAN_WEAPON,
    level = 150,
    sound = "hl1/fvox/beep.wav"
} )

if CLIENT then
    -- score gained on place
    local fontData = {
        font = "Arial",
        extended = false,
        size = 40,
        weight = 500,
        blursize = 0,
        scanlines = 0,
        antialias = true,
        underline = false,
        italic = false,
        strikeout = false,
        symbol = false,
        rotary = false,
        shadow = false,
        additive = false,
        outline = false,
    }
    surface.CreateFont( "scoreGainedOnPlaceFont", fontData )

end
--sandbox support
function ENT:SpawnFunction( ply, tr, ClassName )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 16

    local ent = ents.Create( ClassName )
    ent:SetPos( SpawnPos )
    ent:SetOwner( ply )
    ent:Spawn()
    ent:Activate()

    if not GAMEMODE.ISHUNTERSGLEE then
        ent:Place()
    end

    return ent

end

function ENT:Initialize()
    self:SetModel( self.Model )
    if SERVER then
        self:SetRenderMode( RENDERMODE_TRANSCOLOR )
        self:SetNoDraw( false )
        self:DrawShadow( true )

    end
    self:PostInitializeFunc()

end

function ENT:PostInitializeFunc()

end

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )
local placingCost = 75

function GAMEMODE:ValidNum( num )
    return num or 0

end

function ENT:GetPos2()
    return self:GetPos() + self.PosOffset
end

local function IsHullTraceFull( startPos, hullMaxs, ignoreEnt )
    local traceData = {
        start = startPos,
        endpos = startPos + Vector( 0, 0, 1 ),
        filter = ignoreEnt,
        mins = -hullMaxs,
        maxs = hullMaxs
    }
    local trace = util.TraceHull( traceData )

    return trace.Hit

end

local function getNearestNavFloor( pos )
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + Vector( 0,0,-500 ),
        mask = 131083
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return NULL end
    local navArea = navmesh.GetNearestNavArea( Trace.HitPos, false, 25, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea

end

local function PlayRepeatingSound( self, soundPath, soundDuration )

    local crateEveryoneFilter = RecipientFilter()
    crateEveryoneFilter:AddAllPlayers()

    self.horrificSound = CreateSound( self, soundPath, crateEveryoneFilter )

    -- Create a unique timer name for this entity
    local timerName = "SoundTimer_" .. self:GetClass() .. self:EntIndex()

    timer.Simple( soundDuration * 0.35, function()
        if not IsValid( self ) then return end
        self:doSound( soundPath )

        if self.player and self.player.GivePlayerScore and self.refundAndBonus and self.refundAndBonus > 0 then
            self.player:GivePlayerScore( self.refundAndBonus )
            huntersGlee_Announce( { self.player }, 5, 15, "The beacon survives, you profit " .. self.refundAndBonus + -placingCost .. " score." )
            self.refundAndBonus = nil

        end

    end )

    self.doSound = function( self )
        self.horrificSound:Stop()
        self.horrificSound:PlayEx( 0.7, math.random( 120, 130 ) )

        sound.EmitHint( SOUND_COMBAT, self:GetPos(), 20000, 1, self )

        self:EmitSound( soundPath, 120, math.random( 140, 150 ), 1, CHAN_STATIC )

        util.ScreenShake( self:GetPos(), 1, 20, 1, 1000 )
        local obj = self:GetPhysicsObject()
        if not obj then return end
        obj:ApplyForceCenter( VectorRand() * obj:GetMass() * 100 )
        obj:ApplyTorqueCenter( VectorRand() * obj:GetMass() * 100 )

    end

    -- don't play right away
    --self:doSound( soundPath )

    -- Set the timer to repeat the sound
    timer.Create( timerName, soundDuration, 0, function()
        if IsValid( self ) then
            -- Only play the sound if the entity is still valid
            self:doSound( soundPath )
        else
            -- If the entity is no longer valid, stop the timer
            timer.Remove( timerName )
        end
    end )
end


function ENT:HasEnoughToPurchase()
    local ply = self.player
    if not IsValid( ply ) then return end
    if not ply.GetScore then return end
    local myScore = ply:GetScore()
    local given = self:GetGivenScore()
    local intoDebt = myScore + given < 0
    local justProfit = ( myScore + given ) > myScore
    if intoDebt and not justProfit then return end
    return true
end

function ENT:bestPosToBe()
    local radius = self:GetModelRadius()
    local offset = radius * self.player:GetEyeTrace().HitNormal
    offset.z = math.Clamp( offset.z, -radius, radius * 0.1 )
    return self.player:GetEyeTrace().HitPos + offset

end

function ENT:CanPlace()

    local checkPos = self:GetPos2() + Vector( 0,0,15 )

    if IsHullTraceFull( checkPos, self.HullCheckSize, self ) then return false end
    if getNearestNavFloor( checkPos ) == NULL then return false end
    if not self:HasEnoughToPurchase() then return false end
    return true

end

function ENT:Cancel()
    if not self.player then return end
    local preventCancel = self.preventCancel or 0
    if preventCancel > CurTime() then return end
    if self.player:GetObserverMode() == OBS_MODE_CHASE then self.preventCancel = CurTime() + 1 return end

    local filter = RecipientFilter()
    filter:RemoveAllPlayers()
    filter:AddPlayer( self.player )

    local filterPlayerOnly = RecipientFilter()
    filterPlayerOnly:AddPlayer( self.player )

    local cancelSound = CreateSound( self.player, "common/wpn_hudoff.wav", filterPlayerOnly )
    cancelSound:Play()

    GAMEMODE:RefundShopItemCooldown( self.player, self.itemIdentifier )

    SafeRemoveEntity( self )

end

local MEMORY_BREAKABLE = 4
local startGivingScoreDist = 3000
local startGivingScoreDistSqr = startGivingScoreDist^2

function ENT:GetGivenScore()
    local plys = player.GetAll()
    local smallestDist = math.huge

    for _, currentPly in ipairs( plys ) do
        if currentPly:Health() <= 0 then continue end
        local distToCurrentPlySqr = self:GetPos():DistToSqr( currentPly:GetPos() )
        if distToCurrentPlySqr < smallestDist then
            smallestDist = distToCurrentPlySqr
        end
    end

    if smallestDist > startGivingScoreDistSqr then return -5, 0 end

    local smallestDistLinear = math.sqrt( smallestDist )
    local scoreGiven = math.abs( smallestDistLinear - startGivingScoreDist )

    scoreGiven = scoreGiven / startGivingScoreDist -- scale this to 0-1
    scoreGiven = scoreGiven * 40 -- bring this back up to the score we want

    if smallestDistLinear < 1700 then
        scoreGiven = scoreGiven * 2.5 -- leap to way higher scores
    end

    scoreGiven = scoreGiven + -5

    if scoreGiven > 0 then
        scoreGiven = scoreGiven + placingCost
    end

    return scoreGiven, 0

end

hook.Add( "HUDPaint", "screamercrate_paintscore", function()
    if not GAMEMODE.CanShowDefaultHud or not GAMEMODE:CanShowDefaultHud() then return end
    if not IsValid( LocalPlayer().screamerCrate ) then return end

    local screenMiddleW = ScrW() / 2
    local screenMiddleH = ScrH() / 2

    local scoreGained = math.Round( GAMEMODE:ValidNum( LocalPlayer().screamerCrate.oldScoreGiven ) )

    local stringPt1 = ""
    local scoreString = ""
    local placinCostStr = ""

    if scoreGained > 0 then
        stringPt1 = "First beep reward + Deposit refund: "
        placinCostStr = "Deposit: -75"

        scoreString = stringPt1 .. tostring( scoreGained )
    else
        stringPt1 = "Hunter luring cost: "
        scoreString = stringPt1 .. tostring( scoreGained )
    end

    surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )
    surface.drawShadowedTextBetter( placinCostStr, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 60 )

end )

function ENT:ModifiableThink()
    self:SetPos( self:bestPosToBe() )

    if SERVER then

        if self:AliveCheck() then return end

        self:ColorThink()

    elseif CLIENT then

        self:ClientThink()

        local scoreGiven, penaltyGiven = self:GetGivenScore()

        if scoreGiven ~= self.oldScoreGiven then
            self.oldScoreGiven = scoreGiven
        end
        if penaltyGiven ~= self.oldPenaltyGiven then
            self.oldPenaltyGiven = penaltyGiven
        end
    end
end

function ENT:ColorThink()

    local mode = self.player:GetObserverMode()
    local canShow = mode == OBS_MODE_ROAMING

    if canShow ~= self.canShow then
        if not canShow then
            self:SetNoDraw( true )

        elseif canShow then
            self:SetNoDraw( false )

        end
        -- reset it
        self.couldPlace = nil
    end
    self.canShow = canShow

    local canPlace = self:CanPlace( self:GetPos2() )

    if self.couldPlace ~= canPlace then
        if not canPlace then
            self:SetColor( Color( 255, 0, 0, 255 ) )

        elseif canPlace then
            self:SetColor( Color( 0, 255, 0, 255 ) )

        end
    end
    self.couldPlace = canPlace

end

function ENT:AliveCheck()
    if not IsValid( self.player ) then SafeRemoveEntity( self ) return true end
    if self.player:Health() > 0 then SafeRemoveEntity( self ) return true end

end

function ENT:SetupPlayer( _ )
    self.player.screamerCrate = self
    self.player.ghostEnt = self

end

if SERVER then
    function ENT:HandleKeys( _, key )
        if ( self.nextPlaceThink or 0 ) > CurTime() then return end

        if key == IN_ATTACK and self:CanPlace( self:GetPos2() ) then
            self:Place()

        end

        if key == IN_ATTACK2 then
            self:Cancel()

        end
    end

    hook.Add( "KeyPress", "glee_doplacables_placing", function( ply, key )
        if not IsValid( ply.ghostEnt ) then return end
        ply.ghostEnt:HandleKeys( ply, key )

    end )
end

function ENT:Think()
    if not IsValid( self.player ) then
        self.player = self:GetOwner() or nil
        self:SetupPlayer( self.player )
        if SERVER then
            for _, currentPly in ipairs( player.GetAll() ) do
                local prevent = self.player ~= currentPly
                self:SetPreventTransmit( currentPly, prevent )

            end
        end
    elseif IsValid( self.player ) and IsValid( self:GetOwner() ) then

        self:ModifiableThink()

        if not SERVER then return end

        local mode = self.player:GetObserverMode()

        if mode ~= OBS_MODE_ROAMING then
            self.nextPlaceThink = CurTime() + 1
            return

        end

    end
end

function ENT:ClientThink()
end

if not SERVER then return end

local GM = GAMEMODE

function GM:ScreamingCrate( pos )
    local crate = ents.Create( "item_item_crate" )
    crate:SetPos( pos )
    crate:SetKeyValue( "ItemClass", "dynamic_super_resupply_fake" ) -- has a good chance to spawn a strong weapon
    crate:SetKeyValue( "ItemCount", 8 )
    crate:Spawn()
    PlayRepeatingSound( crate, "horrific_crate_scream", 20 )
    crate:EmitSound( "npc/turret_floor/deploy.wav", 90, 120 )

    crate.terminatorHunterInnateReaction = function()
        return MEMORY_BREAKABLE
    end

    return crate

end

function ENT:Place()

    local crate = GAMEMODE:ScreamingCrate( self:GetPos2() )
    crate:EmitSound( "items/ammocrate_open.wav", 75 )
    crate.player = self.player

    crate.refundAndBonus = math.Round( self:GetGivenScore() )

    local initialCost = -placingCost

    if crate.refundAndBonus > 0 then
        local hookName = "huntersglee_screamigcrate_recorddamage_" .. crate:GetCreationID()
        hook.Add( "EntityTakeDamage", hookName, function( target, dmg )
            if not IsValid( crate ) then hook.Remove( "EntityTakeDamage", hookName ) return end
            if not crate.refundAndBonus then hook.Remove( "EntityTakeDamage", hookName ) return end
            if crate ~= target then return end

            local attacker = dmg:GetAttacker()

            if not attacker:IsPlayer() then return end
            crate.lastAttacker = attacker

        end )
        crate:CallOnRemove( "identifyifscore", function( crate )
            if crate.refundAndBonus and IsValid( crate.player ) then
                if IsValid( crate.lastAttacker ) and crate.lastAttacker:IsPlayer() then
                    huntersGlee_Announce( { self.player }, 5, 10, "Someone beat the beacon, they took the deposit." )
                    huntersGlee_Announce( { crate.lastAttacker }, 5, 10, "You've recieved " .. placingCost .. " for beating the beacon." )

                    if crate.lastAttacker.GivePlayerScore then
                        crate.lastAttacker:GivePlayerScore( placingCost )

                    end
                else
                    huntersGlee_Announce( { crate.player }, 5, 10, "Your crate was broken early, you are left poorer than before." )

                end
            end
        end, crate )
    end

    if self.player and self.player.GivePlayerScore then
        if crate.refundAndBonus > 0 then
            self.player:GivePlayerScore( initialCost )

        else
            self.player:GivePlayerScore( crate.refundAndBonus )

        end
    end

    SafeRemoveEntity( self )

end