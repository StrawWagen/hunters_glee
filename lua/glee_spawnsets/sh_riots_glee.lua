-- incase we keep: paparazzi = reporter

local set = {
    name = "riots_glee", -- unique name
}

local function giveCamera( _, hunter )
    hunter:Give( "gmod_camera" )
end

local function giveRandomWeapon( _, hunter )
    local wpns = {"weapon_crowbar","weapon_shotgun","weapon_smg1"}

    hunter:Give( wpns[math.random(#wpns)] )
end

local annihilated = 0
local limit = 100
local ended = false

if SERVER then
    local setSv = {
        prettyName = "Riot's Glee",
        author = "dedactedlife and IndefiniteXD",
        description = "They're mad at your creations, and want all of you dead. Stop them.",
        difficultyPerMin = "default", -- difficulty per minute
        waveInterval = {3, 5}, -- time between spawn waves
        maxSpawnDist = { 2500, 3500 }, -- CLOSE!
        startingSpawnCount = 1,
        maxSpawnCount = 12,
        chanceToBeVotable = 1,
        spawns = {
            {
                hardRandomChance = nil,
                name = "angry_rioter", -- unique name
                prettyName = "Angry Rioter",
                class = "terminator_nextbot_fakeply", -- class spawned
                spawnType = "hunter",
                difficultyCost = 1,
                countClass = "terminator_nextbot*", -- class COUNTED, uses findbyclass
                minCount = { 0 }, -- will ALWAYS maintain this count
                maxCount = { 12 }, -- will never exceed this count, uses findbycount
                postSpawnedFuncs = { giveRandomWeapon },
            }
        }
    }

    table.Merge( set, setSv )
end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    if CLIENT then return end

    setHelpers.setBaseRole( self, "grunt" )

    setHelpers.addRoleVariant( self, "medic" )
    setHelpers.addRoleVariant( self, "tank" )
    setHelpers.addRoleVariant( self, "sniper" )

    self:Hook( "OnNPCKilled", function( npc )
        if CLIENT then return end
        if npc.glee_SpawnsetThatMadeMe ~= self.name then return end
        if ended then return end -- do not execute if it already ended

        annihilated = annihilated + 1 -- my poor +=
        if annihilated >= limit then
            ended = true
            huntersGlee_AnnounceDramatic( player.GetAll(), 100, 5, "All rioters have been neutralized!" )
            for ply in pairs(player.GetAll()) do
                GAMEMODE:escapifyPlayer( ply )
            end
            GAMEMODE:ForceRoundEnd()
        elseif annihilated % 10 == 0 then
            huntersGlee_Announce( player.GetAll(), 100, 5, "Rioters Left: ".. tostring((limit - annihilated)) )
        end
        
    end )
end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
