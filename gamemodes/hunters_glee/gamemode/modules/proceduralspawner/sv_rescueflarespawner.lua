
-- start spawning rescue flare weapons after rounds are underway for a bit 

local GAMEMODE = GAMEMODE or GM

hook.Add( "huntersglee_round_beginsetup", "glee_resetpersistient_flarespawnlocations", function() 
    GAMEMODE.FastestFoundAt = {}


end )

-- TODO: make this respect spawnSet.genericSpawnerRate
local minute = 60
local idealFindTime = 5 * minute
local bodyCheckDelay = 0.5 * minute
local randomlySpawnItDelay = idealFindTime

local nextCheck = 0
local nextBodyCheck = 0

local upOffset = Vector( 0, 0, 20 )
local upOffsetBigger = Vector( 0, 0, 30 )

local function spawnFlareGunInHand( ragdoll, potentialArea, flareGun )
    local spawnPos = ragdoll:GetPos()
    local spawnAng = ragdoll:GetAngles()

    local rHandBoneIndex = ragdoll:LookupBone( "ValveBiped.Bip01_R_Hand" )
    local lHandBoneIndex = ragdoll:LookupBone( "ValveBiped.Bip01_L_Hand" )
    if rHandBoneIndex then
        spawnPos, spawnAng = ragdoll:GetBonePosition( rHandBoneIndex )

    elseif lHandBoneIndex then
        spawnPos, spawnAng = ragdoll:GetBonePosition( lHandBoneIndex )

    end

    spawnPos = spawnPos + upOffset

    -- catch-all check for if spawnPos is out of bounds
    if IsValid( potentialArea ) and not potentialArea:IsPartiallyVisible( spawnPos ) then return end

    if not flareGun then
        flareGun = ents.Create( "termhunt_aeromatix_signalflare_gun" )

    end
    if IsValid( flareGun ) then
        ragdoll.glee_createdARescueFlareGun = true
        flareGun:SetPos( spawnPos )
        flareGun:SetAngles( spawnAng )
        flareGun:Spawn()
        flareGun:Activate()

    end

    return flareGun

end

local ragdollModels = {
    "models/humans/group01/male_01.mdl",
    "models/humans/group01/male_02.mdl",
    "models/humans/group01/male_03.mdl",
    "models/humans/group01/male_04.mdl",
    "models/humans/group01/male_05.mdl",
    "models/humans/group01/male_06.mdl",
    "models/humans/group01/male_07.mdl",
    "models/humans/group01/male_08.mdl",
    "models/humans/group01/male_09.mdl",
    "models/humans/group03/female_01.mdl",
    "models/humans/group03/female_02.mdl",
    "models/humans/group03/female_03.mdl",
    "models/humans/group03/female_04.mdl",
    -- wheres model05... valve...
    "models/humans/group03/female_06.mdl",
    "models/humans/group03/female_07.mdl",
}

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
            if ragdoll.glee_wasCheckedForARescueFlareGun and ragdoll.glee_wasCheckedForARescueFlareGun > cur then continue end

            local ragsId = ragdoll:MapCreationID()
            local fastestFoundAt = GAMEMODE.FastestFoundAt[ragsId]
            if fastestFoundAt and fastestFoundAt < idealFindTime then continue end

            local pos = ragdoll:GetPos()
            local area = navmesh.GetNearestNavArea( pos, false, 128, false, true, -2 )
            if not IsValid( area ) then continue end

            local heat = GAMEMODE.navmeshActivityHeatmap[area]
            if heat and heat >= 100 then continue end

            local interrupting = terminator_Extras.posIsInterruptingAlive( pos )
            if interrupting then
                ragdoll.glee_wasCheckedForARescueFlareGun = cur + 45
                continue

            end

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
            radius = 10000,
            chance = 100,
            maxCount = 1,
            minAreaSize = 75,
            expireOnRoundEnd = true,
            -- spawn a rebel ragdoll, and put the flare into its hand
            dontSpawn = true,
            extraFlagsBlacklist = bit.bor( GAMEMODE.NavEFlags.UNDER_SKY, GAMEMODE.NavEFlags.LOW_CEILING ), -- spawn indoors but not in tight spaces
            preSpawnedFunc = function( flareGun )
                local pos = flareGun:GetPos()
                local area = navmesh.GetNearestNavArea( pos, false, 500, false, true, -2 )
                if not IsValid( area ) then return end

                local ragdoll = ents.Create( "prop_ragdoll" )
                if not IsValid( ragdoll ) then return end

                ragdoll:SetPos( area:GetCenter() + upOffsetBigger )

                local model = ragdollModels[math.random( 1, #ragdollModels )]
                ragdoll:SetModel( model )

                ragdoll:Spawn()
                ragdoll:Activate()

                -- TODO: play rebel death sound on the ragdoll, so it's more findable
                -- maybe spawn a rebel npc and force kill it via nearest hunter so we get a deathmessage?

                GAMEMODE:HandleRagdollSkulling( ragdoll )

                spawnFlareGunInHand( ragdoll, area, flareGun )

            end,
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