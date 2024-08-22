local GAMEMODE = GAMEMODE or GM

function GM:sendPurchaseConfirm( ply, cost, toPurchase )
    net.Start( "glee_confirmpurchase" )
        net.WriteFloat( cost )
        if toPurchase then
            net.WriteBool( true )
            net.WriteString( toPurchase )

        else
            net.WriteBool( false )

        end
    net.Send( ply )
end

function GM:purchaseItem( ply, toPurchase )
    local delay = 100 - ply:GetSignalStrength()
    delay = delay / 200

    timer.Simple( delay, function()
        if not IsValid( ply ) then return end
        --print( ply, toPurchase )
        local purchasable, notPurchasableReason = self:canPurchase( ply, toPurchase )
        if not purchasable then
            if not notPurchasableReason then return end
            ply:PrintMessage( HUD_PRINTTALK, notPurchasableReason )
            return
        end

        local dat = self.shopItems[toPurchase]
        local purchaseFunc = dat.purchaseFunc
        if purchaseFunc then
            if isfunction( purchaseFunc ) then
                local noErrors, _ = xpcall( purchaseFunc, ErrorNoHaltWithStack, ply, toPurchase )
                if noErrors == false then
                    self:invalidateShopItem( toPurchase )
                    print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s purchaseFunc function errored!!!!!!!!!!!" )
                    return

                end
            elseif purchaseFunc ~= true then
                return

            end
        end

        local theCooldown
        if dat.cooldown then
            theCooldown = self:translateShopItemCooldown( ply, toPurchase, dat.cooldown )

        end
        if theCooldown and theCooldown > 0 then
            self:doShopCooldown( ply, toPurchase, theCooldown )

            net.Start( "glee_sendshopcooldowntoplayer" )
                local cooldownClamped = math.Clamp( theCooldown, 0, 2147483645 ) -- if cooldown == 2147483645 then assume infinite, and only allow one purchase per round.
                net.WriteFloat( cooldownClamped )
                net.WriteString( toPurchase )
            net.Send( ply )

        end

        local cost = self:shopItemCost( toPurchase, ply )

        -- cool purchase sound, kaching!
        self:sendPurchaseConfirm( ply, cost, toPurchase )

        if not dat.fakeCost then
            ply:GivePlayerScore( -cost )

        end

        -- increment purchase count.. AFTER the cost is calculated...
        local name = "huntersglee_purchasecount_" .. toPurchase
        -- use nw2 because this will never be set when player is not valid clientside
        local oldCount = ply:GetNW2Int( name, 0 )
        if oldCount == 0 then
            -- clean this up when round restarts
            self:RunFunctionOnProperCleanup( function() ply:SetNW2Int( name, 0 ) end, ply )

        end
        ply:SetNW2Int( name, oldCount + 1 )

        if game.IsDedicated() then
            -- 'log' shop item purchases 
            local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
            print( nameAndId .. " Bought: " .. dat.name  )

        end
    end )
end

concommand.Add( "termhunt_purchase", function( ply, _, args, _ )
    GAMEMODE:purchaseItem( ply, args[1] )

end )

function GM:RefundShopItemCooldown( ply, toPurchase )
    GAMEMODE:noShopCooldown( ply, toPurchase )
    net.Start( "glee_invalidateshopcooldown" )
        net.WriteString( toPurchase )
    net.Send( ply )

end

function GM:CloseShopOnPly( ply )
    net.Start( "glee_closeshopholders" )
    net.Send( ply )

end

hook.Add( "PlayerSpawn", "glee_closeshopwhenspawning", function( spawned )
    net.Start( "glee_closeshopholders" )
    net.Send( spawned )

end )

hook.Add( "PlayerDeath", "glee_closeshopwhendead", function( died )
    net.Start( "glee_closeshopholders" )
    net.Send( died )

end )


-- stuff for unlocks below

local function newItemData()
    return { bought = nil, enabled = nil }

end

