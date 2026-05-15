
local gasModels = {
    ["models/props_junk/gascan001a.mdl"] = true,
    ["models/props_junk/metalgascan.mdl"] = true,
}

function GM:SpawnGas( pos )
    local ent = ents.Create( "prop_physics" )
    if not IsValid( ent ) then return end

    local keys = table.GetKeys( gasModels )
    local model = keys[math.random( 1, #keys )]
    ent:SetModel( model )
    ent:SetPos( pos )
    ent:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
    ent:Spawn()

    self:RegisterAsGas( ent )

end

function GM:RegisterAsGas( ent )
    if not IsValid( ent ) then return end

    ent.glee_IsGas = true

    self.GasList = self.GasList or {}
    table.insert( self.GasList, ent )

    ent:CallOnRemove( "glee_gas_cleanup", function()
        table.RemoveByValue( self.GasList, ent )

    end )
end

local gasMessagesOnPickup = {
    "There's still some gas in this...",
    "Woah, still some gas in this.",
    "There's some gas left in this.",
    "Some gas still in this.",
}

hook.Add( "OnPlayerPhysicsPickup", "glee_gas_hint", function( ply, ent )
    if not ent.glee_IsGas then return end

    ent.glee_GasSloshSound = CreateSound( ent, "ambient/water/water_in_boat1.wav" )
    ent.glee_GasSloshSound:PlayEx( 0.5, math.random( 80, 120 ) )

    local stopDelay = math.Rand( 0.5, 1 )
    ent.glee_GasSloshSound:FadeOut( stopDelay )

    local timerName = "glee_gas_slosh_cleanup_" .. ent:EntIndex()
    timer.Create( timerName, stopDelay + 0.1, 1, function()
        if not IsValid( ent ) then return end
        ent.glee_GasSloshSound:Stop()

    end )

    local nextHint = ply.glee_NextGasHint or 0
    if nextHint > CurTime() then return end

    ply.glee_NextGasHint = CurTime() + 120

    huntersGlee_Announce( { ply }, 50, 5, gasMessagesOnPickup[math.random( 1, #gasMessagesOnPickup )] )

end )

hook.Add( "OnEntityCreated", "glee_gas_registernewgas", function( ent )
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        local model = ent:GetModel()
        if not model then return end
        if not gasModels[model] then return end
        GAMEMODE:RegisterAsGas( ent )

    end )
end )

hook.Add( "glee_onspawned_glidevehicle", "glee_glidevehicle_gassing", function( veh )
    veh.isEngineEnabled = false
    veh.glee_IsWaitingForGas = true

    GAMEMODE:AddGasUser( veh )

    veh.glee_OldGlidePhysicsCollide = veh.PhysicsCollide
    function veh:PhysicsCollide( data, phys )
        local otherEnt = data.HitEntity
        if IsValid( otherEnt ) and otherEnt.glee_IsGas and self.glee_IsWaitingForGas then
            self.glee_IsWaitingForGas = nil
            self.isEngineEnabled = true
            self.glee_GasFillSound = CreateSound( self, "ambient/water/water_in_boat1.wav" )
            self.glee_GasFillSound:Play()

            local stopDelay = 4
            self.glee_GasFillSound:FadeOut( stopDelay )

            local timerName = "glee_gas_fill_cleanup_" .. self:EntIndex()
            timer.Create( timerName, stopDelay + 0.1, 1, function()
                if not IsValid( self ) then return end
                self.glee_GasFillSound:Stop()

            end )

            timer.Simple( 0, function()
                if not IsValid( otherEnt ) then return end
                SafeRemoveEntity( otherEnt )

            end )
        end

        return self:glee_OldGlidePhysicsCollide( data, phys )

    end

    veh.glee_OldGlideOnDriverEnter = veh.OnDriverEnter
    function veh:OnDriverEnter()
        local driver = self:GetDriver()

        if self.glee_IsWaitingForGas then
            huntersGlee_Announce( { driver }, 50, 5, "It won't start.\nIt's out of gas..." )
            return

        end

        return self:glee_OldGlideOnDriverEnter( driver )

    end
end )


-- register user(vehicle, teleporter generator) for the random gas spawner to spawn gas around
function GM:AddGasUser( ent )
    if not IsValid( ent ) then return end

    self.GasUsers = self.GasUsers or {}
    table.insert( self.GasUsers, ent )

    ent:CallOnRemove( "glee_gasuser_cleanup", function()
        table.RemoveByValue( self.GasUsers, ent )

    end )

end


local nextGasSpawnCheck = 0
local offsetFromGround = Vector( 0, 0, 25 )
local mapGasCount = 4

hook.Add( "glee_sv_validgmthink_active", "glee_addgasjobs", function()
    if nextGasSpawnCheck > CurTime() then return end

    local noSpawnWait = GAMEMODE:ScaledGenericSpawnerRate( 15 )
    local allGas = GAMEMODE.GasList
    if allGas and #allGas >= mapGasCount then nextGasSpawnCheck = CurTime() + noSpawnWait return end

    local gasUsers = GAMEMODE.GasUsers
    if not gasUsers or #gasUsers == 0 then nextGasSpawnCheck = CurTime() + noSpawnWait return end

    local gasJob = {}
    gasJob.jobsName = "gas_spawner"

    local aRandomUser = gasUsers[math.random( 1, #gasUsers )]
    if not IsValid( aRandomUser ) then -- will probably never happen, probably
        table.RemoveByValue( gasUsers, aRandomUser )
        return

    end

    gasJob.posFindingOrigin = aRandomUser:GetPos()
    gasJob.spawnRadius = math.random( 2500, 5000 )
    gasJob.originIsDefinitive = true
    gasJob.sortForNearest = true
    gasJob.areaFilteringFunction = function( job, area )
        if area:IsBlocked() then return end
        if area:IsUnderwater() then return end
        local distToOrigin = area:GetCenter():Distance( job.posFindingOrigin )
        if distToOrigin < job.spawnRadius / 2 then return end -- TOO CLOSE
        return true

    end
    gasJob.hideFromPlayers = true
    gasJob.posDerivingFunc = function( _, area )
        local points = { area:GetRandomPoint() + offsetFromGround }
        for _, spot in ipairs( area:GetHidingSpots( 1 ) ) do
            table.insert( points, spot + offsetFromGround )

        end
        return points

    end
    gasJob.maxPositionsForScoring = 400
    gasJob.posScoringBudget = 1000
    gasJob.posScoringFunction = function( _, toCheckPos, budget )
        -- get nook score, the more nooked the point is, the bigger the score.
        local nookScore = terminator_Extras.GetNookScore( toCheckPos )

        budget = budget + - 1
        return nookScore

    end
    gasJob.onPosFoundFunction = function( _, bestPosition )

        local gas = GAMEMODE:SpawnGas( bestPosition )
        if not IsValid( gas ) then return false end

        gas:DropToFloor()
        hook.Run( "glee_proceduralgas_gasspawned", gas )

        -- remove gas really far away from players
        -- keeps people discovering gas
        local timerName = "glee_proceduralgas_removestale_" .. gas:GetCreationID()
        timer.Create( timerName, 120, 0, function()
            if not IsValid( gas ) then timer.Remove( timerName ) return end
            local gasPos = gas:GetPos()
            if bit.band( util.PointContents( gasPos ), CONTENTS_WATER ) ~= 0 then SafeRemoveEntity( gas ) timer.Remove( timerName ) return end
            local nearest, distSqr = GAMEMODE:nearestAlivePlayer( gasPos )
            if not IsValid( nearest ) then SafeRemoveEntity( gas ) timer.Remove( timerName ) return end
            if distSqr > 4000^2 then SafeRemoveEntity( gas ) timer.Remove( timerName ) return end

        end )

        return true

    end

    GAMEMODE:addProceduralSpawnJob( gasJob )
    --print( "ADDED" )
    --PrintTable( gasJob )

    nextGasSpawnCheck = CurTime() + GAMEMODE:ScaledGenericSpawnerRate( 20 )

end )