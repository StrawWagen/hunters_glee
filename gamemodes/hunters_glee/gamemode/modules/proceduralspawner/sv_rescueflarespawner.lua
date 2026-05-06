
-- start spawning rescue flare weapons after rounds are underway for a bit 

local GAMEMODE = GAMEMODE or GM

hook.Add( "huntersglee_round_beginsetup", "glee_resetpersistient_flarespawnlocations", function() 
    GAMEMODE.FastestFoundAt = {}


end )

-- TODO: make this respect spawnSet.genericSpawnerRate
local minute = 60
local idealFindTime = 5 * minute
local bodyCheckDelay = 0.25 * minute
local shelfCheckDelay = 0.5 * minute
local randomlySpawnItDelay = idealFindTime

local nextCheck = 0
local nextBodyCheck = 0
local nextShelfCheck = 0

local spawnOnShelves = false

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

local maleDeathSounds = {
    "vo/npc/male01/pain07.wav",
    "vo/npc/male01/pain08.wav",
    "vo/npc/male01/pain09.wav",
}

local femaleDeathSounds = {
    "vo/npc/female01/pain05.wav",
    "vo/npc/female01/pain07.wav",
    "vo/npc/female01/ow02.wav",
}

local shelfModel = "models/props_wasteland/kitchen_shelf001a.mdl"
local shelfSpawnPositions = {
    
}

local subMapCheckOffsets = { -200, -400, -800, -1500, -3000 }

local function findSubMapPos( pos )
    for _, offset in ipairs( subMapCheckOffsets ) do
        local testPos = pos + Vector( 0, 0, offset )
        if not util.IsInWorld( testPos ) then continue end
        return testPos
    end
end

