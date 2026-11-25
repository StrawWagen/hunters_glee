
-- Who the watching camera points at, see sh_spectatewatching.lua for the mode as a whole.
-- Players, skulls and hunters all get a score, the camera watches the best.
-- Far away players are scored on whatever we last heard of them. That's fine, picking one teleports us to them.

local tune = {
    interval = 0.5, -- seconds between re-scoring everyone

    baseScore = 100, -- a quiet player doing nothing much. Hunters never score above this
    spokeRecently = 100, -- talked at all in the last GM.VoiceStatsWindow seconds
    perTalkSecond = 2, -- each second they talked in that window
    micspamAbove = 0.9, -- talking more than this much of the window...
    micspamMul = 0.25, -- ...scales the talk seconds by this. Micspam isn't as fun as people talking
    lowHealth = 150, -- at 0% health, down to nothing at full
    firstSkull = 150, -- having any skulls at all
    perSkull = 20, -- each skull after the first
    calm = -50, -- nothing's chasing them, see ply:IsCalm()
    escapeFlareMul = 2, -- carrying an escape flare gun, they might be about to escape. Times everything above
    ownerlessSkull = 100, -- skulls nobody died for, whose owner left, or from an earlier death of theirs
    deathSkullRadius = 300, -- a dead player's skull this close to where they died is from this death

    -- each kind's score is scaled by this, after everything above, people are what's worth watching
    kindMuls = {
        player = 1,
        skull = 0.25,
        hunter = 0.5,
    },

    deathMemory = 30, -- seconds a dead player keeps their last alive score
    deathFalloff = 5, -- higher drops faster at first, then trails off

    -- these two multiply, so a target scoring nothing stays at nothing
    los = 1.25, -- the camera can see them. The current target always gets it
    commitment = 1.5, -- the current target, once we pick someone, we stick with them

    teleportBeyond = 2500, -- a dead target's remains further than this teleport us, alive ones teleport when they're out of range

    -- targets this close to the current one pull the aim point towards themselves, players from much further
    aimRadii = {
        player = 1500,
        skull = 500,
        hunter = 500,
    },
    aimFadeFrom = 0.5, -- fraction of their aim radius where their pull starts fading out
    currentAimWeight = 2, -- the current target's pull, times its score
    nearbySlack = 300, -- targets this much past their aim radius are kept for the aim point too, they move between passes
    obscuredAimMul = 0.15, -- pull of nearby targets the camera can't see, on the aim. Looking at a wall isn't watching them
    obscuredGroupMul = 0.25, -- the same, on the group's spot
    groupHeightMul = 2, -- height counts this much more towards the group's distance, mentos shaped, someone a floor away isn't with them
    aimLosInterval = 0.25, -- seconds between line of sight checks on each nearby target
    companyRadius = 500, -- a living player pulling the aim this close to the current target is company. The camera settles with company, orbits and pulls in on skulls without

    -- line of sight traces, see losHullFor
    losHull = 4, -- half width, a crack a line fits through isn't a view
    losHullMin = 1, -- narrowed to this, for something small
    losHullRecheck = 1, -- seconds between remeasuring something, skulls grow
}

local LocalPlayer = LocalPlayer
local IsValid = IsValid
local CurTime = CurTime
local vecZero = Vector( 0, 0, 0 )

local debugging = GetConVar( "huntersglee_debug_spectatewatching" ):GetBool()
cvars.AddChangeCallback( "huntersglee_debug_spectatewatching", function( _, _, new )
    debugging = tobool( new )

end, "glee_watchscorer_debugging" )

local deathPosHeight = Vector( 0, 0, 16 ) -- death positions are on the floor

local rememberedScores = setmetatable( {}, { __mode = "k" } ) -- each player's last alive score
local deathByPly = {} -- from potentialResurrectionData, see cl_deadpositions.lua
local aliveLastPass = setmetatable( {}, { __mode = "k" } )
local diedBeforeSync = setmetatable( {}, { __mode = "k" } ) -- stand in death entries, until the server's arrive
local deathSkulls = {} -- each dead player's skull from this death, see findDeathSkulls
local candidates = {} -- { ent, score, kind } for everything worth watching
local nearby = {} -- the candidates close enough to the current target to pull the aim point
local current -- what the camera's watching
local nextPass = 0


--[[ Line of sight ]]

local seeThroughMask = bit.bor( CONTENTS_SOLID, CONTENTS_MOVEABLE ) -- see through windows and grates

