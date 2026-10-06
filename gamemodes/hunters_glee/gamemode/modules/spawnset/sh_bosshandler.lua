
-- Only the current Misery's bosses count. Killing one left over from an old Misery
-- doesn't end the round
function GM:IsActiveBoss( ent )
    local madeBy = ent:GetNW2String( "glee_BossOfSpawnset", "" )
    if madeBy == "" then return false end

    return madeBy == self:GetSpawnSetName()

end
