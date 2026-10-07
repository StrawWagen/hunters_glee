
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


-- By index: a boss outside a client's PVS doesn't exist there yet
util.AddNetworkString( "glee_bossspawned" )

local function tellAboutBoss( boss, recipients )
    net.Start( "glee_bossspawned" )
        net.WriteUInt( boss:EntIndex(), MAX_EDICT_BITS )
    net.Send( recipients )

end

-- see GM:IsActiveBoss
function GM:RegisterBoss( boss )
    boss:SetNW2String( "glee_BossOfSpawnset", self.CurrSpawnSetName )

    tellAboutBoss( boss, player.GetAll() )

end

hook.Add( "glee_full_load", "glee_tellaboutbosses", function( ply )
    for _, hunter in ipairs( GAMEMODE.glee_Hunters ) do
        if not IsValid( hunter ) then continue end
        if not GAMEMODE:IsActiveBoss( hunter ) then continue end

        tellAboutBoss( hunter, ply )

    end
end )

hook.Add( "OnNPCKilled", "glee_bossKilled", function( npc, attacker )
    if not IsValid( npc ) then return end
    if not IsValid( attacker ) then return end

    if not GAMEMODE:IsActiveBoss( npc ) then return end

    local goodDeath = attacker:IsPlayer() or attacker:IsNPC() or attacker.isGleeRescueHeli

    if not goodDeath then
        hook.Run( "glee_onboss_crappydefeated", npc, attacker )

    end

    GAMEMODE.roundExtraData.bossKilled = true
    hook.Run( "glee_onboss_defeated", npc, attacker )

end )