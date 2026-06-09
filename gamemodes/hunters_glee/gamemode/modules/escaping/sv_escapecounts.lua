-- Tracks how many players escaped vs remained, per map and per spawnset, using SQLite.
-- Two separate tables - not paired.

util.AddNetworkString( "glee_escapemul_data" )
util.AddNetworkString( "glee_escapemul_request" )

local function initTables()
    sql.Query( [[
        CREATE TABLE IF NOT EXISTS glee_escape_by_map (
            mapname        TEXT PRIMARY KEY,
            escaped        INTEGER NOT NULL DEFAULT 0,
            remained       INTEGER NOT NULL DEFAULT 0,
            lastupdatetime INTEGER
        )
    ]] )

    sql.Query( [[
        CREATE TABLE IF NOT EXISTS glee_escape_by_spawnset (
            spawnset       TEXT PRIMARY KEY,
            escaped        INTEGER NOT NULL DEFAULT 0,
            remained       INTEGER NOT NULL DEFAULT 0,
            lastupdatetime INTEGER
        )
    ]] )
end

initTables()

local function addCounts( tblName, keyCol, keyVal, escaped, remained )
    local result = sql.QueryTyped(
        "INSERT INTO " .. tblName .. " (" .. keyCol .. ", escaped, remained, lastupdatetime) VALUES (?, ?, ?, ?)" ..
        " ON CONFLICT(" .. keyCol .. ") DO UPDATE SET" ..
        " escaped = escaped + excluded.escaped," ..
        " remained = remained + excluded.remained," ..
        " lastupdatetime = excluded.lastupdatetime",
        keyVal, escaped, remained, os.time()
    )

    if result == false then
        ErrorNoHaltWithStack( "GLEE escape counts: SQL error on " .. tblName .. ": " .. sql.LastError() )

    end
end

local rawCountsCache = {}

hook.Add( "huntersglee_round_into_limbo_postafter", "glee_escapecounts_record", function()
    local escaped = GetGlobalInt( "glee_EscapedCount" )
    local remained = GetGlobalInt( "glee_RemainedCount" )

    if escaped + remained == 0 then return end

    local mapName = game.GetMap()
    local spawnSetName = GAMEMODE:GetSpawnSet()

    sql.Begin()
        addCounts( "glee_escape_by_map", "mapname", mapName, escaped, remained )
        rawCountsCache[mapName] = nil

        addCounts( "glee_escape_by_spawnset", "spawnset", spawnSetName, escaped, remained )
        rawCountsCache[spawnSetName] = nil

    sql.Commit()

    GAMEMODE:SyncCurrEscapeMuls()

end )

-- ============================================================
-- Reading

local function getRawCounts( tblName, keyCol, keyVal )
    local cached = rawCountsCache[keyVal]
    if cached then return cached[1], cached[2], cached[3] end

    local rows = sql.QueryTyped( "SELECT escaped, remained, lastupdatetime FROM " .. tblName .. " WHERE " .. keyCol .. " = ?", keyVal )
    if not rows or not rows[1] then return 0, 0, nil end

    local escaped        = rows[1].escaped
    local remained       = rows[1].remained
    local lastUpdateTime = rows[1].lastupdatetime  -- nil for rows migrated before this column existed

    rawCountsCache[keyVal] = { escaped, remained, lastUpdateTime }
    return escaped, remained, lastUpdateTime

end

local rewardPerStaleWeek = 0.15

local function escapeRatioToMultiplier( escaped, remained, lastUpdateTime )
    local base = 1
    local addedByRatio = 0
    if escaped <= 0 then -- NEVER BEEN ESCAPED!
        addedByRatio = 1 -- permanent 2x for first escapes
        addedByRatio = addedByRatio + math.Clamp( remained * 0.01, 0, 1 ) -- up to 3x

    else
        local escapedWeighted = escaped * 2
        local ratio = remained / escapedWeighted
        ratio = ratio - 1
        -- if 10 escaped and 0 remained, ratio is -1
        -- if 20 escaped and 60 remained, ratio is 0.5
        -- if 40 escaped and 60 remained, ratio is -0.25
        -- if 80 escaped and 60 remained, ratio is -0.625

        addedByRatio = math.Clamp( ratio, -1, 1 ) -- up to 2x

    end

    local multiplier = base + addedByRatio

    if lastUpdateTime then
        local secondsElapsed = math.max( 0, os.time() - lastUpdateTime )
        local weeksElapsed   = math.floor( secondsElapsed / ( 7 * 24 * 3600 ) )
        multiplier = multiplier + weeksElapsed * rewardPerStaleWeek

    end

    multiplier = math.max( multiplier, 0.05 ) -- floor: even the easiest map still pays out something
    multiplier = math.Round( multiplier, 2 )

    return multiplier

end


function GM:GetMapsEscapeMultiplier( mapName )
    if not mapName then return 1, 0, 0 end

    local escapedCount, remainedCount, lastUpdateTime = getRawCounts( "glee_escape_by_map", "mapname", mapName )
    return escapeRatioToMultiplier( escapedCount, remainedCount, lastUpdateTime ), escapedCount, remainedCount

end

