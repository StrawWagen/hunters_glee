--AAAAA

local plyMeta = FindMetaTable( "Player" )

function plyMeta:GetBatteryCharge()
    return self:GetNW2Float( "glee_precicebatterycharge", 0 )

end

function plyMeta:PlayerHasBatteryCharge()
    return self:GetBatteryCharge() > 0

end