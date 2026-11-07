local GM = GM or GAMEMODE

-- roles are kits a misery hands out to its players, see setHelpers.setBaseRole
-- ran before the spawnsets are gobbled, so a misery can hand them out as soon as it activates
function GM:RolesInitialThink()
    self.GobbledRoles = nil
    self.gleeRoles = {}

    local roleFiles = file.Find( "glee_spawnsetroles/*.lua", "LUA" )
    for _, name in ipairs( roleFiles ) do
        local prefix = string.sub( name, 1, 3 )
        if prefix ~= "sv_" then
            ErrorNoHaltWithStack( "GLEE: Invalid role file prefix '" .. prefix .. "' in " .. name .. "\nNeeds to be sv_" )
            continue

        end

        -- CompileFile, not include, so saving a role file doesn't autorefresh the whole gamemode
        ProtectedCall( function( nameProtected ) CompileFile( "glee_spawnsetroles/" .. nameProtected )() end, name )

    end

    local count = table.Count( self.gleeRoles )
    permaPrint( "GLEE: Gobbled " .. count .. " roles..." )

    self.GobbledRoles = true
    hook.Run( "glee_post_rolegobble" )

end

-- ran inside each role file, with roles keyed by name
function GM:GobbleRoles( roles )
    for name, data in pairs( roles ) do
        self.gleeRoles[name] = data

    end

    -- Alert, should only happen if something misuses the gobbler or if files are being re-run for dev testing.
    if self.GobbledRoles then
        permaPrint( "GLEE: !!!!!!!!!! Gobbled roles late, you must run gmod_admin_cleanup to apply the changes !!!!!!!!!!!" )

    end
end
