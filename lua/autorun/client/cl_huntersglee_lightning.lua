
-- Every sound a lightning strike makes. The server sends one message per strike saying
-- where it landed and how hard, and the thresholds below decide the rest, so all of it
-- can be scaled by a setting the server never sees.

local thunderClap = "hunters_glee/397952_kinoton_thunder-clap-and-rumble-1.wav"

local volumeConvar = CreateClientConVar( "cl_huntersglee_lightningvolume")

local function lightningVolume()
    return volumeConvar:GetFloat()

end

net.Receive( "glee_lightning_sound", function()
    local strikingPos = net.ReadVector()
    local powa        = net.ReadFloat()

    local volumeMul = lightningVolume()
    if volumeMul <= 0 then return end

    -- clap
    if powa >= 1 then
        -- pitch tops out at powa 4 and falls 10 either side of it, so 80 at powa 0
        local pitOffs = -math.abs( powa - 4 ) * 10

        local volume = 0.6
        if powa >= 4 then
            volume = 1
            -- the same clip again underneath, unpitched, to thicken the big ones
            sound.Play( thunderClap, strikingPos, 140, 100, 0.8 * volumeMul )

        end

        sound.Play( thunderClap, strikingPos, 140, 120 + pitOffs, volume * volumeMul )

    end

    -- fff-wOOSH
    if powa >= 4 then
        sound.Play( "ambient/levels/labs/electric_explosion3.wav", strikingPos, 140, math.random( 80, 120 ) + -powa * 4, 0.8 * volumeMul )

    end

    if powa >= 5.5 then
        -- ker-THUD
        sound.Play( "hunters_glee/wizardry_thunderimpact.wav", strikingPos, 150, 100, volumeMul )

        -- echo, echo echo
        sound.Play( "ambient/levels/labs/teleport_postblast_thunder1.wav", strikingPos, 150, 80, volumeMul )

        -- khaCHOW!
        sound.Play( "hunters_glee/wizardry_thunder.wav", strikingPos, 150, 80, volumeMul )

    end
end )
