local GM = GM or GAMEMODE

local shopHelpers = GM.shopHelpers or {}
GM.shopHelpers = shopHelpers

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

-- dead! keep it interesting for the alive people!
function shopHelpers.deadNotEscapedCheck( purchaser )
    if purchaser:Health() > 0 then return false, "You must be dead to purchase this." end
    if purchaser:GetNWInt( "glee_spectateteam", GAMEMODE.TEAM_PLAYING ) == GAMEMODE.TEAM_ESCAPED then
        return false, "This is only for present souls to purchase."

    end
    return true, ""

end

-- escaped! just spectating, can't respawn, but can control bots!
function shopHelpers.escapedCheck( purchaser )
    if purchaser:GetNWInt( "glee_spectateteam", GAMEMODE.TEAM_PLAYING ) ~= GAMEMODE.TEAM_ESCAPED then
        return false, "You must escape, to purchase this."

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

--[[
    - Self-modifies and returns a list of items after filtering by tags.

    items: table
        - A sequential list of either item ID strings, or item datas.
    tags: string or table
        - The tag(s) to use as a filter.
        - If a table, can either be sequential or a lookup of string to bool.
            - A sequential list is preferable.
            - If a whitelist, items will be allowed if they have ANY of the tags.
                - If requireAll is true, items instead will need ALL of the tags.
            - If a blacklist, items will be allowed if they have NONE of the tags.
    isWhitelist: (optional) bool
        - If true, will treat tags as a whitelist.
        - If false, will treat tags as a balcklist.
        - Defaults to true.
    requireAll: (optional) bool
        - If in whitelist mode, this requires items to have ALL the tags to be allowed.
        - Defaults to false.
--]]
function shopHelpers.filterByTag( items, tags, isWhitelist, requireAll )
    if isstring( tags ) then
        tags = { tags }

    elseif istable( tags ) and tags[1] == nil then
        -- Convert lookup into sequential.
        local oldTags = tags
        tags = {}

        for tag in pairs( oldTags ) do
            table.insert( tags, tag )

        end

    end

    if isWhitelist == nil then isWhitelist = true end

    for i = #items, 1, -1 do
        local item = items[i]

        if isstring( item ) then
            item = GAMEMODE:GetShopItemData( item )
            if not item then
                table.remove( items, i )
                continue

            end

        end

        local remove = false
        local hasATag = false
        local itemTagLookup = item.tags

        for _, tag in ipairs( tags ) do
            if isWhitelist == not itemTagLookup[ tag ] then -- Whitelist + not found, or blacklist + found
                if requireAll or not isWhitelist then
                    remove = true
                    break

                end

            else
                hasATag = true
                if isWhitelist and not requireAll then break end

            end

        end

        if remove or ( isWhitelist and not hasATag ) then
            table.remove( items, i )

        end

    end

    return items

end
