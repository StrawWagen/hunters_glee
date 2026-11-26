--[[
    Actions, for when players need to choose between an entity's actions. All on terminator_Extras.glee_Actions.

        ENT.GleeActions = {
            { key = "tune", label = "Tune", icon = Material( "..." ) },
        }
        function ENT:CanGleeAction( ply, key ) end -- shared, optional. true, or false and a reason, that greys it out
        function ENT:OnGleeAction( ply, key ) end  -- server, true when it went through

        -- instead of GleeActions, for actions that change, eg a label showing a setting
        function ENT:GetGleeActions() end

    SWEPs take the same fields.
    Engine classes, see Register.

    An action that's on lots of entities can bring its own canPick( ent, ply ) and run( ent, ply ),
    eg glee_carrying's PickUpAction, those beat the entity's.

    Sometimes there's only one, an entity that only ever has one, or a list slimmed down while it's carried.
    That one skips the wheel and just runs, see Pick.

    How the player gets at the entity is a reach, see RegisterReach.
    glee_carrying's use is one, holding the SWEP is another, "held", below.
    A reach picks for the player, see Pick in sv_actions.lua, or opens the wheel, see OpenWheel in cl_actions.lua.
]]

terminator_Extras = terminator_Extras or {}
terminator_Extras.glee_Actions = terminator_Extras.glee_Actions or {}

local glee_Actions = terminator_Extras.glee_Actions


-- Engine classes -------------------------------------------------------------

-- Register's defs, by class
-- kept on the table, other files registered these, an autorefresh of this file won't run them again
glee_Actions.ClassDefs = glee_Actions.ClassDefs or {}
local classDefs = glee_Actions.ClassDefs

-- shared, gives an engine class actions
-- def takes the same fields as an ENT, its functions take the ent first, eg def.CanGleeAction( ent, ply, key )
-- def.Matches( ent ), optional, narrows it down within the class
-- other systems keep their own fields on it too, eg glee_carrying's GleeCarryWeapon
-- registering the same id again replaces it, so autorefresh is fine
function glee_Actions.Register( class, id, def )
    def.Id = id

    local defs = classDefs[class] or {}
    classDefs[class] = defs

    for index, existing in ipairs( defs ) do
        if existing.Id == id then
            defs[index] = def
            return

        end
    end

    table.insert( defs, def )

end

-- where ent's actions are defined, the ent itself, or a def registered for its class
-- nil when it has neither
-- a def with Matches beats a catch-all, whatever order they were registered in
function glee_Actions.GetDef( ent )
    if ent.GleeActions or ent.GetGleeActions then return ent end

    local defs = classDefs[ent:GetClass()]
    if not defs then return end

    local catchAll
    for _, def in ipairs( defs ) do
        if not def.Matches then
            catchAll = catchAll or def

        elseif def.Matches( ent ) then
            return def

        end
    end

    return catchAll

end


-- Actions --------------------------------------------------------------------

-- everything ent has, nil when it has none
-- don't edit what it returns, it's usually the def's own table
function glee_Actions.Get( ent )
    local def = glee_Actions.GetDef( ent )
    if not def then return end

    if def.GetGleeActions then return def.GetGleeActions( ent ) end
    return def.GleeActions

end

-- the action in actions with key, nil if there isn't one
function glee_Actions.Find( actions, key )
    for _, action in ipairs( actions or {} ) do
        if action.key == key then return action end

    end
end

-- can ply pick key off ent? false, and maybe a reason, if not
-- shared, so the wheel greys out what the server would refuse
-- not whether they can get at it, that's the reach's
function glee_Actions.CanPick( ply, ent, key )
    if not ply:Alive() then return false end

    local action = glee_Actions.Find( glee_Actions.Get( ent ), key )
    if not action then return false end
    if action.canPick then return action.canPick( ent, ply ) end

    local def = glee_Actions.GetDef( ent )
    if not def.CanGleeAction then return true end

    local canPick, reason = def.CanGleeAction( ent, ply, key )
    return canPick, reason

end


-- Reaches --------------------------------------------------------------------

glee_Actions.Reaches = glee_Actions.Reaches or {}
local reaches = glee_Actions.Reaches

-- shared, a way for players to get at entities' actions, by name
-- reach.InReach( ply, ent ), can ply get at ent this way
--     the server refuses picks when it's false, the client closes the wheel
-- reach.Actions( ent ), optional, what it offers this way, all of them if nil
-- reach.BeforeRun( ply, ent, key ), server, optional, just before a pick runs
-- registering it again replaces it, so autorefresh is fine
function glee_Actions.RegisterReach( name, reach )
    reaches[name] = reach

end

-- nil for a reach that isn't registered
function glee_Actions.GetReach( name )
    return reaches[name]

end

-- what ent offers through reach, nil when nothing
function glee_Actions.Offered( reach, ent )
    if reach.Actions then return reach.Actions( ent ) end
    return glee_Actions.Get( ent )

end

-- the SWEP in their hands
glee_Actions.RegisterReach( "held", {
    InReach = function( ply, wep )
        return ply:GetActiveWeapon() == wep

    end,
} )
