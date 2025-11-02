
net.Receive( "GLEE_PDM:UpdatePlyHull", function()
    local hull = net.ReadUInt( 16 )
    local hullz = net.ReadUInt( 16 )
    local hullzduck = net.ReadUInt( 16 )

    local ply = LocalPlayer()
    if not IsValid( ply ) then print( "AAAAAAAAAAAAAAAAA" ) return end
    ply:SetHull( Vector( -hull, -hull, 0 ), Vector( hull, hull, hullz ) )
    ply:SetHullDuck( Vector( -hull, -hull, 0 ), Vector( hull, hull, hullzduck ) )

end )