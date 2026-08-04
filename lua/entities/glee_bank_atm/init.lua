AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

util.AddNetworkString( "glee_atm_opened" )
util.AddNetworkString( "glee_atm_deposit" )
util.AddNetworkString( "glee_atm_withdraw" )
util.AddNetworkString( "glee_atm_claimownercut" )

ENT.Model = "models/glee/atm/atm01.mdl"
ENT.ATMHealth = 5000

ENT.ShellImpulseForce = 500000
ENT.LightOffset = Vector( 0, 0, 75 )

function ENT:Initialize()
    self:SetNW2Bool( "glee_IsSpectatable", true )
    self.glee_PrettyName = "The Bank ATM" -- will only ever be 1 of these, hence THE

    self:SetModel( self.Model )
    self:SetState( "usable" )

    self.nextPfx = 0

    self.DoNotDuplicate = true
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self:SetMaxHealth( self.ATMHealth )
    self:SetHealth( self.ATMHealth )
    self:SetOwnersCut( 0 )

    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) then return end

    phys:EnableMotion( false )
    phys:SetMass( 25000 )

end

local ATM_USE_RANGE_SQR = 512^2

net.Receive( "glee_atm_deposit", function( _, ply )
    local atm = net.ReadEntity()

    if not IsValid( atm ) or atm:GetClass() ~= "glee_bank_atm" then return end
    if not IsValid( ply ) then return end
    if ply:GetPos():DistToSqr( atm:GetPos() ) > ATM_USE_RANGE_SQR then return end

    local cur      = CurTime()
    local cooldown = ply:Alive() and atm.TransactionCooldown or atm.TransactionCooldownDead
    if ply.glee_atmNextTransaction and ply.glee_atmNextTransaction > cur then return end
    ply.glee_atmNextTransaction = cur + cooldown

    local _success, message = atm:DepositToATM( ply )

    if game.IsDedicated() then -- 'log' shop item purchases 
        local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
        permaPrint( nameAndId .. " ATM Deposited: " .. message )

    end
end )

net.Receive( "glee_atm_withdraw", function( _, ply )
    local atm = net.ReadEntity()

    if not IsValid( atm ) or atm:GetClass() ~= "glee_bank_atm" then return end
    if not IsValid( ply ) then return end
    if ply:GetPos():DistToSqr( atm:GetPos() ) > ATM_USE_RANGE_SQR then return end

    local cur      = CurTime()
    local cooldown = ply:Alive() and atm.TransactionCooldown or atm.TransactionCooldownDead
    if ply.glee_atmNextTransaction and ply.glee_atmNextTransaction > cur then return end
    ply.glee_atmNextTransaction = cur + cooldown

    local _success, message = atm:WithdrawFromBank( ply )

    if game.IsDedicated() then -- 'log' shop item purchases 
        local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
        permaPrint( nameAndId .. " ATM Withdrew: " .. message )

    end
end )

net.Receive( "glee_atm_claimownercut", function( _, ply )
    local atm = net.ReadEntity()

    if not IsValid( atm ) or atm:GetClass() ~= "glee_bank_atm" then return end
    if not IsValid( ply ) then return end
    if ply:GetPos():DistToSqr( atm:GetPos() ) > ATM_USE_RANGE_SQR then return end

    local _success, message = atm:ClaimOwnersCut( ply )

    if game.IsDedicated() then -- 'log' shop item purchases 
        local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
        permaPrint( nameAndId .. " ATM Owner's Cut: " .. message )

    end
end )

-- sandbox spawn
function ENT:SpawnFunction( ply, tr, ClassName )
    if not tr.Hit then return end

    local spawnPos = tr.HitPos + tr.HitNormal
    spawnPos.z = spawnPos.z - 2 -- bit into the ground

    local method = terminator_Extras.glee_ATMArrivalAt( spawnPos )
    if not method then return end

    local ent = ents.Create( ClassName )
    if not IsValid( ent ) then return end

    local aimDir = -ply:GetAimVector()
    aimDir.z = 0
    ent:SetPos( spawnPos )
    ent:SetAngles( aimDir:Angle() )
    ent:Spawn()
    ent:StartArrival( method, spawnPos, ply )

    return ent

