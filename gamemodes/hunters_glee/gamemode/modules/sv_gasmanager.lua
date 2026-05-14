
local gasModels = {
    ["models/props_junk/gascan001a.mdl"] = true,
    ["models/props_junk/metalgascan.mdl"] = true,
}

function GM:CreateGas( pos )
    local ent = ents.Create( "prop_physics" )
    if not IsValid( ent ) then return end

    local model = table.Random( gasModels )
    ent:SetModel( model )
    ent:SetPos( pos )
    ent:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
    ent:Spawn()

    self:RegisterAsGas( ent )

end

function GM:RegisterAsGas( ent )
    if not IsValid( ent ) then return end

    self.GasList = self.GasList or {}

    ent.glee_IsGas = true
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
