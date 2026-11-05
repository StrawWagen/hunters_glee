terminator_Extras = terminator_Extras or {}

-- the rescue heli, an npc_helicopter that flies in when an escape flare finds the sky
-- picks up players, then flies off into the skybox, escaping them
local rescueHeli = {}
terminator_Extras.glee_RescueHeli = rescueHeli

rescueHeli.Debugging = CreateConVar( "huntersglee_debug_escapeheli", "0", { FCVAR_NONE }, "Enable debug info for the escape heli?" )

-- hullsize for finding a corridor from flare to sky, and for the heli's obstacle and skybox checks
rescueHeli.CallingHull = 350

-- hullsize for nav traces
local wayfindingHull = 250

rescueHeli.FlightCfg = {
    speedLimit = 4000,
    closeToObstacleSpeedLimit = 250,
    tooFarFromGround = 1250,
    tooCloseToGround = 300,
    obstacleHull = rescueHeli.CallingHull,
    wayfindingHull = wayfindingHull,
    slowMovingHull = 175,
    startAtTopSpeed = true, -- it enters from the skybox
    wanderHeight = 800,
    debugConVar = rescueHeli.Debugging,
}

rescueHeli.SkyCorridorCfg = {
    corridorHull = rescueHeli.CallingHull,
    minHull = wayfindingHull,
    debugConVar = rescueHeli.Debugging,
}

function rescueHeli.AngerEverything()
    for _, ent in ents.Iterator() do
        if not ent.ReallyAnger then continue end
        ent:ReallyAnger( 120 )

    end
end
