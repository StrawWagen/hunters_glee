AddCSLuaFile()

-- The haptic goggles' radar, glee_nvg_pvs14.
-- With them selected, press E (not aimed at anything) to open a use wheel: radar on or off, or cycle the wavelength.
-- While the radar's on and they're flipped down, the wearer's client fires rays every frame from their eyes, around
-- where they look, that bounce off whatever they hit. The rays aren't drawn. A ray that hits a living player, npc or
-- nextbot puts that target's blip there, one blip per target, moved to every new hit. A blip beeps once when it's
-- first made, and goes away 10 seconds after its target was last hit.
-- Everything's drawn for the wearer only, the server just keeps the radar state on the weapon.

local hapticClass = "glee_nvg_pvs14"

-- rays = per frame, bounces = how many times each can reflect, spread = degrees off the aim
-- high is many rays that reflect once, low is few rays that go a long way round
GleeNVG.wavelengths = {
    { name = "High", rays = 30, bounces = 1, spread = 20 },
    { name = "Medium", rays = 10, bounces = 5, spread = 25 },
    { name = "Low", rays = 4, bounces = 10, spread = 30 },
}

local function hapticOf( ply )
    local wep = ply:GetWeapon( hapticClass )
    if IsValid( wep ) then return wep end

end

local function wavelengthOf( wep )
    local wavelengths = GleeNVG.wavelengths
    return wavelengths[wep:GetWavelength()] or wavelengths[1]

end

if SERVER then
    util.AddNetworkString( "glee_nvg_hapticpick" )

    local pickCooldown = 0.2

    net.Receive( "glee_nvg_hapticpick", function( _, ply )
        if ( ply.glee_NextHapticPick or 0 ) > CurTime() then return end
        ply.glee_NextHapticPick = CurTime() + pickCooldown
        if not ply:Alive() then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid( wep ) or wep:GetClass() ~= hapticClass then return end

        local key = net.ReadString()
        if key == "radar" then
            local on = not wep:GetRadarOn()
            wep:SetRadarOn( on )
            ply:EmitSound( on and "buttons/button17.wav" or "buttons/button16.wav", 55, 120, 0.6 )

        elseif key == "wavelength" then
            local nextIndex = wep:GetWavelength() % #GleeNVG.wavelengths + 1
            wep:SetWavelength( nextIndex )
            ply:EmitSound( "buttons/lightswitch2.wav", 55, 90 + nextIndex * 15, 0.6 )

        end
    end )

    return

end

-- the wheel ---------------------------------------------------------------------

local OUTER_RADIUS_1080P = 300
local useWasDown = false

-- built when it opens, so the labels say what picking them does right now
local function wheelActions( wep )
    local wavelengths = GleeNVG.wavelengths
    local nextIndex = wep:GetWavelength() % #wavelengths + 1
    return {
        { key = "radar", label = wep:GetRadarOn() and "Radar: turn off" or "Radar: turn on" },
        { key = "wavelength", label = "Wavelength: " .. wavelengthOf( wep ).name .. " > " .. wavelengths[nextIndex].name },
    }
end

-- glee_carrying's use wheel, opened on the held goggles instead of something aimed at
-- shares glee_Carrying.CurrentWheel, so its own CreateMove lets go of it when use is released
local function openWheel( ply, wep )
    local carrying = terminator_Extras and terminator_Extras.glee_Carrying
    if not carrying then return end

    local oldWheel = carrying.CurrentWheel
    if IsValid( oldWheel ) then oldWheel:Remove() end

    local wheel = vgui.Create( "glee_wheel" )
    if not IsValid( wheel ) then return end
    local outer = wheel:Style():Scaled( OUTER_RADIUS_1080P )

    wheel:SetSize( outer * 2, outer * 2 )
    wheel:SetItems( wheelActions( wep ) )
    wheel:Center()

    function wheel:GetItemStatus()
        return IsValid( wep ) and ply:GetActiveWeapon() == wep

    end

    function wheel:OnItemSelected( item )
        net.Start( "glee_nvg_hapticpick" )
            net.WriteString( item.key )
        net.SendToServer()
        self:Close()

    end

    hook.Add( "Think", wheel, function( self )
        if IsValid( wep ) and ply:Alive() and ply:GetActiveWeapon() == wep then return end
        self:Close()

    end )

    wheel:HoldAim()
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    carrying.CurrentWheel = wheel

end

