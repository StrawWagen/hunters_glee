
local GM = GM or GAMEMODE

-- shared building blocks for spawnsets, so a misery that wants stock Hunter's Glee behaviour
-- doesn't have to paste it in and then drift away from it
local setHelpers = GM.setHelpers or {}
GM.setHelpers = setHelpers


-- No shop for the living, only "Hardcore" tagged items for the dead, and they wait twice as long.
-- Call from an sh_ spawnset's Activate. Server only and the client draws a shop that won't sell
function setHelpers.makeHardcore( lifecycle )
    -- escaped players sit at health 0, so the Horrors stay open to them
    lifecycle:Hook( "glee_blockshopopen", function()
        if LocalPlayer():Health() <= 0 then return end

        return true, "The shop is closed to the living."

    end )
    -- the shop panel is one way in, termhunt_purchase is the other, and this closes both
    lifecycle:Hook( "glee_shop_canshow", function( _ply, itemData )
        if itemData.tags.Hardcore then return end

        return false, "Too soft for this Misery."

    end )
    lifecycle:Hook( "glee_shop_itemcooldownmul", function( _ply, _itemData, adjust )
        adjust.value = math.max( adjust.value, 20 )
        adjust.mul = adjust.mul * 2

    end )
end


if CLIENT then return end -- the rest spawns hunters


-- rolled at load, so the escalation curve is this session's own, not this round's
local overchargedChanceAtMinutes = {
    [0] = 0,
    [10] = math.Rand( 0, 1 ),
    [20] = math.Rand( 1, 5 ),
    [30] = math.Rand( 5, 15 ),
    [45] = math.Rand( 15, 25 ),
    [60] = 100

}

-- A .postSpawnedFuncs entry. Reads spawnDat.minutesWhenAdded, which the spawner sets as it
-- picks the entry into a wave. A heated session angers every hunter, overcharge roll or not
function setHelpers.postSpawnedOvercharge( spawnDat, spawned )

    local overchargedChance = 0
    local minutesWhenAdded = spawnDat.minutesWhenAdded
    for minutesNeeded, currChance in pairs( overchargedChanceAtMinutes ) do
        if minutesNeeded <= minutesWhenAdded and currChance >= overchargedChance then
            overchargedChance = currChance

        end
    end
    local tooLong = overchargedChance >= 5

    local _, richestScore = GAMEMODE:GetRichestPlayer()

    local spawnInPissed = GAMEMODE.sessionDiffBump > 100 or richestScore > 5000
    local tooDifficult = GAMEMODE.sessionDiffBump > 200
    local wayTooRich = richestScore > 10000

    if spawnInPissed then
        overchargedChance = overchargedChance + 1

    end
    if tooDifficult then
        overchargedChance = overchargedChance + 5

    end
    if wayTooRich then
        overchargedChance = overchargedChance + 10

    end

    local overcharge = math.Rand( 0, 100 ) < overchargedChance

    if spawnInPissed then
        spawned:ReallyAnger( 60 )
        spawned:GetTheBestWeapon()

    end

    if not overcharge then return end

    glee_Overcharge( spawned )

    local lightning = ents.Create( "glee_lightning" )
    lightning:SetOwner( spawned )
    lightning:SetPos( spawned:GetPos() )
    lightning:SetPowa( 12 )
    lightning:Spawn()

    timer.Simple( 0.1, function()
        if not IsValid( spawned ) then return end
        spawned:SetHealth( spawned:GetMaxHealth() )

    end )

    if GAMEMODE.roundExtraData.overchargedWarning then return end
    GAMEMODE.roundExtraData.overchargedWarning = true

    if tooLong then
        huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, "This hunt has gone on too long...\nOvercharged Hunters are on the prowl..." )

    elseif wayTooRich then
        huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, "There's too much score in play...\nOvercharged Hunters are on the prowl..." )

    elseif tooDifficult then
        huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, "The hunters have been pushed to their limits...\nOvercharged Hunters are on the prowl..." )

    end
end
