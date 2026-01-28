
local shopHelpers = GAMEMODE.shopHelpers

-- shared by all placable items
local function ghostCanPurchase( purchaser )
    if IsValid( purchaser.ghostEnt ) then return false, "You're already placing something!\nPlace it, or right click to CANCEL placing it!" end
    return true

end

local function setupPlacable( class, purchaser, itemIdentifier )
    local thing = ents.Create( class )
    thing.itemIdentifier = itemIdentifier
    thing:SetOwner( purchaser )
    thing:Spawn()

    return thing

end

if SERVER then
    GAMEMODE:RegisterStatusEffect( "linked_hunter",
        function( self, owner ) -- setup func
            self.spawnHunterTimerName = self:Timer( "spawnHunter", 0.2, 0, function()
                local hunter = GAMEMODE:SpawnHunter( "terminator_nextbot_snail_disguised" )
                if not IsValid( hunter ) then return end

                if hunter.MimicPlayer then
                    hunter:MimicPlayer( owner )

                end

                SetGlobal2Entity( "glee_linkedhunter", hunter )
                GAMEMODE.roundExtraData.extraHunter = hunter

                self.hunter = hunter
                hunter.linkedPlayer = owner

                if owner:Health() <= 0 then
                    GAMEMODE:SpectateThing( owner, hunter )

                end

                timer.Remove( self.spawnHunterTimerName )

            end )

            self:Hook( "huntersglee_plykilledhunter", function( killer, hunter )
                if hunter ~= self.hunter then return end
                if killer ~= owner then return end

                local reward = 550
                killer:GivePlayerScore( reward )

                huntersGlee_Announce( { killer }, 50, 10, "You feel at peace, a weight has been lifted.\nThe doppleganger is dead...\n+" .. reward .. " score." )

            end )
        end,
        function( self, owner ) -- teardown func
            if IsValid( self.hunter ) then
                self.hunter.linkedPlayer = nil

            end
        end
    )
end

