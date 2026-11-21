-- skulls from the evil crawler and evil snake addons become real glee skulls
-- those addons spill plain prop_physics HGIBS skulls when an egg is cracked open, and the crawler spits one back up after eating a head
-- in glee those count for nothing, so swap each one for a termhunt_skull_pickup right where it is, keeping its momentum
-- only runs in the gamemode itself, sandbox keeps the addons' plain bone props

-- the addons call EvilBoneSpilled( bone, source ) on every bone they spill or spit, see their eggs' Bone and the crawler's Spit
-- so only their own skulls are ever swapped, a skull prop someone spawns is left alone, however close it is

local IsValid = IsValid

local skullModel = "models/gibs/hgibs.mdl"

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
    hook.Add( "EvilBoneSpilled", "glee_evilskulls_convert", function( bone )
        if not IsValid( bone ) then return end
        if string.lower( bone:GetModel() or "" ) ~= skullModel then return end -- ribs and spines stay bones

        -- a tick later, so it's flying with the speed it was given
        timer.Simple( 0, function()
            if not IsValid( bone ) then return end
            if bone.EvilEggFed then return end -- already being swallowed by an egg

            convertSkull( bone )

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
