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
    function( _self, owner )
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
            if math.AngleDifference( currAng.p, startingAng.p ) < 5 and
               math.AngleDifference( currAng.y, startingAng.y ) < 5 and
               math.AngleDifference( currAng.r, startingAng.r ) < 5 then return end

            ply:RemoveStatusEffect( "spawn_protection" )

            timer.Remove( timerName )
            gleetings( ply )

        end )
    end )
end

local function tutorialize( ply )
    print( "GLEE: Tutorializing ", ply )
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

end

local function needsToAsk( ply )
    if not spawned[ply] then return end -- wait until ply has full loaded
    if asked[ply] then return end

    if ply:IsBot() then return end

    local sawIt = ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 )
    local minSawIt = 1
    if game.IsDedicated() then
        minSawIt = 2

    end
    if sawIt < minSawIt then return true end

end

function GAMEMODE:WaitingForAFirstTimePlayer( players )
    if #players <= 0 then return end

    -- start spawning hunters if at least one person got through the tutorial
    if blockSpawning then
        local sawTutorialCount = 0
        local didntSeeTutorialCount = 0
        local minSawIt = 0
        if game.IsDedicated() then
            minSawIt = 1

        end
        for _, ply in ipairs( players ) do
            local sawIt = ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 )
            if sawIt >= minSawIt and not ply:IsBot() then
                sawTutorialCount = sawTutorialCount + 1

            else
                didntSeeTutorialCount = didntSeeTutorialCount + 1

            end
        end
        if sawTutorialCount >= didntSeeTutorialCount then -- ok, enough saw
            blockSpawning = false

        end
        return blockSpawning

    end

    -- if half of all players need the tutorial, block hunter spawning
    local needsToAskCount = 0
    local nonKnowers = {}
    for _, ply in ipairs( players ) do
        local needs = needsToAsk( ply )
        if needs then
            table.insert( nonKnowers, ply )
            needsToAskCount = needsToAskCount + 1

        end
    end

    if needsToAskCount >= #players / 2 then
        blockSpawning = true

    end

    for _, ply in ipairs( nonKnowers ) do
        tutorialize( ply )

    end
end

hook.Add( "PlayerInitialSpawn", "glee_firsttimeply_shelterwhenloading", function( ply )
    ply:GiveStatusEffect( "spawn_protection" )

end )

hook.Add( "glee_full_load", "glee_firsttimeplayercheck", function( ply )
    timer.Simple( 2, function() -- try delaying, so player is definitely ready to create the panel
        ply:RemoveStatusEffect( "spawn_protection" )
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