local function tryBuild()
    sql.Query( [[
        CREATE TABLE IF NOT EXISTS glee_playerskullshop_unlocks(
            steamid64 INT PRIMARY KEY,
            name TEXT NOT NULL,
            itemsjson TEXT
        )
    ]] )
end

local function saveUnlocksForPlayer( ply, unlocks )
    local steamId64 = ply:SteamID64()

    local unlocksJson = util.TableToJSON( unlocks, false )

    local queryUpdate = "UPDATE glee_playerskullshop_unlocks SET name = '" .. ply:Name() .. "', itemsjson = '" .. unlocksJson .. "' WHERE steamid64 = " .. steamId64 .. ";"
    local updateResult = sql.Query( queryUpdate )
    if updateResult then
        return true

    else
        local queryInsert = "INSERT INTO glee_playerskullshop_unlocks( steamid64, name, itemsjson ) VALUES( " .. steamId64 .. ", '" .. ply:Name() .. "', '" .. unlocksJson .. "' )"
        local insertResult = sql.Query( queryInsert )

        if insertResult then
            return true

        else
            return false

        end
    end
end

local function getUnlocksForPlayer( ply )
    local steamId64 = ply:SteamID64()

    local unlocksRaw = sql.Query( "SELECT itemsjson FROM glee_playerskullshop_unlocks WHERE steamid64 = " .. steamId64 )

    -- they dont have unlocks
    if not istable( unlocksRaw ) then
        local unlocks = {}
        for identifier, data in pairs( GAMEMODE.shopItems ) do
            if data.skullCost <= 0 then
                local newDat = newItemData()
                newDat.enabled = true
                newDat.bought = true
                unlocks[identifier] = newDat

            end
        end
        return unlocks
    end

    local unlocks = unlocksRaw[1]["itemsjson"]

    unlocks = util.JSONToTable( unlocks )

    return unlocks

end

local function printData()
    local result = sql.Query( "SELECT * FROM glee_playerskullshop_unlocks" )
    if result then
        PrintTable( result )
    else
        print( sql.LastError() )
    end
end

concommand.Add( "glee_printshopdata", printData, nil, "", FCVAR_CHEAT )

local function wipeData()
    sql.Query( "DROP TABLE glee_playerskullshop_unlocks" )
    print( sql.LastError() )

    timer.Simple( 0, function()
        tryBuild()
        for _, ply in player.Iterator() do
            ply.SkullUnlockData = getUnlocksForPlayer( ply )

        end
    end )
end

concommand.Add( "glee_wipeshopdata", wipeData, nil, "", FCVAR_CHEAT )

-- end sql

local nextEnabledCountManage = 0
local itemEnabledCounts = {}

local function manageEnabledCounts()
    if nextEnabledCountManage > CurTime() then return end
    nextEnabledCountManage = CurTime() + 0.1
    itemEnabledCounts = {}
    for _, ply in player.Iterator() do
        local unlockData = ply.SkullUnlockData
        if unlockData then
            for identifier, data in pairs( unlockData ) do
                if data.enabled then
                    local old = itemEnabledCounts[identifier] or 0
                    itemEnabledCounts[identifier] = old + 1

                end
            end
        end
    end

    GAMEMODE.ItemEnabledCounts = itemEnabledCounts

end

manageEnabledCounts()

function GAMEMODE:SomeoneHasEnabled( identifier )
    local count = itemEnabledCounts[identifier]
    return count and count > 0

end

local function sendFullUpdateTo( ply )
    net.Start( "glee_unlockedupdate", false )
        local count = table.Count( ply.SkullUnlockData )
        net.WriteInt( count, 16 )
        for name, data in pairs( ply.SkullUnlockData ) do
            net.WriteString( name )
            net.WriteBool( data.bought )
            net.WriteBool( data.enabled )

        end
    net.Send( ply )

end

