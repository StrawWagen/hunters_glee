
local GM = GM or GAMEMODE

-- shared building blocks for spawnsets, so a misery that wants stock Hunter's Glee behaviour
-- doesn't have to paste it in and then drift away from it
local setHelpers = GM.setHelpers or {}
GM.setHelpers = setHelpers


-- true while the active misery called setHelpers.makeHardcore
function GM:MiseryIsHardcore()
    return hook.Run( "glee_miseryishardcore" ) == true

end

-- no shop for the living
-- the dead only get "Hardcore" tagged items, and wait twice as long for them, the Door Locker 4x
-- Linked Hunter costs 10x
-- call from an sh_ spawnset's Activate
-- from an sv_ one, clients still draw a shop that won't sell
function setHelpers.makeHardcore( lifecycle )
    lifecycle:Hook( "glee_miseryishardcore", "glee_makeHardcore", function()
        return true

    end )
    -- escaped players sit at health 0, so the Horrors stay open to them
    lifecycle:Hook( "glee_blockshopopen", "glee_makeHardcore", function()
        if LocalPlayer():Health() <= 0 then return end

        return true, "This Misery is Hardcore.\nThe shop is closed to the living..."

    end )
    -- the shop panel is one way in, termhunt_purchase is the other, and this closes both
    lifecycle:Hook( "glee_shop_canshow", "glee_makeHardcore", function( _ply, itemData )
        if itemData.tags.Hardcore then return end

        return false, "Too soft for this Misery."

    end )
    lifecycle:Hook( "glee_shop_itemcooldownmul", "glee_makeHardcore", function( _ply, itemData, adjust )
        -- seconds, before the multiplier, so even an item with no cooldown waits
        adjust.value = math.max( adjust.value, 20 )

        local mul = 2
        if itemData.identifier == "doorlocker" then
            mul = 4

        end
        adjust.mul = adjust.mul * mul

    end )
    lifecycle:Hook( "glee_shop_itemcostmul", "glee_makeHardcore", function( _ply, itemData, adjust )
        if itemData.identifier ~= "additionalterm" then return end
        if adjust.value <= 0 then return end
        adjust.mul = adjust.mul * 10

    end )
end

-- no "Resurrecting" tagged shop items
-- so the only revives are Medical Tissue Reclaimers found in crates
-- call from an sh_ spawnset's Activate
function setHelpers.makeNoReviving( lifecycle )
    lifecycle:Hook( "glee_shop_canshow", "glee_makeNoReviving", function( ply, itemData )
        if not itemData.tags.Resurrecting then return end
        -- grigori respawns by buying resurrection
        if ply:HasStatusEffect( "divine_chosen" ) then return end

        return false, "No soul returns from this Misery."

    end )
end

-- no "SelfResurrecting" tagged shop items
-- the dead have to wait on the living to revive them
-- call from an sh_ spawnset's Activate
function setHelpers.makeNoSelfReviving( lifecycle )
    lifecycle:Hook( "glee_shop_canshow", "glee_makeNoSelfReviving", function( ply, itemData )
        if not itemData.tags.SelfResurrecting then return end
        -- grigori respawns by buying resurrection
        if ply:HasStatusEffect( "divine_chosen" ) then return end

        return false, "No soul resurrects itself in this Misery."

    end )
end

-- puts their model back on through PlayerSetModel
-- for when overridePlayerModel's pickModel would now pick something else for them
function setHelpers.redressPlayer( ply )
    hook.Call( "PlayerSetModel", GAMEMODE, ply )
    ply:SetupHands()

end

-- puts pickModel( ply ) on every player, a model path, or nil to let them wear their own
-- anyone alive when the misery starts changes on the spot, and changes back when it ends
-- call from a spawnset's Activate
function setHelpers.overridePlayerModel( lifecycle, pickModel )
    if CLIENT then return end

    -- hands and model scaling read glee_ModelOverride, so the arms and hull match the body
    lifecycle:Hook( "PlayerSetModel", "glee_overridePlayerModel", function( ply )
        local model = pickModel( ply )
        ply.glee_ModelOverride = model
        if not model then return end

        ply:SetModel( model )
        return true

    end )

    for _, ply in player.Iterator() do
        if ply:Alive() then
            setHelpers.redressPlayer( ply )

        end
    end

    -- the PlayerSetModel hook is gone by now, so this puts their own model back
    lifecycle:AddTeardown( function()
        for _, ply in player.Iterator() do
            if not ply.glee_ModelOverride then continue end
            ply.glee_ModelOverride = nil

            if ply:Alive() then
                setHelpers.redressPlayer( ply )

            end
        end
    end )
end


-- addons add their own helpers with sh_, sv_ or cl_ files in lua/glee_sethelpers/.
-- those run during gamemode load, where GAMEMODE is still nil, so they reach this table through GM
local function gobbleHelperModules()
    for _, fileName in ipairs( file.Find( "glee_sethelpers/*.lua", "LUA" ) ) do
        local prefix = string.sub( fileName, 1, 3 )
        local path = "glee_sethelpers/" .. fileName
        if prefix ~= "sh_" and prefix ~= "sv_" and prefix ~= "cl_" then
            ErrorNoHaltWithStack( "GLEE: Invalid sethelper prefix '" .. prefix .. "' in " .. fileName .. "\nNeeds to be sh_, sv_, or cl_" )
            continue

        end

        if SERVER and prefix ~= "sv_" then
            AddCSLuaFile( path )

        end

        if prefix == "sh_" or ( prefix == "sv_" ) == SERVER then
            ProtectedCall( function( pathProtected ) include( pathProtected ) end, path )

        end
    end
end

-- gobbled after the stock helpers, so a module can use them as it loads
if CLIENT then
    gobbleHelperModules()
    return

end


-- rolled at load, so the escalation curve is this session's own, not this round's
-- percent chance to overcharge, by minutes into the round
local overchargedChanceAtMinutes = {
    [0] = 0,
    [10] = math.Rand( 0, 1 ),
    [20] = math.Rand( 1, 5 ),
    [30] = math.Rand( 5, 15 ),
    [45] = math.Rand( 15, 25 ),
    [60] = 100

}

-- a .postSpawnedFuncs entry
-- the longer the hunt goes, the likelier a hunter spawns overcharged
-- reads spawnDat.minutesWhenAdded, the spawner sets it as it picks the entry into a wave
-- a heated session angers every hunter, overcharged or not
function setHelpers.postSpawnedOvercharge( spawnDat, spawned )

    local overchargedChance = 0
    local minutesWhenAdded = spawnDat.minutesWhenAdded
    for minutesNeeded, currChance in pairs( overchargedChanceAtMinutes ) do
        if minutesNeeded <= minutesWhenAdded and currChance >= overchargedChance then
            overchargedChance = currChance

        end
    end
    local tooLong = overchargedChance >= 5 -- where the curve sits from 30 minutes on

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
    -- once a round, so only spend it on an overcharge there's a message for
    if not ( tooLong or wayTooRich or tooDifficult ) then return end
    GAMEMODE.roundExtraData.overchargedWarning = true

    if tooLong then
        huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, "This hunt has gone on too long...\nOvercharged Hunters are on the prowl..." )

    elseif wayTooRich then
        huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, "There's too much score in play...\nOvercharged Hunters are on the prowl..." )

    elseif tooDifficult then
        huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, "The hunters have been pushed to their limits...\nOvercharged Hunters are on the prowl..." )

    end
end


gobbleHelperModules()
