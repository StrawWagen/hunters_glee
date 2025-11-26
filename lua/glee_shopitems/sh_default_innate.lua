
local shopHelpers = GAMEMODE.shopHelpers

if SERVER then
    local speedBoostBeginsAt = 95
    local bpmToSpeedScale = 4

    GAMEMODE:RegisterStatusEffect( "cold_blooded",
        function( self, owner ) -- setup func
            self:Timer( "manage_coldblooded", 0.1, 0, function()
                local BPM = owner:GetNWInt( "termHuntPlyBPM" ) or 60
                local usefulBPM = BPM - speedBoostBeginsAt
                usefulBPM = usefulBPM * bpmToSpeedScale

                owner:doSpeedModifier( "coldblooded", usefulBPM )

            end )
        end,
        function( self, owner ) -- teardown func, disables the speedmodifier
            owner:doSpeedModifier( "coldblooded", nil )

        end
    )

    GAMEMODE:RegisterStatusEffect( "superior_metabolism",
        function( self, owner ) -- setup func
            self:Hook( "huntersglee_heartbeat_beat", function( ply )
                if ply ~= owner then return end

                local amount = 1

                local newHealth = math.Clamp( owner:Health() + amount, 0, owner:GetMaxHealth() )
                owner:SetHealth( newHealth )

            end )
        end
    )

    GAMEMODE:RegisterStatusEffect( "deafness",
        function( self, owner ) -- setup func
            owner.glee_IsDeaf = true

            function self:GiveDeaf()
                local effectOwner = self:GetOwner()
                effectOwner:SetDSP( 31 )

            end
            function self:UnDeafInternal()
                local effectOwner = self:GetOwner()
                effectOwner:SetDSP( 1 )

            end

            self:Timer( "manage_deafness", 0.1, 0, function()
                if owner:Health() <= 0 then self:UnDeafInternal() return end
                self:GiveDeaf()

            end )
        end,
        function( self, owner ) -- teardown func
            self:UnDeafInternal()
            owner.glee_IsDeaf = false

        end
    )
end



local function bloodDonorCanPurchase( purchaser )
    if purchaser:Health() <= 1 then return false, "You don't have any blood to donate!" end
    return true, ""

end

local function bloodDonorCalc( purchaser )
    local beginningHealth = purchaser:Health()
    local remainingHealth = beginningHealth - 100
    remainingHealth = math.Clamp( remainingHealth, 1, math.huge )

    local scoreGiven = math.abs( beginningHealth - remainingHealth ) * 1.15
    scoreGiven = math.ceil( scoreGiven )

    return scoreGiven, remainingHealth

end

local function bloodDonorCost( purchaser )
    return -bloodDonorCalc( purchaser )

end

local items = {
    -- Risk vs reward.
    [ "blooddonor" ] = {
        name = "Donate Blood.",
        desc = "Donate blood for score.",
        shCost = bloodDonorCost,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE, -- only purchasble when actively hunting, otherwise people would heal with cheap preround healthkits
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, bloodDonorCanPurchase },
        svOnPurchaseFunc = function( purchaser )
            local scoreGiven, remainingHealth = bloodDonorCalc( purchaser )

            GAMEMODE:Bleed( purchaser, scoreGiven )

            purchaser:GivePlayerScore( scoreGiven )

            purchaser:SetHealth( remainingHealth )

            for _ = 0, 2 do
                shopHelpers.playRandomSound( purchaser, shopHelpers.thwaps, 75, math.random( 100, 120 ) )

            end
        end,
    },
    [ "deafness" ] = {
        name = "Hard of Hearing.",
        desc = "You can barely hear a thing!",
        shCost = -75,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "deafness" )

        end,
    },
    [ "coldblooded" ] = {
        name = "Cold Blooded.",
        desc = "Your top speed is linked to your heartrate.",
        shCost = 150,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "cold_blooded" )

        end,
    },
    -- flat upgrade
    [ "superiormetabolism" ] = {
        name = "Superior Metabolism.",
        desc = "You've always been different than those around you.\nWhat would hospitalize others for weeks, passed over you in days.\nYou regenerate health as your heart beats.",
        shCost = 200,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "superior_metabolism" )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )