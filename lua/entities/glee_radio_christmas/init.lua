AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

local GAMEMODE = GAMEMODE or GM
if not GAMEMODE.RandomlySpawnEntTbl then return end

GAMEMODE:RandomlySpawnEntTbl( "glee_radio_christmas", {
    maxCount = 1,
    chance = 50,
    minAreaSize = 25,
} )
