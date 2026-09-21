local GM = GM or GAMEMODE

local shopHelpers = GM.shopHelpers or {}
GM.shopHelpers = shopHelpers


-- An item's own fields can be functions, and a shop item is third party code as often as not.
-- Everything that calls one goes through these, so a thrown error is a dead item, not a dead shop.

-- xpcall handler. A shop item errors every frame the shop is open, so this must not halt
function shopHelpers.errorMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

-- complaint reads like "cost function errored", and the item stops being offered until the next gobble
function shopHelpers.itemFuncFailed( identifier, complaint )
    GAMEMODE:invalidateShopItem( identifier )
    permaPrint( "GLEE: !!!!!!!!!! " .. identifier .. "'s " .. complaint .. "!!!!!!!!!!!" )

end

shopHelpers.REASON_ERROR = "ERROR"
local REASON_ERROR = shopHelpers.REASON_ERROR


-- Picked by the spec's check func. A listener that damages its adjust table returns nothing here,
-- and the caller shouts about the wrong type like it would for any other bad value.
local adjustTypes = {
    [isnumber] = {
        new = function( value ) return { mul = 1, value = value } end,
        finish = function( adjust )
            if not isnumber( adjust.value ) or not isnumber( adjust.mul ) then return end
            return adjust.value * adjust.mul

        end,
    },
    [isstring] = {
        new = function( value ) return { value = value } end,
        finish = function( adjust ) return adjust.value end,
    },
}

--[[------------------------------------
    Lets other addons adjust an item's cost, cooldown or description. The hooks are named
    in sh_shopshared.lua, above the resolveItemField call that runs each one.

    Adjust table is a table so every hook can simply tweak the value without returning anything
    Means multiple hooks can modify in sequence

    Number fields get .mul and .value, string fields only get .value

    Eg;
    hook.Add( "glee_shop_itemcostmul", "half_price_guns", function( ply, itemData, adjust )
        if itemData.tags.Weapon then adjust.mul = adjust.mul * 0.5 end

    end )
--]]-------------------------------------
function shopHelpers.runAdjustHook( identifier, spec, ply, itemData, value )
    local adjustType = adjustTypes[spec.check]
    if not adjustType then
        permaPrint( "GLEE: !!!!!!!!!! " .. spec.hook .. " has no adjust type for " .. identifier .. "!!!!!!!!!!!" )
        return value

    end

    local adjust = adjustType.new( value )

    local noErrors = xpcall( hook.Run, shopHelpers.errorMitt, spec.hook, ply, itemData, adjust )
    if not noErrors then
        permaPrint( "GLEE: !!!!!!!!!! " .. spec.hook .. " errored for " .. identifier .. "!!!!!!!!!!!" )
        return value

    end

    local adjusted = adjustType.finish( adjust )
    if not spec.check( adjusted ) then
        permaPrint( "GLEE: !!!!!!!!!! " .. spec.hook .. " left a non-" .. spec.typeName .. " for " .. identifier .. "!!!!!!!!!!!" )
        return value

    end

    return adjusted

end

--[[---------------------------------------------------------
    shopHelpers.resolveItemField
    @desc Reads an item field that may be a value or a function( ply ), then applies the spec's
        markup, hook and rounding, in that order. An item that errors or returns the wrong type is
        invalidated on the way out.
    @param identifier: string. The shop item to read.
    @param fieldName: string. The key to read off it. A name no item carries is indistinguishable
        from an unset one, so a typo here quietly resolves to spec.default.
    @param ply: Player. The purchaser. Passed to the field's function, and to the markup.
    @param spec: table.
        check     function. What the value has to be, eg isnumber ( REQUIRED )
        typeName  string. Names that type in the complaint ( REQUIRED )
        default   any. What to return when the field is unset, errors, or is the wrong type
        markup    boolean. Multiply by GM:shopMarkup
        round     boolean. Whole numbers only
        hook      string. Run as ( ply, itemData, adjust ), see runAdjustHook
    @return: The value, or spec.default.
--]]---------------------------------------------------------
function shopHelpers.resolveItemField( identifier, fieldName, ply, spec )
    local itemData = GAMEMODE:GetShopItemData( identifier )
    if not itemData then return spec.default end

    local raw = itemData[fieldName]
    if raw == nil then return spec.default end

    local value = raw

    if isfunction( raw ) then
        local noErrors, returned = xpcall( raw, shopHelpers.errorMitt, ply )
        if not noErrors then
            shopHelpers.itemFuncFailed( identifier, fieldName .. " function errored" )
            return spec.default

        end
        value = returned

    end

    if not spec.check( value ) then
        shopHelpers.itemFuncFailed( identifier, fieldName .. " is not a " .. spec.typeName )
        return spec.default

    end

    if spec.markup then
        value = value * GAMEMODE:shopMarkup( ply, identifier )

    end

    if spec.hook then
        value = shopHelpers.runAdjustHook( identifier, spec, ply, itemData, value )

    end

    if spec.round then
        value = math.Round( value )

    end

    return value

