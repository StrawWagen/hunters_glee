-- everyone slowly heals, 1 health every 30s
-- just enough to undo a fall or a graze, never a comeback
-- any damage restarts the wait

local regenInterval = 30
local regenAmount = 1

local function delayRegen( ply )
    ply.glee_nextAmbientRegen = CurTime() + regenInterval

end

hook.Add( "PlayerSpawn", "glee_ambientregen", delayRegen )

hook.Add( "PostEntityTakeDamage", "glee_ambientregen", function( victim, _dmg, took )
    if not took then return end
    if not victim:IsPlayer() then return end
    delayRegen( victim )

end )

timer.Create( "glee_ambientregen", 1, 0, function()
    local cur = CurTime()
    for _, ply in player.Iterator() do
        if ply:Health() <= 0 then continue end
        if ( ply.glee_nextAmbientRegen or 0 ) > cur then continue end

        delayRegen( ply )
        ply:AddHealth( regenAmount, "glee_ambientregen" )

    end
end )
