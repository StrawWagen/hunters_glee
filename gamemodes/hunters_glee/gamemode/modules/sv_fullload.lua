-- https://github.com/CFC-Servers/gm_playerload

local loadQueue = {}

hook.Add( "PlayerInitialSpawn", "glee_FullLoadSetup", function( ply )
    loadQueue[ply] = true

end )

hook.Add( "SetupMove", "glee_FullLoadTrigger", function( ply, _, cmd )
    if not loadQueue[ply] then return end
    if cmd:IsForced() then return end

    loadQueue[ply] = nil
    ply.glee_FullLoaded = true
    hook.Run( "glee_full_load", ply )

end )

for _, ply in player.Iterator() do -- auhto re fresh
    ply.glee_FullLoaded = true

end