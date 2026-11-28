
-- Small helpers both realms use, outside the gamemode so weapons and entities work without it.
-- Server only ones are in server/sv_glee_functions.lua

terminator_Extras = terminator_Extras or {}

if SERVER then
    AddCSLuaFile()

end

local bit_band = bit.band
local util_PointContents = util.PointContents

--[[---------------------------------------------------------
    terminator_Extras.glee_IsInWall
    Inside a wall, or out in the void past the map's edge, both read as solid brush.
    World brushes only, props and brush entities don't count.
    Works clientside, unlike util.IsInWorld, and costs far less than a trace.
    @param pos: The point to check.
    @return: true if it's in solid brush.
--]]---------------------------------------------------------
function terminator_Extras.glee_IsInWall( pos )
    return bit_band( util_PointContents( pos ), MASK_SOLID_BRUSHONLY ) > 0

end

-- other addons' creatures, that aren't NPCs or nextbots, by classname, each with how to tell it's alive
-- the addon need not be installed, a key's only a classname, and each checks what it uses first
local otherAlive = {
    -- Evil Crawling Thing
    ["evil_crawler"] = function( ent )
        return EvilCrawler and ent.GetAct and ent:GetAct() ~= EvilCrawler.ACT_DEAD

    end,
}

--[[---------------------------------------------------------
    terminator_Extras.glee_IsAliveThing
    Players, NPCs and nextbots that are alive, and other addons' creatures that are, see otherAlive above.
    What the goggles that find the living look for.
    @param ent: Any entity, or NULL.
    @return: true if it's alive.
--]]---------------------------------------------------------
function terminator_Extras.glee_IsAliveThing( ent )
    if not IsValid( ent ) then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end

    local isAlive = otherAlive[ent:GetClass()]
    return isAlive and isAlive( ent ) or false

end
