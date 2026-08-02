AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "glee_divine_clap"

ENT.PrintName   = "Divine Applause"
ENT.Purpose     = "Applause of the highest order"
ENT.Category    = "Hunter's Glee"
ENT.Spawnable   = true
ENT.AdminOnly   = game.IsDedicated()

-- many claps that land over a wide area
local interval = 60 * 2

ENT.baseCost = -600
ENT.heliCostMult = 4
ENT.heliNearbyDist = 3000
ENT.interval = interval
ENT.cooldownBool = "termhunt_thunderous_applause"
ENT.cooldownMessage = "Applause was just recently given. Wait until it's time again."
ENT.mischiefOnPlace = 10
ENT.mischiefReason = "applauded thunderously"
ENT.radius = 1050

if CLIENT then
    function ENT:OnDetachedFromOwner()
        self:CircleAway()

    end
    function ENT:CircleAway()
        if not CLIENT then return end
        if not IsValid( self.circle ) then return end
        SafeRemoveEntity( self.circle )

    end

    function ENT:ClientThink()
        if not IsValid( self.player ) then self:CircleAway() return end
        if LocalPlayer() ~= self.player then self:CircleAway() return end
        if not LocalPlayer().ghostEnt or LocalPlayer().ghostEnt ~= self then self:CircleAway() return end

        local circle = self.circle
        if not IsValid( circle ) then
            self:DoCircle()

        elseif not IsValid( circle:GetParent() ) then
            self:CircleAway()

        else
            local oldColor = circle.oldColor
            if not oldColor then
                oldColor = circle:GetColor()
            end

            local newColor = self:GetColor()

            if oldColor ~= newColor then
                circle:SetColor( newColor )

            end
            circle.oldColor = newColor

            local scale = self.radius / circle:GetModelRadius()
            local oldScale = circle.oldScale or 0
            if scale ~= oldScale then
                circle.oldScale = scale
                local matrix = Matrix()
                matrix:Scale( Vector( scale, scale, 0.1 ) )
                circle:EnableMatrix( "RenderMultiply", matrix )

            end
        end
    end

    function ENT:DoCircle()
        local circle = ClientsideModel( "models/hunter/tubes/tube2x2x025.mdl", RENDERGROUP_OPAQUE )
        circle:SetMaterial( "lights/white002" )
        circle:SetPos( self:GetPos() )
        circle:SetParent( self )
        self:CallOnRemove( "removeradiusthing", function()
            self:CircleAway()
        end )
        self.circle = circle

    end
end

function ENT:OnRemove()
    if IsValid( self.circle ) then
        self:CircleAway()

    end
end

local flatten = Vector( 1, 1, 0 )
local tinyUpOffset = Vector( 0, 0, 20 )
local tallOblong = Vector( 1, 1, 4 )

-- wider, mentos-shaped warning volume, and applause-flavored wording
function ENT:WarnNearbyPlayers( strikePos, placerNick )
    local warningDist = self.radius * 4
    local softwarnPlayers = {}
    local hardwarnPlayers = {}
    for _, ply in ipairs( player.GetAll() ) do
        if ply:Health() > 0 then
            local subtProduct = ply:GetPos() - strikePos
            subtProduct = subtProduct * tallOblong
            if subtProduct:LengthSqr() < warningDist then
                table.insert( softwarnPlayers, ply )

            end
        else
            table.insert( hardwarnPlayers, ply )

        end
    end
    huntersGlee_Announce( softwarnPlayers, 100, 15, "Something isn't right...\nYour hair is standing on end... " )
    huntersGlee_Announce( hardwarnPlayers, 100, 15, placerNick .. " is.. Applauding! Thunderously!" )

end

-- The applause timeline, as the length of each phase.
local tickRate          = 0.06
local baseSparkRampTime = 6         -- sparks climb from never to every tick across this
local baseSparkRampTimeNoPlys = baseSparkRampTime * 0.25 -- faster striking if nobodys nearby
local sparkFullTime     = 0.6       -- sparks every tick, once the ramp is done
local silenceTime       = 0.6       -- dead air between the last spark and the first bolt
local strikesFullTime   = 2
local strikesThinTime   = 1.8       -- getting rarer, but the bolts are still strong
local weakStrikesTime   = 0.6       -- past here every bolt is a weak one
local strikesTailTime   = 9         -- second fade stacks onto the first, so it peters out

