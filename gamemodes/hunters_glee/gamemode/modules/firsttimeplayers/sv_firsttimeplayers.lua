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

local function shelterPly( ply )
    if ply:IsBot() then return end

    ply:SetNoTarget( true )
    ply:GodEnable()
    local oldGroup = ply:GetCollisionGroup()
    ply:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
    ply:Fire( "alpha", 1, 0 )

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

            ply:SetNoTarget( false )
            ply:GodDisable()
            ply:SetCollisionGroup( oldGroup )
            ply:Fire( "alpha", 255, 0 )

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
    --if not spawned[ply] then return end
    if asked[ply] then return end

    if ply:IsBot() then return end

    local sawIt = ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 )
    local minSawIt = 0
    if game.IsDedicated() then
        minSawIt = 1

    end
    if sawIt <= minSawIt then return true end

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

hook.Add( "glee_full_load", "glee_firsttimeplayercheck", function( ply )
    spawned[ply] = true

end )

concommand.Add( "glee_test_tutorial", function( ply )
    if not IsValid( ply ) then return end
    asked[ply] = nil
    alreadyDone[ply:SteamID()] = nil
    spawned[ply] = true

    ply:ConCommand( "cl_huntersglee_firsttimetutorial 0" )

end, nil, nil, FCVAR_CHEAT )
