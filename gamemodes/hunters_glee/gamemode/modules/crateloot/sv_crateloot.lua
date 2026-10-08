-- Players breaking box and crate props can turn up supplies, bigger boxes more often
-- Props that drop their own loot when broken set .glee_HasOwnLoot to opt out

local biggestBoxVolume = 109100 -- the biggest default box
local biggestBoxChance = 0.45
local emptyBoxChance = 0.05

local function isBoxOrCrate( prop )
    if prop:GetClass() ~= "prop_physics" then return false end

    local model = string.lower( prop:GetModel() or "" )
    return string.find( model, "crate", 1, true ) ~= nil or string.find( model, "box", 1, true ) ~= nil

end

local insideScale = 0.5 -- keeps the supplies away from the box's walls

local function randomPointInside( prop )
    local mins, maxs = prop:OBBMins(), prop:OBBMaxs()
    local center = ( mins + maxs ) / 2
    local halfExtents = ( maxs - mins ) / 2 * insideScale

    local localPoint = center + Vector(
        math.Rand( -halfExtents.x, halfExtents.x ),
        math.Rand( -halfExtents.y, halfExtents.y ),
        math.Rand( -halfExtents.z, halfExtents.z )
    )
    return prop:LocalToWorld( localPoint )

end

hook.Add( "PropBreak", "glee_crateloot", function( breaker, broken )
    if not IsValid( breaker ) or not breaker:IsPlayer() then return end
    if not isBoxOrCrate( broken ) then return end

    if broken.glee_HasOwnLoot then return end

    local physObj = broken:GetPhysicsObject()
    if not IsValid( physObj ) then return end

    local sizeFraction = math.Clamp( physObj:GetVolume() / biggestBoxVolume, 0, 1 )
    local chance = Lerp( sizeFraction, emptyBoxChance, biggestBoxChance )
    if math.random() > chance then return end

    local supplies = ents.Create( "dynamic_resupply_fake" )
    supplies:SetPos( randomPointInside( broken ) )
    supplies:Spawn()

end )
