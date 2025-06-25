local plyMeta = FindMetaTable( "Player" )

function plyMeta:HuntersKilled()
    return self:GetNW2Int( "glee_hunterkills", 0 )

end

if SERVER then
    hook.Add( "huntersglee_round_into_active", "glee_reset_hunterkills", function()
        for _, ply in ipairs( player.GetAll() ) do
            ply:SetNW2Int( "glee_hunterkills", 0 )

        end
    end )

    hook.Add( "OnNPCKilled", "glee_detect_hunterkilled", function( killed, attacker )
        if not killed.isTerminatorHunterBased then return end
        if not IsValid( attacker ) or not attacker:IsPlayer() then return end

        local attackersKillCount = attacker:GetNW2Int( "glee_hunterkills", 0 )
        attackersKillCount = attackersKillCount + 1

        hook.Run( "huntersglee_plykilledhunter", attacker, killed )
        attacker:SetNW2Int( "glee_hunterkills", attackersKillCount )

    end )
end