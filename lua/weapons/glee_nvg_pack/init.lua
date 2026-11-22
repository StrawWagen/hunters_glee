AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

-- the server side of the pack: the client's wheel sends a key, the goggles come out and the pack goes

util.AddNetworkString( "glee_nvg_packpick" )

local packClass = "glee_nvg_pack"
local pickCooldown = 0.2

local function notify( ply, text, description )
    huntersGlee_Notify( { ply }, {
        text = text,
        description = description,
        kind = "bad",
        time = 4,
    } )
end

local function choiceOf( wep, key )
    for _, choice in ipairs( wep.Choices ) do
        if choice.key == key then return choice end

    end
end

net.Receive( "glee_nvg_packpick", function( _, ply )
    if ( ply.glee_NextPackPick or 0 ) > CurTime() then return end
    ply.glee_NextPackPick = CurTime() + pickCooldown
    if not ply:Alive() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or wep:GetClass() ~= packClass then return end

    local choice = choiceOf( wep, net.ReadString() )
    if not choice then return end

    -- only one pair of goggles at a time, whatever the kind
    if IsValid( ply:GetGleeNVG() ) then
        notify( ply, "ALREADY CARRYING GOGGLES", "One pair at a time, whatever the kind." )
        return
    end

    if choice.extraSkulls > 0 and ply:GetSkulls() < choice.extraSkulls then
        notify( ply, "NOT ENOUGH SKULLS", "That pair wants " .. choice.extraSkulls .. " more." )
        ply:EmitSound( "buttons/button10.wav", 55, 100, 0.6 )
        return
    end

    if choice.extraSkulls > 0 then ply:GivePlayerSkulls( -choice.extraSkulls ) end

    local goggles = ply:Give( choice.class )
    if not IsValid( goggles ) then
        -- nothing came out, so nothing was spent either
        if choice.extraSkulls > 0 then ply:GivePlayerSkulls( choice.extraSkulls ) end
        return
    end

    ply:StripWeapon( packClass )
    ply:SelectWeapon( goggles )
    ply:EmitSound( "items/ammo_pickup.wav", 60, 100, 0.6 )

end )
