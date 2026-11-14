AddCSLuaFile()

ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName   = "Riot Shield"
ENT.Author      = "dedactedlife and IndefiniteXD"
ENT.Purpose     = "No bullets shall pass!"
ENT.Spawnable   = true
ENT.AdminOnly   = game.IsDedicated()
ENT.Category    = "Hunter's Glee"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "materials/entities/glee_backpackable_shield.png"

ENT.Model = "models/glee/weapons/shield/w_riot_shield.mdl"
ENT.GunModel = "models/glee/weapons/shield/w_riot_shield.mdl"

local glee_Carrying = terminator_Extras.glee_Carrying

if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, "glee_shield", "materials/entities/glee_backpackable_shield.png" )

end

glee_Carrying.MakeCarryable( ENT, "glee_backpackable_shield" )

-- Three parts
-- drawing, in cl_draw.lua, the shield bent further out of shape as it wears down
-- the shield's own health, where every hit plays its effects
-- and the "glee_shield_resist" hook, moving damage from anything behind it onto the shield

local shieldHealth = 2500
local armour = 25 -- hits under this do nothing to the shield itself

-- how much of each type a shield in the way takes off, 1 blocks it all
-- damage with several types gets the best of them
-- burn, shock, acid and the like are left through, they're what gets past a shield
local resists = {
    [DMG_BULLET] = 1,
    [DMG_BUCKSHOT] = 1,
    [DMG_BLAST] = 0.5,
    [DMG_CLUB] = 0.9,
    [DMG_SLASH] = 0.9,
    [DMG_CRUSH] = 0.75,
}

-- melee comes in every shape, the hit position can't be trusted
-- terminator fists put it mid air when their trace misses, see weapon_terminatorfists_term's DealDamage
local meleeTypes = bit.bor( DMG_CLUB, DMG_SLASH, DMG_CRUSH )

-- played where the shield was hit, bullets ricochet on top
-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=2694129699 for porting these
local impactSound = {
    sounds = {
        "hunters_glee/riotshield/impact_riotshield_01.wav",
        "hunters_glee/riotshield/impact_riotshield_02.wav",
        "hunters_glee/riotshield/impact_riotshield_03.wav",
        "hunters_glee/riotshield/impact_riotshield_04.wav",
        "hunters_glee/riotshield/impact_riotshield_05.wav",
    },
    -- hits under the armour tink, so you can hear they did nothing
    light = {
        level = 65,
        pitch = { 115, 125 },
        volume = 0.5,
    },
    -- hits over it go from the first to the second, the more damage, up to heaviestHit
    heavy = {
        level = { 75, 90 },
        pitch = { 105, 80 },
        heaviestHit = 200,
    },
}

-- terminator_nextbot's, off its armour
local ricochetSound = {
    level = 75,
    pitch = { 92, 100 },
    sounds = {
        "weapons/fx/rics/ric3.wav",
        "weapons/fx/rics/ric5.wav",
    },
}

-- kicks the carrier's view away from the hit, by how much damage the shield took
local resistPunch = {
    perDamage = 0.1, -- degrees
    max = 10,
}

-- shoves the carrier the way the hit was going, by how much damage the shield took, like the tau cannon's recoil
-- it only throws them far once they're already off the floor
-- on it, crouching braces, it's pushed into the floor instead
local resistKnock = {
    perDamage = 3, -- units a second
    max = 600,
    grounded = 0.25, -- of that, standing or crouched on the floor
}

-- damage the shield isn't meant to stop, like fire or shock, kicks the carrier this much as hard
-- see resists
local unresistedKick = 0.5

-- big hits rattle the carrier, for each point of damage over bigHit, see GM:GivePanic
-- taking damage for real gives a point per 10
local resistPanic = {
    bigHit = 75,
    perDamage = 0.2,
    airborne = 2, -- times as much, off their feet when it landed
}

-- Drawing
if SERVER then
    AddCSLuaFile( "cl_draw.lua" )

else
    include( "cl_draw.lua" )

end