end

--[[---------------------------------------------------------
    shopHelpers.runChecks
    @desc Runs hookName, then checkFuncs, and stops at the first one that says no.
    @param ply: Player. The purchaser, passed to the hook and to every check.
    @param itemData: table. The item being checked. Passed to the hook, NOT to the checks.
    @param hookName: string. Run as ( ply, itemData ). Only an explicit false blocks.
    @param checkFuncs: function or table of functions, each ( ply ) returning allowed, reason.
        A check must return true to pass, so a check that returns nothing blocks with no reason.
    @param funcName: string. Which field checkFuncs came from, for the error shout.
    @return: boolean allowed, and the string reason it was refused.
--]]---------------------------------------------------------
function shopHelpers.runChecks( ply, itemData, hookName, checkFuncs, funcName )
    local identifier = itemData.identifier

    local success, returned, reason = xpcall( hook.Run, shopHelpers.errorMitt, hookName, ply, itemData )
    if not success then
        GAMEMODE:invalidateShopItem( identifier )
        permaPrint( "GLEE: !!!!!!!!!! " .. hookName .. " errored for " .. identifier .. "!!!!!!!!!!!" )
        return false, REASON_ERROR

    end
    if returned == false then return false, reason end -- Blocked

    if isfunction( checkFuncs ) then
        checkFuncs = { checkFuncs }

    end
    if istable( checkFuncs ) then
        for _, checkFunc in ipairs( checkFuncs ) do
            success, returned, reason = xpcall( checkFunc, shopHelpers.errorMitt, ply )
            if not success then
                shopHelpers.itemFuncFailed( identifier, funcName .. " function errored" )
                return false, REASON_ERROR

            else
                if returned == true then continue end
                return false, reason

            end
        end
    end

    return true

end


-- alive! in the hunt
function shopHelpers.aliveCheck( purchaser )
    if purchaser:Health() <= 0 then return false, "You must be alive to purchase this." end
    return true, ""

end

-- dead! keep it interesting for the alive people!
function shopHelpers.deadCheck( purchaser )
    if purchaser:Health() > 0 then return false, "You must be dead to purchase this." end
    return true, ""

end

-- dead! but not for the escaped people.
function shopHelpers.deadNotEscapedCheck( purchaser )
    if purchaser:Health() > 0 then return false, "You must be dead to purchase this." end
    if purchaser:HasEscaped() then
        return false, "This is only for present souls to purchase."

    end
    return true, ""

end

-- escaped! just spectating, can't respawn, but can control bots!
function shopHelpers.escapedCheck( purchaser )
    if not purchaser:HasEscaped() then
        return false, "You must escape, to purchase this."

    end
    return true, ""

end

-- escaped at least once this session
function shopHelpers.hasEscapedOnceCheck( purchaser )
    if purchaser:GetEscapeCount() < 1 then
        return false, "You haven't escaped yet..."

    end
    return true, ""

end

local gunCock = Sound( "items/ammo_pickup.wav" )
function shopHelpers.loadoutConfirm( ply, count )
    for _ = 0, count do
        ply:EmitSound( gunCock, 60, math.random( 90, 110 ) )

    end
