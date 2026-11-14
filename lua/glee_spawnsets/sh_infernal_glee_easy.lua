
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
        genericSpawnerRate = 0.5, -- more crates, sooner!
        breathingRoom = 1,
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
                maxCount = { 1 },
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0
                    spawned.SkeleRunsAfterEnemySprints = true

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
                maxCount = { 4 },
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0
                    spawned.SkeleRunsAfterEnemySprints = true

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
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0
                    spawned.SkeleRunsAfterEnemySprints = true

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


local urgentHint = { urgent = true }

local buttonClasses = {
    func_button = true,
    func_rot_button = true,
}

local function buttonHint( me )
    if GAMEMODE:HasLearnedLesson( me, "PressedAButton" ) then return end
    local valid, phrase = GAMEMODE:TranslatedBind( "+use" )
    if not valid then return GAMEMODE:UnboundHint( "+use", "You can't press buttons..." ) end

    return true, "Press " .. string.upper( phrase ) .. " to interact with buttons!"

end

local nearbyEntHints = {
    item_item_crate = function( me )
        if GAMEMODE:HasLearnedLesson( me, "BrokeSupplies" ) then return end
        if me:GetActiveWeapon():GetClass() == "weapon_crowbar" then
            return true, "Attack the crate.\nIt could contain anything!"

        else
            return true, "Your crowbar is for opening crates.\nEquip it."

        end
    end,
    prop_door_rotating = function( me )
        if GAMEMODE:HasLearnedLesson( me, "OpenedADoor" ) then return end
        local valid, phrase = GAMEMODE:TranslatedBind( "+use" )
        if not valid then return GAMEMODE:UnboundHint( "+use", "You can't open doors..." ) end

        return true, "Press " .. string.upper( phrase ) .. " to open doors!"

    end,
    item_battery = function( me )
        if me:Armor() < me:GetMaxArmor() then return end
        if not me:IsPlayerHolding() then return end
        return true, "FULL BATTERY"

    end,
    terminator_nextbot_infernalskeleton_slow = function( _me )
        GAMEMODE:LearnLesson( "FoundInfernalSkeleton" )

    end
}
for class in pairs( buttonClasses ) do
    nearbyEntHints[class] = buttonHint

end

-- surfaces you can walk into but can't see
local invisibleTextures = {
    ["TOOLS/TOOLSPLAYERCLIP"] = true,
    ["TOOLS/TOOLSCLIP"] = true,
    ["TOOLS/TOOLSINVISIBLE"] = true,
}
local invisibleWallDist = 64

local function isAimingAtInvisibleWall( ply )
    local start = ply:GetShootPos()
    local tr = util.TraceLine( {
        start = start,
        endpos = start + ply:GetAimVector() * invisibleWallDist,
        mask = MASK_PLAYERSOLID,
        filter = ply,
    } )
    if not tr.HitWorld then return false end

    return tr.HitSky or tr.HitNoDraw or invisibleTextures[string.upper( tr.HitTexture )] or false

end

function set:Activate()
    self:Hook( "glee_shop_canshow", function( _identifier, itemData )
        if not itemData.tags.Essential then return false, "This item is not essential, it's for other modes.", true end

        return nil

    end )
    self:Hook( "glee_bargains_overridecount", function( _originalCount )
        return 2

    end )
    self:Hook( "glee_shop_itemcostmul", function( _ply, itemData, adjust )
        if itemData.identifier ~= "guns" then return end
        adjust.mul = adjust.mul * 0.5 -- cheaper guns

    end )
    if SERVER then
        self:Hook( "PlayerUse", function( ply, used )
            local class = used:GetClass()
            if class == "prop_door_rotating" then
                GAMEMODE:LearnLesson( ply, "OpenedADoor" )

            elseif buttonClasses[class] then
                GAMEMODE:LearnLesson( ply, "PressedAButton" )

            end
        end )

        -- the engine hands out battery charge itself, so this checks what it gave a tick later
        self:Hook( "PlayerCanPickupItem", function( ply, item )
            if item:GetClass() ~= "item_battery" then return end
            local oldArmor = ply:Armor()
            if oldArmor >= ply:GetMaxArmor() then return end -- asked every tick they stand on one

            timer.Simple( 0, function()
                if not IsValid( ply ) then return end
                local gained = ply:Armor() - oldArmor
                if gained <= 0 then return end

                huntersGlee_Notify( { ply }, {
                    text = "BATTERY CHARGED +" .. gained,
                    kind = "good",
                    replaceKey = "glee_tutorial_suitcharged",
                    onlyWhile = "alive",
                } )
            end )
        end )

    elseif CLIENT then
        self:Hook( "huntersglee_cl_displayhint_prealivehints", function( ply )
            if isAimingAtInvisibleWall( ply ) then
                return true, "CANNOT PROCEED\nunexplained surface detected"

            end

            local myPos = ply:GetShootPos()
            local nearbyEnts = ents.FindInCone( myPos, ply:GetAimVector(), 250, math.cos( math.rad( 80 ) ) )
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

                if not terminator_Extras.PosCanSee( myPos, entsPos, MASK_SOLID_BRUSHONLY ) then continue end

                nearestHint = hint
                nearestDist = distSqr

            end

            if nearestHint then return true, nearestHint end

        end )
        self:Hook( "huntersglee_cl_displayhint_postalivehints", function( ply )
            local hunting = GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE
            if not hunting then return end

            if ply:GetSkulls() < 1 then
                if not GAMEMODE:HasLearnedLesson( "FoundInfernalSkeleton" ) then
                    return true, "The infernal horde is amassing somewhere...\nHunt them down.", urgentHint

                elseif not GAMEMODE:HasLearnedLesson( "PickedUpSkull" ) and not GetGlobal2Bool( "glee_pleaseshow_rtmtutorialhint", false ) then
                    return true, "Some of the infernal skeletons still have heads...\nCollect their skulls.", urgentHint

                end
            end
        end )
    end
end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
