
DeriveGamemode( "sandbox" )

GM.GLEE_FONT = "Arial"

-- GLOBALS!
GM.ROUND_INVALID          = -1 -- tell people to install a navmesh
GM.ROUND_SETUP      = 0 -- wait until the navmesh has definitely spawned
GM.ROUND_ACTIVE     = 1 -- death has consequences and score can accumulate
GM.ROUND_INACTIVE   = 2 -- let players run around and prevent death
GM.ROUND_LIMBO      = 3 -- just display winners

GM.TEAM_PLAYING = 1 -- alive
GM.TEAM_SPECTATE = 2 -- spectating, as a ghost
GM.TEAM_ESCAPED = 3 -- spectating, but you can't respawn, get cooler items in the shop and free bot controlling

GM.ISHUNTERSGLEE = true

GM.Name = "Hunter's Glee"
GM.Author = "StrawWagen"
GM.Email = "N/A"
GM.Website = "N/A"

include( "player_class/player_termrunner.lua" )
include( "sh_player.lua" )

include( "modules/sh_panic.lua" )
include( "modules/sh_banking.lua" )
include( "modules/sh_tempbools.lua" )
include( "modules/sh_deathsounds.lua" )
include( "modules/sh_slowmopitch.lua" )
include( "modules/sh_danceslowdown.lua" )
include( "modules/sh_playerdrowning.lua" )
include( "modules/battery/sh_battery.lua" )
include( "modules/sh_detecthunterkills.lua" )
include( "modules/shopitems/sh_shophelpers.lua" )
include( "modules/spawnset/sh_spawnpoolutil.lua" )
include( "modules/spawnset/sh_spawnsetcontent.lua" )
include( "modules/unsandboxing/sh_unsandboxing.lua" )

include( "sh_shopshared.lua" )

include( "modules/shopitems/sh_shoptags.lua" )
include( "modules/shopitems/sh_shopcategories.lua" )
include( "modules/shopitems/sh_itemverification.lua" )

-- does not include sh_statuseffectbase, that one is used to return a status effect table

if SERVER then -- load order has to be right :(
    include( "modules/shopitems/sv_shopgobbler.lua" )

end

function GM:SharedSetup()
    GAMEMODE:ResetShopItemCooldowns()
    GAMEMODE:ShopInitialThink()

end

function GM:PostCleanupMap()

    GAMEMODE:SharedSetup()

    if SERVER then
        --GAMEMODE:removePorters()
        GAMEMODE:removeBlockers()

        hook.Run( "glee_PostCleanupMap" )

        if GAMEMODE.blockCleanupSetup then return end

        for _, ply in ipairs( player.GetAll() ) do
            ply.isSetup = nil
            ply:ResetSkulls()

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

function GM:GetSpawnSetName()
    return GetGlobalString( "GLEE_SpawnSetName", "N/A" ), GetGlobalString( "GLEE_SpawnSetPrettyName", "N/A" )

end