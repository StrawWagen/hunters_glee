
-- escaping is how you win a round
hook.Add( "glee_ply_escaped", "learn_hardspawnset_lesson", function( ply )
    if GAMEMODE:IsSpawnsetEasy() then return end

    GAMEMODE:LearnLesson( ply, "WonAHardMisery" )

end )

