-- The Gleeful Envoy bank item's rules. sv_envoy.lua pays it out

local defaultingConVar = GM.CreateDefaultingConVar

GM.GetEnvoyBaseMultiplier = defaultingConVar( "huntersglee_envoy_basemul", 3, "Gleeful Envoys' escape multiplier is raised to at least this, before the per player additions, when any player without a bank account escapes the same round." )
GM.GetEnvoyAddedMultiplier = defaultingConVar( "huntersglee_envoy_addedmul", 0.5, "Added to a Gleeful Envoy's escape multiplier for every player without a bank account that escapes the same round. Paid out on the Envoy's own escape, by any vehicle." )
GM.GetEnvoyNewAccountReward = defaultingConVar( "huntersglee_envoy_newaccountreward", 250, "Score each online Gleeful Envoy gets when someone opens a bank account." )

-- the souls an Envoy is paid for. Envoys need an account, so they never are one
function GM:IsProspectiveAccountHolder( ply )
    return not ply:BankHasAccount()

end

-- the Envoy's Boon. escapeMul is from GetEscapeMultiplier
function GM:GetEnvoysBoon( escapeMul, prospectivesEscaped )
    if prospectivesEscaped <= 0 then return escapeMul end
    return math.max( escapeMul, self:GetEnvoyBaseMultiplier() ) + prospectivesEscaped * self:GetEnvoyAddedMultiplier()

end
