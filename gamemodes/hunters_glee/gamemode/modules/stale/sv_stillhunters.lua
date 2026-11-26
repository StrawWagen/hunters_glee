
-- For spawnSet.spawns.entry.removeAfterStillSeconds, catches hunters that got wedged somewhere, or never could move

local debuggingVar = GetConVar( "huntersglee_debug_hunterspawner" )
local function debugPrint( ... )
    if not debuggingVar:GetBool() then return end
    permaPrint( ... )

end

-- wandering within this of where it last moved from still counts as standing still
local stillWanderDistSqr = 50^2

--[[---------------------------------------------------------
    GM:ManageIfStill
    @desc Removes this hunter once it's stayed in one spot too long.
    @param hunter: The hunter.
    @param secondsToRemove: How long it can stand still, only counted while the round is active.
    @return: None
--]]---------------------------------------------------------
function GM:ManageIfStill( hunter, secondsToRemove )
    local anchor = hunter:GetPos()
    local stillFor = 0
    local timerName = "glee_hunter_removestill_" .. hunter:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( hunter ) then timer.Remove( timerName ) return end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

        local pos = hunter:GetPos()
        if pos:DistToSqr( anchor ) > stillWanderDistSqr then
            anchor = pos
            stillFor = 0
            return

        end

        stillFor = stillFor + 1
        if stillFor < secondsToRemove then return end

        timer.Remove( timerName )
        SafeRemoveEntity( hunter )
        debugPrint( "REMOVE STILL", hunter )

    end )
end
