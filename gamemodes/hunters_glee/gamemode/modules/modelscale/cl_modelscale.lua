
net.Receive( "GLEE_PDM:UpdatePlyHull", function()
    local hull = net.ReadUInt( 16 )
    local hullz = net.ReadUInt( 16 )
    local hullzduck = net.ReadUInt( 16 )

    timer.Create( "GLEE_PDM:DelayedHullUpdate", 0, 0, function()
        local ply = LocalPlayer()
        if not IsValid( ply ) then return end

        ply:SetHull( Vector( -hull, -hull, 0 ), Vector( hull, hull, hullz ) )
        ply:SetHullDuck( Vector( -hull, -hull, 0 ), Vector( hull, hull, hullzduck ) )

        timer.Remove( "GLEE_PDM:DelayedHullUpdate" )

    end )
end )