-- a sustained barrage of strikes scattered across the radius, instead of one bolt
function ENT:BeginStrike( strikePos )
    local startTime = CurTime()
    local timerKey = "thunderousapplause_" .. self:GetCreationID()
    local strikeRad = self.radius

    local sparkRampTime = baseSparkRampTimeNoPlys
    local _, nearestPlyDistSqr = GAMEMODE:nearestAlivePlayer( self:GetPos() )
    if nearestPlyDistSqr < ( strikeRad * 1.75 ) ^ 2 then
        sparkRampTime = baseSparkRampTime

    end

    local sparksEndTime       = sparkRampTime + sparkFullTime
    local strikesStartTime    = sparksEndTime + silenceTime
    local strikesThinFrom     = strikesStartTime + strikesFullTime
    local weakStrikesFrom     = strikesThinFrom + strikesThinTime
    local strikesThinHardFrom = weakStrikesFrom + weakStrikesTime
    local applauseEndTime     = strikesThinHardFrom + strikesTailTime

    local timerEnd = function()
        timer.Stop( timerKey )

    end
    local getRandomSnappedPos = function()
        local offset = VectorRand() * flatten
        offset:Normalize()
        offset = offset * math.random( 0, strikeRad )

        local miniOffset = VectorRand() * math.random( 10, 40 )
        miniOffset = miniOffset * flatten

        local sparkPos = strikePos + offset
        local result = GAMEMODE:getNearestNavFloor( sparkPos, 6000 )

        if not result or not result.IsValid or not result:IsValid() then return end
        sparkPos = result:GetClosestPointOnArea( sparkPos )

        return ( sparkPos + miniOffset ) + tinyUpOffset

    end

    timer.Create( timerKey, tickRate, 0, function()
        if not IsValid( self ) then timerEnd() return end

        local elapsed = CurTime() - startTime

        -- sparks
        if elapsed < sparksEndTime then
            for _ = 1, 2 do
                if math.Rand( 0, sparkRampTime ) > elapsed then continue end

                local sparkPos = getRandomSnappedPos()

                if not sparkPos then continue end

                if not GAMEMODE:IsUnderSky( sparkPos ) then continue end

                if GAMEMODE.PanicSource then
                    GAMEMODE:PanicSource( sparkPos, 100, 200 )

                end
                self:SparkEffect( sparkPos )
                sound.Play( "LoudSpark", sparkPos )
                sound.EmitHint( SOUND_DANGER, sparkPos, 500, 6, self.attackerInflictor )

                if math.random( 0, 100 ) > 50 then continue end

                self:EmitSound( "LoudSpark", 90, 100, 1, CHAN_STATIC )

            end
        elseif ( elapsed > strikesStartTime ) and ( elapsed < applauseEndTime ) then
            if math.Rand( strikesThinFrom, applauseEndTime ) < elapsed then return end
            if math.Rand( strikesThinHardFrom, applauseEndTime ) < elapsed then return end

            if math.random( 0, 100 ) >= 40 then return end

            for _ = 1, 2 do
                local strikingPos = getRandomSnappedPos()

                if not strikingPos then return end

                if not GAMEMODE:IsUnderSky( strikingPos ) then return end

                local powa = math.Rand( 1, 5.5 )
                if not self.firstPowafulStrike then
                    self.firstPowafulStrike = true
                    powa = 8

                end
                if elapsed > weakStrikesFrom then
                    powa = 0.75

                end

                local lightning = ents.Create( "glee_lightning" )
                lightning:SetOwner( self.attackerInflictor )
                lightning:SetPos( strikingPos )
                lightning:SetPowa( powa )
                lightning:Spawn()

            end

        elseif elapsed > applauseEndTime then
            SafeRemoveEntity( self )
            timerEnd()

        end
    end )

end

hook.Add( "huntersglee_round_into_active", "thunderous_applause_initialwait", function()
    GAMEMODE:setTemporaryTrueBool( "termhunt_thunderous_applause_initial", interval )
    GAMEMODE:setTemporaryTrueBool( "termhunt_thunderous_applause", interval )

end )