-- E with the goggles out, and nothing usable in front, so doors and pickups still work
local function aimingAtSomething( ply )
    local carrying = terminator_Extras and terminator_Extras.glee_Carrying
    local range = carrying and carrying.UseRange or 90
    local shootPos = ply:EyePos()
    local tr = util.TraceLine( {
        start = shootPos,
        endpos = shootPos + ply:GetAimVector() * range,
        filter = ply,
    } )
    return IsValid( tr.Entity )

end

hook.Add( "CreateMove", "glee_nvg_hapticwheel", function( cmd )
    local useDown = cmd:KeyDown( IN_USE )
    if useDown == useWasDown then return end
    useWasDown = useDown
    if not useDown then return end -- glee_carrying releases the wheel

    local ply = LocalPlayer()
    if not ply:Alive() or ply:InVehicle() then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or wep:GetClass() ~= hapticClass then return end
    if aimingAtSomething( ply ) then return end

    openWheel( ply, wep )

end )

-- the radar ---------------------------------------------------------------------

local segmentLength = 2000 -- longest a ray goes between bounces
local blipLife = 10 -- seconds a blip stays after its target was last hit
local blipFade = 2 -- it fades out over the last this many seconds
local blipSize = 18
local blipColor = Color( 255, 40, 40 )
local blipSound = "buttons/blip1.wav"

local blips = {} -- [ent] = { pos = last hit, seen = when }

local glow = Material( "sprites/light_glow02_add" )

local function radarRunning( me )
    if not IsValid( me ) or not me:Alive() then return end
    local _, class = me:GetGleeNVGOn()
    if class ~= hapticClass then return end
    local wep = hapticOf( me )
    if not wep or not wep:GetRadarOn() then return end
    return wep

end

local function isTarget( ent, me )
    if not IsValid( ent ) or ent == me then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return false

end

-- the target's blip moves to the newest hit, a new one beeps
local function hitTarget( ent, pos )
    local blip = blips[ent]
    if blip then
        blip.pos = pos
        blip.seen = CurTime()
        return

    end
    blips[ent] = { pos = pos, seen = CurTime() }
    surface.PlaySound( blipSound )

end

-- one ray, reflecting off what it hits until it's out of bounces, hits sky or nothing, or finds a target
local function castRay( me, start, dir, bounces )
    for _ = 0, bounces do
        local tr = util.TraceLine( {
            start = start,
            endpos = start + dir * segmentLength,
            filter = me,
            mask = MASK_SHOT,
        } )

        if not tr.Hit or tr.HitSky then return end
        if isTarget( tr.Entity, me ) then hitTarget( tr.Entity, tr.HitPos ) return end

        local normal = tr.HitNormal
        dir = dir - normal * ( 2 * dir:Dot( normal ) )
        start = tr.HitPos + normal

    end
end

local function pulse( me, wep )
    local wavelength = wavelengthOf( wep )
    local eyePos = me:EyePos()
    local ang = me:EyeAngles()
    local forward, right, up = ang:Forward(), ang:Right(), ang:Up()
    local spread = math.tan( math.rad( wavelength.spread ) )

    for _ = 1, wavelength.rays do
        local dir = forward + right * math.Rand( -spread, spread ) + up * math.Rand( -spread, spread )
        dir:Normalize()
        castRay( me, eyePos - up * 4, dir, wavelength.bounces )

    end
end

hook.Add( "Think", "glee_nvg_hapticradar", function()
    local now = CurTime()

    -- blips run out even after the radar stops, a removed target's blip stays until it runs out too
    for ent, blip in pairs( blips ) do
        if now - blip.seen > blipLife then blips[ent] = nil end

    end

    local me = LocalPlayer()
    local wep = radarRunning( me )
    if not wep then return end
    pulse( me, wep ) -- every frame

end )

hook.Add( "PostDrawTranslucentRenderables", "glee_nvg_hapticradar", function( depth, sky, sky3d )
    if depth or sky or sky3d then return end
    if not next( blips ) then return end
    local now = CurTime()

    -- blips show through walls, that's the point of them
    cam.IgnoreZ( true )
    render.SetMaterial( glow )
    for _, blip in pairs( blips ) do
        local left = blipLife - ( now - blip.seen )
        local alpha = 255 * math.Clamp( left / blipFade, 0, 1 )
        render.DrawSprite( blip.pos, blipSize, blipSize, Color( blipColor.r, blipColor.g, blipColor.b, alpha ) )

    end
    cam.IgnoreZ( false )

end )
