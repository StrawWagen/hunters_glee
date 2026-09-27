local bankFunctions = GM.bankFunctions or {}
GM.bankFunctions = bankFunctions

GM.bankItems = GM.bankItems or {}

-- -1 on these convars means the default in code, so changing a default reaches servers that already archived the convar

-- % of player's bank account charged per period
local glee_BankChargePerPeriod = CreateConVar( "huntersglee_bank_chargeperperiod", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "What percent of player's bank account is charged, per period. -1 is default, 10%", -1, 100 )
local default_BankChargePerPeriod = 10
function GM:GetBankChargePerPeriod()
    local theVal = glee_BankChargePerPeriod:GetFloat()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankChargePerPeriod

    end
end

-- % processing fee applied to deposits, and ATM withdrawls
local glee_BankProcessingFee = CreateConVar( "huntersglee_bank_processingfee", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "What percent of deposits, and ATM withdrawls, is charged as a processing fee. -1 is default, 10%", -1, 100 )
local default_BankProcessingFee = 10
function GM:GetBankProcessingFee()
    local theVal = glee_BankProcessingFee:GetFloat()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankProcessingFee

    end
end

-- the processing fee on a transaction of this size, rounded up
function GM:GetBankProcessingFeeFor( amount )
    return math.ceil( amount * ( self:GetBankProcessingFee() / 100 ) )

end

-- charge period
local glee_BankChargePeriod = CreateConVar( "huntersglee_bank_chargeperiod", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Period that the player's bank account is charged, in seconds. -1 for default, 172800, 2 days.", -1, 999999999999 )
local default_BankChargePeriod = 172800 -- 2 days
function GM:GetBankChargePeriod()
    local theVal = glee_BankChargePeriod:GetFloat()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankChargePeriod

    end
end

-- minimum funds, basically exists to clean up the file
local glee_BankMinFunds = CreateConVar( "huntersglee_bank_minfunds", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Minimum funds in a player's bank account, if an account ends up below this, it will be closed. -1 for default, 100", -1, 999999 )
local default_BankMinFunds = 100
function GM:GetBankMinFunds()
    local theVal = glee_BankMinFunds:GetInt()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankMinFunds

    end
end

-- Bank items sit on an account, one of each, until they expire or the account closes.
-- data.lifetime: seconds the item lasts once given, nil lasts until the account closes.
function GM:RegisterBankItem( name, data )
    self.bankItems[name] = data

end

-- item is an account's entry, { expires = os.time() it stops working, or nil for never }
bankFunctions.itemExpired = function( item )
    if not item.expires then return false end
    return os.time() >= item.expires

end


local meta = FindMetaTable( "Player" )

-- the account has to be left above 0, anything under the minimum funds closes at the next idle fee
function meta:BankCanWithdraw( toWithdraw )
    local funds = self:BankFunds()
    if not funds then return false, "You haven't opened a bank account yet." end
    if funds - toWithdraw <= 0 then return false, "Your account can't cover that." end
    return true

end

function meta:BankHasAccount()
    return istable( bankFunctions.checkBankAccount( self ) )

end

function meta:BankAccount()
    return bankFunctions.checkBankAccount( self )

end

-- expiry is checked here, not left to the server's periodic prune, so items stop working on time
function meta:HasBankItem( name )
    local account = bankFunctions.checkBankAccount( self )
    if not account or not account.items then return false end

    local item = account.items[name]
    if not item then return false end

    return not bankFunctions.itemExpired( item )

end

-- seconds until the item expires, math.huge if it never does, nil if the player doesn't have it
function meta:BankItemTimeLeft( name )
    if not self:HasBankItem( name ) then return end

    local item = self:BankAccount().items[name]
    if not item.expires then return math.huge end

    return item.expires - os.time()

end
