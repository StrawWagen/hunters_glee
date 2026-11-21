-- skulls from the evil crawler and evil snake addons become real glee skulls
-- those addons spill plain prop_physics HGIBS skulls when an egg is cracked open, and the crawler spits one back up after eating a head
-- in glee those count for nothing, so swap each one for a termhunt_skull_pickup right where it is, keeping its momentum
-- only runs in the gamemode itself, sandbox keeps the addons' plain bone props

-- the addons aren't touched. Instead their own methods are wrapped:
-- an egg's ENT:Break spills its bones right there, a crawler's ENT:Spit spits them a moment later from a timer.Simple
-- while either is running, every prop_physics created is one of theirs, so it's known exactly, no guessing by distance
-- a skull prop anyone else spawns is never touched, however close it is

local IsValid = IsValid

local skullModel = "models/gibs/hgibs.mdl"

-- class, and the method that makes its bones
local spillers = {
    evil_crawler_egg = "Break",
    evil_snake_egg = "Break",
    evil_crawler = "Spit",
}

-- the egg or crawler whose bones are being made right now, nil otherwise
local spilling

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

-- runs fn with spilling set to who, and back again even if it errors
local function asSpiller( who, fn, ... )
    local old = spilling
    spilling = who
    local ok, err = pcall( fn, ... )
    spilling = old
    if not ok then ErrorNoHaltWithStack( err ) end

end

-- a crawler spits from a timer.Simple, so its timers are wrapped too, only the ones made inside Spit
local function wrapTimers( who, fn, ... )
    local realSimple = timer.Simple
    timer.Simple = function( delay, callback )
        return realSimple( delay, function( ... ) asSpiller( who, callback, ... ) end )

    end
    local ok, err = pcall( fn, ... )
    timer.Simple = realSimple
    if not ok then ErrorNoHaltWithStack( err ) end

end

-- wraps the class's bone-making method, once. Again after the addon autorefreshes, that replaces it
local function wrapSpiller( class )
    local stored = scripted_ents.GetStored( class )
    if not stored or not stored.t then return end

    local ENT = stored.t
    local methodName = spillers[class]
    local method = ENT[methodName]
    if not method or ENT.glee_SkullsWrapped == method then return end

    local wrapped = function( self, ... )
        asSpiller( self, wrapTimers, self, method, self, ... )

    end
    ENT[methodName] = wrapped
    ENT.glee_SkullsWrapped = wrapped

end

local function setupHooks()
    for class in pairs( spillers ) do
        wrapSpiller( class )

    end

    hook.Add( "OnEntityCreated", "glee_evilskulls_convert", function( ent )
        if not IsValid( ent ) then return end
        local class = ent:GetClass()

        if spillers[class] then
            wrapSpiller( class ) -- in case the addon autorefreshed since
            return

        end

        if not spilling or class ~= "prop_physics" then return end

        -- its model and speed are set after it's created, so a tick later
        timer.Simple( 0, function()
            if not IsValid( ent ) then return end
            if ent.EvilEggFed then return end -- already being swallowed by an egg
            if string.lower( ent:GetModel() or "" ) ~= skullModel then return end -- ribs and spines stay bones

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
