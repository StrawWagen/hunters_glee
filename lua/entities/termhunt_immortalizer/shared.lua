AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

-- base ent for stuff that snaps to players and bots

ENT.Category    = "Other"
ENT.PrintName   = "Player Immortalizer"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Makes a player immortal"
ENT.Spawnable    = false
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.CanInstantlyProfit = false
ENT.CanProfitLater = false

if CLIENT then
    function ENT:DoHudStuff()
        local scoreGained = math.Round( self:GetGivenScore() )

        self:DrawPlacingLine( "Immortalizing Cost: " .. scoreGained )

        local target = self:GetCurrTarget()
        if IsValid( target ) and target:HasStatusEffect( "witness_me" ) then
            self:DrawPlacingLine( "WARNING: Witnessable...", "alert" )

        end
    end
end

function ENT:GetNearestTarget()
    local nearest = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all players within a radius of x units
    local stuff = ents.FindInSphere( myPos, 512 )
    for _, thing in ipairs( stuff ) do
        if ( thing:GetClass() == "player" or thing:IsNextBot() ) and thing:Health() > 0 then
            -- Calculate the distance between the ply and the entity
            local distance = myPos:DistToSqr( thing:GetPos() )
            if distance < nearestDistance then
                nearest = thing
                nearestDistance = distance

            end
        end
    end

    return nearest

end

function ENT:CalculateCanPlace()
    local targ = self:GetCurrTarget()
    if not IsValid( targ ) then return false, "Nothing to immortalize." end
    if targ:HasStatusEffect( "immortal" ) then return false, "That's already immortal." end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    local cooldown = targ.glee_immortCooldown
    if cooldown and cooldown > CurTime() then
        return false, "Cooldown: " .. math.ceil( targ.glee_immortCooldown - CurTime() ) .. "s."
    end
    return true

end

if not SERVER then return end

local newPlayerCostMul = 0.5

function ENT:UpdateGivenScore()
    if not IsValid( self:GetCurrTarget() ) then return end
    if self:GetCurrTarget():IsPlayer() then
        local cost = -300
        if GAMEMODE:IsFirstTimePlayer( self:GetCurrTarget() ) then
            cost = cost * newPlayerCostMul

        end
        self:SetGivenScore( cost )

    elseif self:GetCurrTarget():IsNextBot() then
        self:SetGivenScore( -200 )

    end
end

local rics = {
    "weapons/fx/rics/ric3.wav",
    "weapons/fx/rics/ric5.wav",
}

local immortalTime = 21 -- seconds
local immortCooldown = 25 -- per target, from when it was placed

-- What each point of blocked damage costs the placer. One hit's damage is billed in two tiers of the target's max health
local scorePerDamage = 0.1 -- up to fullCostHealthMul times max health
local fullCostHealthMul = 2
local overkillScorePerDamage = 0.05 -- past that, up to damageClampMul times max health
local damageClampMul = 10 -- the rest is free, some npcs deal math.huge
local nonPlayerCostMul = 0.75 -- for hunters, and anything else that isn't a player

local function endSounds( owner )
    owner:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    owner:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 40, 1, CHAN_STATIC )
    owner:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    owner:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 80, 1, CHAN_STATIC )

end

-- every hit in one tick shows, and sounds, as one charge, a shotgun blast isn't a fountain of them
local function queueCostPopup( effect, owner, charged )
    local queued = effect.queuedPopupCost
    effect.queuedPopupCost = queued + charged
    if queued > 0 then return end

    local placer = effect.placer
    timer.Simple( 0, function()
        local cost = effect.queuedPopupCost
        effect.queuedPopupCost = 0
        if not IsValid( placer ) then return end

        GAMEMODE:sendPurchaseConfirm( placer, -cost )
        if not IsValid( owner ) then return end

        GAMEMODE:SendPlacableScorePopup( placer, owner, -cost )

    end )
end

