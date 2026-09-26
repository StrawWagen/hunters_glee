local defaultDir = GM.DataFileDirectory
local defaultBankDataName = defaultDir .. "/bankdata.json"
GM.bankInfoTable = GM.bankInfoTable or {}
GM.bankInfoTable.accounts = GM.bankInfoTable.accounts or {}

local bankFunctions = GM.bankFunctions
local GAMEMODE = GAMEMODE or GM

bankFunctions.bankDataFile = defaultBankDataName

local somethingHasChanged = nil
local cachedLoadedBank = nil
local validationsSkipped = 0
local nextBankPeriodChargeCheck = CurTime() + 1
local timerName = "glee_bank_savetimer"

local sv_cheats = GetConVar( "sv_cheats" )

-- a known bug, if you switch sv_cheats to on, the bank funds don't update on client until players withdraw/deposit
bankFunctions.isCheats = function()
    return sv_cheats:GetBool()

end

bankFunctions.accountsFunds = function( account )
    if bankFunctions.isCheats() then
        return account.cheatsFunds or 0

    else
        return account.funds or 0

    end
end

-- toAdd may be negative. false, and nothing changes, when there's no account or it would leave the account at or below 0
bankFunctions.changeFunds = function( ply, toAdd )
    local account = bankFunctions.checkBankAccount( ply )
    if not account then return false end

    local funds = bankFunctions.accountsFunds( account )
    funds = funds + toAdd

    if funds <= 0 then return false end

    bankFunctions.setAccountsFunds( account, funds )

    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        bankFunctions.checkBankAccount( ply )
        somethingHasChanged = true

    end )

    return true

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

        for _, account in pairs( accounts ) do
            bankFunctions.pruneExpiredItems( account )

        end

        for steamID, account in pairs( accounts ) do
            if bankFunctions.shouldPeriodChargeAccount( account ) ~= true then continue end

            local chargedAmount = bankFunctions.periodChargeBankAccount( account )
            permaPrint( "GLEE: " .. steamID .. "'s bank account was charged " .. chargedAmount .. " " .. account.funds .. " in idle fees." )

            --this doesnt care about cheat funds
            if account.funds >= GAMEMODE:GetBankMinFunds() then continue end

            permaPrint( "GLEE: " .. steamID .. "'s bank account was closed." )
            bankFunctions.closeAccount( steamID )
            hook.Run( "glee_bankAccountClose", steamID )

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
    if not file.Exists( defaultDir, "DATA" ) then
        file.CreateDir( defaultDir )

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

bankFunctions.updateOwnerName = function( account, ownerEnt )
    local ownersName = ownerEnt:Nick()
    account.ownersName = ownersName

end

bankFunctions.setAccountsFunds = function( account, newFunds )
    -- store rounded to 1 decimal place, so the saved bank data file stays readable
    newFunds = math.Round( newFunds, 1 )
    if bankFunctions.isCheats() then
        account.cheatsFunds = newFunds

    else
        account.funds = newFunds

    end
end

bankFunctions.shouldPeriodChargeAccount = function( account )
    local thePeriod = GAMEMODE:GetBankChargePeriod()
    local currentTime = os.time()

    local since = currentTime - account.lastCharge
    if since < thePeriod then return end

    return true

end

bankFunctions.periodChargeBankAccount = function( account )
    local oldFunds = bankFunctions.accountsFunds( account )

    local percentCharge = GAMEMODE:GetBankChargePerPeriod()
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

bankFunctions.openAccount = function( ply )
    bankFunctions.createAccount( ply )
    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        bankFunctions.checkBankAccount( ply )
        somethingHasChanged = true

    end )
end

bankFunctions.closeAccount = function( steamID )
    GAMEMODE.bankInfoTable.accounts[steamID] = nil

end

-- Giving an item the account already holds replaces it, restarting its lifetime.
bankFunctions.giveItem = function( ply, name )
    local itemData = GAMEMODE.bankItems[name]
    if not itemData then return false end

    local account = GAMEMODE.bankInfoTable.accounts[ply:SteamID()]
    if not account then return false end

    local item = {}
    if itemData.lifetime then
        item.expires = os.time() + itemData.lifetime

    end

    account.items = account.items or {}
    account.items[name] = item

    somethingHasChanged = true
    bankFunctions.checkBankAccount( ply )

    return true

end

