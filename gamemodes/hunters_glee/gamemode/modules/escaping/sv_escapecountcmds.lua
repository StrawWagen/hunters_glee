
concommand.Add( "huntersglee_debug_printescapemuls", function( ply, cmd, args )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local mapName = args[1] or game.GetMap()
    local spawnSetName = args[2] or GAMEMODE:GetSpawnSet()

    permaPrint( "Map:", mapName, " | ", GAMEMODE:GetMapsEscapeMultiplier( mapName ) )
    local nominatedRows = sql.Query( "SELECT nominated FROM glee_escape_by_spawnset WHERE spawnset = " .. sql.SQLStr( spawnSetName ) )
    local nominated = nominatedRows and tonumber( nominatedRows[1].nominated ) or 0

    permaPrint( "Spawnset:", spawnSetName, " | ", GAMEMODE:GetSpawnsetsEscapeMultiplier( spawnSetName ) )
    if nominated > 0 then
        permaPrint( "Spawnset nominated:", nominated )

    end

end )

concommand.Add( "huntersglee_resetescapecount_map", function( ply, cmd, args )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local mapName = args[1]
    if not mapName or mapName == "" then
        permaPrint( "Usage: huntersglee_resetescapecount_map <mapname>" )
        return

    end

    sql.Query( "DELETE FROM glee_escape_by_map WHERE mapname = " .. sql.SQLStr( mapName ) )
    GAMEMODE.mapEscapeCountsCache[mapName] = nil
    GAMEMODE:SyncCurrEscapeMuls()

    permaPrint( "Reset escape counts for map:", mapName )

end )

concommand.Add( "huntersglee_resetescapecount_spawnset", function( ply, cmd, args )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local spawnSetName = args[1]
    if not spawnSetName or spawnSetName == "" then
        permaPrint( "Usage: huntersglee_resetescapecount_spawnset <spawnsetname>" )
        return

    end

    sql.Query( "DELETE FROM glee_escape_by_spawnset WHERE spawnset = " .. sql.SQLStr( spawnSetName ) )
    GAMEMODE.spawnsetEscapeCountsCache[spawnSetName] = nil
    GAMEMODE:SyncCurrEscapeMuls()

    permaPrint( "Reset escape counts for spawnset:", spawnSetName )

end )


-- last, so leaving it off a row doesn't misalign the columns before it
local function nominatedSuffix( nominated )
    if tonumber( nominated ) <= 0 then return "" end
    return "  nominated: " .. nominated

end

local function printEscapeTable( tblName, keyCol, sortCol )
    -- a misery nominated but never played still shows
    local rows = sql.Query(
        "SELECT " .. keyCol .. ", escaped, remained, nominated FROM " .. tblName ..
        " WHERE escaped + remained + nominated > 0 ORDER BY " .. sortCol .. " DESC"
    )
    if not rows then
        permaPrint( "  (none)" )
        return

    end
    for i, row in ipairs( rows ) do
        permaPrint( string.format( "  #%-3d  %-42s  escaped: %-6s  remained: %-6s",
            i, row[keyCol], row.escaped, row.remained ) .. nominatedSuffix( row.nominated ) )

    end
end

concommand.Add( "huntersglee_print_byescaped", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    permaPrint( "=== Maps (most escaped) ===" )
    printEscapeTable( "glee_escape_by_map", "mapname", "escaped" )

    permaPrint( "=== Spawnsets (most escaped) ===" )
    printEscapeTable( "glee_escape_by_spawnset", "spawnset", "escaped" )

end )

concommand.Add( "huntersglee_print_byremained", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    permaPrint( "=== Maps (most remained) ===" )
    printEscapeTable( "glee_escape_by_map", "mapname", "remained" )

    permaPrint( "=== Spawnsets (most remained) ===" )
    printEscapeTable( "glee_escape_by_spawnset", "spawnset", "remained" )

end )

local function printMultiplierTable( tblName, keyCol, getMul )
    local rows = sql.Query( "SELECT " .. keyCol .. ", lastescapetime, nominated FROM " .. tblName )
    if not rows then
        permaPrint( "  (none)" )
        return

    end

    local secondsPerWeek = 7 * 24 * 3600

    local entries = {}
    for _, row in ipairs( rows ) do
        local key = row[keyCol]
        local mul, escaped, remained = getMul( key )

        local weeksSince = "never"
        if escaped > 0 then
            weeksSince = "?" -- escaped before lastescapetime existed

        end

        local lastEscapeTime = tonumber( row.lastescapetime )
        if lastEscapeTime then
            weeksSince = math.floor( math.max( 0, os.time() - lastEscapeTime ) / secondsPerWeek )

        end

        entries[#entries + 1] = { key = key, mul = mul, escaped = escaped, remained = remained, nominated = row.nominated, weeksSince = weeksSince }

    end

    table.sort( entries, function( a, b ) return a.mul > b.mul end )

    for i, e in ipairs( entries ) do
        permaPrint( string.format( "  #%-3d  %-42s  mul: %-5s  escaped: %-6s  remained: %-6s  weeks since escape: %-6s",
            i, e.key, e.mul, e.escaped, e.remained, e.weeksSince ) .. nominatedSuffix( e.nominated ) )

    end
end

concommand.Add( "huntersglee_print_bymultiplier", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    permaPrint( "=== Maps (by multiplier) ===" )
    printMultiplierTable( "glee_escape_by_map", "mapname", function( key )
        return GAMEMODE:GetMapsEscapeMultiplier( key )
    end )

    permaPrint( "=== Spawnsets (by multiplier) ===" )
    printMultiplierTable( "glee_escape_by_spawnset", "spawnset", function( key )
        return GAMEMODE:GetSpawnsetsEscapeMultiplier( key )

    end )

end )