-- Bills the placer for one blocked hit. Returns whether they still have money left after
local function chargePlacer( effect, owner, damageDealt )
    local placer = effect.placer

    local maxHealth = owner:GetMaxHealth()
    local counted = math.Clamp( damageDealt, 0, maxHealth * damageClampMul )
    local fullCostDamage = math.min( counted, maxHealth * fullCostHealthMul )
    local overkillDamage = counted - fullCostDamage

    local cost = fullCostDamage * scorePerDamage + overkillDamage * overkillScorePerDamage
    if not owner:IsPlayer() then
        cost = cost * nonPlayerCostMul

    elseif GAMEMODE:IsFirstTimePlayer( owner ) then
        cost = cost * newPlayerCostMul

    end
    effect.owedScore = effect.owedScore + cost

    -- score is a whole number, so the fractions wait for the next hit
    local owed = math.floor( effect.owedScore )
    if owed > 0 then
        effect.owedScore = effect.owedScore - owed

        local charged = math.min( owed, math.max( placer:GetScore(), 0 ) )
        if charged > 0 then
            placer:GivePlayerScore( -charged )
            queueCostPopup( effect, owner, charged )

        end
    end

    return placer:GetScore() > 0

end

function ENT:Place()
    local target = self:GetCurrTarget()

    if not IsValid( target ) then return end

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( target:GetShootPos() ) ) do
        if not thing:IsPlayer() then continue end
        if thing == target then continue end

        table.insert( plysToAlert, thing )

    end

    local targetName = GAMEMODE:GetNameOfBot( target )
    local advice = GAMEMODE:LooksLikePlayer( target ) and "SUGGESTED ACTION: Use " .. targetName .. " as cover." or "RETREAT, Avoid " .. targetName .. "."
    huntersGlee_NotifyLivingAndDead( plysToAlert, {
        text = "ANOMALOUS ENERGY DETECTED",
        description = GAMEMODE:SuitNameOf( self.player ) .. " has gifted likely immortality to " .. targetName .. ".\n" .. advice,
        time = 12,
    }, {
        text = self.player:Nick() .. " has gifted immortality to " .. targetName,
        time = 12,
    } )

    if target:IsPlayer() then
        huntersGlee_Announce( { target }, 10, 10, "Something's off, you feel strong, you feel... Immortal.\n" .. self.player:Nick() .. " has gifted you temporary Immortality." )

    end

    target:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 80, 1, CHAN_STATIC )
    target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 120, 1, CHAN_STATIC )

    util.ScreenShake( target:GetPos(), 40, 20, 1.5, 1500, true )

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end

    if target:IsPlayer() then
        -- one forgiveness per person immortalized, so nobody farms it off the same target
        GAMEMODE.roundExtraData.hasImmortalizedTbl = GAMEMODE.roundExtraData.hasImmortalizedTbl or {}
        if GAMEMODE:GetStoredPersistentGuilt( self.player ) > 0 and not GAMEMODE.roundExtraData.hasImmortalizedTbl[target] then
            GAMEMODE.roundExtraData.hasImmortalizedTbl[target] = true
            local isFirst = GAMEMODE:IsFirstTimePlayer( target )
            local reduction = isFirst and -0.5 or -0.05
            local msg = isFirst and "A new soul!\nYour guilt lifts..." or "Your guilt barely lifts..."

            GAMEMODE:IncrementPersistentGuilt( self.player, reduction, msg )

        end
    else
        GAMEMODE:AddMischievousness( self.player, 1, "immortalized a hunter..." )

    end

    local effect = target:GiveStatusEffect( "immortal" )
    if effect then
        effect.placer = self.player

    end

    self:DetachFromOwner()
    target.glee_immortCooldown = CurTime() + immortCooldown

    SafeRemoveEntity( self )

end

if not GAMEMODE.IsReallyHuntersGlee then return end

