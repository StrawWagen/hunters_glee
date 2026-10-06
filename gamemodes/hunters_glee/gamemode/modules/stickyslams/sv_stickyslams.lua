-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=3812596923
-- server half of sticky slams, see sh_stickyslams.lua
-- the stock weapon_slam is c++ ( hl2mp's ), we steer it by playing its own anims and setting its internal state,
-- the same way its own throw/detonate code does

local slamAmmo = "slam"
local placeReach = GM.StickySlamReach * 1.5 -- room for the target to move during the attach anim
local slamFacing = Angle( 90, 0, 0 )
local propSurfaceOffset = 2
local stockHoldGrace = 0.1
local satchelExplodeDelay = 0.2 -- the stock detonate's delay

-- last tick's right mouse, per player holding a SLAM, so one click detonates once
-- left mouse is held down to keep placing, like the stock SLAM
local rmbHeld = {}

local function getStickySlams( ply )
    local slams = {}
    for _, slam in ipairs( ents.FindByClass( "glee_sticky_slam" ) ) do
        if slam:GetSlamOwner() == ply then
            slams[#slams + 1] = slam

        end
    end
    return slams

end

-- the satchels the stock detonator would set off
local function getLiveSatchels( ply )
    local satchels = {}
    for _, satchel in ipairs( ents.FindByClass( "npc_satchel" ) ) do
        if satchel:GetInternalVariable( "m_hThrower" ) == ply and satchel:GetInternalVariable( "m_bIsLive" ) then
            satchels[#satchels + 1] = satchel

        end
    end
    return satchels

end

hook.Add( "PlayerDeath", "glee_stickyslams_ownerdied", function( ply )
    for _, slam in ipairs( getStickySlams( ply ) ) do
        slam:DetonateSoon()

    end
end )

-- nobody's left to set them off
hook.Add( "PlayerDisconnected", "glee_stickyslams_ownerleft", function( ply )
    for _, slam in ipairs( getStickySlams( ply ) ) do
        slam:FallOff()

    end

    rmbHeld[ply] = nil

end )


-- the stock SLAM's state, everything here mirrors the hl2mp weapon_slam.cpp

-- its m_tSlamState is only ever tripmine, or throw ( 1 )
local slamStateTripmine = 0

local function isDetonatorOut( wep )
    return wep:GetInternalVariable( "m_bDetonatorArmed" )

end

local function inTripmineMode( wep )
    return wep:GetInternalVariable( "m_tSlamState" ) == slamStateTripmine

end

-- its own left click won't fire either, while its throw/attach anims are still chaining into the next
local function stockIsBusy( wep )
    return wep:GetInternalVariable( "m_bNeedReload" ) or CurTime() < wep:GetNextPrimaryFire()

end

-- gets the detonator out, like throwing a satchel does
local function armDetonator( wep, ply )
    if not isDetonatorOut( wep ) then
        wep:SetSaveValue( "m_bDetonatorArmed", true )
        wep:SetSaveValue( "m_bNeedDetonatorDraw", true ) -- read by drawActFor

    end

    -- without this, its WeaponIdle deletes an empty SLAM instead of idling on the detonator
    if ply:GetAmmoCount( slamAmmo ) <= 0 then
        wep:SetSaveValue( "m_bNeedReload", true )

    end
end

-- consumes m_bNeedDetonatorDraw, the detonator only gets drawn out once
local function drawActFor( wep, ply )
    if not isDetonatorOut( wep ) then
        return inTripmineMode( wep ) and ACT_SLAM_TRIPMINE_DRAW or ACT_SLAM_THROW_ND_DRAW

    end

    local drawDetonator = wep:GetInternalVariable( "m_bNeedDetonatorDraw" )
    wep:SetSaveValue( "m_bNeedDetonatorDraw", false )

    if ply:GetAmmoCount( slamAmmo ) <= 0 then
        return ACT_SLAM_DETONATOR_DRAW

    end
    if inTripmineMode( wep ) then
        return drawDetonator and ACT_SLAM_DETONATOR_STICKWALL_DRAW or ACT_SLAM_STICKWALL_DRAW

    end
    return drawDetonator and ACT_SLAM_DETONATOR_THROW_DRAW or ACT_SLAM_THROW_DRAW

end

-- nil when the SLAM is empty with nothing left to detonate
local function idleActFor( wep, ply )
    local armed = isDetonatorOut( wep )
    if ply:GetAmmoCount( slamAmmo ) <= 0 then
        return armed and ACT_SLAM_DETONATOR_IDLE or nil

    end
    if inTripmineMode( wep ) then
        return armed and ACT_SLAM_STICKWALL_IDLE or ACT_SLAM_TRIPMINE_IDLE

    end
    return armed and ACT_SLAM_THROW_IDLE or ACT_SLAM_THROW_ND_IDLE

end

-- its StartSatchelDetonate's choice
local function detonateActFor( wep )
    if wep:GetInternalVariable( "m_bNeedReload" ) then return ACT_SLAM_DETONATOR_DETONATE end
    if inTripmineMode( wep ) then return ACT_SLAM_STICKWALL_DETONATE end

    return ACT_SLAM_THROW_DETONATE

end


-- what the anims do

local function placeSlam( wep, ply, ctx )
    local target = ctx.target
    if not IsValid( target ) or not GAMEMODE:CanStickSlamTo( target ) then return false end
    if ply:GetAmmoCount( slamAmmo ) <= 0 then return false end

    local pos, ang = LocalToWorld( ctx.localPos, ctx.localAng, target:GetPos(), target:GetAngles() )
    if ply:GetShootPos():Distance( pos ) > placeReach then return false end

    local slam = ents.Create( "glee_sticky_slam" )
    slam:SetPos( pos )
    slam:SetAngles( ang )
    slam:SetSlamOwner( ply )
    slam:Spawn()
    slam:StickTo( target )

    ply:RemoveAmmo( 1, slamAmmo )
    armDetonator( wep, ply )
    return true

end

-- does the stock SatchelDetonate's job too, so sticky slams and satchels always go off together
local function detonateEverything( wep, ply )
    for _, slam in ipairs( getStickySlams( ply ) ) do
        slam:Trigger()

    end
    for _, satchel in ipairs( getLiveSatchels( ply ) ) do
        satchel:Fire( "Explode", "", satchelExplodeDelay, ply, ply )

    end

    wep:SetSaveValue( "m_bDetonatorArmed", false )
    return true

end


-- plays steps of the SLAM's viewmodel anims, server side
-- act      viewmodel anim to play, or function( wep, ply ) returning one when the step starts
-- armedAct played instead while the detonator is out
-- finish   fraction of the anim to play before moving to the next step
-- event    fraction of the anim where sound plays and onEvent runs
-- onEvent( wep, ply, ctx ), return false to skip to the last step, so sequences with one that can fail end in drawStep
-- when the last step ends, it idles the way the stock SLAM would, it doesn't reliably idle out of our anims on its own

local drawStep = { act = drawActFor, finish = 0.96 }

local placingSteps = {
    { act = ACT_SLAM_TRIPMINE_ATTACH, armedAct = ACT_SLAM_STICKWALL_ATTACH, finish = 0.92, event = 0, sound = "Weapon_SLAM.TripMineMode" },
    { act = ACT_SLAM_TRIPMINE_ATTACH2, armedAct = ACT_SLAM_STICKWALL_ATTACH2, finish = 0.94, event = 0.38, sound = "TripmineGrenade.Place", onEvent = placeSlam },
    drawStep,
}

-- the detonator's already in hand
local armedDetonatingSteps = {
    { act = detonateActFor, finish = 1, event = 0, sound = "Weapon_SLAM.SatchelDetonate", onEvent = detonateEverything },
}

-- the stock SLAM only re-arms on deploy for satchels, so after a weapon switch we bring the detonator out ourselves
local unarmedDetonatingSteps = {
    { act = ACT_SLAM_DETONATOR_DRAW, finish = 0.94 },
    { act = ACT_SLAM_DETONATOR_DETONATE, finish = 0.94, event = 0.28, sound = "Weapon_SLAM.SatchelDetonate", onEvent = detonateEverything },
    { act = ACT_SLAM_DETONATOR_HOLSTER, finish = 0.90 },
    drawStep,
}

local function animLength( ply, act )
    local vm = ply:GetViewModel()
    if not IsValid( vm ) then return 1 end

    local seq = vm:SelectWeightedSequence( act )
    if seq < 0 then return 1 end

    local length = vm:SequenceDuration( seq )
    if length <= 0 then return 1 end

    return length

end

local activeSequences = {}

local function playStep( wep, ply, sequence )
    local step = sequence.steps[sequence.index]
    local act = step.act
    if step.armedAct and isDetonatorOut( wep ) then
        act = step.armedAct

    elseif isfunction( act ) then
        act = act( wep, ply )

    end

    local now = CurTime()
    local length = animLength( ply, act )
    local stepEnds = now + length * step.finish

    wep:SendWeaponAnim( act )
    wep:SetNextPrimaryFire( stepEnds )
    wep:SetNextSecondaryFire( stepEnds )
    -- stops the stock SLAM idling, or switching modes, over the top of us
    -- held a little past stepEnds, or it can sneak an idle in before our Think moves on
    local holdStockUntil = stepEnds + stockHoldGrace
    wep:SetSaveValue( "m_flTimeWeaponIdle", holdStockUntil )
    wep:SetSaveValue( "m_flWallSwitchTime", holdStockUntil )

    sequence.stepEnds = stepEnds
    sequence.eventAt = step.event and now + length * step.event

end

local skipToLastStep

-- returns false if onEvent cut the sequence to its last step
local function fireEvent( wep, ply, sequence )
    sequence.eventAt = nil

    local step = sequence.steps[sequence.index]
    if step.sound then
        wep:EmitSound( step.sound )

    end
    if step.onEvent and not step.onEvent( wep, ply, sequence.ctx ) then
        skipToLastStep( wep, ply, sequence )
        return false

    end
    return true

end

local function nextStep( wep, ply, sequence )
    sequence.index = sequence.index + 1
    if not sequence.steps[sequence.index] then
        activeSequences[wep] = nil

        local idleAct = idleActFor( wep, ply )
        if idleAct then
            wep:SendWeaponAnim( idleAct )

        else
            -- what its WeaponIdle does with an empty SLAM, but that doesn't run after our anims
            ply:StripWeapon( "weapon_slam" )
            ply:SwitchToDefaultWeapon()

        end
        return

    end
    playStep( wep, ply, sequence )

    -- event = 0 goes off with the anim, not a tick later
    if sequence.eventAt and sequence.eventAt <= CurTime() then
        fireEvent( wep, ply, sequence )

    end
end

skipToLastStep = function( wep, ply, sequence )
    sequence.index = #sequence.steps - 1
    nextStep( wep, ply, sequence )

end

local function runSequence( wep, ply, steps, ctx )
    local sequence = { steps = steps, index = 0, ctx = ctx }
    activeSequences[wep] = sequence
    nextStep( wep, ply, sequence )

end

hook.Add( "Think", "glee_stickyslams_sequences", function()
    local now = CurTime()
    for wep, sequence in pairs( activeSequences ) do
        local ply = IsValid( wep ) and wep:GetOwner()
        if not IsValid( ply ) or ply:Health() <= 0 or ply:GetActiveWeapon() ~= wep then
            activeSequences[wep] = nil
            continue

        end

        if sequence.eventAt and now >= sequence.eventAt then
            local cutShort = not fireEvent( wep, ply, sequence )
            if cutShort then continue end

        end

        if now >= sequence.stepEnds then
            nextStep( wep, ply, sequence )

        end
    end
end )


-- input

-- props have flat faces, bodies can take a SLAM sunk in a little
local function hasFlatSurfaces( ent )
    if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then return false end
    return ent:GetClass() ~= "prop_ragdoll"

end

local function startPlacing( wep, ply, target, pos, normal )
    if hasFlatSurfaces( target ) then
        pos = pos + normal * propSurfaceOffset

    end

    -- stored relative to the target, so it lands where we aimed even if the target moves during the anim
    local localPos, localAng = WorldToLocal( pos, normal:Angle() + slamFacing, target:GetPos(), target:GetAngles() )

    ply:SetAnimation( PLAYER_ATTACK1 )
    runSequence( wep, ply, placingSteps, { target = target, localPos = localPos, localAng = localAng } )

end

-- only takes the click over when there's sticky slams out, satchels alone are left to the stock SLAM
local function startDetonating( wep, ply, cmd )
    if #getStickySlams( ply ) <= 0 then return end
    if CurTime() < wep:GetNextSecondaryFire() then return end

    cmd:RemoveKey( IN_ATTACK2 )

    -- a thrown satchel that isn't out of the hand yet would land after we'd disarmed, with nothing to set it off
    if wep:GetInternalVariable( "m_bThrowSatchel" ) then return end

    if isDetonatorOut( wep ) then
        runSequence( wep, ply, armedDetonatingSteps )

    else
        runSequence( wep, ply, unarmedDetonatingSteps )

    end
end

-- runs for every player, every tick, so it bails as cheap as it can
local IsValid = IsValid
local IN_ATTACK = IN_ATTACK
local IN_ATTACK2 = IN_ATTACK2
local clickKey = GM.StickySlamClickKey

local GetActiveWeapon = FindMetaTable( "Player" ).GetActiveWeapon
local GetClass = FindMetaTable( "Entity" ).GetClass
local cmdMeta = FindMetaTable( "CUserCmd" )
local KeyDown = cmdMeta.KeyDown
local RemoveKey = cmdMeta.RemoveKey

hook.Add( "StartCommand", "glee_stickyslams_input", function( ply, cmd )
    local wep = GetActiveWeapon( ply )
    if not IsValid( wep ) or GetClass( wep ) ~= "weapon_slam" then
        rmbHeld[ply] = nil
        return

    end

    local clientClicked = KeyDown( cmd, clickKey )
    RemoveKey( cmd, clickKey )

    if not GAMEMODE:CanUseStickySlams( ply ) then
        rmbHeld[ply] = nil
        return

    end

    local lmb = KeyDown( cmd, IN_ATTACK ) or clientClicked
    local rmb = KeyDown( cmd, IN_ATTACK2 )
    local pressedR = rmb and not rmbHeld[ply]
    rmbHeld[ply] = rmb

    local target, pos, normal
    if lmb and ply:GetAmmoCount( slamAmmo ) > 0 then
        target, pos, normal = GAMEMODE:FindStickySlamTarget( ply, cmd:GetViewAngles():Forward() )

    end
    -- every tick it's held, or the stock SLAM throws one as soon as our anim finishes
    -- and always when the client predicted a stick, or the stock SLAM does something the client never predicted
    if target or clientClicked then
        RemoveKey( cmd, IN_ATTACK )

    end

    if activeSequences[wep] then return end

    if target and not stockIsBusy( wep ) then
        startPlacing( wep, ply, target, pos, normal )

    elseif pressedR then
        startDetonating( wep, ply, cmd )

    end
end )
