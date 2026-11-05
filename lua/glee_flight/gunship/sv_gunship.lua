terminator_Extras = terminator_Extras or {}

-- the combine gunship, an npc_combinegunship that circles its enemy, and bombs it with missile salvos
-- the brain decides where to be, the flight navigator gets it there
-- kept across autorefresh, the other gunship files add their functions to this
local gunship = terminator_Extras.glee_Gunship or {}
terminator_Extras.glee_Gunship = gunship

gunship.Debugging = CreateConVar( "huntersglee_debug_gunship", "0", { FCVAR_NONE }, "Enable debug info for the gunship?" )

-- missile pairs need this resolution
gunship.ThinkInterval = 0.3
-- steering is ~60 traces a go, so it runs slower than the brain
gunship.SteerInterval = 0.9

-- above the floor under us, when it's not fighting
local cruiseHeight = 1200

gunship.FlightCfg = {
    speedLimit = 1500,
    closeToObstacleSpeedLimit = 400,
    tooFarFromGround = 2200, -- above cruiseHeight, or it fights the orbit's altitude
    tooCloseToGround = 300,
    obstacleHull = 175,
    wayfindingHull = 250,
    slowMovingHull = 175,
    wanderHeight = cruiseHeight,
    debugConVar = gunship.Debugging,
}

-- one more rocket and it's dead, so it runs
gunship.FleeSpeed = 4000

-- forgets an enemy it can't see after this long
gunship.TargetMemory = 37

gunship.OrbitCfg = {
    engageDist = 3500, -- 2d, closer than this and it fights, further and it approaches
    duelRadius = 3150,
    bombRadiusMul = 1.25,
    -- lost them, it circles where it last saw them, tight enough to look in at ground level
    searchRadius = 1750,
    searchFor = 20, -- seconds since it last saw them, then it gives up searching and flies straight over them

    -- it never aims at the circle, it aims a carrot ahead of itself, at an angle off the line to the center
    -- 90 is tangent, under 90 spirals in, so the ring holds by alternating spiral in and tangent drift out
    baseAngle = 60,
    angleCorrection = 30, -- too far, turn in this much more, too close, turn out to tangent
    sweetBand = 200, -- this close to the radius, no correction

    carrotDist = 1600,
    sightCheckDist = 2000, -- can the center see this far along the heading, or will we lose it
    momentum = 0.4, -- how much of our current heading the carrot keeps
    centerLeadTime = 1.5, -- the center leads the target by this many seconds of its velocity
    carrotInterval = 1.8,
    validateHull = 175,

    -- the radius shrinks where it keeps losing sight or hitting walls, and recovers out in the open
    radiusShrinkObscured = 0.85,
    radiusShrinkBlocked = 0.9,
    radiusRecover = 1.05,
    radiusMinMul = 0.4,

    cruiseHeight = cruiseHeight,
    tooHighCarrot = 1920, -- the floor under the carrot is this far down, come down to the target
    tooHighMe = 2400, -- same, under us
    targetHeightBase = 320, -- above the target's feet, when duelling at its height
    -- square waves stacked onto targetHeightBase, sudden steps
    bobs = {
        { height = 200, period = 24 },
        { height = 200, period = 9 },
    },
}

gunship.BoomerangCfg = {
    duration = 5, -- by the end, it's heading straight at the target
    canFireBelowAngle = 90, -- bombing, it fires once it's heading back in this close to the target
}

