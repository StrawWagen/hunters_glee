
-- named non-players, eg the shop's turrets, or a spawnset's .spawns prettyName
function GM:GetDeathNoticeEntityName( ent )
    if isentity( ent ) and IsValid( ent ) then
        if ent.Nick then return ent:Nick() end

        local prettyName = ent:GetNWString( "glee_PrettyName", "" )
        if prettyName ~= "" then return prettyName end

    end

    return self.BaseClass.GetDeathNoticeEntityName( self, ent )

end
