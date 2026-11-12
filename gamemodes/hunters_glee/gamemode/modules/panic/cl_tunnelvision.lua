
-- Tunnel vision, the world going dark around one spot on screen, closing in on every beat of your heart
--
--  -- every frame you want it, any time before RenderScreenspaceEffects
--  GAMEMODE:RequestTunnelVision( 0.8, 0.35, x, y, Color( 4, 6, 12 ) )
--
-- The strongest request each frame is the one drawn
-- Stop asking, and it fades out where it was

local doTunnelVar = CreateClientConVar( "cl_huntersglee_tunnelvision", "1", true, false, "Let your view close in during heart attacks, and when a guardian halo notices you?", 0, 1 )

local tunnelFadeSpeed = 3 -- per second, so it doesn't snap on and off
local tunnelFollowSpeed = 12 -- how fast what's shown chases what's requested, the spot, the size and the color
local tunnelBeatSqueeze = 0.08 -- of screen height, how much a beat closes it
local tunnelWeakOpening = 0.5 -- of screen height, how much wider open it is at no strength
local tunnelFalloff = 0.45 -- of screen height, from clear to fully dark
local tunnelAlpha = 220
local tunnelDefaultColor = Color( 4, 6, 12 )
local tunnelSegments = 32

-- the rings out from the middle, as a fraction of the falloff and of tunnelAlpha. smooths the edge
-- the last ring reaches far past any screen corner
local tunnelRings = {
    { dist = 0, alpha = 0 },
    { dist = 0.4, alpha = 0.2 },
    { dist = 0.75, alpha = 0.6 },
    { dist = 1, alpha = 1 },
    { dist = 20, alpha = 1 },
}

local tunnelCos, tunnelSin = {}, {}
for seg = 0, tunnelSegments do
    local ang = seg / tunnelSegments * math.pi * 2
    tunnelCos[seg] = math.cos( ang )
    tunnelSin[seg] = math.sin( ang )

end


-- Drawing

local function tunnelVertex( x, y, ring, color, strength )
    mesh.Position( x, y, 0 )
    mesh.Color( color.r, color.g, color.b, tunnelAlpha * ring.alpha * strength )
    mesh.AdvanceVertex()

end

local tunnelRadii = {}

-- a dark ring of vertex colored triangles, clear in the middle
local function drawTunnel( centerX, centerY, clear, falloff, color, strength )
    for index, ring in ipairs( tunnelRings ) do
        tunnelRadii[index] = clear + ring.dist * falloff

    end

    render.SetColorMaterial()
    mesh.Begin( MATERIAL_TRIANGLES, ( #tunnelRings - 1 ) * tunnelSegments * 2 )
    for index = 1, #tunnelRings - 1 do
        local inner, outer = tunnelRings[index], tunnelRings[index + 1]
        local innerRadius, outerRadius = tunnelRadii[index], tunnelRadii[index + 1]

        for seg = 0, tunnelSegments - 1 do
            local cosA, sinA = tunnelCos[seg], tunnelSin[seg]
            local cosB, sinB = tunnelCos[seg + 1], tunnelSin[seg + 1]

            local innerAX, innerAY = centerX + cosA * innerRadius, centerY + sinA * innerRadius
            local innerBX, innerBY = centerX + cosB * innerRadius, centerY + sinB * innerRadius
            local outerAX, outerAY = centerX + cosA * outerRadius, centerY + sinA * outerRadius
            local outerBX, outerBY = centerX + cosB * outerRadius, centerY + sinB * outerRadius

            tunnelVertex( innerAX, innerAY, inner, color, strength )
            tunnelVertex( outerAX, outerAY, outer, color, strength )
            tunnelVertex( outerBX, outerBY, outer, color, strength )

            tunnelVertex( innerAX, innerAY, inner, color, strength )
            tunnelVertex( outerBX, outerBY, outer, color, strength )
            tunnelVertex( innerBX, innerBY, inner, color, strength )

        end
    end
    mesh.End()

end


-- The heartbeat

local beatDecay = 6 -- how fast a beat's squeeze lets go, per second
local lastBeat = -math.huge

hook.Add( "glee_cl_heartbeat", "glee_tunnelvision_beat", function()
    lastBeat = CurTime()

end )

-- 1 on the beat, dying away to 0 before the next
local function beatPulse()
    return math.exp( -( CurTime() - lastBeat ) * beatDecay )

end


-- Requests

local requested = { frame = 0, strength = 0, clear = 0, x = 0, y = 0, color = tunnelDefaultColor }

--[[---------------------------------------------------------
    GM:RequestTunnelVision
    @desc Darkens the screen around a spot for this frame. Ask again every frame to keep it.
    @param strength: 0 to 1. How dark, and how far it's closed in.
    @param clear: Fraction of screen height, the radius left clear at full strength.
    @param x, y: Where on screen it centers, the middle of the screen if nil.
    @param color: Color of the dark, a near black blue if nil.
--]]---------------------------------------------------------
function GM:RequestTunnelVision( strength, clear, x, y, color )
    if not doTunnelVar:GetBool() then return end

    local frame = FrameNumber()
    if requested.frame == frame and strength <= requested.strength then return end

    requested.frame = frame
    requested.strength = strength
    requested.clear = clear
    requested.x = x or ScrW() / 2
    requested.y = y or ScrH() / 2
    requested.color = color or tunnelDefaultColor

end


-- Ties it together

-- what's on screen, chasing what was requested. held as it fades out
local shownStrength = 0
local shownClear = 0
local shownColor = Color( 0, 0, 0 )
local shownX, shownY = nil, nil

-- slides between requests instead of jumping, the strongest can be a very different tunnel from one frame to the next
local function chaseRequest( frameTime )
    -- nothing on screen to slide from, so it starts as asked
    local follow = 1
    if shownX then
        follow = math.min( frameTime * tunnelFollowSpeed, 1 )

    end

    local color = requested.color
    shownX = Lerp( follow, shownX or requested.x, requested.x )
    shownY = Lerp( follow, shownY or requested.y, requested.y )
    shownClear = Lerp( follow, shownClear, requested.clear )
    shownColor.r = Lerp( follow, shownColor.r, color.r )
    shownColor.g = Lerp( follow, shownColor.g, color.g )
    shownColor.b = Lerp( follow, shownColor.b, color.b )

end

hook.Add( "RenderScreenspaceEffects", "glee_tunnelvision", function()
    local target = 0
    if requested.frame == FrameNumber() then
        target = requested.strength

    end

    local frameTime = RealFrameTime() -- your aim doesn't slow down in slow motion, so this can't either
    shownStrength = math.Approach( shownStrength, target, frameTime * tunnelFadeSpeed )
    if shownStrength <= 0 then
        shownX = nil
        return

    end

    if target > 0 then
        chaseRequest( frameTime )

    end

    local scrH = ScrH()
    -- never under 0, a negative radius turns the mesh inside out
    local clear = math.max( shownClear - tunnelBeatSqueeze * beatPulse() + ( 1 - shownStrength ) * tunnelWeakOpening, 0 )

    cam.Start2D()
        cam.IgnoreZ( true ) -- the viewmodel's still in the depth buffer, it'd cut its shape out of the tunnel
        drawTunnel( shownX, shownY, clear * scrH, tunnelFalloff * scrH, shownColor, shownStrength )
        cam.IgnoreZ( false )
    cam.End2D()

end )
