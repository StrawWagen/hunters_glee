-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=3812596923
-- hold a SLAM, left click something close to stick one onto it, right click to set them all off
-- see sv_stickyslams.lua, and entities/glee_sticky_slam.lua

local reach = 100
GM.StickySlamReach = reach

-- the client takes IN_ATTACK off so the stock SLAM doesn't predict a throw, this carries the click to the server instead
GM.StickySlamClickKey = IN_WEAPON1

-- holding a SLAM, and not taunting
function GM:CanUseStickySlams( ply )
    if ply:IsPlayingTaunt2() then return false end

    local wep = ply:GetActiveWeapon()
    return IsValid( wep ) and wep:GetClass() == "weapon_slam"

end

-- alive players, npcs and hunters, or anything physics can move
-- clients can't see physics objects, so they guess on props and the server has the final say
function GM:CanStickSlamTo( ent )
    if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
        return ent:Health() > 0

    end
    if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
    if CLIENT then return true end

    local physObj = ent:GetPhysicsObject()
    return IsValid( physObj ) and physObj:IsMotionEnabled()

end

local function isLooseSlam( ent )
    return ent:GetClass() == "glee_sticky_slam" and not IsValid( ent:GetParent() )

end

-- returns what we're aiming at, and the world pos & surface normal to stick to, or nil if it's out of reach or not stickable
-- aiming at a stuck slam sticks onto whatever that slam is stuck to, so slams stack
function GM:FindStickySlamTarget( ply, aimDir )
    local start = ply:GetShootPos()
    local aimTr = util.TraceLine( {
        start = start,
        endpos = start + aimDir * reach,
        filter = function( ent )
            return ent ~= ply and not isLooseSlam( ent )

        end,
        mask = MASK_SHOT,
    } )

    local target = aimTr.Entity
    if IsValid( target ) and target:GetClass() == "glee_sticky_slam" then
        target = target:GetParent()

    end
    if not IsValid( target ) or not self:CanStickSlamTo( target ) then return end

    return target, aimTr.HitPos, aimTr.HitNormal

end

if CLIENT then
    hook.Add( "StartCommand", "glee_stickyslams_predictclick", function( ply, cmd )
        if not cmd:KeyDown( IN_ATTACK ) then return end
        if not GAMEMODE:CanUseStickySlams( ply ) then return end
        if ply:GetAmmoCount( "slam" ) <= 0 then return end
        if not GAMEMODE:FindStickySlamTarget( ply, cmd:GetViewAngles():Forward() ) then return end

        cmd:RemoveKey( IN_ATTACK )
        cmd:AddKey( GAMEMODE.StickySlamClickKey )

    end )
end
