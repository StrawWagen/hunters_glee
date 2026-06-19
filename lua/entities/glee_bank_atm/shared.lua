ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category  = "Hunter's Glee"
ENT.PrintName = "Bank ATM"
ENT.Author    = "StrawWagen"
ENT.Spawnable = true
ENT.AdminOnly = game.IsDedicated()

ENT.TransactionAmount       = 1000
ENT.DeadTransactionAmount   = 666
ENT.TransactionCooldown     = 0.25
ENT.TransactionCooldownDead = 1

function ENT:SetupDataTables()
    self:NetworkVar( "String", "State" )    -- "usable" | "burrowing" | "broken"
    self:NetworkVar( "Int",    "OwnersCut" ) -- score accumulating for the ATM owner
    self:NetworkVar( "Entity", "AtmOwner" ) -- purchasing player; NULL for auto-spawned ATMs

end

function ENT:Nick()
    return "The ATM"

end

local atmColor = Vector( 255, 20, 20 ) / 255

function ENT:GetPlayerColor()
    return atmColor

end

-- Returns true, or false + reason if the player cannot deposit right now.
function ENT:CanDeposit( ply )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not ply:BankHasAccount() then return false, "Open a bank account first" end
    if ply:GetScore() <= 0 then return false, "No score to deposit" end
    return true

end

-- Returns true, or false + reason if the player cannot withdraw right now.
function ENT:CanWithdraw( ply )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not ply:BankHasAccount() then return false, "Open a bank account first" end

    local bankFunds  = ply:GetNW2Int( "Glee_BankFunds", 0 )
    local minFunds   = gleefunc_BankMinFunds()
    local cap        = ply:Alive() and self.TransactionAmount or self.DeadTransactionAmount
    local toWithdraw = math.min( cap, math.max( 0, bankFunds - minFunds ) )

    if toWithdraw < cap then return false, "Your funds are too low.\nThe ATM's withdrawl threshold is 1000 score." end
    return true

end
