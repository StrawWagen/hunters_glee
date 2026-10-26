AddCSLuaFile()

--[[
    A handle to a big carried entity, see glee_carrying/sh_carrying.lua. The entity rides the hand bone
    while this is out, and the spine while it's not. It's never copied or remade, it keeps doing
    whatever it does the whole time.

    Subclasses set CarryEntClass, or override CreateCarryEnt for what needs more than a class, and the
    bone offsets below. They may define, server side,
        SWEP:OnCarryStart( ent, carrier )
        SWEP:OnCarryEnd( ent, carrier, placed ) -- carrier can be NULL. Not placed, it was dropped, and may get flung right after

    Holding reload previews where it'd be placed, letting go places it there. Any other way this weapon
    leaves its owner, it's let go where it is. The gamemode's dropper then throws it, see GetDroppedEntity.

    Think only runs while it's out, subclasses can define SWEP:OnBackThink(), server side, every tick
    it's on the back instead.
]]

local glee_Carrying = terminator_Extras.glee_Carrying

SWEP.Base = "weapon_base"
SWEP.IsGleeBackpackable = true

SWEP.Spawnable = false
SWEP.Category = "Hunter's Glee"
SWEP.DrawCrosshair = false
SWEP.DrawAmmo = false

SWEP.CarryEntClass = nil -- what the base CreateCarryEnt spawns, only for glee_Carrying.GiveNewCarryable

SWEP.HoldType = "duel" -- never "normal", the gamemode's dropper refuses to drop those

-- the elites' arms, posed into holding something out in front, guns shrunk away
SWEP.ViewModel = "models/weapons/cstrike/c_pist_elite.mdl"
SWEP.UseHands = true
SWEP.ViewModelFOV = 70
SWEP.ViewModelFlip = false
SWEP.WorldModel = "models/weapons/w_c4.mdl" -- never drawn, the carried entity is the world model
SWEP.ViewModelOffset = Vector( 0, 0, 0 ) -- the whole viewmodel, arms and held model, along right, forward, up

-- { [boneName] = { scale = Vector, pos = Vector, angle = Angle } }, as SWEP Construction Kit writes them.
-- A bone's scale carries down to its children. Maxwell's pose, palms rolled up
SWEP.ViewModelBoneMods = glee_Carrying.ElitesBoneMods( 0, -80.047, 71.204 )

-- the carried entity's model, drawn on the viewmodel
SWEP.HeldModelBone = "ValveBiped.Bip01_R_Hand"
SWEP.HeldModelPos = Vector( 0, 0, 0 )
SWEP.HeldModelAng = Angle( 0, 0, 0 )
SWEP.HeldModelScale = 1

-- where the carried entity rides on the owner
SWEP.WorldModelHandBone = "ValveBiped.Bip01_R_Hand"
SWEP.WorldModelHandPos = Vector( 0, 0, 0 )
SWEP.WorldModelHandAng = Angle( 0, 0, 0 )
SWEP.WorldModelHandScale = 1
SWEP.WorldModelBackBone = "ValveBiped.Bip01_Spine2"
SWEP.WorldModelBackPos = Vector( 0, 0, 0 )
SWEP.WorldModelBackAng = Angle( 0, 0, 0 )
SWEP.WorldModelBackScale = 1

SWEP.SpeedModifier = -50 -- run speed, while it's carried, in hand or on the back, see UpdateCarrySlow. Hunter's Glee only

SWEP.PlaceDistance = 100
SWEP.PlaceAng = Angle( 0, 0, 0 ) -- turns the model within its placement, upright and facing the same way as the placer
-- From the placed entity, one of sounds at random. An entry's own pitch beats the root's
SWEP.PlacedSound = {
    pitch = 80,
    sounds = {
        { path = "physics/cardboard/cardboard_box_impact_hard1.wav" },
        { path = "physics/cardboard/cardboard_box_impact_hard2.wav" },
        { path = "physics/cardboard/cardboard_box_impact_hard3.wav" },
    },
}
SWEP.PlacedUpOffset = 0 -- off the floor, along its slope, for a model whose bounds don't reach its real base
SWEP.PlaceGhostAng = nil -- PlaceAng for the preview only, when its still pose sits differently than the placed entity's
SWEP.PlaceMinFloorUp = 0.25 -- of the surface normal, steeper than this isn't a floor
SWEP.PlaceCoreFraction = 0.5 -- of its narrowest width, how much of its middle has to be clear to place it
SWEP.PlaceCoreLift = 18 -- step height, clutter under it lower than this doesn't block a place

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

