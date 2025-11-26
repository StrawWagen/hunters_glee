
local plyMeta = FindMetaTable( "Player" )
local nw2NamePrefix = "glee_hasstatuseffect_"

function plyMeta:HasStatusEffect( name )
    return self:GetNW2Bool( nw2NamePrefix .. name, false )

end