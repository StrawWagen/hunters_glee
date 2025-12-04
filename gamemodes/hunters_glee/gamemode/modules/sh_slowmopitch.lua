
local hostTimescale = GetConVar( "host_timescale" )

hook.Add( "EntityEmitSound", "zzz_glee_slowmopitchhook", function( soundData )
    local ts = game.GetTimeScale()
    if ts == 1 then return end

    soundData.Pitch = math.Clamp( soundData.Pitch * hostTimescale:GetFloat(), 0, 255 )
    return true

end )


-- yield to tfa
local function TFACheck()
    local hookTable = hook.GetTable()
    if not hookTable.EntityEmitSound then return end
    if not hookTable.EntityEmitSound["zzz_TFA_EntityEmitSound"] then return end

    hook.Remove( "EntityEmitSound", "zzz_glee_slowmopitchhook" )

end

TFACheck()

-- check again after everything loads
hook.Add( "InitPostEntity", "glee_slowmopitch_detectTFA", TFACheck )