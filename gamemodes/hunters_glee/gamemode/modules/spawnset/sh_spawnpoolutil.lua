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

    hook.Add( "glee_post_set_spawnset", "glee_spawnset_sync", function( _, spawnSet )
        spawnSet.spawnPool = {}
        for _, spawn in ipairs( spawnSet.spawns ) do
            spawnSet.spawnPool[spawn.class] = true
        end

        sendPoolTo( spawnSet, player.GetAll() )

    end )

    hook.Add( "glee_full_load", "glee_spawnset_sync", function( ply )
        local _, spawnSet = GAMEMODE:GetSpawnSet()
        sendPoolTo( spawnSet, ply )

    end )

    function GM:ClassIsInSpawnPool( class )
        local _, spawnSet = self:GetSpawnSet()
        if not spawnSet.spawnPool then return end
        return spawnSet.spawnPool[class]

    end

elseif CLIENT then
    local spawnPool
    net.Receive( "glee_spawnset_syncpool", function()
        spawnPool = {}
        local count = net.ReadInt( 16 )
        for _ = 1, count do
            spawnPool[net.ReadString()] = true

        end
    end )

    function GM:ClassIsInSpawnPool( class )
        if not spawnPool then return end
        return spawnPool[class]

    end
end