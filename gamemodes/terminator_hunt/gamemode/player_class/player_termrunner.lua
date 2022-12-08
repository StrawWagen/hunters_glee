AddCSLuaFile( "player_termrunner.lua" )
DEFINE_BASECLASS( "player_default" )

local PLAYER = {}

PLAYER.DuckSpeed            = 0.1        -- How fast to go from not ducking, to ducking
PLAYER.UnDuckSpeed            = 0.1        -- How fast to go from ducking, to not ducking

--
-- Creates a Taunt Camera
--
PLAYER.TauntCam = TauntCamera()

--
-- See gamemodes/base/player_class/player_default.lua for all overridable variables
--
PLAYER.SlowWalkSpeed        = 100
PLAYER.WalkSpeed             = 200 * 0.9
PLAYER.RunSpeed                = 400 * 0.85

--
-- Set up the network table accessors
--
function PLAYER:SetupDataTables()
    BaseClass.SetupDataTables( self )

end


function PLAYER:Loadout()
    self.Player:Give( "termhunt_hands" )
    self.Player:Give( "termhunt_shove" )
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

end

--
-- Return true to draw local (thirdperson) camera - false to prevent - nothing to use default behaviour
--
function PLAYER:ShouldDrawLocal()

    if ( self.TauntCam:ShouldDrawLocalPlayer( self.Player, self.Player:IsPlayingTaunt() ) ) then return true end

end

--
-- Allow player class to create move
--
function PLAYER:CreateMove( cmd )

    if ( self.TauntCam:CreateMove( cmd, self.Player, self.Player:IsPlayingTaunt() ) ) then return true end

end

--
-- Allow changing the player's view
--
function PLAYER:CalcView( view )

    if ( self.TauntCam:CalcView( view, self.Player, self.Player:IsPlayingTaunt() ) ) then return true end

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
    if bit.band( move:GetButtons(), IN_JUMP ) ~= 0 and bit.band( move:GetOldButtons(), IN_JUMP ) == 0 and self.Player:OnGround() then
        JUMPING = true
    end

end

function PLAYER:FinishMove( move )

    -- If the player has jumped this frame
    if ( JUMPING ) then
        -- Get their orientation
        local forward = move:GetAngles()
        forward.p = 0
        forward = forward:Forward()

        -- Compute the speed boost

        -- HL2 normally provides a much weaker jump boost when sprinting
        -- For some reason this never applied to GMod, so we won't perform
        -- this check here to preserve the "authentic" feeling
        local speedBoostPerc = ( ( not self.Player:Crouching() ) and 0.5 ) or 0.1

        local speedAddition = math.abs( move:GetForwardSpeed() * speedBoostPerc )
        local maxSpeed = move:GetMaxSpeed() * ( 1 + speedBoostPerc )
        local newSpeed = speedAddition + move:GetVelocity():Length2D()

        -- Clamp it to make sure they can't bunnyhop to ludicrous speed
        if newSpeed > maxSpeed then
            speedAddition = speedAddition - (newSpeed - maxSpeed)
        end

        -- Reverse it if the player is running backwards
        if move:GetVelocity():Dot(forward) < 0 then
            speedAddition = -speedAddition
        end

        -- Apply the speed boost
        move:SetVelocity(forward * speedAddition + move:GetVelocity())
    end

    JUMPING = nil

end

player_manager.RegisterClass( "player_termrunner", PLAYER, "player_default" )