local losTrace = {
    mins = Vector( 0, 0, 0 ),
    maxs = Vector( 0, 0, 0 ),
}

local losHulls = setmetatable( {}, { __mode = "k" } ) -- entity to { half, nextCheck }

-- A quarter of its smallest side, between losHullMin and losHull.
-- Any wider, a trace ending at its middle clips whatever it's lying on
local function losHullFor( ent, cur )
    if not IsValid( ent ) then return tune.losHull end

    local measured = losHulls[ent]
    if not measured then
        measured = { nextCheck = 0 }
        losHulls[ent] = measured

    end

    if measured.nextCheck <= cur then
        measured.nextCheck = cur + tune.losHullRecheck
        local size = ent:OBBMaxs() - ent:OBBMins()
        measured.half = math.Clamp( math.min( size.x, size.y, size.z ) / 4, tune.losHullMin, tune.losHull )

    end

    return measured.half

end

--[[---------------------------------------------------------
    GM:WatchCanSee
    @desc Whether there's a view from one spot to another.
        From out in the void, everything reads as solid, so nothing's visible from there.
    @param from: Vector
    @param to: Vector
    @param ent: What's at to, nil for an empty spot. The trace ignores it, and narrows to fit it
    @param mask: Optional, sees through windows and grates without one.
        Some maps build solid looking things out of grates, lifts included. MASK_SOLID_BRUSHONLY sees through nothing.
    @return boolean
--]]---------------------------------------------------------
function GM:WatchCanSee( from, to, ent, mask )
    if not IsValid( ent ) then
        ent = nil

    end

    local half = losHullFor( ent, CurTime() )
    losTrace.mins:SetUnpacked( -half, -half, -half )
    losTrace.maxs:SetUnpacked( half, half, half )
    losTrace.start = from
    losTrace.endpos = to
    losTrace.filter = ent
    losTrace.mask = mask or seeThroughMask
    return not util.TraceHull( losTrace ).Hit

end


--[[ Skulls and hunters, tracked as they arrive, rather than searched for ]]

local tracked = setmetatable( {}, { __mode = "k" } ) -- entity to "skull" or "hunter"

-- isTerminatorHunterBased is on the entity's class, so it's there at creation. glee_IsHunter might not have arrived yet
local function track( ent )
    if ent:GetClass() == "termhunt_skull_pickup" then
        tracked[ent] = "skull"

    elseif ent.isTerminatorHunterBased then
        tracked[ent] = "hunter"

    end
end

hook.Add( "OnEntityCreated", "glee_watchscorer_track", track )

-- the ones that arrived before this file did
for _, ent in ents.Iterator() do
    track( ent )

end


--[[ Where to look at each thing ]]

local function isDead( ply )
    return deathByPly[ply] ~= nil or ply:Health() <= 0

end

--[[---------------------------------------------------------
    GM:WatchAimPosOf
    @desc Where the camera looks to watch ent, and how fast that spot's moving.
        The dead are watched through their skull, then their ragdoll, then where they died.
    @param ent: A player, skull or hunter.
    @return Vector: The spot.
    @return Vector: Its velocity.
    @return Entity: What the spot's on, ent, their skull or their ragdoll. nil for where they died
--]]---------------------------------------------------------
function GM:WatchAimPosOf( ent )
    if ent:IsPlayer() then
        if not isDead( ent ) then return ent:GetShootPos(), ent:GetVelocity(), ent end

        local skull = deathSkulls[ent]
        if IsValid( skull ) then return skull:WorldSpaceCenter(), skull:GetVelocity(), skull end

        local ragdoll = ent:GetRagdollEntity()
        if IsValid( ragdoll ) then return ragdoll:WorldSpaceCenter(), ragdoll:GetVelocity(), ragdoll end

        local died = deathByPly[ent]
        if died then return died.pos + deathPosHeight, vecZero end

        return ent:WorldSpaceCenter(), vecZero, ent

    end

    if ent.GetShootPos then return ent:GetShootPos(), ent:GetVelocity(), ent end

    return ent:WorldSpaceCenter(), ent:GetVelocity(), ent

end

local function canSeeEnt( camPos, ent )
    if ent:IsDormant() then return false end -- where we last saw it, not where it is

    local pos, _, body = GAMEMODE:WatchAimPosOf( ent )
    return GAMEMODE:WatchCanSee( camPos, pos, body )

end


--[[ Scoring ]]

