AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

util.AddNetworkString( "glee_atm_opened" )
util.AddNetworkString( "glee_atm_deposit" )
util.AddNetworkString( "glee_atm_withdraw" )
util.AddNetworkString( "glee_atm_claimownercut" )

ENT.Model          = "models/glee/atm/atm01.mdl"
ENT.BurrowDuration = 3
ENT.BurrowDepth    = 1000
ENT.EjectDelay = 0.25
ENT.ATMHealth = 5000

ENT.Shells = {
    {
        model = "models/hunter/tubes/tube1x1x2c.mdl",
        offset = Vector( 0.2, -0.3, -0.3 ),
        angle = Angle( 0, -90, 0 ),
        mat = "phoenix_storms/cube"

    },
    {
        model = "models/hunter/tubes/tube1x1x2c.mdl",
        offset = Vector( 0.2, -0.3, -0.3 ),
        angle = Angle( 0,  90, 0 ),
        mat = "phoenix_storms/cube"
    },
    {
        model = "models/hunter/misc/cone1x1.mdl",
        offset = Vector( 0.1, -0.3, 94.6 ),
        angle = Angle( 0, -90, 0 ),
        mat = "models/glee/atm/atm_drillbit"
    },
}

ENT.ShellImpulseForce = 500000
ENT.LightOffset = Vector( 0, 0, 75 )

function ENT:Initialize()
    self:SetNW2Bool( "glee_IsSpectatable", true )
    self.glee_PrettyName = "The Bank ATM" -- will only ever be 1 of these

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
        print( nameAndId .. " ATM Deposited: " .. message )

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
        print( nameAndId .. " ATM Withdrew: " .. message )

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
        print( nameAndId .. " ATM Owner's Cut: " .. message )

    end
end )

-- sandbox spawn
function ENT:SpawnFunction( ply, tr, ClassName )
    if not tr.Hit then return end

    local spawnPos = tr.HitPos + tr.HitNormal
    spawnPos.z = spawnPos.z - 2 -- bit into the ground

    local ent = ents.Create( ClassName )
    if not IsValid( ent ) then return end

    local aimDir = -ply:GetAimVector()
    aimDir.z = 0
    ent:SetPos( spawnPos + Vector( 0, 0, -ent.BurrowDepth ) )
    ent:SetAngles( aimDir:Angle() )
    ent:Spawn()
    ent:StartBurrowingToPos( spawnPos, ent.BurrowDuration, ply )

    return ent

end

function ENT:StartBurrowingToPos( targetPos, duration, ownerPly )
    self.BurrowStartPos  = self:GetPos()
    self.BurrowTargetPos = targetPos
    self.BurrowStartTime = CurTime()
    self.BurrowDuration  = duration or self.BurrowDuration
    self.NextBurrowSound = CurTime() + 0.5
    self:SetState( "burrowing" )

    self.EjectTime = CurTime() + self.BurrowDuration + self.EjectDelay

    if IsValid( ownerPly ) then
        self:SetAtmOwner( ownerPly )

    end

    self:SpawnShells()

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

