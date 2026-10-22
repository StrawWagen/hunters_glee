
-- named non-players, eg the shop's turrets
function GM:GetDeathNoticeEntityName( ent )
    if isentity( ent ) and IsValid( ent ) and ent.Nick then return ent:Nick() end

    return self.BaseClass.GetDeathNoticeEntityName( self, ent )

end
