-- PROBLEM: maps feel empty because you can't find other people

DeriveGamemode( "base" )

include( "lib/sh_termfuncs.lua" )
include( "player_class/player_termrunner.lua" )

include( "sh_shopshared.lua" )
include( "modules/sh_panic.lua" )
include( "modules/sh_playerdrowning.lua" )
include( "modules/sh_detecthunterkills.lua" )
include( "modules/sh_tempbools.lua" )

resource.AddSingleFile( "sound/53937_meutecee_trumpethit07.wav" )
resource.AddSingleFile( "sound/418788_name_heartbeat_single.wav" )
resource.AddSingleFile( "sound/209578_zott820_cash-register-purchase.wav" )
resource.AddSingleFile( "sound/482735__copyc4t__cartoon-long-throw.wav" )

GM.Name = "Hunter's Glee"
GM.Author = "StrawWagen"
GM.Email = "N/A"
GM.Website = "N/A"

-- GLOBALS!
GM.INVALID          = -1 -- tell people to install a navmesh
GM.ROUND_SETUP      = 0 -- wait until the navmesh has definitely spawned
GM.ROUND_ACTIVE     = 1 -- death has consequences and score can accumulate
GM.ROUND_INACTIVE   = 2 -- let players run around and prevent death
GM.ROUND_LIMBO      = 3 -- just display winners

GM.ISHUNTERSGLEE = true


function GM:GetHuntersClass()
    return "sb_advanced_nextbot_terminator_hunter_snail"

end

function GM:RoundState()
    return GetGlobal2Int( "termhunt_roundstate", 0 )
end

function GM:SharedSetup()
    GAMEMODE:ResetShopItemCooldowns()
    GAMEMODE:SetupShop()
    GAMEMODE:SetupShopCatalouge()

end

function GM:PutInnateInProperCleanup( timerName, additionalFunc, funcTarget )
    GAMEMODE.TimersToCleanup = GAMEMODE.TimersToCleanup or {}

    local tbl = { name = timerName, func = additionalFunc, targ = funcTarget }

    table.insert( GAMEMODE.TimersToCleanup, tbl )

end

function GM:RunFunctionOnProperCleanup( theFunc, funcTarget )
    GAMEMODE.TimersToCleanup = GAMEMODE.TimersToCleanup or {}

    local tbl = { func = theFunc, targ = funcTarget }

    table.insert( GAMEMODE.TimersToCleanup, tbl )

end

local function catch( err )
    print( "FUNCTION ERRORED WHEN CLEANUPTIMERS RAN!" )
    ErrorNoHaltWithStack( err )
end

function GM:CleanupTimers()
    GAMEMODE.TimersToCleanup = GAMEMODE.TimersToCleanup or {}
    for _, tbl in ipairs( GAMEMODE.TimersToCleanup ) do
        if tbl.name then
            timer.Stop( tbl.name )

        end

        local func = tbl.func
        if func and IsValid( tbl.targ ) then
            xpcall( func, catch, tbl.targ )
        end
    end
    GAMEMODE.TimersToCleanup = nil
end

function GM:PostCleanupMap()

    GAMEMODE:SharedSetup()

    if SERVER then
        GAMEMODE:removePorters()
        GAMEMODE:removeBlockers()

        GAMEMODE:CleanupTimers()

        if GAMEMODE.blockCleanupSetup then return end

        for _, ply in ipairs( player.GetAll() ) do
            ply.isSetup = nil

        end

        GAMEMODE:TermHuntSetup()

    end
end

function GM:InitPostEntity()

    GAMEMODE:SharedSetup()

end

function GM:Initialize()

    if SERVER then
        GAMEMODE:TermHuntSetup()
        GAMEMODE:concmdSetup()

    end
end

function GM:ResetShopItemCooldowns()
    if SERVER then
        net.Start( "glee_resetplayershopcooldowns" )
        net.Broadcast()

        for _, currentPlayer in ipairs( player.GetAll() ) do
            currentPlayer.shopItemCooldowns = {}

        end
    else
        LocalPlayer().shopItemCooldowns = {}
    end
end