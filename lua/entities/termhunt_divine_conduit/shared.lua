AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Divine Conduit"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Begins a divine conduit"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/tubes/tube1x1x2.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

if SERVER then
    util.AddNetworkString( "glee_nomoredivineconduit" )

end

if CLIENT then
    local nextNoMoreConduit = 0

    net.Receive( "glee_nomoredivineconduit", function()
        if nextNoMoreConduit > CurTime() then return end
        nextNoMoreConduit = CurTime() + 0.1

        local toWipe = net.ReadEntity()
        if IsValid( toWipe ) then
            toWipe:CircleAway()

        end

        if toWipe ~= LocalPlayer().ghostEnt then return end
        LocalPlayer().ghostEnt = nil

    end )

    function ENT:CircleAway()
        if not CLIENT then return end
        if not IsValid( self.circle ) then return end
        SafeRemoveEntity( self.circle )

    end

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
end

function ENT:OnRemove()
    if IsValid( self.circle ) then
        self:CircleAway()

    end
end

function ENT:PostInitializeFunc()
    if not GAMEMODE.ISHUNTERSGLEE then SafeRemoveEntity( self ) return end
    self:SetMaterial( "lights/white001" )

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


local function SparkEffect( SparkPos )
    local Sparks = EffectData()
    Sparks:SetOrigin( SparkPos )
    Sparks:SetMagnitude( 2 )
    Sparks:SetScale( 1 )
    Sparks:SetRadius( 6 )
    util.Effect( "Sparks", Sparks )
end

function ENT:UpdateGivenScore()
    self:SetGivenScore( -600 )

end

function ENT:CalculateCanPlace()
    local checkPos = self:GetPos2() + Vector( 0,0,15 )

    if IsHullTraceFull( checkPos, self.HullCheckSize, self ) then return false, self.noPurchaseReason_NoRoom end
    if getNearestNavFloor( checkPos ) == NULL then return false, self.noPurchaseReason_OffNavmesh end
    if not GAMEMODE:IsUnderSky( checkPos ) then return false, "Needs to be placed under the sky." end
    if GAMEMODE:isTemporaryTrueBool( "terhunt_divine_conduit" ) then return false, "It's too soon for another conduit to form." end
    if not self:HasEnoughToPurchase() then return false, self.noPurchaseReason_TooPoor end
    return true

end

ENT.radius = 1200

function ENT:DoCircle()
    local circle = ClientsideModel( "models/hunter/tubes/tube2x2x025.mdl", RENDERGROUP_OPAQUE )
    circle:SetMaterial( "lights/white001" )
    circle:SetPos( self:GetPos() )
    circle:SetParent( self )
    self:CallOnRemove( "removeradiusthing", function()
        self:CircleAway()
    end )
    self.circle = circle

end

local flatten = Vector( 1,1,0 )
local tinyUpOffset = Vector( 0,0,20 )

function ENT:Place()

    local underSky, strikePos = GAMEMODE:IsUnderSky( self:GetPos() )
    if not underSky then return end

    local betrayalScore = self:GetGivenScore()

    if self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )

    end

    local divineIncrement = 0
    local timerKey = "divineconduit_" .. self:GetCreationID()
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

    huntersGlee_Announce( player.GetAll(), 100, 15, "A DIVINE CONDUIT HAS BEEN OPENED BY " .. string.upper( self.player:Name() ) )

    timer.Create( timerKey, 0.06, 0, function()
        if not IsValid( self ) then timerEnd() return end

        divineIncrement = divineIncrement + 1

        -- sparks
        if divineIncrement < 75 then
            for _ = 1, 2 do
                if math.random( 1, 60 ) > divineIncrement then continue end

                local sparkPos = getRandomSnappedPos()

                if not sparkPos then continue end

                if not GAMEMODE:IsUnderSky( sparkPos ) then continue end

                SparkEffect( sparkPos )
                sound.Play( "LoudSpark", sparkPos )
                sound.EmitHint( SOUND_DANGER, sparkPos, 500, 6, self:GetOwner() )

                if math.random( 0, 100 ) > 50 then continue end

                self:EmitSound( "LoudSpark", 90, 100, 1, CHAN_STATIC )

            end
        -- start striking after 120
        elseif ( divineIncrement > 100 ) and ( divineIncrement < 400 ) then
            if math.random( 175, 400 ) < divineIncrement then return end
            if math.random( 215, 400 ) < divineIncrement then return end

            if math.random( 0, 100 ) >= 28 then return end

            for _ = 1, 2 do
                local strikingPos = getRandomSnappedPos()

                if not strikingPos then return end

                if not GAMEMODE:IsUnderSky( strikingPos ) then return end

                local powa = 5
                if not self.firstPowafulStrike then
                    self.firstPowafulStrike = true
                    powa = 7

                end
                if divineIncrement > 200 then
                    powa = 1.25

                end

                termHunt_PowafulLightning( self.attackerInflictor, self, strikingPos, powa )

            end

        elseif divineIncrement > 400 then
            SafeRemoveEntity( self )
            timerEnd()

        end
    end )

    self.attackerInflictor = self.player

    net.Start( "glee_nomoredivineconduit" )
        net.WriteEntity( self )

    net.Send( self.player )

    self.player.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )

    GAMEMODE:setTemporaryTrueBool( "terhunt_divine_conduit", 240 )

end