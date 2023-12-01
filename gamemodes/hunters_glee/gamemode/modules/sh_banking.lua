local defaultBankDataDir = "hunters_glee"
local defaultBankDataName = defaultBankDataDir .. "/bankdata.json"
GM.bankInfoTable = GM.bankInfoTable or {}
GM.bankInfoTable.accounts = GM.bankInfoTable.accounts or {}

local bankFunctions = {}
local GAMEMODE = GM

local glee_BankChargePerPeriod = CreateConVar( "huntersglee_bank_chargeperperiod", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "What percent of player's bank account is charged, per period. -1 is default, 10%", 0, 100 )
local default_BankChargePerPeriod = 10
function func_BankChargePerPeriod()
    local theVal = glee_BankChargePerPeriod:GetFloat()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankChargePerPeriod

    end
end

local glee_BankChargePeriod = CreateConVar( "huntersglee_bank_chargeperiod", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Period that the player's bank account is charged, in seconds. -1 for default, 86400, 1 day.", 1, 999999999999 )
local default_BankChargePeriod = 86400
function func_BankChargePeriod()
    local theVal = glee_BankChargePeriod:GetFloat()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankChargePeriod

    end
end

local somethingHasChanged = nil

local function saveBank()
    if not SERVER then return end
    GAMEMODE.bankInfoTable.savedTime = os.time()
    if not file.Exists( defaultBankDataDir, "DATA" ) then
        file.CreateDir( defaultBankDataDir )

    end
    --print( "saved" )
    --PrintTable( GAMEMODE.bankInfoTable )
    file.Write( defaultBankDataName, util.TableToJSON( GAMEMODE.bankInfoTable, true ) )

end

local function loadBank()
    if not SERVER then return end
    if not file.Exists( defaultBankDataName, "DATA" ) then return end

    local existingBankFile = file.Read( defaultBankDataName, "DATA" )
    if not existingBankFile then return end

    local decodedTbl = util.JSONToTable( existingBankFile )
    if not decodedTbl or not decodedTbl.savedTime then return end

    return decodedTbl

end

local validationsSkipped = 0
local nextBankPeriodChargeCheck = CurTime() + 1

local function validateBank()
    if not SERVER then return end
    --print( "validated" )
    validationsSkipped = 0
    local decodedTbl = loadBank()
    -- nothing saved

    -- initial load with a saved bank
    if not GAMEMODE.bankInfoTable.savedTime and decodedTbl then
        GAMEMODE.bankInfoTable = decodedTbl
        --printTable( GAMEMODE.bankInfoTable )
        --print( "loadedsavedbank" )

    end
    local osTime = os.time()

    -- process stale accounts
    if nextBankPeriodChargeCheck < CurTime() then
        nextBankPeriodChargeCheck = CurTime() + 240
        local accounts = GAMEMODE.bankInfoTable.accounts
        for steamID, account in pairs( accounts ) do
            if not bankFunctions.shouldPeriodChargeAccount( account ) then continue end

            local chargedAmount = bankFunctions.periodChargeBankAccount( account )

            print( "GLEE: " .. steamID .. "'s bank account was charged " .. chargedAmount .. " in idle fees." )

             --this doesnt care about cheat funds
            if account.funds >= 100 then continue end

            print( "GLEE: " .. steamID .. "'s bank account was closed." )
            bankFunctions.closeAccount( steamID )

        end
    end

    local needsToSave = somethingHasChanged
    needsToSave = needsToSave and ( not decodedTbl or osTime > decodedTbl.savedTime )

    if needsToSave then
        somethingHasChanged = nil
        saveBank()
        --print( "saved" )
        for _, ply in ipairs( player.GetAll() ) do
            bankFunctions.checkBankAccount( ply )

        end
    end
end

validateBank()
hook.Add( "ShutDown", "glee_validatebank_shutdown", function() 
    somethingHasChanged = true
    validateBank()

end )

hook.Add( "glee_roundstatechanged", "glee_validatebank_roundchangestates", validateBank )

local timerName = "glee_bank_savetimer"

local function updateBankTimer()
    if not SERVER then return end
    timer.Remove( timerName )
    if validationsSkipped >= 10 then
        validateBank()

    else
        validationsSkipped = validationsSkipped + 1
        timer.Create( timerName, 4, 1, validateBank )
        timer.Create( timerName, 4, 1, validateBank )

    end
end



local sv_cheats = GetConVar( "sv_cheats" )

local function isCheats()
    return sv_cheats:GetBool()

end

local function accountsFunds( account )
    if isCheats() then
        return account.cheatsFunds or 0

    else
        return account.funds or 0

    end
end

local function setAccountsFunds( account, newFunds )
    if isCheats() then
        account.cheatsFunds = newFunds

    else
        account.funds = newFunds

    end
end

bankFunctions.checkBankAccount = function( ply )
    if SERVER then
        local account = GAMEMODE.bankInfoTable.accounts[ ply:SteamID() ]
        local has
        local funds
        if not account then
            has = false
            funds = 0

        else
            has = true
            funds = accountsFunds( account )
        end

        ply:SetNW2Bool( "Glee_HasBankAccount", has )
        ply:SetNW2Int( "Glee_BankFunds", funds )

        return account

    elseif CLIENT then
        local has = ply:GetNW2Bool( "Glee_HasBankAccount", false )
        local funds = ply:GetNW2Int( "Glee_BankFunds", 0 )
        if not has then return end

        return { funds = funds, cheatsFunds = funds }

    end
end

bankFunctions.shouldPeriodChargeAccount = function( account )
    local thePeriod = func_BankChargePeriod()
    local currentTime = os.time()

    local since = currentTime - account.lastCharge
    if since < thePeriod then return end

    return true

end

bankFunctions.periodChargeBankAccount = function( account )
    local oldFunds = accountsFunds( account )

    local percentCharge = func_BankChargePerPeriod()
    local toMultiplyBy = ( 100 - percentCharge ) / 100

    account.lastCharge = os.time()

    local newFunds = oldFunds * toMultiplyBy
    local charge = math.abs( oldFunds - newFunds )
    charge = math.Round( charge )

    setAccountsFunds( account, oldFunds + -charge )

    somethingHasChanged = true

    return charge

end

local function createAccount( ply )
    local account = {}
    account.creationTime = os.time()
    account.lastCharge = account.creationTime
    GAMEMODE.bankInfoTable.accounts[ply:SteamID()] = account

end

bankFunctions.closeAccount = function( steamID )
    GAMEMODE.bankInfoTable.accounts[steamID] = nil

end

local function canDeposit( ply, toDeposit )
    local account = bankFunctions.checkBankAccount( ply )
    if not account then return end

    local funds = accountsFunds( account )

    funds = funds + toDeposit

    if funds <= 0 then return false end
    return true

end

local function bankDeposit( ply, toDeposit )
    if not SERVER then return end
    local account = bankFunctions.checkBankAccount( ply )
    if not account then return end

    local funds = accountsFunds( account )
    funds = funds + toDeposit

    if funds <= 0 then return end

    setAccountsFunds( account, funds )

    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        bankFunctions.checkBankAccount( ply )
        somethingHasChanged = true

    end )
end


local meta = FindMetaTable( "Player" )

function meta:BankCanDeposit( toDeposit )
    return canDeposit( self, toDeposit )

end

function meta:BankDepositScore( toDeposit )
    bankDeposit( self, toDeposit )
    updateBankTimer()

end

function meta:BankOpenAccount()
    createAccount( self )
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        bankFunctions.checkBankAccount( self )
        somethingHasChanged = true

    end )
end

function meta:BankHasAccount()
    return istable( bankFunctions.checkBankAccount( self ) )

end

function meta:BankAccount()
    return bankFunctions.checkBankAccount( self )

end