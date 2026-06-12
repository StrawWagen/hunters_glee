ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category  = "Hunter's Glee"
ENT.PrintName = "Bank ATM"
ENT.Author    = "StrawWagen"
ENT.Spawnable = true
ENT.AdminOnly = game.IsDedicated()

ENT.Model    = "models/glee/atm/atm01.mdl"
ENT.SkullCount      = 10
ENT.SkullOffsetMaxs = Vector( 8, 12, 15 )
ENT.SkullOffsetMins = Vector( -8, -12, 15 )

ENT.BurrowDuration = 2

ENT.TransactionAmounts = { 100, 500, 1000 }

ENT.Shells = {
    { "models/hunter/tubes/tube1x1x2c.mdl", Vector( 0.2, -0.3, -0.3 ), Angle( 0, -90, 0 ) },
    { "models/hunter/tubes/tube1x1x2c.mdl", Vector( 0.2, -0.3, -0.3 ), Angle( 0,  90, 0 ) },
    { "models/hunter/misc/cone1x1.mdl",     Vector( 0.1, -0.3, 94.6 ), Angle( 0, -90, 0 ) },
}

ENT.ShellImpulseForce = 50000

function ENT:SetupDataTables()
    self:NetworkVar( "String", "State" )    -- "usable" | "burrowing" | "shell_ejecting"
    self:NetworkVar( "Int",    "PoolFunds" ) -- score held in the ATM pool
    self:NetworkVar( "Entity", "AtmOwner" ) -- purchasing player; NULL for auto-spawned ATMs

end

function ENT:Initialize()
    self:SetModel( self.Model )
    self:SetState( "usable" )

    if not SERVER then return end

    self.DoNotDuplicate = true
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self:SetMaxHealth( 2000 )
    self:SetHealth( 2000 )
    self:SetPoolFunds( 0 )

    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) then return end

    phys:EnableMotion( false )

end

-- ─── SERVER ONLY ──────────────────────────────────────────────────────────────
if not SERVER then return end

net.Receive( "glee_atm_deposit", function( _, ply )
    local atm    = net.ReadEntity()
    local amount = net.ReadUInt( 32 )

    if not IsValid( atm ) or atm:GetClass() ~= "glee_bank_atm" then return end
    if not IsValid( ply ) then return end
    if ply:GetPos():DistToSqr( atm:GetPos() ) > 512 ^ 2 then return end

    local ok, msg = atm:DepositToATM( ply, amount )

    net.Start( "glee_atm_transactionresult" )
    net.WriteBool( ok )
    net.WriteString( msg or "" )
    net.Send( ply )

end )

net.Receive( "glee_atm_withdraw", function( _, ply )
    local atm    = net.ReadEntity()
    local amount = net.ReadUInt( 32 )

    if not IsValid( atm ) or atm:GetClass() ~= "glee_bank_atm" then return end
    if not IsValid( ply ) then return end
    if ply:GetPos():DistToSqr( atm:GetPos() ) > 512 ^ 2 then return end

    local ok, msg = atm:WithdrawFromBank( ply, amount )

    net.Start( "glee_atm_transactionresult" )
    net.WriteBool( ok )
    net.WriteString( msg or "" )
    net.Send( ply )

end )

net.Receive( "glee_atm_withdrawpool", function( _, ply )
    local atm = net.ReadEntity()

    if not IsValid( atm ) or atm:GetClass() ~= "glee_bank_atm" then return end
    if not IsValid( ply ) then return end
    if ply:GetPos():DistToSqr( atm:GetPos() ) > 512 ^ 2 then return end

    local ok, msg = atm:WithdrawFromPool( ply )

    net.Start( "glee_atm_transactionresult" )
    net.WriteBool( ok )
    net.WriteString( msg or "" )
    net.Send( ply )

end )

-- sandbox spawn
function ENT:SpawnFunction( ply, tr, ClassName )
    if not tr.Hit then return end

    local spawnPos = tr.HitPos + tr.HitNormal
    local ent = ents.Create( ClassName )
    if not IsValid( ent ) then return end

    local aimDir = -ply:GetAimVector()
    aimDir.z = 0
    ent:SetPos( spawnPos + Vector( 0, 0, -100 ) )
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
    self:SetState( "burrowing" )

    if IsValid( ownerPly ) then
        self:SetAtmOwner( ownerPly )

    end

    self:SpawnShells()

end

function ENT:Use( activator )
    if self:GetState() ~= "usable" then return end
    if not IsValid( activator ) or not activator:IsPlayer() then return end

    net.Start( "glee_atm_opened" )
    net.WriteEntity( self )
    net.Send( activator )

end

