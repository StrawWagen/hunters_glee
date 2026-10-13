AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName   = "Crate Beacon"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Puts a supply crate on the HUD of everyone near it. Shoot it off."
ENT.Category    = "Hunter's Glee"
ENT.Spawnable   = true
ENT.AdminOnly   = game.IsDedicated()
ENT.Model       = "models/props_lab/reciever01b.mdl"

sound.Add( {
    name = "horrific_crate_scream",
    channel = CHAN_WEAPON,
    level = 150,
    sound = "hl1/fvox/beep.wav"
} )

function ENT:SetupDataTables()
    self:NetworkVar( "Int", "ChargedUntil" )
    if SERVER then
        self:SetChargedUntil( CurTime() + 1 )

    end
end

-- cl_plynames module draws a name panel for anything with a Nick
function ENT:Nick()
    if self:GetChargedUntil() < CurTime() then return end
    return "!!!"

end

local beaconColor = Vector( 255, 190, 0 ) / 255
function ENT:GetPlayerColor()
    if self:GetChargedUntil() < CurTime() then return end
    return beaconColor

end


if not SERVER then return end

-- Beeps hunters over to its crate, only while on it. A ghost's beacon holds their deposit until
-- its first beep: survive to it and the placer's paid back, break it or its crate first and that player takes it.
-- Knocked off, it goes dark, left to be found and smashed for its battery

-- a couple of shots, it exists to be taken off the crate
ENT.BeaconHealth = 10

local beepInterval = 20
local beepsPerCrate = 10
local firstBeepDelay = beepInterval * 0.35

-- vel of battery when this breaks
local batteryPop = Vector( 0, 0, 110 )

function ENT:Initialize()
    self:SetModel( self.Model )
    self:PhysicsInit( SOLID_VPHYSICS )

    -- the panel hides anything on 0 health, and prints Health/GetMaxHealth when looked at
    self:SetMaxHealth( self.BeaconHealth )
    self:SetHealth( self.BeaconHealth )

    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) then return end

    phys:SetMass( 15 )

end

function ENT:DropBattery()
    local battery = ents.Create( "item_battery" )
    if not IsValid( battery ) then return end

    battery:SetPos( self:WorldSpaceCenter() )
    battery:SetAngles( AngleRand() )
    battery:Spawn()

    local phys = battery:GetPhysicsObject()
    if not IsValid( phys ) then return end

    phys:SetVelocity( VectorRand() * 30 + batteryPop )

end

function ENT:BeepTimerName()
    return "glee_cratebeacon_beep_" .. self:GetCreationID()

end

function ENT:Beep( pitchMul )
    local crate = self:GetParent()
    if not IsValid( crate ) then return end

    local everyone = RecipientFilter()
    everyone:AddAllPlayers()
    local scream = CreateSound( self, "horrific_crate_scream", everyone )
    scream:Stop()
    scream:PlayEx( 0.7, math.random( 120, 130 ) * pitchMul )

    local cratePos = crate:GetPos()

    sound.EmitHint( SOUND_COMBAT, cratePos, 20000, 1, crate )
    self:EmitSound( "horrific_crate_scream", 120, math.random( 140, 150 ) * pitchMul, 1, CHAN_STATIC )
    util.ScreenShake( cratePos, 1, 20, 1, 1000 )

    local obj = crate:GetPhysicsObject()
    if not IsValid( obj ) then return end

    local force = obj:GetMass() * 100 * pitchMul
    obj:ApplyForceCenter( VectorRand() * force )
    obj:ApplyTorqueCenter( VectorRand() * force )

end

-- two beeps, the second higher, so people can turn their heads, find the supplies easier
function ENT:BeepTwice()
    self:Beep( 1 )

    timer.Simple( 0.75, function()
        if not IsValid( self ) then return end
        if not self:IsTransmitting() then return end

        self:Beep( 1.2 )

    end )
end

function ENT:IsTransmitting()
    return self:GetChargedUntil() > CurTime()

end

-- Call once it's on its crate. placer and refundAndBonus are nil for crates nobody placed,
-- they beep without a deposit riding on them
function ENT:StartTransmitting( placer, refundAndBonus, deposit )
    if refundAndBonus and refundAndBonus > 0 then
        self.placer = placer
        self.refundAndBonus = refundAndBonus
        self.deposit = deposit

    end

    self:SetChargedUntil( CurTime() + firstBeepDelay + beepsPerCrate * beepInterval + 1 )

    local timerName = self:BeepTimerName()
    timer.Create( timerName, firstBeepDelay, 1, function()
        if not IsValid( self ) then return end

        self:BeepTwice()
        self:PayPlacer()

        timer.Create( timerName, beepInterval, beepsPerCrate, function()
            if not IsValid( self ) then return end
            self:BeepTwice()

        end )
    end )
end

-- off the HUD, and silent, for good
function ENT:GoDark()
    self:SetChargedUntil( 0 )
    timer.Remove( self:BeepTimerName() )

end

-- refundAndBonus is the flag as well as the amount, whatever settles the deposit clears it
function ENT:PayPlacer()
    local bonus = self.refundAndBonus
    if not bonus then return end
    self.refundAndBonus = nil

    local placer = self.placer
    if not IsValid( placer ) then return end

    placer:GivePlayerScore( bonus )
    GAMEMODE:SendPlacableScorePopup( placer, self, bonus )
    huntersGlee_Announce( { placer }, 5, 10, "The beacon survives, you profit " .. bonus - self.deposit .. " score." )
    GAMEMODE:LearnLesson( placer, "BeaconSurvived" ) -- they've done it once, stop explaining the deposit

end

function ENT:LoseDeposit( culprit )
    if not self.refundAndBonus then return end
    self.refundAndBonus = nil

    local placer = self.placer
    local thief = IsValid( culprit ) and culprit:IsPlayer() and culprit ~= placer and culprit or nil

    if thief then
        thief:GivePlayerScore( self.deposit )
        huntersGlee_Announce( { thief }, 5, 11, "You've recieved " .. self.deposit .. " for beating the beacon." )

    end

    if not IsValid( placer ) then return end

    if thief then
        huntersGlee_Announce( { placer }, 5, 10, thief:Nick() .. " beat the beacon, they took the deposit." )

    else
        huntersGlee_Announce( { placer }, 5, 10, "Your beacon was beaten early, you are left poorer than before." )

    end
end

-- its crate broke out from under it
function ENT:CrateBroken( breaker )
    self:LoseDeposit( breaker )
    self:GoDark()

    terminator_Extras.ParentedDetailFallOff( self:GetParent(), self, false )

end

function ENT:OnRemove()
    -- removed without breaking, eg cleanup, nobody won or lost anything
    self.refundAndBonus = nil
    self:GoDark()

end

function ENT:Break()
    self:LoseDeposit( self.lastAttacker )
    self:GoDark()

    self:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav", 75, 90 )

    local sparks = EffectData()
    sparks:SetOrigin( self:WorldSpaceCenter() )
    sparks:SetMagnitude( 2 )
    sparks:SetScale( 1 )
    sparks:SetRadius( 2 )
    util.Effect( "Sparks", sparks )

    self:DropBattery()

    SafeRemoveEntity( self )

end

function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )

    local attacker = dmg:GetAttacker()
    if IsValid( attacker ) and attacker:IsPlayer() then
        self.lastAttacker = attacker

    end

    self:SetHealth( self:Health() - dmg:GetDamage() )
    if self:Health() > 0 then return end

    self:Break()

end
