AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "termhunt_manhack_crate"

ENT.Category    = "Other"
ENT.PrintName   = "TNT Box"
ENT.Author      = "TwoLemons"
ENT.Purpose     = ""
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.CrateCountMin = 1
ENT.CrateCountMax = 2
ENT.CrateLaunchMin = 50
ENT.CrateLaunchMax = 125
ENT.CrateLaunchPitchMin = -45 -- Negative is upwards
ENT.CrateLaunchPitchMax = 0 -- Negative is upwards
ENT.CreditThreshold = 15 -- At least this much damage must be dealt for score to count. Gotta really get em!

-- TNT Field Overrides
ENT.TNTDamage = 250
ENT.TNTRadius = 400
ENT.TNTDelayMin = 4
ENT.TNTDelayMax = 4.5 -- just enough variance so they dont explode at the same exact time
ENT.TNTEffectScale = 2


if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreGainedString = "TNT Cost: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

local GM = GAMEMODE

ENT.SuperCloseCost = -200
ENT.CloseCost = -75
ENT.FarCost = 50

local MEMORY_BREAKABLE = terminator_Extras.botMemoryTypes.MEMORY_BREAKABLE

function GM:BombCrate( pos, crateStatsRef )
    local crate = ents.Create( "prop_physics" )
    crate:SetModel( "models/Items/item_item_crate.mdl" )
    crate:SetPos( pos )
    local random = math.random( -4, 4 ) * 45
    crate:SetAngles( Angle( 0, random, 0 ) )
    crate:Spawn()

    crateStatsRef = crateStatsRef or baseclass.Get( "glee_tnt_crate" )

    crate.glee_IsTNTCrate = true

    crate.glee_TNT_CrateCount = math.random( crateStatsRef.CrateCountMin, crateStatsRef.CrateCountMax )
    crate.glee_TNT_CrateLaunchMin = crateStatsRef.CrateLaunchMin
    crate.glee_TNT_CrateLaunchMax = crateStatsRef.CrateLaunchMax
    crate.glee_TNT_CrateLaunchPitchMin = crateStatsRef.CrateLaunchPitchMin
    crate.glee_TNT_CrateLaunchPitchMax = crateStatsRef.CrateLaunchPitchMax
    crate.glee_TNT_CrateCreditThreshold = crateStatsRef.CreditThreshold

    crate.glee_TNT_Crate_damage = crateStatsRef.TNTDamage
    crate.glee_TNT_Crate_radius = crateStatsRef.TNTRadius
    crate.glee_TNT_Crate_delayMin = crateStatsRef.TNTDelayMin
    crate.glee_TNT_Crate_delayMax = crateStatsRef.TNTDelayMax
    crate.glee_TNT_Crate_effectScale = crateStatsRef.TNTEffectScale

    -- make the bots try to break this!
    crate.terminatorHunterInnateReaction = function()
        return MEMORY_BREAKABLE

    end

    return crate

end

local function getCreationPos( ent )
    local creationPos = ent:GetPos() + ( VectorRand() * ent:GetModelRadius() )
    creationPos = ent:WorldToLocal( ent:NearestPoint( creationPos ) )
    creationPos = creationPos * 0.6
    return ent:LocalToWorld( creationPos )

end

local function makeBomb( crate )
    local owner = crate.glee_TNT_Crate_player
    local damage = crate.glee_TNT_Crate_damage
    local vel = crate:GetPhysicsObject():GetVelocity()

    local bombAng = Angle( 0, math.Rand( -180, 180 ), 90 )
    bombAng:RotateAroundAxis( bombAng:Up(), math.Rand( -180, 180 ) )
    bombAng = crate:LocalToWorldAngles( bombAng )

    local bomb = ents.Create( "glee_timed_tnt" )
    if not IsValid( bomb ) then return end

    bomb:SetPosCentered( crate:WorldSpaceCenter(), bombAng )
    bomb.Damage = damage
    bomb.Radius = crate.glee_TNT_Crate_radius
    bomb.DelayMin = crate.glee_TNT_Crate_delayMin
    bomb.DelayMax = crate.glee_TNT_Crate_delayMax
    bomb.EffectScale = crate.glee_TNT_Crate_effectScale

    bomb:Spawn()

    local ang = Angle(
        math.Rand( crate.glee_TNT_CrateLaunchPitchMin, crate.glee_TNT_CrateLaunchPitchMax ),
        math.Rand( -180, 180 ),
        0
    )

    vel = vel + ang:Forward() * math.Rand( crate.glee_TNT_CrateLaunchMin, crate.glee_TNT_CrateLaunchMax )

    bomb:GetPhysicsObject():SetVelocity( vel )
    bomb.glee_IsTNTCrateBomb = true
    bomb.glee_TNT_Crate_player = owner
    bomb.glee_TNT_Crate_creditThreshold = damage * crate.glee_TNT_CrateCreditThreshold

end

hook.Add( "PropBreak", "glee_spawn_rewarding_tnt_crate", function( _, broken )
    if not broken.glee_IsTNTCrate then return end

    for _ = 1, broken.glee_TNT_CrateCount do
        makeBomb( broken )

    end

    for _ = 1, 5 do
        local creationPos = getCreationPos( broken )
        local score = ents.Create( "termhunt_score_pickup" )
        score:SetPos( creationPos )
        score:SetAngles( AngleRand() )
        score:Spawn()

    end
end )

hook.Add( "PostEntityTakeDamage", "glee_rewarding_tnt_crate_reward", function ( target, dmg, took )
    if not took then return end
    if not dmg:IsExplosionDamage() then return end
    if not target:IsPlayer() and not target:IsNextBot() then return end

    local bomb = dmg:GetInflictor()
    if not IsValid( bomb ) then return end
    if not bomb.glee_IsTNTCrateBomb then return end
    if bomb.glee_TNT_CrateSpent then return end

    local preScaledDamage = dmg:GetDamage()
    if preScaledDamage < bomb.glee_TNT_Crate_creditThreshold then return end

    bomb.glee_TNT_CrateSpent = true

    local owner = bomb.glee_TNT_Crate_player
    if not IsValid( owner ) then return end
    if not owner.GivePlayerScore then return end

    if target:IsPlayer() then
        if target == owner then
            huntersGlee_Announce( { owner }, 5, 8, "You've been damaged by your own Timed TNT..." )

        else
            owner:GivePlayerScore( 75 )
            huntersGlee_Announce( { owner }, 5, 8, "Your timed TNT damaged a player! You gain 75 score!" )

        end
    elseif target:IsNextBot() or target:IsNPC() then
        owner:GivePlayerScore( 25 )
        huntersGlee_Announce( { owner }, 5, 8, "Your timed TNT damaged " .. GAMEMODE:GetNameOfBot( target ) .. ". You only gain 25 score." )

    end
end )

function ENT:Place()
    local betrayalScore = self:GetGivenScore()
    local crate = GM:BombCrate( self:OffsettedPlacingPos(), self )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        crate.glee_TNT_Crate_player = self.player
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    GAMEMODE:AddMischievousness( self.player, 6, "placed timed tnt" )

    SafeRemoveEntity( self )

end
