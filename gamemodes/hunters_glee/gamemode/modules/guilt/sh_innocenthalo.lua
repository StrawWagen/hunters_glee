
-- Halos over the innocent, the players it's a guilty kill to kill
-- Only the GUILTY see them, they're the ones who need the reminder
--
-- the server only picks who wears one, that's WHO GETS A HALO
-- the client starts at the bottom of the file, in PUTTING IT ON
-- the halos themselves are drawn in DRAWING A HALO, the blocks before it are what they're made of

local GAMEMODE = GAMEMODE or GM

local haloName = "innocent_halo"
local newbieHaloName = "innocent_halo_newbie" -- new here, and their killer's guilt weighs far heavier. brighter, and it shines

if SERVER then
    -- -----------------------------------------------------------------------
    -- WHO GETS A HALO
    -- the effects handed out here are what the client draws
    -- -----------------------------------------------------------------------

    GAMEMODE:RegisterStatusEffect( haloName )
    GAMEMODE:RegisterStatusEffect( newbieHaloName )

    local function haloFor( ply )
        local _, guiltData = GAMEMODE:GetPlysGuiltLevel( ply )
        if guiltData.killedForNoGuilt then return end

        if GAMEMODE:IsFirstTimePlayer( ply ) then return newbieHaloName end
        return haloName

    end

    local function setHalo( ply, name, wanted )
        if wanted == ply:HasStatusEffect( name ) then return end

        if wanted then
            ply:GiveStatusEffect( name )

        else
            ply:RemoveStatusEffect( name )

        end
    end

    -- polled, innocence moves with guilt, bank funds, the tutorial, and effects get wiped on round change
    timer.Create( "glee_innocenthalos", 1, 0, function()
        if not IsValid( LocalPlayer() ) then return end
        if not GAMEMODE:PersistentGuiltIsEnabled() then return end

        for _, ply in player.Iterator() do
            local halo = haloFor( ply )
            setHalo( ply, haloName, halo == haloName )
            setHalo( ply, newbieHaloName, halo == newbieHaloName )

        end
    end )
end

