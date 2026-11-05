terminator_Extras = terminator_Extras or {}

-- the flyers go for heavy targets first, a gunship or a heli is what it takes to put one down
local gleeFlightHeavies = terminator_Extras.gleeFlightHeavies or {}
terminator_Extras.gleeFlightHeavies = gleeFlightHeavies

local heavyHealth = 1500
-- above the 99 the rescue heli feuds at, so the engine picks these first
local heavyPriority = 200

function gleeFlightHeavies.IsHeavy( ent )
    return ent:Health() > heavyHealth or ent.ReallyHeavy == true

end

-- every think, after anything else that sets relationships, they'd knock it back down
function gleeFlightHeavies.PrioritizeKnownHeavies( npc )
    for _, enemy in ipairs( npc:GetKnownEnemies() ) do
        if not IsValid( enemy ) then continue end
        if not gleeFlightHeavies.IsHeavy( enemy ) then continue end
        if npc:Disposition( enemy ) ~= D_HT then continue end

        npc:AddEntityRelationship( enemy, D_HT, heavyPriority )

    end
end
