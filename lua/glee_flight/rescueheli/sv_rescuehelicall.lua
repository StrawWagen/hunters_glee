-- the countdown between someone calling the heli and it entering the map
local rescueHeli = terminator_Extras.glee_RescueHeli

local rescueTimerName = "glee_rescueheli_countdown"

local function cancelRescueTimer()
    if not timer.Exists( rescueTimerName ) then return end
    timer.Remove( rescueTimerName )

end

hook.Add( "huntersglee_round_leave_limbo", "glee_cancelrescuehelitimer_limboend", cancelRescueTimer )
hook.Add( "huntersglee_round_into_limbo", "glee_cancelrescuehelitimer_limboend", cancelRescueTimer )
hook.Add( "glee_post_realcleanupmap", "glee_cancelrescuehelitimer_cleanup", cancelRescueTimer )

-- counting down, or already flying around
function rescueHeli.IsCalledOrPresent()
    return IsValid( terminator_Extras.glee_CurrentRescueHeli ) or timer.Exists( rescueTimerName )

end

-- heli enters the map at spawnPos, and flies to goalPos first
function rescueHeli.Call( spawnPos, goalPos, caller )
    rescueHeli.AngerEverything()

    local heliSpawnDelay = 70
    if not GAMEMODE.IsReallyHuntersGlee then
        heliSpawnDelay = 30

    end
    local diffBump
    local permaDiffBump

    local faceDir = terminator_Extras.dirToPos( spawnPos, goalPos )
    local firstWait = 3
    local secondWait = 10

    hook.Run( "glee_onescapehelicalled", caller )

    timer.Create( rescueTimerName, 1, heliSpawnDelay, function()
        local repsLeft = timer.RepsLeft( rescueTimerName )
        if repsLeft == heliSpawnDelay - firstWait then
            local name
            if not IsValid( caller ) then
                name = "Something Dead"

            elseif caller.Nick and isstring( caller:Nick() ) then
                name = caller:Nick()

            else
                name = GAMEMODE:GetNameOfBot( caller )

            end
            huntersGlee_AnnounceDramatic( player.GetAll(), 500, secondWait - firstWait, name .. "\nHAS CALLED FOR RESCUE!" )
            if GAMEMODE.IsReallyHuntersGlee then
                GAMEMODE:SendMusic( "tracks/heliEvac" )
                local _, spawnSet = GAMEMODE:GetSpawnSet()
                diffBump = spawnSet.diffBumpWhenWaveKilled / 2
                permaDiffBump = spawnSet.diffBumpWhenWaveKilled / 10
                GAMEMODE:BumpRoundDifficulty( diffBump, "rescue_heli1" ) -- send the spawner into overdrive
                GAMEMODE:BumpSessionDifficulty( permaDiffBump, "rescue_heli1" ) -- make the session harder, permanently
                rescueHeli.AngerEverything()

            end
        end

        if repsLeft == heliSpawnDelay - secondWait then
            huntersGlee_AnnounceDramatic( player.GetAll(), 501, 10, "Rescue, entering the map in T-" .. heliSpawnDelay - secondWait .. " seconds..." )

            if not diffBump then return end
            GAMEMODE:BumpRoundDifficulty( diffBump, "rescue_heli2" ) -- send the spawner into overdrive
            GAMEMODE:BumpSessionDifficulty( permaDiffBump, "rescue_heli2" )
            GAMEMODE:NewSpawnWaveNow()
            rescueHeli.AngerEverything()

        end
        if repsLeft == 10 then
            huntersGlee_Announce( player.GetAll(), 100, 5, "T-10 seconds till map entry..." )

            if not diffBump then return end
            GAMEMODE:BumpRoundDifficulty( diffBump, "rescue_heli3" )
            GAMEMODE:BumpSessionDifficulty( permaDiffBump, "rescue_heli3" )
            rescueHeli.AngerEverything()

        end
        if repsLeft == 0 then
            huntersGlee_AnnounceDramatic( player.GetAll(), 100, 10, "Rescue has entered the map..." )
            rescueHeli.Spawn( spawnPos, faceDir, goalPos )

            if not diffBump then return end
            GAMEMODE:BumpRoundDifficulty( diffBump, "rescue_heli4" )
            GAMEMODE:BumpSessionDifficulty( permaDiffBump, "rescue_heli4" )
            GAMEMODE:NewSpawnWaveNow()
            rescueHeli.AngerEverything()

        end
    end )
end
