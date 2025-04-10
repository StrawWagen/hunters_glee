
AddCSLuaFile()

sound.Add( {
    name = "loud_asf_thunder",
    channel = CHAN_STATIC,
    level = 140,
    volume = 0.8,
    sound = "397952_kinoton_thunder-clap-and-rumble-1.wav"
} )

function glee_CanOvercharge( target )
    if target.DoMetallicDamage then return true end
    if target:GetMaxHealth() < terminator_Extras.healthDefault * 0.5 then return false end
    return true

end

function glee_Overcharge( target )
    target:Overcharge()
    target:ReallyAnger( 120 )

    target:EmitSound( "ambient/levels/labs/electric_explosion1.wav", 100, 80 )

    local timerName = "terminator_overchargedpower_" .. target:GetCreationID()

    timer.Create( timerName, 0.1, 0, function()
        if not IsValid( target ) then timer.Remove( timerName ) return end
        if target:Health() <= 0 then timer.Remove( timerName ) return end

        if math.random( 0, 100 ) > 25 then return end

        target:EmitSound( "LoudSpark" )
        local hitTr = termHunt_ElectricalArcEffect( target, target:WorldSpaceCenter(), -vector_up, math.Rand( 0.5, 1 ), vector_up, 1000 )

        local zzarpedEnt = hitTr.Entity

        if not IsValid( zzarpedEnt ) then return end
        zzarpedEnt:Fire( "IgniteLifetime", 5 )

    end )
end

hook.Add( "EntityTakeDamage", "glee_interceptlightningdamage", function( target, dmgInfo ) 
    local inflic = dmgInfo:GetInflictor()
    if not IsValid( inflic ) then return end
    if not inflic.glee_inflictingLightning then return end
    if target:IsPlayer() and target:Health() > 0 then
        if dmgInfo:GetDamage() > ( target:Health() * 2 ) and not target:HasWeapon( "termhunt_divine_chosen" ) then
            local oldModel = target:GetModel()
            target:SetModel( "models/player/skeleton.mdl" )
            if GAMEMODE.Bleed then
                GAMEMODE:Bleed( target, 200 )

            end
            -- they lived!
            timer.Simple( 0.05, function()
                if not IsValid( target ) then return end
                if target:Health() <= 0 then return end
                if target:GetModel() ~= "models/player/skeleton.mdl" then return end
                target:SetModel( oldModel )

            end )
        end
    elseif target:IsNextBot() and target.isTerminatorHunterChummy then
        if math.random( 500, 10000 ) > dmgInfo:GetDamage() then return end
        dmgInfo:ScaleDamage( 0.1 )
        glee_Overcharge( target )
    end
end )

if not SERVER then return end

local recipFilterEveryone = RecipientFilter()

function termHunt_ElectricalArcEffect( parent, startPos, targetDir, scale, initialDir, dist )
    recipFilterEveryone:AddAllPlayers()

    local ToVector = targetDir
    local Dist = dist or 25000
    local WanderDirection = initialDir or targetDir
    local NumPoints = 50
    local PointTable = {}
    local OldPoint = startPos
    local inWallCount = 0

    local lastNotInWall = startPos

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
            lastNotInWall = OldPoint
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

    local _, hitTr = terminator_Extras.PosCanSee( lastNotInWall, OldPoint )

    if scale < 1 then return hitTr end

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

    return hitTr

end

local function dirToPos( startPos, endPos )
    if not startPos then return vec_zero end
    if not endPos then return vec_zero end

    return ( endPos - startPos ):GetNormalized()

end


local vecNeg5Hundred = Vector( 0,0,-500 )
local vectorUp25 = Vector( 0, 0, 25 )

function termHunt_PowafulLightning( inflic, attacker, strikingPos, powa )
    if not IsValid( attacker ) then
        attacker = inflic

    end
    --HACK!
    inflic.glee_inflictingLightning = true

    -- call the hunters
    sound.EmitHint( SOUND_COMBAT, strikingPos, 8000, 1, inflic )

    for index = 1, powa * 2 do
        local size = index * 5
        local offset = Vector( math.random( -size, size ), math.random( -size, size ) )
        local target = strikingPos + vecNeg5Hundred + offset
        util.Decal( "Scorch", strikingPos + vectorUp25 + offset, target, nil )

    end

    util.ScreenShake( strikingPos, 15, 20, 1.5, 1200, true )
    util.ScreenShake( strikingPos, 1, 20, 1.5, 3000, true )

    timer.Simple( 0, function()
        terminator_Extras.GleeFancySplode( strikingPos + vectorUp25, powa * 55, 100 + powa * 55, attacker, inflic )

    end )

    local flash = EffectData()
    flash:SetScale( powa / 2 )
    flash:SetOrigin( strikingPos + vector_up )
    util.Effect( "eff_huntersglee_strikeeffect", flash )

    termHunt_ElectricalArcEffect( inflic, strikingPos, vector_up, powa )

    for _, thing in ipairs( ents.FindInSphere( strikingPos, 400 ) ) do
        if not IsValid( thing ) then continue end
        if IsValid( thing:GetParent() ) then continue end

        local dir = dirToPos( strikingPos, thing:GetPos() )

        local dmgType = DMG_SHOCK
        local damageScale = 1
        if powa > 4 and strikingPos:DistToSqr( thing:GetPos() ) < 100^2 then
            dmgType = bit.bor( DMG_DISSOLVE, DMG_SHOCK )
            damageScale = 10

        end

        if not dir then return end

        local damage = DamageInfo()
        damage:SetDamage( powa * damageScale * 100 ^ 1.1 )
        damage:SetDamagePosition( strikingPos )
        damage:SetAttacker( attacker )
        damage:SetInflictor( inflic )
        damage:SetDamageType( dmgType )
        damage:SetDamageForce( dir * 1000 )
        thing:TakeDamageInfo( damage )

        if thing ~= attacker and thing:IsSolid() and not ( thing:IsWeapon() and IsValid( thing:GetOwner() ) and thing:GetOwner():IsPlayer() ) then
            thing:Fire( "IgniteLifetime", powa * 5 )

        end
    end
    if powa >= 4 then
        inflic:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 140, math.random( 80, 120 ) + -powa * 4, 0.8, CHAN_STATIC )

    end

    if powa >= 5.5 then
        local bigHit = CreateSound( inflic, "hunters_glee/wizardry_thunderimpact.wav", recipFilterEveryone )
        bigHit:SetSoundLevel( 150 )
        bigHit:ChangeVolume( 1 )
        bigHit:ChangePitch( 100 )
        bigHit:Play()

        local bigEcho = CreateSound( inflic, "ambient/levels/labs/teleport_postblast_thunder1.wav", recipFilterEveryone )
        bigEcho:SetSoundLevel( 150 )
        bigEcho:ChangeVolume( 1 )
        bigEcho:ChangePitch( 80 )
        bigEcho:Play()

        local biggHIT = CreateSound( inflic, "hunters_glee/wizardry_thunder.wav", recipFilterEveryone )
        biggHIT:SetSoundLevel( 150 )
        biggHIT:ChangeVolume( 1 )
        biggHIT:ChangePitch( 80 )
        biggHIT:Play()

        util.ScreenShake( strikingPos, 20, 20, 2, 16000, true )

    end

    --HACK!
    timer.Simple( 0, function()
        inflic.glee_inflictingLightning = nil

    end )

end