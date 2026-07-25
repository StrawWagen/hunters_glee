AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Divine Clap"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "A single, charged strike of lightning"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/tubes/tube1x1x2.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

-- balance knobs, overridable by derived entities ( eg termhunt_thunderous_applause )
local interval = 60 * 4 -- initial lock, and the global cooldown between uses

ENT.baseCost = -500
ENT.heliCostMult = 3 -- cost multiplier when placed near the escape heli
ENT.heliNearbyDist = 2000
ENT.interval = interval
ENT.cooldownBool = "termhunt_divine_clap" -- temporary bool gating reuse
ENT.cooldownMessage = "It's too soon to clap again. Wait."
ENT.mischiefOnPlace = 2
ENT.mischiefReason = "called down a smite"

-- only used by the default ( clap ) telegraph/strike, which derived entities override
local strikePowa = 8
local chargeTime = 3 -- seconds of telegraph before the bolt lands
local sparkRadius = 120 -- max spread of the telegraph sparks from the strike point

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2
        local scoreGained = math.Round( self:GetGivenScore() )
        local stringPt1 = ""
        if scoreGained < 0 then
            stringPt1 = "Cost: "
        end

        local scoreString = stringPt1 .. tostring( scoreGained )

        surface.SetFont( "scoreGainedOnPlaceFont" )
        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

function ENT:PostInitializeFunc()
    if not GAMEMODE.IsReallyHuntersGlee then SafeRemoveEntity( self ) return end
    self:SetMaterial( "lights/white002" )

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
        endpos = pos + Vector( 0, 0, -500 ),
        mask = 131083
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return NULL end
    local navArea = navmesh.GetNearestNavArea( Trace.HitPos, false, 25, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea

end

function ENT:SparkEffect( SparkPos )
    local Sparks = EffectData()
    Sparks:SetOrigin( SparkPos )
    Sparks:SetNormal( VectorRand() )
    Sparks:SetMagnitude( 2 )
    Sparks:SetScale( 1 )
    Sparks:SetRadius( 6 )
    util.Effect( "Sparks", Sparks )

end

function ENT:UpdateGivenScore()
    local cost = self.baseCost
    local heli = terminator_Extras and terminator_Extras.glee_CurrentRescueHeli
    if IsValid( heli ) and heli:GetPos():DistToSqr( self:GetPos() ) < self.heliNearbyDist ^ 2 then
        cost = cost * self.heliCostMult
        self:AddBlameReason( heli, -200, "Escape Heli" )

    end
    self:SetGivenScore( cost )

end

local sv_cheats = GetConVar( "sv_cheats" )

local function isCheats()
    return sv_cheats:GetBool()

end

function ENT:CalculateCanPlace()
    local checkPos = self:OffsettedPlacingPos() + Vector( 0, 0, 15 )

    if IsHullTraceFull( checkPos, self.HullCheckSize, self ) then return false, self.noPurchaseReason_NoRoom end
    if getNearestNavFloor( checkPos ) == NULL then return false, self.noPurchaseReason_OffNavmesh end
    if not GAMEMODE:IsUnderSky( checkPos ) then return false, "Needs to be placed under the sky." end
    if not isCheats() and GAMEMODE:isTemporaryTrueBool( self.cooldownBool ) then return false, self.cooldownMessage end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

local flatten = Vector( 1, 1, 0 )
local tinyUpOffset = Vector( 0, 0, 20 )

-- warn the living standing near the strike, tell the dead what's coming
-- derived entities override this to change the shape/wording of the warning
function ENT:WarnNearbyPlayers( strikePos, placerNick )
    local warningDistSqr = ( strikePowa * 400 ) ^ 2
    local softwarnPlayers = {}
    local hardwarnPlayers = {}
    for _, ply in ipairs( player.GetAll() ) do
        if ply:Health() > 0 then
            if ply:GetPos():DistToSqr( strikePos ) < warningDistSqr then
                table.insert( softwarnPlayers, ply )

            end
        else
            table.insert( hardwarnPlayers, ply )

        end
    end
    huntersGlee_Announce( softwarnPlayers, 100, chargeTime, "Weird, it feels like your hair's standing up..." )
    huntersGlee_Announce( hardwarnPlayers, 100, chargeTime, placerNick .. " has begun a Divine Clap." )

end

-- shared placeable-lightning routine: warn, pay out, detach, then telegraph and strike
-- override WarnNearbyPlayers / BeginStrike to reflavor it
function ENT:Place()

    local underSky = GAMEMODE:IsUnderSky( self:GetPos() )
    if not underSky then return end

    local strikePos = self:GetPos()

    -- who lands the bolt, kept even after we detach from the placer
    self.attackerInflictor = self.player
    local placerNick = IsValid( self.player ) and self.player:Nick() or "Someone"

    self:WarnNearbyPlayers( strikePos, placerNick )

    -- pay out and stir the pot now
    local betrayalScore = self:GetGivenScore()
    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    GAMEMODE:AddMischievousness( self.player, self.mischiefOnPlace, self.mischiefReason )

    -- start the cooldown, then detach so the strike is committed no matter what the placer does
    GAMEMODE:setTemporaryTrueBool( self.cooldownBool, self.interval )

    self:DetachFromOwner()

    self:BeginStrike( strikePos )

end

-- charge for chargeTime, sparks building at the spot, then ONE strike
function ENT:BeginStrike( strikePos )
    local timerKey = "divine_clap_" .. self:GetCreationID()

    local timerEnd = function()
        timer.Stop( timerKey )

    end

    local strikeAt = CurTime() + chargeTime

    timer.Create( timerKey, 0.06, 0, function()
        if not IsValid( self ) then timerEnd() return end

        if CurTime() < strikeAt then
            -- telegraph: sparks get more frequent and wider as the strike nears
            local fraction = 1 - ( ( strikeAt - CurTime() ) / chargeTime ) -- 0 -> 1
            local intensity = math.ease.InExpo( fraction ) -- slow build, then a rush right before the strike

            for _ = 1, 4 do
                if intensity < 0.96 and math.random() > ( intensity + 0.1 ) then continue end

                local offset = VectorRand() * flatten
                offset:Normalize()
                offset = offset * math.random( 0, Lerp( intensity, sparkRadius / 3, sparkRadius ) )

                local sparkPos = strikePos + offset + tinyUpOffset

                if not GAMEMODE:IsUnderSky( sparkPos ) then continue end

                sparkPos = terminator_Extras.getFloorTr( sparkPos ).HitPos

                if GAMEMODE.PanicSource then
                    GAMEMODE:PanicSource( sparkPos, 100, 200 )

                end

                self:SparkEffect( sparkPos )
                sound.Play( "LoudSpark", sparkPos )
                sound.EmitHint( SOUND_DANGER, sparkPos, 500, 6, self.attackerInflictor )

            end
        else
            local lightning = ents.Create( "glee_lightning" )
            lightning:SetOwner( self.attackerInflictor )
            lightning:SetPos( strikePos )
            lightning:SetPowa( strikePowa )
            lightning:Spawn()

            SafeRemoveEntity( self )
            timerEnd()

        end
    end )

end

hook.Add( "huntersglee_round_into_active", "divine_clap_initialwait", function()
    GAMEMODE:setTemporaryTrueBool( "termhunt_divine_clap_initial", interval )
    GAMEMODE:setTemporaryTrueBool( "termhunt_divine_clap", interval )

end )
