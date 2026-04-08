
-- start spawning rescue flare weapons after rounds are underway for a bit 

local GAMEMODE = GAMEMODE or GM

local minute = 60
local bodyCheckDelay = 1 * minute
local randomlySpawnItDelay = 5 * minute

hook.Add( "glee_sv_validgmthink_active", "glee_rescueflarespawning", function()
    if GAMEMODE:IsGenericSpawning( "termhunt_aeromatix_signalflare_gun" ) then return end
    local remain = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, CurTime() )

    if remain > randomlySpawnItDelay then
        GAMEMODE:RandomlySpawnEntTbl( "termhunt_aeromatix_signalflare_gun", {
            chance = 100,
            maxCount = 1,
            minAreaSize = 50,
            expireOnRoundEnd = true,

        } )
    end
end )