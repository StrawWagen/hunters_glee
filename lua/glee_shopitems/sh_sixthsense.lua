
local shopHelpers = GAMEMODE.shopHelpers
local entMeta = FindMetaTable( "Entity" )

-- sense rules, how the sixth sense reacts to things. an entity takes the first rule that matches it, checking
--   its override, a client only rule name, eg a doppelganger we've seen through
--   then its tag, a rule name the server networks, set when gameplay hooks announce what something became
--   then rules listing its class, in the order they're added
--   then rules with matches but no classes, in the order they're added
--
-- matching, a rule with neither is only reached by tag or override
-- classes = list of classes it's for
-- matches = fn( ent ), narrows it within its classes, or without classes, is checked against everything
--
-- reacting
-- type   = SENSE_ constant, or fn( ent, owner, dist ) returning one, nil if it's not sensed right now
-- size   = number, or fn( ent, owner, dist ) returning one, before closeness growth
-- growsWithin, growth, falloff = optional, size grows up to size * ( 1 + growth ) as dist goes from growsWithin to 0
--   growsWithin can be fn( ent, owner, dist ), nil to not grow
-- growthJitter = optional, blob jitter added per unit of that growth
-- blobRange = optional, number or fn( ent, owner, dist ), how far away its blob shows, defaultBlobRange if nil
-- think  = optional, client only, fn( ent, owner, dist ), runs every resort, can set ent.glee_senseRuleOverride

local SENSE_LOOT = 1
local SENSE_FRIENDLY = 2
local SENSE_HAZARD = 3
local SENSE_HOSTILE = 4

local senseColors = {
    [SENSE_LOOT] = Color( 0, 255, 0 ),
    [SENSE_FRIENDLY] = Color( 0, 0, 255 ),
    [SENSE_HAZARD] = Color( 255, 0, 0 ),
    [SENSE_HOSTILE] = Color( 255, 0, 0 ),
}

local maxDistance = 8000
local defaultBlobRange = 1250
local threatBlobRange = 2500

local threatGrowsWithin = 1250
local threatGrowth = 26
local threatFalloff = 1.16
local threatGrowthJitter = 1 / 18

-- paths need you to stop and pay attention, anything faster than a walk drowns them out
local walkSpeedTolerance = 1.1 -- walking can overshoot WalkSpeed a hair

local function isMovingTooFast( owner )
    return owner:GetVelocity():Length2DSqr() > ( owner:GetWalkSpeed() * walkSpeedTolerance ) ^ 2

end

local rulesByName = {}
local rulesByClass = {}
local classlessRules = {}

local senseTagNW = "glee_senseRule"

