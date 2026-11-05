
local GM = GM or GAMEMODE

-- can a spawn entry, and so a whole misery, ever spawn anything on this map?
-- the navmesh flags these lean on aren't there until the navpatcher's done

util.AddNetworkString( "glee_spawnsetsunsuitedtomap" )

-- [an entry's canSpawnOnMap] = its answer
-- keyed by the function, so every round's parsed copy of an entry shares the registered one's answer
local canSpawnOnMapAnswers = {}

-- before the navpatcher's done, an entry with anything to check is false, and asked again later
function GM:CanEntrySpawnOnMap( spawnEntry )
    -- MarchValidHunterPos can never place it, and a queued spawn that can't place holds up its wave until it's dropped
    local preferredEFlags = spawnEntry.preferredEFlags
    if preferredEFlags and spawnEntry.firmPreferredEFlags and not self:MapHasEFlags( preferredEFlags ) then return false end

    local canSpawnOnMap = spawnEntry.canSpawnOnMap
    if not canSpawnOnMap then return true end
    if not self.glee_NavpatcherFinished then return false end

    local answer = canSpawnOnMapAnswers[canSpawnOnMap]
    if answer == nil then
        local noErrors, canSpawn = xpcall( canSpawnOnMap, ErrorNoHaltWithStack, spawnEntry )
        answer = noErrors and canSpawn and true or false
        canSpawnOnMapAnswers[canSpawnOnMap] = answer

    end
    return answer

end

local function sendUnsuitedSpawnsets( plyOrPlys )
    local unsuited = GAMEMODE.glee_SpawnsetsUnsuitedToMap

    net.Start( "glee_spawnsetsunsuitedtomap" )
        net.WriteUInt( table.Count( unsuited ), 16 )
        for setName, _ in pairs( unsuited ) do
            net.WriteString( setName )

        end
    net.Send( plyOrPlys )

end

local function warnIfActiveIsUnsuited()
    local setName = GAMEMODE:GetSpawnSetName()
    if GAMEMODE:DoesSpawnsetSuitMap( setName ) then return end
    permaPrint( "GLEE: the active Misery, " .. setName .. ", can't spawn anything on this map" )

end

-- a misery with spawns, none of which can ever spawn here, doesn't suit the map
-- one with no spawns at all meant it
local function findUnsuitedSpawnsets()
    if not GAMEMODE.glee_NavpatcherFinished then return end
    if not GAMEMODE.GobbledSpawnsets then return end

    local unsuited = {}
    for setName, spawnSet in pairs( GAMEMODE:GetSpawnSets() ) do
        local spawns = spawnSet.spawns
        if #spawns <= 0 then continue end

        local anyCanSpawn
        for _, spawnEntry in ipairs( spawns ) do
            if GAMEMODE:CanEntrySpawnOnMap( spawnEntry ) then
                anyCanSpawn = true
                break

            end
        end

        if anyCanSpawn then continue end
        unsuited[setName] = true
        permaPrint( "GLEE: " .. setName .. " can't spawn anything on this map, it's out of the Misery vote" )

    end

    GAMEMODE.glee_SpawnsetsUnsuitedToMap = unsuited
    sendUnsuitedSpawnsets( player.GetAll() )
    warnIfActiveIsUnsuited()

end

-- whichever of these comes last
hook.Add( "glee_navpatcher_finish", "glee_spawnsetmapcheck", function()
    GAMEMODE.glee_NavpatcherFinished = true
    findUnsuitedSpawnsets()

end )

hook.Add( "glee_post_spawnsetgobble", "glee_spawnsetmapcheck", findUnsuitedSpawnsets )

hook.Add( "glee_post_new_spawnset", "glee_spawnsetmapcheck", warnIfActiveIsUnsuited )

hook.Add( "glee_full_load", "glee_spawnsetmapcheck", sendUnsuitedSpawnsets )
