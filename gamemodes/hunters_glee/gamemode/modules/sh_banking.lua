local defaultBankDataDir = "hunters_glee"
local defaultBankDataName = defaultBankDataDir .. "/bankdata.json"
GM.bankInfoTable = GM.bankInfoTable or {}
GM.bankInfoTable.accounts = GM.bankInfoTable.accounts or {}

local bankFunctions = {}
local GAMEMODE = GM

-- % of player's bank account charged per period
local glee_BankChargePerPeriod = CreateConVar( "huntersglee_bank_chargeperperiod", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "What percent of player's bank account is charged, per period. -1 is default, 10%", -1, 100 )
local default_BankChargePerPeriod = 10
function gleefunc_BankChargePerPeriod()
    local theVal = glee_BankChargePerPeriod:GetFloat()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankChargePerPeriod

    end
end

-- charge period
local glee_BankChargePeriod = CreateConVar( "huntersglee_bank_chargeperiod", "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Period that the player's bank account is charged, in seconds. -1 for default, 86400, 1 day.", -1, 999999999999 )
local default_BankChargePeriod = 172800 -- 2 days
function gleefunc_BankChargePeriod()
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
function gleefunc_BankMinFunds()
    local theVal = glee_BankMinFunds:GetInt()
    if theVal ~= -1 then
        return math.Round( theVal, 2 )

    else
        return default_BankMinFunds

    end
end

local sv_cheats = GetConVar( "sv_cheats" )

local function isCheats()
    return sv_cheats:GetBool()

end

-- a known bug, if you switch sv_cheats to on, the bank funds don't update on client until players withdraw/deposit

-- server, everything else is shared
if SERVER then
    local somethingHasChanged = nil
    local cachedLoadedBank = nil
    local validationsSkipped = 0
    local nextBankPeriodChargeCheck = CurTime() + 1
    local timerName = "glee_bank_savetimer"

    bankFunctions.bankDeposit = function( ply, toDeposit )
        local account = bankFunctions.checkBankAccount( ply )
        if not account then return end

        local funds = bankFunctions.accountsFunds( account )
        funds = funds + toDeposit

        if funds <= 0 then return end

        bankFunctions.setAccountsFunds( account, funds )

        timer.Simple( 0, function()
            if not IsValid( ply ) then return end
            bankFunctions.checkBankAccount( ply )
            somethingHasChanged = true

        end )
    end

    bankFunctions.validateBank = function()
        validationsSkipped = 0
        local decodedTbl = bankFunctions.bankOnFile()

        -- initial load with a saved bank
        if not GAMEMODE.bankInfoTable.savedTime and decodedTbl then
            GAMEMODE.bankInfoTable = decodedTbl

        end
        local osTime = os.time()

        -- process stale accounts
        if nextBankPeriodChargeCheck < CurTime() then
            nextBankPeriodChargeCheck = CurTime() + 240
            local accounts = GAMEMODE.bankInfoTable.accounts
            for steamID, account in pairs( accounts ) do
                if bankFunctions.shouldPeriodChargeAccount( account ) ~= true then continue end

                local chargedAmount = bankFunctions.periodChargeBankAccount( account )
                print( "GLEE: " .. steamID .. "'s bank account was charged " .. chargedAmount .. " " .. account.funds .. " in idle fees." )

                --this doesnt care about cheat funds
                if account.funds >= gleefunc_BankMinFunds() then continue end

                print( "GLEE: " .. steamID .. "'s bank account was closed." )
                bankFunctions.closeAccount( steamID )

            end
        end

        local needsToSave = somethingHasChanged
        needsToSave = needsToSave and ( not decodedTbl or osTime > decodedTbl.savedTime )

        if needsToSave then
            somethingHasChanged = nil
            bankFunctions.saveBank()
            for _, ply in ipairs( player.GetAll() ) do
                bankFunctions.checkBankAccount( ply )

            end
        end
    end

    bankFunctions.saveBank = function()
        GAMEMODE.bankInfoTable.savedTime = os.time()
        if not file.Exists( defaultBankDataDir, "DATA" ) then
            file.CreateDir( defaultBankDataDir )

        end
        file.Write( defaultBankDataName, util.TableToJSON( GAMEMODE.bankInfoTable, true ) )
        bankFunctions.resetBankOnFileCache()

    end

    bankFunctions.loadBank = function()
        if not file.Exists( defaultBankDataName, "DATA" ) then return end

        local existingBankFile = file.Read( defaultBankDataName, "DATA" )
        if not existingBankFile then return end

        local decodedTbl = util.JSONToTable( existingBankFile )
        if not decodedTbl or not decodedTbl.savedTime then return end

        return decodedTbl

    end

    bankFunctions.updateBankTimer = function()
        timer.Remove( timerName )
        if validationsSkipped >= 10 then
            bankFunctions.validateBank()

        else
            validationsSkipped = validationsSkipped + 1
            timer.Create( timerName, 4, 1, bankFunctions.validateBank )

        end
    end

    bankFunctions.bankOnFile = function()
        if cachedLoadedBank then return cachedLoadedBank end

        cachedLoadedBank = bankFunctions.loadBank()
        return cachedLoadedBank

    end

    bankFunctions.resetBankOnFileCache = function()
        cachedLoadedBank = nil

    end

    bankFunctions.validateBank()
    hook.Add( "ShutDown", "glee_validatebank_shutdown", function()
        somethingHasChanged = true
        bankFunctions.validateBank()

    end )

    hook.Add( "PlayerInitialSpawn", "glee_updateplybankstuff", function( spawned )
        timer.Simple( 0, function()
            if not IsValid( spawned ) then return end
            bankFunctions.checkBankAccount( spawned )

        end )
    end )

    hook.Add( "glee_roundstatechanged", "glee_validatebank_roundchangestates", bankFunctions.validateBank )

    bankFunctions.updateOwnerName = function( account, ownerEnt )
        local ownersName = ownerEnt:Nick()
        account.ownersName = ownersName

    end

    bankFunctions.setAccountsFunds = function( account, newFunds )
        if isCheats() then
            account.cheatsFunds = newFunds

        else
            account.funds = newFunds

        end
    end

    bankFunctions.shouldPeriodChargeAccount = function( account )
        local thePeriod = gleefunc_BankChargePeriod()
        local currentTime = os.time()

        local since = currentTime - account.lastCharge
        if since < thePeriod then return end

        return true

    end

    bankFunctions.periodChargeBankAccount = function( account )
        local oldFunds = bankFunctions.accountsFunds( account )

        local percentCharge = gleefunc_BankChargePerPeriod()
        local toMultiplyBy = ( 100 - percentCharge ) / 100

        account.lastCharge = os.time()

        local newFunds = oldFunds * toMultiplyBy
        local charge = math.abs( oldFunds - newFunds )
        charge = math.Round( charge )

        bankFunctions.setAccountsFunds( account, oldFunds + -charge )

        somethingHasChanged = true

        return charge

    end

    bankFunctions.createAccount = function( ply )
        local account = {}
        account.creationTime = os.time()
        account.lastCharge = account.creationTime
        account.ownersName = ply:Nick()
        GAMEMODE.bankInfoTable.accounts[ply:SteamID()] = account

    end

    bankFunctions.closeAccount = function( steamID )
        GAMEMODE.bankInfoTable.accounts[steamID] = nil

    end

    local nextSend = 0
    -- send ALL the bank accounts to this player!
    net.Receive( "glee_requestallbankaccounts", function( _, ply )
        if nextSend > CurTime() then return end
        nextSend = CurTime() + 1

        local accounts = GAMEMODE.bankInfoTable.accounts

        local count = table.Count( accounts )
        net.Start( "glee_requestallbankaccounts" )
        net.WriteUInt( count, 32 )
        for ownersId, value in pairs( accounts ) do
            net.WriteString( ownersId ) -- steamid
            net.WriteString( value.ownersName or "Unknown" )
            net.WriteUInt( value.funds or 0, 32 )

        end
        net.Send( ply )

    end )