-- TODO: play rebel death sound on the ragdoll, so it's more findable
local function spawnAndKillRebel( pos, model )
    local hunter = GAMEMODE:getNearestHunter( pos )
    if not IsValid( hunter ) then return end

    local spawnPos = findSubMapPos( pos )
    if not spawnPos then return end

    local rebel = ents.Create( "npc_citizen" )
    if not IsValid( rebel ) then return end

    rebel:SetPos( spawnPos )
    rebel:SetModel( model )
    rebel:Spawn()
    rebel:Activate()

    timer.Simple( 0.1, function()
        if not IsValid( rebel ) then return end

        if IsValid( hunter ) then
            local dmgInfo = DamageInfo()
            dmgInfo:SetDamage( 1000 )
            dmgInfo:SetDamageType( DMG_GENERIC )
            dmgInfo:SetAttacker( hunter )
            dmgInfo:SetInflictor( hunter )
            rebel:TakeDamageInfo( dmgInfo )

        else
            rebel:TakeDamage( 1000 )

        end

    end )
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
        if #ragdolls >= 2 then
            -- spawn at lowest ragdolls first
            local ragPunishments = {}
            for _, ragdoll in ipairs( ragdolls ) do
                local punishment = ragdoll:GetPos().z
                local pos = ragdoll:GetPos()
                local area = navmesh.GetNearestNavArea( pos, false, 128, false, false, -2 )
                if IsValid( area ) then
                    ragdoll.glee_rescueFlareNavArea = area
                    -- avoid 
                    local heat = GAMEMODE.navmeshActivityHeatmap[area]
                    if heat then
                        punishment = punishment + heat

                    end
                end
                ragPunishments[ragdoll] = punishment
                debugoverlay.Text( pos, tostring( math.Round( punishment ) ), 30, Color( 255, 0, 0 ), false )

            end
            table.sort( ragdolls, function( a, b ) return ragPunishments[a] < ragPunishments[b] end )

        end

        local spawned = false

        if #ragdolls >= 1 then
            for _, ragdoll in ipairs( ragdolls ) do
                if ragdoll.glee_skulldecapitated then continue end
                if ragdoll.glee_createdARescueFlareGun then continue end
                if ragdoll.glee_wasCheckedForARescueFlareGun and ragdoll.glee_wasCheckedForARescueFlareGun > cur then continue end

                local ragsId = ragdoll:MapCreationID()
                local fastestFoundAt = GAMEMODE.FastestFoundAt[ragsId]
                if fastestFoundAt and fastestFoundAt < idealFindTime then continue end

                local pos = ragdoll:GetPos()
                local area = ragdoll.glee_rescueFlareNavArea
                if not IsValid( area ) then continue end

                local interrupting = terminator_Extras.posIsInterruptingAlive( pos )
                if interrupting then
                    ragdoll.glee_wasCheckedForARescueFlareGun = cur + 45
                    continue

                end

                local flareGun = spawnFlareGunInHand( ragdoll, area )
                if not IsValid( flareGun ) then continue end

                spawned = true

                flareGun.glee_RFlareCreatedByMapRagdoll = true
                flareGun.glee_RFlareCreatorId = ragsId

                nextBodyCheck = CurTime() + 60
                break

            end
        end

        if not spawned then
            nextBodyCheck = CurTime() + 120
            print( "shelf spawning!" )
            spawnOnShelves = true
            nextShelfCheck = cur + shelfCheckDelay / 10

        end
    end
    if spawnOnShelves and remain > shelfCheckDelay then
        local props = ents.FindByClass( "prop_physics*" )
        local shelves = {}
        for _, prop in ipairs( props ) do
            local mdl = prop:GetModel()
            if mdl ~= shelfModel then continue end
            table.insert( shelves, prop )

        end
        if #shelves >= 2 then
            local shelfPunishments = {}
            for _, shelf in ipairs( shelves ) do
                local punishment = shelf:GetPos().z
                local pos = shelf:GetPos()
                local area = navmesh.GetNearestNavArea( pos, false, 128, false, false, -2 )
                if IsValid( area ) then
                    shelf.glee_rescueFlareNavArea = area
                    -- avoid 
                    local heat = GAMEMODE.navmeshActivityHeatmap[area]
                    if heat then
                        punishment = punishment + heat

                    end
                end
                shelfPunishments[shelf] = punishment

            end
            table.sort( shelves, function( a, b ) return shelfPunishments[a] < shelfPunishments[b] end )

        end

        if #shelves >= 1 then
            for _, shelf in ipairs( shelves ) do
                if shelf.glee_wasCheckedForARescueFlareGun and shelf.glee_wasCheckedForARescueFlareGun > cur then continue end

                local shelfsId = shelf:MapCreationID()
                local fastestFoundAt = GAMEMODE.FastestFoundAt[shelfsId]
                if fastestFoundAt and fastestFoundAt < idealFindTime then continue end

                local pos = shelf:GetPos()
                local area = shelf.glee_rescueFlareNavArea
                if not IsValid( area ) then continue end

                local interrupting = terminator_Extras.posIsInterruptingAlive( pos )
                if interrupting then
                    shelf.glee_wasCheckedForARescueFlareGun = cur + 45
                    continue

                end

                -- TODO: FINISH THIS!!!

            end
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

                local finalPos = area:GetCenter() + upOffsetBigger
                ragdoll:SetPos( finalPos )

                local model = ragdollModels[math.random( 1, #ragdollModels )]
                ragdoll:SetModel( model )

                ragdoll:Spawn()
                ragdoll:Activate()

                GAMEMODE:HandleRagdollSkulling( ragdoll )

                spawnFlareGunInHand( ragdoll, area, flareGun )

                local rebel = spawnAndKillRebel( finalPos, model )
                if not IsValid( rebel ) then return end

                local deathSnd
                if string.find( model, "female" ) then
                    deathSnd = femaleDeathSounds[math.random( 1, #femaleDeathSounds )]

                elseif string.find( model, "male" ) then
                    deathSnd = maleDeathSounds[math.random( 1, #maleDeathSounds )]

                end
                local filterAllPlayers = RecipientFilter()
                filterAllPlayers:AddAllPlayers()
                ragdoll:EmitSound( deathSnd, 100, 100, 1, CHAN_STATIC, 0, 0, filterAllPlayers )

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