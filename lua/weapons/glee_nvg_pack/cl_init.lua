include( "shared.lua" )

-- the pack's use wheel, client side, only the carrier sees it

local packClass = "glee_nvg_pack"

local OUTER_RADIUS_1080P = 300

-- built when it opens, so the haptic's extra skull shows as it stands now
local function wheelActions( wep )
    local actions = {}
    for _, choice in ipairs( wep.Choices ) do
        local label = choice.label
        if choice.extraSkulls > 0 then label = label .. " (+" .. choice.extraSkulls .. " skull)" end
        actions[#actions + 1] = { key = choice.key, label = label, extraSkulls = choice.extraSkulls }

    end
    return actions

end

-- glee_carrying's use wheel, opened on the held pack instead of something aimed at
-- shares glee_Carrying.CurrentWheel, so its own CreateMove lets go of it when use is released
local function openWheel( ply, wep )
    local carrying = terminator_Extras and terminator_Extras.glee_Carrying
    if not carrying then return end

    local oldWheel = carrying.CurrentWheel
    if IsValid( oldWheel ) then oldWheel:Remove() end

    local wheel = vgui.Create( "glee_wheel" )
    if not IsValid( wheel ) then return end
    local outer = wheel:Style():Scaled( OUTER_RADIUS_1080P )

    wheel:SetSize( outer * 2, outer * 2 )
    wheel:SetItems( wheelActions( wep ) )
    wheel:Center()

    function wheel:GetItemStatus( item )
        if not IsValid( wep ) or ply:GetActiveWeapon() ~= wep then return false end
        return ply:GetSkulls() >= ( item.extraSkulls or 0 )

    end

    function wheel:OnItemSelected( item )
        net.Start( "glee_nvg_packpick" )
            net.WriteString( item.key )
        net.SendToServer()
        self:Close()

    end

    hook.Add( "Think", wheel, function( self )
        if IsValid( wep ) and ply:Alive() and ply:GetActiveWeapon() == wep then return end
        self:Close()

    end )

    wheel:HoldAim()
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    carrying.CurrentWheel = wheel

end

-- E with the pack out, and nothing usable in front, so doors and pickups still work
local function aimingAtSomething( ply )
    local carrying = terminator_Extras and terminator_Extras.glee_Carrying
    local range = carrying and carrying.UseRange or 90
    local shootPos = ply:EyePos()
    local tr = util.TraceLine( {
        start = shootPos,
        endpos = shootPos + ply:GetAimVector() * range,
        filter = ply,
    } )
    return IsValid( tr.Entity )

end

hook.Add( "PlayerBindPress", "glee_nvg_packwheel", function( ply, bind, pressed )
    if not pressed or bind ~= "+use" then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or wep:GetClass() ~= packClass then return end
    if not ply:Alive() or ply:InVehicle() then return end
    if aimingAtSomething( ply ) then return end

    openWheel( ply, wep )

end )
