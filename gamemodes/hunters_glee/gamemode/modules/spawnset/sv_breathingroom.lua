
-- add extra delay between waves

GM.breathingRoomScale = 0

function GM:SetRoundBreathingRoom( scale )
    self.breathingRoomScale = scale

end

function GM:GetRoundBreathingRoom()
    return self.breathingRoomScale

end

local blockTimeAddedLowHealth = 120
local blockTimeAddedOnFire = 120
local blockTimeAddedMediumHealth = 40
local blockTimeAddedFullHealth = -60
local blockTimeAddedNotMoving = 30
local blockTimeAddedNeverOpenedShop = 15
local blockTimeAddedNeverShopped = 15

local blockTimeAddedDidntMoveFar = 20
local blockTimeAddedDidntMoveAtAll = 40
local moveFar = 350^2 -- "far"
local move = 100^2

local function updateWaveStartPositions()
    local startOfWavePositions = GAMEMODE.breathingRoom_startOfWavePositions
    if not startOfWavePositions then
        startOfWavePositions = {}
        GAMEMODE.breathingRoom_startOfWavePositions = startOfWavePositions

    else
        table.Empty( startOfWavePositions )

    end

    for _, ply in player.Iterator() do
        if not GAMEMODE:plyIsHuntable( ply ) then continue end
        startOfWavePositions[ply] = ply:GetPos()

    end
end

hook.Add( "huntersglee_round_into_active", "breathing_room", function()
    if GAMEMODE.breathingRoomScale <= 0 then return end
    updateWaveStartPositions()

end )
hook.Add( "huntersglee_postwavegenerated", "breathing_room", function()
    if GAMEMODE.breathingRoomScale <= 0 then return end
    updateWaveStartPositions()

end )
hook.Add( "huntersglee_spawnwavegeneration_block", "breathing_room", function()
    if GAMEMODE.breathingRoomScale <= 0 then return end
    local sinceLastWave = CurTime() - GAMEMODE.lastSpawnWave
    local startOfWavePositions = GAMEMODE.breathingRoom_startOfWavePositions

    local blockTimes = {}
    local huntableCount = 0

    for _, ply in ipairs( player.GetAll() ) do
        if not GAMEMODE:plyIsHuntable( ply ) then continue end
        if ply:IsBot() then continue end -- not useful, don't wait for bots

        huntableCount = huntableCount + 1

        local hp = ply:Health()
        local maxHp = ply:GetMaxHealth()
        if hp <= maxHp * 0.15 then
            blockTimes["lowHealth"] = ( blockTimes["lowHealth"] or 0 ) + blockTimeAddedLowHealth

        elseif hp <= maxHp * 0.5 then
            blockTimes["mediumHealth"] = ( blockTimes["mediumHealth"] or 0 ) + blockTimeAddedMediumHealth

        elseif hp >= maxHp * 0.99 then
            blockTimes["fullHealth"] = ( blockTimes["fullHealth"] or 0 ) + blockTimeAddedFullHealth

        end

        if not GAMEMODE:HasLearnedLesson( ply, "OpenedShop" ) then
            blockTimes["neverBrowsed"] = ( blockTimes["neverBrowsed"] or 0 ) + blockTimeAddedNeverOpenedShop

        end

        if not GAMEMODE:HasLearnedLesson( ply, "BoughtAnItem" ) then
            blockTimes["neverShopped"] = ( blockTimes["neverShopped"] or 0 ) + blockTimeAddedNeverShopped

        end

        if ply:IsOnFire() then
            blockTimes["onFire"] = ( blockTimes["onFire"] or 0 ) + blockTimeAddedOnFire

        end

        local plysSpeedSqr = ply:GetVelocity():LengthSqr()
        if plysSpeedSqr <= 10^2 then
            blockTimes["notMoving"] = ( blockTimes["notMoving"] or 0 ) + blockTimeAddedNotMoving

        end

        if startOfWavePositions then
            local ourPosAtWaveStart = startOfWavePositions[ply]
            if ourPosAtWaveStart then
                local distMovedSinceLastWave = ply:GetPos():DistToSqr( ourPosAtWaveStart )

                if distMovedSinceLastWave < move then
                    blockTimes["moveAtAll"] = ( blockTimes["moveAtAll"] or 0 ) + blockTimeAddedDidntMoveAtAll

                elseif distMovedSinceLastWave < moveFar then
                    blockTimes["moveFar"] = ( blockTimes["moveFar"] or 0 ) + blockTimeAddedDidntMoveFar

                end
            end
        end
    end

    if huntableCount <= 0 then return true end -- nobodys ready for the hunt yet

    local blockTime = 0
    for _name, added in pairs( blockTimes ) do
        --print( _name, added )
        blockTime = blockTime + added

    end
    blockTime = blockTime / huntableCount
    blockTime = blockTime * GAMEMODE.breathingRoomScale

    --print( blockTime, sinceLastWave, blockTime > sinceLastWave )

    if blockTime > sinceLastWave then return true end -- BLOCK

end )

-- the spawnset is re-set every round, so a mid-round SetRoundBreathingRoom lasts until the next round
hook.Add( "glee_post_set_spawnset", "breathing_room_reset", function( _setName, spawnSet )
    local scale = spawnSet.breathingRoom
    GAMEMODE.breathingRoomScale = scale

end )