end

function shopHelpers.purchaseWeapon( purchaser, data )
    local wepClass = data.class
    local weapon = purchaser:GetWeapon( wepClass )
    local alreadyHasWeapon = IsValid( weapon )

    if not alreadyHasWeapon then
        weapon = purchaser:Give( wepClass )

        if IsValid( weapon ) then
            purchaser:SelectWeapon( weapon )

        end
    end

    if not IsValid( weapon ) then return end

    -- primary ammo
    local primaryAmmoType = data.ammoType or weapon:GetPrimaryAmmoType()
    local primaryClips = alreadyHasWeapon and data.resupplyClips or data.purchaseClips

    if primaryClips then
        local clipSize = weapon:GetMaxClip1()
        if clipSize == -1 then
            local hasDefaultClip = weapon.Primary and weapon.Primary.DefaultClip
            if hasDefaultClip then
                clipSize = weapon.Primary.DefaultClip

            else
                clipSize = 1

            end
        end

        purchaser:GiveAmmo( clipSize * primaryClips, primaryAmmoType, true )

    end

    -- secondary ammo
    local secondaryAmmoType = data.secondaryAmmoType or weapon:GetSecondaryAmmoType()
    local secondaryClips = alreadyHasWeapon and data.resupplySecondaryClips or data.purchaseSecondaryClips

    if secondaryClips and secondaryAmmoType and secondaryAmmoType ~= -1 then
        local clipSize = weapon:GetMaxClip2()
        if clipSize == -1 then
            local hasDefaultClip = weapon.Secondary and weapon.Secondary.DefaultClip
            if hasDefaultClip then
                clipSize = weapon.Secondary.DefaultClip

            else
                clipSize = 1

            end
        end

        purchaser:GiveAmmo( clipSize * secondaryClips, secondaryAmmoType, true )

    end

    -- confirmation sound
    if data.confirmSoundWeight then
        shopHelpers.loadoutConfirm( purchaser, data.confirmSoundWeight )

    end
end

local cheatsVar = GetConVar( "sv_cheats" )
function shopHelpers.isCheats()
    return cheatsVar:GetBool()

end

shopHelpers.thwaps = {
    Sound( "physics/body/body_medium_impact_hard3.wav" ),
    Sound( "physics/body/body_medium_impact_hard2.wav" ),
    Sound( "physics/body/body_medium_break2.wav" ),

}

function shopHelpers.playRandomSound( ent, sounds, level, pitch, channel )
    if not channel then
        channel = CHAN_STATIC
    end
    local soundName = sounds[math.random( #sounds )]

    ent:EmitSound( soundName, level, pitch, 1, channel )

end

function shopHelpers.hasMultiplePeople() -- some items require multiple players, hide them so we dont confuse new plys
    if #player.GetAll() <= 1 then return end
    return true

end

function shopHelpers.terminatorInSpawnPool()
    return GAMEMODE:PartialClassIsInSpawnPool( "terminator_nextbot" )

end

function shopHelpers.multiplePeopleAndTerm()
    return shopHelpers.hasMultiplePeople() and shopHelpers.terminatorInSpawnPool()

end

-- Does NOT sort by weight.
function shopHelpers.getItemsInCategory( category )
    local items = {}

    for _, itemData in pairs( GAMEMODE.shopItems ) do
        if itemData.categories and itemData.categories[category] then
            table.insert( items, itemData )

        end

    end

    return items

end

function shopHelpers.getItemsByTag( tag )
    local items = {}

    for _, itemData in pairs( GAMEMODE.shopItems ) do
        if itemData.tags and itemData.tags[tag] then
            table.insert( items, itemData )

        end

    end

    return items

end

function shopHelpers.setupPlacable( class, purchaser, itemIdentifier )
    local itemData = GAMEMODE:GetShopItemData( itemIdentifier )
    local thing = ents.Create( class )
    thing.itemIdentifier = itemIdentifier
    thing.canGoInDebt = itemData.canGoInDebt
    thing:SetOwner( purchaser )
    thing:Spawn()

    return thing

end
