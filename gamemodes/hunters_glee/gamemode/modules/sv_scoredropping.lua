
hook.Add( "PlayerDeath", "glee_DropScoreOnSuicide", function( victim, inflictor, attacker )
    if victim ~= inflictor or victim ~= attacker then return end-- not a suicide

    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

    local theirScore = victim:GetScore()
    local scoreToDrop = theirScore / 4
    if scoreToDrop < 10 then return end

    scoreToDrop = math.ceil( scoreToDrop )

    victim:GivePlayerScore( -scoreToDrop )
    huntersGlee_Announce( { victim }, 1, 5, "You've suicided.\n" .. scoreToDrop .. " score is left behind." )

    while scoreToDrop > 0 do
        local droppedBall = ents.Create( "termhunt_score_pickup" )
        droppedBall:SetPos( victim:GetPos() + vector_up * 25 )

        local theBallsScore = math.Clamp( scoreToDrop, 0, math.random( 90, 110 ) )
        scoreToDrop = scoreToDrop + -theBallsScore
        droppedBall:SetScore( theBallsScore )
        droppedBall:Spawn()

        if IsValid( droppedBall:GetPhysicsObject() ) then
            droppedBall:GetPhysicsObject():SetVelocity( VectorRand() * math.random( 10, 30 ) )

        end
    end
end )

local tooMuchScore = CreateConVar( "huntersglee_scoreleakquota", "2500", FCVAR_ARCHIVE, "If a player's score is above this, it will 'leak' on death" )

hook.Add( "PlayerDeath", "glee_DropScoreWithTooMuch", function( victim, inflictor, attacker )
    if ( victim == inflictor and victim == attacker ) then return end -- suicides handled above

    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

    local theirScore = victim:GetScore()
    if theirScore < tooMuchScore:GetInt() then return end
    local scoreAboveX = theirScore - tooMuchScore:GetInt()

    local scoreToDrop = scoreAboveX / 2
    if scoreToDrop < 10 then return end

    scoreToDrop = math.ceil( scoreToDrop )

    victim:GivePlayerScore( -scoreToDrop )
    huntersGlee_Announce( { victim }, 1, 5, "You've died with too much score.\n" .. scoreToDrop .. " score is left behind." )

    while scoreToDrop > 0 do
        local droppedBall = ents.Create( "termhunt_score_pickup" )
        droppedBall:SetPos( victim:GetPos() + vector_up * 25 )

        local theBallsScore = math.Clamp( scoreToDrop, 0, math.random( 90, 110 ) )
        scoreToDrop = scoreToDrop + -theBallsScore
        droppedBall:SetScore( theBallsScore )
        droppedBall:Spawn()

        if IsValid( droppedBall:GetPhysicsObject() ) then
            droppedBall:GetPhysicsObject():SetVelocity( VectorRand() * math.random( 10, 30 ) )

        end
    end
end )