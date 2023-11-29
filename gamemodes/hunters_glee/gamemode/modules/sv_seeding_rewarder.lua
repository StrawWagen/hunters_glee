-- intended functionality
-- if player is first, or second player to join, give them seeding score
-- every player that joins after them, calls a hook

--FIX!
-- rewards first person to load after map changes..... -done i think
-- doesnt reward first person if the second one joins after the timer!

local CurTime = CurTime

local lastHitSeedCap = 0
GM.seedPlayers = GM.seedPlayers or {}


local minutesToReset = CreateConVar( "seedply_minutestoreset", "-1", FCVAR_ARCHIVE, "-1 for default. Minutes. How long before the list of seed players resets." )
local default_minutesToReset = 5

local function minutesToResetFunc()
    local theVal = minutesToReset:GetFloat()
    if theVal <= -1 then return default_minutesToReset end

    return theVal

end

local maxSeedingPlayers = CreateConVar( "seedply_maxseeds", "-1", FCVAR_ARCHIVE, "-1 for default. How many seed players before we stop calling the hook." )
local default_maxSeedingPlayers = 3

local function maxSeedingPlayersFunc()
    local theVal = maxSeedingPlayers:GetInt()
    if theVal <= -1 then return default_maxSeedingPlayers end

    return theVal

end

local seedingIsEnabled = CreateConVar( "seedply_doseeding", "-1", FCVAR_ARCHIVE, "-1 for default. Do seeding bonuses?" )
local default_seedingIsEnabled = true

local function seedingIsEnabledFunc()
    local theVal = seedingIsEnabled:GetInt()
    if theVal <= -1 then return default_seedingIsEnabled end

    return seedingIsEnabled:GetBool()

end
-- check static stuff
local function isSeedableSession()
    if not game.IsDedicated() then return end
    if not seedingIsEnabledFunc() then return end

    return true

end

local timerName = "glee_resetSeedsTimer"
timer.Remove( timerName )

local serverStartedGracePeriod = 10 * 60
local mapStartedGracePeriod = 2 * 60

local function mapJustChanged()
    local mapJustStarted = CurTime() < mapStartedGracePeriod
    local serverJustStarted = RealTime() < serverStartedGracePeriod

    if mapJustStarted then
        -- let first ply to join get the reward
        if serverJustStarted then return end
        return true

    end
end

function GM:ResetSeedCapTime()
    local timeNeededToReset = minutesToResetFunc() * 60

    lastHitSeedCap = CurTime()

    timeNeededToReset = math.max( timeNeededToReset, 60 )

    timer.Remove( timerName )
    timer.Create( timerName, timeNeededToReset + 1, 1, function()
        GAMEMODE:ResetSeedCapTime()
        GAMEMODE:VerifySeedPlayers()

    end )
end

function GM:VerifySeedPlayers()
    local maxSeeds = maxSeedingPlayersFunc()
    if player.GetCount() > maxSeeds then return end
    if player.GetCount() <= 0 then timer.Remove( timerName ) return end

    for index, oldSeedPly in pairs( GAMEMODE.seedPlayers ) do
        if not IsValid( oldSeedPly ) then
            GAMEMODE.seedPlayers[index] = nil

        end
    end
    for _, ply in ipairs( player.GetAll() ) do
        GAMEMODE:SeedPlayerThink( ply )

    end
end

function GM:SeedPlayerThink( ply )
    if not isSeedableSession() then return end
    if mapJustChanged() then return end

    local maxSeeds = maxSeedingPlayersFunc()
    if table.Count( GAMEMODE.seedPlayers ) > maxSeeds then GAMEMODE:ResetSeedCapTime() return end
    if player.GetCount() > maxSeeds then GAMEMODE:ResetSeedCapTime() return end

    -- too soon since the slots were last taken!
    local timeNeededToReset = minutesToResetFunc() * 60
    if ( lastHitSeedCap + timeNeededToReset ) > CurTime() then return end

    local plysSteamId = ply:SteamID()
    if not GAMEMODE.seedPlayers[ plysSteamId ] then
        GAMEMODE.seedPlayers[plysSteamId] = ply
        GAMEMODE:OnBecomeSeedPlayer( ply, GAMEMODE.seedPlayers )

    end
