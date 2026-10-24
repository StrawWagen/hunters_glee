
local GM = GM or GAMEMODE

local maxOptionsVar = CreateConVar( "hunterslglee_modevote_maxoptions", 6, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Amount of options that show up in the Misery vote", 2, 9 )

function GM:GetMiseryVoteMaxOptions()
    return maxOptionsVar:GetInt()

end

-- sv_spawnsetvote sets this when a vote begins, and zeroes it if one is cancelled
function GM:IsMiseryVoteRunning()
    return GetGlobal2Float( "glee_MiseryVoteEnd", 0 ) > CurTime()

end

-- A misery's percent chance to be picked for a vote, before the vote's own adjustments. nil is always.
-- Clientside, the escape multiplier is only known once it's been synced or requested
function GM:GetSpawnsetVotableChance( setName )
    local registered = self:GetRegisteredSpawnSet( setName )
    if not registered then return end

    local hardThresh = registered.easy and self.easyCostSoftMax or 1
    local mul = self:GetSpawnsetsEscapeMultiplier( setName )

    -- make spawnsets fade into the background if they aren't challenging people
    if registered.chanceToBeVotableWhenHard and mul >= hardThresh then
        return registered.chanceToBeVotableWhenHard

    end

    return registered.chanceToBeVotable

end
