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

ENT.ExplosionDamage = 80
ENT.ExplosionRadius = 150
ENT.ExplosionDelay = 3


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

function GM:BombCrate( pos, damage, radius, delay )
    local crate = ents.Create( "prop_physics" )
    crate:SetModel( "models/Items/item_item_crate.mdl" )
    crate:SetPos( pos )
    local random = math.random( -4, 4 ) * 45
    crate:SetAngles( Angle( 0, random, 0 ) )
    crate:Spawn()

    crate.glee_IsBombCrate = true
    crate.glee_BombCrate_damage = damage or 80
    crate.glee_BombCrate_radius = radius or 150
    crate.glee_BombCrate_delay = delay or 3

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

hook.Add( "PropBreak", "glee_spawn_rewarding_bombcrate", function( _, broken )
    if not broken.glee_IsBombCrate then return end

    local owner = broken.glee_BombCrate_player
    local damage = broken.glee_BombCrate_damage
    local radius = broken.glee_BombCrate_radius
    local delay = broken.glee_BombCrate_delay

    local bombAng = Angle( 0, math.Rand( -180, 180 ), 90 )
    bombAng:RotateAroundAxis( bombAng:Up(), math.Rand( -180, 180 ) )
    bombAng = broken:LocalToWorldAngles( bombAng )

    local bomb = ents.Create( "prop_physics" )
    bomb:SetModel( "models/dav0r/tnt/tnttimed.mdl" )

    -- Center the bomb (it has a bad origin)
    local bombPos = LocalToWorld( -bomb:OBBCenter(), Angle(), broken:WorldSpaceCenter(), bombAng )
    bomb:SetAngles( bombAng )
    bomb:SetPos( bombPos )
    bomb:Spawn()

    bomb.glee_IsBombCrateBomb = true

    for _ = 1, 5 do
        local creationPos = getCreationPos( broken )
        local score = ents.Create( "termhunt_score_pickup" )
        score:SetPos( creationPos )
        score:SetAngles( AngleRand() )
        score:Spawn()

    end

    timer.Simple( 0.2, function() -- Delay since sounds on fresh-spawned ents can fail networking
        bomb:EmitSound( "ambient/machines/ticktock.wav", 80, 255, 1 )
        bomb:EmitSound( "ambient/machines/ticktock.wav", 80, 255, 1 ) -- Quiet sound. Play it twice to boost the volume.

    end )

    timer.Simple( delay, function()
        if not IsValid( bomb ) then return end

        bomb:StopSound( "ambient/machines/ticktock.wav" )
        bomb:StopSound( "ambient/machines/ticktock.wav" )

        local pos = bomb:WorldSpaceCenter()
        local attacker = IsValid( owner ) and owner or bomb -- Still need an attacker if the owner left

        util.BlastDamage( bomb, attacker, pos, radius, damage )

        local eff = EffectData()
        eff:SetOrigin( pos )
        eff:SetMagnitude( 1 )
        eff:SetScale( 1 )
        eff:SetFlags( 0 )
        util.Effect( "Explosion", eff )

        SafeRemoveEntity( bomb )

    end )
end )

hook.Add( "PostEntityTakeDamage", "glee_rewarding_bombcrate_reward", function ( target, dmg, took )
    if not took then return end
    if not dmg:IsExplosionDamage() then return end
    if not target:IsPlayer() and not target:IsNextBot() then return end

    local crate = dmg:GetInflictor()
    if not IsValid( crate ) then return end
    if not crate.glee_IsBombCrateBomb then return end
    if crate.glee_BombCrateSpent then return end

    crate.glee_BombCrateSpent = true

    local owner = dmg:GetAttacker()
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
    local crate = GM:BombCrate( self:OffsettedPlacingPos(), self.ExplosionDamage, self.ExplosionRadius, self.ExplosionDelay )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        crate.glee_BombCrate_player = self.player
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    GAMEMODE:AddMischievousness( self.player, 4, "placed explosive supplies" )

    SafeRemoveEntity( self )

end