end

hook.Add( "PlayerInitialSpawn", "glee_seeding_shouldbecomeseed", function( ply )

    if mapJustChanged() then return end

    GAMEMODE:VerifySeedPlayers()

end )

hook.Add( "PlayerInitialSpawn", "glee_seeding_shouldrewardseeds", function( plyThatJoined )
    timer.Simple( 0, function()
        if not IsValid( plyThatJoined ) then return end

        if not isSeedableSession() then return end
        if mapJustChanged() then GAMEMODE:ResetSeedCapTime() return end

        for _, seedPly in pairs( GAMEMODE.seedPlayers ) do
            if seedPly == plyThatJoined then continue end
            GAMEMODE:RewardSeedPly( seedPly, plyThatJoined )

        end
    end )
end )


-- replace OnBecomeSeedPlayer and RewardSeedPly if you want to steal my code ( GIVE CREDIT! ) :)

local maxReward = 600
local dropOffDivisor = 10
GM.SEED_RewardedIds = GM.SEED_RewardedIds or {}
GM.SEED_SeedPlysReward = GM.SEED_SeedPlysReward or {}

function GM:OnBecomeSeedPlayer( seedPly, seedPlysTable )
    local seedPlysId = seedPly:SteamID()
    GAMEMODE.SEED_SeedPlysReward[ seedPlysId ] = maxReward / table.Count( seedPlysTable )

end

function GM:RewardSeedPly( seedPly, plyThatJoined )
    local seedPlysId = seedPly:SteamID()
    local joinedPlysId = plyThatJoined:SteamID()
    local big = nil

    if not GAMEMODE.SEED_RewardedIds[ seedPlysId ] then
        GAMEMODE.SEED_RewardedIds[ seedPlysId ] = {}
        big = true

    end

    -- already rewarded for this player!
    if GAMEMODE.SEED_RewardedIds[ seedPlysId ][ joinedPlysId ] then return end

    local theReward = GAMEMODE.SEED_SeedPlysReward[ seedPlysId ]
    if not theReward then
        theReward = maxReward / table.Count( GAMEMODE.seedPlayers )

    end

    theReward = math.floor( theReward )

    local rewardLost = theReward / dropOffDivisor
    GAMEMODE.SEED_SeedPlysReward[ seedPlysId ] = math.Clamp( theReward + -rewardLost, 0, math.huge )

    if theReward <= 0 then return end

    local theCutoff = ( maxReward * 0.5 )

    local distToCutoff = math.abs( theReward - theCutoff ) / theCutoff
    local distToNone = math.abs( theReward - 0 ) / maxReward

    local lvl = 110 + ( -distToCutoff * 60 )
    local pit = 120 + ( -distToCutoff * 50 )
    seedPly:EmitSound( "buttons/button9.wav", lvl, pit )
    if distToCutoff > 0.5 then
        big = true
        local pit2 = 100 + ( -distToCutoff * 80 )
        seedPly:EmitSound( "buttons/lever7.wav", lvl, pit2 )
        seedPly:EmitSound( "209578_zott820_cash-register-purchase.wav", lvl, pit2 )

    end

    -- big if true
    if big then
        huntersGlee_Announce( { seedPly }, 500 * distToNone, 12 * distToNone, plyThatJoined:Nick() .. " Joined because of you!\nYou laid the seeds for this...\n" .. theReward .. " Seeding bonus!" )

    -- ok they got the gist
    else
        huntersGlee_Announce( { seedPly }, 20 * distToNone, 10 * distToNone, plyThatJoined:Nick() .. " Joined.\n" .. theReward .. " Seeding bonus!" )

    end
    seedPly:GivePlayerScore( theReward )

end