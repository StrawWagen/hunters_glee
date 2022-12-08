DeriveGamemode( "base" )

include( "player_class/player_termrunner.lua" )

include( "shopshared.lua" )

resource.AddSingleFile( "sound/53937_meutecee_trumpethit07.wav" )
resource.AddSingleFile( "sound/418788_name_heartbeat_single.wav" )

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

function GM:RoundState()
    return GetGlobalInt( "termhunt_roundstate", 0 )
end

function GM:SharedSetup()
    GAMEMODE:SetupShop()
    GAMEMODE:SetupShopCatalouge()

end

function GM:PostCleanupMap()

    GAMEMODE:SharedSetup()

    if SERVER then 
        GAMEMODE:removePorters()
        GAMEMODE:removeBlockers()

        if GAMEMODE.blockCleanupSetup then return end

        GAMEMODE:TermHuntSetup()

    elseif CLIENT then

    end
end

function GM:InitPostEntity()

    GAMEMODE:SharedSetup()

end

function GM:Initialize()

    if SERVER then 
        GAMEMODE:TermHuntSetup()
        GAMEMODE:concmdSetup()

    elseif CLIENT then

    end
end