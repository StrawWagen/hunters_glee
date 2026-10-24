
local GM = GM or GAMEMODE

-- Players who own the bank item can pay score to put a misery into the next vote.
-- One they haven't seen costs more, going by the seen set their client synced, which it could fake

GM.MiseryNominationBankItem = "miserynomination"
GM.MiseryNominationBaseCost = 500
GM.MiseryNominationRarestChance = 1 -- rarer than this costs no more
GM.MiseryNominationBlindCostMul = 5

-- [steamID64] = { setName = string, cost = what they paid }
-- the server's, and on clients the copy sv_spawnsetnominate last sent
GM.glee_MiseryNominations = GM.glee_MiseryNominations or {}

function GM:GetMiseryNominations()
    return self.glee_MiseryNominations

end

-- [steamID64] = a nomination whose nominator left. Off the ballot until they're back and it fits again
-- on clients, only their own
GM.glee_SuspendedMiseryNominations = GM.glee_SuspendedMiseryNominations or {}

function GM:GetSuspendedMiseryNominations()
    return self.glee_SuspendedMiseryNominations

end

-- What a misery with this percent chance to be votable multiplies its nomination cost by
function GM:GetMiseryNominationRarityMul( chance )
    return math.sqrt( 100 / math.Clamp( chance, self.MiseryNominationRarestChance, 100 ) )

end

-- Clientside, this is 0 until the misery's escape multiplier has been synced or requested
function GM:GetMiseryNominationCost( ply, setName )
    local mul = self:GetSpawnsetsEscapeMultiplier( setName )
    local chance = self:GetSpawnsetVotableChance( setName ) or 100

    local cost = self.MiseryNominationBaseCost * mul * self:GetMiseryNominationRarityMul( chance )
    if not self:HasSeenMisery( ply, setName ) then
        cost = cost * self.MiseryNominationBlindCostMul

    end

    return math.Round( cost )

end

-- Whether ply could nominate anything at all right now. Returns true, or false and why not
function GM:CanNominateMiseries( ply )
    if not ply:HasBankItem( self.MiseryNominationBankItem ) then return false, "Nominating Miseries is a service of the Bank." end
    if self:IsMiseryVoteRunning() then return false, "A Misery vote is already underway." end

    return true

end

-- Whether the ballot has room for a nomination of setName, whoever makes it. Returns true, or false and why not
function GM:CanMiseryTakeNomination( setName )
    if not self:GetRegisteredSpawnSet( setName ) then return false, "That isn't a Misery." end
    if setName == self:GetSpawnSetName() then return false, "You're already suffering this Misery." end

    for _, nomination in pairs( self.glee_MiseryNominations ) do
        if nomination.setName == setName then return false, "Someone has already nominated this Misery." end

    end

    if table.Count( self.glee_MiseryNominations ) >= self:GetMiseryVoteMaxOptions() then return false, "The next Misery vote is full of nominations." end

    return true

end

-- Returns true, or false and why not. One nomination each, withdraw it to nominate another
function GM:CanNominateMisery( ply, setName )
    local canAny, reason = self:CanNominateMiseries( ply )
    if not canAny then return false, reason end

    local steamID64 = ply:SteamID64()
    local mine = self.glee_MiseryNominations[steamID64]
    if mine then
        if mine.setName == setName then return false, "You've already nominated this Misery." end
        return false, "Withdraw your nomination first."

    end

    if self.glee_SuspendedMiseryNominations[steamID64] then return false, "Your nomination is suspended until there's room for it. Withdraw it first." end

    local canTake, takeReason = self:CanMiseryTakeNomination( setName )
    if not canTake then return false, takeReason end

    if ply:GetScore() < self:GetMiseryNominationCost( ply, setName ) then return false, "You can't afford to nominate this Misery." end

    return true

end

-- Returns true, or false and why not. Suspended nominations can be withdrawn too
function GM:CanWithdrawMiseryNomination( ply )
    local steamID64 = ply:SteamID64()
    if not self.glee_MiseryNominations[steamID64] and not self.glee_SuspendedMiseryNominations[steamID64] then return false, "You haven't nominated a Misery." end

    return true

end