function ENT:SpawnShells()
    self.ShellEnts = {}

    for _, shellDef in ipairs( self.Shells ) do
        local shellEnt = terminator_Extras.AttachParentedDetail( self, shellDef.model, shellDef.offset, shellDef.angle )
        if not IsValid( shellEnt ) then continue end

        self.ShellEnts[#self.ShellEnts + 1] = shellEnt

        if shellDef.mat then
            shellEnt:SetMaterial( shellDef.mat )

        end

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

function ENT:EjectShells()
    if not self.ShellEnts then return end

    local atmPos = self:GetPos()

    terminator_Extras.GleeFancySplode( self:WorldSpaceCenter(), 0, 200, game.GetWorld(), game.GetWorld(), false )

    terminator_Extras.AttachParentedDetail( self, "models/props_wasteland/speakercluster01a.mdl", Vector( -9.4, 1.3, 69 ), Angle( -46, 149.2, 110.7 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_wasteland/speakercluster01a.mdl", Vector( -10.8, 7.5, 16.8 ), Angle( 15.7, 138.7, -139.6 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_c17/light_cagelight01_on.mdl", Vector( -11.3, 11.3, 76.7 ), Angle( 0, 90.3, -90 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_c17/light_cagelight01_on.mdl", Vector( -11.2, -11.5, 76 ), Angle( 0, -89.5, 90 ) )
    terminator_Extras.AttachParentedDetail( self, "models/props_rooftop/satellitedish02.mdl", Vector( -17.6, 18.7, 78.9 ), Angle( -12.1, 147, 2.4 ) )

    self:EmitSound( "doors/vent_open1.wav", 80, 120, 1, CHAN_STATIC )

    local forceOrigin = atmPos + forceUpOffset

    for _, shellEnt in ipairs( self.ShellEnts ) do
        if not IsValid( shellEnt ) then continue end

        self:EjectEntity( shellEnt, self.ShellImpulseForce, forceOrigin )

    end

    self:SetState( "usable" )

    local brightness = 2
    -- bright red light
    local dlight = ents.Create( "light_dynamic" )
    dlight:SetKeyValue( "_light", "255 25 25 200" )
    dlight:SetKeyValue( "distance", "450" )
    dlight:SetKeyValue( "brightness", tostring( brightness ) )
    dlight:SetPos( self:LocalToWorld( self.LightOffset ) )
    dlight:SetParent( self )
    dlight:Spawn()

    timer.Simple( 0.1, function()
        if not IsValid( self ) then return end
        local myPhys = self:GetPhysicsObject()
        if not IsValid( myPhys ) then return end
        myPhys:EnableMotion( true )

    end )

    hook.Run( "glee_atm_finishedBurrowing", self )

end

local collideLength = 50
local collideSize = 17
local collideMaxs = Vector( collideSize, collideSize, collideLength )
local collideMins = -collideMaxs

function ENT:UpdateBurrow()
    if self:GetState() ~= "burrowing" then return end

    local cur = CurTime()

    local elapsed  = cur - self.BurrowStartTime
    local progress = math.min( elapsed / self.BurrowDuration, 1.0 )

    local lerpedPos = LerpVector( progress, self.BurrowStartPos, self.BurrowTargetPos )
    self:SetPos( lerpedPos )

    local dir = terminator_Extras.dirToPos( lerpedPos, self.BurrowTargetPos )
    local stuffAboveUs = ents.FindAlongRay( lerpedPos, lerpedPos + dir * 100, collideMins, collideMaxs )
    if #stuffAboveUs > 0 then
        for _, ent in ipairs( stuffAboveUs ) do
            if not IsValid( ent ) then continue end
            if ent == self then continue end

            local entsParent = ent:GetParent()
            if IsValid( entsParent ) and entsParent == self then continue end

            local entsObj = ent:GetPhysicsObject()
            if not IsValid( entsObj ) then continue end

            entsObj:ApplyForceCenter( dir * 10000 )

            local damage = DamageInfo()
            damage:SetDamage( 150 )
            damage:SetDamageType( DMG_CRUSH )
            damage:SetAttacker( self )
            damage:SetInflictor( self )
            damage:SetDamagePosition( ent:WorldSpaceCenter() )
            damage:SetDamageForce( dir * 10000 )
            ent:TakeDamageInfo( damage )

        end
    end

    if cur > self.NextBurrowSound then
        self.NextBurrowSound = cur + math.Rand( 0.4, 0.8 )
        sound.Play( "npc/antlion/digdown1.wav", self.BurrowTargetPos + Vector( 0, 0, 25 ), 75, math.random( 70, 90 ), progress )

    end

    if progress < 1 then return end

    if cur < self.EjectTime then return end

    self:SetPos( self.BurrowTargetPos )
    self:EjectShells()

end

function ENT:Think()
    self:UpdateBurrow()
    self:NextThink( CurTime() )
    return true

end

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
        -- damage hooks dont play effects
        timer.Simple( 0, function()
            if not IsValid( self ) then return end

            self.nextPfx = cur + 0.5
            self.lastPfxName = pfxToUse

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
    self:EjectEntity( door, self.ShellImpulseForce * 2, self:WorldSpaceCenter() )

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
        self:SetOwnersCut( 0 )

    end
end