local function addSenseRule( name, rule )
    rule.name = name
    rulesByName[name] = rule

    if not rule.classes then
        if rule.matches then
            classlessRules[#classlessRules + 1] = rule

        end
        return

    end
    for _, class in ipairs( rule.classes ) do
        local classRules = rulesByClass[class] or {}
        rulesByClass[class] = classRules
        classRules[#classRules + 1] = rule

    end
end

local function firstMatching( rules, ent )
    if not rules then return end
    for _, rule in ipairs( rules ) do
        if not rule.matches or rule.matches( ent ) then return rule end

    end
end

local function findSenseRule( ent, entsTbl )
    local override = entsTbl.glee_senseRuleOverride
    if override then return rulesByName[override] end

    local tag = entMeta.GetNW2String( ent, senseTagNW, "" )
    if tag ~= "" then return rulesByName[tag] end

    return firstMatching( rulesByClass[entMeta.GetClass( ent )], ent ) or firstMatching( classlessRules, ent )

end

-- gameplay hooks announce what things became, these tag them with the rule for it
if SERVER then
    local function tagHook( hookName, ruleFor )
        hook.Add( hookName, "glee_sixthsense_tag", function( ent, ... )
            local ruleName = ruleFor( ent, ... )
            if not ruleName then return end
            ent:SetNW2String( senseTagNW, ruleName )

        end )
    end

    tagHook( "huntersglee_gas_becamegas", function() return "gas" end )

    local rulesForCrateKinds = {} -- eg screamer = "screamer_crate", kinds without one fall back to the item_item_crate class rule
    tagHook( "huntersglee_crate_becamecrate", function( _crate, kind ) return rulesForCrateKinds[kind] end )

end

local function resolveField( field, ent, owner, dist )
    if isfunction( field ) then return field( ent, owner, dist ) end
    return field

end

-- returns the final size, and the size before closeness growth
local function getSensedSize( rule, ent, owner, dist )
    local size = resolveField( rule.size, ent, owner, dist )
    local growsWithin = resolveField( rule.growsWithin, ent, owner, dist )
    if not growsWithin then return size, size end

    local closeness = math.max( 1 - dist / growsWithin, 0 )
    return size * ( 1 + closeness ^ rule.falloff * rule.growth ), size

end

local function ammoFor( weaponClass )
    return function( _ent, owner )
        if not owner:HasWeapon( weaponClass ) then return end
        return SENSE_LOOT

    end
end

local function aliveFriendly( ent )
    if ent:Health() <= 0 then return end
    return SENSE_FRIENDLY

end

local function isChosen( ply )
    return ply:HasStatusEffect( "divine_chosen" )

end

-- grigori can't escape
local function escapeFriendly( _ent, owner )
    if isChosen( owner ) then return end
    return SENSE_FRIENDLY

end


-- loot

addSenseRule( "medkit", {
    classes = { "item_healthkit", "item_healthvial" },
    type = function( _ent, owner )
        if owner:Health() >= owner:GetMaxHealth() then return end
        return SENSE_LOOT

    end,
    size = 50,
} )

addSenseRule( "battery", {
    classes = { "item_battery" },
    type = function( _ent, owner )
        if owner:Armor() >= owner:GetMaxArmor() then return end
        return SENSE_LOOT

    end,
    size = 50,
} )

addSenseRule( "ar2_balls", { classes = { "item_ammo_ar2_altfire" }, type = ammoFor( "weapon_ar2" ), size = 50 } )
addSenseRule( "smg_grenades", { classes = { "item_ammo_smg1_grenade" }, type = ammoFor( "weapon_smg1" ), size = 50 } )
addSenseRule( "rpg_rounds", { classes = { "item_rpg_round" }, type = ammoFor( "weapon_rpg" ), size = 50 } )

addSenseRule( "pickup", {
    classes = { "termhunt_skull_pickup", "termhunt_score_pickup", "item_item_crate" },
    type = SENSE_LOOT,
    size = 50,
} )

addSenseRule( "gas", { type = SENSE_LOOT, size = 50 } ) -- tagged

addSenseRule( "atm", {
    classes = { "glee_bank_atm" },
    type = SENSE_LOOT,
    size = 200,
    blobRange = threatBlobRange,
} )

addSenseRule( "escape_flare_gun", {
    classes = { "termhunt_aeromatix_signalflare_gun" },
    type = escapeFriendly,
    size = 100,
} )

addSenseRule( "rescue_heli", {
    classes = { "npc_helicopter" },
    matches = function( ent ) return ent:GetNWBool( "isGleeRescueHeli", false ) end,
    type = escapeFriendly,
    size = 300,
    blobRange = 5000,
} )


-- hazards

addSenseRule( "trap", {
    classes = { "termhunt_bear_trap", "npc_tripmine", "glee_sticky_slam" },
    type = function( _ent, _owner, dist )
        if dist > 1000 then return end
        return SENSE_HAZARD

    end,
    size = 50,
    growsWithin = 1000,
    growth = 12,
    falloff = 1.04,
} )


-- people

-- before "player", so it's matched first
addSenseRule( "grigori", {
    classes = { "player" },
    matches = isChosen,
    type = function( ent, owner )
        if ent:Health() <= 0 then return end
        if isChosen( owner ) then return SENSE_FRIENDLY end
        return SENSE_HOSTILE

    end,
    size = function( ent, owner )
        if isChosen( owner ) then return 100 end
        return 150 * GAMEMODE:GetBotScaryness( owner, ent )

    end,
    growsWithin = function( _ent, owner )
        if isChosen( owner ) then return end
        return threatGrowsWithin

    end,
    growth = threatGrowth,
    falloff = threatFalloff,
    growthJitter = threatGrowthJitter,
    blobRange = function( _ent, owner )
        if isChosen( owner ) then return defaultBlobRange end
        return threatBlobRange

    end,
} )

addSenseRule( "player", {
    classes = { "player" },
    type = aliveFriendly,
    size = 100,
} )

addSenseRule( "disguised", {
    classes = { "terminator_nextbot_snail_disguised" },
    -- reveals are per client, and the server never thinks, so it always paths to it as a player
    think = function( _ent, entsTbl, _owner, dist )
        if math.random( 0, 300 ) < dist then return end
        entsTbl.glee_senseRuleOverride = "hunter"

    end,
    type = aliveFriendly,
    size = 100,
} )


-- no classes, checked against everything without a tag or class rule

addSenseRule( "hunter", {
    matches = function( ent ) return string.StartsWith( ent:GetClass(), "terminator_nextbot" ) end,
    type = function( ent )
        if ent:Health() <= 0 then return end
        return SENSE_HOSTILE

    end,
    size = function( ent, owner )
        return 150 * GAMEMODE:GetBotScaryness( owner, ent ) -- bigger when we're low health, smaller when they're weak

    end,
    growsWithin = threatGrowsWithin,
    growth = threatGrowth,
    falloff = threatFalloff,
    growthJitter = threatGrowthJitter,
    blobRange = threatBlobRange,
} )

addSenseRule( "ground_weapon", {
    matches = function( ent ) return ent:IsWeapon() end,
    type = function( ent, owner )
        if IsValid( ent:GetOwner() ) then return end
        if owner:HasWeapon( ent:GetClass() ) then return end
        return SENSE_LOOT

    end,
    size = 50,
} )


-- sixth sense stuff
if CLIENT then
    local LocalPlayer   = LocalPlayer
    local CurTime       = CurTime
    local IsValid       = IsValid
    local VectorRand    = VectorRand

    local maxBlobs = 35

    -- each type gets its own shapes, not just its own colour, so they read apart without telling colours apart
    -- blobs are layers, drawn in order. strandWidth scales the width a strand gets from its target's size
    local threatStyle = {
        strand = Material( "hunters_glee/sixth_sense/strand_threat" ),
        strandWidth = 3,
        blob = {
            Material( "hunters_glee/sixth_sense/blob_threat" ),
            Material( "hunters_glee/sixth_sense/blob_threat_spikes" ),
        },
    }
    local senseStyles = {
        [SENSE_LOOT] = {
            strand = Material( "hunters_glee/sixth_sense/strand_loot" ),
            strandWidth = 1,
            blob = { Material( "hunters_glee/sixth_sense/blob_loot" ) },
        },
        [SENSE_FRIENDLY] = {
            strand = Material( "hunters_glee/sixth_sense/strand_friendly" ),
            strandWidth = 5,
            blob = { Material( "hunters_glee/sixth_sense/blob_friendly" ) },
        },
        [SENSE_HAZARD] = threatStyle,
        [SENSE_HOSTILE] = threatStyle,
    }

    local function collectSensable( owner )
        local found = {}
        for _, ent in ents.Iterator() do
            if ent == owner then continue end
            local entsTbl = entMeta.GetTable( ent )
            if not findSenseRule( ent, entsTbl ) then continue end
            found[#found + 1] = ent

        end
        return found

    end

    -- rules with a think get to change the entity's rule before it's picked
    local function resolveSenseRules( owner, sensable )
        local myPos = owner:GetPos()
        local rules = {}
        for _, ent in ipairs( sensable ) do
            local entsTbl = entMeta.GetTable( ent )
            local rule = findSenseRule( ent, entsTbl )
            if rule and rule.think then
                rule.think( ent, entsTbl, owner, ent:GetPos():Distance( myPos ) )
                rule = findSenseRule( ent, entsTbl )

            end
            rules[ent] = rule

        end
        return rules

    end

    local function sortForClosestTo( sortPos, stuffToSort )
        local valid = {}
        local distSqrs = {}
        for _, ent in ipairs( stuffToSort ) do
            if not IsValid( ent ) then continue end
            valid[#valid + 1] = ent
            distSqrs[ent] = ent:GetPos():DistToSqr( sortPos )

        end
        table.sort( valid, function( a, b ) return distSqrs[a] < distSqrs[b] end )
        return valid

    end

    local strandSubdivisions = 4
    -- must outlast the longest gap between updates to one target, server's pathRefreshMax + maxPaths * pathSendDelayMax, or live strands dim
    local strandFadeDelay = 4.5
    local strandFadeDuration = 1.5
    local strandSnapDuration = 0.8
    local strandGrowDuration = 1.2 -- new strands creep out to full length over this
    local strandGrowEdge = 150 -- how soft the creeping tip is
    local strandAttentionLoseTime = 0.25 -- seconds for strands to fade out once we move too fast
    local strandAttentionGainTime = 1 -- and to fade back in once we slow down

    -- wisp shape, all distances in units along the path
    local wispSpacing = 32
    local wispAlpha = 1
    local wispVariance = 0.25 -- each strand's wavelength and drift speed is randomized by up to this fraction, so they don't move in lockstep
    local wispFadeIn = 64 -- so it doesn't start inside our chest
    local wispPinBlend = 200 -- how far down the path our movement since the server built it bleeds
    local wispWaveLength = 350
    local wispWaveAmp = 18
    local wispSpread = 60 -- extra sway at the far end, scent dispersing
    local wispRise = 40 -- drifts up by this much at the far end
    local wispDriftSpeed = 0.6 -- waves travel along the path at wispWaveLength * this, per second
    local wispTexLength = 256

    local upVec = Vector( 0, 0, 1 )
    local wispPos = Vector()

    local function catmullRom( p0, p1, p2, p3, t )
        local t2 = t * t
        local t3 = t2 * t
        return 0.5 * ( ( 2 * p1 ) + ( p2 - p0 ) * t + ( 2 * p0 - 5 * p1 + 4 * p2 - p3 ) * t2 + ( 3 * p1 - p0 - 3 * p2 + p3 ) * t3 )

    end

    local function smoothPoints( points )
        local count = #points
        local smoothed = {}
        for i = 1, count - 1 do
            local p0 = points[math.max( i - 1, 1 )]
            local p1 = points[i]
            local p2 = points[i + 1]
            local p3 = points[math.min( i + 2, count )]
            for sub = 0, strandSubdivisions - 1 do
                smoothed[#smoothed + 1] = catmullRom( p0, p1, p2, p3, sub / strandSubdivisions )

            end
        end
        smoothed[#smoothed + 1] = points[count]
        return smoothed

    end

    -- evenly spaced points, so long straights get as many waves as corners do
    -- each point also gets its distance along the path, and a horizontal side vector to sway along
    local function resamplePath( smoothed )
        local resampled = { { pos = smoothed[1], dist = 0 } }
        local travelled = 0
        local nextAt = wispSpacing
        for i = 2, #smoothed do
            local from = smoothed[i - 1]
            local to = smoothed[i]
            local segLength = from:Distance( to )
            while segLength > 0 and travelled + segLength >= nextAt do
                local fraction = ( nextAt - travelled ) / segLength
                resampled[#resampled + 1] = { pos = LerpVector( fraction, from, to ), dist = nextAt }
                nextAt = nextAt + wispSpacing

            end
            travelled = travelled + segLength

        end
        resampled[#resampled + 1] = { pos = smoothed[#smoothed], dist = travelled }

        for i, point in ipairs( resampled ) do
            local tangent = resampled[math.min( i + 1, #resampled )].pos - resampled[math.max( i - 1, 1 )].pos
            local side = tangent:Cross( upVec )
            if side:IsZero() then side = Vector( 1, 0, 0 ) end
            side:Normalize()
            point.side = side

        end
        return resampled, travelled

    end

    -- relies on resamplePath spacing every point but the last wispSpacing apart
    local function samplePathAt( points, dist )
        local count = #points
        local index = math.floor( dist / wispSpacing ) + 1
        if index >= count then return points[count].pos:Unpack() end

        local from = points[index]
        local to = points[index + 1]
        local span = to.dist - from.dist
        local fraction = span > 0 and math.Clamp( ( dist - from.dist ) / span, 0, 1 ) or 0
        local fromPos = from.pos
        local toPos = to.pos
        return Lerp( fraction, fromPos.x, toPos.x ), Lerp( fraction, fromPos.y, toPos.y ), Lerp( fraction, fromPos.z, toPos.z )

    end

    net.Receive( "glee_sixthsense_paths", function()
        local effect = LocalPlayer():GetStatusEffect( "sixth_sense" )
        if not effect then return end

        local entIndex = net.ReadUInt( MAX_EDICT_BITS )
        local path = {
            ent = Entity( entIndex ),
            senseType = net.ReadUInt( 3 ),
            size = net.ReadFloat(),
        }
        local points = {}
        for i = 1, net.ReadUInt( 6 ) do
            points[i] = net.ReadVector()

        end
        if #points < 2 then return end

        path.builtFrom = points[1]
        path.points, path.length = resamplePath( smoothPoints( points ) )
        if path.length <= 0 then return end

        -- seeded by the target, so a strand keeps its rhythm across refreshes instead of jumping
        local seed = ( entIndex * 0.618034 ) % 1 -- golden ratio, neighbouring indexes land far apart
        path.phase = seed * math.pi * 2
        path.waveLength = wispWaveLength * ( 1 + ( seed - 0.5 ) * 2 * wispVariance )
        path.driftSpeed = wispDriftSpeed * ( 1 + ( 0.5 - seed ) * 2 * wispVariance )

        -- snap from the old shape. if the old one was still snapping itself, it jumps to where it was headed
        local previous = effect.strands[entIndex]
        if previous then
            previous.previous = nil
            path.previous = previous
            path.appeared = previous.appeared -- so an update mid-growth doesn't restart it

        else
            path.appeared = CurTime()

        end
        path.received = CurTime()
        effect.strands[entIndex] = path

    end )

    local strandColor = Color( 255, 255, 255, 255 )

    local function drawStrand( path, startPos, curTime, staleness )
        local points = path.points
        local length = path.length

        local previous = path.previous
        local snap = 1
        if previous then
            snap = math.Clamp( ( curTime - path.received ) / strandSnapDuration, 0, 1 )
            snap = snap * snap * ( 3 - 2 * snap )
            if snap >= 1 then
                path.previous = nil
                previous = nil

            end
        end

        local senseColor = senseColors[path.senseType]
        local style = senseStyles[path.senseType]
        render.SetMaterial( style.strand )

        local baseWidth = ( 2 + math.sqrt( path.size ) * 0.6 ) * 0.5 * style.strandWidth
        local wispSeed = path.phase
        local waveLength = path.waveLength

        -- scent from loot drifts away from us, threats drift toward us
        local flowsToward = path.senseType == SENSE_HOSTILE or path.senseType == SENSE_HAZARD
        local drift = curTime * path.driftSpeed * math.pi * 2
        if flowsToward then drift = -drift end

        -- new strands creep out from us
        local grow = math.Clamp( ( curTime - path.appeared ) / strandGrowDuration, 0, 1 )
        local reach = ( 1 - ( 1 - grow ) ^ 2 ) * ( length + strandGrowEdge )

        local pinX, pinY, pinZ = ( startPos - path.builtFrom ):Unpack()
        local oldPinX, oldPinY, oldPinZ
        if previous then
            oldPinX, oldPinY, oldPinZ = ( startPos - previous.builtFrom ):Unpack()

        end

        render.StartBeam( #points )
        for _, point in ipairs( points ) do
            local dist = point.dist
            local along = dist / length
            local spread = along * along * wispSpread
            local fadeIn = math.min( dist / wispFadeIn, 1 )

            local phase = dist / waveLength * math.pi * 2 - drift + wispSeed
            local sway = math.sin( phase ) * ( wispWaveAmp + spread ) * fadeIn
            local rise = along * wispRise + math.sin( phase * 0.7 + wispSeed ) * spread * 0.5
            local pinWeight = math.max( 1 - dist / wispPinBlend, 0 )

            local pos = point.pos
            local x = pos.x + pinX * pinWeight
            local y = pos.y + pinY * pinWeight
            local z = pos.z + pinZ * pinWeight
            if previous then
                local oldX, oldY, oldZ = samplePathAt( previous.points, dist )
                x = Lerp( snap, oldX + oldPinX * pinWeight, x )
                y = Lerp( snap, oldY + oldPinY * pinWeight, y )
                z = Lerp( snap, oldZ + oldPinZ * pinWeight, z )

            end

            local side = point.side
            wispPos:SetUnpacked( x + side.x * sway, y + side.y * sway, z + rise )

            local grown = math.Clamp( ( reach - dist ) / strandGrowEdge, 0, 1 )

            local brightness = ( 1 - along ) * fadeIn * grown * ( 1 - staleness ) * wispAlpha
            strandColor.r = senseColor.r * brightness
            strandColor.g = senseColor.g * brightness
            strandColor.b = senseColor.b * brightness
            strandColor.a = 255 * brightness

            local width = baseWidth * ( 0.6 + along * 1.4 ) * grown
            render.AddBeam( wispPos, width, dist / wispTexLength - drift * 0.05, strandColor )

        end
        render.EndBeam()

    end

    GAMEMODE:RegisterStatusEffect( "sixth_sense",
        function( self, owner ) -- setup func
            if LocalPlayer() ~= owner then return end

            self.strands = {} -- by target ent index
            self.attention = 0

            self:Hook( "PostDrawTranslucentRenderables", function( depth, skybox )
                if depth or skybox then return end
                if owner:Health() <= 0 then return end

                if isMovingTooFast( owner ) then
                    self.attention = math.max( self.attention - FrameTime() / strandAttentionLoseTime, 0 )
                    if self.attention <= 0 then
                        table.Empty( self.strands ) -- built from where we used to be, wait for fresh ones

                    end
                else
                    self.attention = math.min( self.attention + FrameTime() / strandAttentionGainTime, 1 )

                end
                local attention = self.attention
                if attention <= 0 then return end

                local curTime = CurTime()
                local startPos = owner:WorldSpaceCenter()
                for entIndex, path in pairs( self.strands ) do
                    local staleness = math.Clamp( ( curTime - path.received - strandFadeDelay ) / strandFadeDuration, 0, 1 )
                    if staleness >= 1 then
                        self.strands[entIndex] = nil
                        continue

                    end
                    drawStrand( path, startPos, curTime, 1 - ( 1 - staleness ) * attention )

                end
            end )

            self.sensable = {}
            self.sensedRules = {}
            self.nextCollect = 0
            self.nextSort = 0

            local sharedColor = Color( 255, 255, 255, 255 )

            self:Hook( "HUDPaint", function()
                if entMeta.Health( owner ) <= 0 then return end

                local curTime = CurTime()

                if self.nextCollect < curTime then
                    self.nextCollect = curTime + 2
                    self.sensable = collectSensable( owner )

                end
                if self.nextSort < curTime then
                    self.nextSort = curTime + 0.5
                    self.sensable = sortForClosestTo( owner:GetPos(), self.sensable )
                    self.sensedRules = resolveSenseRules( owner, self.sensable )

                end

                local myPos = owner:GetShootPos()
                local shown = 0
                local sensedRules = self.sensedRules

                -- every sensable ent on the map, every frame, keep ent access off Entity __index
                for _, sensed in ipairs( self.sensable ) do -- put the blobs on stuff!
                    if shown >= maxBlobs then return end
                    local rule = sensedRules[sensed]
                    if not rule then continue end
                    if not IsValid( sensed ) then continue end

                    local sensedsTbl = entMeta.GetTable( sensed )
                    local sensedPos = entMeta.WorldSpaceCenter( sensed )
                    local distance = sensedPos:Distance( myPos )

                    -- before the range cull, so lastRealSeen stays fresh for things out of range
                    local unknownAlphaBite = 0 -- make stuff have less alpha when we dont see it for a while
                    local oldPos = sensedsTbl.sixthSenseOldPos or sensedPos
                    local randomScale = distance / 50
                    if entMeta.IsDormant( sensed ) or ( sensedsTbl.IsHomeless and not entMeta.IsSolid( sensed ) ) then
                        sensedsTbl.glee_sixthsense_wasdormant = true
                        sensedPos = oldPos
                        randomScale = randomScale * 0.75

                        local lastRealSeen = sensedsTbl.glee_sixthsense_lastRealSeen or 0
                        if lastRealSeen ~= 0 then
                            local timeSinceLastSeen = curTime - lastRealSeen
                            unknownAlphaBite = timeSinceLastSeen / 45

                        end
                    else
                        sensedsTbl.glee_sixthsense_lastRealSeen = curTime
                        if sensedsTbl.glee_sixthsense_wasdormant then
                            sensedsTbl.glee_sixthsense_wasdormant = nil
                            sensedsTbl.glee_senseRuleOverride = nil

                        end
                    end

                    -- range first, type funcs can be pricey and blobRange never depends on the type
                    local blobRange = resolveField( rule.blobRange, sensed, owner, distance ) or defaultBlobRange
                    if distance > blobRange then continue end

                    local senseType = resolveField( rule.type, sensed, owner, distance )
                    if not senseType then continue end

                    local spriteSize, baseSize = getSensedSize( rule, sensed, owner, distance )
                    randomScale = randomScale + ( spriteSize - baseSize ) * ( rule.growthJitter or 0 )

                    -- handle the pos smoothing and randomization
                    local newPos = sensedPos + ( VectorRand() * randomScale )
                    local posSmoothed = ( newPos * 0.08 ) + ( oldPos * 0.92 )
                    sensedsTbl.sixthSenseOldPos = posSmoothed

                    local pos2d = posSmoothed:ToScreen()
                    -- clamped, SetDrawColor wraps past 255, so overbright fades back in from black
                    local opaqueWhenClose = math.Clamp( ( 1 - distance / blobRange ) * 2 - unknownAlphaBite, 0, 1 )
                    local senseColor = senseColors[senseType]

                    sharedColor.r = senseColor.r * opaqueWhenClose
                    sharedColor.g = senseColor.g * opaqueWhenClose
                    sharedColor.b = senseColor.b * opaqueWhenClose

                    local rotation = ( entMeta.EntIndex( sensed ) * 0.618034 ) % 1 * 360 -- golden ratio, neighbouring indexes land far apart

                    surface.SetDrawColor( sharedColor )
                    for _, layer in ipairs( senseStyles[senseType].blob ) do
                        surface.SetMaterial( layer )
                        surface.DrawTexturedRectRotated( pos2d.x, pos2d.y, spriteSize, spriteSize, rotation )

                    end

                    shown = shown + 1

                end
            end )
        end
    )

end
if SERVER then
    util.AddNetworkString( "glee_sixthsense_paths" )

    local Astar = terminator_Extras.Astar
    local PosCanSee = terminator_Extras.PosCanSee

    -- randomized so strands don't all update in sync, client's strandFadeDelay must outlast the longest gap these allow
    local pathRefreshMin = 1
    local pathRefreshMax = 2
    local pathSendDelayMax = 0.5 -- after each path is sent

    local maxPaths = 4
    local maxNetPoints = 63 -- networked in 6 bits
    local shownPathLength = 1600
    local hoverOffset = Vector( 0, 0, 48 )
    local eyePullRangeSqr = 3000^2
    local pathingBudget = 0.0005 -- seconds per tick, per sixth senser

    local pathingSearchTbl = {
        MaxPathingIterations = 4000, -- when it runs out, Astar returns the path that got closest
    }

    local pathingLocoData = {
        canUseLadders = true,
        jumpHeight = 500, -- way past a crouch jump, scent doesn't care if you can make the climb
        deathDropHeight = 400,
    }

    local function pathCost( _owner, locoData, toArea, fromArea, ladder, connDist )
        if IsValid( ladder ) then return ladder:GetLength() * 1.5 + 200 end

        local heightChange = fromArea:ComputeAdjacentConnectionHeightChange( toArea )
        if heightChange > locoData.jumpHeight then return -1 end
        if -heightChange > locoData.deathDropHeight then return -1 end

        return connDist

    end

    local function collectSensed( owner )
        local myPos = owner:GetPos()
        local sensed = {}

        for _, ent in ents.Iterator() do
            if ent == owner then continue end

            local dist = ent:GetPos():Distance( myPos )
            if dist > maxDistance then continue end

            local entsTbl = entMeta.GetTable( ent )

            local rule = findSenseRule( ent, entsTbl )
            if not rule then continue end

            local senseType = resolveField( rule.type, ent, owner, dist )
            if not senseType then continue end

            local size = getSensedSize( rule, ent, owner, dist )
            sensed[#sensed + 1] = {
                ent = ent,
                senseType = senseType,
                size = size,
                priority = size * ( 1 - dist / maxDistance ),
            }
        end

        table.sort( sensed, function( a, b ) return a.priority > b.priority end )
        return sensed

    end

    local function corridorToPoints( corridor, startPos )
        local points = {}
        local prev = startPos
        for _, area in ipairs( corridor ) do
            if not IsValid( area ) then return end
            prev = area:GetClosestPointOnArea( prev )
            points[#points + 1] = prev + hoverOffset

        end
        return points

    end

    -- starts the path at the furthest point the owner can see, so from a vantage point it points off into the distance, not down the way off the vantage
    local function pullFromEyes( owner, points )
        local eyePos = owner:GetShootPos()
        local furthestSeen = 0
        for i, point in ipairs( points ) do
            if point:DistToSqr( eyePos ) > eyePullRangeSqr then continue end
            if i % 8 == 0 then coroutine.yield() end
            if not PosCanSee( eyePos, point, MASK_SOLID_BRUSHONLY ) then continue end
            furthestSeen = i

        end

        local pulled = { owner:WorldSpaceCenter() }
        for i = math.max( furthestSeen, 1 ), #points do
            pulled[#pulled + 1] = points[i]

        end
        return pulled

    end

    local function trimToLength( points, maxLength )
        local trimmed = { points[1] }
        local length = 0
        for i = 2, #points do
            local from = points[i - 1]
            local to = points[i]
            local segLength = from:Distance( to )
            if length + segLength >= maxLength then
                local fraction = ( maxLength - length ) / segLength
                trimmed[#trimmed + 1] = LerpVector( fraction, from, to )
                break

            end
            length = length + segLength
            trimmed[#trimmed + 1] = to

        end
        return trimmed

    end

    local function debugDrawPath( path )
        local color = senseColors[path.senseType]
        local points = path.points
        for i = 2, #points do
            debugoverlay.Line( points[i - 1], points[i], pathRefreshMax, color, true )

        end
    end

    -- one pass, builds paths to the most important stuff we sense, calling onPathBuilt( path ) as each finishes
    local function buildSensePaths( owner, onPathBuilt )
        local sensed = collectSensed( owner )
        for i = 1, math.min( maxPaths, #sensed ) do
            local target = sensed[i]
            local ent = target.ent
            if not IsValid( ent ) then continue end
            if not IsValid( owner ) then return end
            if isMovingTooFast( owner ) then return end

            -- onPathBuilt can wait a while, so start from wherever we are now
            local startArea = navmesh.GetNearestNavArea( owner:GetPos(), false, 200, false, true )
            if not IsValid( startArea ) then return end

            local goal = ent:GetPos()
            local goalArea = navmesh.GetNearestNavArea( goal, false, 200, false, true )
            if not IsValid( goalArea ) then continue end

            local _, corridor = Astar( owner, pathingSearchTbl, startArea, goal, goalArea, pathCost, pathingLocoData )
            if not corridor then continue end

            local points = corridorToPoints( corridor, owner:GetPos() )
            if not points then continue end

            if not IsValid( owner ) then return end
            points = pullFromEyes( owner, points )
            points = trimToLength( points, shownPathLength )

            local path = {
                ent = ent,
                senseType = target.senseType,
                size = target.size,
                points = points,
            }
            debugDrawPath( path )
            onPathBuilt( path )

        end
    end

    local function sendSensePath( owner, path )
        local ent = path.ent
        if not IsValid( ent ) then return end

        net.Start( "glee_sixthsense_paths" )
        -- the index, not the entity, the client needs it even when the entity is outside their PVS
        net.WriteUInt( ent:EntIndex(), MAX_EDICT_BITS )
        net.WriteUInt( path.senseType, 3 )
        net.WriteFloat( path.size )

        local points = path.points
        local count = math.min( #points, maxNetPoints )
        net.WriteUInt( count, 6 )
        for i = 1, count do
            net.WriteVector( points[i] )

        end
        net.Send( owner )

    end

    GAMEMODE:RegisterStatusEffect( "sixth_sense",
        function( self, owner ) -- setup func
            self:Hook( "terminator_spotenemy", function( term, spotted ) -- play arresting sound when an enemy spots us
                if spotted ~= owner then return end

                local nextSound = self.glee_nextSixthSenseSpottedSound or 0
                if nextSound > CurTime() then return end

                local scaryness = GAMEMODE:GetBotScaryness( owner, term )
                if scaryness < 0.7 then return end -- not scary, zzzzzzzzz

                self.glee_nextSixthSenseSpottedSound = CurTime() + 30

                local distance = owner:GetPos():Distance( term:GetPos() )

                if distance > 800 * scaryness then
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 140, 0.7, CHAN_STATIC )
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 180, 0.5, CHAN_STATIC )
                    GAMEMODE:GivePanic( owner, 30 * scaryness )

                else
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 100, 0.7, CHAN_STATIC )
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 40, 0.5, CHAN_STATIC )
                    GAMEMODE:GivePanic( owner, 60 * scaryness )

                end
            end )

            self:Hook( "terminator_enemythink", function( term, theThingWhoIsEnemy ) -- give panic when an enemy has its eyes on us
                if theThingWhoIsEnemy ~= owner then return end

                local nextSixthSenseTrackingPanic = self.glee_nextSixthSenseTrackingPanic or 0
                if nextSixthSenseTrackingPanic > CurTime() then return end

                -- dont do like a billion of these events
                self.glee_nextSixthSenseTrackingPanic = CurTime() + 1
                local distance = term:GetPos():Distance( owner:GetPos() )
                local scaryness = GAMEMODE:GetBotScaryness( owner, term )

                -- extra scary if very very close
                if scaryness >= 0.7 and distance < 350 then
                    GAMEMODE:GivePanic( owner, 100 * scaryness )

                end

                -- scary if close
                if distance < 500 then
                    GAMEMODE:GivePanic( owner, 12 * scaryness )

                -- if they have LOS on us, or are nearby
                elseif distance < 1000 or term.IsSeeEnemy then
                    GAMEMODE:GivePanic( owner, 8 * scaryness )

                end
            end )

            self.nextPathRefresh = 0
            self.pathingWakeAt = 0

            -- only call from inside pathingCor, the Think below won't resume it until the time's up
            local function sleep( seconds )
                self.pathingWakeAt = CurTime() + seconds
                coroutine.yield()

            end

            local function onPathBuilt( path )
                if not IsValid( owner ) then return end
                if isMovingTooFast( owner ) then return end -- went stale while it was building
                sendSensePath( owner, path )
                sleep( math.Rand( 0, pathSendDelayMax ) )

            end

            self:Hook( "Think", function()
                local curTime = CurTime()
                local pathingCor = self.pathingCor
                if not pathingCor then
                    if owner:Health() <= 0 then return end
                    if isMovingTooFast( owner ) then
                        self.nextPathRefresh = 0 -- fresh paths the moment we slow down
                        return

                    end
                    if self.nextPathRefresh > curTime then return end

                    pathingCor = coroutine.create( function()
                        buildSensePaths( owner, onPathBuilt )
                        self.nextPathRefresh = CurTime() + math.Rand( pathRefreshMin, pathRefreshMax )

                    end )
                    self.pathingCor = pathingCor

                end
                if self.pathingWakeAt > curTime then return end

                local startTime = SysTime()
                while SysTime() - startTime < pathingBudget do
                    local ok, err = coroutine.resume( pathingCor )
                    if not ok then
                        ErrorNoHalt( debug.traceback( pathingCor, err ) .. "\n" )
                        self.nextPathRefresh = curTime + pathRefreshMax

                    end
                    if coroutine.status( pathingCor ) == "dead" then
                        self.pathingCor = nil
                        break

                    end
                    if self.pathingWakeAt > curTime then break end

                end
            end )
        end
    )
end

local items = {
    ["sixthsense"] = {
        name = "Sixth Sense.",
        desc = "You gain a sixth sense.\nYou innately know where things are.\nBut the sixth sense can be overwhelming.\nPanic will mount as the hunters close in.",
        shCost = 225,
        markup = 2,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Essential", },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "sixth_sense" )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )
