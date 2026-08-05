local GAMEMODE = GAMEMODE or GM

local asked = {}
local spawned = {}
local alreadyDone = {}
local blockSpawning

util.AddNetworkString( "glee_dothefirsttimemessage" )
util.AddNetworkString( "glee_askforgleetings" )

local function gleetings( ply )
    if not game.IsDedicated() then return end

    local filterNotPly = RecipientFilter()
    filterNotPly:AddAllPlayers()
    filterNotPly:RemovePlayer( ply )
    net.Start( "glee_askforgleetings" )
        net.WriteEntity( ply )
    net.Send( filterNotPly )

end

GAMEMODE:RegisterStatusEffect( "spawn_protection",
    function( self, owner )
        self:SetRemoveOnDeath( true ) -- in case it gets stuck, will make it remove on owner killbind

        owner.glee_sheltering_normalCollisionGroup = owner.glee_sheltering_normalCollisionGroup or owner:GetCollisionGroup()
        owner:SetNoTarget( true )
        owner:GodEnable()
        owner:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
        owner:Fire( "alpha", 0, 0 )
        owner:SetNWBool( "glee_firstowner_sheltering", true )

    end,
    function( _self, owner )
        owner:SetNoTarget( false )
        owner:GodDisable()
        owner:SetCollisionGroup( owner.glee_sheltering_normalCollisionGroup or COLLISION_GROUP_PLAYER )
        owner:Fire( "alpha", 255, 0 )

    end
)

local function shelterPly( ply )
    if ply:IsBot() then return end

    ply:GiveStatusEffect( "spawn_protection" )

    local wait = 2
    wait = wait + ply:Ping() / 50

    timer.Simple( wait, function() -- wait until the gui gets em
        if not IsValid( ply ) then return end

        local startingAng = ply:GetAngles()

        local timerName = "glee_tutorialshelter_" .. ply:GetCreationID()
        timer.Create( timerName, 0.1, 0, function()
            if not IsValid( ply ) then timer.Remove( timerName ) return end
            local currAng = ply:GetAngles()

            -- remove godmode when tutorial lets go and allows them to aim again
            if math.abs( math.AngleDifference( currAng.p, startingAng.p ) ) < 5 and
               math.abs( math.AngleDifference( currAng.y, startingAng.y ) ) < 5 and
               math.abs( math.AngleDifference( currAng.r, startingAng.r ) ) < 5 then return end

            ply:RemoveStatusEffect( "spawn_protection" )

            timer.Remove( timerName )
            gleetings( ply )

        end )
    end )
end

local function tutorialize( ply )
    permaPrint( "GLEE: Tutorializing ", ply )
    if ply:Glee_FlashlightIsOn() then
        ply:Glee_Flashlight( false )

    end
    asked[ply] = true
    if not alreadyDone[ply:SteamID()] then -- NEVER give god/notarg more than once per session
        alreadyDone[ply:SteamID()] = true
        shelterPly( ply )

    end
    net.Start( "glee_dothefirsttimemessage" )
    net.Send( ply )

    ply.glee_IsFirstTimePlayer = true

end

local function tutorialKnowledgeLevel( ply )
    return ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 )

end

-- two different tutorials for singleplayer/multiplayer
local function requiredKnowledgeLevel()
    if game.IsDedicated() then return 2 end
    return 1

end

local function needsToAsk( ply )
    if not spawned[ply] then return end -- wait until ply has full loaded
    if asked[ply] then return end

    if ply:IsBot() then return end

    return tutorialKnowledgeLevel( ply ) < requiredKnowledgeLevel()

end

local function isEducated( ply )
    if ply:IsBot() then return end

    return tutorialKnowledgeLevel( ply ) >= requiredKnowledgeLevel()

end

function GAMEMODE:IsFirstTimePlayer( ply )
    return ply.glee_IsFirstTimePlayer

end

function GAMEMODE:WaitingForAFirstTimePlayer( players )
    if #players <= 0 then return end

    local halfTheServer = #players / 2

    -- Already waiting, so the only question is whether it's over yet.
    if blockSpawning then
        local sawIt = 0

        for _, ply in ipairs( players ) do
            if isEducated( ply ) then sawIt = sawIt + 1 end

        end

        blockSpawning = sawIt < halfTheServer
        return blockSpawning

    end

    local nonKnowers = {}

    for _, ply in ipairs( players ) do
        if needsToAsk( ply ) then nonKnowers[#nonKnowers + 1] = ply end

    end

    -- >50% of the session are new players
    -- if this happens, stop spawning until at least half the session finishes the tutorial
    -- and set the mode to the easiest terminator mode
    local needsToBlock = #nonKnowers >= halfTheServer
    if needsToBlock then
        RunConsoleCommand( "huntersglee_spawnset", "hunters_glee_oneguy" )
        blockSpawning = true

    end

    for _, ply in ipairs( nonKnowers ) do
        tutorialize( ply )

    end
end

-- shelter until they are done loading
hook.Add( "PlayerInitialSpawn", "glee_firsttimeply_shelterwhenloading", function( ply )
    ply:GiveStatusEffect( "spawn_protection" )

end )

-- they're done loading
hook.Add( "glee_full_load", "glee_firsttimeplayercheck", function( ply )
    -- wait a couple seconds
    timer.Simple( 2, function()
        if not IsValid( ply ) then return end
        -- then remove their spawn protection
        ply:RemoveStatusEffect( "spawn_protection" )

        -- and mark them as ready for the tutorial
        spawned[ply] = true

    end )
end )

concommand.Add( "glee_test_tutorial", function( ply )
    if not IsValid( ply ) then return end
    asked[ply] = nil
    alreadyDone[ply:SteamID()] = nil
    spawned[ply] = true

    ply:ConCommand( "cl_huntersglee_firsttimetutorial 0" )

end, nil, nil, FCVAR_CHEAT )

concommand.Add( "glee_test_tutorial_everyone", function( caller )
    if not caller:IsSuperAdmin() then return end

    for _, ply in player.Iterator() do
        asked[ply] = nil
        alreadyDone[ply:SteamID()] = nil
        spawned[ply] = true

        ply:ConCommand( "cl_huntersglee_firsttimetutorial 0" )

    end
end, nil, nil )
