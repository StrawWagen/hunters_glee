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

ENT.noPurchaseReason_NoRoom = "No room to place this."
ENT.noPurchaseReason_OffNavmesh = "The hunters can't path to that spot."
ENT.noPurchaseReason_TooPoor = "You're too poor."

ENT.placedItems = 0

sound.Add( {
    name = "horrific_crate_scream",
    channel = CHAN_WEAPON,
    level = 150,
    sound = "hl1/fvox/beep.wav"
} )

function ENT:SetupDataTablesExtra()
end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "CanPlace" )
    self:NetworkVar( "Bool", 1, "InvalidPlacing" )
    self:NetworkVar( "Int", 0, "GivenScore" )
    self:NetworkVar( "Int", 1, "GivenScoreAlt" ) -- for some ents

    self:SetupDataTablesExtra()

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
local deposit = -75
local placingCost = math.abs( deposit )

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

    hook.Add( "HUDPaint", "glee_placablestuff_hudthink", function()
        if not GAMEMODE.CanShowDefaultHud or not GAMEMODE:CanShowDefaultHud() then return end
        if not IsValid( LocalPlayer().ghostEnt ) then return end

        LocalPlayer().ghostEnt:DoHudStuff()

    end )

    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local stringPt1 = ""
        local scoreString = ""
        local placinCostStr = ""

        if scoreGained > 0 then
            stringPt1 = "Projected profit: "
            placinCostStr = "Deposit: " .. tostring( deposit )

            scoreString = stringPt1 .. tostring( scoreGained + deposit )
        else
            stringPt1 = "Hunter luring cost: "
            scoreString = stringPt1 .. tostring( scoreGained )
        end

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )
        surface.drawShadowedTextBetter( placinCostStr, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 60 )

    end
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

        self:doSoundComprehensive()

        if self.player and self.player.GivePlayerScore and self.refundAndBonus and self.refundAndBonus > 0 then
            self.player:GivePlayerScore( self.refundAndBonus )
            huntersGlee_Announce( { self.player }, 5, 15, "The beacon survives, you profit " .. self.refundAndBonus + -placingCost .. " score." )
            self.refundAndBonus = nil

        end

    end )

    self.doSoundComprehensive = function()
        self:doSound( 1 )

        timer.Simple( 0.75, function()
            if not IsValid( self ) then return end
            self:doSound( 1.2 )

        end )
    end

    self.doSound = function( soundEmitter, pitchMul )
        soundEmitter.horrificSound:Stop()
        soundEmitter.horrificSound:PlayEx( 0.7, math.random( 120, 130 ) * pitchMul )

        sound.EmitHint( SOUND_COMBAT, soundEmitter:GetPos(), 20000, 1, soundEmitter )

        soundEmitter:EmitSound( soundPath, 120, math.random( 140, 150 ) * pitchMul, 1, CHAN_STATIC )

        util.ScreenShake( soundEmitter:GetPos(), 1, 20, 1, 1000 )
        local obj = soundEmitter:GetPhysicsObject()
        if not obj then return end
        obj:ApplyForceCenter( VectorRand() * obj:GetMass() * 100 * pitchMul )
        obj:ApplyTorqueCenter( VectorRand() * obj:GetMass() * 100 * pitchMul )

    end

    -- don't play right away
    --self:doSound( soundPath )

    -- Set the timer to repeat the sound
    timer.Create( timerName, soundDuration, 0, function()
        if IsValid( self ) then
            -- Only play the sound if the entity is still valid
            self:doSoundComprehensive()

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

function ENT:ManageMyPos()
    local theNewBestPos = self:bestPosToBe()
    if not theNewBestPos then return end
    self:SetPos( theNewBestPos )

end

function ENT:bestPosToBe()
    local radius = self:GetModelRadius()
    local offset = radius * self.player:GetEyeTrace().HitNormal
    offset.z = math.Clamp( offset.z, -radius, radius * 0.1 )
    if not self.player:GetEyeTrace().Hit then return end

    return self.player:GetEyeTrace().HitPos + offset

end

local vec15Z = Vector( 0,0,15 )

function ENT:CalculateCanPlace()
    local checkPos = self:GetPos2() + vec15Z

    if IsHullTraceFull( checkPos, self.HullCheckSize, self ) then return false, self.noPurchaseReason_NoRoom end
    if getNearestNavFloor( checkPos ) == NULL then return false, self.noPurchaseReason_OffNavmesh end
    if not self:HasEnoughToPurchase() then return false, self.noPurchaseReason_TooPoor end
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

    if self.placedItems <= 0 then
        GAMEMODE:RefundShopItemCooldown( self.player, self.itemIdentifier )

    end

    SafeRemoveEntity( self )

end

function ENT:DoScoreThink()
    self:NextThink( CurTime() + engine.TickInterval() )

    local nextScoreThink = self.nextScoreThink or 0
    if nextScoreThink > CurTime() then return true end
    self.nextScoreThink = CurTime() + 0.15

    self:UpdateGivenScore()

    local canPlace, noBuyReason = self:CalculateCanPlace()
    self.cannotPurchaseReason = noBuyReason

    self:SetCanPlace( canPlace )
    self:ColorThink()

    return true

end

function ENT:ModifiableThink()
    if not SERVER then return end

    if self:AliveCheck() then return end

    self:ManageMyPos()

    return self:DoScoreThink()

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

    local canPlace = self:GetCanPlace()

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
    self.player.ghostEnt = self

end

function ENT:Think()
    local toReturn
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
        toReturn = self:ModifiableThink()

        if CLIENT then
            self:ClientThink()

        elseif SERVER then

            local mode = self.player:GetObserverMode()
            if mode ~= OBS_MODE_ROAMING then
                self.nextPlaceThink = CurTime() + 1
                return

            end

            return toReturn

        end
    end
end

function ENT:ClientThink()
end

if not SERVER then return end

function ENT:PlaceFailed()
    if not self.cannotPurchaseReason then return end
    huntersGlee_Announce( { self.player }, 10, 5, self.cannotPurchaseReason )

end

function ENT:HandleKeys( ply, key )
    if ( self.nextPlaceThink or 0 ) > CurTime() then return end

    if key == IN_ATTACK then
        if self:GetCanPlace() then
            self:Place()
            self.placedItems = self.placedItems + 1
            ply.glee_ghostEntActionTime = CurTime()

        else
            self:PlaceFailed()
            ply.glee_ghostEntActionTime = CurTime()

        end
    end

    if key == IN_ATTACK2 then
        self:Cancel()
        ply.glee_ghostEntActionTime = CurTime()

    end
end

hook.Add( "KeyPress", "glee_doplacables_placing", function( ply, key )
    if not IsValid( ply.ghostEnt ) then return end
    ply.ghostEnt:HandleKeys( ply, key )

end )


local MEMORY_BREAKABLE = 4
local startGivingScoreDist = 3000
local startGivingScoreDistSqr = startGivingScoreDist^2

function ENT:UpdateGivenScore()
    local plys = player.GetAll()
    local smallestDist = math.huge

    for _, currentPly in ipairs( plys ) do
        if currentPly:Health() <= 0 then continue end
        local distToCurrentPlySqr = self:GetPos():DistToSqr( currentPly:GetPos() )
        if distToCurrentPlySqr < smallestDist then
            smallestDist = distToCurrentPlySqr
        end
    end

    if smallestDist > startGivingScoreDistSqr then self:SetGivenScore( -5 ) return end

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

    self:SetGivenScore( scoreGiven )

end

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
        crate:CallOnRemove( "identifyifscore", function( removingCrate )
            if removingCrate.refundAndBonus and IsValid( removingCrate.player ) then
                if IsValid( removingCrate.lastAttacker ) and removingCrate.lastAttacker:IsPlayer() then
                    huntersGlee_Announce( { self.player }, 5, 10, "Someone beat the beacon, they took the deposit." )
                    huntersGlee_Announce( { removingCrate.lastAttacker }, 5, 10, "You've recieved " .. placingCost .. " for beating the beacon." )

                    if removingCrate.lastAttacker.GivePlayerScore then
                        removingCrate.lastAttacker:GivePlayerScore( placingCost )

                    end
                else
                    huntersGlee_Announce( { removingCrate.player }, 5, 10, "Your crate was broken early, you are left poorer than before." )

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