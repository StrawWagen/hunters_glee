function termHunt_ElectricalArcEffect( Attacker, Victim, Powa )
    local VictimPos = Victim:LocalToWorld( Victim:OBBCenter() )
    local SelfPos = Attacker:GetPoz()
    local ToVector = VictimPos - SelfPos
    local Dist = ToVector:Length()
    local Dir = ToVector:GetNormalized()
    local WanderDirection = self:GetUp()
    local NumPoints = math.Clamp( math.ceil( 60 * Dist / 1000 ) + 1, 1, 60 )
    local PointTable = {}
    PointTable[1] = SelfPos

    for i = 2, NumPoints do
        local NewPoint
        local WeCantGoThere = true
        local C_P_I_L = 0

        while WeCantGoThere do
            NewPoint = PointTable[i - 1] + WanderDirection * Dist / NumPoints
            local CheckTr = {}
            CheckTr.start = PointTable[i - 1]
            CheckTr.endpos = NewPoint

            CheckTr.filter = { Attacker, Victim }

            local CheckTra = util.TraceLine( CheckTr )

            if CheckTra.Hit then
                WanderDirection = ( WanderDirection + CheckTra.HitNormal * 0.5 ):GetNormalized()
            else
                WeCantGoThere = false
            end

            C_P_I_L = C_P_I_L + 1

            if C_P_I_L >= 200 then
                print( "CRASH PREVENTION" )
                break
            end
        end

        PointTable[i] = NewPoint
        WanderDirection = ( WanderDirection + VectorRand() * 0.35 + ( VictimPos - NewPoint ):GetNormalized() * 0.2 ):GetNormalized()
    end

    PointTable[NumPoints + 1] = VictimPos

    for key, point in pairs( PointTable ) do
        if not ( key == NumPoints + 1 ) then
            local Harg = EffectData()
            Harg:SetStart( point )
            Harg:SetOrigin( PointTable[key + 1] )
            Harg:SetScale( Powa / 50 )
            util.Effect( "eff_jack_plasmaarc", Harg )
        end
    end

    local Randim = math.Rand( 0.95, 1.05 )
    local SoundMod = math.Clamp( ( 50 - self.CapacitorMaxCharge ) / 50 * 30, -40, 40 )
    sound.Play( "snd_jack_zapang.mp3", SelfPos, 90 - SoundMod / 2, 110 * Randim + SoundMod )
    sound.Play( "snd_jack_zapang.mp3", VictimPos, 80 - SoundMod / 2, 111 * Randim + SoundMod )
    sound.Play( "snd_jack_smallthunder.mp3", SelfPos, 120, 100 )
end

function EFFECT:Init( data )
    self.StartPos = data:GetStart()
    self.EndPos = data:GetOrigin()
    self.Scayul = data:GetScale() ^ 0.5
    self.Delay = math.Clamp( 0.06 * data:GetScale(), 0.025, 0.06 )
    self.EndTime = CurTime() + self.Delay
    self:SetRenderBoundsWS( self.StartPos, self.EndPos )
    local dlightend = DynamicLight( 0 )
    dlightend.Pos = self.EndPos
    dlightend.Size = 500 * self.Scayul
    dlightend.Decay = 10000
    dlightend.R = 100
    dlightend.G = 150
    dlightend.B = 255
    dlightend.Brightness = 3 * self.Scayul
    dlightend.DieTime = CurTime() + self.Delay
end

function EFFECT:Think()
    if self.EndTime < CurTime() then
        return false
    else
        return true
    end
end

function EFFECT:Render()
    self:SetRenderBoundsWS( self.StartPos, self.EndPos )

    local Beamtwo = CreateMaterial( "xeno/beamgauss", "UnlitGeneric", {
        ["$basetexture"] = "sprites/spotlight",
        ["$additive"] = "1",
        ["$vertexcolor"] = "1",
        ["$vertexalpha"] = "1",
    } )

    render.SetMaterial( Beamtwo )
    render.DrawBeam( self.StartPos, self.EndPos, Lerp( ( self.EndTime - CurTime() ) / self.Delay, 0, 8 * self.Scayul ), 0, 0, Color( 100, 150, 255, 254 ) )
end