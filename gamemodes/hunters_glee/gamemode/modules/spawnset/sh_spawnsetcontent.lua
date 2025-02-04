if SERVER then
    util.AddNetworkString( "glee_spawnsetcontent_asker" )

    local function content()
        local _, spawnSet = GAMEMODE:GetSpawnSet()
        local contentTbl = spawnSet.resourcesAdded
        if not contentTbl then return end
        if #contentTbl <= 0 then return end

        return contentTbl

    end

    local function updateContent( plysIn )
        local contentTbl = content()
        if not contentTbl then return end

        SetGlobalInt( "GLEE_SpawnSet_ContentCount", #contentTbl )
        local plys
        if istable( plysIn ) then
            plys = plysIn

        else
            plys = { plysIn }

        end
        net.Start( "glee_spawnsetcontent_asker", false )
            for _, contentStr in ipairs( contentTbl ) do
                net.WriteString( contentStr )

            end
        net.Send( plys )
    end

    hook.Add( "glee_post_set_spawnset", "glee_spawnset_content", function( _, spawnSet )
        if not ( spawnSet.resourcesAdded and #spawnSet.resourcesAdded >= 0 ) then return end

        SetGlobalInt( "GLEE_SpawnSet_ContentCount", #spawnSet.resourcesAdded )

        timer.Simple( 1, function()
            updateContent( player.GetAll() )
            hook.Add( "huntersglee_round_into_active", "glee_update_spawnset_content", function()
                if not content() then hook.Remove( "huntersglee_round_into_active", "glee_update_spawnset_content" ) return end
                updateContent( player.GetAll() )

            end )
            hook.Add( "glee_full_load", "glee_update_spawnset_content", function( ply )
                if not content() then hook.Remove( "glee_full_load", "glee_update_spawnset_content" ) return end
                updateContent( ply )

            end )
            timer.Create( "glee_contentbackup", 60, 0, function() -- putting this here because im especially worried about GlobalInt not working right, it often doesn't
                if not content() then timer.Remove( "glee_contentbackup" ) return end
                updateContent( player.GetAll() )

            end )
        end )
    end )

else
    local nextThink = 0
    local contentTried = {}
    local contentTodo = {}
    local thinking

    local function tryDoingContent()
        if thinking then return end
        if #contentTodo <= 0 then return true end -- all done

        local currContent = table.remove( contentTodo, 1 )
        if not currContent or not isstring( currContent ) then return end -- just in case

        if contentTried[currContent] then return end

        contentTried[currContent] = true
        thinking = true

        MsgN( "GLEE: mounting " .. currContent )
        steamworks.DownloadUGC( currContent, function( path )
            thinking = nil
            if not path then return end
            local succeed = game.MountGMA( path )

            if not succeed then return end
            MsgN( "GLEE: successfully mounted " .. currContent )

        end )
    end

    net.Receive( "glee_spawnsetcontent_asker", function()
        if nextThink > CurTime() then return end
        nextThink = CurTime() + 0.5

        local count = GetGlobalInt( "GLEE_SpawnSet_ContentCount", 0 )
        if count <= 0 then return end

        for _ = 1, count do
            local currContent = net.ReadString()
            table.insert( contentTodo, currContent )

        end
        hook.Add( "Think", "glee_spawnset_getcontent", function() 
            local allDone = tryDoingContent()
            if allDone then hook.Remove( "Think", "glee_spawnset_getcontent" ) return end

        end )
    end )
end