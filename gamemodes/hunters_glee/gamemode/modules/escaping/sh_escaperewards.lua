
-- easy miseries' escape multipliers are soft clamped down to this, see sv_escapecounts
GM.easyCostSoftMax = 0.75

-- -1 on these convars means the default in code, so changing a default reaches servers that already archived the convar
function GM.CreateDefaultingConVar( name, default, help )
    local cvar = CreateConVar( name, "-1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, help .. " -1 is default, " .. default, -1, 999999 )

    return function()
        local theVal = cvar:GetFloat()
        if theVal ~= -1 then
            return math.Round( theVal, 2 )

        else
            return default

        end
    end
end

local defaultingConVar = GM.CreateDefaultingConVar

GM.GetEscapeReward = defaultingConVar( "huntersglee_escape_reward", 500, "Score given for escaping, multiplied by the map and misery's escape multiplier." )
GM.GetEscapeRewardBoon = defaultingConVar( "huntersglee_escape_reward_everyone", 1000, "Extra score given for escaping when everyone escaped, multiplied by the escape multiplier." )
GM.GetEscapeRewardPerRider = defaultingConVar( "huntersglee_escape_reward_perrider", 500, "Score given to a driver, per passenger they helped escape." )

GM.GetSkullReward = defaultingConVar( "huntersglee_escape_skullreward", 15, "Score per skull when escaping without Skull Gains. Not multiplied." )
GM.GetSkullRewardGains = defaultingConVar( "huntersglee_escape_skullreward_gains", 50, "Score per skull when escaping with Skull Gains, multiplied by the escape multiplier." )
GM.GetSkullRewardGainsBoon = defaultingConVar( "huntersglee_escape_skullreward_gains_everyone", 100, "Extra score per skull with Skull Gains when everyone escaped." )

GM.GetSkullRelayMultiplier = defaultingConVar( "huntersglee_escape_skullreward_relaymul", 2, "Multiplier on the Skull Gains rate while connected to the Off-World Skull Relay." )

-- The Escape Multiplier for the current map and misery: their product, then the map's and the misery's.
-- Unrounded. Nil on client if a sync failed
function GM:GetEscapeMultiplier()
    -- 0 is the client cache's "not here", real multipliers never go below 0.15
    local mapMul = self:GetMapsEscapeMultiplier( game.GetMap() )
    if mapMul <= 0 then return end

    local spawnsetName = GetGlobalString( "GLEE_SpawnSetName", "" )
    local spawnsetMul = 1 -- the server's answer for no misery, the client's cache has nothing for it
    if spawnsetName ~= "" then
        spawnsetMul = self:GetSpawnsetsEscapeMultiplier( spawnsetName )
        if spawnsetMul <= 0 then return end

    end

    return mapMul * spawnsetMul, mapMul, spawnsetMul

end

