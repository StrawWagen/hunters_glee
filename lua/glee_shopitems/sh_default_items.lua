
local shopHelpers = GAMEMODE.shopHelpers

local loadoutLoadout = {
    "weapon_shotgun",
    "weapon_smg1",
    "weapon_crossbow",
    "weapon_357",

}

local function canPurchaseSuitBattery( purchaser )
    local new = purchaser:Armor() + 15
    if new > purchaser:GetMaxArmor() then return false, "Your battery is full." end
    return true

end

hook.Add( "PlayerDeath", "glee_skullcache_trackdeathpositions", function( victim, inflictor, attacker )
    if not victim:IsPlayer() then return end
    local deathPositions = victim.glee_SkullCache_DeathPositions or {}

    if #deathPositions >= 1 and victim == attacker then return end -- real deaths only pls

    table.insert( deathPositions, victim:GetPos() )
    local tooManyPositions = 25
    if #deathPositions > tooManyPositions then
        table.remove( deathPositions, 1 )

    end
    victim.glee_SkullCache_DeathPositions = deathPositions

end )

local function purchaseSkullCache( purchaser )
    local deathPositions = purchaser.glee_SkullCache_DeathPositions
    local myPos = purchaser:GetPos()

    local sorted = table.Copy( deathPositions )
    table.sort( sorted, function( a, b )
        return a:DistToSqr( myPos ) > b:DistToSqr( myPos )

    end )

    local bestPos
    local bestArea
    for _, pos in ipairs( sorted ) do
        if not bestPos then -- default to furthest position
            bestPos = pos

        end
        local area = GAMEMODE:getNearestNav( pos, 500 )
        if area == NULL then continue end
        if not GAMEMODE.navmeshActivityHeatmap[area] then continue end
        if terminator_Extras.posIsInterruptingAlive( pos ) then continue end
        bestPos = pos
        bestArea = area
        break

    end

    if not bestPos then return end -- should never happen

    if IsValid( bestArea ) then
        bestPos = bestArea:GetCenter()

    end

    local cache = ents.Create( "glee_skullcache" )
    cache:SetPos( bestPos )
    cache:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
    cache:Spawn()

    local oldCount = GetGlobalInt( "glee_SkullCachePurchaseCount", 0 )
    SetGlobalInt( "glee_SkullCachePurchaseCount", oldCount + 1 )

end

-- decrease skullcache cost when round ends with everyone dead
hook.Add( "huntersglee_no_one_escaped", "glee_shophandler_resetpersistpurchasecounts", function()
    local oldCount = GetGlobalInt( "glee_SkullCachePurchaseCount", 0 )
    local newCount = oldCount - 1
    if newCount < 0 then return end
    SetGlobalInt( "glee_SkullCachePurchaseCount", newCount )

end )

-- debug
hook.Add( "glee_post_realcleanupmap", "glee_shophandler_resetpersistpurchasecounts", function()
    SetGlobalInt( "glee_SignalFlarePurchaseCount", 0 )
    SetGlobalInt( "glee_SkullCachePurchaseCount", 0 )

end )

-- buff some weapons against npcs
local buffs = {
    ["npc_tripmine"] = 1.75,
    ["npc_grenade_frag"] = 1.75,
    ["weapon_357"] = 2,
    ["weapon_smg1"] = 1.5,
    ["rpg_missile"] = 1.5,
}
hook.Add( "EntityTakeDamage", "glee_default_items_buff", function( target, dmgInfo )
    if not target:IsNPC() then return end

    local inflictor = dmgInfo:GetInflictor()
    if not IsValid( inflictor ) then return end

    local buffMult = buffs[inflictor:GetClass()]
    if not buffMult then return end

    dmgInfo:ScaleDamage( buffMult )

end )

-- each spawnset has their own purchase count
-- encourages fun spawnset switching
hook.Add( "glee_post_new_spawnset", "glee_shophandler_resetpersistpurchasecounts", function( newName, _set, oldName )
    if not oldName then return end -- initalize

    -- setup the tbl
    GAMEMODE.shopHandler_signalFlarePurchaseCounts = GAMEMODE.shopHandler_signalFlarePurchaseCounts or {}
    GAMEMODE.shopHandler_skullCachePurchaseCounts = GAMEMODE.shopHandler_skullCachePurchaseCounts or {}

    local oldSetsCount = GetGlobalInt( "glee_SignalFlarePurchaseCount", 0 )
    local newSetsCount = GAMEMODE.shopHandler_signalFlarePurchaseCounts[newName] or 0

    GAMEMODE.shopHandler_signalFlarePurchaseCounts[oldName] = oldSetsCount
    SetGlobalInt( "glee_SignalFlarePurchaseCount", newSetsCount )

    local oldCacheCount = GetGlobalInt( "glee_SkullCachePurchaseCount", 0 )
    local newCacheCount = GAMEMODE.shopHandler_skullCachePurchaseCounts[newName] or 0

    GAMEMODE.shopHandler_skullCachePurchaseCounts[oldName] = oldCacheCount
    SetGlobalInt( "glee_SkullCachePurchaseCount", newCacheCount )

end )

