-- Pays Gleeful Envoys, and tells them about the Prospective Account Holders they're paid for. Rules in sh_envoy.lua

local GAMEMODE = GAMEMODE or GM

hook.Add( "huntersglee_round_postroundend", "glee_envoy_countescapedprospectives", function()
    local escapedCount = 0

    for _, ply in player.Iterator() do
        if ply:IsBot() then -- easy testing
            escapedCount = escapedCount + 1

        end
        if not ply:HasEscaped() then continue end
        if not GAMEMODE:IsProspectiveAccountHolder( ply ) then continue end

        escapedCount = escapedCount + 1

    end

    GAMEMODE.roundExtraData.escapedProspectiveCount = escapedCount

end )

-- ply's escape multiplier, and how many Prospective Account Holders raised it. Unchanged, and 0, for non Envoys
function GM:GetEnvoysEscapeMultiplier( ply, escapeMul )
    if not ply:HasBankItem( "gleeful_envoy" ) then return escapeMul, 0 end

    local escapedCount = self.roundExtraData.escapedProspectiveCount or 0
    return self:GetEnvoysBoon( escapeMul, escapedCount ), escapedCount

end

local function onlineEnvoys( except )
    local envoys = {}
    for _, ply in player.Iterator() do
        if ply == except then continue end
        if not ply:HasBankItem( "gleeful_envoy" ) then continue end

        envoys[#envoys + 1] = ply

    end
    return envoys

end

local function alertEnvoys( about, msg )
    local envoys = onlineEnvoys( about )
    if #envoys <= 0 then return end

    huntersGlee_Announce( envoys, 50, 6, msg )

end

hook.Add( "glee_bankAccountOpen", "glee_envoy_payfornewaccount", function( opener )
    local reward = GAMEMODE:GetEnvoyNewAccountReward()

    for _, envoy in ipairs( onlineEnvoys( opener ) ) do
        envoy:GivePlayerScore( reward )
        GAMEMODE:sendPurchaseConfirm( envoy, -reward )
        huntersGlee_Announce( { envoy }, 50, 6, opener:Nick() .. "\nIs now an Account Holder...\n+" .. reward .. " Score." )

    end
end )

hook.Add( "glee_full_load", "glee_envoy_alertarrival", function( ply )
    if not GAMEMODE:IsProspectiveAccountHolder( ply ) then return end

    alertEnvoys( ply, "A Prospective Account Holder has arrived...\nGet them up to speed!\nSee that " .. ply:Nick() .. " escapes..." )

end )

hook.Add( "glee_ply_escaped", "glee_envoy_alertescape", function( ply )
    if not GAMEMODE:IsProspectiveAccountHolder( ply ) then return end

    local msg = ply:Nick() .. ",\nA Prospective Account Holder, has escaped."
    alertEnvoys( ply, msg )

end )
