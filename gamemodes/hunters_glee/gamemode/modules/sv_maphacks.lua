-- tweaks to map entities, so maps play nice with the hunt
-- cleanup respawns every map entity, so GM:ApplyMapHacks runs after each one, see shared.lua's postCleanupMap


-- doors

-- mess up locked doors on door heavy maps
local function hackDoors( gm )
    local doors = ents.FindByClass( "prop_door_rotating" )
    for _, door in ipairs( doors ) do
        door:SetKeyValue( "returndelay", "-1" )

    end
    if #doors > 30 then
        for _, door in ipairs( doors ) do
            if door:GetInternalVariable( "m_bLocked" ) ~= true then continue end
            if not terminator_Extras.CanBashDoor( door ) then continue end -- door is decor

            local areaIsBig = nil
            local area = gm:getNearestNavFloor( door:WorldSpaceCenter() )

            if area and area:IsValid() then
                -- door is creating blocked flag, unlock it!
                local maxSize = math.max( area:GetSizeX(), area:GetSizeY() )
                areaIsBig = maxSize > 26

            end

            if not areaIsBig then continue end

            door:Fire( "Unlock" )

        end
    end
end


-- movers

-- elevators should ALWAYS have the ability to crush things
-- no teddybear elevators please
local minMoverCrush = 1

local function hackMovers()
    for _, mover in ipairs( ents.FindByClass( "func_movelinear" ) ) do
        if mover:GetInternalVariable( "m_flBlockDamage" ) >= minMoverCrush then continue end

        mover:SetKeyValue( "blockdamage", minMoverCrush )

    end
end


--[[---------------------------------------------------------
    GM:ApplyMapHacks
    Applies every map entity tweak.
    Needs the navmesh, the door unlocking checks nav area sizes.
    @return: None
--]]---------------------------------------------------------
function GM:ApplyMapHacks()
    hackDoors( self )
    hackMovers()

end
