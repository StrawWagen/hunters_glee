AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

DEFINE_BASECLASS( "glee_wearable_base" )

-- handed straight to a player, bought or spawnmenu given, they come flipped down
-- Give equips right as it creates, so that's how it's told apart
-- picked up off the ground, they're flipped up, found ones shouldn't blind whoever grabs them
function SWEP:OwnerChanged()
    self:SetDown( CurTime() - self:GetCreationTime() <= 0.1 )
    BaseClass.OwnerChanged( self )

end

-- one of GetGleeActions' keys, in shared.lua, glee_actions has checked it's offered
-- goggles with more handle theirs, then hand the rest to this
function SWEP:OnGleeAction( ply, key )
    if key ~= "flip" then return BaseClass.OnGleeAction( self, ply, key ) end

    local down = not self:GetDown()
    self:SetDown( down )

    local snd = down and self.GleeNVGOnSound or self.GleeNVGOffSound
    ply:EmitSound( snd, 60, math.random( 95, 105 ), 0.8 )

    return true

end
