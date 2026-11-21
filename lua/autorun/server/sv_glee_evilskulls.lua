-- skulls from the evil crawler and evil snake addons become real glee skulls
-- those addons spill plain prop_physics HGIBS skulls when an egg is cracked open, and the crawler spits one back up after eating a head
-- in glee those count for nothing, so swap each one for a termhunt_skull_pickup right where it is, keeping its momentum
-- only runs in the gamemode itself, sandbox keeps the addons' plain bone props

local IsValid = IsValid
local CurTime = CurTime

local skullModel = "models/gibs/hgibs.mdl"

local eggClasses = {
    evil_crawler_egg = true,
    evil_snake_egg = true,
}

-- how close a skull has to be to a cracked egg or a crawler to count as its skull
-- eggs fling bones out at up to 180 u/s from ~10 units off center, crawlers spit them up to 280 u/s from 4 units away
local eggReach = 64
local crawlerReach = 48
local eggMemory = 1 -- seconds a cracked egg is remembered for, the bones spawn on the same tick it breaks

-- eggs remove themselves right after spilling their bones, so remember where they cracked
local crackedEggs = {}

local function nearCrackedEgg( pos )
    local cur = CurTime()
    local reachSqr = eggReach^2
    for i = #crackedEggs, 1, -1 do
        local egg = crackedEggs[i]
        if egg.time + eggMemory < cur then
            table.remove( crackedEggs, i )

        elseif egg.pos:DistToSqr( pos ) < reachSqr then
            return true

        end
    end
end

local function nearCrawler( pos )
    for _, ent in ipairs( ents.FindInSphere( pos, crawlerReach ) ) do
        if ent:GetClass() == "evil_crawler" then return true end

    end
end

local function convertSkull( prop )
    local pos = prop:GetPos()
    local ang = prop:GetAngles()
    local vel, angVel
    local oldObj = prop:GetPhysicsObject()
    if IsValid( oldObj ) then
        vel = oldObj:GetVelocity()
        angVel = oldObj:GetAngleVelocity()

    end

    -- out of the way before the new one spawns in the same spot
    prop:SetNotSolid( true )
    SafeRemoveEntity( prop )

    local skull = ents.Create( "termhunt_skull_pickup" )
    if not IsValid( skull ) then return end
    -- players who watch it fly out get the "that's its skull" hint, not "someone died here"
    skull.fromSomethingWitnessable = true
    skull:SetPos( pos )
    skull:SetAngles( ang )
    skull:Spawn()

    local newObj = skull:GetPhysicsObject()
    if IsValid( newObj ) and vel then
        newObj:SetVelocity( vel )
        newObj:AddAngleVelocity( angVel )

    end
end

local function setupHooks()
    hook.Add( "EntityRemoved", "glee_evilskulls_eggcracked", function( ent )
        if not eggClasses[ent:GetClass()] then return end
        if not ent.Broken then return end -- hatched, no bones

        table.insert( crackedEggs, { pos = ent:WorldSpaceCenter(), time = CurTime() } )

    end )

    hook.Add( "OnEntityCreated", "glee_evilskulls_convert", function( ent )
        if not IsValid( ent ) then return end
        if ent:GetClass() ~= "prop_physics" then return end

        -- model and position are set after creation, check next tick
        timer.Simple( 0, function()
            if not IsValid( ent ) then return end
            if ent.EvilEggFed then return end -- already being swallowed by an egg
            if string.lower( ent:GetModel() or "" ) ~= skullModel then return end

            local pos = ent:WorldSpaceCenter()
            if not nearCrackedEgg( pos ) and not nearCrawler( pos ) then return end

            convertSkull( ent )

        end )
    end )
end

hook.Add( "InitPostEntity", "glee_setupevilskulls", function()
    if gmod.GetGamemode().IsReallyHuntersGlee then
        setupHooks()

    end
end )

local theGamemode = gmod.GetGamemode()

-- autorefresh
if theGamemode and theGamemode.IsReallyHuntersGlee then
    setupHooks()

end