-- Entity and Bool slot 0 are taken, subclasses start theirs at 1
function SWEP:SetupDataTables()
    self:NetworkVar( "Entity", 0, "CarriedEnt" )
    self:NetworkVar( "Bool", 0, "OnBack" ) -- what it carries rides the back, not the hands
    -- handed out without an entity, it may make one, see glee_Carrying.GiveNewCarryable. Used up as it's equipped
    self:NetworkVar( "Bool", 1, "MakesOwnCarryEnt" )

    if SERVER then
        self:NetworkVarNotify( "OnBack", function( wep, _, _, onBack )
            wep:OnBackChanged( onBack )

        end )
    end
end

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )

end

-- Autorefresh. The offsets are applied once, as it's held or put away, so they're put back on here
function SWEP:OnReloaded()
    self:SetHoldType( self.HoldType )

    if CLIENT then
        self.glee_BoneModsModel = nil
        return

    end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    if owner:GetActiveWeapon() == self then
        self:AttachCarried( self.WorldModelHandBone, self.WorldModelHandPos, self.WorldModelHandAng, self.WorldModelHandScale )

    else
        self:AttachCarried( self.WorldModelBackBone, self.WorldModelBackPos, self.WorldModelBackAng, self.WorldModelBackScale )

    end
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:Deploy()
    self:SetHoldType( self.HoldType )

    if SERVER then
        local owner = self:GetOwner()
        if self:GetOnBack() then
            owner:EmitSound( "npc/footsteps/softshoe_generic6.wav", 65, 110 )
            owner:ViewPunch( Angle( -1, 0, math.Rand( -1, -2 ) ) )

        end
        self:AttachCarried( self.WorldModelHandBone, self.WorldModelHandPos, self.WorldModelHandAng, self.WorldModelHandScale )
        self:SetOnBack( false )

        -- the R that stashed it is still down, it's not the start of a place
        self.glee_ReloadBlocked = IsValid( owner ) and owner:KeyDown( IN_RELOAD )

    end

    return true

end

-- Refuses a switch when there's no room on the back, see glee_Carrying.CanPutAway. Here and not in a
-- PlayerSwitchWeapon hook, any other addon's hook that returns a value there stops ours from running
function SWEP:Holster( newWep )
    local owner = self:GetOwner()
    -- holstered as it's dropped or its owner dies, there's nothing left to put away
    local puttingAway = IsValid( self:GetCarriedEnt() ) and IsValid( owner ) and owner:Alive()

    if puttingAway and IsValid( newWep ) then
        local canPutAway, reason = glee_Carrying.CanPutAway( owner, self, newWep )
        if not canPutAway then
            if SERVER then
                if reason == "noback" then
                    glee_Carrying.HintCantBackpack( owner )

                else
                    glee_Carrying.HintHandsFull( owner )

                end
            end
            return false

        end
    end

    if SERVER then
        self.glee_PlaceHeld = nil

        if puttingAway then
            self:AttachCarried( self.WorldModelBackBone, self.WorldModelBackPos, self.WorldModelBackAng, self.WorldModelBackScale )
            self:SetOnBack( true )

            -- a tick late, a strip holsters it right before removing it, and that's no put-away
            timer.Simple( 0, function()
                if not IsValid( self ) or not IsValid( self:GetCarriedEnt() ) or not IsValid( owner ) then return end

                owner:EmitSound( "npc/footsteps/softshoe_generic6.wav", 65, 140 )
                owner:ViewPunch( Angle( 1, 0, math.Rand( 1, 2 ) ) )
                timer.Simple( 0.2, function()
                    if not IsValid( owner ) then return end
                    owner:EmitSound( "npc/metropolice/gear1.wav", 65, 140, 0.5 )
                    owner:ViewPunch( Angle( -1, 0, 0 ) )

                end )
            end )
        end

    end

    return true

end

-- The model's bounds once PlaceAng's turned it, in the frame it's placed in
local function placedBounds( mins, maxs, placeAng )
    local placedMins = Vector( math.huge, math.huge, math.huge )
    local placedMaxs = -placedMins

    for corner = 0, 7 do
        local point = Vector(
            bit.band( corner, 1 ) == 0 and mins.x or maxs.x,
            bit.band( corner, 2 ) == 0 and mins.y or maxs.y,
            bit.band( corner, 4 ) == 0 and mins.z or maxs.z
        )
        point:Rotate( placeAng )

        placedMins.x = math.min( placedMins.x, point.x )
        placedMins.y = math.min( placedMins.y, point.y )
        placedMins.z = math.min( placedMins.z, point.z )
        placedMaxs.x = math.max( placedMaxs.x, point.x )
        placedMaxs.y = math.max( placedMaxs.y, point.y )
        placedMaxs.z = math.max( placedMaxs.z, point.z )

    end

    return placedMins, placedMaxs

