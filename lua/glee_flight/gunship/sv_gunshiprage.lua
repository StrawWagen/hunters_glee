-- spite, and the rage it boils over into
-- a horde with rockets keeps its enemy a rocket, so it never acquires anyone to bomb
-- banked spite, and who it's owed by, lets it hit back anyway
local gunship = terminator_Extras.glee_Gunship

local spiteCfg = gunship.SpiteCfg

-- only players earn a grudge
function gunship.GainSpite( state, rawDamage, attacker )
    state.spite = state.spite + rawDamage
    if not IsValid( attacker ) or not attacker:IsPlayer() then return end

    state.grudges[attacker] = ( state.grudges[attacker] or 0 ) + rawDamage

end

function gunship.SpendSpite( state, amount )
    state.spite = math.max( state.spite - amount, 0 )

end

local function canRageAt( ent )
    if not IsValid( ent ) or ent:Health() <= 0 then return false end
    return not ent:IsPlayer() or ent:Alive()

end

-- weighted by grudge, someone it can see weighs far more
local function pickGrudge( npc, state )
    local myPos = npc:GetPos()
    local candidates = {}
    local totalWeight = 0

    for ply, grudge in pairs( state.grudges ) do
        if not IsValid( ply ) then
            state.grudges[ply] = nil -- they left
            continue

        end
        if not canRageAt( ply ) then continue end

        local weight = grudge
        if not terminator_Extras.PosCanSee( myPos, ply:WorldSpaceCenter(), MASK_SOLID_BRUSHONLY ) then
            weight = weight * spiteCfg.rageUnseenWeight

        end
        totalWeight = totalWeight + weight
        table.insert( candidates, { ply = ply, weight = weight } )

    end

    if totalWeight <= 0 then return end

    local roll = math.Rand( 0, totalWeight )
    for _, candidate in ipairs( candidates ) do
        roll = roll - candidate.weight
        if roll <= 0 then return candidate.ply end

    end
    return candidates[#candidates].ply

end

-- who it's raging at right now, nil while it's calm, or has nobody left to rage at
function gunship.ManageRage( npc, state )
    if state.raging then
        if state.spite < spiteCfg.rageUntil then
            state.raging = false

        end
    elseif state.spite >= spiteCfg.rageAt and npc:Health() < npc:GetMaxHealth() * spiteCfg.rageBelowHealth then
        state.raging = true

    end

    if not state.raging then
        state.rageTarget = nil
        return

    end

    -- lining up a belly cannon shot, switching would lose its sighting, and call the shot off
    local cannonTarget = state.bellyCannon and state.bellyCannon.target
    if canRageAt( cannonTarget ) then
        state.rageTarget = cannonTarget
        return cannonTarget

    end

    local cur = CurTime()
    if not canRageAt( state.rageTarget ) or cur >= state.nextRageReroll then
        state.rageTarget = pickGrudge( npc, state )
        state.nextRageReroll = cur + spiteCfg.rageRerollEvery

    end
    return state.rageTarget

end
