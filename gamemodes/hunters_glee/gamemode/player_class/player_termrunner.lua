AddCSLuaFile()
DEFINE_BASECLASS( "player_default" )
include( "player_termrunnertaunt.lua" )
local PLAYER = {}

PLAYER.DuckSpeed            = 0.1        -- How fast to go from not ducking, to ducking
PLAYER.UnDuckSpeed          = 0.1        -- How fast to go from ducking, to not ducking

--
-- Creates a Taunt Camera
--
PLAYER.TauntCam = GLEE_TauntCamera()

--
-- See gamemodes/base/player_class/player_default.lua for all overridable variables
--
PLAYER.SlowWalkSpeed        = 100
PLAYER.WalkSpeed             = 200 * 0.75 -- was 0.9
PLAYER.RunSpeed                = 400 * 0.75 -- was 0.85, then was 0.75, back to 0.85, back to 0.75


function PLAYER:SetupPlayerFuncsCheck()
    local realPlayer = self.Player
    if not IsValid( realPlayer ) then return end

    if realPlayer.isSetup then return end
    realPlayer.isSetup = true

    realPlayer.shopItemCooldowns = {}

    realPlayer.AddRespawnFunction = function( onRespawn )

        realPlayer.onRespawnFunctions = realPlayer.onRespawnFunctions or {}

        table.insert( realPlayer.onRespawnFunctions, onRespawn )

    end

    realPlayer.Resurrect = function()
        if not realPlayer.unstuckOrigin then return end

        hook.Run( "termhunt_plyresurrected", realPlayer )

        GAMEMODE:unspectatifyPlayer( realPlayer )
        realPlayer:Spawn()

    end
end


--
-- Set up the network table accessors
--
function PLAYER:SetupDataTables()
    BaseClass.SetupDataTables( self )

end


function PLAYER:Loadout()
    self.Player:Give( "termhunt_shove" )
    self.Player:Give( "termhunt_radio" )
    self.Player:Give( "weapon_crowbar" )

    self.Player:SelectWeapon( "weapon_crowbar" )

end

function PLAYER:SetModel()
    BaseClass.SetModel( self )

end

--
-- Called when the player spawns
--
function PLAYER:Spawn()
    BaseClass.Spawn( self )

    self:SetupPlayerFuncsCheck()

    local realPlayer = self.Player
    -- something has gone horribly wrong
    if not IsValid( realPlayer ) then return end
    realPlayer:unstuckFullHandle()

    if not realPlayer.realRespawn then return end

    -- hook + weird table of functions
    hook.Run( "termhunt_realrespawn", realPlayer )

end

--
-- Return true to draw local (thirdperson) camera - false to prevent - nothing to use default behaviour
--
function PLAYER:ShouldDrawLocal()

    if ( self.TauntCam:ShouldDrawLocalPlayer( self.Player, self.Player:IsPlayingTaunt2() ) ) then return true end

end

--
-- Allow player class to create move
--
function PLAYER:CreateMove( cmd )

    if ( self.TauntCam:CreateMove( cmd, self.Player, self.Player:IsPlayingTaunt2() ) ) then return end

end

--
-- Allow changing the player's view
--
function PLAYER:CalcView( view )

    if ( self.TauntCam:CalcView( view, self.Player, self.Player:IsPlayingTaunt2() ) ) then return true end

    -- Your stuff here

end

function PLAYER:GetHandsModel()

    -- return { model = "models/weapons/c_arms_cstrike.mdl", skin = 1, body = "0100000" }

    local cl_playermodel = self.Player:GetInfo( "cl_playermodel" )
    return player_manager.TranslatePlayerHands( cl_playermodel )

end

--
-- Reproduces the jump boost from HL2 singleplayer
--
local JUMPING

function PLAYER:StartMove( move )

    -- Only apply the jump boost in FinishMove if the player has jumped during this frame
    -- Using a global variable is safe here because nothing else happens between SetupMove and FinishMove
    -- IS IT SAFE THO?
    if bit.band( move:GetButtons(), IN_JUMP ) ~= 0 and bit.band( move:GetOldButtons(), IN_JUMP ) == 0 and self.Player:OnGround() then
        JUMPING = true
    end

end

