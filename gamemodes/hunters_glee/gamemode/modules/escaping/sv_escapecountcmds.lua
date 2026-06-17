
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


local function printEscapeTable( tblName, keyCol, sortCol )
    local rows = sql.Query(
        "SELECT " .. keyCol .. ", escaped, remained FROM " .. tblName ..
        " WHERE escaped + remained > 0 ORDER BY " .. sortCol .. " DESC"
    )
    if not rows then
        print( "  (none)" )
        return

    end
    for i, row in ipairs( rows ) do
        print( string.format( "  #%-3d  %-42s  escaped: %-6s  remained: %s",
            i, row[keyCol], row.escaped, row.remained ) )

    end
end

concommand.Add( "huntersglee_print_byescaped", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    print( "=== Maps (most escaped) ===" )
    printEscapeTable( "glee_escape_by_map", "mapname", "escaped" )

    print( "=== Spawnsets (most escaped) ===" )
    printEscapeTable( "glee_escape_by_spawnset", "spawnset", "escaped" )

end )

concommand.Add( "huntersglee_print_byremained", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    print( "=== Maps (most remained) ===" )
    printEscapeTable( "glee_escape_by_map", "mapname", "remained" )

    print( "=== Spawnsets (most remained) ===" )
    printEscapeTable( "glee_escape_by_spawnset", "spawnset", "remained" )

end )

local function printMultiplierTable( tblName, keyCol, getMul )
    local rows = sql.Query( "SELECT " .. keyCol .. " FROM " .. tblName )
    if not rows then
        print( "  (none)" )
        return

    end

    local entries = {}
    for _, row in ipairs( rows ) do
        local key = row[keyCol]
        local mul, escaped, remained = getMul( key )
        entries[#entries + 1] = { key = key, mul = mul, escaped = escaped, remained = remained }

    end

    table.sort( entries, function( a, b ) return a.mul > b.mul end )

    for i, e in ipairs( entries ) do
        print( string.format( "  #%-3d  %-42s  mul: %-5s  escaped: %-6s  remained: %s",
            i, e.key, e.mul, e.escaped, e.remained ) )

    end
end

concommand.Add( "huntersglee_print_bymultiplier", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    print( "=== Maps (by multiplier) ===" )
    printMultiplierTable( "glee_escape_by_map", "mapname", function( key )
        return GAMEMODE:GetMapsEscapeMultiplier( key )
    end )

    print( "=== Spawnsets (by multiplier) ===" )
    printMultiplierTable( "glee_escape_by_spawnset", "spawnset", function( key )
        return GAMEMODE:GetSpawnsetsEscapeMultiplier( key )
    end )

end )