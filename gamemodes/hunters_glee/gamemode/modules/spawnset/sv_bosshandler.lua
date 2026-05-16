
-- spawn entry field: .isBoss
-- Optional. When this entry's NPC is killed, all alive players escape.
-- true  — explicitly mark as boss.
-- false — opt out of auto-detection.
-- nil   — auto-detected: if spawnSet.maxSpawnCount <= 1, the highest difficultyCost entry becomes the boss.

function GM:HandleBossDetection( spawnSet )
    -- if any entry already explicitly declares isBoss, leave it alone
    for _, spawn in ipairs( spawnSet.spawns ) do
        if spawn.isBoss then return end

    end

    -- only auto-assign when the spawnset is a single-hunter scenario
    if spawnSet.maxSpawnCount > 1 then return end

    -- mark the most expensive eligible entry
    local bestSpawn = nil
    local bestCost = -math.huge

    for _, spawn in ipairs( spawnSet.spawns ) do
        if spawn.isBoss == false then continue end -- explicit opt-out
        if spawn.difficultyCost > bestCost then
            bestCost = spawn.difficultyCost
            bestSpawn = spawn

        end
    end

    if not bestSpawn then return end

    bestSpawn.isBoss = true

end

hook.Add( "OnNPCKilled", "glee_bossKilled", function( npc, attacker )
    if not IsValid( npc ) then return end
    if not IsValid( attacker ) then return end

    if not attacker:IsPlayer() then return end

    if not npc.glee_IsBoss then return end

    GAMEMODE.roundExtraData.bossKilled = true
    hook.Run( "glee_onbossdefeated", npc, attacker )

end )