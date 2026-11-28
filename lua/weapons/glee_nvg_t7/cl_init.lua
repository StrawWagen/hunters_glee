include( "shared.lua" )

-- The motion camera. Only what changed lights up, everything holding still goes black.
-- Each frame is compared against a snapshot from a moment ago, see SWEP.Motion's lag.
-- Turning or walking moves the whole picture, so it all lights up, it's a camera to hold still.
-- What changed glows, and fades out slowly, so it's never missed between redraws.
-- Wider tubes show that glow less often, held on screen in between, see SWEP.Fovs.
-- Grain goes over it every frame, so even a held picture never looks frozen.
--
-- DrawGleeVision at the bottom runs it, glee_nvg_base calls that every frame they're down.
-- Above it, in order: the render targets, grain, the snapshots, comparing a frame against one, and the afterglow.

-- one's retaken every lag / snapshotCount seconds
-- each frame's compared against the newest that's at least lag old
local snapshotCount = 4

-- not drawn for this long, eg flipped up, and the snapshots are stale, they're all retaken
local staleAfter = 0.5


-- Render targets -------------------------------------------------------------

-- frames are only ever stored by straight copies, those change nothing
-- drawing one through a material changes its brightness, so two frames being compared both go through one,
-- the same way, and a still scene still cancels to exactly black
local function textureMaterial( name, texture )
    local mat = CreateMaterial( name, "UnlitGeneric", {
        ["$basetexture"] = "_rt_FullFrameFB",
        ["$vertexcolor"] = 1,
        ["$ignorez"] = 1,
    } )
    mat:SetTexture( "$basetexture", texture )
    return mat

end

local function makeTarget( name, w, h )
    -- render targets live until disconnect under their name, one that changes how it's made needs a new name
    local fullName = "glee_nvg_t7_" .. name .. "_" .. w .. "x" .. h
    -- the screen's exact size. GetRenderTarget rounds to a power of 2, and a stretched copy reads as all changed
    local target = GetRenderTargetEx( fullName, w, h,
        RT_SIZE_FULL_FRAME_BUFFER,
        MATERIAL_RT_DEPTH_NONE,
        bit.bor( 1, 256 ), -- point sampled, no mips
        0,
        IMAGE_FORMAT_BGRA8888
    )
    return { target = target, mat = textureMaterial( fullName, target ) }

end

-- current, this frame, copied off the screen
-- snapshots, earlier frames
-- behind, the snapshot minus the current frame, see drawChanges
-- glow, what's changed lately, fading
-- shown, the glow as of the last redraw, put on screen every frame
local targets
local targetsSize

-- set when the targets are made, they hold nothing yet
local targetsFresh = false

local function getTargets( w, h )
    local size = w .. "x" .. h
    if targetsSize == size then return targets end

    targets = {
        current = makeTarget( "current", w, h ),
        behind = makeTarget( "behind", w, h ),
        glow = makeTarget( "glow", w, h ),
        shown = makeTarget( "shown", w, h ),
        snapshots = {},
    }
    for index = 1, snapshotCount do
        targets.snapshots[index] = makeTarget( "snapshot" .. index, w, h )

    end
    targetsSize = size
    targetsFresh = true
    return targets

end


-- Grain ----------------------------------------------------------------------

-- a small tile of random greys, made once, tiled over the screen at a new random offset every frame
local grainSize = 128
local grainMat

local function makeGrain()
    local fullName = "glee_nvg_t7_grain_" .. grainSize
    local target = GetRenderTargetEx( fullName, grainSize, grainSize,
        RT_SIZE_NO_CHANGE,
        MATERIAL_RT_DEPTH_NONE,
        bit.bor( 1, 256 ), -- point sampled, no mips. no clamp flags, so it wraps and tiles
        0,
        IMAGE_FORMAT_BGRA8888
    )

    render.PushRenderTarget( target )
    cam.Start2D()
        render.Clear( 0, 0, 0, 255 )
        for x = 0, grainSize - 1 do
            for y = 0, grainSize - 1 do
                local grey = math.random( 0, 255 )
                surface.SetDrawColor( grey, grey, grey, 255 )
                surface.DrawRect( x, y, 1, 1 )

            end
        end
    cam.End2D()
    render.PopRenderTarget()

    grainMat = textureMaterial( fullName, target )

end

-- added on top, so black becomes faint static and what's lit stays lit
local function drawGrain( brightness, w, h )
    if not grainMat then makeGrain() end

    local u = math.random( 0, grainSize - 1 ) / grainSize
    local v = math.random( 0, grainSize - 1 ) / grainSize
    local level = brightness * 255

    cam.Start2D()
        render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD )
        surface.SetMaterial( grainMat )
        surface.SetDrawColor( level, level, level, 255 )
        surface.DrawTexturedRectUV( 0, 0, w, h, u, v, u + w / grainSize, v + h / grainSize )
        render.OverrideBlend( false )
    cam.End2D()

end


-- Snapshots ------------------------------------------------------------------

-- when each snapshot was taken, by index
local snapshotTimes = {}
local lastSnapshot = 0

-- the one taken longest ago, the next written over
local function oldestSnapshot()
    local oldest = 1
    for index = 2, snapshotCount do
        if snapshotTimes[index] < snapshotTimes[oldest] then oldest = index end

    end
    return oldest

end

-- the newest snapshot at least lag old, or the oldest if none are yet
local function snapshotToCompare( lag, now )
    local best, bestTime
    for index = 1, snapshotCount do
        local time = snapshotTimes[index]
        if now - time >= lag and ( not bestTime or time > bestTime ) then
            best, bestTime = index, time

        end
    end
    if best then return best end

    return oldestSnapshot()

end


