AddCSLuaFile()
DEFINE_BASECLASS( "player_sandbox" )
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