-- every shield there is, placed or carried
-- carried ones are still the real entity, riding the carrier, see glee_backpackable_base's StartCarrying
local shields = {}

-- autorefresh empties the table above, and the shields already out never Initialize again
for _, shield in ipairs( ents.FindByClass( "glee_shield" ) ) do
    shields[shield] = true

end

function ENT:SetupDataTables()
    self:NetworkVar( "Float", "Wear" ) -- 0 to 1, health lost

end

function ENT:Initialize()
    self:SetModel( self.Model )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:DrawShadow( true )

    if SERVER then
        self:SetMaxHealth( shieldHealth )
        self:SetHealth( shieldHealth )
        shields[self] = true

        local myObj = self:GetPhysicsObject()
        if IsValid( myObj ) then
            myObj:SetMass( 250 )

        end
    end
end

function ENT:OnRemove()
    shields[self] = nil
    if CLIENT then
        self:DestroyMeshes()

    end
end

if not SERVER then return end

-- the best resist dmg's types get, 0 for none
local function resistFor( dmg )
    local dmgType = dmg:GetDamageType()
    local best = 0
    for type, resist in pairs( resists ) do
        if bit.band( dmgType, type ) ~= 0 and resist > best then
            best = resist

        end
    end
    return best

end

-- what fired a bullet or swung, a turret's inflictor is itself while its attacker is whoever owns it
local function shooterPos( dmg )
    local shooter = dmg:GetInflictor()
    if not IsValid( shooter ) or shooter:IsWeapon() then
        shooter = dmg:GetAttacker()

    end
    if not IsValid( shooter ) then return end

    if shooter.GetShootPos then return shooter:GetShootPos() end
    return shooter:WorldSpaceCenter()

end

-- the line the damage travelled, from, to, and its damage position
-- bullets go shooter to where they hit
-- melee goes swinger to the nearest bit of victim
-- the rest go from their damage position, explosions give their centre, to the nearest bit of victim
local function damageLine( dmg, victim )
    local pos = dmg:GetDamagePosition()
    if pos == vector_origin then
        local inflictor = dmg:GetInflictor()
        if not IsValid( inflictor ) then return end

        pos = inflictor:WorldSpaceCenter()

    end

    if dmg:IsBulletDamage() or dmg:IsDamageType( DMG_BUCKSHOT ) then
        local shooter = shooterPos( dmg )
        if shooter then return shooter, pos, pos end

    elseif bit.band( dmg:GetDamageType(), meleeTypes ) ~= 0 then
        local swinger = shooterPos( dmg )
        if swinger then return swinger, victim:NearestPoint( swinger ), pos end

    end

    return pos, victim:NearestPoint( pos ), pos

end

-- where the line from, to crosses shield, or the damage position if it's inside it
-- nil when shield isn't in the way
local function wherePastShield( shield, from, to, pos )
    local mins, maxs = shield:OBBMins(), shield:OBBMaxs()
    if shield:WorldToLocal( pos ):WithinAABox( mins, maxs ) then return pos end

    return util.IntersectRayWithOBB( from, to - from, shield:GetPos(), shield:GetAngles(), mins, maxs )

end