end

-- the footprint's middle and corners, as signs of its extents
local footprintSamples = {
    { 0, 0 },
    { 1, 1 },
    { 1, -1 },
    { -1, 1 },
    { -1, -1 },
}

-- Several traces down across the footprint, so one bump or seam doesn't tilt the whole thing.
-- Nil when none of them found a floor
local function averageFloorNormal( center, yawAng, mins, maxs, rise, filter )
    local total = Vector( 0, 0, 0 )
    local hits = 0

    for _, sample in ipairs( footprintSamples ) do
        local offset = Vector(
            sample[1] > 0 and maxs.x or sample[1] < 0 and mins.x or 0,
            sample[2] > 0 and maxs.y or sample[2] < 0 and mins.y or 0,
            0
        )
        offset:Rotate( yawAng )

        local start = center + offset + Vector( 0, 0, rise )
        local tr = util.TraceLine( {
            start = start,
            endpos = start - Vector( 0, 0, rise * 2 ),
            filter = filter,
        } )

        if tr.Hit and not tr.StartSolid then
            total:Add( tr.HitNormal )
            hits = hits + 1

        end
    end

    if hits == 0 then return end

    return total:GetNormalized()

end

-- Where it'd land: pos, ang, then the slope's angle before PlaceAng, for the ghost to apply its own.
-- On the floor the placer's aiming at, tilted to its slope. Nil and why when it can't go there,
-- "nofloor" or "blocked". Fits the model at scale 1, so it's off for anything that was scaled before it was carried
function SWEP:GetPlacement( placer )
    local ent = self:GetCarriedEnt()
    if not IsValid( ent ) then return end

    local filter = glee_Carrying.GetCarrierTraceFilter( placer )
    local shootPos = placer:GetShootPos()

    local floorTr = util.TraceLine( {
        start = shootPos,
        endpos = shootPos + placer:GetAimVector() * self.PlaceDistance,
        filter = filter,
    } )
    if not floorTr.Hit or floorTr.HitNormal.z < self.PlaceMinFloorUp then return nil, "nofloor" end

    local modelMins, modelMaxs = ent:GetModelBounds()
    local mins, maxs = placedBounds( modelMins, modelMaxs, self.PlaceAng )

    -- how far the slope rises across the model's footprint, the uphill edge is that much above the hit
    local normalZ = floorTr.HitNormal.z
    local footprintRadius = math.max( -mins.x, maxs.x, -mins.y, maxs.y ) * math.sqrt( 2 )
    local rise = footprintRadius * math.sqrt( 1 - normalZ ^ 2 ) / normalZ + 1

    local yawAng = Angle( 0, placer:EyeAngles().y, 0 )
    local floorNormal = averageFloorNormal( floorTr.HitPos, yawAng, mins, maxs, rise, filter )
    if not floorNormal or floorNormal.z < self.PlaceMinFloorUp then return nil, "nofloor" end

    -- the placer's facing, laid flat along the slope
    local forward = yawAng:Forward()
    forward = ( forward - floorNormal * forward:Dot( floorNormal ) ):GetNormalized()
    local slopeAng = forward:AngleEx( floorNormal )
    local _, placedAng = LocalToWorld( vector_origin, self.PlaceAng, vector_origin, slopeAng )

    local pos = floorTr.HitPos + floorNormal * ( self.PlacedUpOffset - mins.z )

    -- Lenient on purpose, only its middle has to be clear, physics pushes the rest out of what it clips.
    -- Square, so it's the same whichever way it faces
    local coreCenter = ( mins + maxs ) * 0.5
    coreCenter.z = 0
    coreCenter:Rotate( yawAng )

    local coreHalfWidth = math.min( maxs.x - mins.x, maxs.y - mins.y ) * 0.5 * self.PlaceCoreFraction
    local coreTop = maxs.z - ( maxs.z - mins.z ) * 0.1 -- a ceiling it'd only brush doesn't block it
    local coreBottom = math.min( mins.z + self.PlaceCoreLift, coreTop - 1 )

    local coreTr = util.TraceHull( {
        start = pos + coreCenter,
        endpos = pos + coreCenter,
        mins = Vector( -coreHalfWidth, -coreHalfWidth, coreBottom ),
        maxs = Vector( coreHalfWidth, coreHalfWidth, coreTop ),
        filter = filter,
    } )
    if coreTr.StartSolid then return nil, "blocked" end

    return pos, placedAng, slopeAng

