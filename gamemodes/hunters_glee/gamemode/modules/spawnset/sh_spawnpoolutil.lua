if SERVER then
    util.AddNetworkString( "glee_spawnset_syncpool" )
    local function sendPoolTo( spawnSet, plys )
        if not spawnSet then return end
        if not spawnSet.spawnPool then return end

        local count = table.Count( spawnSet.spawnPool )
        if count <= 0 then return end -- might happen

        net.Start( "glee_spawnset_syncpool", false )
            net.WriteInt( count, 16 )
            for class, _ in pairs( spawnSet.spawnPool ) do
                net.WriteString( class )

            end
        net.Send( plys )

    end

    local function resetPool( _, spawnSet )
        spawnSet.spawnPool = {}
        spawnSet.partialClassCache = {}
        for _, spawn in ipairs( spawnSet.spawns ) do
            spawnSet.spawnPool[spawn.class] = true
        end

        sendPoolTo( spawnSet, player.GetAll() )
    end

    hook.Add( "glee_post_set_spawnset", "glee_spawnset_sync", resetPool )
    hook.Add( "glee_post_refresh_spawnset", "glee_spawnset_sync", resetPool )

    hook.Add( "glee_full_load", "glee_spawnset_sync", function( ply )
        local _, spawnSet = GAMEMODE:GetSpawnSet()
        sendPoolTo( spawnSet, ply )

    end )

    function GM:ClassIsInSpawnPool( class )
        local _, spawnSet = self:GetSpawnSet()
        if not spawnSet.spawnPool then return end
        return spawnSet.spawnPool[class]

    end

    function GM:PartialClassIsInSpawnPool( partialClass )
        local _, spawnSet = self:GetSpawnSet()
        if not spawnSet.spawnPool then return end

        local isIn = spawnSet.partialClassCache[partialClass]
        if isIn ~= nil then return isIn end

        for poolClass, _ in pairs( spawnSet.spawnPool ) do
            if string.find( poolClass, partialClass ) then
                isIn = true
                break

            end
        end

        if not isIn then
            isIn = false

        end

        spawnSet.partialClassCache[partialClass] = isIn
        return isIn

    end

    timer.Simple( 0, function() -- autorefresh
        if not GAMEMODE then return end
        if not GAMEMODE.GetSpawnSet then return end

        local _, spawnSet = GAMEMODE:GetSpawnSet()
        sendPoolTo( spawnSet, player.GetAll() )

    end )

elseif CLIENT then
    local spawnPool
    local partialClassCache

    net.Receive( "glee_spawnset_syncpool", function()
        spawnPool = {}
        partialClassCache = {}
        local count = net.ReadInt( 16 )
        for _ = 1, count do
            local class = net.ReadString()
            spawnPool[class] = true

        end
    end )

    function GM:ClassIsInSpawnPool( class )
        if not spawnPool then return end
        return spawnPool[class]

    end

    function GM:PartialClassIsInSpawnPool( partialClass )
        if not spawnPool then return end

        local isIn = partialClassCache[partialClass]
        if isIn ~= nil then return isIn end

        for poolClass, _ in pairs( spawnPool ) do
            if string.find( poolClass, partialClass ) then
                isIn = true
                break

            end
        end

        if not isIn then
            isIn = false

        end

        partialClassCache[partialClass] = isIn
        return isIn

    end
end