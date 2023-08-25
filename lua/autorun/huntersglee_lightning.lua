
AddCSLuaFile()

sound.Add( {
    name = "loud_asf_thunder",
    channel = CHAN_STATIC,
    level = 140,
    volume = 0.8,
    sound = "397952_kinoton_thunder-clap-and-rumble-1.wav"
} )

if not SERVER then return end

local recipFilterEveryone = RecipientFilter()

function termHunt_ElectricalArcEffect( parent, startPos, targetDir, scale )
    recipFilterEveryone:AddAllPlayers()

    local ToVector = targetDir
    local Dist = 25000
    local WanderDirection = targetDir
    local NumPoints = 100
    local PointTable = {}
    local OldPoint = startPos
    local inWallCount = 0
    PointTable[1] = startPos

    for i = 2, NumPoints do
        local NewPoint = OldPoint + WanderDirection * ( Dist / NumPoints )

        PointTable[i] = NewPoint
        OldPoint = NewPoint
        WanderDirection = ( WanderDirection + VectorRand() + ToVector * 0.4 ):GetNormalized()

        if not util.IsInWorld( NewPoint ) then
            inWallCount = inWallCount + 1
            if inWallCount > 10 then break end
        else
            inWallCount = 0
        end
    end

    for key, point in ipairs( PointTable ) do
        local next = PointTable[key + 1]
        if point and next then
            local Beam = EffectData()
            Beam:SetStart( point )
            Beam:SetOrigin( next )
            Beam:SetScale( scale )
            util.Effect( "eff_termhunt_plasmaarc", Beam, recipFilterEveryone )

        end
    end

    local pitOffs = math.abs( scale - 4 )
    pitOffs = -pitOffs * 10
    -- pitoffs goes from 0 at 4 scale
    -- to +40 at 0 scale

    local lvl = 140
    local volume = 0.6
    if scale >= 4 then
        lvl = 140
        volume = 1
        parent:EmitSound( "loud_asf_thunder" )

    end

    local loudOnePitch = 120 + pitOffs
    local bigThunderClap = CreateSound( parent, "397952_kinoton_thunder-clap-and-rumble-1.wav", recipFilterEveryone )

    bigThunderClap:SetSoundLevel( lvl )
    bigThunderClap:ChangeVolume( volume )
    bigThunderClap:ChangePitch( loudOnePitch )
    bigThunderClap:Play()

end

local function dirToPos( startPos, endPos )
    if not startPos then return vec_zero end
    if not endPos then return vec_zero end

    return ( endPos - startPos ):GetNormalized()

end


local vecNegHunFifty = Vector( 0,0,-150 )

function termHunt_PowafulLightning( inflic, parent, strikingPos, powa )
    inflic = inflic or parent

    sound.EmitHint( SOUND_COMBAT, strikingPos, 8000, 1, parent )

    termHunt_ElectricalArcEffect( parent, strikingPos, vector_up, powa )

    util.Decal( "Scorch", strikingPos, strikingPos + vecNegHunFifty, nil )

    util.ScreenShake( strikingPos, 15, 20, 1.5, 1200 )
    util.ScreenShake( strikingPos, 1, 20, 1.5, 3000 )

    local explode = ents.Create( "env_explosion" )
    explode:SetPos( strikingPos )
    explode:SetOwner( inflic )
    explode:Spawn()
    explode:SetKeyValue( "iMagnitude", powa * 55 )
    explode:Fire( "Explode", 0, 0.05 )

    for _, thing in ipairs( ents.FindInSphere( strikingPos, 200 ) ) do
        if not IsValid( thing ) then continue end
        if IsValid( thing:GetParent() ) then continue end

        local dir = dirToPos( strikingPos, thing:GetPos() )

        if not dir then return end

        local damage = DamageInfo()
        damage:SetDamageType( DMG_SHOCK )
        damage:SetDamage( powa * 100 ^ 1.1 )
        damage:SetDamagePosition( strikingPos )
        damage:SetDamageForce( dir * 1000 )
        damage:SetAttacker( inflic )
        damage:SetInflictor( parent )
        thing:TakeDamageInfo( damage )

        if thing ~= parent and not thing:IsPlayer() and thing:IsSolid() then
            thing:Fire( "IgniteLifetime", powa * 4 )

        end
    end
    if powa >= 4 then
        parent:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 140, math.random( 80, 120 ) + -powa * 4, 0.8, CHAN_STATIC )

    end
    if powa >= 5 then
        local bigEcho = CreateSound( parent, "ambient/levels/labs/teleport_postblast_thunder1.wav", recipFilterEveryone )
        bigEcho:SetSoundLevel( 150 )
        bigEcho:ChangeVolume( 1 )
        bigEcho:ChangePitch( 80 )
        bigEcho:Play()

    end
end