local items = {
    [ "screamcrate" ] = {
        name = "Beaconed Supplies",
        desc = "Supplies with a beacon.\nBetray the others for score.\nCosts 75 to place.\nRefund upon first beacon transmit.",
        shCost = 0,
        markup = 1,
        cooldown = 60,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -5,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "screamer_crate", purchaser, itemIdentifier )

        end,
    },
    [ "normcrate" ] = {
        name = "Supplies",
        desc = "Supplies without a beacon.\nContains health, armour, rarely a weapon, special ammunition.\nPlace indoors, and far away from players and other supplies, for more score.",
        shCost = 0,
        markup = 1,
        cooldown = 10,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -4,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_normal_crate", purchaser, itemIdentifier )

        end,
    },
    [ "weapcrate" ] = {
        name = "Crate of Weapons",
        desc = "Supply crate with 5 weapons in it\nPlace indoors, and far away from players and other supplies, for more score.",
        shCost = 0,
        markup = 1,
        cooldown = 55,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_weapon_crate", purchaser, itemIdentifier )

        end,
    },
    [ "manhackcrate" ] = {
        name = "Crate with Manhacks",
        desc = "Supply crate with 5 manhacks in it.\nGives score when the manhacks damage stuff.",
        shCost = 0,
        markup = 1,
        cooldown = 80,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 10,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_manhack_crate", purchaser, itemIdentifier )

        end,
    },
    [ "undeadbeartrap" ] = {
        name = "Beartrap.",
        desc = "Beartrap.\nWhen a player, hunter, steps on it, you get a reward.\nCosts more to place it near the living, and intersecting objects.",
        shCost = 0,
        markup = 1,
        cooldown = 15,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_undead_beartrap", purchaser, itemIdentifier )

        end,
    },
    [ "barrels" ] = {
        name = "Barrels",
        desc = "6 Barrels",
        shCost = 0,
        markup = 1,
        cooldown = 2,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_barrels", purchaser, itemIdentifier )

        end,
    },
    [ "barnacle" ] = {
        name = "Barnacle",
        desc = "Barnacle.\nYou gain 100 score the first time it grabs someone, and 45 score every further second it has someone grabbed.\nCosts more to place in groups, or place too close to players.",
        shCost = 5,
        markup = 1,
        cooldown = 0.5,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 10,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "placable_barnacle", purchaser, itemIdentifier )

        end,
    },
    [ "doorlocker" ] = {
        name = "Door Locker",
        desc = "Locks doors, you gain score when something uses it.\n150 score, default.\n250 score if a player fleeing a hunter uses it.\nDon't use your own locked doors.",
        shCost = 5,
        markup = 1,
        cooldown = 0.5,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 10,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "door_locker", purchaser, itemIdentifier )

        end,
    },
    [ "additionalterm" ] = {
        name = "Linked Hunter",
        desc = "Spawn another hunter.\nThey will take on your appearance.\nIf you personally kill it, you will gain 350 score.\nThe newcomer will never lose you, if you regain your life...",
        shCost = function()
            if GAMEMODE:ClassIsInSpawnPool( "terminator_nextbot_snail_disguised" ) then
                return -150

            else
                return 200

            end
        end,
        markup = 1,
        cooldown = 90,
        tags = { "DEADSACRIFICES", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -100,
        shPurchaseCheck = { shopHelpers.undeadCheck, function()
            local extraData = GAMEMODE.roundExtraData or {}
            local extraHunter = GetGlobal2Entity( "glee_linkedhunter" )
            local validCsideHunter = IsValid( extraHunter ) and extraHunter:Health() > 0
            if IsValid( extraData.extraHunter ) or validCsideHunter then return nil, "There is already a linked hunter." end
            return true, nil

        end },
        svOnPurchaseFunc = function( purchaser )
            purchaser:GiveStatusEffect( "linked_hunter" )
            GAMEMODE:CloseShopOnPly( purchaser )

        end,
    },
    [ "presser" ] = {
        name = "Presser",
        desc = "Press things on the map.\nThe more a thing is pressed, the higher it's cost climbs...",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -4,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_presser", purchaser, itemIdentifier )

        end,
    },
    [ "homicidalglee" ] = {
        name = "Homicidal Glee.",
        desc = "Bring a player's Homicidal Glee to the surface...\nCosts nothing to place, if the player killed you at least once before.\nCan only be placed every 15 seconds.",
        costDecorative = "0 / -400",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 0,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_retribution", purchaser, itemIdentifier )

        end,
    },
    [ "termovercharger" ] = {
        name = "Overcharger.",
        desc = "Overcharge a Hunter. Global 3 minute delay between Overcharges.",
        costDecorative = "-450",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 19,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_overcharger", purchaser, itemIdentifier )

        end,
    },
    [ "temporalinversion" ] = {
        name = "Temporal Inversion",
        desc = "Swaps a player out for their most remote enemy.\nUnlocks after 2 minutes, then a global 2 minute cooldown between uses.",
        costDecorative = "-400",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase, function()
            if GAMEMODE:isTemporaryTrueBool( "termhunt_player_swapper_initial" ) then return nil, "Not unlocked yet." end
            if GAMEMODE:isTemporaryTrueBool( "termhunt_player_swapper" ) then return nil, "It is too soon for another inversion to begin." end
            return true, nil

        end },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "player_swapper", purchaser, itemIdentifier )

        end,
    },
    [ "immortalizer" ] = {
        name = "Gift of Immortality",
        desc = "Gift 20 seconds, of true Immortality.\nCosts 200 to gift to hunters, 300 to gift to players.",
        costDecorative = "-200 / -300",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_immortalizer", purchaser, itemIdentifier )

        end,
    },
    [ "blessing" ] = {
        name = "A Blessing",
        desc = "2 minutes of health regeneration, and Calm.\nCosts 50 to gift to hunters, 100 to gift to players.",
        costDecorative = "-50 / -100",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_blessing", purchaser, itemIdentifier )

        end,
    },
    [ "thunderousapplause" ] = {
        name = "Thunderous Applause",
        desc = "Let the Living, hear your utmost gratitiude.\nUnlocks after 4 minutes, then a global 4 minute cooldown between uses.",
        costDecorative = "-600",
        shCost = 0,
        markup = 1,
        cooldown = 0,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase, function()
            if GAMEMODE:isTemporaryTrueBool( "termhunt_thunderous_applause_initial" ) then return nil, "It's too soon for the applause to begin." end
            if GAMEMODE:isTemporaryTrueBool( "termhunt_thunderous_applause" ) then return nil, "Applause must be spaced out. Wait.." end
            return true, nil

        end },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "termhunt_thunderous_applause", purchaser, itemIdentifier )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )
