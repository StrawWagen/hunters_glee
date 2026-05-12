
local gasModels = {
    "models/props_junk/gascan001a.mdl",
    "models/props_junk/metalgascan.mdl",
}

function GM:CreateGas( pos )
    local ent = ents.Create( "prop_physics" )
    if not IsValid( ent ) then return end

    ent:SetModel( gasModels[math.random( 1, #gasModels )] )
    ent:SetPos( pos )
    ent:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
    ent:Spawn()

    self:RegisterAsGas( ent )

end

function GM:RegisterAsGas( ent )
    if not IsValid( ent ) then return end
    ent.glee_IsGas = true

end

hook.Add( "OnPlayerPhysicsPickup" )