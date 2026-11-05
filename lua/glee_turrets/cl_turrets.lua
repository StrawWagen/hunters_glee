
local glee_Turrets = terminator_Extras.glee_Turrets

local turretColor = Vector( 255, 190, 0 ) / 255

hook.Add( "EntityNetworkedVarChanged", "glee_shopturret_nick", function( ent, varName )
    if varName ~= "glee_TurretName" then return end

    -- "" hides its name tag, see glee_nametag
    ent.Nick = function()
        if terminator_Extras.glee_Carrying.IsCarried( ent ) then return "" end
        return glee_Turrets.GetName( ent )

    end
    ent.GetPlayerColor = function()
        return turretColor

    end

    -- the name panels only pick up ents that had a Nick when they were created
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        hook.Run( "glee_cl_proxyhud_pleasepaintthis", ent )

    end )
end )