-- Whoever's carrying an escape flare gun.
-- Only guns the server sends us, a holstered one may not be, then they only count while it's out
local function flareCarriers()
    local carriers = {}
    for _, gun in ipairs( ents.FindByClass( "termhunt_aeromatix_signalflare_gun" ) ) do
        local owner = gun:GetOwner()
        if IsValid( owner ) then
            carriers[owner] = true

        end
    end

    return carriers

end

local function alivePlayerScore( ply, cur, hasFlare )
    local score = tune.baseScore

    local window = GAMEMODE.VoiceStatsWindow
    if ply:GetLastSpokeTime() > cur - window then
        score = score + tune.spokeRecently

    end

    local talkSeconds = ply:GetRecentTalkSeconds()
    local talkScore = talkSeconds * tune.perTalkSecond
    if talkSeconds > window * tune.micspamAbove then
        talkScore = talkScore * tune.micspamMul

    end
    score = score + talkScore

    local healthFraction = math.Clamp( ply:Health() / math.max( ply:GetMaxHealth(), 1 ), 0, 1 )
    score = score + ( 1 - healthFraction ) * tune.lowHealth

    local skulls = ply:GetSkulls()
    if skulls > 0 then
        score = score + tune.firstSkull + ( skulls - 1 ) * tune.perSkull

    end

    if ply:IsCalm() then
        score = score + tune.calm

    end

    score = math.max( score, 0 )
    if hasFlare then
        score = score * tune.escapeFlareMul

    end

    return score

end

-- death resets their BPM and drops their skulls, so they're scored on how they were just before
local function deadPlayerScore( ply, cur )
    local remembered = rememberedScores[ply]
    local died = deathByPly[ply]
    if not remembered or not died then return 0 end

    local left = 1 - ( cur - died.time ) / tune.deathMemory
    if left <= 0 then return 0 end

    return remembered * left ^ tune.deathFalloff

end

local function hunterScore( me, hunter )
    local scaryness = GAMEMODE:GetBotScaryness( me, hunter )
    return math.min( tune.baseScore * scaryness, tune.baseScore )

end

-- Their skull from this death only. Old ones, from earlier deaths and rounds, say nothing about them now
local function skullScore( skull, playerScores )
    local owner = player.GetBySteamID64( skull:GetOwnerSteamID64() )
    if not IsValid( owner ) or deathSkulls[owner] ~= skull then return tune.ownerlessSkull end

    return playerScores[owner] or 0

end

-- A player's skulls all carry their SteamID, persisted ones from earlier rounds too.
-- The one from this death is the one nearest where they died
local function findDeathSkulls( skulls )
    deathSkulls = {}
    local nearestDistSqr = {}
    local radiusSqr = tune.deathSkullRadius ^ 2

    for _, skull in ipairs( skulls ) do
        local owner = player.GetBySteamID64( skull:GetOwnerSteamID64() )
        local died = IsValid( owner ) and deathByPly[owner]
        if not died then continue end

        local distSqr = skull:GetPos():DistToSqr( died.pos )
        if distSqr > radiusSqr then continue end
        if nearestDistSqr[owner] and distSqr >= nearestDistSqr[owner] then continue end

        deathSkulls[owner] = skull
        nearestDistSqr[owner] = distSqr

    end
end

local function rebuildDeaths()
    deathByPly = {}
    for _, died in ipairs( potentialResurrectionData ) do
        if IsValid( died.ply ) then
            deathByPly[died.ply] = died

        end
    end

    for ply, standIn in pairs( diedBeforeSync ) do
        if deathByPly[ply] or not IsValid( ply ) or ply:Health() > 0 then
            diedBeforeSync[ply] = nil

        else
            deathByPly[ply] = standIn

        end
    end
end

-- Players are remembered even while we're alive, so the ones who died just before us still score
local function scorePlayers( me, cur )
    local playerScores = {}
    local carriers = flareCarriers()
    for _, ply in player.Iterator() do
        if ply == me then continue end

        if not isDead( ply ) then
            local score = alivePlayerScore( ply, cur, carriers[ply] )
            rememberedScores[ply] = score
            playerScores[ply] = score
            aliveLastPass[ply] = true
            continue

        end

        -- Just died, and the server's death position hasn't arrived yet.
        -- Without a stand in they'd drop out for a pass, and the camera would jerk off them
        if not deathByPly[ply] and aliveLastPass[ply] then
            local standIn = { ply = ply, pos = ply:GetPos(), time = cur }
            diedBeforeSync[ply] = standIn
            deathByPly[ply] = standIn

        end
        aliveLastPass[ply] = nil

        if deathByPly[ply] then
            playerScores[ply] = deadPlayerScore( ply, cur )

        end -- dead without a death position, never played this round
    end

    return playerScores

