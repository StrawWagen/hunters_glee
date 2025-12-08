-- kill sandbox stuff

hook.Add( "PlayerNoClip", "glee_blocknoclip", function( _, wantsToEnter )
    if wantsToEnter then
        return false

    end
end )

local LocalPlayer = LocalPlayer
local function canSpawnMenu( ply )
    if not IsValid( ply ) then
        if SERVER then
            return false

        else
            ply = LocalPlayer()

        end
    end
    if not IsValid( ply ) then return false end
    if not ply:IsAdmin() then return false end
    return true

end

function GM:CanProperty( ply, _property, _ent )
    return canSpawnMenu( ply )

end

if CLIENT then
    -- will fail on first creation because of invalid localplayer
    function GM:SpawnMenuEnabled()
        return canSpawnMenu()

    end

    -- we then call it again when localplayer is valid
    hook.Add( "InitPostEntity", "glee_CreateSpawnMenu", function()
        if not canSpawnMenu() then return end
        RunConsoleCommand( "spawnmenu_reload" ) -- calls CreateSpawnMenu

    end )

    function GM:SpawnMenuOpen()
        return canSpawnMenu()

    end

    local function supressHints()
        local toSupress = {
            "OpeningMenu",
            "Annoy1",
            "Annoy2",
            "OpeningContext",
            "EditingSpawnlists",
            "EditingSpawnlistsSave",
        }

        for _, str in ipairs( toSupress ) do
            GAMEMODE:SuppressHint( str )
        end

        GAMEMODE.glee_OldAddHint = GAMEMODE.glee_OldAddHint or GAMEMODE.AddHint
        function GAMEMODE:GleeAddHint( ... )
            self:glee_OldAddHint( ... )
        end

        function GAMEMODE:AddHint() -- no extra hints
            return
        end
    end

    local function postLoaded()
        supressHints()

        -- kill menubar for non-admins
        menubar.glee_oldMenuBarInit = menubar.glee_oldMenuBarInit or menubar.Init
        menubar.Init = function()
            if not canSpawnMenu() then return end
            menubar.glee_oldMenuBarInit()

        end

        menubar.glee_oldMenuParentTo = menubar.glee_oldMenuParentTo or menubar.ParentTo
        menubar.ParentTo = function( to )
            if not canSpawnMenu() then return end
            menubar.glee_oldMenuParentTo( to )

        end
        CreateContextMenu()

    end

    hook.Add( "OnGamemodeLoaded", "Glee_CreateSpawnMenu", postLoaded )

else
    hook.Add( "PlayerSpawnObject", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerSpawnEffect", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerSpawnNPC", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerSpawnProp", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerSpawnRagdoll", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerSpawnSENT", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerSpawnSWEP", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerSpawnVehicle", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "PlayerGiveSWEP", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "CanArmDupe", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "CanDrive", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "CanTool", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "CanCreateUndo", "glee_unsandboxify", canSpawnMenu )
    hook.Add( "CanUndo", "glee_unsandboxify", canSpawnMenu )

    -- stop player was killed by x console messages
    local string_find = string.find
    local old_MsgAll = MsgAll
    function MsgAll( ... )
        for _, arg in ipairs( { ... } ) do
            if string_find( arg, "suicide" ) or string_find( arg, "killed" ) then
                return

            end
        end
        old_MsgAll( ... )

    end
end