end
if CLIENT then
    local nextAsk = 0
    local currCallback
    function GAMEMODE:RequestAllBankAccounts( callback )
        if nextAsk > CurTime() then return false end
        nextAsk = CurTime() + 1

        net.Start( "glee_requestallbankaccounts" )
        net.SendToServer()
        currCallback = callback

        return true

    end
    net.Receive( "glee_requestallbankaccounts", function()
        if not currCallback then return end

        local accounts = {}
        local count = net.ReadUInt( 32 )
        for _ = 1, count do
            local steamID = net.ReadString()
            local ownersName = net.ReadString()
            local funds = net.ReadUInt( 32 )
            accounts[steamID] = {
                ownersName = ownersName,
                funds = funds,

            }
        end
        currCallback( accounts )
        currCallback = nil

    end )
end

bankFunctions.accountsFunds = function( account )
    if isCheats() then
        return account.cheatsFunds or 0

    else
        return account.funds or 0

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
            funds = bankFunctions.accountsFunds( account )
            bankFunctions.updateOwnerName( account, ply )

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

bankFunctions.canDeposit = function( ply, toDeposit )
    local account = bankFunctions.checkBankAccount( ply )
    if not account then return end

    local funds = bankFunctions.accountsFunds( account )

    funds = funds + toDeposit

    if funds <= 0 then return false end
    return true

end


local meta = FindMetaTable( "Player" )

function meta:BankCanDeposit( toDeposit )
    return bankFunctions.canDeposit( self, toDeposit )

end

function meta:BankDepositScore( toDeposit )
    bankFunctions.bankDeposit( self, toDeposit )
    bankFunctions.updateBankTimer()

end

function meta:BankOpenAccount()
    bankFunctions.createAccount( self )
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