-- The haptic goggles' sweep, included by cl_init.lua
-- the cone's shape, the grid of directions the rays sweep across it, and the contacts they find
-- radarThink at the bottom runs it every frame, cl_overlay.lua draws what it leaves

local haptic = SWEP.Haptic
local fillEyes = haptic.fillEyes
local eyesToWorld = haptic.eyesToWorld
local castRay = haptic.castRay
local trace = haptic.trace
local along = haptic.along


-- The cone's shape -----------------------------------------------------------
-- the radar's cone is a circle with the top and bottom sliced off flat, a band across it
-- the narrow cone is small enough to be the whole circle, the wider ones flatten out to the band
--
-- it's all measured on a flat lens one unit ahead of the eyes,
-- left and up are how far left and up of its middle a point sits

local bandSquash = 0.3 -- the band's height as a share of the circle's, at the wide cones
local bandFullCone = 10 -- this wide, whole circle
local bandFlatCone = 40 -- this wide, the band above

-- the band's height as a share of the circle's, flattening between the two widths
local function bandHeightShare( halfAngle )
    local cone = math.deg( halfAngle ) * 2
    if cone <= bandFullCone then return 1 end
    if cone >= bandFlatCone then return bandSquash end

    local flattened = ( cone - bandFullCone ) / ( bandFlatCone - bandFullCone )
    return Lerp( flattened, 1, bandSquash )

end

-- the band's size on the lens
-- radius, the circle's. halfHeight, from the middle up to the flat top
-- cutAngle, how far round the circle from level the flat top meets its edge
local function bandSize( halfAngle )
    local radius = math.tan( halfAngle )
    local halfHeight = radius * bandHeightShare( halfAngle )
    local cutAngle = math.asin( halfHeight / radius )
    return radius, halfHeight, cutAngle

end

-- the direction local to the eyes that passes through a point on the lens
-- points level with each other stay level on screen, that's what keeps the band's top and bottom straight
local function lensToDir( left, up )
    local length = math.sqrt( 1 + left * left + up * up )
    return Vector( 1 / length, left / length, up / length )

end

local function bandArea( halfAngle )
    local radius, halfHeight, cutAngle = bandSize( halfAngle )
    local topHalfWidth = radius * math.cos( cutAngle )

    -- two triangles from the middle, up to the flat top and down to the flat bottom
    local flatTriangles = 2 * topHalfWidth * halfHeight
    -- and two pie slices from the middle out to the curved sides
    local sideSlices = 2 * radius * radius * cutAngle
    return flatTriangles + sideSlices

end

-- how far apart the grid's points are on the lens
-- the resolution is a density: its points fill the widest cone, a narrower one gets fewer at the same spacing
local function gridCell( wep )
    local widestHalfAngle = math.rad( math.max( unpack( wep.Cones ) ) / 2 )
    local areaPerPoint = bandArea( widestHalfAngle ) / wep:CurrentResolution().points
    return math.sqrt( areaPerPoint )

end

-- the band's outline, local to the eyes. same mapping as the rays, so the line drawn on screen is
-- the boundary they fill: the circle's own arc down each side, flat top and bottom where it was cut
local outlineSegments = 20 -- points along the flat top and bottom
local arcSegments = 24 -- points along each side's arc
local outlineCache = {}

