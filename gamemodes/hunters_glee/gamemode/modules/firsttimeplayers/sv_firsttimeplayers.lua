local GAMEMODE = GAMEMODE or GM

local asked = {}
local spawned = {}
local blockSpawning

util.AddNetworkString( "glee_dothefirsttimemessage" )

local function needsToAsk( ply )
    --if not spawned[ply] then return end
    if asked[ply] then return end

    if ply:IsBot() then return true end

    local sawIt = ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 )
    if sawIt == 0 then return true end

end

function GAMEMODE:WaitingForAFirstTimePlayer( players )
    if #players <= 0 then return end

    -- start spawning hunters if at least one person got through the tutorial
    if blockSpawning then
        for _, ply in ipairs( players ) do
            local sawIt = ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 )
            if sawIt >= 1 and not ply:IsBot() then
                blockSpawning = nil
                break

            end
        end
        return blockSpawning

    end

    -- if all players need the tutorial, block hunter spawning
    local needsToAskCount = 0
    local nonKnowers = {}
    for _, ply in ipairs( players ) do
        local needs = needsToAsk( ply )
        if needs then
            table.insert( nonKnowers, ply )
            needsToAskCount = needsToAskCount + 1

        end
    end

    if needsToAskCount >= #players then
        blockSpawning = true

    end

    for _, ply in ipairs( nonKnowers ) do
        print( "GLEE: Tutorializing ", ply )
        if ply:Glee_FlashlightIsOn() then
            ply:Glee_Flashlight( false )

        end
        asked[ply] = true
        net.Start( "glee_dothefirsttimemessage" )
        net.Send( ply )

    end
end


-- https://github.com/CFC-Servers/gm_playerload

local loadQueue = {}

hook.Add( "PlayerInitialSpawn", "glee_FullLoadSetup", function( ply )
    loadQueue[ply] = true

end )

hook.Add( "SetupMove", "glee_FullLoadTrigger", function( ply, _, cmd )
    if not loadQueue[ply] then return end
    if cmd:IsForced() then return end

    loadQueue[ply] = nil
    spawned[ply] = true
    ply.glee_FullLoaded = true
    hook.Run( "glee_plyfullload", ply )

end )