function PLAYER:FinishMove( move )

    -- If the player has jumped this frame
    if JUMPING and not self.Player:Crouching() then
        -- Get their orientation
        local forward = move:GetAngles()
        forward.p = 0
        forward = forward:Forward()

        -- Compute the speed boost

        -- HL2 normally provides a much weaker jump boost when sprinting
        -- For some reason this never applied to GMod, so we won't perform
        -- this check here to preserve the "authentic" feeling
        local speedBoostPerc = 0.065

        local speedAddition = math.abs( move:GetForwardSpeed() * speedBoostPerc )
        local maxSpeed = move:GetMaxSpeed() * ( 1 + speedBoostPerc )
        local newSpeed = speedAddition + move:GetVelocity():Length2D()

        -- Clamp it to make sure they can't bunnyhop to ludicrous speed
        if newSpeed > maxSpeed then
            speedAddition = speedAddition - ( newSpeed - maxSpeed )
        end

        -- Reverse it if the player is running backwards
        if move:GetVelocity():Dot( forward ) < 0 then
            speedAddition = -speedAddition
        end

        -- Apply the speed boost
        move:SetVelocity( forward * speedAddition + move:GetVelocity() )
    end

    JUMPING = nil

end

player_manager.RegisterClass( "player_termrunner", PLAYER, "player_default" )

-- put this here instead of making new file for shared player stuff
-- TODO: new shared file for player stuff....
local meta = FindMetaTable( "Player" )

function meta:GetScore()
    return self:GetNWInt( "huntersglee_score", 0 )

end

function meta:GetSkulls()
    return self:GetNWInt( "huntersglee_skulls", 0 )

end

