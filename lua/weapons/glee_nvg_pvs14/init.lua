AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

-- picks from the haptic goggles' use wheel, the radar state lives on the weapon so it stays with the goggles if thrown

util.AddNetworkString( "glee_nvg_hapticpick" )

local hapticClass = "glee_nvg_pvs14"
local pickCooldown = 0.2

net.Receive( "glee_nvg_hapticpick", function( _, ply )
    if ( ply.glee_NextHapticPick or 0 ) > CurTime() then return end
    ply.glee_NextHapticPick = CurTime() + pickCooldown
    if not ply:Alive() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or wep:GetClass() ~= hapticClass then return end

    local key = net.ReadString()
    if key == "radar" then
        local on = not wep:GetRadarOn()
        wep:SetRadarOn( on )
        ply:EmitSound( on and "buttons/button17.wav" or "buttons/button16.wav", 55, 120, 0.6 )

    elseif key == "cone" then
        local nextIndex = wep:GetCone() % #wep.Cones + 1
        wep:SetCone( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 150 - nextIndex * 15, 0.6 )

    elseif key == "wavelength" then
        local nextIndex = wep:GetWavelength() % #wep.Wavelengths + 1
        wep:SetWavelength( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 90 + nextIndex * 15, 0.6 )

    end
end )
