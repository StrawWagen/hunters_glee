
-- PData records that last until a timestamp, eg persistent guilt, first time player status
-- store os.time() + duration as the value, and wipe the expired rows once a map with WipeExpiredPData
-- so the table only ever holds records that still mean something

-- PData keys are "<steamid64>[<name>]", and LIKE treats _ as a single-char wildcard, hence the escape
-- value is a TEXT column, so a bare compare is lexicographic, and only correct while every
-- timestamp is the same digit count. the CAST makes it numeric
local wipeExpiredQuery = [[
    DELETE FROM playerpdata
    WHERE infoid LIKE ? ESCAPE '\'
    AND CAST( value AS INTEGER ) < ?
]]

-- returns how many rows were wiped, nil if the wipe failed
function GM:WipeExpiredPData( name )
    local escapedName = string.gsub( name, "[\\_%%]", "\\%0" )
    local wiped = sql.QueryTyped( wipeExpiredQuery, "%[" .. escapedName .. "]", os.time() )
    if wiped == false then
        ErrorNoHaltWithStack( "glee expired " .. name .. " wipe failed: " .. tostring( sql.LastError() ) )
        return

    end

    -- changes() reports the last write on the connection, so nothing may query between here and the delete
    local changed = sql.QueryTyped( "SELECT changes() AS wipedCount" )
    if not changed then return end

    -- QueryTyped, not Query, so this is a number and not a string
    return changed[1].wipedCount

end
