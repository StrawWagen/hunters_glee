local GM = GM or GAMEMODE

-- how a misery gets registered, sh_spawnsetregistry is where registered miseries are read from

--[[---------------------------------------------------------
    GM:RegisterSpawnSets
    @desc Registers every valid misery GM:BakeSpawnSets gave back.
    Templates are never registered, but still checked, so the ones people copy from can't quietly rot.
    @param toRegister: The miseries to register, by name.
    @param templates: The templates, by name.
    @return: How many registered.
--]]---------------------------------------------------------
function GM:RegisterSpawnSets( toRegister, templates )
    for _, template in SortedPairs( templates ) do
        self:IsValidSpawnSet( template )

    end

    local count = 0
    for _, spawnSet in SortedPairs( toRegister ) do
        if self:RegisterSpawnSet( spawnSet ) then
            count = count + 1

        end
    end

    return count

end

function GM:RegisterSpawnSet( spawnSet )
    if not self:IsValidSpawnSet( spawnSet ) then permaPrint( "GLEE: tried to register inavlid spawnset" ) return end

    local exists = self.RegisteredSpawnSets[spawnSet.name]
    if exists then permaPrint( "GLEE, overriding old " .. spawnSet.name .. " spawnSet" ) end

    self.RegisteredSpawnSets[spawnSet.name] = spawnSet

    return true

end
