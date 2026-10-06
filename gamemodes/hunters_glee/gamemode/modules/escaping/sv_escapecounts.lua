-- Tracks how many players escaped vs remained, per map and per spawnset, using SQLite.
-- Two separate tables - not paired.

util.AddNetworkString( "glee_escapemul_data" )
util.AddNetworkString( "glee_escapemul_request" )

local function initTables()
    -- adds columns that postdate the CREATE TABLE. if this grows past a column or two, switch to one declared list:
    -- TODO: ask HMM if this is good
    -- this is OKAY but not standard
    -- only forward-compatible for adding columns
    local escapeColumns = {
        { "escaped",        "INTEGER NOT NULL DEFAULT 0" },
        { "remained",       "INTEGER NOT NULL DEFAULT 0" },
        { "lastupdatetime", "INTEGER" },
        { "lastescapetime", "INTEGER" },
    }

    local function ensureTable( tblName, keyCol, columns )
        sql.Query( "CREATE TABLE IF NOT EXISTS " .. tblName .. " ( " .. keyCol .. " TEXT PRIMARY KEY )" )

        local existing = {}
        for _, col in ipairs( sql.Query( "PRAGMA table_info(" .. tblName .. ")" ) or {} ) do
            existing[col.name] = true

        end

        for _, col in ipairs( columns ) do
            if not existing[col[1]] then
                sql.Query( "ALTER TABLE " .. tblName .. " ADD COLUMN " .. col[1] .. " " .. col[2] )

            end
        end
    end

    ensureTable( "glee_escape_by_map",      "mapname",  escapeColumns )
    ensureTable( "glee_escape_by_spawnset", "spawnset", escapeColumns )

end

initTables()

-- lastupdatetime is the last round played, lastescapetime the last round anyone escaped ( NULL if nobody ever has )
local function addCounts( tblName, keyCol, keyVal, escaped, remained )
    local now = os.time()
    local escapeTime = 0
    if escaped > 0 then
        escapeTime = now

    end

    -- query credit, HMM
    local result = sql.QueryTyped(
        "INSERT INTO " .. tblName .. " (" .. keyCol .. ", escaped, remained, lastupdatetime, lastescapetime) VALUES (?, ?, ?, ?, NULLIF(?, 0))" ..
        " ON CONFLICT(" .. keyCol .. ") DO UPDATE SET" ..
        " escaped = escaped + excluded.escaped," ..
        " remained = remained + excluded.remained," ..
        " lastupdatetime = excluded.lastupdatetime," ..
        " lastescapetime = COALESCE(excluded.lastescapetime, lastescapetime)",
        keyVal, escaped, remained, now, escapeTime
    )

    if result == false then
        ErrorNoHaltWithStack( "GLEE escape counts: SQL error on " .. tblName .. ": " .. sql.LastError() )

    end
end

-- ["name"] = { escaped, remained, staleSince }
GM.mapEscapeCountsCache = {}
GM.spawnsetEscapeCountsCache = {}

function GM:UpdateEscapeCounts()
    -- has the map or spawnset been escaped?
    local escaped = GetGlobalInt( "glee_EscapedCount" )
    local remained = GetGlobalInt( "glee_RemainedCount" )
    -- if hasn't been escaped or died to, don't write anything
    if escaped + remained == 0 then return end

    local mapName = game.GetMap()
    local spawnSetName = GAMEMODE:GetSpawnSet()

    sql.Begin()
        addCounts( "glee_escape_by_map", "mapname", mapName, escaped, remained )
        self.mapEscapeCountsCache[mapName] = nil

        addCounts( "glee_escape_by_spawnset", "spawnset", spawnSetName, escaped, remained )
        self.spawnsetEscapeCountsCache[spawnSetName] = nil

    sql.Commit()

    GAMEMODE:SyncCurrEscapeMuls()

end

-- ============================================================
-- Reading

-- Returns escaped, remained, and when it started going stale
local function getRawCounts( cache, tblName, keyCol, keyVal )
    local cached = cache[keyVal]
    if cached then return cached[1], cached[2], cached[3] end

    local rows = sql.QueryTyped( "SELECT escaped, remained, lastupdatetime, lastescapetime FROM " .. tblName .. " WHERE " .. keyCol .. " = ?", keyVal )
    if not rows or not rows[1] then return 0, 0, nil end

    local escaped    = rows[1].escaped
    local remained   = rows[1].remained
    local staleSince = rows[1].lastescapetime or rows[1].lastupdatetime

    cache[keyVal] = { escaped, remained, staleSince }
    return escaped, remained, staleSince

end