function GM:GetSpawnsetsEscapeMultiplier( spawnSetName )
    if not spawnSetName then return 1, 0, 0 end

    local escapedCount, remainedCount, lastUpdateTime = getRawCounts( "glee_escape_by_spawnset", "spawnset", spawnSetName )
    return escapeRatioToMultiplier( escapedCount, remainedCount, lastUpdateTime ), escapedCount, remainedCount

end

-- ============================================================
-- Syncing

local function sendEscapeMulData( entries, toSend )
    net.Start( "glee_escapemul_data" )

    net.WriteUInt( #entries, 8 ) -- up to 255 entries synced at once
    for _, entry in ipairs( entries ) do
        net.WriteBool( entry.isSpawnset )
        net.WriteString( entry.key )
        net.WriteFloat( entry.mul )
        net.WriteUInt( entry.escaped,  32 )
        net.WriteUInt( entry.remained, 32 )

    end
    if toSend then
        net.Send( toSend )

    else
        net.Broadcast()

    end
end

function GM:SyncCurrEscapeMuls( ply )
    local mapName = game.GetMap()
    local mapMul, mapEscaped, mapRemained = GAMEMODE:GetMapsEscapeMultiplier( mapName )

    local spawnSetName = GAMEMODE:GetSpawnSet() or ""
    local spawnSetMul, spawnSetEscaped, spawnSetRemained = GAMEMODE:GetSpawnsetsEscapeMultiplier( spawnSetName )

    local entries = {
        { isSpawnset = false, key = mapName,      mul = mapMul,      escaped = mapEscaped,      remained = mapRemained },
        { isSpawnset = true,  key = spawnSetName, mul = spawnSetMul, escaped = spawnSetEscaped, remained = spawnSetRemained },
    }
    sendEscapeMulData( entries, ply )

end

function GM:SyncEscapeMultipliersForSpawnsets( spawnsetNames, toSync )
    local entries = {}
    for _, spawnSetName in ipairs( spawnsetNames ) do
        local mul, escaped, remained = GAMEMODE:GetSpawnsetsEscapeMultiplier( spawnSetName )
        entries[#entries + 1] = { isSpawnset = true, key = spawnSetName, mul = mul, escaped = escaped, remained = remained }

    end
    sendEscapeMulData( entries, toSync )

end

function GM:SyncEscapeMultipliersForMaps( maps, toSync )
    local entries = {}
    for _, mapName in ipairs( maps ) do
        local mul, escaped, remained = GAMEMODE:GetMapsEscapeMultiplier( mapName )
        entries[#entries + 1] = { isSpawnset = false, key = mapName, mul = mul, escaped = escaped, remained = remained }

    end
    sendEscapeMulData( entries, toSync )

end


local nextEscapeMulRequest = {}

net.Receive( "glee_escapemul_request", function( _, ply )
    local steamID = ply:SteamID()
    local now = CurTime()
    local nextRequest = nextEscapeMulRequest[steamID] or 0
    if nextRequest > now then return end
    nextEscapeMulRequest[steamID] = now + 0.5

    local count = math.min( net.ReadUInt( 8 ), 64 )
    local results = {}
    for _ = 1, count do
        local isSpawnset = net.ReadBool()
        local key = net.ReadString()
        local mul, escaped, remained
        if isSpawnset then
            mul, escaped, remained = GAMEMODE:GetSpawnsetsEscapeMultiplier( key )

        else
            mul, escaped, remained = GAMEMODE:GetMapsEscapeMultiplier( key )

        end
        local entry = {
            isSpawnset = isSpawnset,
            key = key,
            mul = mul,
            escaped = escaped,
            remained = remained

        }
        results[#results + 1] = entry

    end

    sendEscapeMulData( results, ply )

end )

hook.Add( "glee_full_load", "glee_escapemul_syncnew", function( ply )
    GAMEMODE:SyncCurrEscapeMuls( ply )

end )


concommand.Add( "huntersglee_debug_printescapemuls", function( ply, cmd, args )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local mapName = args[1] or game.GetMap()
    local spawnSetName = args[2] or GAMEMODE:GetSpawnSet()

    print( "Map:", mapName, " | ", GAMEMODE:GetMapsEscapeMultiplier( mapName ) )
    print( "Spawnset:", spawnSetName, " | ", GAMEMODE:GetSpawnsetsEscapeMultiplier( spawnSetName ) )

end )

concommand.Add( "huntersglee_resetescapecount_map", function( ply, cmd, args )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local mapName = args[1]
    if not mapName or mapName == "" then
        print( "Usage: huntersglee_resetescapecount_map <mapname>" )
        return
    end

    sql.Query( "DELETE FROM glee_escape_by_map WHERE mapname = " .. sql.SQLStr( mapName ) )
    rawCountsCache[mapName] = nil
    GAMEMODE:SyncCurrEscapeMuls()

    print( "Reset escape counts for map:", mapName )

end )

concommand.Add( "huntersglee_resetescapecount_spawnset", function( ply, cmd, args )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local spawnSetName = args[1]
    if not spawnSetName or spawnSetName == "" then
        print( "Usage: huntersglee_resetescapecount_spawnset <spawnsetname>" )
        return
    end

    sql.Query( "DELETE FROM glee_escape_by_spawnset WHERE spawnset = " .. sql.SQLStr( spawnSetName ) )
    rawCountsCache[spawnSetName] = nil
    GAMEMODE:SyncCurrEscapeMuls()

    print( "Reset escape counts for spawnset:", spawnSetName )

end )