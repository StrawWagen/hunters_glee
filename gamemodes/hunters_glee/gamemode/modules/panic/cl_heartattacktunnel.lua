
-- Tunnel vision as a heart attack builds, the closer to the attack, the tighter it closes
-- sv_player.lua networks how far along the attack is, as glee_heartattack. cl_tunnelvision.lua draws it

local noReturnProgress = 0.533 -- matches DoHeartAttackThink, past this the attack climbs on its own, so it's fully closed by here
local firstTwingeStrength = 0.4 -- the first beat over the threshold already shows
local heartAttackClear = 0.4 -- of screen height, once it's fully closed
local heartAttackColor = Color( 80, 0, 6 )

-- before RenderScreenspaceEffects, where the tunnel's drawn
hook.Add( "PreRender", "glee_heartattacktunnel", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) or not ply:SeesThroughOwnEyes() then return end

    local progress = ply:GetNWFloat( "glee_heartattack", 0 )
    if progress <= 0 then return end

    local strength = math.Remap( math.min( progress, noReturnProgress ), 0, noReturnProgress, firstTwingeStrength, 1 )
    GAMEMODE:RequestTunnelVision( strength, heartAttackClear, nil, nil, heartAttackColor )

end )