-- Comparing ------------------------------------------------------------------

-- draws over what's there, replacing it
local function drawReplacing( mat, w, h )
    render.OverrideBlend( true, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD )
    surface.SetMaterial( mat )
    surface.SetDrawColor( 255, 255, 255, 255 )
    surface.DrawTexturedRect( 0, 0, w, h )

end

-- takes it away from what's there, stopping at black
local function drawSubtracting( mat, w, h )
    render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_REVERSE_SUBTRACT )
    surface.SetMaterial( mat )
    surface.SetDrawColor( 255, 255, 255, 255 )
    surface.DrawTexturedRect( 0, 0, w, h )

end

local function drawAdding( mat, w, h )
    render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD )
    surface.SetMaterial( mat )
    surface.SetDrawColor( 255, 255, 255, 255 )
    surface.DrawTexturedRect( 0, 0, w, h )

end

local grey = {
    ["$pp_colour_addr"] = 0,
    ["$pp_colour_addg"] = 0,
    ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"] = 1,
    ["$pp_colour_colour"] = 0,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0,
}

-- draws what changed this frame onto the screen
local function drawChanges( motion, rts, w, h, now )
    local current = rts.current
    local compared = rts.snapshots[snapshotToCompare( motion.lag, now )]

    -- blending stops at black, so either way round the change can be, it takes two subtractions
    -- behind gets the snapshot minus the current frame, the screen gets the other way, then behind's added on
    render.PushRenderTarget( rts.behind.target )
    cam.Start2D()
        drawReplacing( compared.mat, w, h )
        drawSubtracting( current.mat, w, h )
        render.OverrideBlend( false )
    cam.End2D()
    render.PopRenderTarget()

    local threshold = motion.threshold * 255
    cam.Start2D()
        drawReplacing( current.mat, w, h )
        drawSubtracting( compared.mat, w, h )
        drawAdding( rts.behind.mat, w, h )

        -- small changes dropped, flickering lights, noise
        render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_REVERSE_SUBTRACT )
        surface.SetDrawColor( threshold, threshold, threshold, 255 )
        surface.DrawRect( 0, 0, w, h )
        render.OverrideBlend( false )
    cam.End2D()

    grey["$pp_colour_contrast"] = motion.gain
    DrawColorModify( grey )

end


-- Afterglow ------------------------------------------------------------------

-- small fades round to nothing in 8 bits, so dim glow never reaches black on its own
-- this often, a step's taken off everything. by time, not per frame, or high fps would kill the glow early
local glowStepInterval = 1 / 30
local glowStep = 2 -- out of 255

-- the glow so far, faded by keep, kept wherever it's brighter than what just changed
local function drawAfterglow( glow, keep, stepDown, w, h )
    local level = keep * 255
    cam.Start2D()
        render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_MAX )
        surface.SetMaterial( glow.mat )
        surface.SetDrawColor( level, level, level, 255 )
        surface.DrawTexturedRect( 0, 0, w, h )

        if stepDown then
            render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_REVERSE_SUBTRACT )
            surface.SetDrawColor( glowStep, glowStep, glowStep, 255 )
            surface.DrawRect( 0, 0, w, h )

        end
        render.OverrideBlend( false )
    cam.End2D()

end


-- Each frame -----------------------------------------------------------------

-- the glow's fed at most this often, past it frames are skipped
-- each feed draws the glow back through a material, which darkens it a little, so more feeds a second would fade it faster
local glowRate = 66

local lastGlowStep = 0
local lastGlow = 0
local lastShown = 0
local lastDraw = 0

-- compares this frame, adds it to the glow, and keeps the snapshots going
local function feedGlow( motion, rts, now, stale )
    local w, h = ScrW(), ScrH()
    local current = rts.current
    render.CopyRenderTargetToTexture( current.target )

    if stale then
        -- nothing to compare against, the frame as it is becomes every snapshot
        for index, snapshot in ipairs( rts.snapshots ) do
            render.CopyTexture( current.target, snapshot.target )
            snapshotTimes[index] = now

        end
        lastSnapshot = now
        targetsFresh = false
        -- or glow from the last time they were down shows up
        render.ClearRenderTarget( rts.glow.target, color_black )

    end

    drawChanges( motion, rts, w, h, now )

    local stepDown = now - lastGlowStep >= glowStepInterval
    if stepDown then lastGlowStep = now end
    drawAfterglow( rts.glow, math.exp( -( now - lastGlow ) / motion.afterglow ), stepDown, w, h )
    render.CopyRenderTargetToTexture( rts.glow.target )
    lastGlow = now

    -- after the compare, so it's never written over before it's used
    if now - lastSnapshot >= motion.lag / snapshotCount then
        local oldest = oldestSnapshot()
        render.CopyTexture( current.target, rts.snapshots[oldest].target )
        snapshotTimes[oldest] = now
        lastSnapshot = now

    end
end

function SWEP:DrawGleeVision()
    local motion = self.Motion
    local w, h = ScrW(), ScrH()
    local rts = getTargets( w, h )
    local now = RealTime()

    local stale = targetsFresh or now - lastDraw > staleAfter
    lastDraw = now

    if stale or now - lastGlow >= 1 / glowRate then
        feedGlow( motion, rts, now, stale )

    end

    -- the glow's fed all the time, wide tubes just show it less often
    local refreshRate = self:CurrentFov().refreshRate
    if stale or not refreshRate or now - lastShown >= 1 / refreshRate then
        render.CopyTexture( rts.glow.target, rts.shown.target )
        lastShown = now

    end

    -- the screen has the picture, or a feed's glow, on it. this puts the last redraw over it
    render.DrawTextureToScreen( rts.shown.target )

    drawGrain( motion.grain, w, h )

end
