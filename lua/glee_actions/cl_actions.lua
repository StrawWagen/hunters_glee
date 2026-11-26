local glee_Actions = terminator_Extras.glee_Actions

-- asks the server to pick key off ent, through the reach named reachName, see Pick in sv_actions.lua
-- by key, not wheel slot, what it offers can change in between
function glee_Actions.SendPick( reachName, ent, key )
    net.Start( "glee_actions_pick" )
        net.WriteString( reachName )
        net.WriteEntity( ent )
        net.WriteString( key )
    net.SendToServer()

end

-- a wheel of what ent offers through the reach named reachName, held open while bind's key is
-- see glee_FlickPickWheel in vgui/glee_wheel.lua
-- greys out what CanPick refuses, closes once ent's out of reach
-- nothing when it offers nothing
function glee_Actions.OpenWheel( reachName, ent, bind )
    local reach = glee_Actions.GetReach( reachName )
    local actions = glee_Actions.Offered( reach, ent )
    if not actions then return end

    local ply = LocalPlayer()
    local wheel = vgui.Create( "glee_wheel" )
    wheel:SetItems( actions )

    function wheel:GetItemStatus( item )
        if not IsValid( ent ) then return false end

        -- just the yes or no, glee_wheel reads a second return as a cooldown
        local canPick = glee_Actions.CanPick( ply, ent, item.key )
        return canPick

    end

    function wheel:OnItemSelected( item )
        glee_Actions.SendPick( reachName, ent, item.key )

    end

    function wheel:ShouldClose()
        return not IsValid( ent ) or not reach.InReach( ply, ent )

    end

    terminator_Extras.glee_FlickPickWheel( wheel, bind )

end
