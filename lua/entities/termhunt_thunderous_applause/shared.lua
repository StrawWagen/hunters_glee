AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "glee_divine_clap"

ENT.PrintName   = "Divine Applause"
ENT.Purpose     = "Applause of the highest order"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()

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

-- a sustained barrage of strikes scattered across the radius, instead of one bolt
function ENT:BeginStrike( strikePos )
    local divineIncrement = 0
    local timerKey = "thunderousapplause_" .. self:GetCreationID()
    local strikeRad = self.radius

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

    local max = 300

    timer.Create( timerKey, 0.06, 0, function()
        if not IsValid( self ) then timerEnd() return end

        divineIncrement = divineIncrement + 1

        -- sparks
        if divineIncrement < 70 then
            for _ = 1, 2 do
                if math.random( 1, 60 ) > divineIncrement then continue end

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
        -- start striking after 80
        elseif ( divineIncrement > 80 ) and ( divineIncrement < max ) then
            if math.random( 110, max ) < divineIncrement then return end
            if math.random( 150, max ) < divineIncrement then return end

            if math.random( 0, 100 ) >= 40 then return end

            for _ = 1, 2 do
                local strikingPos = getRandomSnappedPos()

                if not strikingPos then return end

                if not GAMEMODE:IsUnderSky( strikingPos ) then return end

                local powa = math.random( 1, 4 )
                if not self.firstPowafulStrike then
                    self.firstPowafulStrike = true
                    powa = 7

                end
                if divineIncrement > 140 then
                    powa = 0.75

                end

                local lightning = ents.Create( "glee_lightning" )
                lightning:SetOwner( self.attackerInflictor )
                lightning:SetPos( strikingPos )
                lightning:SetPowa( powa )
                lightning:Spawn()

            end

        elseif divineIncrement > max then
            SafeRemoveEntity( self )
            timerEnd()

        end
    end )

end

hook.Add( "huntersglee_round_into_active", "thunderous_applause_initialwait", function()
    GAMEMODE:setTemporaryTrueBool( "termhunt_thunderous_applause_initial", interval )
    GAMEMODE:setTemporaryTrueBool( "termhunt_thunderous_applause", interval )

end )
