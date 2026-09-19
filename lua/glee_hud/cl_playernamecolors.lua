-- What colour another player's name draws in. Not a hud style: it comes from the
-- player's own state, not from the look of the panel around it

terminator_Extras.glee_DeadPlyColor = Color( 87, 117, 117 )
terminator_Extras.glee_EscapedPlyColor = Color( 0, 190, 255 )

-- Every colour picked below belongs to someone else, so the alpha goes on this copy
local nameColor = Color( 255, 255, 255, 255 )

-- Returns a shared colour the next call overwrites, so read it now.
-- An unseen player has no name colour, and draws in the dead one
function terminator_Extras.glee_PlayerNameColor( ply, visible )
    local color = nil
    local a = nil
    if ply:Health() <= 0 then
        if ply.HasEscaped and ply:HasEscaped() then
            color = terminator_Extras.glee_EscapedPlyColor
            a = 255

        elseif visible then
            color = terminator_Extras.glee_DeadPlyColor
            a = 255

        end
    elseif ply:Health() > 0 then
        if visible then
            color = GAMEMODE:GetTeamColor( ply )
            a = 160

        end
    end

    if ply.glee_PlayerNameColorOverride then
        color = ply.glee_PlayerNameColorOverride
        a = 255

    end

    if not color then
        color = terminator_Extras.glee_DeadPlyColor
        a = 255

    end

    nameColor.r = color.r
    nameColor.g = color.g
    nameColor.b = color.b
    nameColor.a = a

    return nameColor

end
