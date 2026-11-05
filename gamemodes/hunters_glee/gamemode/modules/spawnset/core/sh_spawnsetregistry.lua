
local GM = GM or GAMEMODE

-- Every registered misery, keyed by name.
-- The server holds the full definitions. Clients only hold the public fields sv_spawnsetgobbler sends,
-- with their cl_/sh_ file's functions merged on top, and are empty until that first send arrives.
GM.RegisteredSpawnSets = GM.RegisteredSpawnSets or {}

function GM:GetSpawnSets()
    return self.RegisteredSpawnSets

end

function GM:GetRegisteredSpawnSet( setName )
    local asRegistered = self.RegisteredSpawnSets[setName]
    return asRegistered

end

function GM:GetPrettyNameOfSpawnSet( setName )
    local asRegistered = self.RegisteredSpawnSets[setName]
    if not asRegistered then return "" end
    return asRegistered.prettyName

end

-- [setName] = true, for miseries that can't spawn anything on this map, sv_spawnsetmapcheck works these out
-- empty until the navpatcher's done, so everything suits the map until then
GM.glee_SpawnsetsUnsuitedToMap = GM.glee_SpawnsetsUnsuitedToMap or {}

function GM:DoesSpawnsetSuitMap( setName )
    return not self.glee_SpawnsetsUnsuitedToMap[setName]

end

function GM:IsSpawnsetEasy( setName )
    setName = setName or self:GetSpawnSetName()
    local registered = self.RegisteredSpawnSets[setName]
    if not registered then return end

    return registered.easy

end