-- sound.Play goes out on CHAN_STATIC, so a shotgun's pellets all play over each other
local function playHitSound( dmg, damage, pos )
    local path = impactSound.sounds[math.random( #impactSound.sounds )]
    if damage < armour then
        local light = impactSound.light
        sound.Play( path, pos, light.level, math.random( light.pitch[1], light.pitch[2] ), light.volume )

    else
        local heavy = impactSound.heavy
        local heft = math.Clamp( ( damage - armour ) / ( heavy.heaviestHit - armour ), 0, 1 )
        local level = math.Round( Lerp( heft, heavy.level[1], heavy.level[2] ) )
        local pitch = math.Round( Lerp( heft, heavy.pitch[1], heavy.pitch[2] ) )
        sound.Play( path, pos, level, pitch )

    end

    if dmg:IsBulletDamage() or dmg:IsDamageType( DMG_BUCKSHOT ) then
        local ricochet = ricochetSound.sounds[math.random( #ricochetSound.sounds )]
        sound.Play( ricochet, pos, ricochetSound.level, math.random( ricochetSound.pitch[1], ricochetSound.pitch[2] ) )

    end
end

-- view punch, panic and knockback, see resistPunch, resistPanic and resistKnock
-- a carried shield's owner is its carrier, see glee_backpackable_base's StartCarrying
-- travel is the way the hit was going, nil when nothing shot or swung it, then it's just a punch straight back
local function kickOwner( shield, damage, travel )
    local owner = shield:GetOwner()
    if not IsValid( owner ) or not owner:IsPlayer() then return end

    -- Hunter's Glee only, the shield works in sandbox too
    if GAMEMODE.GivePanic and damage > resistPanic.bigHit then
        local panic = ( damage - resistPanic.bigHit ) * resistPanic.perDamage
        if not owner:OnGround() then
            panic = panic * resistPanic.airborne

        end
        GAMEMODE:GivePanic( owner, panic )

    end

    local punchDir = travel or owner:GetAimVector()
    local side = punchDir:Dot( owner:EyeAngles():Right() ) -- 1 when the hit came from the left

    local punch = math.min( damage * resistPunch.perDamage, resistPunch.max )
    owner:ViewPunch( Angle( -punch * ( 1 - math.abs( side ) ), -side * punch, 0 ) )

    if not travel then return end

    local knockDir = Vector( travel )
    local knock = math.min( damage * resistKnock.perDamage, resistKnock.max )
    if owner:OnGround() then
        knock = knock * resistKnock.grounded
        if owner:Crouching() then
            knockDir.z = knockDir.z - 1
            knockDir:Normalize()

        end
    end
    owner:SetVelocity( knockDir * knock )

end

function ENT:OnTakeDamage( dmg )
    if self.glee_Broken then return end

    self:TakePhysicsDamage( dmg )

    local damage = dmg:GetDamage()

    local pos = dmg:GetDamagePosition()
    if pos == vector_origin then
        pos = self:WorldSpaceCenter()

    end
    local from = shooterPos( dmg )
    local travel = from and ( pos - from ):GetNormalized()

    playHitSound( dmg, damage, pos )

    -- never from their own damage, a carrier's stray shot or blast shouldn't shove them
    if dmg:GetAttacker() ~= self:GetOwner() then
        local kick = resistFor( dmg ) > 0 and 1 or unresistedKick
        kickOwner( self, damage * kick, travel )

    end

    if damage < armour then return end

    self:SetHealth( self:Health() - damage )
    self:SetWear( 1 - self:Health() / self:GetMaxHealth() )
    if self:Health() > 0 then return end

    self.glee_Broken = true
    self:EmitSound( "physics/metal/metal_box_break" .. math.random( 1, 2 ) .. ".wav", 80, math.random( 90, 100 ) )
    SafeRemoveEntity( self )

end

hook.Add( "EntityTakeDamage", "glee_shield_resist", function( victim, dmg )
    if shields[victim] then return end

    local resist = resistFor( dmg )
    if resist <= 0 then return end

    local from, to, pos = damageLine( dmg, victim )
    if not from then return end

    for shield in pairs( shields ) do
        local blockedAt = IsValid( shield ) and wherePastShield( shield, from, to, pos )
        if blockedAt then
            -- the shield's own damage lands back in this hook, shields[victim] lets it through
            local blocked = DamageInfo()
            blocked:SetDamage( dmg:GetDamage() * resist )
            blocked:SetDamageType( dmg:GetDamageType() )
            blocked:SetAttacker( dmg:GetAttacker() )
            blocked:SetInflictor( dmg:GetInflictor() )
            blocked:SetDamagePosition( blockedAt )
            blocked:SetDamageForce( dmg:GetDamageForce() * resist )
            shield:TakeDamageInfo( blocked )

            if resist >= 1 then return true end

            dmg:ScaleDamage( 1 - resist )
            return

        end
    end
end )
