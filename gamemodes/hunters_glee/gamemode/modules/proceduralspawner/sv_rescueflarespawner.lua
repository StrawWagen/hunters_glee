
-- start spawning rescue flare weapons after rounds are underway for a bit 

local GAMEMODE = GAMEMODE or GM

hook.Add( "huntersglee_round_beginsetup", "glee_resetpersistient_flarespawnlocations", function() 
    GAMEMODE.FastestFoundAt = {}


end )

local minute = 60
local idealFindTime = 5 * minute
local bodyCheckDelay = 0.5 * minute
local randomlySpawnItDelay = idealFindTime

local nextCheck = 0
local nextBodyCheck = 0

local function spawnFlareGunInHand( ragdoll, potentialArea )
    local spawnPos = ragdoll:GetPos() + Vector( 0, 0, 20 )
    local spawnAng = ragdoll:GetAngles()

    local rHandBoneIndex = ragdoll:LookupBone( "ValveBiped.Bip01_R_Hand" )
    local lHandBoneIndex = ragdoll:LookupBone( "ValveBiped.Bip01_L_Hand" )
    if rHandBoneIndex then
        spawnPos, spawnAng = ragdoll:GetBonePosition( rHandBoneIndex )

    elseif lHandBoneIndex then
        spawnPos, spawnAng = ragdoll:GetBonePosition( lHandBoneIndex )

    end

    -- catch-all check for if spawnPos is out of bounds
    if IsValid( potentialArea ) and not potentialArea:IsPartiallyVisible( spawnPos ) then return end

    local flareGun = ents.Create( "termhunt_aeromatix_signalflare_gun" )
    if IsValid( flareGun ) then
        ragdoll.glee_createdARescueFlareGun = true
        flareGun:SetPos( spawnPos )
        flareGun:SetAngles( spawnAng )
        flareGun:Spawn()
        flareGun:Activate()

    end

    return flareGun

end

hook.Add( "glee_sv_validgmthink_active", "glee_rescueflarespawning", function()
    local cur = CurTime()
    if nextCheck > cur then return end
    nextCheck = cur + 10

    if not GAMEMODE.isSkyOnMap then return end

    local remain = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )

    local flareGuns = ents.FindByClass( "termhunt_aeromatix_signalflare_gun" )
    if #flareGuns > 0 then return end

    if remain > bodyCheckDelay and nextBodyCheck < cur then
        nextBodyCheck = cur + 15
        local ragdolls = ents.FindByClass( "prop_ragdoll" )
        -- spawn at lowest ragdolls first
        table.sort( ragdolls, function( a, b ) return a:GetPos().z < b:GetPos().z end )

        for _, ragdoll in ipairs( ragdolls ) do
            if ragdoll.glee_skulldecapitated then continue end
            if ragdoll.glee_createdARescueFlareGun then continue end

            local ragsId = ragdoll:MapCreationID()
            local fastestFoundAt = GAMEMODE.FastestFoundAt[ragsId]
            if fastestFoundAt and fastestFoundAt < idealFindTime then continue end

            local pos = ragdoll:GetPos()
            local area = navmesh.GetNearestNavArea( pos, false, 128, false, true, -2 )
            if not IsValid( area ) then continue end

            local interrupting = terminator_Extras.posIsInterruptingAlive( pos )
            if interrupting then continue end

            local flareGun = spawnFlareGunInHand( ragdoll, area )
            if not IsValid( flareGun ) then continue end

            flareGun.glee_RFlareCreatedByMapRagdoll = true
            flareGun.glee_RFlareCreatorId = ragsId

            nextBodyCheck = CurTime() + 60
            break

        end
    end
    if remain > randomlySpawnItDelay then
        if GAMEMODE:IsGenericSpawning( "termhunt_aeromatix_signalflare_gun" ) then return end

        GAMEMODE:RandomlySpawnEntTbl( "termhunt_aeromatix_signalflare_gun", {
            chance = 100,
            maxCount = 1,
            minAreaSize = 50,
            expireOnRoundEnd = true,

        } )
    end
end )

hook.Add( "WeaponEquip", "glee_trackrescueflarepickups", function( weapon )
    if not weapon.glee_RFlareCreatorId then return end

    local currentTimeInRound = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, CurTime() )

    local creatorId = weapon.glee_RFlareCreatorId
    local prevBest = GAMEMODE.FastestFoundAt[creatorId] or math.huge
    GAMEMODE.FastestFoundAt[creatorId] = math.min( currentTimeInRound, prevBest )

end )