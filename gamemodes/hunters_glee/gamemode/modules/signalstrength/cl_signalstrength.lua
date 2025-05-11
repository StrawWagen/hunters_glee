local math = math

local meta = FindMetaTable( "Player" )
local nextSend = 0

function meta:GetSignalStrength()
    local base = self:GetNW2Int( "glee_signalstrength", 0 )
    local static = self:GetNW2Int( "glee_signalstrength_static", 100 )

    if nextSend < CurTime() then
        nextSend = CurTime() + 1
        net.Start( "glee_updatesignalstrength" )
        net.SendToServer()

    end

    return math.Clamp( base + math.random( -static, 0 ), 0, 100 )

end