GAMEMODE:RegisterStatusEffect( "immortal",
    function( self, owner ) -- setup
        self:SetPlyRemoveOnDeath( true )
        self.owedScore = 0
        self.queuedPopupCost = 0
        self.secondsLeft = immortalTime

        self:Hook( "EntityTakeDamage", function( victim, damage )
            if victim ~= owner then return end

            -- self.placer is set by whoever gave this, right after setup
            if not IsValid( self.placer ) then owner:RemoveStatusEffect( "immortal" ) return end

            -- a witnessed death can't be shrugged off, it takes everything the placer has, and the immortality with it
            local damageAttacker = damage:GetAttacker()
            local witnessAttacker = victim.gleeWitness_Attacker
            local fromWitness = IsValid( witnessAttacker ) and witnessAttacker == damageAttacker
            local fromWitnessWorld = victim.gleeWitness_WorldAttacker and damageAttacker == game.GetWorld()
            if fromWitness or fromWitnessWorld then
                local placer = self.placer
                local everything = math.max( placer:GetScore(), 0 )
                if everything > 0 then
                    placer:GivePlayerScore( -everything )
                    queueCostPopup( self, owner, everything )

                end

                self.ranOutOfMoney = true
                owner:RemoveStatusEffect( "immortal" )
                return

            end

            if damage:IsBulletDamage() then
                owner:EmitSound( table.Random( rics ), 75, math.random( 92, 100 ), 1, CHAN_STATIC )

            end

            local damageDealt = damage:GetDamage()
            local effectsDamage = math.Clamp( damageDealt, 0, 5000 ) -- sanity clamp, eg supercop

            local path = "physics/metal/metal_barrel_impact_hard" .. math.random( 5, 7 ) .. ".wav"
            local pit = 120 + ( -effectsDamage / 10 )
            owner:EmitSound( path, 85, pit, 1, CHAN_STATIC )

            GAMEMODE:GivePanic( owner, effectsDamage / 4 )

            damage:SetDamageForce( damage:GetDamageForce() * effectsDamage )
            damage:ScaleDamage( 0 )

            util.ScreenShake( owner:GetPos(), effectsDamage / 2, 20, effectsDamage / 1000, 1500, true )

            local stillPaying = chargePlacer( self, owner, damageDealt )
            if not stillPaying then
                self.ranOutOfMoney = true
                owner:RemoveStatusEffect( "immortal" )

            end

            return true

        end )

        self:Timer( "countdown", 1, 0, function()
            if not IsValid( self.placer ) then owner:RemoveStatusEffect( "immortal" ) return end

            self.secondsLeft = self.secondsLeft - 1
            local secondsLeft = self.secondsLeft

            if secondsLeft <= 0 then
                owner:RemoveStatusEffect( "immortal" )
                return

            end

            if secondsLeft <= 8 then
                owner:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 80, 80 + secondsLeft * 2, 1, CHAN_STATIC )
                if owner:IsPlayer() then
                    huntersGlee_Notify( { owner }, {
                        text = "IMMORTALITY FAILING " .. secondsLeft,
                        description = "SUGGESTED ACTION: Seek cover.",
                        kind = "bad",
                        time = 1.5,
                        replaceKey = "immortality_countdown",
                    } )

                end
            end
        end )
    end,
    function( self, owner ) -- teardown
        if not IsValid( owner ) then return end

        endSounds( owner )

        if owner:IsPlayer() then
            huntersGlee_CancelNotify( { owner }, "immortality_countdown" )

        end

        if not self.ranOutOfMoney then return end

        if IsValid( self.placer ) then
            local name = owner:IsPlayer() and owner:Nick() or GAMEMODE:GetNameOfBot( owner )
            huntersGlee_Notify( { self.placer }, {
                text = name .. "'s cost of immortality has ballooned too much...",
                kind = "bad",
                time = 10,
                style = "soulthought",
            } )

        end
        if owner:IsPlayer() then
            huntersGlee_Announce( { owner }, 10, 4, "Your immortality FAILS?!\nThe funder has run out of Score..." )

        end
    end
)
