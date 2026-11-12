-- An innocent's halo striking whoever hurt them. Spikes the halo, see sh_innocenthalo.lua, and arcs from it to them
-- local fx = EffectData()
-- fx:SetOrigin( haloPos ) -- roughly where the halo is, the real spot's used when this client's drawing it
-- fx:SetStart( strikePos )
-- fx:SetEntity( innocent ) -- or NULL, to arc from the origin with no halo
-- util.Effect( "eff_glee_halosmite", fx )

local smiteColor = Angle( 220, 235, 255 )
local haloFreshness = 0.5 -- seconds, a halo drawn longer ago than this is somewhere else now

function EFFECT:Init( data )
    local from = data:GetOrigin()
    local to = data:GetStart()

    local innocent = data:GetEntity()
    if IsValid( innocent ) then
        local now = CurTime()
        innocent.glee_haloSmiteTime = now

        local drawnAt = innocent.glee_haloDrawnTime
        if drawnAt and now - drawnAt < haloFreshness then
            from = innocent.glee_haloCenter

        end
    end

    -- every setting set, see eff_term_goodarc
    local fx = EffectData()
        fx:SetOrigin( from )
        fx:SetStart( to )
        fx:SetNormal( vector_up ) -- leaps up off the halo, then comes down on them
        fx:SetScale( 3 )
        fx:SetMagnitude( 16 ) -- segments
        fx:SetRadius( 40 ) -- jitter
        fx:SetAngles( smiteColor )
        fx:SetDamageType( 4 ) -- branches
        fx:SetEntity( NULL )
        fx:SetFlags( 32 ) -- through walls, it always lands
    util.Effect( "eff_term_goodarc", fx )

end

function EFFECT:Think()
    return false

end

function EFFECT:Render()
end
