local danceSpeed = 50

hook.Add( "StartCommand", "glee_dancingnoattack", function( ply, cmd )
    if not ply:IsPlayingTaunt2() then return end
    cmd:RemoveKey( IN_ATTACK )
    cmd:RemoveKey( IN_ATTACK2 )

    cmd:SetForwardMove( math.Clamp( cmd:GetForwardMove(), -danceSpeed, danceSpeed ) )
    cmd:SetSideMove( math.Clamp( cmd:GetSideMove(), -danceSpeed, danceSpeed ) )
    cmd:SetUpMove( math.Clamp( cmd:GetUpMove(), -danceSpeed, danceSpeed ) )

end )

if SERVER then
    local plyMeta = FindMetaTable( "Player" )

    plyMeta.glee_OldDoAnimEvent = plyMeta.glee_OldDoAnimEvent or plyMeta.DoAnimationEvent

    function plyMeta:DoAnimationEvent( ... )
        local blockFor = self.glee_BlockAnimEventsFor
        if blockFor and blockFor > CurTime() then return end
        if hook.Run( "glee_blockanimevent", self, ... ) == true then return end
        plyMeta.glee_OldDoAnimEvent( self, ... )

    end

    function plyMeta:BlockAnimEventsFor( duration )
        self.glee_BlockAnimEventsFor = CurTime() + duration

    end

    function plyMeta:IsPlayingTaunt2()
        if not self:Alive() then return end
        return self.glee_IsDancin or self:IsPlayingTaunt()

    end

    function plyMeta:TauntDance( ACT )
        ACT = ACT or ACT_GMOD_TAUNT_DANCE
        local danceSeq = self:SelectWeightedSequence( ACT )

        if not danceSeq then return end

        local length = self:SequenceDuration( danceSeq )

        self.glee_IsDancin = true

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:DoAnimationEvent( ACT )
            self:SetNW2Bool( "glee_isdancing", true )
            self:SetNW2Int( "glee_stopsdancing", CurTime() + length )
            self:BlockAnimEventsFor( length + 0.1 )

        end )

        timer.Simple( length, function()
            if not IsValid( self ) then return end

            self:SetNW2Bool( "glee_isdancing", false )
            self:SetNW2Int( "glee_stopsdancing", 0 )
            self.glee_IsDancin = nil

        end )

        return true

    end
else
    local plyMeta = FindMetaTable( "Player" )

    function plyMeta:IsPlayingTaunt2()
        if not self:Alive() then return end
        local isForcedDance = ( self:GetNW2Bool( "glee_isdancing", false ) and self:GetNW2Int( "glee_stopsdancing" ) > CurTime() )
        return isForcedDance or self:IsPlayingTaunt()

    end
end