local function bandOutline( halfAngle )
    local cached = outlineCache[halfAngle]
    if cached then return cached end

    local radius, halfHeight, cutAngle = bandSize( halfAngle )
    local topHalfWidth = radius * math.cos( cutAngle )
    local dirs = {}

    local function add( left, up )
        dirs[#dirs + 1] = lensToDir( left, up )

    end

    -- across the top, right to left
    for i = 0, outlineSegments do
        add( Lerp( i / outlineSegments, -topHalfWidth, topHalfWidth ), halfHeight )
    end
    -- down the left side's arc
    for i = 1, arcSegments do
        local around = Lerp( i / arcSegments, cutAngle, -cutAngle )
        add( radius * math.cos( around ), radius * math.sin( around ) )
    end
    -- across the bottom, left to right
    for i = 1, outlineSegments do
        add( Lerp( i / outlineSegments, topHalfWidth, -topHalfWidth ), -halfHeight )
    end
    -- up the right side's arc
    for i = 1, arcSegments do
        local around = Lerp( i / arcSegments, -cutAngle, cutAngle )
        add( -radius * math.cos( around ), radius * math.sin( around ) )
    end

    outlineCache[halfAngle] = dirs
    return dirs

end


-- The grid -------------------------------------------------------------------
-- a cone's worth of directions, local to the eyes, laid out in rows, then ordered from the middle outwards
-- shiftAcross and shiftDown, in cells, 0 up to 1, slide every point across and down by that much,
-- wrapping round at the band's edges. each sweep shifts a little further, so the gaps get filled in over time

-- grids for the current cone and cell size, by shift. a change of either empties it,
-- each is up to Max resolution's points, so keeping every setting ever picked added up
local gridCache = {}
local gridCacheFor -- the cone and cell size gridCache holds

local function gridDirs( halfAngle, cell, shiftAcross, shiftDown )
    local setting = halfAngle .. ":" .. cell
    if setting ~= gridCacheFor then
        gridCacheFor = setting
        table.Empty( gridCache )

    end

    local key = shiftAcross .. ":" .. shiftDown
    local cached = gridCache[key]
    if cached then return cached end

    local radius, halfHeight = bandSize( halfAngle )
    local rowCount = math.max( 1, math.Round( 2 * halfHeight / cell ) )
    local rowStep = 2 * halfHeight / rowCount

    -- what the sort orders by, worked out once a point rather than twice every comparison
    local outward, around = {}, {}
    local dirs = {}

    for row = 0, rowCount - 1 do
        -- the half step puts each point in the middle of its cell, the shift rolls it on and wraps
        local up = halfHeight - ( ( row + 0.5 + shiftDown ) % rowCount ) * rowStep

        -- the row is only as wide as the circle still is at that height
        -- on the whole circle, a row wrapped right onto the edge can round a hair past it, and the root of that is nan
        local halfWidth = math.sqrt( math.max( radius * radius - up * up, 0 ) )
        local columnCount = math.max( 1, math.Round( 2 * halfWidth / cell ) )
        local columnStep = 2 * halfWidth / columnCount

        for column = 0, columnCount - 1 do
            local left = -halfWidth + ( ( column + 0.5 + shiftAcross ) % columnCount ) * columnStep
            local dir = lensToDir( left, up )
            dirs[#dirs + 1] = dir
            outward[dir] = dir.x
            around[dir] = math.atan2( up, left )

        end
    end

    gridCache[key] = dirs
    -- dir.x is how close to straight ahead it is, so highest first walks outwards ring by ring.
    -- a ring's points then go round in order, so each reads as one tidy band rather than a scatter
    table.sort( dirs, function( a, b )
        if outward[a] ~= outward[b] then return outward[a] > outward[b] end
        return around[a] < around[b]

    end )
    return dirs

end


-- Contacts -------------------------------------------------------------------
-- one per thing the rays found, holding where the rays landed on it, until the sweep comes back round
-- only the rays find things, so what traces pass through never shows
-- the snakes and fungus are SOLID_NONE, and that's deliberate
-- blipping them without a ray reaching them lit the fungus up on sight

local detectLife = 10 -- a target counts as new again after this long without being hit
local detectSound = "buttons/combine_button7.wav" -- combine terminal chirp, short and electronic
local maxHits = 64 -- per contact. past it, the oldest hits are written over

-- a hit lasts until the sweep comes back round to its point, hit there again or not, then fades out over this
local retireFade = 0.3 -- seconds

-- [ent] = {
--     seen = the last hit
--     beepedAt = when it last beeped
--     name = worked out once, on first contact
--     hits, hitCount, hitTotal = see recordHit
--     retireRay, fadeRays = its newest hit's
--     and cl_overlay.lua keeps its eased box on it
-- }
-- never replaced, so cl_overlay.lua can hold it
local contacts = {}

local sweepPass = 0 -- completed sweeps so far
local raysFired = 0 -- every ray since the goggles were put on, the clock hits retire by
-- how many rays a hit fades over once retired, at the rate it was fired at, set each pulse
-- kept on each hit, so a change of rate mid fade doesn't jump every fade on screen
local fadeRays = 1

-- what to call it. the gamemode's names when it's running, so a doppelganger reads as who it's wearing
local function nameOf( ent )
    if GAMEMODE.GetNameOfBot then return GAMEMODE:GetNameOfBot( ent ) end
    if ent.PrettyName then return ent.PrettyName end
    if ent:IsPlayer() then return ent:Nick() end

    local printName = ent.PrintName
    if printName and printName ~= "" then return printName end
    return ent:GetClass()

end

-- how much of the way to close this frame, to follow something at perSecond whatever the framerate
local function followShare( perSecond )
    return 1 - math.exp( -perSecond * FrameTime() )

end

-- the sweep slows down under SWEP.SlowFps, see shared.lua
-- the framerate's smoothed, so one hitch doesn't slow it, and hovering at the line doesn't flip it every frame
local fpsSmoothing = 2 -- per second, how quickly the smoothed frame time follows the real one
local smoothFrameTime = 0
local slowed = false

-- set once a frame, by pulse
local function updateSlowed( wep )
    smoothFrameTime = Lerp( followShare( fpsSmoothing ), smoothFrameTime, FrameTime() )
    slowed = smoothFrameTime > 1 / wep.SlowFps

end

-- the rays fired per second right now, the wavelength's, or its slowed share
local function currentRate( wep )
    local rate = wep:CurrentWavelength().raysPerSecond
    return slowed and rate * wep.SlowShare or rate

end

-- how much of a hit, or a contact by its newest hit, is left: 1 and true until it retires, then down to 0
-- timed in rays, so it's the sweep's own clock and stops with it
local function retiredFade( record )
    local over = raysFired - record.retireRay
    if over < 0 then return 1, true end
    return 1 - over / record.fadeRays, false

end

-- localDir is the bearing the ray went out on, local to the eyes, so its blip sits on the lens like the sweep's
-- bare, nothing else was on the line, see pulse
-- retireRay is raysFired when the sweep next reaches this hit's point, the hit retires then
-- beeps once per target, until it's gone unhit for detectLife
local function recordHit( ent, localDir, bare, retireRay )
    local now = CurTime()
    local contact = contacts[ent]

    if not contact then
        contact = {
            name = nameOf( ent ),
            hits = {},
            hitCount = 0,
            hitTotal = 0,
        }
        contacts[ent] = contact

    end

    if not contact.beepedAt or now - contact.seen > detectLife then
        contact.beepedAt = now
        -- surface.PlaySound is fixed at full volume, so this is emitted instead to halve it.
        -- level 75 is normal attenuation, and the emitter is the listener, so it lands in their ears
        LocalPlayer():EmitSound( detectSound, 75, 100, 0.5 )

    end

    contact.seen = now
    contact.retireRay = retireRay
    contact.fadeRays = fadeRays

    -- the hit tables are kept and written over, sweep after sweep
    local slot = contact.hitTotal % maxHits + 1
    local hit = contact.hits[slot]
    if not hit then
        hit = {}
        contact.hits[slot] = hit

    end
    hit.dir = localDir -- gridDirs' own, read only
    hit.bare = bare
    hit.retireRay = retireRay
    hit.fadeRays = fadeRays
    contact.hitTotal = contact.hitTotal + 1
    contact.hitCount = math.min( contact.hitTotal, maxHits )

end


-- The sweep ------------------------------------------------------------------
-- the pattern is a fixed grid of points; each frame walks only a slice of it, so a full sweep
-- takes points / raysPerSecond seconds instead of costing the whole grid every frame. the grid creeps
-- a fraction of a cell every sweep, so anything that fell between points gets caught later
-- paced by time, not frames: a sweep sped up by the framerate also sped up how often everything
-- on the overlay repeats, past what's safe for photosensitive players

local scanIndex = 1 -- where the next frame's slice of the sweep starts
local shiftSteps = 16 -- each sweep slides the grid a 16th of a cell across
local shiftDownSteps = 3 -- and three 16ths down

local raysOwed = 0 -- fractions of a ray carried between frames

-- the last frames' slices, newest at sliceHead, for the overlay's trail, which draws them by age
-- enough for its trail at any framerate short of the hundreds
local trailSlices = 64
local slices = {}
for i = 1, trailSlices do
    slices[i] = {}

end
local sliceHead = 1

-- the wearer's eyes, a ray's direction in the world, and its sight line's end, filled in place, see the top of cl_rays.lua
local rayEyes = {}
local worldDir = Vector()
local sightEnd = Vector()

local function pulse( me, wep )
    local wavelength = wep:CurrentWavelength()
    local eyePos = me:EyePos()
    fillEyes( rayEyes, me:EyeAngles() )
    local halfCone = math.rad( wep:CurrentCone() / 2 )

    local shiftAcross = ( sweepPass % shiftSteps ) / shiftSteps
    local shiftDown = ( sweepPass * shiftDownSteps % shiftSteps ) / shiftSteps
    local dirs = gridDirs( halfCone, gridCell( wep ), shiftAcross, shiftDown )
    local count = #dirs

    updateSlowed( wep )
    local rate = currentRate( wep )
    fadeRays = rate * retireFade
    raysOwed = raysOwed + rate * FrameTime()
    local perFrame = math.min( math.floor( raysOwed ), count )
    raysOwed = math.min( raysOwed - perFrame, 1 ) -- past a whole sweep in one frame is dropped, not owed
    if perFrame < 1 then return end

    for offset = 0, perFrame - 1 do
        raysFired = raysFired + 1
        local localDir = dirs[( scanIndex - 1 + offset ) % count + 1]
        eyesToWorld( worldDir, localDir, rayEyes )

        local hit = castRay( me, eyePos, worldDir, wavelength )
        if hit then
            -- a second ray up the same bearing, plain: no piercing, no deflection, it stops at the
            -- first solid. a contact that only came through a wall or off a bent ray still has that
            -- wall or that thing in the way, so this lands on something other than the target.
            -- a contact with nothing else on the line is a bare one
            local sight = trace( eyePos, along( sightEnd, eyePos, worldDir, wavelength.length ), me )
            local bare = not sight.Hit or sight.Entity == hit

            -- a whole sweep's worth of rays from now is this same point again
            recordHit( hit, localDir, bare, raysFired + count )

        end
    end

    sliceHead = sliceHead % trailSlices + 1
    local slice = slices[sliceHead]
    slice.dirs = dirs
    slice.first = scanIndex
    slice.count = perFrame
    slice.born = CurTime()

    local before = scanIndex
    scanIndex = ( scanIndex - 1 + perFrame ) % count + 1
    if scanIndex <= before then sweepPass = sweepPass + 1 end -- the cursor came back round: one sweep done

end


-- The hum --------------------------------------------------------------------
-- from the Alien: Isolation - Motion Tracker addon
-- a loop on its own channel, so it runs under the sweep instead of pinging over it
-- the file loads in the background, so it's asked for once, and dropped if the radar stopped meanwhile

local radarLoopSound = "sound/glee/nvg/motiontracker_noise_loop.wav"
local radarLoopVolume = 0.35
local radarLoop = nil -- the playing IGModAudioChannel
local radarLoopLoading = false
local radarLoopWanted = false
local radarLoopFailed = false -- it won't load, stop asking

local function stopRadarLoop()
    radarLoopWanted = false
    if radarLoop then radarLoop:Stop() end
    radarLoop = nil

end

local function startRadarLoop()
    radarLoopWanted = true
    if radarLoopLoading or radarLoopFailed then return end

    -- the file ran out before the radar did: start it again rather than going quiet
    if radarLoop and radarLoop:GetState() == GMOD_CHANNEL_STOPPED then radarLoop = nil end
    if radarLoop then return end

    radarLoopLoading = true
    sound.PlayFile( radarLoopSound, "noblock", function( channel, errID, errStr )
        radarLoopLoading = false
        if not channel then
            radarLoopFailed = true
            MsgN( "[glee] nvg radar loop failed: ", errID, " ", errStr )
            return

        end
        -- turned off, or taken off, while it loaded
        if not radarLoopWanted then
            channel:Stop()
            return

        end
        radarLoop = channel
        channel:SetVolume( radarLoopVolume )
        channel:Play()

    end )
end


-- Running it -----------------------------------------------------------------

local function radarRunning( wep, wearer )
    return wep:GetRadarOn() and wep:IsGleeSeeing( wearer )

end

-- every frame. contacts age out whether or not the radar's running
local function radarThink( wep, wearer )
    local now = CurTime()

    -- kept past its fade while it'd still count as seen, so it doesn't beep again
    for ent, contact in pairs( contacts ) do
        if now - contact.seen > detectLife and retiredFade( contact ) <= 0 then contacts[ent] = nil end

    end

    if not radarRunning( wep, wearer ) then
        stopRadarLoop()
        return

    end

    startRadarLoop()
    pulse( wearer, wep )

end

-- taken off
local function clearRadar()
    stopRadarLoop()
    table.Empty( contacts )
    raysOwed = 0
    for _, slice in ipairs( slices ) do
        slice.born = nil

    end
end


-- What the other files use --------------------------------------------------

haptic.bandOutline = bandOutline
haptic.gridCell = gridCell
haptic.followShare = followShare
haptic.retiredFade = retiredFade
haptic.contacts = contacts
haptic.slices = slices
haptic.trailSlices = trailSlices
haptic.newestSlice = function() return sliceHead end
haptic.radarRunning = radarRunning
haptic.radarThink = radarThink
haptic.clearRadar = clearRadar
