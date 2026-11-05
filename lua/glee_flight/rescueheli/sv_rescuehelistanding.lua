-- who the heli rescues, ignores, hates, and fights alongside
local rescueHeli = terminator_Extras.glee_RescueHeli

local function makeHeliFriendlyWith( heli, thing )
    if not IsValid( heli ) then return end
    if not IsValid( thing ) then return end
    heli:AddEntityRelationship( thing, D_LI, 99 )

end

function rescueHeli.MakeFeudWith( heli, thing )
    if not IsValid( heli ) then return end
    if not IsValid( thing ) then return end
    heli:AddEntityRelationship( thing, D_HT, 99 )
    if not thing.AddEntityRelationship then return end
    thing:AddEntityRelationship( heli, D_HT, 999 )

end

-- the spawnmenu's Resistance Turret, which the shop's is, out of a class we otherwise hate
local function isResistanceTurret( ent )
    return ent:GetClass() == "npc_turret_floor" and ent:HasSpawnFlags( SF_FLOOR_TURRET_CITIZEN )

end

local function makeAlliesWith( heli, thing )
    makeHeliFriendlyWith( heli, thing )
    thing:AddEntityRelationship( heli, D_LI, 99 )

end

local heliHateAttackThreshold = 2 -- hate anyone who attacks us more times than this

-- HasStatusEffect only exists on the glee gamemode, guard it for sandbox etc.
local function heliPlayerHasEffect( ply, effect )
    return ply.HasStatusEffect and ply:HasStatusEffect( effect )

end

local function heliPlayerAttackCount( heli, ply )
    return heli.glee_HeliAttackers and heli.glee_HeliAttackers[ply] or 0

end

-- has this player earned the heli's hate?
local function heliHatesPlayer( heli, ply )
    local attackCount = heliPlayerAttackCount( heli, ply )

    -- the divine chosen get ignored, but one shot at the heli ends that truce
    if heliPlayerHasEffect( ply, "divine_chosen" ) and attackCount >= 1 then return true end

    -- anyone who keeps taking shots at us
    if attackCount > heliHateAttackThreshold then return true end

    return false

end

-- someone the heli refuses to pick up: the divine chosen, anyone it's come to hate,
-- or anyone still loading/in the tutorial, who can't come to it
function rescueHeli.WontRescue( heli, ply )
    if heliPlayerHasEffect( ply, "spawn_protection" ) then return true end
    if heliPlayerHasEffect( ply, "divine_chosen" ) then return true end
    if heliHatesPlayer( heli, ply ) then return true end

    return false

end

function rescueHeli.CanBoard( heli, ply )
    return not heliHatesPlayer( heli, ply )

end

function rescueHeli.UpdatePlayerRelationship( heli, ply )
    if not IsValid( heli ) then return end
    if not IsValid( ply ) then return end

    -- hate the ones who earned it ( divine chosen who shot us, or repeat attackers )
    if heliHatesPlayer( heli, ply ) then
        rescueHeli.MakeFeudWith( heli, ply )

    -- ignore the divine chosen otherwise
    elseif heliPlayerHasEffect( ply, "divine_chosen" ) then
        heli:AddEntityRelationship( ply, D_NU, 99 )

    -- everyone else is a rescuee
    else
        makeHeliFriendlyWith( heli, ply )

    end
end

local toHate = {
    "npc_combine_camera",
    "npc_turret_ceiling",
    "npc_cscanner",
    "npc_combinedropship",
    "npc_combinegunship",
    "npc_combine_s",
    "npc_turret_floor",
    "npc_citizen_rebel_enemy",
    "npc_hunter",
    "npc_manhack",
    "npc_metropolice",
    "npc_rollermine",
    "npc_clawscanner",
    "npc_stalker",
    "npc_strider",
}

-- call once, after the heli spawns
function rescueHeli.SetupStanding( heli )
    for _, ply in player.Iterator() do
        rescueHeli.UpdatePlayerRelationship( heli, ply )

    end

    -- spawnflags are set between creation and Spawn, so it's judged a tick later
    hook.Add( "OnEntityCreated", heli, function( self, ent )
        if ent:GetClass() ~= "npc_turret_floor" then return end

        timer.Simple( 0, function()
            if not IsValid( self ) or not IsValid( ent ) then return end
            if not isResistanceTurret( ent ) then return end

            makeAlliesWith( self, ent )

        end )
    end )

    -- buff its damage when it decides to shoot
    local hookName = "glee_rescuehelishoot_" .. heli:GetCreationID()
    hook.Add( "EntityTakeDamage", hookName, function( target, dmgInfo )
        if not IsValid( heli ) then
            hook.Remove( "EntityTakeDamage", hookName )
            return

        end
        local attacker = dmgInfo:GetAttacker()
        if attacker == heli and ( not target:IsPlayer() or heliHatesPlayer( heli, target ) ) then
            dmgInfo:ScaleDamage( 15 )

        elseif target == heli then
            if not dmgInfo:IsExplosionDamage() then -- nuke force from non-explosive damage
                if dmgInfo:GetDamage() <= 10 then return end -- just give up if super weak non-explosive damage
                dmgInfo:SetDamageForce( Vector( 0, 0, 0 ) )

            end
            if not IsValid( attacker ) then return end
            if not attacker:IsPlayer() then return end

            -- tally the hit, then re-judge them ( a divine chosen truce ends now, repeat attackers earn hate )
            heli.glee_HeliAttackers = heli.glee_HeliAttackers or {}
            heli.glee_HeliAttackers[attacker] = ( heli.glee_HeliAttackers[attacker] or 0 ) + 1
            rescueHeli.UpdatePlayerRelationship( heli, attacker )

            -- the divine chosen were being ignored; don't also taunt them for shooting
            if heliPlayerHasEffect( attacker, "divine_chosen" ) then return end

            if not GAMEMODE.SurfaceHomicidalGlee then return end
            GAMEMODE:SurfaceHomicidalGlee( attacker, heli )

        end
    end )

    heli:SetSaveValue( "m_iClass", CLASS_PLAYER_ALLY_VITAL )
    -- heli:SetNPCClass

    for _, class in ipairs( toHate ) do
        heli:AddRelationship( class .. " D_HT 99" )
        for _, ent in ipairs( ents.FindByClass( class ) ) do
            if isResistanceTurret( ent ) then
                makeAlliesWith( heli, ent )

            else
                ent:AddEntityRelationship( heli, D_HT, 99 )

            end
        end
    end
end
