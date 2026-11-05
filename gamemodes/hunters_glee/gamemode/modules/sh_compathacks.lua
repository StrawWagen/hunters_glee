-- fixes for other addons misbehaving under glee

if SERVER then
    -- sit anywhere parents seats to the player being sat on, but doesn't eject riders on KillSilent
    hook.Add( "PostPlayerDeath", "glee_compat_ejectsitters", function( ply )
        for _, child in ipairs( ply:GetChildren() ) do
            if not child:IsVehicle() then continue end

            local driver = child:GetDriver()
            if IsValid( driver ) then
                driver:ExitVehicle()

            end
        end
    end )
end
