
sound.Add( {
    name = "loud_asf_thunder",
    channel = CHAN_STATIC,
    level = 140,
    volume = 0.8,
    sound = "hunters_glee/397952_kinoton_thunder-clap-and-rumble-1.wav"
} )

function glee_CanOvercharge( target )
    return target:CanOvercharge()

end

function glee_Overcharge( target )
    target:Overcharge()

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

util.AddNetworkString( "glee_lightning_sound" )

local recipFilterEveryone = RecipientFilter()

local function dirToPos( startPos, endPos )
    if not startPos then return vec_zero end
    if not endPos then return vec_zero end

    return ( endPos - startPos ):GetNormalized()

end


local vecNeg5Hundred = Vector( 0, 0, -500 )
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

    -- the arc wanders up out of the strike, one beam per step, and gives up once it has
    -- spent 10 steps running outside the map
    recipFilterEveryone:AddAllPlayers()

    local arcDist = 25000
    local arcPoints = 50
    local wanderDir = vector_up
    local oldPoint = strikingPos
    local pointTable = { strikingPos }
    local inWallCount = 0

    for i = 2, arcPoints do
        local newPoint = oldPoint + wanderDir * ( arcDist / arcPoints )

        pointTable[i] = newPoint
        oldPoint = newPoint
        wanderDir = ( wanderDir + VectorRand() + vector_up * 0.4 ):GetNormalized()

        if not util.IsInWorld( newPoint ) then
            inWallCount = inWallCount + 1
            if inWallCount > 10 then break end

        else
            inWallCount = 0

        end
    end

    for key, point in ipairs( pointTable ) do
        local nextPoint = pointTable[key + 1]
        if nextPoint then
            local beam = EffectData()
            beam:SetStart( point )
            beam:SetOrigin( nextPoint )
            beam:SetScale( powa )
            util.Effect( "eff_termhunt_plasmaarc", beam, recipFilterEveryone )

        end
    end

    for _, thing in ipairs( ents.FindInSphere( strikingPos, 400 ) ) do
        if not IsValid( thing ) then continue end
        if IsValid( thing:GetParent() ) then continue end

        local dir = dirToPos( strikingPos, thing:GetPos() )

        local dmgType = DMG_SHOCK
        local damageScale = 1

        -- DIRECT HIT!
        if powa > 4 and strikingPos:DistToSqr( thing:GetPos() ) < 100^2 then
            dmgType = bit.bor( DMG_DISSOLVE, DMG_SHOCK )
            damageScale = 10

        elseif not terminator_Extras.PosCanSee( strikingPos, thing:WorldSpaceCenter() ) then
            damageScale = 0.25

        end

        local damageAmount = powa * damageScale * 100 ^ 1.1

        if damageAmount < 1 then continue end

        thing:SetNWBool( "glee_recentlyStruckByLightning", true )
        timer.Simple( 0.1, function()
            if not IsValid( thing ) then return end
            thing:SetNWBool( "glee_recentlyStruckByLightning", false )

        end )

        local damage = DamageInfo()
        damage:SetDamage( damageAmount )
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

    -- every clap, woosh and thud is picked and played in cl_huntersglee_lightning.lua,
    -- so a listener can turn the whole strike down without the server knowing
    net.Start( "glee_lightning_sound" )
        net.WriteVector( strikingPos )
        net.WriteFloat( powa )
    net.Broadcast()

    if powa >= 5.5 then
        util.ScreenShake( strikingPos, 20, 20, 2, 16000, true )

    end

    --HACK!
    timer.Simple( 0, function()
        inflic.glee_inflictingLightning = nil

    end )
end