local meta = FindMetaTable( "Player" )

function meta:GetScore()
    return self:GetNWInt( "huntersglee_score", 0 )

end

function meta:GetSkulls()
    return self:GetNWInt( "huntersglee_skulls", 0 )

end

if SERVER then
    function meta:GivePlayerScore( add )
        if hook.Run( "huntersglee_givescore", self, add ) == false then return end
        local score = self:GetScore()
        self:SetNWInt( "huntersglee_score", math.Round( score + add ) )
    end

    function meta:GivePlayerSkulls( add )
        if hook.Run( "huntersglee_giveskulls", self, add ) == false then return end
        local skulls = self:GetSkulls()
        self:SetNWInt( "huntersglee_skulls", math.Round( skulls + add ) )
    end

    function meta:ResetScore()
        self:SetNWInt( "huntersglee_score", 0 )

    end

    function meta:ResetSkulls()
        self:SetNWInt( "huntersglee_skulls", 0 )

    end
end