end

local placedLesson = "PlacedAHoldable"

-- Reload runs every tick it's held, Think places on the tick it's let go
function SWEP:Reload()
    if not SERVER then return end
    if self.glee_ReloadBlocked then return end
    -- reload's for what's lifted with use then, see glee_carrying
    if IsValid( glee_Carrying.GetPhysicsHeld( self:GetOwner() ) ) then return end

    if not self.glee_PlaceHeld then
        self.glee_PlaceHeld = true
        self.glee_PlaceWasValid = false

    end

    -- a tap at nothing is just a tap, the deny's for losing a spot they had
    if not self.glee_PlaceWasValid and self:GetPlacement( self:GetOwner() ) then
        self.glee_PlaceWasValid = true

    end
end

function SWEP:Think()
    if not SERVER then return end

    local owner = self:GetOwner()
    if self.glee_ReloadBlocked and not owner:KeyDown( IN_RELOAD ) then
        self.glee_ReloadBlocked = nil

    end

    if not self.glee_PlaceHeld then return end
    if owner:KeyDown( IN_RELOAD ) then return end

    self.glee_PlaceHeld = nil

    local pos, ang = self:GetPlacement( owner )
    if not pos then
        if self.glee_PlaceWasValid then
            owner:EmitSound( "common/wpn_denyselect.wav", 60 )

        end
        return

    end

    local placed = self:GetCarriedEnt()
    self:StopCarrying( pos, ang )

    local placedSound = self.PlacedSound
    if placedSound and IsValid( placed ) then
        local entry = placedSound.sounds[math.random( #placedSound.sounds )]
        placed:EmitSound( entry.path, 70, entry.pitch or placedSound.pitch or 100 )

    end

    owner:ViewPunch( Angle( 2, 0, 0 ) )

    -- lessons are the gamemode's, outside it there's no hint to grow out of
    if GAMEMODE.LearnLesson then
        GAMEMODE:LearnLesson( owner, placedLesson )

    end

    local previous = owner:GetPreviousWeapon()
    if IsValid( previous ) and previous:IsWeapon() and previous ~= self then
        owner:SelectWeapon( previous:GetClass() )

    end

    SafeRemoveEntity( self )

end

function SWEP:OnRemove()
    if SERVER then
        self:StopCarrying()

    else
        SafeRemoveEntity( self.MyHeldModel )
        SafeRemoveEntity( self.glee_PlacementGhost )

    end
end


if SERVER then
    function SWEP:Equip( newOwner )
        self.glee_Carrier = newOwner

        local ent = self.glee_CarryOnEquip
        self.glee_CarryOnEquip = nil

        local makesOwn = self:GetMakesOwnCarryEnt()
        self:SetMakesOwnCarryEnt( false )

        -- handed out by class with nothing to carry, eg weapons restored from a snapshot. Making one
        -- would duplicate what was released when they were stripped, so only GiveNewCarryable's does
        if not IsValid( ent ) then
            if not makesOwn then
                SafeRemoveEntity( self )
                return

            end

            ent = self:CreateCarryEnt( newOwner:GetPos() )
            if not IsValid( ent ) then
                SafeRemoveEntity( self )
                return

            end
        end

        self:StartCarrying( ent )

    end

    -- Its carrier's slowed by SpeedModifier while it's on their back, and in their hands by that times
    -- their carry rules' handsSpeedMul, see glee_Carrying.GetCarryRules. None once it's let go.
    -- onBack's for OnBack's change callback, which runs before GetOnBack changes. The gamemode's speed
    -- handler does it, so it's nothing outside the gamemode. Keyed per weapon, a hands-and-back swap
    -- holsters one before deploying the other, a shared key would have the deploy wipe what the holster added
    function SWEP:UpdateCarrySlow( onBack )
        local carrier = self.glee_Carrier -- not GetOwner, that's gone by the time OnDrop releases it
        if not IsValid( carrier ) or not carrier.DoSpeedModifier then return end

        if onBack == nil then
            onBack = self:GetOnBack()

        end

        local modifier = nil
        if IsValid( self:GetCarriedEnt() ) then
            if onBack then
                modifier = self.SpeedModifier

            else
                modifier = self.SpeedModifier * glee_Carrying.GetCarryRules( carrier ).handsSpeedMul

            end
        end

        carrier:DoSpeedModifier( "glee_backpackable_carryslow_" .. self:EntIndex(), modifier )

    end

    -- Spawned, for a weapon handed out without one. Override for what needs more than its class
    function SWEP:CreateCarryEnt( pos )
        local ent = ents.Create( self.CarryEntClass )
        if not IsValid( ent ) then return end

        ent:SetPos( pos )
        ent:Spawn()

        return ent

    end

    function SWEP:OnDrop()
        self:StopCarrying()
        SafeRemoveEntity( self )

    end

    -- For whatever dropped this, the entity to throw in its place. This removes itself as it drops,
    -- so flinging the weapon would do nothing. NULL if it never let go of anything
    function SWEP:GetDroppedEntity()
        return self.glee_ReleasedEnt or NULL

    end

    -- what StartCarrying changes on the entity, for StopCarrying to put back
    local function rememberEntState( ent )
        local phys = ent:GetPhysicsObject()

        ent.glee_PreCarryState = {
            owner = ent:GetOwner(),
            moveType = ent:GetMoveType(),
            modelScale = ent:GetModelScale(),
            solidType = ent:GetSolid(),
            collisionGroup = ent:GetCollisionGroup(),
            customCollisionCheck = ent:GetCustomCollisionCheck(),
            notSolid = bit.band( ent:GetSolidFlags(), FSOLID_NOT_SOLID ) ~= 0,
            motionEnabled = IsValid( phys ) and phys:IsMotionEnabled(),
            collisionsEnabled = IsValid( phys ) and phys:IsCollisionEnabled(),
        }
    end

    -- Recounted, not toggled, they can carry two and let go of one. Read by the terminator's stealth
    -- checks, see terminator_nextbot/enemyoverrides.lua
    local function updateIsCarrying( carrier )
        if not IsValid( carrier ) then return end

        local isCarrying = false
        for _, wep in ipairs( glee_Carrying.GetCarriedWeapons( carrier ) ) do
            if IsValid( wep:GetCarriedEnt() ) then
                isCarrying = true
                break

            end
        end

        carrier.glee_IsCarrying = isCarrying

    end

    do
        -- the ones with an OnBackThink, riding a back right now. Breaks with autorefresh, it comes back empty
        local onBackWeapons = {}

        local thinkingWeapons = {}

        -- copied out first, OnBackThink can put things on or take them off a back mid loop
        hook.Add( "Think", "glee_backpackable_onbackthink", function()
            local count = 0
            for wep in pairs( onBackWeapons ) do
                count = count + 1
                thinkingWeapons[count] = wep

            end

            for index = 1, count do
                local wep = thinkingWeapons[index]
                thinkingWeapons[index] = nil

                if not IsValid( wep ) then
                    onBackWeapons[wep] = nil

                elseif onBackWeapons[wep] then
                    wep:OnBackThink()

                end
            end
        end )

        -- OnBack's change callback, OnBackThink runs while it's true. A weapon without one is never tracked
        function SWEP:OnBackChanged( onBack )
            if onBack and self.OnBackThink then
                onBackWeapons[self] = true

            else
                onBackWeapons[self] = nil

            end

            self:UpdateCarrySlow( onBack )

        end
    end

    -- Takes ent on as what this carries: frozen, walked through but still shot, and riding the owner's back.
    -- StopCarrying undoes all of it. Removing ent removes this weapon
    function SWEP:StartCarrying( ent )
        self:SetCarriedEnt( ent )
        ent:SetNW2Entity( "glee_CarrierWeapon", self )

        rememberEntState( ent )

        -- the physics object stays behind where it was picked up, frozen
        local phys = ent:GetPhysicsObject()
        if IsValid( phys ) then
            phys:EnableMotion( false )
            phys:EnableCollisions( false )

        end

        ent:SetMoveType( MOVETYPE_NONE )

        -- the carrier's traces skip what they own, so it's not in the way of their own use or aim
        ent:SetOwner( self.glee_Carrier )

        -- a box where it's carried, its physics object is back where it was picked up. Players and their
        -- movement pass through weapons, bullets and swings don't
        ent:SetSolid( SOLID_BBOX )
        ent:SetNotSolid( false )
        ent:SetCollisionGroup( COLLISION_GROUP_WEAPON )

        -- so glee_carrying's ShouldCollide is asked about it, see there
        ent:SetCustomCollisionCheck( true )
        ent:CollisionRulesChanged()

        glee_Carrying.SetCarriedTracked( ent, true )

        -- StopCarrying bails on a removed ent, so it's untracked here
        ent:CallOnRemove( "glee_carrying_removeweapon", function( removed, wep )
            glee_Carrying.SetCarriedTracked( removed, false )
            SafeRemoveEntity( wep )

        end, self )

        self:AttachCarried( self.WorldModelBackBone, self.WorldModelBackPos, self.WorldModelBackAng, self.WorldModelBackScale )
        self:SetOnBack( true )

        updateIsCarrying( self.glee_Carrier )

        self:OnCarryStart( ent, self.glee_Carrier )

    end

    -- stubs, see the top of this file
    function SWEP:OnCarryStart( _ent, _carrier )
    end

    function SWEP:OnCarryEnd( _ent, _carrier, _placed )
    end

    -- Onto one of the owner's bones, at that offset and model scale. Nothing without an entity or an owner
    function SWEP:AttachCarried( boneName, pos, ang, scale )
        local ent = self:GetCarriedEnt()
        local owner = self:GetOwner()
        if not IsValid( ent ) or not IsValid( owner ) then return end

        ent:SetModelScale( scale )

        local bone = owner:LookupBone( boneName )
        if bone then
            ent:FollowBone( owner, bone )
            ent:SetLocalPos( pos )
            ent:SetLocalAngles( ang )

        else -- playermodel without the bone, it rides at their chest instead
            ent:SetParent( owner )
            ent:SetLocalPos( owner:OBBCenter() )
            ent:SetLocalAngles( angle_zero )

        end
    end

    -- Placed at placePos and placeAng, or without them dropped where it is, at the carrier's speed.
    -- Puts back what StartCarrying changed, then OnCarryEnd. Leaves the weapon, removing it is the caller's
    function SWEP:StopCarrying( placePos, placeAng )
        local ent = self:GetCarriedEnt()
        if not IsValid( ent ) then return end

        -- the owner's already gone by OnDrop
        local carrier = self.glee_Carrier
        local state = ent.glee_PreCarryState
        ent.glee_PreCarryState = nil

        self:SetCarriedEnt( NULL )
        self.glee_ReleasedEnt = ent -- see GetDroppedEntity
        ent:SetNW2Entity( "glee_CarrierWeapon", NULL )
        ent:RemoveCallOnRemove( "glee_carrying_removeweapon" )
        glee_Carrying.SetCarriedTracked( ent, false )
        self:SetOnBack( false )

        local placing = placePos ~= nil
        local pos, ang = placePos or ent:GetPos(), placeAng or ent:GetAngles()

        ent:SetParent( NULL )
        ent:RemoveEffects( EF_FOLLOWBONE )
        ent:SetModelScale( state.modelScale )

        ent:SetOwner( state.owner )
        ent:SetMoveType( state.moveType )
        ent:SetSolid( state.solidType )
        ent:SetNotSolid( state.notSolid )
        ent:SetCollisionGroup( state.collisionGroup )

        ent:SetCustomCollisionCheck( state.customCollisionCheck )
        ent:CollisionRulesChanged()

        ent:SetPos( pos )
        ent:SetAngles( ang )

        local phys = ent:GetPhysicsObject()
        if IsValid( phys ) then
            phys:SetPos( pos )
            phys:SetAngles( ang )
            phys:EnableCollisions( state.collisionsEnabled )
            phys:EnableMotion( state.motionEnabled )

            if state.motionEnabled then
                phys:Wake()

            end

            if not placing and IsValid( carrier ) and state.moveType == MOVETYPE_VPHYSICS then
                phys:SetVelocity( carrier:GetVelocity() )

            end
        end

        -- let go from the hands, OnBack was already false, so its change callback never ran
        self:UpdateCarrySlow()

        updateIsCarrying( carrier )

        -- a smart sleeper frozen before it was picked up would stay frozen where it's let go
        if ent.glee_smartSleeping and terminator_Extras.SmartSleepWakeEntity then
            terminator_Extras.SmartSleepWakeEntity( ent )

        end

        self:OnCarryEnd( ent, carrier, placing )

    end
end


if not CLIENT then return end

function SWEP:DrawWorldModel()
end

function SWEP:DrawWorldModelTranslucent()
end

local ghostColor = Color( 255, 255, 255, 150 )

-- input, not KeyDown, the player's keys aren't known clientside in singleplayer
local function isReloadHeld()
    local ply = LocalPlayer()
    if ply:IsTyping() or gui.IsGameUIVisible() or IsValid( vgui.GetKeyboardFocus() ) then return false end

    local bind = input.LookupBinding( "+reload" )
    if not bind then return false end

    return input.IsButtonDown( input.GetKeyCode( bind ) )

end

-- The client's side of the server's Reload, so the preview shows when a place would happen
function SWEP:IsPreviewingPlacement()
    if self.glee_ReloadBlocked then return false end
    if not IsValid( self:GetCarriedEnt() ) then return false end
    if IsValid( glee_Carrying.GetPhysicsHeld( LocalPlayer() ) ) then return false end -- see Reload

    return isReloadHeld()

end

local placingDrop = 6 -- how far the viewmodel sinks while getting ready to place
local placingDropRate = 25 -- per second, of exponential easing. 25 is most of the way in 0.1s

-- ViewModelOffset, and the sink while a place is being readied
function SWEP:GetViewModelPosition( pos, ang )
    local target = 0
    if self:IsPreviewingPlacement() then
        target = 1

    end

    local lowered = self.glee_PlacingLowered or 0
    lowered = lowered + ( target - lowered ) * ( 1 - math.exp( -placingDropRate * RealFrameTime() ) )
    self.glee_PlacingLowered = lowered

    local offset = self.ViewModelOffset
    pos = pos + ang:Right() * offset.x + ang:Forward() * offset.y + ang:Up() * offset.z

    return pos - ang:Up() * placingDrop * lowered, ang

end

function SWEP:RemovePlacementGhost()
    SafeRemoveEntity( self.glee_PlacementGhost )
    self.glee_PlacementGhost = nil

end

-- The see-through copy where a place would land, only while one's being readied and there's somewhere to
function SWEP:UpdatePlacementGhost()
    local ent = self:GetCarriedEnt()
    local pos, ang, slopeAng
    self.glee_PlacementDenied = nil
    if self:IsPreviewingPlacement() then
        pos, ang, slopeAng = self:GetPlacement( LocalPlayer() )
        if not pos then
            self.glee_PlacementDenied = ang -- why, see GetPlacement
            ang = nil

        end
    end

    if pos and self.PlaceGhostAng then
        local _, ghostAng = LocalToWorld( vector_origin, self.PlaceGhostAng, vector_origin, slopeAng )
        ang = ghostAng

    end

    if not pos then
        self:RemovePlacementGhost()
        return

    end

    local ghost = self.glee_PlacementGhost
    if not IsValid( ghost ) or ghost:GetModel() ~= ent:GetModel() then
        SafeRemoveEntity( ghost )

        ghost = ClientsideModel( ent:GetModel(), RENDERGROUP_TRANSLUCENT )
        if not IsValid( ghost ) then return end

        ghost:SetRenderMode( RENDERMODE_TRANSCOLOR )
        ghost:SetColor( ghostColor )
        ghost:SetSkin( ent:GetSkin() )
        self.glee_PlacementGhost = ghost

    end

    ghost:SetPos( pos )
    ghost:SetAngles( ang )

end

-- not the SWEP's Think, that never runs clientside in singleplayer
local ghostingWep

hook.Add( "Think", "glee_backpackable_placementghost", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end -- joining, there's no local player yet

    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or not wep.IsGleeBackpackable then wep = nil end

    if wep ~= ghostingWep then
        if IsValid( ghostingWep ) then
            ghostingWep:RemovePlacementGhost()

        end

        -- as the server's Deploy does, an R still down from stashing it isn't a place
        if wep then
            wep.glee_ReloadBlocked = isReloadHeld()

        end
    end
    ghostingWep = wep

    if not wep then return end

    if wep.glee_ReloadBlocked and not isReloadHeld() then
        wep.glee_ReloadBlocked = nil

    end

    wep:UpdatePlacementGhost()

end )

function SWEP:HintPostStack()
    if self:IsPreviewingPlacement() and not IsValid( self.glee_PlacementGhost ) then
        if self.glee_PlacementDenied == "blocked" then return true, "Something's in the way." end
        return true, "Aim at some nearby, flat floor."

    end

    if GAMEMODE:HasLearnedLesson( placedLesson ) then return end

    local valid, phrase = GAMEMODE:TranslatedBind( "+reload" )
    if not valid then return GAMEMODE:UnboundHint( "+reload", "You can't set this down...", true ) end

    return true, "Hold " .. string.upper( phrase ) .. " to start PLACING this."

end

-- A copy of the carried entity's model, on the viewmodel's HeldModelBone this frame. Nil when there's
-- nothing to draw. Never parented, the viewmodel's shared by every weapon, and following one of its
-- bones went stale whenever another weapon swapped its model out. So it's placed fresh every draw
function SWEP:EnsureHeldModel( vm )
    local ent = self:GetCarriedEnt()
    if not IsValid( ent ) then return end

    local held = self.MyHeldModel
    if not IsValid( held ) or held:GetModel() ~= ent:GetModel() then
        SafeRemoveEntity( held )

        held = ClientsideModel( ent:GetModel() )
        if not IsValid( held ) then return end

        held:SetNoDraw( true )
        self.MyHeldModel = held

    end

    local bone = vm:LookupBone( self.HeldModelBone )
    if not bone then return end

    -- drawn after the viewmodel, so its bones, bone mods and all, are set up for this frame
    local matrix = vm:GetBoneMatrix( bone )
    if not matrix then return end

    local pos, ang = LocalToWorld( self.HeldModelPos, self.HeldModelAng, matrix:GetTranslation(), matrix:GetAngles() )
    held:SetPos( pos )
    held:SetAngles( ang )
    held:SetModelScale( self.HeldModelScale )
    held:SetSkin( ent:GetSkin() )
    held:SetupBones()

    return held

end

local scaleOne = Vector( 1, 1, 1 )

-- Every bone the mods move, scale included, once per viewmodel model.
-- Bone indices run parents first, so a parent's scale is always ready for its children
function SWEP:GetResolvedBoneMods( vm )
    local model = vm:GetModel()
    if self.glee_BoneModsModel == model then return self.glee_BoneMods end

    local mods = self.ViewModelBoneMods
    local list = {}
    local scales = {}

    for bone = 0, vm:GetBoneCount() - 1 do
        local mod = mods[vm:GetBoneName( bone )]
        local scale = mod and mod.scale or scaleOne

        local parent = vm:GetBoneParent( bone )
        if parent >= 0 then
            scale = scale * scales[parent]

        end
        scales[bone] = scale

        if mod or scale ~= scaleOne then
            list[#list + 1] = {
                bone = bone,
                scale = scale,
                pos = mod and mod.pos or vector_origin,
                angle = mod and mod.angle or angle_zero,
            }
        end
    end

    self.glee_BoneModsModel = model
    self.glee_BoneMods = list

    return list

end

-- Bone mods only last the frame they're drawn in, so a missed holster can't leave them on the next weapon.
-- Breaks with autorefresh, mods applied as this file reloads are forgotten and never reset
local manipulatedVM
local manipulatedBones

hook.Add( "PreRender", "glee_backpackable_resetviewmodelbones", function()
    if not manipulatedVM then return end

    if IsValid( manipulatedVM ) then
        for _, mod in ipairs( manipulatedBones ) do
            manipulatedVM:ManipulateBoneScale( mod.bone, scaleOne )
            manipulatedVM:ManipulateBoneAngles( mod.bone, angle_zero )
            manipulatedVM:ManipulateBonePosition( mod.bone, vector_origin )

        end
    end

    manipulatedVM = nil
    manipulatedBones = nil

end )

local invisMat = Material( "models/blackout/blackout" )

function SWEP:PreDrawViewModel( vm )
    if self.ViewModelBoneMods then
        local mods = self:GetResolvedBoneMods( vm )
        for _, mod in ipairs( mods ) do
            vm:ManipulateBoneScale( mod.bone, mod.scale )
            vm:ManipulateBoneAngles( mod.bone, mod.angle )
            vm:ManipulateBonePosition( mod.bone, mod.pos )

        end

        -- something may have set its bones up already this frame, before the mods
        vm:InvalidateBoneCache()

        manipulatedVM = vm
        manipulatedBones = mods

    end

    -- hidden only for this draw, so nothing carries over to the next weapon's viewmodel
    self.glee_HiddenMaterialCount = #vm:GetMaterials()
    for index = 0, self.glee_HiddenMaterialCount - 1 do
        render.MaterialOverrideByIndex( index, invisMat )

    end
end

-- The held model's drawn after the viewmodel, so it follows bones the mods already moved
function SWEP:PostDrawViewModel( vm )
    for index = 0, ( self.glee_HiddenMaterialCount or 0 ) - 1 do
        render.MaterialOverrideByIndex( index, nil )

    end
    self.glee_HiddenMaterialCount = nil

    local held = self:EnsureHeldModel( vm )
    if not held then return end

    held:DrawModel()

end
