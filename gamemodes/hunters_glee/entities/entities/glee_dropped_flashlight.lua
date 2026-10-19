-- a player's flashlight, dropped by modules/thirdpersonflashlight when they die or get stripped with it on
-- keeps their light and flickers it out over a few seconds, the lamp itself sticks around longer

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Dropped Flashlight"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH -- the glow draws in the translucent pass

function ENT:SetupDataTables()
    self:NetworkVar( "Float", 0, "GlowStrength" )

end

if CLIENT then
    -- drawn with the held lamp's model, our own model scale doesn't network properly
    function ENT:Draw()
        GAMEMODE:GleeDrawFlashlightLamp( self:GetPos(), self:GetAngles() )

    end

    function ENT:DrawTranslucent()
        local forward = self:GetForward()
        local lensPos = self:GetPos() + forward * GAMEMODE.FlashlightLampLensOffset
        GAMEMODE:GleeDrawFlashlightGlow( lensPos, forward, self:GetGlowStrength() )

    end

    return

end

local minLightLifetime = 6
local maxLightLifetime = 12
local despawnTime = 15 -- keep above maxLightLifetime, or the light gets cut off before it flickers out

local minFlickers = 3
local maxFlickers = 6
local gapShrink = 0.6 -- each gap between flickers is this much of the last, so they bunch up toward the end
local endBrightness = 0.05 -- where it settles after the last flicker, right before dying
local maxFlickerDip = 0.3
local minFlickerLength = 0.01
local maxFlickerLength = 0.5

-- when each flicker starts, fit into the light's lifetime
local function scheduleFlickers( startTime, lifetime )
    local count = math.random( minFlickers, maxFlickers )

    -- one more gap than flickers, the last flicker to the light dying
    local gaps = {}
    local gapsTotal = 0
    for i = 1, count + 1 do
        local gap = gapShrink ^ ( i - 1 ) * math.Rand( 0.7, 1.3 )
        gaps[i] = gap
        gapsTotal = gapsTotal + gap

    end

    local flickerTimes = {}
    local time = startTime
    for i = 1, count do
        time = time + gaps[i] / gapsTotal * lifetime
        flickerTimes[i] = time

    end

    return flickerTimes

end

-- steps down the same ratio every flicker, reaching endBrightness after the last
local function settledBrightness( flickersDone, flickerCount )
    return endBrightness ^ ( flickersDone / flickerCount )

end

function ENT:Initialize()
    self:SetModel( GAMEMODE.FlashlightLampModel )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetModelScale( GAMEMODE.FlashlightLampScale, 0 ) -- physics only follow once Activate'd, after Spawn
    self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

    local physObj = self:GetPhysicsObject()
    if IsValid( physObj ) then
        physObj:Wake()

    end

    local cur = CurTime()
    local lightLifetime = math.Rand( minLightLifetime, maxLightLifetime )
    self.glee_LightDieTime = cur + lightLifetime
    self.glee_DespawnTime = cur + despawnTime
    self.glee_FlickerTimes = scheduleFlickers( cur, lightLifetime )
    self.glee_FlickersDone = 0

end

-- theLight should have glee_LightStats from sv_flashlight
function ENT:TakeLight( theLight )
    self.glee_Light = theLight

    theLight:SetParent( self )
    theLight:SetLocalPos( Vector( GAMEMODE.FlashlightLampLensOffset, 0, 0 ) )
    theLight:SetLocalAngles( angle_zero )

    self:SetLightStrength( 1 )

end

-- returns false once the light's gone
function ENT:SetLightStrength( strength )
    local theLight = self.glee_Light
    if not IsValid( theLight ) or not theLight.glee_LightStats then return false end

    self:SetGlowStrength( GAMEMODE:ApplyFlashlightStats( theLight, theLight.glee_LightStats, strength ) )
    return true

end

function ENT:KillLight()
    if IsValid( self.glee_Light ) then
        self:EmitSound( "buttons/lightswitch2.wav", 60, math.random( 110, 130 ), 0.4 )

    end
    SafeRemoveEntity( self.glee_Light )
    self.glee_Light = nil
    self:SetGlowStrength( 0 )

end

-- holds steady between flickers, each flicker dips the light, then it settles a little dimmer than before
function ENT:Think()
    local cur = CurTime()
    if cur >= self.glee_DespawnTime then
        self:Remove()
        return

    end

    if cur >= self.glee_LightDieTime then
        self:KillLight()
        self:NextThink( self.glee_DespawnTime )
        return true

    end

    local flickerTimes = self.glee_FlickerTimes
    local flickerCount = #flickerTimes
    local alive = true

    if self.glee_SettleTime then
        if cur >= self.glee_SettleTime then
            self.glee_SettleTime = nil
            alive = self:SetLightStrength( settledBrightness( self.glee_FlickersDone, flickerCount ) )

        end
    else
        local nextFlicker = flickerTimes[self.glee_FlickersDone + 1]
        if nextFlicker and cur >= nextFlicker then
            local brightnessBefore = settledBrightness( self.glee_FlickersDone, flickerCount )
            self.glee_FlickersDone = self.glee_FlickersDone + 1
            alive = self:SetLightStrength( brightnessBefore * math.Rand( 0, maxFlickerDip ) )
            self.glee_SettleTime = cur + math.Rand( minFlickerLength, maxFlickerLength )

        end
    end

    if not alive then
        self:KillLight()
        self:NextThink( self.glee_DespawnTime )
        return true

    end

    local nextEvent = self.glee_SettleTime or flickerTimes[self.glee_FlickersDone + 1] or self.glee_LightDieTime
    self:NextThink( math.min( nextEvent, self.glee_LightDieTime ) )
    return true

end

function ENT:OnRemove()
    SafeRemoveEntity( self.glee_Light )

end