-- Unregistered items are kept, so an item file failing to load can't wipe everyone's purchases.
bankFunctions.pruneExpiredItems = function( account )
    if not account.items then return end

    for name, item in pairs( account.items ) do
        if not bankFunctions.itemExpired( item ) then continue end

        account.items[name] = nil
        somethingHasChanged = true

    end
end

-- also pushes the account to the player's NW2 vars, which is all cl_banking's checkBankAccount can see
bankFunctions.checkBankAccount = function( ply )
    local account = GAMEMODE.bankInfoTable.accounts[ply:SteamID()]
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

    local items = account and account.items
    for name in pairs( GAMEMODE.bankItems ) do
        local item = items and items[name]
        ply:SetNW2Bool( "Glee_BankItem_" .. name, item ~= nil )
        ply:SetNW2Int( "Glee_BankItemExpires_" .. name, item and item.expires or 0 ) -- 0 is never expires

    end

    return account

end

bankFunctions.validateBank()
hook.Add( "ShutDown", "glee_validatebank_shutdown", function()
    somethingHasChanged = true
    bankFunctions.validateBank()

    -- validateBank won't save twice in one os.time() second, but there's no later chance to
    if somethingHasChanged then
        bankFunctions.saveBank()

    end
end )

hook.Add( "PlayerInitialSpawn", "glee_updateplybankstuff", function( spawned )
    timer.Simple( 0, function()
        if not IsValid( spawned ) then return end
        bankFunctions.checkBankAccount( spawned )

    end )
end )

hook.Add( "glee_roundstatechanged", "glee_validatebank_roundchangestates", bankFunctions.validateBank )

local nextSend = 0
-- send ALL the bank accounts to this player!
net.Receive( "glee_requestallbankaccounts", function( _, ply )
    if nextSend > CurTime() then return end
    nextSend = CurTime() + 0.01

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

-- admin tool: print the highest-balance bank accounts to the console, lowest to highest
concommand.Add( "glee_bank_printtop", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local sorted = {}
    for steamID, account in pairs( GAMEMODE.bankInfoTable.accounts ) do
        sorted[#sorted + 1] = {
            steamID = steamID,
            ownersName = account.ownersName or "Unknown",
            funds = account.funds or 0,
        }
    end

    -- lowest to highest balance
    table.sort( sorted, function( a, b ) return a.funds < b.funds end )

    -- when there are more than 25, keep the 25 highest ( still shown lowest to highest )
    local maxToPrint = 25
    local printCount = math.min( #sorted, maxToPrint )
    local startIndex = #sorted - printCount + 1

    permaPrint( "GLEE: Showing " .. printCount .. " of " .. #sorted .. " bank accounts ( lowest to highest balance ):" )
    for i = startIndex, #sorted do
        local entry = sorted[i]
        permaPrint( string.format( "  %2d. %12.1f  %s  ( %s )", i - startIndex + 1, entry.funds, entry.ownersName, entry.steamID ) )

    end
end )


local meta = FindMetaTable( "Player" )

-- nil when there's no account
function meta:BankFunds()
    local account = bankFunctions.checkBankAccount( self )
    if not account then return end
    return bankFunctions.accountsFunds( account )

end

-- Doesn't touch the player's score, take it from them once this succeeds.
-- Returns the processing fee cut from toDeposit, or false and a reason.
function meta:BankDeposit( toDeposit )
    local fee = GAMEMODE:GetBankProcessingFeeFor( toDeposit )
    if not bankFunctions.changeFunds( self, toDeposit - fee ) then return false, "You haven't opened a bank account yet." end

    bankFunctions.updateBankTimer()
    return fee

end

function meta:BankDepositNoFee( toDeposit )
    if not bankFunctions.changeFunds( self, toDeposit ) then return false, "You haven't opened a bank account yet." end

    bankFunctions.updateBankTimer()
    return true

end

-- Takes exactly toWithdraw, charge any fee on top of it. Doesn't touch the player's score, pay them once this succeeds.
-- Returns true, or false and a reason.
function meta:BankWithdraw( toWithdraw )
    local canWithdraw, reason = self:BankCanWithdraw( toWithdraw )
    if not canWithdraw then return false, reason end

    bankFunctions.changeFunds( self, -toWithdraw )
    bankFunctions.updateBankTimer()
    return true

end

function meta:BankOpenAccount()
    bankFunctions.openAccount( self )
    bankFunctions.updateBankTimer()

end

-- false when the item isn't registered, or the player has no account to hold it
function meta:GiveBankItem( name )
    local given = bankFunctions.giveItem( self, name )
    if given then
        bankFunctions.updateBankTimer()

    end
    return given

end
