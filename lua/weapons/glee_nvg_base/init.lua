AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

DEFINE_BASECLASS( "glee_wearable_base" )

util.AddNetworkString( "glee_nvg_wheelpick" )

local pickCooldown = 0.2

-- picked up again, they start flipped up
function SWEP:OnDrop()
    self:SetDown( false )
    BaseClass.OnDrop( self )

end

-- one of the wheel's keys, see GetWheelActions in cl_init.lua
-- goggles with more on their wheel handle theirs, then hand the rest to this
function SWEP:OnWheelPick( ply, key )
    if key ~= "flip" then return end

    local down = not self:GetDown()
    self:SetDown( down )

    local snd = down and self.GleeNVGOnSound or self.GleeNVGOffSound
    ply:EmitSound( snd, 60, math.random( 95, 105 ), 0.8 )

end

-- by key, not wheel slot, it only picks from the goggles in their hands
net.Receive( "glee_nvg_wheelpick", function( _, ply )
    if ( ply.glee_NextNVGWheelPick or 0 ) > CurTime() then return end
    ply.glee_NextNVGWheelPick = CurTime() + pickCooldown
    if not ply:Alive() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or not wep.OnWheelPick then return end

    wep:OnWheelPick( ply, net.ReadString() )

end )
