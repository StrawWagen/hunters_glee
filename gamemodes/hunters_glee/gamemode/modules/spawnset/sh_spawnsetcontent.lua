if SERVER then
    util.AddNetworkString( "glee_spawnsetcontent_asker" )

    local function content()
        local _, spawnSet = GAMEMODE:GetSpawnSet()
        local contentTbl = spawnSet.resourcesAdded
        if not contentTbl then return end
        if #contentTbl <= 0 then return end

        return contentTbl

    end

    local function updateContent( plys )
        local contentTbl = content()
        if not contentTbl then return end

        SetGlobalInt( "GLEE_SpawnSet_ContentCount", #contentTbl )
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
                updateContent( { ply } )

            end )
            timer.Create( "glee_contentbackup", 60, 0, function() -- putting this here because im especially worried about GlobalInt not working right, it often doesn't
                if not content() then timer.Remove( "glee_contentbackup" ) return end
                updateContent( player.GetAll() )

            end )
        end )
    end )

else
    local developer = GetConVar( "developer" )
    local function isDeveloping()
        return developer and developer:GetInt() > 0

    end

    local function devPrint( ... )
        if not isDeveloping() then return end
        print( ... )

    end

    local contentTried = {}
    local contentTodo = {}
    local nextThink = 0
    local thinking

    -- catch invalid Material() calls, store invalid materials, so we can rebuild them after the content is downloaded
    terminator_Extras.glee_InvalidMats = {}
    terminator_Extras.glee_OldMaterial = terminator_Extras.glee_OldMaterial or Material
    local oldMaterial = terminator_Extras.glee_OldMaterial
    function Material( name, params )
        local mat = oldMaterial( name, params )
        if mat:IsError() and not terminator_Extras.glee_InvalidMats[name] then
            terminator_Extras.glee_InvalidMats[name] = { name = name, mat = mat, params = params }

        end
        return mat

    end

    local function fixBrokeMaterials( stuffMounted )
        local materialsMounted = {}
        for _, mountedName in ipairs( stuffMounted ) do
            if string.StartsWith( mountedName, "materials/" ) then
                table.insert( materialsMounted, mountedName )

            end
        end

        devPrint( "GLEE: trying to fix " .. #materialsMounted .. " materials" )

        if isDeveloping() then
            PrintTable( materialsMounted )
            for invalidMatName, _ in pairs( terminator_Extras.glee_InvalidMats ) do
                print( invalidMatName )

            end
        end

        local fixed = {}
        for _, mountedName in ipairs( materialsMounted ) do
            for invalidMatName, matData in pairs( terminator_Extras.glee_InvalidMats ) do
                if string.find( mountedName, invalidMatName ) then -- all the mounted stuff is gonna be like material.vmt, etc
                    if fixed[invalidMatName] then continue end -- already fixed this one
                    local mat = matData.mat

                    local nameToTry = mountedName
                    nameToTry = string.Replace( nameToTry, "materials/", "" )

                    local wasProperMat = string.EndsWith( nameToTry, ".vmt" ) -- mat probably has custom params

                    local tempMat = Material( nameToTry, matData.params )
                    if tempMat:IsError() then
                        devPrint( "GLEE: " .. nameToTry .. " FAILFIX 1" )
                        continue

                    end

                    devPrint( "GLEE: fixing material " .. invalidMatName .. " with " .. nameToTry )
                    mat:SetTexture( "$basetexture", tempMat:GetTexture( "$basetexture" ) ) -- we need to update the actual material!

                    if wasProperMat then -- no way to set mat values generically? would operate over tempMat:GetKeyValues() if there was?
                        mat:SetInt( "$alphatest", tempMat:GetInt( "$alphatest" ) or 0 )
                        mat:SetInt( "$nocull", tempMat:GetInt( "$nocull" ) or 0 )
                        mat:SetInt( "$ignorez", tempMat:GetInt( "$ignorez" ) or 0 )
                        mat:SetInt( "$vertexcolor", tempMat:GetInt( "$vertexcolor" ) or 0 )
                        mat:SetInt( "$vertexalpha", tempMat:GetInt( "$vertexalpha" ) or 0 )
                        mat:SetInt( "$mips", tempMat:GetInt( "$mips" ) or 0 )
                        mat:SetInt( "$noclamp", tempMat:GetInt( "$noclamp" ) or 0 )
                        mat:SetInt( "$smooth", tempMat:GetInt( "$smooth" ) or 0 )

                    end

                    mat:Recompute()
                    devPrint( "GLEE: " .. invalidMatName .. " fixed!" )
                    fixed[invalidMatName] = true

                end
            end
        end
    end

    local function tryDoingContent()
        if thinking then return end
        if nextThink > CurTime() then return end
        if #contentTodo <= 0 then return true end -- all done

        local currContent = table.remove( contentTodo, 1 )
        if not currContent or not isstring( currContent ) then return end -- just in case

        if contentTried[currContent] then return end

        contentTried[currContent] = true
        thinking = true
        nextThink = CurTime() + 0.1

        MsgN( "GLEE: mounting " .. currContent )
        steamworks.DownloadUGC( currContent, function( path )
            thinking = nil
            nextThink = CurTime() + 0.1

            if not path then return end
            local succeeded, stuffMounted = game.MountGMA( path )

            if not succeeded then return end
            MsgN( "GLEE: successfully mounted " .. currContent )

            if not stuffMounted then return end
            fixBrokeMaterials( stuffMounted )

        end )
    end

    local nextRecieve = 0
    net.Receive( "glee_spawnsetcontent_asker", function()
        if nextRecieve > CurTime() then return end
        nextRecieve = CurTime() + 0.5

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