local function plyUnlocksThink( ply, compareCRC )
    local nextRecieve = ply.glee_NextUnlockedUpdateCheck or 0
    if nextRecieve > CurTime() then return end

    ply.glee_NextUnlockedUpdateCheck = CurTime() + 1

    local skullUnlockData = ply.SkullUnlockData

    if not skullUnlockData then
        skullUnlockData = getUnlocksForPlayer( ply )
        ply.SkullUnlockData = skullUnlockData

    end

    manageEnabledCounts()

    if compareCRC then
        local currTbl = table.ToString( skullUnlockData )
        local trueCRC = util.CRC( currTbl )
        if compareCRC ~= trueCRC then
            sendFullUpdateTo( ply )

        end
    else
        sendFullUpdateTo( ply )

    end

    return skullUnlockData

end

hook.Add( "glee_plyfullload", "glee_setuplayerunlocks", function( spawned )
    plyUnlocksThink( spawned )

end )

hook.Add( "PlayerDisconnected", "glee_manageitemenabledcounts", function()
    manageEnabledCounts()

end )

net.Receive( "glee_askforunlockedupdate", function( _, sender )
    local crc = net.ReadInt( 32 )
    plyUnlocksThink( sender, crc )

end )

function GM:plyHasUnlockedItem( ply, itemName, data )
    data = data or self:GetShopItemData( itemName )
    if not data then return end
    if data.unlockMirror then
        data = self:GetShopItemData( data.unlockMirror )
        if not data then
            self:invalidateShopItem( itemName )
            print( "GLEE: !!!!!!!!!! " .. itemName .. " has invalid .unlockMirror field!!!!!!!!!!!" )

        end
    end

    if data.skullCost <= 0 then return end

    local skullUnlockData = ply.SkullUnlockData
    if not skullUnlockData then
        skullUnlockData = plyUnlocksThink( ply )

    end

    local unlockedItem = skullUnlockData[ itemName ]

    if not unlockedItem then return false end
    return unlockedItem.bought

end

function GM:unlockItem( ply, toUnlock )
    local unlockable, notUnlockableReason = self:canUnlock( ply, toUnlock )
    if not unlockable then
        if not notUnlockableReason then return end
        ply:PrintMessage( HUD_PRINTTALK, notUnlockableReason )
        return

    end
    local dat = self.shopItems[toUnlock]
    if not dat then return end

    local skullUnlockData = ply.SkullUnlockData
    if not skullUnlockData then
        skullUnlockData = plyUnlocksThink( ply )

    end

    -- Update the player's unlock data
    local itemDat = newItemData()
    skullUnlockData[toUnlock] = itemDat
    itemDat.enabled = true
    itemDat.bought = true

    saveUnlocksForPlayer( ply, skullUnlockData )

    -- Deduct the skulls cost from the player
    ply:GivePlayerSkulls( -dat.skullCost )

    -- Notify the player of the update
    sendFullUpdateTo( ply )

end

function GM:toggleUnlockedItem( ply, toUnlock )
    local dat = self.shopItems[toUnlock]
    if not dat then return end

    local skullUnlockData = ply.SkullUnlockData
    if not skullUnlockData then
        skullUnlockData = plyUnlocksThink( ply )

    end

    local dataForItem = skullUnlockData[toUnlock]

    -- not unlocked yet
    if not dataForItem then
        if dat.skullCost == 0 then
            dataForItem = newItemData()
            dataForItem.bought = true
            skullUnlockData[toUnlock] = dataForItem

        else
            return

        end
    end

    local old = dataForItem.enabled

    -- Update the player's unlock data
    dataForItem.enabled = not old

    saveUnlocksForPlayer( ply, skullUnlockData )

    -- Notify the player of the update
    sendFullUpdateTo( ply )

end

concommand.Add( "termhunt_unlock", function( ply, _, args, _ )
    GAMEMODE:unlockItem( ply, args[1] )

end )

concommand.Add( "termhunt_enabletoggle", function( ply, _, args, _ )
    GAMEMODE:toggleUnlockedItem( ply, args[1] )

end )