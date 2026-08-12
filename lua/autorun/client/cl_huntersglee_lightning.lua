
-- Every sound a lightning strike makes. The server sends one message per strike saying
-- where it landed and how hard, and the thresholds below decide the rest, so all of it
-- can be scaled by a setting the server never sees.

local thunderClaps = {
    "hunters_glee/397952_kinoton_thunder-clap-and-rumble-1.wav",
    "hunters_glee/521096__kinoton__thunder-clap-and-rumble-3.wav",
    "hunters_glee/760214__kinoton__thunder-clap-and-rumble-7.wav",
}

local volumeConvar = CreateClientConVar( "cl_huntersglee_lightningvolume", 1, true, false, "Sound volume for lightning strikes" )

local function lightningVolume()
    return volumeConvar:GetFloat()

end

local goodDelayMagicNum = 60000

local function getTimeDelayToFeel( ref )
    local dist = ref:Distance( LocalPlayer():GetPos() )
    local timeDelay = dist / goodDelayMagicNum
    return timeDelay, dist

end

local downOffset = Vector( 0, 0, -30 )

net.Receive( "glee_lightning_sound", function()
    local strikingPos = net.ReadVector()
    local powa        = net.ReadFloat()

    local volumeMul = lightningVolume()
    if volumeMul <= 0 then return end

    local delay = getTimeDelayToFeel( strikingPos )
    if powa < 4 then
        timer.Simple( delay, function()
            local contents = util.PointContents( strikingPos + downOffset )

            local explSound = "BaseExplosionEffect.Sound"
            if bit.band( contents, CONTENTS_WATER ) ~= 0 then
                explSound = "WaterExplosionEffect.Sound"

            end

            local vol = 0.5 + ( volumeMul * 0.5 )
            EmitSound( explSound, strikingPos, 0, CHAN_WEAPON, vol, 100, SND_NOFLAGS, math.random( 88, 120 ) )

        end )
    end

    -- clap
    if powa >= 1 then
        -- pitch tops out at powa 4 and falls 10 either side of it, so 80 at powa 0
        local pitOffs = -math.abs( powa - 4 ) * math.Rand( 9, 11 )

        local volume = 0.6
        if powa >= 4 then
            volume = 1

        end

        timer.Simple( delay, function()
            local clap = thunderClaps[math.random( 1, #thunderClaps )]
            sound.Play( clap, strikingPos, 140, 120 + pitOffs, volume * volumeMul )

        end )
    end

    -- fff-wOOSH
    if powa >= 4 then
        sound.Play( "ambient/levels/labs/electric_explosion3.wav", strikingPos, 115, math.random( 80, 120 ) + -powa * 4, volumeMul )

    end

    if powa >= 5.5 then
        -- ker-THUD
        sound.Play( "hunters_glee/wizardry_thunderimpact.wav", strikingPos, 125, math.random( 90, 100 ), volumeMul )

        local struckBySoundDist = 1500 + ( powa * 250 )
        local distToStrike = EyePos():Distance( strikingPos )
        if distToStrike < struckBySoundDist then
            local vol = 1 - ( distToStrike / struckBySoundDist )
            vol = vol * volumeMul
            EmitSound( "hunters_glee/141529__cheeseheadburger__struck-by-lightning.wav", strikingPos, -2, CHAN_STATIC, vol, 150, SND_NOFLAGS, math.random( 90, 100 ) )

        end
        timer.Simple( delay, function()
            -- echo, echo echo
            sound.Play( "ambient/levels/labs/teleport_postblast_thunder1.wav", strikingPos, 155, math.random( 50, 90 ), volumeMul )

            -- khaCHOW!
            sound.Play( "hunters_glee/wizardry_thunder.wav", strikingPos, 155, math.random( 70, 80 ) - ( delay * 8 ), volumeMul )

        end )
    end
end )
