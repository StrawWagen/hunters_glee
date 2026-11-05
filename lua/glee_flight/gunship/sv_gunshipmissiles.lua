-- bomb runs, salvos of dumbfire missiles fired in pairs, led at the target
local gunship = terminator_Extras.glee_Gunship

local bombCfg = gunship.BombCfg

-- stops whatever was sweeping in that slot, then sweeps a sound's pitch
-- soundLevel is for raw .wav paths, which otherwise play quiet, sound scripts bring their own
function gunship.SweepSound( npc, state, slot, soundName, fromPitch, toPitch, sweepTime, soundLevel )
    local old = state[slot]
    if old then old:Stop() end

    local snd = CreateSound( npc, soundName )
    if soundLevel then
        snd:SetSoundLevel( soundLevel )

    end
    snd:PlayEx( 1, fromPitch )
    snd:ChangePitch( toPitch, sweepTime )
    state[slot] = snd

end

function gunship.StartBombRun( npc, state, segment )
    state.ammo = bombCfg.ammo[segment]
    state.nextMissile = CurTime() + bombCfg.pairGap[segment] * 0.5

    npc:EmitSound( "npc/combine_gunship/attack_start2.wav", 150, 60, 1, CHAN_STATIC )
    gunship.SweepSound( npc, state, "bombSound", "NPC_CombineGunship.SeeEnemy", 100, 75, 0.8 )

end

function gunship.EndBombRun( npc, state )
    npc:EmitSound( "npc/combine_gunship/attack_stop2.wav", 150, 60, 1, CHAN_STATIC )
    gunship.SweepSound( npc, state, "bombSound", "NPC_CombineGunship.SeeEnemy", 75, 100, 0.8 )

end

-- nearly dead and bombing, every rocket fired at it reloads it, once per rocket
function gunship.MadReload( state, rocket )
    if state.lastMadRocket == rocket then return end
    state.lastMadRocket = rocket
    state.ammo = bombCfg.madAmmo

end

-- one more hit could kill it, it screams at every rocket it sees coming, whatever it's doing
function gunship.TerrorAtRocket( npc, state, rocket )
    if state.lastTerrorRocket == rocket then return end
    state.lastTerrorRocket = rocket

    gunship.SweepSound( npc, state, "terrorSound", "NPC_CombineGunship.Pain", 80, 105, 1 )

end

local function launch( npc, spawnPos, aimPos )
    local dir = ( aimPos - spawnPos ):GetNormalized()

    local missile = ents.Create( "glee_gunshipmissile" )
    if not IsValid( missile ) then return end
    missile:SetPos( spawnPos )
    missile:SetAngles( dir:Angle() )
    missile:SetOwner( npc )
    missile:Spawn()

    local filterTargetable = terminator_Extras.recipFilterAllTargetablePlayers()
    npc:EmitSound( "weapons/mortar/mortar_fire1.wav", 95, 100, 1, CHAN_STATIC, SND_NOFLAGS, 0, filterTargetable )
    npc:EmitSound( "weapons/mortar/mortar_fire1.wav", 140, 80, 0.5, CHAN_STATIC, SND_NOFLAGS, 0, filterTargetable )

    local effectData = EffectData()
    effectData:SetOrigin( spawnPos )
    effectData:SetAngles( ( -dir ):Angle() )
    effectData:SetScale( 10 )
    util.Effect( "MuzzleEffect", effectData, true, true )

end

-- in sight, led
-- out of sight, where it last saw them, spread wider for every missile it's guessed with since
-- never seen them, it aims at them anyway, unspread
local function aimAt( sighting, target, distToTarget, canSeeTarget )
    local lastSeenPos = sighting and sighting.pos or target:WorldSpaceCenter()
    if canSeeTarget then
        local leadTime = math.max( distToTarget / bombCfg.leadSpeed, 1 )
        return lastSeenPos + target:GetVelocity() * leadTime

    end

    local guessedWith = sighting and sighting.missilesSince or 0
    local spread = bombCfg.blindSpreadPerMissile * guessedWith
    local offset = Angle( 0, math.Rand( 0, 360 ), 0 ):Forward() * spread * math.sqrt( math.Rand( 0, 1 ) )
    return lastSeenPos + offset

end

-- fires when the pair timing says so, holds fire while the shot's blocked
function gunship.ManageMissiles( npc, state, segment, target, distToTarget, canSeeTarget )
    if state.ammo <= 0 then return end
    local cur = CurTime()
    if cur < state.nextMissile then return end

    -- odd ammo is the second of a pair, it fires from the other side
    local side = state.ammo % 2 == 1 and 1 or -1
    local spawnPos = npc:GetPos() + npc:GetRight() * bombCfg.launchSideOffset * side + npc:GetForward() * bombCfg.launchForwardOffset

    local sighting = gunship.LastSighting( state, target )
    local aimPos = aimAt( sighting, target, distToTarget, canSeeTarget )

    if not util.IsInWorld( spawnPos ) then return end
    if not terminator_Extras.PosCanSee( spawnPos, aimPos, MASK_SOLID_BRUSHONLY ) then return end

    launch( npc, spawnPos, aimPos )
    state.ammo = state.ammo - 1
    gunship.SpendSpite( state, gunship.SpiteCfg.perMissile )
    if sighting then
        sighting.missilesSince = sighting.missilesSince + 1

    end

    if state.ammo % 2 == 1 then
        state.nextMissile = cur + bombCfg.inPairGap[segment]

    else
        state.nextMissile = cur + bombCfg.pairGap[segment]

    end
end