if SERVER then
    function meta:GivePlayerScore( add )
        if hook.Run( "huntersglee_givescore", self, add ) == false then return end
        local score = self:GetScore()
        self:SetNWInt( "huntersglee_score", math.Round( score + add ) )
    end

    function meta:GivePlayerSkulls( add )
        if hook.Run( "huntersglee_giveskulls", self, add ) == false then return end
        local skulls = self:GetSkulls()
        self:SetNWInt( "huntersglee_skulls", math.Round( skulls + add ) )
    end

    function meta:ResetScore()
        self:SetNWInt( "huntersglee_score", 0 )

    end

    function meta:ResetSkulls()
        self:SetNWInt( "huntersglee_skulls", 0 )

    end


    function meta:TeleportTo( pos )
        self.unstuckOrigin = pos
        self:SetPos( pos )
        self:unstuckFullHandle()

        timer.Simple( 0.5, function()
            if not IsValid( ply ) then return end
            if ply:GetPos():DistToSqr( pos ) < 750^2 then return end

            -- didnt teleport ply... try AGAIN!
            self.unstuckOrigin = pos
            self:SetPos( pos )
            self:unstuckFullHandle()

        end )
    end

    function meta:BeginUnstuck()
        self.unstuckOrigin = nil
        self:unstuckFullHandle()

    end


    function meta:IsStuckBasic()
        if self:IsOnGround() then return end

        -- 15^2
        if self:GetVelocity():LengthSqr() > 225 then return end
        local move = self:GetMoveType()
        if move == MOVETYPE_NOCLIP then return end
        if move == MOVETYPE_LADDER then return end

        return true

    end


    -- this func should be ran after player's pos is set
    function meta:unstuckFullHandle()
        timer.Simple( 0.1, function()
            if not self:IsValid() then return end
            self.glee_Unstucking = true
            local shouldBeValid

            local origin = self.unstuckOrigin or self:GetPos()
            local result = self:checkIfPlyIsStuckAndHandle( origin )

            -- they are stuck
            if result == true then
                -- recursive yay
                self:unstuckFullHandle()

            -- not stuck anymore!!! break the recursion!
            elseif result == false then
                if self.unstuckOrigin ~= nil then
                    self.unstuckOrigin = nil

                end
                self.glee_Unstucking = nil
                shouldBeValid = true

            end
            if shouldBeValid then
                timer.Simple( 0.1, function()
                    if not IsValid( self ) then return end
                    if self:IsStuckBasic() then
                        -- oops im actually still stuck
                        self:unstuckFullHandle()

                    end
                end )
            end
        end )
    end

    -- take a player's pos, then iterate until we find a pos that is,
        -- empty, nothing there already
        -- not under a displacement

    -- starts off checking right next to player, then goes crazy and checks far away

    function meta:checkIfPlyIsStuckAndHandle( overridePos )

        local unstuckOrigin = overridePos or self:GetPos()
        local thePos = nil

        local minBound, maxBound = self:GetCollisionBounds()
        minBound = minBound * 1.1
        maxBound = maxBound * 1.1

        local plyHeightOffset = Vector( 0, 0, maxBound.z )

        minBound.z = -4
        maxBound.z = 4
        local randomOffset = Vector( 0, 0, 0 )
        -- lots of traces for 1 tick lol
        local max = 1500
        local doBigCheck = max * 0.5

        for index = 0, max do

            local scalar = 0.5
            -- nothing close, go ham
            if index > doBigCheck then
                scalar = math.Rand( 0.5, 4 )

            end

            local randomOffsetScale = index * scalar
            local randomDirection = VectorRand( -1, 1 )
            randomOffset = randomDirection * randomOffsetScale
            local potentiallyClearPos = unstuckOrigin + randomOffset

            local contents = util.PointContents( potentiallyClearPos )
            local isSolidOrClipped = bit.band( contents, CONTENTS_SOLID ) ~= 0 or bit.band( contents, CONTENTS_PLAYERCLIP ) ~= 0

            if isSolidOrClipped then continue end

            local startPos = potentiallyClearPos + plyHeightOffset
            local endPos = potentiallyClearPos

            local traceDataDown = {}
            traceDataDown.start = startPos
            traceDataDown.endpos = endPos
            traceDataDown.filter = self
            traceDataDown.mask = MASK_PLAYERSOLID
            traceDataDown.mins = minBound
            traceDataDown.maxs = maxBound

            local trace = util.TraceHull( traceDataDown )

            if trace.Hit or trace.StartSolid or GAMEMODE:IsUnderDisplacementExtensive( potentiallyClearPos ) then continue end

            if index == 0 then
                -- ply is not stuck
                return false

            end

            -- ok we are stuck
            -- do a reverse trace because sometimes ppls heads get stuck inside displacement roofs
            local traceDataUp = {}
            traceDataUp.start = endPos
            traceDataUp.endpos = startPos
            traceDataUp.filter = self
            traceDataUp.mask = MASK_PLAYERSOLID
            traceDataUp.mins = minBound
            traceDataUp.maxs = maxBound

            local traceUp = util.TraceHull( traceDataUp )

            if traceUp.Hit or traceUp.StartSolid then continue end

            local finalClipCheck = {}
            finalClipCheck.start = unstuckOrigin + terminator_Extras.dirToPos( unstuckOrigin, potentiallyClearPos ) * 35
            finalClipCheck.endpos = potentiallyClearPos
            finalClipCheck.mins = minBound
            finalClipCheck.maxs = maxBound
            finalClipCheck.mask = CONTENTS_PLAYERCLIP

            local finalClipCheckResult = util.TraceHull( finalClipCheck )

            -- this pos would send us through a player clip ( just a sanity check, will fail if eg, a corner exists )
            if finalClipCheckResult.Hit then continue end

            -- we were stuck and this spot will set us free
            thePos = potentiallyClearPos
            break

        end

        if thePos then
            -- ply is not stuck anymore
            self:SetPos( thePos )
            --debugoverlay.Cross( thePos, 10, 10, color_white, true )
            hook.Run( "termhunt_plyescapestuck", self, unstuckOrigin, thePos )
            return false

        else
            -- ply is still stuck
            return true

        end
    end

    function meta:GetNavAreaData()
        if not self.glee_CachedNavArea then
            self:CacheNavArea()

        end
        return self.glee_CachedNavArea, self.glee_SqrDistToCachedNavArea

    end

    function meta:CacheNavArea()
        local myPos = self:GetPos()
        if not util.IsInWorld( myPos ) then
            self.glee_CachedNavArea = nil
            self.glee_SqrDistToCachedNavArea = math.huge
            return

        end
        local area = navmesh.GetNearestNavArea( myPos, true, navCheckDist, true, true )
        self.glee_CachedNavArea = area
        if area then
            self.glee_SqrDistToCachedNavArea = myPos:DistToSqr( area:GetClosestPointOnArea( myPos ) )

        else
            self.glee_SqrDistToCachedNavArea = math.huge

        end
    end

    hook.Add( "glee_sv_validgmthink", "glee_manageunstucking", function( players )
        for _, ply in ipairs( players ) do
            if ply:Health() > 0 then
                local basicStuckCount = ply.glee_basicStuckCount or 0
                -- do not interrupt current unstuck
                if ply.glee_Unstucking then
                    ply.glee_basicStuckCount = 0

                elseif basicStuckCount > 20 then
                    ply.glee_basicStuckCount = 0
                    ply:unstuckFullHandle()
                    ply:EmitSound( "physics/rubber/rubber_tire_impact_hard2.wav", 65, math.random( 80, 100 ) )

                    print( "GLEE: unstucking " .. ply:Name() )

                elseif ply:IsStuckBasic() then
                    ply.glee_basicStuckCount = basicStuckCount + 1

                    if basicStuckCount > 10 and not ply.glee_doneUnstuckWarn then
                        ply:EmitSound( "physics/cardboard/cardboard_box_impact_hard6.wav", 65, math.random( 50, 60 ) )
                        ply.glee_doneUnstuckWarn = true

                    end
                elseif basicStuckCount > 0 then
                    ply.glee_basicStuckCount = 0
                    ply.glee_doneUnstuckWarn = nil

                end
            end
        end
    end )
end

