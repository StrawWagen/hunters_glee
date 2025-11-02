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

    local startingAng = ply:GetAngles()
    startingAng.p = math.Round( startingAng.p, 0 )
    startingAng.y = math.Round( startingAng.y, 0 )
    startingAng.r = math.Round( startingAng.r, 0 )

    local startPos = ply:GetPos()

    ply:SetNoTarget( true )
    ply:GodEnable()
    local oldGroup = ply:GetCollisionGroup()
    ply:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
    ply:Fire( "alpha", 0 )

    local timerName = "glee_tutorialshelter_" .. ply:GetCreationID()
    timer.Create( timerName, 0.1, 0, function()
        if not IsValid( ply ) then timer.Remove( timerName ) return end
        local currAng = ply:GetAngles()
        currAng.p = math.Round( currAng.p, 0 )
        currAng.y = math.Round( currAng.y, 0 )
        currAng.r = math.Round( currAng.r, 0 )

        local currPos = ply:GetPos()
        if currPos:Distance( startPos ) < 50 and currAng == startingAng then return end

        ply:SetNoTarget( false )
        ply:GodDisable()
        ply:SetCollisionGroup( oldGroup )
        ply:Fire( "alpha", 255 )

        timer.Remove( timerName )
        gleetings( ply )

    end )
end

local function tutorialize( ply )
    print( "GLEE: Tutorializing ", ply )
    if ply:Glee_FlashlightIsOn() then
        ply:Glee_Flashlight( false )

    end
    asked[ply] = true
    if not alreadyDone[ply:SteamID()] then -- only give them god/notarg once per round
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
    if sawIt == 0 then return true end

end

function GAMEMODE:WaitingForAFirstTimePlayer( players )
    if #players <= 0 then return end

    -- start spawning hunters if at least one person got through the tutorial
    if blockSpawning then
        local sawTutorialCount = 0
        local didntSeeTutorialCount = 0
        for _, ply in ipairs( players ) do
            local sawIt = ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 )
            if sawIt >= 1 and not ply:IsBot() then
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