-- tables indexed by health segment, 1 is nearly dead, 3 is full health
gunship.BombCfg = {
    duelToBombEvery = { 6, 18, 30 },
    ammo = { 6, 4, 4 },
    pairGap = { 1.2, 3.4, 5.5 }, -- before the first missile of a pair
    inPairGap = { 0.6, 0.9, 1.25 }, -- before the second
    madAmmo = 8, -- segment 1, every incoming rocket reloads it to this
    -- a rocket coming at it holds its missiles and belly cannon, like its gun, until it's under this fraction of its health
    rocketDistractsAbove = 0.5,
    spiteDamage = 200, -- damage it shrugs off before it bombs out of spite, bullets it's immune to count
    -- right over its target, the pulse gun often can't angle down to it, gone quiet this long there, it's owed missiles
    quietGunTime = 4,
    overheadRadius = 1000, -- 2d
    launchSideOffset = 100,
    launchForwardOffset = 200,
    leadSpeed = 1000, -- leads by dist / this seconds, the missiles average faster, so it overleads, which was always the fun
    -- out of sight, missiles go where it last saw them, spread this much wider for each one fired since
    blindSpreadPerMissile = 150,
}

-- a strider warp cannon shot out of the belly, its owed missiles get paid with this instead
-- it backs away from the target, tilting nose up, so the belly comes to bear, then fires
gunship.BellyCannonCfg = {
    cooldown = { 10, 20, 30 }, -- by health segment, after every shot, and every try that gave up
    setupTimeout = 6, -- can't line it up by then, it bombs instead
    -- it only starts backing off while it can see them, but them ducking into cover doesn't call it off
    -- unseen this long though, and wherever it last saw them is stale, it bombs instead
    blindFireTime = 5,

    -- this many hostiles this close to the target, it goes for the cannon owed missiles or not, same as the rescue heli
    crowdRadius = 1250,
    crowdCount = 2, -- the target counts

    -- the shot only lines up when all of these hold
    backingSpeed = 150, -- moving backwards relative to itself, at least this fast
    aimCone = 55, -- degrees, the target has to be within this of straight out of the belly
    minDist = 800, -- closer than this, it'd catch itself
    -- further than this, the target's too level with it for the belly to ever bear, and backing off only makes that worse
    -- it won't plan a shot from out here, and gives up on one that's backed off this far
    maxDist = 3500,
    desperateHealth = 1 / 3, -- at or under this fraction of its health, maxDist's off, it'll try from anywhere
    landTolerance = 400, -- the shot has to land at least this close to the target
    -- it won't plan a shot that needs backing off without this much clear behind it, and the shot landing from there
    backoffRoom = 1200,

    prefireTime = 2, -- the strider's is 1.25, its charge visuals stretch to fit

    -- charging, it swings like a turret, aiming where they'll be when it fires
    -- slow enough that up close, a sprint across the belly outruns it, far off it keeps up easily
    turnRate = 30, -- degrees a second
    -- out of sight, it keeps leading them from where it last saw them, this many seconds of guessing at most
    maxLead = 6,

    -- the hit
    hitDamage = 500, -- dissolve, to whatever it hits directly, before the gunship's damage mul
    hitForce = 50000,
    blastMagnitudes = { 455, 227 }, -- env_explosions, radius is 2.5x
    -- the shot shoves it back the way it fired from, and it rides the shove for a moment
    recoilKick = 400,
    recoilSpeed = 800,
    recoilTime = 0.5,
    recoilDist = 300,
}

-- backed off to fire the belly cannon, and lost them, it reloads and charges where it last saw them, missiles away
gunship.ChargeCfg = {
    window = 2, -- losing them this long after the shot still counts
    extraAmmo = 2, -- on top of the health segment's load
    reachedDist = 1000, -- 2d, this close to where it last saw them, the charge is over
}

-- set when it spawns, by who's online then
gunship.BaseHealth = 1000
gunship.HealthPerPlayer = 200

-- so a team with heavy explosives can't burst it down
gunship.DamageCfg = {
    maxPerHit = 100,
    hitCooldown = 0.25, -- after a hit lands, nothing does for this long
    -- from its first hit, a floor its health can't go under, sliding from this fraction of max health to nothing over minLife
    -- so it always lives at least minLife seconds once the fight starts
    startFloor = 0.5,
    minLife = 60 * 3,
    -- this far above the floor, as a fraction of the floor, damage starts tapering off, so it slows down before it hits it
    taperOfFloor = 0.4,
}
