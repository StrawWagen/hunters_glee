
-- How spawn protected players look. sv_firsttimeplayers.lua gives and takes it

local GAMEMODE = GAMEMODE or GM

GAMEMODE:RegisterStatusEffect( "spawn_protection",
    function( self, _owner )
        local preDrawing = {}
        self:HookOnce( "PrePlayerDraw", function( ply )
            if not ply:HasStatusEffect( "spawn_protection" ) then return end
            preDrawing[ply] = true

            local pulse = math.abs( math.sin( CurTime() * 2 ) ) * 0.25 + 0.2
            render.SetBlend( pulse )
            render.SetColorModulation( 0.6, 0.8, 1 )

        end )
        self:HookOnce( "PostPlayerDraw", function( ply )
            if not preDrawing[ply] then return end
            preDrawing[ply] = nil

            render.SetBlend( 1 )
            render.SetColorModulation( 1, 1, 1 )

        end )
    end
)
