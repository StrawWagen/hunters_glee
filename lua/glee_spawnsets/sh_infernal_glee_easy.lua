
local set = {
    name = "infernal_glee_easy", -- unique name
}
if SERVER then -- NavEFlags no exist on client
    local setSv = {
        prettyName = "Mildly Gleeful Inferno",
        description = "It burns, it burns! IT BURNS!",
        difficultyPerMin = "default*0.5", -- difficulty per minute
        waveInterval = "default*0.35", -- time between spawn waves
        diffBumpWhenWaveKilled = "default*4", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
        startingBudget = "default", -- so budget isnt 0
        spawnCountPerDifficulty = "default*0.5",
        startingSpawnCount = "default*5",
        maxSpawnCount = { 25 }, -- hard cap on count
        maxSpawnDist = "default*0.15", -- spawn close, these cant pathfind
        minSpawnDist = "default*0.15",
        roundEndSound = "default",
        roundStartSound = "default",
        chanceToBeVotable = 0.1,
        chanceToBeVotableWhenHard = 15, -- stick around when this is still a challenge
        genericSpawnerRate = 2, -- more crates, sooner!
        easy = true,
        spawns = {
            {
                name = "infernal_ambler", -- unique name
                prettyName = "An Infernal Ambler",
                class = "terminator_nextbot_infernalskeleton_slow", -- class spawned
                spawnType = "hunter",
                spawnSameZ = true,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                difficultyCost = 2,
            },
            {
                name = "infernal_heckler_RAREEARLY", -- unique name
                prettyName = "An Infernal Heckler",
                class = "terminator_nextbot_infernalskeleton", -- class spawned
                spawnType = "hunter",
                spawnAbove = true,
                difficultyCost = 125,
                countClass = "terminator_nextbot_infernalskeleton",
                maxCount = { 1 },
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0
                    spawned.SkeleRareRunning = true

                end },
            },
            {
                name = "infernal_heckler", -- unique name
                prettyName = "An Infernal Heckler",
                class = "terminator_nextbot_infernalskeleton", -- class spawned
                spawnType = "hunter",
                spawnSameZ = true,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                difficultyCost = 90,
                minutesNeeded = { 1, 2 },
                countClass = "terminator_nextbot_infernalskeleton",
                maxCount = { 4 },
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0
                    spawned.SkeleRareRunning = true

                end },
            },
            {
                name = "infernal_heckler_RARENUMEROUS", -- unique name
                prettyName = "An Infernal Heckler",
                class = "terminator_nextbot_infernalskeleton", -- class spawned
                spawnType = "hunter",
                spawnSameZ = true,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                difficultyCost = 500,
                countClass = "terminator_nextbot_infernalskeleton",
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0
                    spawned.SkeleRareRunning = true

                end },
            },
            {
                hardRandomChance = 5,
                name = "the_infernal_rumbler_RAREEARLY", -- unique name
                prettyName = "The Infernal Rumbler",
                class = "terminator_nextbot_infernalskeleton_large", -- class spawned
                spawnType = "hunter",
                spawnAbove = true,
                difficultyCost = { 1500, 2500 }, -- super rare early one, just added in here for fun
                countClass = "terminator_nextbot_infernalskeleton_large",
                maxCount = { 1 },
                isBoss = true, -- kill it to win!
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHeadlessChance = 0

                end },
            },
            {
                hardRandomChance = 15,
                name = "the_infernal_rumbler", -- unique name
                prettyName = "The Infernal Rumbler",
                class = "terminator_nextbot_infernalskeleton_large", -- class spawned
                spawnType = "hunter",
                spawnSameZ = true,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                difficultyCost = 150,
                minutesNeeded = { 3, 4 },
                countClass = "terminator_nextbot_infernalskeleton_large",
                maxCount = { 1 },
                isBoss = true, -- kill it to win!
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHeadlessChance = 0

                end },
            },
        }
    }
    table.Merge( set, setSv )

end


local nearbyEntHints = {
    item_item_crate = function( me )
        if GAMEMODE:HasLearnedLesson( me, "BrokeSupplies" ) then return end
        if me:GetActiveWeapon() == "weapon_crowbar" then
            return true, "Attack the crate.\nIt could contain anything!"

        else
            return true, "Your crowbar is fantastic at opening crates.\nEquip it"

        end
    end,
    prop_door_rotating = function( me )
        if GAMEMODE:HasLearnedLesson( me, "OpenedADoor" ) then return end
        local valid, phrase = GAMEMODE:TranslatedBind( "+use" )
        if not valid then GAMMODE:LearnLesson( "OpenedADoor" ) return end

        return true, "Press " .. phrase .. " to open doors!"

    end,
}


local blockTimeAddedLowHealth = 120
local blockTimeAddedOnFire = 120
local blockTimeAddedMediumHealth = 30
local blockTimeAddedFullHealth = -60
local blockTimeAddedNotMoving = 30
local blockTimeAddedNeverOpenedShop = 15
local blockTimeAddedNeverShopped = 15

local blockTimeAddedDidntMoveFar = 20
local blockTimeAddedDidntMoveAtAll = 40
local moveFar = 350^2 -- "far"
local move = 100^2

local function updateWaveStartPositions( theSet )
    local startOfWavePositions = theSet.startOfWavePositions
    if not startOfWavePositions then
        startOfWavePositions = {}
        theSet.startOfWavePositions = startOfWavePositions

    else
        table.Empty( startOfWavePositions )

    end

    for _, ply in player.Iterator() do
        if not GAMEMODE:plyIsHuntable( ply ) then continue end
        startOfWavePositions[ply] = ply:GetPos()

    end