function ENT:SpawnShells()
    self.ShellEnts = self.ShellEnts or {}

    for _, shellDef in ipairs( self.Shells ) do
        local shellEnt = terminator_Extras.AttachParentedDetail( self, shellDef[1], shellDef[2], shellDef[3] )
        if not IsValid( shellEnt ) then continue end

        table.insert( self.ShellEnts, shellEnt )

        local phys = shellEnt:GetPhysicsObject()
        if not IsValid( phys ) then continue end

        phys:SetMass( 500 )
        phys:SetMaterial( "Metalgrate" )

    end

end

local forceUpOffset = Vector( 0, 0, 75 )

function ENT:EjectShells()
    if not self.ShellEnts then return end

    local atmPos = self:GetPos()

    local fx = EffectData()
    fx:SetOrigin( atmPos )
    fx:SetScale( 2 )
    util.Effect( "HelicopterMegaBomb", fx, nil, true )

    local forceOrigin = atmPos + forceUpOffset

    for _, shellEnt in ipairs( self.ShellEnts ) do
        if not IsValid( shellEnt ) then continue end

        local shellPos = shellEnt:GetPos()
        shellEnt:SetParent()
        shellEnt:SetPos( shellPos )
        shellEnt:SetCollisionGroup( COLLISION_GROUP_NONE )

        local phys = shellEnt:GetPhysicsObject()
        if not IsValid( phys ) then continue end

        local dir = ( shellEnt:GetPos() - atmPos ):GetNormalized()
        phys:ApplyForceOffset( dir * self.ShellImpulseForce, forceOrigin )

    end

    self:SetState( "usable" )

end

function ENT:UpdateBurrow()
    if self:GetState() ~= "burrowing" then return end

    local elapsed  = CurTime() - self.BurrowStartTime
    local progress = math.min( elapsed / self.BurrowDuration, 1.0 )

    self:SetPos( LerpVector( progress, self.BurrowStartPos, self.BurrowTargetPos ) )

    if progress < 1.0 then return end

    self:SetPos( self.BurrowTargetPos )
    self:SetState( "shell_ejecting" )
    self:EjectShells()

end

function ENT:Think()
    self:UpdateBurrow()
    self:NextThink( CurTime() )
    return true

end

function ENT:DepositToATM( ply, toDeposit )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not IsValid( ply ) then return false, "Invalid player" end
    if not table.HasValue( self.TransactionAmounts, toDeposit ) then return false, "Invalid amount" end
    if not ply:BankHasAccount() then return false, "Open a bank account first" end
    if ply:GetScore() < toDeposit then return false, "Not enough score" end

    local fee     = gleefunc_BankProcessingFee()
    local halfFee = fee / 2
    local feeAmt  = math.Round( toDeposit * halfFee / 100 )
    local bankAmt = toDeposit - feeAmt * 2

    ply:GivePlayerScore( -toDeposit )
    ply:BankDepositScore( bankAmt )
    self:SetPoolFunds( self:GetPoolFunds() + feeAmt )

    return true, "Deposited $" .. toDeposit .. " → $" .. bankAmt .. " to account, $" .. feeAmt .. " to pool"

end

function ENT:WithdrawFromBank( ply, toWithdraw )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not IsValid( ply ) then return false, "Invalid player" end
    if not table.HasValue( self.TransactionAmounts, toWithdraw ) then return false, "Invalid amount" end
    if not ply:BankHasAccount() then return false, "Open a bank account first" end
    if not ply:BankCanDeposit( -toWithdraw ) then return false, "Not enough funds in account" end

    ply:BankDepositScore( -toWithdraw )
    ply:GivePlayerScore( toWithdraw )

    return true, "Withdrew $" .. toWithdraw .. " from account"

end

function ENT:WithdrawFromPool( ply )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not IsValid( ply ) then return false, "Invalid player" end

    local owner = self:GetAtmOwner()
    if not IsValid( owner ) then return false, "Destroy the ATM to claim the pool" end
    if ply ~= owner then return false, "Only the ATM owner can withdraw from the pool" end
    if self:GetPoolFunds() <= 0 then return false, "ATM pool is empty" end

    local amount = self:GetPoolFunds()
    ply:GivePlayerScore( amount )
    self:SetPoolFunds( 0 )

    return true, "Withdrew $" .. amount .. " from ATM pool"

end

function ENT:OnTakeDamage( dmg )
    self:SetHealth( self:Health() - dmg:GetDamage() )
    if self:Health() > 0 then return end

    self:Die()

end

function ENT:Die()
    local pos       = self:GetPos()
    local poolFunds = self:GetPoolFunds()

    if poolFunds > 0 then
        local pickup = ents.Create( "termhunt_score_pickup" )
        if IsValid( pickup ) then
            pickup:SetPos( pos + Vector( 0, 0, 50 ) )
            pickup:Spawn()
            pickup:SetScore( poolFunds )
            pickup:UpdateScoreLive()

        end
        self:SetPoolFunds( 0 )

    end

    terminator_Extras.GleeFancySplode( pos, 0, 200, game.GetWorld(), game.GetWorld(), false )
    SafeRemoveEntity( self )

end

function ENT:OnRemove()
end
