AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "termhunt_manhack_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Explosive Box"
ENT.Author      = "TwoLemons"
ENT.Purpose     = ""
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.BombCountMin = 3
ENT.BombCountMax = 4
ENT.BombLaunchMin = 200
ENT.BombLaunchMax = 400
ENT.BombLaunchPitchMin = -45 -- Negative is upwards
ENT.BombLaunchPitchMax = 0 -- Negative is upwards
ENT.FirstBombNoLaunch = true
ENT.CreditThreshold = 0.15 -- At least this much (0-1) of the original damage must be dealt for score to count. Prevents cases where the victim is on the edge of the radius.

-- TNT Field Overrides
ENT.TNTDamage = 70
ENT.TNTRadius = 200
ENT.TNTDelayMin = 2.5
ENT.TNTDelayMax = 3.5
ENT.TNTDamageMultNPC = 3 -- Applies to NPCs and NextBots.
ENT.TNTEffectScale = 1.5


if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreGainedString = "Explosive Surprise Cost: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

local GM = GAMEMODE

function GM:BombCrate( pos, crateStatsRef )
    local crate = ents.Create( "prop_physics" )
    crate:SetModel( "models/Items/item_item_crate.mdl" )
    crate:SetPos( pos )
    local random = math.random( -4, 4 ) * 45
    crate:SetAngles( Angle( 0, random, 0 ) )
    crate:Spawn()

    crateStatsRef = crateStatsRef or baseclass.Get( "glee_bomb_crate" )

    crate.glee_IsBombCrate = true

    crate.glee_BombCrate_bombCount = math.random( crateStatsRef.BombCountMin, crateStatsRef.BombCountMax )
    crate.glee_BombCrate_bombLaunchMin = crateStatsRef.BombLaunchMin
    crate.glee_BombCrate_bombLaunchMax = crateStatsRef.BombLaunchMax
    crate.glee_BombCrate_bombLaunchPitchMin = crateStatsRef.BombLaunchPitchMin
    crate.glee_BombCrate_bombLaunchPitchMax = crateStatsRef.BombLaunchPitchMax
    crate.glee_BombCrate_firstBombNoLaunch = crateStatsRef.FirstBombNoLaunch
    crate.glee_BombCrate_creditThreshold = crateStatsRef.CreditThreshold

    crate.glee_BombCrate_damage = crateStatsRef.TNTDamage
    crate.glee_BombCrate_radius = crateStatsRef.TNTRadius
    crate.glee_BombCrate_delayMin = crateStatsRef.TNTDelayMin
    crate.glee_BombCrate_delayMax = crateStatsRef.TNTDelayMax
    crate.glee_BombCrate_damageMultNPC = crateStatsRef.TNTDamageMultNPC
    crate.glee_BombCrate_effectScale = crateStatsRef.TNTEffectScale

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

local function makeBomb( crate, noLaunch )
    local owner = crate.glee_BombCrate_player
    local damage = crate.glee_BombCrate_damage
    local vel = crate:GetPhysicsObject():GetVelocity()

    local bombAng = Angle( 0, math.Rand( -180, 180 ), 90 )
    bombAng:RotateAroundAxis( bombAng:Up(), math.Rand( -180, 180 ) )
    bombAng = crate:LocalToWorldAngles( bombAng )

    local bomb = ents.Create( "glee_timed_tnt" )
    bomb:SetPosCentered( crate:WorldSpaceCenter(), bombAng )
    bomb:Spawn()
    bomb.Damage = damage
    bomb.Radius = crate.glee_BombCrate_radius
    bomb.DelayMin = crate.glee_BombCrate_delayMin
    bomb.DelayMax = crate.glee_BombCrate_delayMax
    bomb.DamageMultNPC = crate.glee_BombCrate_damageMultNPC
    bomb.EffectScale = crate.glee_BombCrate_effectScale
    bomb:StartExplosionTimer()

    if not noLaunch then
        local ang = Angle(
            math.Rand( crate.glee_BombCrate_bombLaunchPitchMin, crate.glee_BombCrate_bombLaunchPitchMax ),
            math.Rand( -180, 180 ),
            0
        )

        vel = vel + ang:Forward() * math.Rand( crate.glee_BombCrate_bombLaunchMin, crate.glee_BombCrate_bombLaunchMax )

    end

    bomb:GetPhysicsObject():SetVelocity( vel )
    bomb.glee_IsBombCrateBomb = true
    bomb.glee_BombCrate_player = owner
    bomb.glee_BombCrate_creditThreshold = damage * crate.glee_BombCrate_creditThreshold

end

hook.Add( "PropBreak", "glee_spawn_rewarding_bombcrate", function( _, broken )
    if not broken.glee_IsBombCrate then return end

    local noFirstLaunch = broken.glee_BombCrate_firstBombNoLaunch

    for i = 1, broken.glee_BombCrate_bombCount do
        makeBomb( broken, noFirstLaunch and i == 1 )

    end

    for _ = 1, 5 do
        local creationPos = getCreationPos( broken )
        local score = ents.Create( "termhunt_score_pickup" )
        score:SetPos( creationPos )
        score:SetAngles( AngleRand() )
        score:Spawn()

    end
end )

hook.Add( "PostEntityTakeDamage", "glee_rewarding_bombcrate_reward", function ( target, dmg, took )
    if not took then return end
    if not dmg:IsExplosionDamage() then return end
    if not target:IsPlayer() and not target:IsNextBot() then return end

    local bomb = dmg:GetInflictor()
    if not IsValid( bomb ) then return end
    if not bomb.glee_IsBombCrateBomb then return end
    if bomb.glee_BombCrateSpent then return end

    local preScaledDamage = bomb.glee_TimedTNT_PreScaledDamage or dmg:GetDamage()
    if preScaledDamage < bomb.glee_BombCrate_creditThreshold then return end

    bomb.glee_BombCrateSpent = true

    local owner = bomb.glee_BombCrate_player
    if not IsValid( owner ) then return end
    if not owner.GivePlayerScore then return end

    if target:IsPlayer() then
        if target == owner then
            huntersGlee_Announce( { owner }, 5, 8, "You've been damaged by your own explosives..." )

        else
            owner:GivePlayerScore( 75 )
            huntersGlee_Announce( { owner }, 5, 8, "The explosives have damaged a player! You gain 75 score!" )

        end
    elseif target:IsNextBot() then
        owner:GivePlayerScore( 25 )
        huntersGlee_Announce( { owner }, 5, 8, "The explosives have damaged " .. GAMEMODE:GetNameOfBot( target ) .. ". You only gain 25 score." )

    end
end )

function ENT:Place()
    local betrayalScore = self:GetGivenScore()
    local crate = GM:BombCrate( self:OffsettedPlacingPos(), self )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        crate.glee_BombCrate_player = self.player
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    GAMEMODE:AddMischievousness( self.player, 4, "placed explosive supplies" )

    SafeRemoveEntity( self )

end
