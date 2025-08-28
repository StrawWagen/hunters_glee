
CreateConVar( "huntersglee_players_cannot_swim", 1, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED ), "Block players from swimming?.", 0, 1 )
CreateConVar( "huntersglee_cannotswim_graceperiod", 4.5, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED ), "How long to let players swim for?.", 0, 64 )

if SERVER then
    hook.Add( "glee_sv_validgmthink", "glee_playerdrowning", function( players )
        for _, ply in ipairs( players ) do
            if ply:Health() <= 0 then continue end
            local wata = ply:WaterLevel()
            if wata >= 2 and ply:IsOnFire() then
                ply:Extinguish()
            end
            if wata >= 3 then
                if ply.glee_drowning then
                    if ply.glee_drowning < CurTime() then
                        local dmginfo = DamageInfo()
                        local count = ply.glee_drowning_damagecount or 0
                        ply.glee_drowning_damagecount = count + 1
                        local drownDamage = ( ply:GetMaxHealth() / 25 ) + ply.glee_drowning_damagecount * 2
                        dmginfo:SetDamage( drownDamage )
                        dmginfo:SetDamageType( DMG_DROWN )
                        dmginfo:SetAttacker( game.GetWorld() )
                        dmginfo:SetInflictor( game.GetWorld() )

                        ply:TakeDamageInfo( dmginfo )
                        -- have started drowning properly
                        ply.glee_drowning = CurTime() + 1.25
                        GAMEMODE:GivePanic( ply, 25 )
                    end
                else
                    -- will start drowning soon
                    ply.glee_drowning = CurTime() + 8
                    ply.glee_drowning_damagecount = 0
                    GAMEMODE:GivePanic( ply, 45 )
                end
            else
                ply.glee_drowning_damagecount = nil
                ply.glee_drowning = nil

            end
        end
    end )
end

hook.Add( "PlayerDeath", "glee_resetdrowning", function( ply )
    ply.glee_drowning_damagecount = nil
    ply.glee_drowning = nil

end )

local blockPlySwimmingCached

local function blockPlySwimming() -- TODO; JUST GET THE RETURN OF CREATECONVAR WTF IS THIS OLD CODE
    if not blockPlySwimmingCached then
        blockPlySwimmingCached = GetConVar( "huntersglee_players_cannot_swim" )

    end
    return blockPlySwimmingCached

end

local gracePeriodLengthCached

local function getDrowningGracePeriod()
    if not gracePeriodLengthCached then
        gracePeriodLengthCached = GetConVar( "huntersglee_cannotswim_graceperiod" )

    end
    return gracePeriodLengthCached

end

local function RemoveKeys( data, keys )
    -- Using bitwise operations to clear the key bits.
    local newbuttons = bit.band( data:GetButtons(), bit.bnot( keys ) )
    data:SetButtons( newbuttons )

end

hook.Add( "SetupMove", "glee_unabletoswim", function( ply, mvd )
    if blockPlySwimming():GetBool() ~= true then return end
    local waterLvl = ply:WaterLevel()
    local cur = CurTime()
    if waterLvl >= 2 and ply:Health() > 0 and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
        if SERVER then
            local nextWaterSound = ply.glee_nextWaterSound or 0

            if ply.glee_DoSufferingSplash and waterLvl >= 2 and nextWaterSound < cur then
                ply.glee_DoSufferingSplash = nil
                ply.glee_nextWaterSound = cur + math.Rand( 0.2, 0.8 )
                if waterLvl == 2 then
                    ply:EmitSound( "ambient/water/water_splash" .. math.random( 1, 3 ) .. ".wav", 75 )

                elseif waterLvl == 3 then
                    ply:EmitSound( "player/footsteps/wade" .. math.random( 1, 8 ) .. ".wav", 75, math.random( 60, 80 ) )

                end
            end

            if waterLvl == 2 and nextWaterSound < cur then
                ply.glee_nextWaterSound = cur + math.Rand( 1, 2 )
                ply:EmitSound( "ambient/water/water_splash" .. math.random( 1, 3 ) .. ".wav", 75 )

            elseif waterLvl == 3 and nextWaterSound < cur then
                ply.glee_nextWaterSound = cur + math.Rand( 1.5, 3 )
                ply:EmitSound( "player/footsteps/wade" .. math.random( 1, 8 ) .. ".wav", 75, math.random( 40, 60 ) )

            end
        end

        local noswimming_briefrespite = ply.glee_noswimming_briefrespite or 0
        local noswimming_lastlandlubbering = ply.glee_noswimming_lastlandlubbering or 0
        local timeSinceFreeFromWater = math.abs( noswimming_lastlandlubbering - cur )

        if not ply:IsOnGround() then
            if ply.glee_drowning then
                ply.glee_drowning = ply.glee_drowning + -0.003

            end
            if noswimming_briefrespite < cur then -- give them a couple seconds of swimming
                local timeItTakesToLoseSwim = getDrowningGracePeriod():GetFloat()
                local swimmingStrengthNormalized = timeSinceFreeFromWater / timeItTakesToLoseSwim
                local maxTheyCanGoUp = -swimmingStrengthNormalized * 400

                maxTheyCanGoUp = maxTheyCanGoUp + 400
                if maxTheyCanGoUp > 0 and SERVER then
                    -- warn ply
                    GAMEMODE:GivePanic( ply, 5 )

                end
                maxTheyCanGoUp = math.Clamp( maxTheyCanGoUp, -100, 400 )

                local vel = mvd:GetVelocity()
                local newZ = math.Clamp( vel.z, -400, maxTheyCanGoUp )
                vel.z = newZ
                mvd:SetVelocity( vel )

                if mvd:KeyDown( IN_JUMP ) then
                    RemoveKeys( mvd, IN_JUMP )

                end
            end
        else
            ply.glee_noswimming_briefrespite = cur + 0.8
            ply.glee_noswimming_lastlandlubbering = cur + -( getDrowningGracePeriod():GetFloat() / 2 )
            ply.glee_nextWaterSound = cur + 0.8
            ply.glee_DoSufferingSplash = true

        end
    elseif ply:IsOnGround() then
        ply.glee_noswimming_lastlandlubbering = cur

    end
end )