end

-- nothing real sits at exactly the map origin, it's something we've never been sent a position for
local function atOrigin( ent )
    return ent:GetPos():IsZero()

end

local function addCandidate( ent, score, kind )
    table.insert( candidates, { ent = ent, score = score * tune.kindMuls[kind], kind = kind } )

end

local function gatherCandidates( me, playerScores )
    candidates = {}

    for ply, score in pairs( playerScores ) do
        -- the dead are watched through their remains, not where their body is
        if not isDead( ply ) and atOrigin( ply ) then continue end

        addCandidate( ply, score, "player" )

    end

    local skulls = {}
    for ent, kind in pairs( tracked ) do
        if not IsValid( ent ) or atOrigin( ent ) then continue end

        if kind == "skull" then
            table.insert( skulls, ent )

        elseif ent:GetNW2Bool( "glee_IsHunter" ) and ent:Health() > 0 then -- interloper bots are terminators too
            addCandidate( ent, hunterScore( me, ent ), "hunter" )

        end
    end

    -- before scoring them, a skull's only worth its owner's score if it's from this death
    findDeathSkulls( skulls )
    for _, skull in ipairs( skulls ) do
        addCandidate( skull, skullScore( skull, playerScores ), "skull" )

    end
end

-- the aim point runs every frame, so it only looks through these
local function gatherNearby()
    nearby = {}
    if not IsValid( current ) then return end

    local targetPos = GAMEMODE:WatchAimPosOf( current )
    for _, candidate in ipairs( candidates ) do
        local ent = candidate.ent
        if not IsValid( ent ) then continue end

        local reach = tune.aimRadii[candidate.kind] + tune.nearbySlack
        if ent == current or GAMEMODE:WatchAimPosOf( ent ):Distance( targetPos ) < reach then
            table.insert( nearby, candidate )

        end
    end
end


--[[ Picking ]]

-- The request is only for people, and the server only takes it for someone new.
-- Not while the camera's ramping up, it flies towards them instead, see GM:SpectateWatchingRamp
local function teleportIfFar( me, target )
    if not target:IsPlayer() then return end
    if GAMEMODE:SpectateWatchingRamp() < 1 then return end

    if isDead( target ) then
        local aimPos = GAMEMODE:WatchAimPosOf( target )
        if aimPos:Distance( me:EyePos() ) < tune.teleportBeyond then return end

    elseif not target:IsDormant() then
        return

    end

    if debugging then
        permaPrint( "watching: asked to teleport to", target )

    end

    net.Start( "glee_spectatewatching_teleport" )
    net.WriteEntity( target )
    net.SendToServer()

end

local function pickTarget( me )
    local camPos = me:EyePos()
    local best
    local bestScore = 0

    for _, candidate in ipairs( candidates ) do
        local ent = candidate.ent
        if not IsValid( ent ) then continue end

        local isCurrent = ent == current
        local score = candidate.score
        if isCurrent or canSeeEnt( camPos, ent ) then
            score = score * tune.los

        end
        if isCurrent then
            score = score * tune.commitment

        end

        if score > bestScore then
            best = ent
            bestScore = score

        end

        if debugging then
            local text = candidate.kind .. " " .. math.Round( candidate.score ) .. " -> " .. math.Round( score )
            debugoverlay.Text( GAMEMODE:WatchAimPosOf( ent ), text, tune.interval, false )

        end
    end

    if not best then
        if not IsValid( current ) then current = nil end
        return

    end
    if best == current then return end

    if debugging then
        permaPrint( "watching: switched to", best, "scoring", math.Round( bestScore ) )

    end

    current = best
    teleportIfFar( me, best )

end

hook.Add( "Think", "glee_watchscorer", function()
    local cur = CurTime()
    if nextPass > cur then return end
    nextPass = cur + tune.interval

    local me = LocalPlayer()
    if not IsValid( me ) then return end

    rebuildDeaths()
    local playerScores = scorePlayers( me, cur )

    if not GAMEMODE:IsSpectateWatching() then
        current = nil
        return

    end

    gatherCandidates( me, playerScores )
    pickTarget( me )
    gatherNearby()

end )


--[[ What the camera and HUD read ]]

-- what the camera's watching, nil when there's nothing worth it
function GM:WatchTarget()
    if not IsValid( current ) then return end

    return current

