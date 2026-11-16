-- copy this file to make your own misery
-- every field is in the README, under "Adding Spawnsets"

-- want it hardcore? makeHardcore needs an sh_ file
-- rename your copy to sh_, and put everything but name and Activate inside an "if SERVER then" block
-- sh_combine_onslaught.lua does exactly that

local exampleSet = {
    name = "default_example", -- unique name
    template = true, -- DELETE THIS in your copy, it keeps this misery out of the vote
    prettyName = "Default Example",
    description = "A misery to copy.", -- best used as a hint that teases what's coming
    -- author = "Me", -- shown under the description as "by Me"
    -- chanceToBeVotable = 0.5, -- percent chance to show up in the !rtm vote, 0 - 100
    -- maxSpawnCount = 6, -- hard cap on hunter count, 10 is default
    -- startWeapons = { { class = "weapon_smg1", purchaseClips = 3 } }, -- everyone gets one each round

    spawns = {
        {
            name = "example_hunter", -- unique name
            prettyName = "A Hunter",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 10, 15 }, -- budget it costs, entries are checked from highest cost to lowest
            -- minCount = { 1 }, -- always keep this many
        },

            -- most miseries pair entries like this, a rare few early, then lots once the round heats up
        -- {
        --     hardRandomChance = { 0, 15 },
        --     name = "example_shotgunner_RARE",
        --     prettyName = "A Shotgunner",
        --     class = "terminator_nextbot_cshotgunsoldier",
        --     spawnType = "hunter",
        --     difficultyCost = { 20, 30 }, -- pricey, so only a big wave fits one
        --     difficultyNeeded = { 25, 50 },
        --     maxCount = { 2 }, -- a taste
        -- },
        -- {
        --     hardRandomChance = { 25, 45 },
        --     name = "example_shotgunner_COMMON",
        --     prettyName = "A Shotgunner",
        --     class = "terminator_nextbot_cshotgunsoldier",
        --     spawnType = "hunter",
        --     difficultyCost = { 4, 6 }, -- cheap, so waves fill up with them
        --     difficultyNeeded = { 150, 200 }, -- the flood
        -- },
    },
}

-- runs when the misery changes to this one, see "Spawnset Example E: Lifecycle" in the README
-- function exampleSet:Activate()
--     GAMEMODE.setHelpers.overridePlayerModel( self, function( ply ) return "models/player/group03/male_07.mdl" end )
-- end

table.insert( GLEE_SPAWNSETS, exampleSet )