end

function set:Activate()
    self:Hook( "glee_shop_canshow", function( _identifier, itemData )
        if not itemData.tags.Essential then return false, "This item is not essential, it's for other modes.", true end

        return nil

    end )
    self:Hook( "glee_bargains_overridecount", function( _originalCount )
        return 2

    end )
    self:Hook( "huntersglee_round_into_active", function()
        updateWaveStartPositions( self )

    end )
    self:Hook( "PlayerUse", function( ply, used )
        if used:GetClass() ~= "prop_door_rotating" then return end
        GAMEMODE:LearnLesson( ply, "OpenedADoor" )

    end )
    self:Hook( "glee_shop_itemcostmul", function( _ply, itemData, costMulTbl )
        if itemData.identifier ~= "guns" then return end
        costMulTbl[1] = costMulTbl[1] * 0.5 -- cheaper guns

    end )
    self:Hook( "huntersglee_postwavegenerated", function()
        updateWaveStartPositions( self )

    end )
    self:Hook( "huntersglee_cl_displayhint_prealivehints", function( ply )
        local hunting = GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE
        if not hunting then return end

        local myPos = ply:GetShootPos()
        local nearbyEnts = ents.FindInCone( myPos, ply:GetAimVector(), 400, 0.8 )
        local nearestDist = math.huge
        local nearestHint
        for _, ent in ipairs( nearbyEnts ) do
            local hintFunc = nearbyEntHints[ent:GetClass()]
            if not hintFunc then continue end

            local entsPos = ent:WorldSpaceCenter()

            local distSqr = entsPos:DistToSqr( myPos )
            if distSqr > nearestDist then continue end

            local valid, hint = hintFunc( ply, ent )
            if not valid then continue end

            if not terminator_Extras.PosCanSee( myPos, entsPos ) then continue end

            nearestHint = hint
            nearestDist = distSqr

        end

        if nearestHint then return true, nearestHint end

    end )
    self:Hook( "huntersglee_cl_displayhint_postalivehints", function( ply )
        local hunting = GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE
        if not hunting then return end

        if not GAMEMODE:HasLearnedLesson( "PickedUpSkull" ) and ply:GetSkulls() < 1 then
            return true, "The infernal horde is amassing somewhere...\nTake their skulls."

        end

    end )
    self:Hook( "huntersglee_spawnwavegeneration_block", function()
        local sinceLastWave = CurTime() - GAMEMODE.lastSpawnWave
        local startOfWavePositions = self.startOfWavePositions

        local blockTimes = {}
        local huntableCount = 0

        for _, ply in ipairs( player.GetAll() ) do
            if not GAMEMODE:plyIsHuntable( ply ) then continue end
            if ply:IsBot() then continue end -- not useful, don't wait for bots

            huntableCount = huntableCount + 1

            local hp = ply:Health()
            local maxHp = ply:GetMaxHealth()
            if hp <= maxHp * 0.15 then
                blockTimes["lowHealth"] = blockTimes["lowHealth"] or 0 + blockTimeAddedLowHealth

            elseif hp <= maxHp * 0.5 then
                blockTimes["mediumHealth"] = blockTimes["mediumHealth"] or 0 + blockTimeAddedMediumHealth

            elseif hp >= maxHp * 0.99 then
                blockTimes["fullHealth"] = blockTimes["fullHealth"] or 0 + blockTimeAddedFullHealth

            end

            if not GAMEMODE:HasLearnedLesson( ply, "OpenedShop" ) then
                blockTimes["neverBrowsed"] = blockTimes["neverBrowsed"] or 0 + blockTimeAddedNeverOpenedShop

            end

            if not GAMEMODE:HasLearnedLesson( ply, "BoughtAnItem" ) then
                blockTimes["neverShopped"] = blockTimes["neverShopped"] or 0 + blockTimeAddedNeverShopped

            end

            if ply:IsOnFire() then
                blockTimes["onFire"] = blockTimes["onFire"] or 0 + blockTimeAddedOnFire

            end

            local plysSpeedSqr = ply:GetVelocity():LengthSqr()
            if plysSpeedSqr <= 10^2 then
                blockTimes["notMoving"] = blockTimes["notMoving"] or 0 + blockTimeAddedNotMoving

            end

            local ourPosAtWaveStart = startOfWavePositions[ply]
            if ourPosAtWaveStart then
                local distMovedSinceLastWave = ply:GetPos():DistToSqr( ourPosAtWaveStart )

                if distMovedSinceLastWave < move then
                    blockTimes["moveAtAll"] = blockTimes["moveAtAll"] or 0 + blockTimeAddedDidntMoveAtAll

                elseif distMovedSinceLastWave < moveFar then
                    blockTimes["moveFar"] = blockTimes["moveFar"] or 0 + blockTimeAddedDidntMoveFar

                end
            end
        end

        if huntableCount <= 0 then return true end -- nobodys ready for the hunt yet

        local blockTime = 0
        for _name, added in pairs( blockTimes ) do
            --print( name, added )
            blockTime = blockTime + added

        end
        blockTime = blockTime / huntableCount

        --print( blockTime, sinceLastWave, blockTime > sinceLastWave )

        if blockTime > sinceLastWave then return true end -- BLOCK

    end )
end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