local items = {
    -- lol you ran out of battery
    ["armor"] = {
        name = "Suit Battery",
        desc = "15 Suit Battery.",
        shCost = 15,
        markup = 6,
        markupPerPurchase = 0.5,
        cooldown = 0.5,
        tags = { "ITEMS" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -150,
        shPurchaseCheck = { shopHelpers.aliveCheck, canPurchaseSuitBattery },
        svOnPurchaseFunc = function( purchaser )
            local new = math.Clamp( purchaser:Armor() + 15, 0, purchaser:GetMaxArmor() )
            purchaser:SetArmor( new )

            purchaser:EmitSound( "ItemBattery.Touch" )

        end,
    },
    ["rpg"] = {
        name = "RPG",
        desc = "RPG + Rockets.\nRocketing a hunter can save you in a pinch.",
        shCost = 60,
        markup = 1.5,
        markupPerPurchase = 0.15,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -140,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_rpg",
                confirmSoundWeight = 1,
                ammoType = "RPG_Round",
                purchaseClips = 4,
                resupplyClips = 6,

            } )
        end,
    },
    ["frag"] = {
        name = "10 Grenades",
        desc = "10 Grenades.\nSimple explosives, useful for hordes!",
        shCost = 50,
        markup = 1.5,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_frag",
                confirmSoundWeight = 1,
                ammoType = "Grenade",
                purchaseClips = 9,
                resupplyClips = 10,

            } )
        end,
    },
    -- heal jooce
    ["healthkit"] = {
        name = "Medkit",
        desc = "Heals.\nYou gain score for healing players.\nHealing yourself is unweildy and slow.\nExcess health you find, will reload it.",
        shCost = 80,
        markup = 2,
        markupPerPurchase = 0.15,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -100,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            local medkit = "termhunt_medkit"
            local weap = purchaser:GetWeapon( medkit )
            local hasWeap = IsValid( weap )

            if hasWeap then
                weap:HealJuice( 200 )

            else
                purchaser:Give( medkit, false )
                shopHelpers.loadoutConfirm( purchaser, 1 )

            end
        end,
    },
    -- funny bear trap
    ["beartrap"] = {
        name = "Six Beartraps",
        desc = "Traps players, Terminators can easily overpower them.",
        shCost = 65,
        markup = 2,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 0,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_weapon_beartrap",
                confirmSoundWeight = 1,
                ammoType = "GLEE_BEARTRAP",
                purchaseClips = 5,
                resupplyClips = 6,

            } )
        end,
    },
    -- terminator doesnt like taking damage from this, will save your ass
    ["ar2"] = {
        name = "Ar2",
        desc = "Ar2 + Balls.\nIt takes 2 AR2 balls to kill a terminator.",
        shCost = 75,
        markup = 2,
        markupPerPurchase = 0.4,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -150,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_ar2",
                confirmSoundWeight = 1,
                ammoType = "AR2",
                purchaseClips = 5,
                resupplyClips = 10,
                secondaryAmmoType = "AR2AltFire",
                purchaseSecondaryClips = 2,
                resupplySecondaryClips = 4,

            } )
        end,
    },
    ["guns"] = {
        name = "Loadout",
        desc = "Normal guns.\n& Ammo!\nNot very useful against metal...",
        shCost = 45,
        markup = 1.5,
        markupPerPurchase = 0.25,
        cooldown = 1,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -95,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            for _, currWep in ipairs( loadoutLoadout ) do
                shopHelpers.purchaseWeapon( purchaser, {
                    class = currWep,
                    confirmSoundWeight = 1,
                    ammoType = nil, -- auto
                    purchaseClips = 3,
                    resupplyClips = 4,

                } )
            end
        end,
    },
    ["nailer"] = {
        name = "Nailer",
        desc = "Nail things together!\nNailing is rather loud.",
        shCost = 45,
        markup = 3,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_weapon_hammer",
                confirmSoundWeight = 2,
                ammoType = "GLEE_NAILS",
                purchaseClips = 0,
                resupplyClips = 2,

            } )
        end,
    },
    ["gravitygun"] = {
        name = "Gravity Gun",
        desc = "Gravity Gun",
        shCost = 60,
        markup = 2,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.aliveCheck, function( purchaser )
            local gravgun = purchaser:GetWeapon( "weapon_physcannon" )
            if IsValid( gravgun ) then return false, "You aready have a Gravity Gun!" end
            return true

        end },
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_physcannon",
                confirmSoundWeight = 2,

            } )
        end,
    },
    ["flaregun"] = {
        name = "Flaregun",
        desc = "Flaregun.\n+ 6 flares.",
        shCost = 45,
        markup = 1.25,
        markupPerPurchase = 0.15,
        cooldown = 1,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,

        },
        weight = 1,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_aeromatix_flare_gun",
                confirmSoundWeight = 2,
                ammoType = "GLEE_FLAREGUN_PLAYER",
                purchaseClips = 2,
                resupplyClips = 6,

            } )
        end,
    },
    -- lets people mess with locked rooms
    ["lockpick"] = {
        name = "Lockpick",
        desc = "Lockpick, for doors.\nCan also open things like crates,\n( relatively ) quietly.",
        shCost = 20,
        markup = 6,
        cooldown = 10,
        tags = { "ITEMS", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.aliveCheck, lockpickCanPurchase },
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_lockpick",
                confirmSoundWeight = 2,

            } )
        end,
    },
    ["slams"] = {
        name = "Slams",
        desc = "Some slams, 17 to be exact.",
        shCost = 60,
        markup = 2,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_slam",
                confirmSoundWeight = 3,
                ammoType = "slam",
                purchaseClips = 14, -- spawns us with 3 extra slams
                resupplyClips = 17,

            } )
        end,
    },
    ["skullcache"] = {
        name = "Hidden Skull Cache",
        desc = "A hidden cache of skulls\nOnly purchasable if you've escaped at least once...\nWill be nearby your most remote death.\nYou've escaped once, and unlocked this.",
        shCost = function()
            local startingCost = 1000
            local costPerPurchase = 500
            local purchaseCount = GetGlobalInt( "glee_SkullCachePurchaseCount", 0 )
            return startingCost + ( purchaseCount * costPerPurchase )

        end,
        markupPerPurchase = 0.5,
        cooldown = 60,
        tags = { "ITEMS", "Utility", "NewGamePlus" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 800,
        shPurchaseCheck = {
            shopHelpers.aliveCheck,
            function( ply )
                -- stupid stupid but i dont want to sync the count of this
                if not SERVER then return true, "" end

                local deathPositions = ply.glee_SkullCache_DeathPositions
                if not deathPositions or #deathPositions < 1 then return false, "You haven't died yet..." end
                return true, ""

            end,
        },
        shCanShowInShop = shopHelpers.hasEscapedOnceCheck,
        svOnPurchaseFunc = purchaseSkullCache,
    },
    -- funny cam
    ["crapvidcam"] = {
        name = "Crappy Video Camera",
        desc = "Document the glee.",
        shCost = 0,
        shSkullCost = 1,
        cooldown = 0.5,
        tags = { "ITEMS", "Utility", "Fun", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 900,
        shPurchaseCheck = { shopHelpers.aliveCheck,
            function( purchaser )
                if purchaser:HasWeapon( "weapon_glee_crapvidcam" ) then return false, "You already have a Crappy Video Camera." end
                return true

            end
        },
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_glee_crapvidcam",
                confirmSoundWeight = 1,

            } )
        end,
    },
    -- ka BOOOOOM
    ["taucannon"] = {
        name = "Tau Cannon",
        desc = "High risk, High reward.\nDon't let it overcharge!",
        shCost = 0,
        shSkullCost = 6,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1100,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_taucannon",
                confirmSoundWeight = 4,
                ammoType = "Uranium_235",
                purchaseClips = 0,
                resupplyClips = 2,

            } )
        end,
    },
    -- awesome boomertaintaters gun
    ["ar3"] = {
        name = "Emplacement Gun",
        desc = "Rapid fire, powerful, chews through flesh, but not metal...\nOverheats quickly...",
        shCost = 0,
        shSkullCost = 5,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1000,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_ar3",
                confirmSoundWeight = 6,
                ammoType = "AR2",
                purchaseClips = 1,
                resupplyClips = 4,

            } )
        end,
    },
    ["grigorigun"] = {
        name = "Annabelle",
        desc = "IT KNOWS WHEN YOU MISS...",
        shCost = 0,
        shSkullCost = 5,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1000,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_annabelle",
                confirmSoundWeight = 5,
                ammoType = nil, -- auto
                purchaseClips = 0,
                resupplyClips = 6,

            } )
        end,
    },
    ["signalflare"] = {
        name = "Signal Flare Gun",
        desc = "Very bright flaregun, It could probably be seen from miles away...",
        shCost = 0,
        shSkullCost = function()
            local costPerPurchase = 15
            local purchaseCount = GetGlobalInt( "glee_SignalFlarePurchaseCount", 0 )
            local cost = costPerPurchase + ( purchaseCount * costPerPurchase )
            return cost

        end,
        cooldown = 0.5,
        tags = { "ITEMS", "Utility", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 10000,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_aeromatix_signalflare_gun",
                confirmSoundWeight = 10,
                ammoType = nil, -- auto
                purchaseClips = 0,
                resupplyClips = 1,

            } )

            local oldCount = GetGlobalInt( "glee_SignalFlarePurchaseCount", 0 )
            SetGlobalInt( "glee_SignalFlarePurchaseCount", oldCount + 1 )

        end,
        shCanShowInShop = function()
            if not GetGlobalBool( "glee_isSkyOnMap", false ) then return false, "There's nowhere to signal to..." end
            return true, ""

        end,
    }
}

GAMEMODE:GobbleShopItems( items )