local rewardPerStaleWeek = 0.1
local maxStaleReward = 2.5
GM.easyCostSoftMax = 0.75

local function escapeRatioToMultiplier( escaped, remained, staleSince )
    local base = 1
    local addedByRatio = 0
    if escaped <= 0 then -- NEVER BEEN ESCAPED! climb the mul!
        addedByRatio = 0.5 -- permanent 1.5x for first escapes
        addedByRatio = addedByRatio + math.Clamp( remained * 0.070, 0, 2 ) -- map is unescapable, up to 3.5x at first
        addedByRatio = addedByRatio + math.Clamp( remained * 0.005, 0, 1.5 ) -- and continue up to 5x for really miserable maps

    else -- the normal path
        local escapedWeighted = escaped * 1.4
        local ratio = remained / escapedWeighted
        ratio = ratio - 1
        -- if 10 escaped and 0 remained,  ratio is -1
        -- if 20 escaped and 60 remained, ratio is 1.14
        -- if 40 escaped and 60 remained, ratio is 0.07
        -- if 80 escaped and 60 remained, ratio is -0.46

        if ratio <= 0 then
            addedByRatio = math.Clamp( ratio, -1, 0 ) -- easy map, down to 0x ( floored later )

        else
            addedByRatio = math.min( ratio, 1 ) -- hard map, up to 2x
            addedByRatio = addedByRatio + math.Clamp( ratio * 0.01, 0, 1.5 ) -- very hard: slow tail, up to 3.5x

        end
    end

    local multiplier = base + addedByRatio

    -- note, un-escaped maps won't often get here, since staleSince falls back to lastupdatetime if lastescapetime is nil 
    if staleSince then
        local secondsElapsed = math.max( 0, os.time() - staleSince )
        local weeksElapsed   = math.floor( secondsElapsed / ( 7 * 24 * 3600 ) )
        -- stale weeks can only nudge the multiplier UP TO maxStaleReward, not past it
        local headroom    = math.max( 0, maxStaleReward - multiplier )
        local staleReward = math.min( weeksElapsed * rewardPerStaleWeek, headroom )
        multiplier = multiplier + staleReward

    end

    multiplier = math.max( multiplier, 0.15 ) -- floor: even the easiest map still pays out something
    multiplier = math.Round( multiplier, 2 )

    return multiplier

end


function GM:GetMapsEscapeMultiplier( mapName )
    if not mapName then return 1, 0, 0 end

    local escapedCount, remainedCount, staleSince = getRawCounts( self.mapEscapeCountsCache, "glee_escape_by_map", "mapname", mapName )
    return escapeRatioToMultiplier( escapedCount, remainedCount, staleSince ), escapedCount, remainedCount

end

function GM:GetSpawnsetsEscapeMultiplier( spawnSetName )
    if not spawnSetName or spawnSetName == "" then return 1, 0, 0 end

    local escapedCount, remainedCount, staleSince = getRawCounts( self.spawnsetEscapeCountsCache, "glee_escape_by_spawnset", "spawnset", spawnSetName )
    local multiplier = escapeRatioToMultiplier( escapedCount, remainedCount, staleSince )

    local spawnset = self:GetRegisteredSpawnSet( spawnSetName )
    if spawnset and spawnset.easy and multiplier > self.easyCostSoftMax then -- hardcoded easy round, soft clamp out the multiplier
        local aboveMax = multiplier - self.easyCostSoftMax
        multiplier = self.easyCostSoftMax + aboveMax * 0.1

    end

    return multiplier, escapedCount, remainedCount

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

function GM:SyncCurrEscapeMuls( toSync )
    local mapName = game.GetMap()
    local mapMul, mapEscaped, mapRemained = GAMEMODE:GetMapsEscapeMultiplier( mapName )

    local spawnSetName = GAMEMODE:GetSpawnSet() or "" -- can be nil if called before self.ROUND_SETUP finishes
    local spawnSetMul, spawnSetEscaped, spawnSetRemained = GAMEMODE:GetSpawnsetsEscapeMultiplier( spawnSetName )

    local entries = {
        { isSpawnset = false, key = mapName,      mul = mapMul,      escaped = mapEscaped,      remained = mapRemained },
        { isSpawnset = true,  key = spawnSetName, mul = spawnSetMul, escaped = spawnSetEscaped, remained = spawnSetRemained },
    }
    sendEscapeMulData( entries, toSync )

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

hook.Add( "glee_post_new_spawnset", "glee_escapemul_syncnew_spawnset", function()
    GAMEMODE:SyncCurrEscapeMuls( player.GetAll() )

end )
