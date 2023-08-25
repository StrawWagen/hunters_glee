if SERVER then

    CreateConVar( "huntersglee_players_cannot_swim", 1, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Block players from swimming?.", 0, 32 )

    function GM:managePlayerDrowning( players )
        for _, ply in ipairs( players ) do
            if ply:WaterLevel() >= 3 then
                if ply:IsOnFire() then
                    ply:Extinguish()
                end

                if ply.glee_drowning then
                    if ply.glee_drowning < CurTime() then
                        local dmginfo = DamageInfo()
                        dmginfo:SetDamage( ply:GetMaxHealth() / 25 )
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
                    GAMEMODE:GivePanic( ply, 45 )
                end
            else
                ply.glee_drowning = nil

            end
        end
    end

end

local blockPlySwimmingCached

local function blockPlySwimming()
    if not blockPlySwimmingCached then
        blockPlySwimmingCached = GetConVar( "huntersglee_players_cannot_swim" )

    end
    return blockPlySwimmingCached

end

local CMoveData = FindMetaTable( "CMoveData" )

function CMoveData:RemoveKeys( keys )
    -- Using bitwise operations to clear the key bits.
    local newbuttons = bit.band( self:GetButtons(), bit.bnot( keys ) )
    self:SetButtons( newbuttons )

end

hook.Add( "SetupMove", "glee_unabletoswim", function( ply, mvd )
    if not blockPlySwimming() then return end
    if blockPlySwimming():GetBool() ~= true then return end
    local waterLvl = ply:WaterLevel()
    if waterLvl >= 2 and ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
        if SERVER then
            local nextWaterSound = ply.glee_nextWaterSound or 0

            if ply.glee_DoSufferingSplash and waterLvl >= 2 and nextWaterSound < CurTime() then
                ply.glee_DoSufferingSplash = nil
                ply.glee_nextWaterSound = CurTime() + math.Rand( 0.2, 0.8 )
                if waterLvl == 2 then
                    ply:EmitSound( "ambient/water/water_splash" .. math.random( 1, 3 ) .. ".wav", 75 )

                elseif waterLvl == 3 then
                    ply:EmitSound( "player/footsteps/wade" .. math.random( 1, 8 ) .. ".wav", 75, math.random( 60, 80 ) )

                end
            end

            if waterLvl == 2 and nextWaterSound < CurTime() then
                ply.glee_nextWaterSound = CurTime() + math.Rand( 1, 2 )
                ply:EmitSound( "ambient/water/water_splash" .. math.random( 1, 3 ) .. ".wav", 75 )

            elseif waterLvl == 3 and nextWaterSound < CurTime() then
                ply.glee_nextWaterSound = CurTime() + math.Rand( 1.5, 3 )
                ply:EmitSound( "player/footsteps/wade" .. math.random( 1, 8 ) .. ".wav", 75, math.random( 40, 60 ) )

            end
        end

        local noswimming_briefrespite = ply.glee_noswimming_briefrespite or 0

        if not ply:IsOnGround() then
            if ply.glee_drowning then
                ply.glee_drowning = ply.glee_drowning + -0.003

            end
            if noswimming_briefrespite < CurTime() then
                local vel = mvd:GetVelocity()
                local newZ = -vel.z * 1.115
                newZ = math.Clamp( newZ, -400, -45 )
                vel.z = newZ
                mvd:SetVelocity( vel )

                if mvd:KeyDown( IN_JUMP ) then
                    mvd:RemoveKeys( IN_JUMP )

                end
            end
        else
            ply.glee_noswimming_briefrespite = CurTime() + 0.8
            ply.glee_nextWaterSound = CurTime() + 0.8
            ply.glee_DoSufferingSplash = true

        end
    end
end )