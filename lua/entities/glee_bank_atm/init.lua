AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

util.AddNetworkString( "glee_atm_opened" )
util.AddNetworkString( "glee_atm_deposit" )
util.AddNetworkString( "glee_atm_withdraw" )
util.AddNetworkString( "glee_atm_withdrawpool" )
util.AddNetworkString( "glee_atm_transactionresult" )