end

-- who the HUD names, a skull from someone's latest death is theirs, older ones are nobody's
function GM:WatchedPerson()
    local target = self:WatchTarget()
    if not target then return end
    if target:GetClass() ~= "termhunt_skull_pickup" then return target end

    local owner = player.GetBySteamID64( target:GetOwnerSteamID64() )
    if IsValid( owner ) and deathSkulls[owner] == target then return owner end

end

-- starting fresh, pick someone on the next Think
function GM:ResetWatchTarget()
    current = nil
    nearby = {}
    nextPass = 0

end

-- whether the camera can see each nearby target, rechecked every aimLosInterval rather than every frame
local aimLos = setmetatable( {}, { __mode = "k" } ) -- entity to { sees, nextCheck }

local function aimSees( camPos, ent, cur )
    local checked = aimLos[ent]
    if not checked then
        -- staggered, so a crowd arriving together doesn't all recheck on the same frame
        checked = { nextCheck = cur + math.Rand( 0, tune.aimLosInterval ) }
        checked.sees = canSeeEnt( camPos, ent )
        aimLos[ent] = checked

    elseif checked.nextCheck <= cur then
        checked.nextCheck = cur + tune.aimLosInterval
        checked.sees = canSeeEnt( camPos, ent )

    end

    return checked.sees

end

-- full pull inside aimFadeFrom, none at the radius, so walking across it doesn't jerk the aim
local function pullFade( dist, radius )
    local fadeFrom = radius * tune.aimFadeFrom
    return math.Clamp( ( radius - dist ) / ( radius - fadeFrom ), 0, 1 )

end

--[[---------------------------------------------------------
    GM:WatchAimPoint
    @desc Where the camera should look this frame, and where the group it's watching is.
        Both are the current target, pulled towards anything interesting nearby.
        Both pull less towards what the camera can't see, someone behind a wall isn't part of what it's watching.
        So both move when the camera does.
    @param target: The current target.
    @param camPos: Where the camera is.
    @return Vector: The aim point.
    @return Vector: The group's spot, move the camera relative to this one.
    @return Vector: The current target's own spot.
    @return Vector: The current target's velocity.
    @return Entity: What the current target's spot is on, see GM:WatchAimPosOf.
    @return boolean: Whether another living player is within companyRadius of the current target.
--]]---------------------------------------------------------
function GM:WatchAimPoint( target, camPos )
    local targetPos, targetVel, targetBody = self:WatchAimPosOf( target )
    local cur = CurTime()

    local aimSum = Vector( 0, 0, 0 )
    local aimWeight = 0
    local groupSum = Vector( 0, 0, 0 )
    local groupWeight = 0
    local hasCompany = false

    for _, candidate in ipairs( nearby ) do
        local ent = candidate.ent
        if not IsValid( ent ) then continue end

        local weight
        local groupsWeight
        local pos
        local seen = true
        if ent == target then
            pos = targetPos
            weight = math.max( candidate.score, 1 ) * tune.currentAimWeight -- 1, so a target scoring nothing still holds the aim
            groupsWeight = weight

        else
            pos = self:WatchAimPosOf( ent )
            local dist = pos:Distance( targetPos )
            local radius = tune.aimRadii[candidate.kind]
            if dist >= radius then continue end

            weight = candidate.score * pullFade( dist, radius )

            local rise = ( pos.z - targetPos.z ) * tune.groupHeightMul
            local groupDist = math.sqrt( pos:Distance2DSqr( targetPos ) + rise * rise )
            groupsWeight = candidate.score * pullFade( groupDist, radius )

            seen = aimSees( camPos, ent, cur )

            if weight > 0 and dist < tune.companyRadius and candidate.kind == "player" and not isDead( ent ) then
                hasCompany = true

            end
        end

        if weight > 0 then
            local aimsWeight = seen and weight or weight * tune.obscuredAimMul
            aimSum:Add( pos * aimsWeight )
            aimWeight = aimWeight + aimsWeight

            if not seen then
                groupsWeight = groupsWeight * tune.obscuredGroupMul

            end
            groupSum:Add( pos * groupsWeight )
            groupWeight = groupWeight + groupsWeight

        end
    end

    local aimPoint = aimWeight > 0 and aimSum / aimWeight or targetPos
    local groupPos = groupWeight > 0 and groupSum / groupWeight or targetPos

    return aimPoint, groupPos, targetPos, targetVel, targetBody, hasCompany

end
