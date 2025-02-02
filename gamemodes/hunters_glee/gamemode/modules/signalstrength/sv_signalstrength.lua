local centerOffset = Vector( 0, 0, 25 )

local meta = FindMetaTable( "Player" )

-- 1-100
function meta:GetSignalStrength( area )
    if self:Health() <= 0 then return 100, 0 end

    if not area then
        area = self:GetNavAreaData()

    end

    if not area then return 5, 50 end

    local pos = area:GetCenter() + centerOffset

    local signalFinal = 0
    local staticFinal = 0
    if not GAMEMODE.highestAreaZ then
        signalFinal = 45
        staticFinal = ( area:GetID() % 30 ) + 20

    elseif not GAMEMODE.isSkyOnMap then
        local distToHighest = GAMEMODE.highestAreaZ - pos.z
        signalFinal =  25 - ( distToHighest / 1000 )
        staticFinal = ( area:GetID() % 30 ) + 20

    elseif not GAMEMODE.areasUnderSky[ area ] then
        local neighborCount = 0
        local exposedScore = 0
        local checked = {}
        for _, neighbor in ipairs( area:GetAdjacentAreas() ) do
            if checked[neighbor] then continue end
            checked[neighbor] = true
            neighborCount = neighborCount + 1
            if GAMEMODE.areasUnderSky[neighbor] then
                exposedScore = math.Clamp( exposedScore + 2, 4, math.huge )

            end
            -- wecursive!
            for _, rNeighbor in ipairs( neighbor:GetAdjacentAreas() ) do
                if checked[rNeighbor] then continue end
                neighborCount = neighborCount + 1
                checked[rNeighbor] = true
                if GAMEMODE.areasUnderSky[rNeighbor] then
                    exposedScore = math.Clamp( exposedScore + 0.5, 2, math.huge )

                end
            end
        end

        local base = 35 + ( ( exposedScore / neighborCount ) * 100 )
        local distToHighest = GAMEMODE.highestZ - pos.z
        signalFinal = base - ( distToHighest / 1000 )
        staticFinal = area:GetID() % 10

    else
        local distToHighest = GAMEMODE.highestZ - pos.z
        signalFinal = 100 - ( distToHighest / 1000 )
        staticFinal = area:GetID() % 5

    end

    local returnedSignal, returnedStatic = hook.Run( "glee_signalstrength_update", self, signalFinal, staticFinal )
    if returnedSignal then
        signalFinal = returnedSignal

    end
    if returnedStatic then
        staticFinal = returnedStatic

    end

    signalFinal = math.Clamp( signalFinal, 0, 100 )

    return signalFinal, staticFinal

end

function meta:UpdateSignalStrength( nav )
    local strength, static = self:GetSignalStrength( nav )
    self:SetNW2Int( "glee_signalstrength", strength )
    self:SetNW2Int( "glee_signalstrength_static", static )

end

hook.Add( "glee_ply_changednavareas", "glee_updatesignalstrength", function( ply, _, new )
    ply:UpdateSignalStrength( new )

end )

hook.Add( "PlayerDeath", "glee_updatesignalstrengthondeath", function( died )
    died:UpdateSignalStrength()

end )

hook.Add( "PlayerSpawn", "glee_updatesignalstrengthonrespawn", function( spawned )
    timer.Simple( 0, function()
        if not IsValid( spawned ) then return end
        spawned:UpdateSignalStrength()

    end )
end )

util.AddNetworkString( "glee_updatesignalstrength" )

local nextRecieve = 0
net.Receive( "glee_updatesignalstrength", function( _, ply )
    if nextRecieve > CurTime() then return end
    nextRecieve = CurTime() + 0.01

    hook.Run( "glee_signalstrength_used", ply )

    ply:UpdateSignalStrength()

end )