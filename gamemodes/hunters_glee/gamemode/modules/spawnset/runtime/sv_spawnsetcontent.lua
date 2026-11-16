
-- a misery's resourcesAdded, workshop ids sent to every client while it's active. clients can't unmount, so it stays after
-- the downloading lives in terminator_Extras.AddOnDemandWorkshop

local addedIds = {}

hook.Add( "glee_post_new_spawnset", "glee_spawnset_content", function( _, spawnSet )
    -- removed first, two miseries can share an id
    for _, id in ipairs( addedIds ) do
        terminator_Extras.RemoveOnDemandWorkshop( id )

    end
    addedIds = {}

    local resourcesAdded = spawnSet.resourcesAdded
    if not resourcesAdded then return end

    for _, id in ipairs( resourcesAdded ) do
        terminator_Extras.AddOnDemandWorkshop( id )
        table.insert( addedIds, id )

    end
end )