if CLIENT then
    local math = math
    local render = render


    -- -----------------------------------------------------------------------
    -- THE PROP
    -- the model and colors every halo shares
    -- -----------------------------------------------------------------------

    -- the model's never drawn, it's just what rides the head. the halo's a ring of beams drawn around it, in its up plane
    -- alpha under 255 puts the prop with the translucents, where the beams and sprites belong
    local haloModel = "models/hunter/tubes/tube2x2x025.mdl"
    local haloScale = 0.12
    local haloColor = Color( 220, 190, 90, 254 )
    local newbieHaloColor = Color( 255, 250, 215, 254 )


    -- -----------------------------------------------------------------------
    -- THE RING
    -- the glowing line every halo is built from
    -- -----------------------------------------------------------------------

    -- beams face the camera, so the ring's a glowing line from any angle, light, not a solid object
    local ringMat = Material( "sprites/tp_beam001" )
    local haloRadius = 5.5
    local ringCoreWidth = 1.5
    local ringCoreBrightness = 0.9
    local ringEdgeWidth = 5 -- a faint wide ring under the core, blurs its edge
    local ringEdgeBrightness = 0.3
    local ringTextureRepeats = 4

    -- the ring's points, worked out once. drawn every frame for every halo, so no trig or new Vectors in there
    local function makeRingPoints( segments )
        local points = { count = segments, cos = {}, sin = {}, tex = {} }
        for seg = 0, segments do
            local frac = seg / segments
            local ang = frac * math.pi * 2
            points.cos[seg] = math.cos( ang )
            points.sin[seg] = math.sin( ang )
            points.tex[seg] = frac * ringTextureRepeats

        end
        return points
    end

    -- past this, a halo's just its core ring, at fewer segments. no edge, wobble, crackle, arcs or eyes
    local farDistSqr = 600 ^ 2
    local nearRing = makeRingPoints( 24 )
    local farRing = makeRingPoints( 12 )

    local ringColor = Color( 255, 255, 255 )
    local ringPos = Vector()

    -- texShift slides the texture round the ring, in texture lengths
    local function drawRing( ring, center, forward, right, radius, width, color, brightness, texShift )
        brightness = math.min( brightness, 1 )
        ringColor.r = color.r * brightness
        ringColor.g = color.g * brightness
        ringColor.b = color.b * brightness
        ringColor.a = 255 * brightness

        local cx, cy, cz = center:Unpack()
        local fx, fy, fz = forward:Unpack()
        local rx, ry, rz = right:Unpack()
        local cosOf, sinOf, texOf = ring.cos, ring.sin, ring.tex

        render.StartBeam( ring.count + 1 )
        for seg = 0, ring.count do
            local along = cosOf[seg] * radius
            local across = sinOf[seg] * radius
            ringPos:SetUnpacked( cx + fx * along + rx * across, cy + fy * along + ry * across, cz + fz * along + rz * across )
            render.AddBeam( ringPos, width, texOf[seg] + texShift, ringColor )

        end
        render.EndBeam()

    end


    -- -----------------------------------------------------------------------
    -- WOBBLE AND FLICKER
    -- why a halo's never quite still
    -- -----------------------------------------------------------------------

    -- the halo leans a couple degrees and the lean swings round, like a top on a table
    -- the owner speeding up or stopping knocks it, and it springs back to its spin
    local wobbleRestTilt = math.rad( 2 ) -- the lean it spins at, undisturbed
    local wobbleMaxTilt = math.rad( 6 )
    local wobblePrecession = 2.5 -- radians a second the lean swings round
    local wobbleStiffness = 40
    local wobbleDamping = 4
    local wobbleKick = 0.002 -- lean speed per unit/s the owner's velocity changes
    local wobbleMaxStep = 0.1 -- seconds, a hitch doesn't fling it

    -- returns the lean along forward and right, in radians. steps once a frame, however many passes draw it
    local function wobbleTilt( owner, prop, forward, right, now )
        local wobble = prop.glee_haloWobble
        if not wobble then
            wobble = { tiltX = 0, tiltY = 0, speedX = 0, speedY = 0, frame = 0, lastVelX = 0, lastVelY = 0, lastVelZ = 0 }
            prop.glee_haloWobble = wobble

        end

        local frame = FrameNumber()
        if wobble.frame == frame then return wobble.tiltX, wobble.tiltY end

        local velX, velY, velZ = owner:GetVelocity():Unpack()

        -- not drawn last frame, eg off screen or far. the velocity change since then isn't a knock
        if wobble.frame == frame - 1 then
            local dt = math.min( FrameTime(), wobbleMaxStep )

            -- leans against the change, lagging behind the head
            local changeX, changeY, changeZ = velX - wobble.lastVelX, velY - wobble.lastVelY, velZ - wobble.lastVelZ
            local fx, fy, fz = forward:Unpack()
            local rx, ry, rz = right:Unpack()
            wobble.speedX = wobble.speedX - ( changeX * fx + changeY * fy + changeZ * fz ) * wobbleKick
            wobble.speedY = wobble.speedY - ( changeX * rx + changeY * ry + changeZ * rz ) * wobbleKick

            local phase = now * wobblePrecession + owner:EntIndex()
            local restX = math.cos( phase ) * wobbleRestTilt
            local restY = math.sin( phase ) * wobbleRestTilt

            wobble.speedX = wobble.speedX + ( ( restX - wobble.tiltX ) * wobbleStiffness - wobble.speedX * wobbleDamping ) * dt
            wobble.speedY = wobble.speedY + ( ( restY - wobble.tiltY ) * wobbleStiffness - wobble.speedY * wobbleDamping ) * dt
            wobble.tiltX = wobble.tiltX + wobble.speedX * dt
            wobble.tiltY = wobble.tiltY + wobble.speedY * dt

            local tilt = math.sqrt( wobble.tiltX ^ 2 + wobble.tiltY ^ 2 )
            if tilt > wobbleMaxTilt then
                wobble.tiltX = wobble.tiltX * wobbleMaxTilt / tilt
                wobble.tiltY = wobble.tiltY * wobbleMaxTilt / tilt

            end
        end

        wobble.frame = frame
        wobble.lastVelX, wobble.lastVelY, wobble.lastVelZ = velX, velY, velZ
        return wobble.tiltX, wobble.tiltY

    end

    -- unsteady, like a candle. offset per player so a crowd of halos doesn't flicker in step
    local function flickerFor( owner, now )
        local offset = owner:EntIndex() * 1.7
        return 0.8 + 0.2 * math.sin( now * 11 + offset ) * math.sin( now * 4.3 + offset )

    end


    -- -----------------------------------------------------------------------
    -- THE WATCHER'S WHEEL
    -- the newbie halo is a Watcher's wheel. the divine powers, keeping an eye on their innocent
    -- their power is lightning. it crackles round the rim, and arcs across it
    -- the rim is full of eyes, mostly shut. aim at the newbie, and they all open on you
    -- -----------------------------------------------------------------------

    local glowMat = Material( "sprites/light_glow02_add" )
    local crackleMat = Material( "sprites/tp_beam001" )

    local crackleWidth = 3
    local crackleBrightness = 0.35
    local crackleSpeed = 3 -- texture lengths a second it crawls round the rim
    local crackleColor = Color( 210, 225, 255 )

    -- the Watcher keeps time with the guilty's own heart, an arc and a flare on every beat
    -- so a racing heart sets the halo crackling
    local beatDecay = 6 -- how fast a beat's flare dies, per second
    local ringBeatFlare = 0.8 -- extra core ring brightness on the beat, on top of 1
    local ringBeatGrowth = 0.25 -- extra ring radius on the beat, on top of 1
    local lastBeat = -math.huge
    local beatCount = 0

    -- glee_cl_heartbeat, hooked while there's a newbie halo on
    local function noteHeartbeat()
        lastBeat = CurTime()
        beatCount = beatCount + 1

    end

    -- 1 on the beat, dying away to 0 before the next
    local function beatPulse( now )
        return math.exp( -( now - lastBeat ) * beatDecay )

    end

    local arcLife = 0.15
    local arcPointCount = 6
    local arcJitter = 1.2
    local arcWidth = 1
    local arcColor = Color( 220, 230, 255 )
    local arcPos = Vector()

    -- a short jagged arc across the ring, between two rim points, on the beat
    local function drawArc( center, forward, right, up, radius, now, seed )
        local age = now - lastBeat
        if age > arcLife then return end

        -- the ends come from the beat, so an arc holds still for its short life. only the jag between flickers
        -- seeded per halo, so every halo on screen doesn't arc the same way
        local slot = beatCount + seed
        local angA = slot * 2.39996
        local angB = angA + math.pi * ( 0.5 + ( slot * 0.618 ) % 0.5 )
        local startAlong, startAcross = math.cos( angA ) * radius, math.sin( angA ) * radius
        local endAlong, endAcross = math.cos( angB ) * radius, math.sin( angB ) * radius

        local fade = 1 - age / arcLife
        arcColor.a = 255 * fade

        local cx, cy, cz = center:Unpack()
        local fx, fy, fz = forward:Unpack()
        local rx, ry, rz = right:Unpack()
        local ux, uy, uz = up:Unpack()

        local last = arcPointCount - 1
        render.StartBeam( arcPointCount )
        for point = 0, last do
            local t = point / last
            local along = startAlong + ( endAlong - startAlong ) * t
            local across = startAcross + ( endAcross - startAcross ) * t
            local lift = 0
            if point ~= 0 and point ~= last then
                along = along + math.Rand( -arcJitter, arcJitter )
                across = across + math.Rand( -arcJitter, arcJitter )
                lift = math.Rand( -arcJitter, arcJitter )

            end
            arcPos:SetUnpacked(
                cx + fx * along + rx * across + ux * lift,
                cy + fy * along + ry * across + uy * lift,
                cz + fz * along + rz * across + uz * lift
            )
            render.AddBeam( arcPos, arcWidth * fade, t, arcColor )

        end
        render.EndBeam()

    end

    local eyeCount = 7
    local eyeSpin = 0.3 -- radians a second the eyes drift round the rim
    local eyeShutSize = 1.5
    local eyeOpenSize = 5
    local eyeShutAlpha = 25
    local eyeColor = Color( 235, 240, 255 )

    local function drawEyes( center, forward, right, radius, now, closeness, offset )
        local cx, cy, cz = center:Unpack()
        local fx, fy, fz = forward:Unpack()
        local rx, ry, rz = right:Unpack()

        for eye = 1, eyeCount do
            local ang = eye / eyeCount * math.pi * 2 + now * eyeSpin
            local along = math.cos( ang ) * radius
            local across = math.sin( ang ) * radius
            ringPos:SetUnpacked( cx + fx * along + rx * across, cy + fy * along + ry * across, cz + fz * along + rz * across )

            -- each one cracks open now and then on its own
            local peek = math.max( 0, math.sin( now * 0.7 + eye * 2.3 + offset ) ) ^ 4 * 0.5
            local open = math.max( peek, closeness )

            eyeColor.a = eyeShutAlpha + ( 255 - eyeShutAlpha ) * open
            local size = eyeShutSize + ( eyeOpenSize - eyeShutSize ) * open
            render.DrawSprite( ringPos, size, size, eyeColor )

        end
    end


    -- -----------------------------------------------------------------------
    -- BEING NOTICED
    -- crosshair on a nearby newbie, and the Watcher notices you. it goes still, its eyes open, the world closes in on it
    -- -----------------------------------------------------------------------

    local aimConeOuter = math.cos( math.rad( 16 ) ) -- starts reacting
    local aimConeInner = math.cos( math.rad( 5 ) ) -- fully reacting
    local aimDistOuter = 250 -- starts reacting, nothing's traced past this
    local aimDistInner = 100 -- fully reacting
    local aimBoost = 1.5 -- extra intensity at full aim, on top of 1
    local ringNoticedGrowth = 0.8 -- extra ring radius at full aim, on top of 1
    local noticedTunnelClear = 0.35 -- of screen height, the clear middle around the halo at full aim, see cl_tunnelvision.lua

    -- the strongest aim at any newbie this frame. read by the thunder below
    local aimedAtCloseness = 0
    local aimedAtFrame = 0

    -- 0 to 1, how squarely and how close the local player's looking at owner's halo. 0 through walls
    -- the halo, not their middle, it's what the tunnel frames
    -- the dead get noticed too, a ghost's still guilty
    local function aimClosenessTo( owner, target )
        local viewer = LocalPlayer()
        local eyePos = EyePos()
        local toTarget = target - eyePos
        local dist = toTarget:Length()
        if dist >= aimDistOuter then return 0 end

        toTarget:Div( dist )
        local aimed = math.Remap( EyeVector():Dot( toTarget ), aimConeOuter, aimConeInner, 0, 1 )
        if aimed <= 0 then return 0 end

        local near = math.Remap( dist, aimDistOuter, aimDistInner, 0, 1 )
        local closeness = math.min( aimed, 1 ) * math.min( near, 1 )

        local tr = util.TraceLine( {
            start = eyePos,
            endpos = target,
            filter = { viewer, owner },
            mask = MASK_VISIBLE,
        } )
        if tr.Hit then return 0 end

        return closeness

    end

    -- call while drawing in 3D, the tunnel's screen pos comes from the view being drawn
    local function noteAimedAt( closeness, center )
        local frame = FrameNumber()
        if aimedAtFrame ~= frame then
            aimedAtFrame = frame
            aimedAtCloseness = 0

        end
        aimedAtCloseness = math.max( aimedAtCloseness, closeness )
        if closeness <= 0 then return end

        local onScreen = center:ToScreen()
        GAMEMODE:RequestTunnelVision( closeness, noticedTunnelClear, onScreen.x, onScreen.y )

    end

    -- distant thunder, once, as the Watcher first notices you
    local thunderSounds = {
        "ambient/atmosphere/thunder1.wav",
        "ambient/atmosphere/thunder2.wav",
        "ambient/atmosphere/thunder3.wav",
        "ambient/atmosphere/thunder4.wav",
    }
    local thunderAtCloseness = 0.3
    local thunderCooldown = 10
    local thunderVolume = 0.3
    local thunderDist = 300 -- how far off it rolls in from
    local thunderLift = 200
    local nextThunder = 0
    local thundered = false -- since the aim last fell away

    local function rumbleThunder()
        local volume = thunderVolume
        local volumeVar = GetConVar( "cl_huntersglee_lightningvolume" )
        if volumeVar then
            volume = volume * volumeVar:GetFloat()

        end
        if volume <= 0 then return end

        local dir = VectorRand()
        dir.z = 0
        dir:Normalize()
        local from = EyePos() + dir * thunderDist + vector_up * thunderLift

        sound.Play( thunderSounds[math.random( #thunderSounds )], from, 90, math.random( 60, 75 ), volume )

    end

    -- RenderScreenspaceEffects, hooked while there's a newbie halo on. after every halo's drawn, so the aim's all in
    local function noticeThunder()
        local closeness = 0
        if aimedAtFrame == FrameNumber() then
            closeness = aimedAtCloseness

        end
        local now = CurTime()
        if closeness <= 0 then
            thundered = false

        elseif closeness >= thunderAtCloseness and not thundered and now >= nextThunder then
            thundered = true
            nextThunder = now + thunderCooldown
            rumbleThunder()

        end

    end


    -- -----------------------------------------------------------------------
    -- THE SMITE
    -- the halo leaping out as it strikes whoever hurt its innocent. set by eff_glee_halosmite
    -- -----------------------------------------------------------------------

    local smiteGrowth = 2.5 -- extra ring radius on the strike, on top of 1
    local smiteBrightness = 2
    local smiteDecay = 4 -- per second, mostly gone in half a second

    local function smiteSpike( owner, now )
        local smoteAt = owner.glee_haloSmiteTime
        if not smoteAt then return 0 end

        return math.exp( -( now - smoteAt ) * smiteDecay )

    end


    -- -----------------------------------------------------------------------
    -- VIEWS AND BOUNDS
    -- the engine doesn't know the ring's there, it culls by the model, and redraws it for reflections
    -- -----------------------------------------------------------------------

    -- water reflections and RT cameras draw the halo again, from their own view
    -- those only get the cheap core ring, no aim. their aim's not yours, and their ToScreen would throw the tunnel
    local mainViewOrigin = Vector()

    -- RenderScene, hooked while there's any halo on
    local function noteMainView( origin )
        mainViewOrigin:Set( origin )

    end

    local function drawingMainView()
        return EyePos():DistToSqr( mainViewOrigin ) < 1

    end

    -- the model's bounds are a tiny tube's. the ring grows far past them, and would get culled while still on screen
    -- bigger than it needs, it's in the model's space, which may or may not get haloScale applied
    local haloReach = haloRadius * ( 1 + ringNoticedGrowth + ringBeatGrowth + smiteGrowth ) + ringEdgeWidth
    local reachBounds = Vector( haloReach, haloReach, haloReach ) / haloScale

    -- every draw, a model scale change can reset them. the prop only draws when it's on screen, so this keeps up
    local function padBounds( prop )
        prop:SetRenderBounds( -reachBounds, reachBounds )

    end


    -- -----------------------------------------------------------------------
    -- DRAWING A HALO
    -- the draw function for each kind of halo, on the living and on their souls
    -- -----------------------------------------------------------------------

    local function makeHaloDraw( color, shines )
        return function( owner, prop )
            padBounds( prop )
            local now = CurTime()
            local flicker = flickerFor( owner, now )
            local center = prop:GetPos()
            local forward = prop:GetForward()
            local right = prop:GetRight()

            -- where the smite arcs from, see eff_glee_halosmite
            owner.glee_haloCenter = center
            owner.glee_haloDrawnTime = now

            local smite = smiteSpike( owner, now )
            local smiteFlare = 1 + smite * smiteBrightness

            render.SetMaterial( ringMat )

            if EyePos():DistToSqr( center ) > farDistSqr or not drawingMainView() then
                local farRadius = haloRadius * ( 1 + smite * smiteGrowth )
                drawRing( farRing, center, forward, right, farRadius, ringCoreWidth, color, ringCoreBrightness * flicker * smiteFlare, 0 )
                return

            end

            local closeness = 0
            if shines then
                closeness = aimClosenessTo( owner, center )
                noteAimedAt( closeness, center )

            end
            local boost = 1 + closeness * aimBoost
            -- noticing you, or striking. it's still, and every eye's open
            local focus = math.max( closeness, smite )

            -- a couple degrees, close enough to just nudge the axes instead of rotating them
            local up = prop:GetUp()
            local tiltX, tiltY = wobbleTilt( owner, prop, forward, right, now )
            local unfocused = 1 - focus
            tiltX, tiltY = tiltX * unfocused, tiltY * unfocused
            forward, right, up = forward - up * tiltX, right - up * tiltY, up + forward * tiltX + right * tiltY

            local pulse = 0
            if shines then
                pulse = beatPulse( now )

            end
            local beat = 1 + pulse * ringBeatFlare

            -- swells as it notices you, same as the tunnel closing in, throbs with your heart, and leaps as it strikes
            local radius = haloRadius * ( 1 + closeness * ringNoticedGrowth + pulse * ringBeatGrowth + smite * smiteGrowth )

            drawRing( nearRing, center, forward, right, radius, ringEdgeWidth, color, ringEdgeBrightness * flicker * smiteFlare, 0 )
            drawRing( nearRing, center, forward, right, radius, ringCoreWidth, color, ringCoreBrightness * flicker * boost * beat * smiteFlare, 0 )
            if not shines then return end

            local offset = owner:EntIndex() * 1.7

            render.SetMaterial( crackleMat )
            drawRing( nearRing, center, forward, right, radius, crackleWidth, crackleColor, crackleBrightness * boost * smiteFlare, now * crackleSpeed * boost )
            drawArc( center, forward, right, up, radius, now, owner:EntIndex() )

            render.SetMaterial( glowMat )
            drawEyes( center, forward, right, radius, now, focus, offset )

        end
    end

    -- the innocent's soul keeps their halo, see cl_souls.lua. only the dead see souls, so only guilty ghosts see these
    -- calm, a ghost can't be hurt, so nothing to notice. no aim, tunnel, eyes or arcs
    local soulBrightness = 0.5 -- souls are drawn half see through, so's their halo

    local function makeSoulHaloDraw( color )
        return function( soul, prop )
            padBounds( prop )
            local now = CurTime()
            local center = prop:GetPos()
            local forward = prop:GetForward()
            local right = prop:GetRight()

            local soulsPly = soul:GetOwner()
            local brightness = soulBrightness * flickerFor( IsValid( soulsPly ) and soulsPly or soul, now )

            render.SetMaterial( ringMat )

            if EyePos():DistToSqr( center ) > farDistSqr or not drawingMainView() then
                drawRing( farRing, center, forward, right, haloRadius, ringCoreWidth, color, ringCoreBrightness * brightness, 0 )
                return

            end

            local up = prop:GetUp()
            local tiltX, tiltY = wobbleTilt( soul, prop, forward, right, now )
            forward, right = forward - up * tiltX, right - up * tiltY

            drawRing( nearRing, center, forward, right, haloRadius, ringEdgeWidth, color, ringEdgeBrightness * brightness, 0 )
            drawRing( nearRing, center, forward, right, haloRadius, ringCoreWidth, color, ringCoreBrightness * brightness, 0 )

        end
    end


    -- -----------------------------------------------------------------------
    -- HALO ENTRIES
    -- the extra models a halo is made of, one for each place it can sit
    -- -----------------------------------------------------------------------

    -- where it sits, the first of these the model has
    local headBoneName = "ValveBiped.Bip01_Head1"
    local headHaloHeight = 8 -- above the head bone
    local eyesAttachmentName = "eyes"
    local eyesHaloHeight = 7 -- above the eyes attachment
    local originHaloHeight = 80 -- above the origin, players only, a ragdoll's origin flops about

    -- "head", "eyes", "origin" or nil, the first of those ent has to put a halo on
    -- origin's only for players, they stand upright. a ragdoll's origin is wherever it flopped
    local function haloPlacement( ent, originOk )
        if ent:LookupBone( headBoneName ) then return "head" end
        if ent:LookupAttachment( eyesAttachmentName ) > 0 then return "eyes" end
        if originOk then return "origin" end

    end

    -- the ring's drawn in the model's forward/right plane, so its up wants to point out the top of the head
    local function placeEntry( entry, placement )
        if placement == "head" then
            entry.bone = headBoneName
            entry.pos = Vector( headHaloHeight, 0, 0 ) -- the head bone's x points up
            entry.ang = Angle( 90, 0, 0 )

        elseif placement == "eyes" then
            entry.attachment = eyesAttachmentName
            entry.pos = Vector( 0, 0, eyesHaloHeight ) -- the eyes attachment's z points up

        else
            entry.pos = Vector( 0, 0, originHaloHeight )

        end
        return entry

    end

    local function haloEntry( color, shines, placement )
        return placeEntry( {
            model = haloModel,
            color = color,
            scale = haloScale,
            hideWhenDead = true,
            draw = makeHaloDraw( color, shines ),
        }, placement )

    end

    local function haloEntries( color, shines )
        return {
            head = haloEntry( color, shines, "head" ),
            eyes = haloEntry( color, shines, "eyes" ),
            origin = haloEntry( color, shines, "origin" ),
        }
    end

    local halos = {
        [haloName] = haloEntries( haloColor, false ),
        [newbieHaloName] = haloEntries( newbieHaloColor, true ),
    }

    local function soulHaloEntry( color, placement )
        return placeEntry( {
            model = haloModel,
            color = color,
            scale = haloScale,
            draw = makeSoulHaloDraw( color ),
        }, placement )

    end

    local function soulHaloEntries( color )
        return {
            head = soulHaloEntry( color, "head" ),
            eyes = soulHaloEntry( color, "eyes" ),
        }
    end

    local soulHalos = {
        [haloName] = soulHaloEntries( haloColor ),
        [newbieHaloName] = soulHaloEntries( newbieHaloColor ),
    }


    -- -----------------------------------------------------------------------
    -- PUTTING IT ON
    -- the status effects themselves, on the player and on their soul
    -- -----------------------------------------------------------------------

    -- per halo name, so swapping one halo for the other can't have the old one's teardown take the new one off
    local function soulHaloKey( name )
        return "glee_innocenthalo_soul_" .. name

    end

    local function haloOnSoul( name, soul )
        if not IsValid( soul ) then return end

        local placement = haloPlacement( soul, false )
        if not placement then return end

        terminator_Extras.AttachMyExtraModels( soul, { soulHalos[name][placement] }, soulHaloKey( name ) )

    end

    -- checked once, when the halo goes on. someone turning GUILTY mid round sees them next round
    local function localPlyIsGuilty()
        local level = GAMEMODE:GetPlysGuiltLevel( LocalPlayer() )
        return level >= GAMEMODE.PermaGuiltLevels.GUILTY

    end

    -- where it sits is picked once too, a model change to one without that bone or attachment loses the halo until it's reapplied
    local function putOnHalo( self, owner )
        if not localPlyIsGuilty() then return end

        local name = self:GetPrintName()
        self:HookOnce( "RenderScene", noteMainView )
        if name == newbieHaloName then
            self:HookOnce( "glee_cl_heartbeat", noteHeartbeat )
            self:HookOnce( "RenderScreenspaceEffects", noticeThunder )

        end

        self:AddExtraModel( halos[name][haloPlacement( owner, true )] )

        -- souls come and go while the effect's on, they're remade on every death and model change
        haloOnSoul( name, owner.glee_soul )
        self:Hook( "glee_soulcreated", function( soul, soulsPly )
            if soulsPly ~= owner then return end
            haloOnSoul( name, soul )

        end )
    end

    -- the soul's halo goes with the soul, this is for the effect ending while the soul's still around
    local function takeOffHalo( self, owner )
        local soul = owner.glee_soul
        if not IsValid( soul ) then return end

        terminator_Extras.RemoveMyExtraModels( soul, soulHaloKey( self:GetPrintName() ) )

    end

    GAMEMODE:RegisterStatusEffect( haloName, putOnHalo, takeOffHalo )
    GAMEMODE:RegisterStatusEffect( newbieHaloName, putOnHalo, takeOffHalo )
end