end

-- NOTE: dead players CAN use this
function ENT:Use( activator )
    if self:GetState() ~= "usable" then return end
    if not IsValid( activator ) or not activator:IsPlayer() then return end

    local likelyPresser = activator.ghostEnt
    if IsValid( likelyPresser ) then
        SafeRemoveEntityDelayed( likelyPresser, 0 )

    end

    net.Start( "glee_atm_opened" )
    net.WriteEntity( self )
    net.Send( activator )

end

function ENT:SpawnShells( method )
    self.ShellEnts = {}
    if not method.shells then return end

    for _, shellDef in ipairs( method.shells ) do
        local shellEnt = terminator_Extras.AttachParentedDetail( self, shellDef.model, shellDef.offset, shellDef.angle )
        if not IsValid( shellEnt ) then continue end

        self.ShellEnts[#self.ShellEnts + 1] = shellEnt
        shellEnt.glee_ejectSounds = shellDef.ejectSounds
        shellEnt.glee_shellName = shellDef.name

        if shellDef.mat then
            shellEnt:SetMaterial( shellDef.mat )

        end

        self["glee_atmpart_" .. shellDef.name] = shellEnt

        local phys = shellEnt:GetPhysicsObject()
        if not IsValid( phys ) then continue end

        phys:SetMass( 500 )
        phys:SetMaterial( "Metalgrate" )

    end
end

local forceUpOffset = Vector( 0, 0, 75 )

function ENT:EjectEntity( ejecting, forceMul, forceOrigin )
    local shellPos = ejecting:GetPos()
    ejecting:SetParent()
    ejecting:SetPos( shellPos )
    ejecting:SetCollisionGroup( COLLISION_GROUP_NONE )

    local phys = ejecting:GetPhysicsObject()
    if not IsValid( phys ) then return end

    local dir = ( shellPos - forceOrigin ):GetNormalized()
    phys:ApplyForceOffset( dir * forceMul, forceOrigin )

end

local breachOffset = Vector( 0, 0, 5 )

-- Ejects the shells whose name contains nameFilter, or all of them when it is nil.
-- Ejected shells leave the list, so a shell can only ever go once.
function ENT:EjectShells( nameFilter )
    if not self.ShellEnts then return end

    local atmPos = self:GetPos()
    local forceOrigin = atmPos + forceUpOffset

    local stillAttached = {}

    for _, shellEnt in ipairs( self.ShellEnts ) do
        if not IsValid( shellEnt ) then continue end

        -- plain find, so a filter is read as the literal text it looks like
        if nameFilter and not string.find( shellEnt.glee_shellName, nameFilter, 1, true ) then
            stillAttached[#stillAttached + 1] = shellEnt
            continue

        end

        self:EjectEntity( shellEnt, self.ShellImpulseForce, forceOrigin )

        local ejectSounds = shellEnt.glee_ejectSounds
        if not ejectSounds then continue end

        for _, ejectSound in ipairs( ejectSounds ) do
            shellEnt:EmitSound( ejectSound.path, ejectSound.level, math.random( ejectSound.pitch[1], ejectSound.pitch[2] ) )

        end
    end

    if #stillAttached <= 0 then
        self.ShellEnts = nil
        return

    end

    self.ShellEnts = stillAttached

end

function ENT:AttachDecorations()
    terminator_Extras.AttachParentedDetail( self, "models/props_wasteland/speakercluster01a.mdl", Vector( -9.4, 1.3, 69 ), Angle( -46, 149.2, 110.7 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_wasteland/speakercluster01a.mdl", Vector( -10.8, 7.5, 16.8 ), Angle( 15.7, 138.7, -139.6 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_c17/light_cagelight01_on.mdl", Vector( -11.3, 11.3, 76.7 ), Angle( 0, 90.3, -90 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_c17/light_cagelight01_on.mdl", Vector( -11.2, -11.5, 76 ), Angle( 0, -89.5, 90 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_rooftop/satellitedish02.mdl", Vector( -17.6, 18.7, 78.9 ), Angle( -12.1, 147, 2.4 ) )

    local dlight = ents.Create( "light_dynamic" )
    dlight:SetKeyValue( "_light", "255 25 25 200" ) -- bright red
    dlight:SetKeyValue( "distance", "450" )
    dlight:SetKeyValue( "brightness", "2" )
    dlight:SetPos( self:LocalToWorld( self.LightOffset ) )
    dlight:SetParent( self )
    dlight:Spawn()

end

local collideLength = 50
local collideSize = 17
local collideMaxs = Vector( collideSize, collideSize, collideLength )
local collideMins = -collideMaxs

local crushLookahead = 100
local crushDamage = 150
local crushForce = 10000

-- Sweeps the whole distance travelled, not a window ahead, so nothing is tunnelled
-- through at arrival speeds.
function ENT:CrushBetween( fromPos, toPos )
    local travel = toPos - fromPos
    if travel:IsZero() then return end

    local dir = travel:GetNormalized()

    local inTheWay = ents.FindAlongRay( fromPos, toPos + dir * crushLookahead, collideMins, collideMaxs )
    for _, ent in ipairs( inTheWay ) do
        if not IsValid( ent ) then continue end
        if ent == self then continue end

        local entsParent = ent:GetParent()
        if IsValid( entsParent ) and entsParent == self then continue end

        local entsObj = ent:GetPhysicsObject()
        if not IsValid( entsObj ) then continue end

        entsObj:ApplyForceCenter( dir * crushForce )

        local dmg = DamageInfo()
        dmg:SetDamage( crushDamage )
        dmg:SetDamageType( DMG_CRUSH )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( ent:WorldSpaceCenter() )
        dmg:SetDamageForce( dir * crushForce )
        ent:TakeDamageInfo( dmg )

    end
end

function ENT:StartArrival( methodName, targetPos, ownerPly )
    local method = self.ArrivalMethods[methodName]
    if not method then return end

    self:SetArrivalMethod( methodName )
    self:SetState( "arriving" )

    self.ArrivalTargetPos = targetPos
    self.ArrivalStartTime = CurTime()
    self.ArrivalEjectTime = nil

    local startPos = method.StartPos( self, targetPos )
    self.ArrivalStartPos = startPos
    self.LastArrivalPos  = startPos
    self:SetPos( startPos )

    if IsValid( ownerPly ) then
        self:SetAtmOwner( ownerPly )

    end

    if method.hidden then
        self:SetNoDraw( true )
        self:SetNotSolid( true )

    end

    self:SpawnShells( method )

    if method.OnStart then
        method.OnStart( self )

    end

    return true

end

function ENT:UpdateArrival()
    if self:GetState() ~= "arriving" then return end

    local method = self.ArrivalMethods[self:GetArrivalMethod()]
    if not method then return end

    -- unset until we touch down, so it doubles as the flag for "still travelling"
    if not self.ArrivalEjectTime then
        local newPos, arrived = method.Move( self )

        self:CrushBetween( self.LastArrivalPos, newPos )
        self:SetPos( newPos )
        self.LastArrivalPos = newPos

        if not arrived then return end

        self.ArrivalEjectTime = CurTime() + method.ejectDelay

        if method.OnTouchdown then
            method.OnTouchdown( self )

        end
    end

    if CurTime() < self.ArrivalEjectTime then return end

    -- corrects drift the travel maths accumulated, but a method that let go into
    -- physics has landed somewhere real and must not be dragged back to the pad
    if not method.physicsLanding then
        self:SetPos( self.ArrivalTargetPos )

    end

    self:FinishArrival( method )

end

function ENT:FinishArrival( method )
    self:SetNoDraw( false )
    self:SetNotSolid( false )

    self:AttachDecorations()
    self:EjectShells()

    terminator_Extras.GleeFancySplode( self:WorldSpaceCenter(), 0, 200, game.GetWorld(), game.GetWorld(), false )

    self:EmitSound( "doors/vent_open1.wav", 80, 120, 1, CHAN_STATIC )

    terminator_Extras.DoPFXAtPos( "glee_atm_burrow_breach", self:GetPos() + breachOffset )
    self:EmitSound( "ambient/levels/outland/ol09_biggundestroy.wav", 88, math.random( 130, 140 ) )

    self:SetState( "usable" )

    timer.Simple( 0.1, function()
        if not IsValid( self ) then return end
        local myPhys = self:GetPhysicsObject()
        if not IsValid( myPhys ) then return end
        myPhys:EnableMotion( true )

    end )

    if method.OnArrive then
        method.OnArrive( self )

    end

    hook.Run( "glee_atm_arrived", self, method.name )
    hook.Run( "glee_atm_finishedBurrowing", self ) -- deprecated, superseded by glee_atm_arrived

end

function ENT:Think()
    -- scheduled before the work, because arriving ends in hooks that may remove us
    self:NextThink( CurTime() )

    self:UpdateArrival()

    return true

end


--[[---------------------------------------------------------
    Arrival methods, the half that moves the ATM

    shared.lua declares and prices these. Move is called every tick and answers where
    the ATM should be now, and whether it has landed; how it gets there is entirely
    the method's business.
-----------------------------------------------------------]]

local shells = {
    {
        model = "models/hunter/tubes/tube1x1x2c.mdl",
        offset = Vector( 0.2, -0.3, -0.3 ),
        angle = Angle( 0, -90, 0 ),
        mat = "phoenix_storms/cube",
        name = "atmShell1",
        ejectSounds = {
            { path = "physics/metal/metal_large_debris1.wav", level = 75, pitch = { 120, 130 } },
        },

    },
    {
        model = "models/hunter/tubes/tube1x1x2c.mdl",
        offset = Vector( 0.2, -0.3, -0.3 ),
        angle = Angle( 0,  90, 0 ),
        mat = "phoenix_storms/cube",
        name = "atmShell2",
        ejectSounds = {
            { path = "physics/metal/metal_large_debris2.wav", level = 75, pitch = { 120, 140 } },
        },
    },
}
local arrivalMethods = ENT.ArrivalMethods
local burrow   = arrivalMethods.burrow
local rocket   = arrivalMethods.rocket
--local teleport = arrivalMethods.teleport

burrow.shells = terminator_Extras.tableCopySimple( shells )
burrow.shells[#burrow.shells + 1] = {
    model = "models/hunter/misc/cone1x1.mdl",
    offset = Vector( 0.1, -0.3, 94.6 ),
    angle = Angle( 0, -90, 0 ),
    mat = "models/glee/atm/atm_drillbit",
    name = "atmBit",
}

rocket.shells = terminator_Extras.tableCopySimple( shells )
rocket.shells[#rocket.shells + 1] = {
    model = "models/hunter/misc/cone1x05.mdl",
    offset = Vector( 0.1, -0.3, 94.6 ),
    angle = Angle( 0, -90, 0 ),
    mat = "phoenix_storms/cube",
    name = "atmBit",
}
rocket.shells[#rocket.shells + 1] = {
    model = "models/xqm/afterburner1medium.mdl",
    offset = Vector( 1.7, 0.9, -13 ),
    angle = Angle( 0, -180, -180 ),
    name = "atmRocket",
}
--teleport.shells = shells

local burrowSoundOffset = Vector( 0, 0, 25 )
local burrowPebbleOffset = Vector( 0, 0, 1 )

function burrow.StartPos( _self, targetPos )
    return targetPos - Vector( 0, 0, burrow.depth )

end

function burrow.OnStart( self )
    self.NextBurrowSound = CurTime() + 0.5

    terminator_Extras.DoPFXAtPos( "glee_atm_burrow_pebbles", self.ArrivalTargetPos + burrowPebbleOffset )

end

function burrow.Move( self )
    local cur = CurTime()
    local progress = math.min( ( cur - self.ArrivalStartTime ) / burrow.duration, 1.0 )

    if cur > self.NextBurrowSound then
        self.NextBurrowSound = cur + math.Rand( 0.4, 0.8 )
        sound.Play( "npc/antlion/digdown1.wav", self.ArrivalTargetPos + burrowSoundOffset, 75, math.random( 70, 90 ), progress )

    end

    if progress > 0.85 and not self.PlayedPreEmergeSound then
        self.PlayedPreEmergeSound = true
        sound.Play( "ambient/levels/dog_v_strider/dvs_dogslamstrider_00_30_07.wav", self.ArrivalTargetPos + burrowSoundOffset, 88, math.random( 90, 95 ) )

    end

    return LerpVector( progress, self.ArrivalStartPos, self.ArrivalTargetPos ), progress >= 1

end

local scorchDepth = Vector( 0, 0, -100 )

function burrow.OnArrive( self )
    local atmPos = self:GetPos()

    util.Decal( "Scorch", atmPos, atmPos + scorchDepth, self )

end

local rocketSkyOffset = Vector( 0, 0, 60 )
local rocketSkyMargin = 64 -- don't enter flush against the sky brush

function rocket.StartPos( _self, targetPos )
    local _underSky, skyPos = GAMEMODE:IsUnderSky( targetPos + rocketSkyOffset )

    local entryZ = math.min( skyPos.z - rocketSkyMargin, targetPos.z + rocket.entryHeight )

    return Vector( targetPos.x, targetPos.y, math.max( entryZ, targetPos.z + 1 ) )

end

-- The rocket is a map wide event, so its sounds reach past the PVS that would
-- otherwise decide who is close enough to hear them.
local function emitToEveryone( ent, path, level, pitch )
    local everyone = RecipientFilter()
    everyone:AddAllPlayers()

    ent:EmitSound( path, level, pitch, 1, CHAN_STATIC, SND_NOFLAGS, 0, everyone )

end

function rocket.OnStart( self )
    self.rocketVel = -1000
    self.rocketBurning = false
    self.rocketLastMove = CurTime()

    emitToEveryone( self, "npc/env_headcrabcanister/incoming.wav", 125, 50 )

end

function rocket.OnIgnite( self )
    self:SetRocketBurning( true )

    emitToEveryone( self, "ambient/explosions/explode_9.wav", 125, 80 )

end

-- Everything the exhaust can roughly reach, cooked and shoved.
function rocket.EngineDmgThink( self )
    local myPos = self:GetPos()
    local down = -self:GetUp()

    for _, ent in ipairs( ents.FindInCone( myPos, down, rocket.blastRange, rocket.blastCone ) ) do
        if not IsValid( ent ) then continue end
        if ent == self then continue end

        local entsParent = ent:GetParent()
        if IsValid( entsParent ) then
            if entsParent == self then continue end
            if ent:IsWeapon() then continue end
            if entsParent:IsPlayer() then continue end

        end

        local entsPos = ent:WorldSpaceCenter()
        if not terminator_Extras.PosCanSee( myPos, entsPos, MASK_SOLID_BRUSHONLY ) then continue end

        local fireDmg = DamageInfo()
        fireDmg:SetDamage( rocket.blastDamage )
        fireDmg:SetDamageType( DMG_BURN )
        fireDmg:SetAttacker( self )
        fireDmg:SetInflictor( self )
        fireDmg:SetDamagePosition( entsPos )
        fireDmg:SetDamageForce( terminator_Extras.dirToPos( myPos, entsPos ) * rocket.blastForce )
        ent:TakeDamageInfo( fireDmg )

        ent:Ignite( math.Rand( rocket.blastIgnite[1], rocket.blastIgnite[2] ) )

    end
end

function rocket.Move( self )
    local cur = CurTime()
    local dt = cur - self.rocketLastMove
    self.rocketLastMove = cur

    local pos = self:GetPos()
    if dt <= 0 then return pos, false end

    -- the burn is solved against the release point, not the pad; physics covers the rest
    local releaseZ = self.ArrivalTargetPos.z + rocket.releaseHeight
    local height = pos.z - releaseZ
    local vel = self.rocketVel

    -- the engines have to light early enough to null out the fall before the pad, so
    -- solve for the distance that takes and burn the moment we are inside it
    local netDecel = rocket.thrust - rocket.gravity
    local burnHeight = ( ( vel * vel ) / ( 2 * netDecel ) ) * rocket.igniteMargin

    if not self.rocketBurning and ( height <= burnHeight or height <= rocket.minIgniteHeight ) then
        self.rocketBurning = true
        rocket.OnIgnite( self )

    end

    if self.rocketBurning then
        -- clamped so a burn with margin to spare settles onto the pad instead of hovering
        vel = math.min( vel + netDecel * dt, -rocket.touchdownSpeed )

        local nextBigThink = self.nextBigRocketThink or 0
        if nextBigThink < cur then
            self.nextBigRocketThink = cur + 0.1
            local scorchOffset = Vector( pos.x + math.Rand( -100, 100 ), pos.y + math.Rand( -100, 100 ), pos.z + -100 )
            util.Decal( "Scorch", pos, scorchOffset, self )

            rocket.EngineDmgThink( self )

        end
    else
        vel = vel - rocket.gravity * dt

    end

    self.rocketVel = vel

    local newZ = pos.z + vel * dt
    if newZ <= releaseZ then return Vector( pos.x, pos.y, releaseZ ), true end

    return Vector( pos.x, pos.y, newZ ), false

end

function rocket.OnTouchdown( self )
    self.rocketBurning = false
    self:SetRocketBurning( false )

    -- funny atm physics: the engine is thrown downward into the spot the ATM is about
    -- to land on, and the ATM then lands on it. the casing stays on until FinishArrival
    self:EjectShells( "Rocket" )

    -- let go short of the ground, so it lands on whatever is really under it
    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) then return end

    phys:EnableMotion( true )
    phys:Wake()
    phys:SetVelocity( Vector( 0, 0, self.rocketVel ) )

end

function rocket.OnArrive( self )
    self:EmitSound( "ambient/machines/thumper_hit.wav", 90, 90 )

end

--function teleport.StartPos( _self, targetPos )
--    return Vector( targetPos )
--
--end
--
--function teleport.Move( self )
--    return self.ArrivalTargetPos, CurTime() >= self.ArrivalStartTime + teleport.duration
--
--end


function ENT:DepositToATM( ply )
    if not IsValid( ply ) then return false, "Invalid player" end
    local canDeposit, reason = self:CanDeposit( ply )
    if not canDeposit then return false, reason end

    local cap       = ply:Alive() and self.TransactionAmount or self.DeadTransactionAmount
    local toDeposit = math.min( ply:GetScore(), cap )

    ply:GivePlayerScore( -toDeposit )
    local fee = ply:BankDepositScoreFullHandle( toDeposit )
    self:SetOwnersCut( self:GetOwnersCut() + math.floor( fee / 2 ) )

    return true, "Deposited $" .. toDeposit

end

function ENT:WithdrawFromBank( ply )
    if not IsValid( ply ) then return false, "Invalid player" end
    local canWithdraw, reason = self:CanWithdraw( ply )
    if not canWithdraw then return false, reason end

    local bankFunds  = ply:GetNW2Int( "Glee_BankFunds", 0 )
    local minFunds   = gleefunc_BankMinFunds()
    local cap        = ply:Alive() and self.TransactionAmount or self.DeadTransactionAmount
    local toWithdraw = math.min( cap, math.max( 0, bankFunds - minFunds ) )

    local fee        = math.floor( toWithdraw * gleefunc_BankProcessingFee() / 100 )
    local playerGets = toWithdraw

    ply:BankDepositScore( -( toWithdraw + fee ) )
    ply:GivePlayerScore( playerGets )
    self:SetOwnersCut( self:GetOwnersCut() + math.floor( fee / 2 ) )

    return true, "Withdrew $" .. playerGets

end

function ENT:ClaimOwnersCut( ply )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not IsValid( ply ) then return false, "Invalid player" end

    local owner = self:GetAtmOwner()
    if not IsValid( owner ) then return false, "Destroy the ATM to claim the owner's cut" end
    if ply ~= owner then return false, "Only the ATM owner can claim the owner's cut" end
    if self:GetOwnersCut() <= 0 then return false, "Owner's cut is empty" end

    local amount = self:GetOwnersCut()
    ply:GivePlayerScore( amount )
    self:SetOwnersCut( 0 )

    return true, "Claimed owner's cut: " .. amount

end

function ENT:OnTakeDamage( dmg )
    if self:GetState() ~= "usable" then return end

    local damage = dmg:GetDamage()
    self:SetHealth( self:Health() - damage )

    local percentLost = 100 - math.ceil( self:Health() / self:GetMaxHealth() * 100 )
    local pfxScale = percentLost + damage / 4
    local pfxToUse
    -- find the effect above the threshold
    if pfxScale <= 25 then
        pfxToUse = "fire_small_02"

    elseif pfxScale <= 50 then
        pfxToUse = "fire_small_01"

    else
        pfxToUse = "fire_small_03"

    end

    local cur = CurTime()
    local canPfx = pfxToUse and ( cur > self.nextPfx or self.lastPfxName ~= pfxToUse )

    if canPfx then
        -- claimed now, not inside the timer, or every pellet of one blast gets its own
        self.nextPfx = cur + 0.5
        self.lastPfxName = pfxToUse

        -- damage hooks dont play effects
        timer.Simple( 0, function()
            if not IsValid( self ) then return end

            local randOffsetted = self:WorldSpaceCenter() + VectorRand() * self:GetModelRadius() * 2
            local pfxPos = self:NearestPoint( randOffsetted )

            local particleeffect = ents.Create( "info_particle_system" )

            particleeffect:SetKeyValue( "effect_name", pfxToUse )
            particleeffect:SetKeyValue( "start_active", 1 )
            particleeffect:SetOwner( self )
            particleeffect:SetPos( pfxPos )
            particleeffect:SetAngles( self:GetAngles() )
            particleeffect:Spawn()
            particleeffect:Activate()
            particleeffect:SetParent( self )

            local stop = math.Rand( 2, 3 )
            particleeffect:Fire( "Stop", "", stop )

            SafeRemoveEntityDelayed( particleeffect, stop )

            if pfxScale > 90 or damage > 90 then
                terminator_Extras.GleeFancySplode( pfxPos, 0, 200, game.GetWorld(), game.GetWorld(), false )

            end
        end )
    end


    if self:Health() > 0 then return end

    self:Die()

end

local scoreDumpOffset = Vector( -16, 0, 40 )
local alwaysInsideATM = { 50, 1000 }

function ENT:Die()
    self:SetState( "broken" )

    local pos       = self:GetPos()
    local poolFunds = self:GetOwnersCut() + math.random( alwaysInsideATM[1], alwaysInsideATM[2] )

    terminator_Extras.GleeFancySplode( pos, 1500, 350, self, self )
    terminator_Extras.GleeFancySplode( pos, 25, 750, self, self )

    timer.Simple( 0, function()
        local eff = EffectData()
            eff:SetOrigin( pos )
            eff:SetScale( 2 )
            eff:SetNormal( Vector( 0, 0, 1 ) )

        util.Effect( "glee_huge_m9k_splode", eff )

    end )

    self:SetBodygroup( 0, 1 ) -- disable model door
    local door = terminator_Extras.AttachParentedDetail( self, "models/glee/atm/atm01_door.mdl", Vector( 0, 0, 0 ), Angle( 0, 0, 0 ) )
    if IsValid( door ) then
        self:EjectEntity( door, self.ShellImpulseForce * 2, self:WorldSpaceCenter() )

    end

    self:SetOwnersCut( 0 ) -- it is all in the pool now, and about to be on the floor

    local reps = 0
    local scorePos = self:LocalToWorld( scoreDumpOffset )
    while poolFunds > 0 do
        reps = reps + 1
        local scoreForThisBall = math.min( 25 * reps, poolFunds )
        poolFunds = poolFunds - scoreForThisBall

        local pickup = ents.Create( "termhunt_score_pickup" )
        if IsValid( pickup ) then
            local offset = -self:GetForward() * math.Rand( 0, 20 ) + self:GetRight() * math.Rand( -10, 10 )
            pickup:SetPos( scorePos + offset )
            pickup:Spawn()
            pickup:SetScore( scoreForThisBall )
            pickup:UpdateScoreLive()

        end
    end
end
