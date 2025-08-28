
-- TODO: debuff items too

-- if people leave while dead, they rejoin dead.
hook.Add( "PlayerDisconnected", "glee_preservedeath", function( leaver )
    local roundExtraData = GAMEMODE.roundExtraData
    local leavers = roundExtraData.leavers

    if not leavers then
        leavers = {}
        roundExtraData.leavers = leavers

    end

    leavers[ leaver:SteamID() ] = {
        score = leaver:GetScore(),
        alive = leaver:Alive(),
    }

end )

hook.Add( "PlayerInitialSpawn", "glee_rejoin_dead", function( ply )
    local roundExtraData = GAMEMODE.roundExtraData
    if not roundExtraData then return end

    local leavers = roundExtraData.leavers
    if not leavers then return end

    local leftData = leavers[ ply:SteamID() ]
    if not leftData then return end

    leavers[ ply:SteamID() ] = nil

    if leftData.score <= 0 then -- TODO, open this hole after debuff items can be made persist
        ply:SetScore( leftData.score )

    end

    if not leftData.alive then
        timer.Simple( 0, function()
            if not IsValid( ply ) then return end
            ply:TakeDamage( math.huge, game.GetWorld(), game.GetWorld() )

        end )
    end
end )