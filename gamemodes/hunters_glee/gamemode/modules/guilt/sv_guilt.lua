
-- keep track of who's pissed off who this round

util.AddNetworkString( "glee_dealtpvpdamage" )
util.AddNetworkString( "glee_homicidallygleeful" )

hook.Add( "huntersglee_round_into_active", "glee_slighting_initialize", function()
    GAMEMODE.roundExtraData.hasSlighted = {}
    GAMEMODE.roundExtraData.slightReasons = {}
    GAMEMODE.roundExtraData.generalMischievousness = {}
    GAMEMODE.roundExtraData.mischievousnessReasons = {}
    GAMEMODE.roundExtraData.nextHomicidalGleeSurfaces = {}
    GAMEMODE.roundExtraData.newbieKillers = {}
    GAMEMODE.roundExtraData.reviveForgivableKillers = {}
    GAMEMODE.roundExtraData.reviveForgivenessUsedAnyone = {}
    GAMEMODE.roundExtraData.reviveForgivenessUsedNewbie = {}

end )

local developerVar = GetConVar( "developer" )

local autoHomicidalEvilnessIncrements = 200
local extraAfterFirstSurface = 100
local evilnessPerPersistGuilt = 15


--[[---------------------------------------------------------
    GM:AddSlight
    @desc How much has X player slighted Y player this round? The more X kills Y, the higher this climbs.
    @param ply: The player doing the slighting.
    @param target: The player being slighted.
    @return: None
--]]---------------------------------------------------------
function GM:AddSlight( slighter, slighted, amount, reason )
    if self:RoundState() ~= self.ROUND_ACTIVE then return end

    local slighterId = slighter:SteamID()
    local slightedId = slighted:SteamID()

    local allSlighted = self.roundExtraData.hasSlighted
    local allSlightReasons = self.roundExtraData.slightReasons

    local slightersSlights = allSlighted[slighterId] or {}

    local slightersReasons = allSlightReasons[slighterId] or {}
    local slightersReasonsForTarget = slightersReasons[slightedId] or {}

    local oldAmount = slightersSlights[slightedId] or 0
    slightersSlights[slightedId] = oldAmount + amount
    self.roundExtraData.hasSlighted[slighterId] = slightersSlights

    hook.Run( "huntersglee_player_slighted", slighter, slighted, amount, reason )

    if not reason then ErrorNoHaltWithStack( "AAAH NO AddSlight REASON" ) end
    table.insert( slightersReasonsForTarget, reason ) -- for debugging
    slightersReasons[slightedId] = slightersReasonsForTarget
    self.roundExtraData.slightReasons[slighterId] = slightersReasons

end

--[[---------------------------------------------------------
    GM:HasSlighted
    @desc How much has X player slighted Y player this round?
    @param ply: The player doing the slighting.
    @param target: The player being slighted.
    @return: Amount slighted
--]]---------------------------------------------------------
function GM:HasSlighted( slighter, slighted )
    if self:RoundState() ~= self.ROUND_ACTIVE then return 0 end

    local allSlighted = self.roundExtraData.hasSlighted
    -- breaks on bots!
    -- all bots have same steamid!
    local slightersSlights = allSlighted[slighter:SteamID()]
    if not slightersSlights then return 0 end
    local amount = slightersSlights[slighted:SteamID()]
    if not amount then return 0 end

    return amount

end

--[[---------------------------------------------------------
    GM:IsInnocent
    @desc Has this player slighted others, or been generally mischievous enough to be considered "not innocent"?
      mischievous players are those who place many barrels, beartraps, harmful items when dead, etc.
    @param ply: The player to check.
    @return: Boolean
    @return: Total evilness amount
--]]---------------------------------------------------------
local innocentTolerance = 25
function GM:IsInnocent( ply )
    if self:RoundState() ~= self.ROUND_ACTIVE then return true, 0 end

    local plysId = ply:SteamID()
    local totalEvilness = 0

    -- have they been placing lots of evil items while dead?
    local miscTbl = self.roundExtraData.generalMischievousness
    if miscTbl then
        local mischeviousness = miscTbl[plysId] or 0
        totalEvilness = totalEvilness + mischeviousness

    end

    -- is this person a persistently evil presence?
    local persistGuilt = self:GetStoredPersistentGuilt( ply )
    local persistentEvilness = persistGuilt * evilnessPerPersistGuilt
    totalEvilness = totalEvilness + persistentEvilness

    local slightTbl = self.roundExtraData.hasSlighted
    if slightTbl then
        -- have they been killing people? damaging people?
        local slightersSlights = slightTbl[plysId]
        if slightersSlights then
            for _, amount in pairs( slightersSlights ) do
                totalEvilness = totalEvilness + amount

            end
        end
    end

    local innocent = totalEvilness < innocentTolerance
    return innocent, totalEvilness

end

--[[---------------------------------------------------------
    GM:IsEvil
    @desc Has this player settled into evil, through this round's feuds and mischief, or a guilt tier flagged evil?
      The evil fight eachother at full damage, and hit the innocent much softer.
    @param ply: The player to check.
    @return: Boolean
    @return: Total evilness amount, this round's
--]]---------------------------------------------------------
function GM:IsEvil( ply )
    local innocent, evilness = self:IsInnocent( ply )

    local _, guiltData = self:GetPlysGuiltLevel( ply )
    if guiltData.evil then return true, evilness end

    if innocent then return false, evilness end

    return evilness >= autoHomicidalEvilnessIncrements * 2, evilness

end

--[[---------------------------------------------------------
    GM:AddMischievousness
    @desc track how mischievous this player is, so the gamemode can react to it.
    @param ply: The player to increase mischievousness for.
    @param amount: How much to increase by.
    @return: None
--]]---------------------------------------------------------
function GM:AddMischievousness( ply, amount, reason )
    if self:RoundState() ~= self.ROUND_ACTIVE then return end

    local plysId = ply:SteamID()
    local oldAmount = self.roundExtraData.generalMischievousness[plysId] or 0
    local oldReasons = self.roundExtraData.mischievousnessReasons[plysId] or {}

    self.roundExtraData.generalMischievousness[plysId] = oldAmount + amount

    hook.Run( "huntersglee_player_beingmischievous", ply, amount )

    if not reason then ErrorNoHaltWithStack( "AAAH NO AddMischievousness REASON" ) end
    table.insert( oldReasons, reason ) -- for debugging
    self.roundExtraData.mischievousnessReasons[plysId] = oldReasons

end

--[[---------------------------------------------------------
    GM:GetMischievousness
    @desc How mischievous is this player? How much chaos are they adding to the round?
      The more a player places beartraps, barrels, harmful items when dead, the higher this climbs.
    @param ply: The player to check.
    @return: Amount of mischievousness
--]]---------------------------------------------------------
function GM:GetMischievousness( ply )
    if self:RoundState() ~= self.ROUND_ACTIVE then return 0 end

    local plysId = ply:SteamID()
    local mischievousness = self.roundExtraData.generalMischievousness[plysId] or 0

    return mischievousness

end

--[[---------------------------------------------------------
    GM:OnKilledTrulyInnocentSoul
    @desc Reacts to a player killing a truly, INNOCENT soul.
        adds a massive downside to killing people for no reason
    @param attacker: The player who did the killing.
    @return: None
--]]---------------------------------------------------------
function GM:OnKilledTrulyInnocentSoul( attacker )
    -- every 2 innocent player kills, it surfaces
    local currentEvilnessToSurface = GAMEMODE.roundExtraData.nextHomicidalGleeSurfaces[attacker:SteamID()] or autoHomicidalEvilnessIncrements

    local _, attackersEvilness = GAMEMODE:IsInnocent( attacker )
    if attackersEvilness < currentEvilnessToSurface then return end

    GAMEMODE.roundExtraData.nextHomicidalGleeSurfaces[attacker:SteamID()] = currentEvilnessToSurface + autoHomicidalEvilnessIncrements + extraAfterFirstSurface

    GAMEMODE:GivePanic( attacker, attackersEvilness )

    if not attacker.glee_autoHomicidalGleeHint then
        GAMEMODE:GivePanic( attacker, attackersEvilness * 2 )
        attacker.glee_autoHomicidalGleeHint = true
        huntersGlee_Announce( { attacker }, 10, 6, "So much death!\nIt's making you feel... Homicidally Gleeful...?" )

    end

    -- let them build up, do multiple dances in a row if they kill like 10 people in 1 second
    local timerName = "glee_autohomicidalglee_waiter" .. attacker:GetCreationID() .. currentEvilnessToSurface
    timer.Create( timerName, math.Rand( 2, 6 ), 0, function()
        if not IsValid( attacker ) then timer.Remove( timerName ) return end
        if attacker:Health() <= 0 then timer.Remove( timerName ) return end

        if attacker:IsPlayingTaunt2() then return end -- wait....

        GAMEMODE:SurfaceHomicidalGlee( attacker )
        timer.Remove( timerName )

    end )
end

local smitingRelief = 1 -- days, infernal summons carry their own, see glee_infernal_persecutors

hook.Add( "PlayerDeath", "glee_storeslights", function( died, inflictor, attacker )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

    if not IsValid( attacker ) then return end
    if attacker == died then return end

    if not attacker:IsPlayer() then return end

    local persistGuiltMul = 1
    local _, diedsGuiltData = GAMEMODE:GetPlysGuiltLevel( died )

    -- some guilt-free inflictors still punish killing the innocent
    -- only divine lightning sets glee_InnocentVictimGuiltMul, and it rewards smiting the wicked
    if inflictor.glee_GuiltFreeInflictor then
        local innocentMul = inflictor.glee_InnocentVictimGuiltMul
        if not innocentMul then return end

        if diedsGuiltData.godlySlayingRelievesGuilt and GAMEMODE:PersistentGuiltIsEnabled() then
            GAMEMODE:IncrementPersistentGuilt( attacker, -smitingRelief, "A guilty player is smitten...\nYou feel less guilty already." )

        end

        if diedsGuiltData.killedForNoGuilt then return end

        persistGuiltMul = innocentMul

    end

    -- the chosen doesn't get guilt
    if attacker:HasStatusEffect( "divine_chosen" ) then return end

    -- this player was guilty enough to trigger homicidal glee
    if died.glee_guiltyHomicidalGlee then return end

    local slightAmnt, reason

    local hookResult, hookReason = hook.Run( "glee_slightsizeoverride", died, attacker )
    if hookResult ~= nil then
        if hookResult == false then return end
        if hookResult == 0 then return end

        if not hookReason then
            ErrorNoHaltWithStack( "glee_slightsizeoverride, no second arg(reason for slight) returned" )
            return

        end
        slightAmnt = hookResult
        reason = hookReason

    elseif GAMEMODE:IsInnocent( died ) then
        slightAmnt = 100
        reason = "killed innocent"

    else
        slightAmnt = 10
        reason = "killed evil"

    end
    GAMEMODE:AddSlight( attacker, died, slightAmnt, reason )

    -- persistent guilt is decided by the victim's guilt tier, not by IsInnocent
    -- before the glee check, so the guilt this adds counts toward surfacing
    if not diedsGuiltData.killedForNoGuilt then
        hook.Run( "glee_onguiltykill", attacker, died, persistGuiltMul )

    end

    -- automatic homicidal glee surfacing below

    -- only for killing innocent people
    if not GAMEMODE:IsInnocent( died ) then return end

    GAMEMODE:OnKilledTrulyInnocentSoul( attacker )

end )

-- infernal summons forgive whoever summoned them, for each of the wicked they kill
hook.Add( "PlayerDeath", "glee_summonsrelieveguilt", function( died, _inflictor, attacker )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    if not GAMEMODE:PersistentGuiltIsEnabled() then return end
    if not IsValid( attacker ) then return end

    local relief = attacker.glee_SummonerGuiltRelief
    if not relief then return end

    local summoner = attacker.glee_Summoner
    if not IsValid( summoner ) then return end
    if summoner == died then return end

    local _, diedsGuiltData = GAMEMODE:GetPlysGuiltLevel( died )
    if not diedsGuiltData.godlySlayingRelievesGuilt then return end

    GAMEMODE:IncrementPersistentGuilt( summoner, -relief, "Your skeletons punished a wicked soul...\nThings are how they should be.\nYou feel less guilty already." )

end )

hook.Add( "glee_shover_shove", "glee_shover_slights", function( shoved, shover )
    if not shoved:IsPlayer() then return end
    GAMEMODE:AddSlight( shover, shoved, 0.5, "shoved them" )

end )

hook.Add( "huntersglee_player_reset", "glee_reset_autohomicidalgleehint", function( ply )
    ply.glee_autoHomicidalGleeHint = nil

end )


-- -----------------------------------------------------------------------
-- PVP DAMAGE
-- players hurting players, scaled hardest when it's a guilty kill
-- -----------------------------------------------------------------------

local function isEvil( ply )
    return GAMEMODE:IsEvil( ply )

end

local function isHomicidallyGleeful( ply )
    return ply.glee_guiltyHomicidalGlee == true

end

-- the same line the halos are drawn at
local function killingThemIsGuilty( ply )
    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( ply )
    return not guiltData.killedForNoGuilt

end

-- off on listen servers, everyone there reads as 0 days
local function hasZeroToOneDaysOfGuilt( ply )
    if not GAMEMODE:PersistentGuiltIsEnabled() then return false end
    return GAMEMODE:GetPersistentGuilt( ply ) < GAMEMODE.PermaGuiltLevels.BARELY_GUILTY

end

local function isNew( ply )
    return GAMEMODE:IsFirstTimePlayer( ply )

end

local function isNotNew( ply )
    return not GAMEMODE:IsFirstTimePlayer( ply )

end

-- items that should always do full damage, eg, items placed by dead players
local function isGuiltFree( inflictor )
    return IsValid( inflictor ) and inflictor.glee_GuiltFreeInflictor == true

end

local function isNotGuiltFree( inflictor )
    return not isGuiltFree( inflictor )

end

-- read top to bottom, the first rule that applies is the one used
-- appliesIf leaves out whoever doesn't matter
-- ballMaxHealth replaces the combine ball's damage, as a fraction of the victim's max health
-- everythingElse is bullets, melee, fire, anything not an explosion or a ball
local pvpDamageRules = {
    { -- both evil, they can fight eachother fine
        appliesIf = {
            attacker = isEvil,
            victim = isEvil,
        },
        fullDamage = true,
    },
    { -- guilty enough to trigger homicidal glee, no protection
        appliesIf = {
            victim = isHomicidallyGleeful,
        },
        fullDamage = true,
    },
    { -- so glancing hits on new players don't cost a huge pile of guilt
        appliesIf = {
            attacker = isNotNew,
            victim = isNew,
            inflictor = isNotGuiltFree,
        },
        explosive = 0.05,
        ballMaxHealth = 0.1,
        everythingElse = 0.05,
    },
    { -- above the guilt-free items, those don't help the evil
        appliesIf = {
            attacker = isEvil,
            victim = killingThemIsGuilty,
        },
        explosive = 0.25,
        ballMaxHealth = 0.25,
        everythingElse = 0.25,
    },
    {
        appliesIf = {
            inflictor = isGuiltFree,
        },
        fullDamage = true,
    },
    { -- keeps pvp off the people who've stayed clean
        appliesIf = {
            attacker = hasZeroToOneDaysOfGuilt,
            victim = killingThemIsGuilty,
        },
        explosive = 0.25,
        ballMaxHealth = 0.5,
        everythingElse = 0.25,
    },
    {
        appliesIf = {},
        explosive = 0.75,
        ballMaxHealth = 0.9,
        everythingElse = 0.5,
    },
}

local function firstApplyingRule( attacker, victim, inflictor )
    for _, rule in ipairs( pvpDamageRules ) do
        local appliesIf = rule.appliesIf
        if appliesIf.attacker and not appliesIf.attacker( attacker ) then continue end
        if appliesIf.victim and not appliesIf.victim( victim ) then continue end
        if appliesIf.inflictor and not appliesIf.inflictor( inflictor ) then continue end

        return rule

    end
end

hook.Add( "EntityTakeDamage", "huntersglee_makepvpreallybad", function( dmgTarg, dmg )
    if dmg:IsFallDamage() then return end -- shoving and goomba doesnt get scaled

    local attacker = dmg:GetAttacker()
    local inflictor = dmg:GetInflictor()

    if dmgTarg == attacker then return end -- they're damaging themselves? go ahead
    if not dmgTarg:IsPlayer() or not attacker:IsPlayer() then return end

    if GAMEMODE.blockPvp == true then -- round setup
        dmg:ScaleDamage( 0 )
        return

    end

    local rule = firstApplyingRule( attacker, dmgTarg, inflictor )
    if rule.fullDamage then return end

    if dmg:IsDamageType( DMG_DISSOLVE ) and IsValid( inflictor ) and inflictor:GetClass() == "prop_combine_ball" then
        local nextpermittedballdamage = dmgTarg.huntersglee_nextpermittedballdamage or 0
        if nextpermittedballdamage > CurTime() then
            dmg:ScaleDamage( 0 )
            return

        end
        dmgTarg.huntersglee_nextpermittedballdamage = CurTime() + 0.5

        dmg:SetDamage( dmgTarg:GetMaxHealth() * rule.ballMaxHealth )
        dmg:SetDamageForce( dmg:GetDamageForce() * 12 )
        dmgTarg:EmitSound( "NPC_CombineBall.KillImpact" )

        local damagedplayercount = inflictor.huntersglee_ball_damagedplayercount or 0
        inflictor.huntersglee_ball_damagedplayercount = damagedplayercount + 1

        if inflictor.huntersglee_ball_damagedplayercount >= 6 then
            inflictor:Fire( "Explode" )

        end
    elseif dmg:IsExplosionDamage() then
        dmg:ScaleDamage( rule.explosive )

    else
        dmg:ScaleDamage( rule.everythingElse )

    end

    net.Start( "glee_dealtpvpdamage" )
        net.WriteInt( math.Round( dmg:GetDamage() ), 16 )
    net.Send( attacker )

end )

hook.Add( "glee_homicidallygleeful", "glee_homicidalglee_sendtodancer", function( dancer )
    net.Start( "glee_homicidallygleeful" )
    net.Send( dancer )

end )


-- PERSISTENT GUILT begin

local dayInSeconds = 60 * 60 * 24

local function getGuiltInDays( guiltSeconds )
    local currentTime = os.time()
    local diffInSeconds = math.max( guiltSeconds - currentTime, 0 )
    local guiltInDays = math.Round( diffInSeconds / dayInSeconds, 1 )

    return guiltInDays

end

function GM:GetStoredPersistentGuilt( ply )
    local currentTime = os.time()
    local oldPersistentGuilt = ply:GetPData( "glee_persistentguilt", currentTime )
    local guiltInDays = getGuiltInDays( oldPersistentGuilt )
    return guiltInDays

end

local guiltTierFlashes = 3 -- a worse guilt tier can't go unnoticed
local guiltTierFlashInterval = 0.75

function GM:IncrementPersistentGuilt( ply, add, msg )
    local daysToAdd = dayInSeconds * ( add or 1 )
    local currentTime = os.time()
    local oldPersistentGuilt = ply:GetPData( "glee_persistentguilt", currentTime )
    if not isnumber( oldPersistentGuilt ) then
        oldPersistentGuilt = tonumber( oldPersistentGuilt )

    end

    local newPersistentGuilt = math.max( oldPersistentGuilt, currentTime ) + daysToAdd

    -- guilt is the timestamp they are guilty until, so anything before now is just zero
    if newPersistentGuilt < currentTime then
        if oldPersistentGuilt <= currentTime then return end -- already zero, nothing they'd see change
        newPersistentGuilt = currentTime

    end

    ply:SetPData( "glee_persistentguilt", newPersistentGuilt )

    local inDaysOld = getGuiltInDays( oldPersistentGuilt )
    local inDays = getGuiltInDays( newPersistentGuilt )

    ply:SetNWFloat( "glee_persistentguilt_days", inDays )

    if developerVar:GetBool() then
        permaPrint( ply, "now has " .. inDays .. " days of guilt..." )

    end

    local kind
    local extraFlashes
    local flashInterval

    if newPersistentGuilt > oldPersistentGuilt then
        kind = "alert"

        local oldLevel = getGuiltLevel( inDaysOld )
        local level, levelData = getGuiltLevel( inDays )
        if level > oldLevel then
            extraFlashes = guiltTierFlashes
            flashInterval = guiltTierFlashInterval

        end

        if not msg then
            if level > oldLevel and levelData.message then -- play transition message if this teir has one
                msg = levelData.message

            elseif inDays <= 1 then -- first day of guilt
                msg = "Killing an innocent soul...\nYou feel... Guilty?"

            elseif inDays <= 5 then -- first 5 days
                msg = "Your guilt grows"
                for _ = 1, math.floor( inDays ) do
                    msg = msg .. "."

                end
            end
        end
    end
    if newPersistentGuilt < oldPersistentGuilt then
        kind = "good"

        if not msg then
            msg = "You feel some of your guilt fade..."

        end
    end

    if msg and msg ~= "" then
        local time = math.max( 10, daysToAdd * 2 )
        huntersGlee_Notify( { ply }, { text = msg, kind = kind, time = time, extraFlashes = extraFlashes, flashInterval = flashInterval } )

    end
end

-- persistent guilt is a dedicated server only mechanic
-- developer 1 enables it for testing
function GM:PersistentGuiltIsEnabled()
    return game.IsDedicated() or developerVar:GetBool()

end

-- guilt is the timestamp they're guilty until, so every row already in the past is dead weight
hook.Add( "huntersglee_round_firstsetup", "glee_wipe_stale_guilt", function()
    local wipedCount = GAMEMODE:WipeExpiredPData( "glee_persistentguilt" )
    if not wipedCount then return end

    if wipedCount <= 0 then
        if not game.IsDedicated() then return end -- only notify no change if we are a dedicated server

        permaPrint( "GLEE: no expired persistent guilt records." )
        return

    end

    permaPrint( "GLEE: wiped " .. wipedCount .. " expired persistent guilt records." )

end )



hook.Add( "PlayerInitialSpawn", "glee_checkpersistentguilt", function( ply )
    local guiltInDays = GAMEMODE:GetStoredPersistentGuilt( ply )
    if guiltInDays <= 0 then return end

    ply:SetNWFloat( "glee_persistentguilt_days", guiltInDays )

end )

hook.Add( "glee_full_load", "glee_guiltyjoinhuntdead", function( ply )
    if not GAMEMODE:PersistentGuiltIsEnabled() then return end
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    if ply:Health() <= 0 then return end

    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( ply )
    if not guiltData.joinsTheHuntDead then return end

    ply:KillSilent()
    huntersGlee_Notify( { ply }, { text = "Your sins are too great.\nYou join the hunt among the dead.", kind = "alert", time = 10 } )

end )

local function isNewbieKill( killer, died )
    return GAMEMODE:IsFirstTimePlayer( died ) and not GAMEMODE:IsFirstTimePlayer( killer )

end

-- before any persistGuiltMul
local function guiltyKillDays( killer, died )
    if isNewbieKill( killer, died ) then return 10 end
    return 1

end

hook.Add( "glee_onguiltykill", "glee_incrementpersistentguilt", function( attacker, died, persistGuiltMul )
    if not GAMEMODE:PersistentGuiltIsEnabled() then return end

    local msg

    local killedNewbie = isNewbieKill( attacker, died )
    local daysToAdd = guiltyKillDays( attacker, died )
    if killedNewbie then
        msg = "They were new here...\nYour guilt is spiraling out of control!"

    end

    persistGuiltMul = persistGuiltMul or 1
    daysToAdd = daysToAdd * persistGuiltMul
    GAMEMODE:IncrementPersistentGuilt( attacker, daysToAdd, msg )

    -- scaled kills come from divine lightning, a deliberate smite, never an accident
    if persistGuiltMul == 1 then
        GAMEMODE.roundExtraData.reviveForgivableKillers[died] = attacker

    end

    if not killedNewbie then return end

    local allNewbieKillers = GAMEMODE.roundExtraData.newbieKillers
    local diedsKillers = allNewbieKillers[died] or {}
    diedsKillers[attacker] = daysToAdd
    allNewbieKillers[died] = diedsKillers

end )

--[[---------------------------------------------------------
    GM:ForgiveKillByRevive
    @desc Reviving the player you just killed takes back the guilt for it.
      Each killer gets one forgiveness of anyone a round, plus one more of a new player.
    @param reviver: The player using the revive kit.
    @param revived: The player being brought back.
    @return: True if guilt was forgiven
--]]---------------------------------------------------------
function GM:ForgiveKillByRevive( reviver, revived )
    local forgivableKillers = self.roundExtraData.reviveForgivableKillers
    if not forgivableKillers then return false end
    if forgivableKillers[revived] ~= reviver then return false end

    local reviveForgivenessUsedNewbie = self.roundExtraData.reviveForgivenessUsedNewbie
    local reviveForgivenessUsedAnyone = self.roundExtraData.reviveForgivenessUsedAnyone

    -- a new player uses their own forgiveness first, then the one for anyone
    if isNewbieKill( reviver, revived ) and not reviveForgivenessUsedNewbie[reviver] then
        reviveForgivenessUsedNewbie[reviver] = true

    elseif not reviveForgivenessUsedAnyone[reviver] then
        reviveForgivenessUsedAnyone[reviver] = true

    else
        return false

    end

    forgivableKillers[revived] = nil

    -- they made it right, so a rage quit shouldn't cost them the newbie guilt again
    local newbiesKillers = self.roundExtraData.newbieKillers[revived]
    if newbiesKillers then
        newbiesKillers[reviver] = nil

    end

    self:IncrementPersistentGuilt( reviver, -guiltyKillDays( reviver, revived ), "You brought them back.\nSuch a weight off your chest..." )
    return true

end

-- a new player who rage quits after being killed costs each killer their newbie guilt again
hook.Add( "PlayerDisconnected", "glee_newbieragequit_guilt", function( leaver )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

    local allNewbieKillers = GAMEMODE.roundExtraData.newbieKillers
    if not allNewbieKillers then return end

    local leaversKillers = allNewbieKillers[leaver]
    if not leaversKillers then return end

    allNewbieKillers[leaver] = nil

    local msg = leaver:Nick() .. " was new here, and you killed them.\nNow they've left... Your guilt grows."

    for killer, daysGiven in pairs( leaversKillers ) do
        if not IsValid( killer ) then continue end
        GAMEMODE:IncrementPersistentGuilt( killer, daysGiven, msg )

    end
end )


concommand.Add( "glee_test_guilt_reset", function( caller, _, _args, argStr )
    if IsValid( caller ) and not caller:IsAdmin() then return end

    local ply, steamId, failReason = GAMEMODE:FindPlayerByArg( GAMEMODE:ArgWords( argStr )[1] )
    if not steamId then
        permaPrint( failReason or "Usage: glee_test_guilt_reset <player>, offline players by SteamID" )
        return

    end

    util.SetPData( steamId, "glee_persistentguilt", 0 )

    if IsValid( ply ) then
        ply:SetNWFloat( "glee_persistentguilt_days", 0 )
        permaPrint( "GLEE: Reset guilt for " .. ply:Nick() .. " (" .. steamId .. ")" )

    else
        permaPrint( "GLEE: Reset guilt for offline player " .. steamId )

    end
end )

concommand.Add( "glee_test_guilt_adddays", function( caller, _, _args, argStr )
    if IsValid( caller ) and not caller:IsAdmin() then return end

    local words = GAMEMODE:ArgWords( argStr )
    local ply, steamId, failReason = GAMEMODE:FindPlayerByArg( words[1] )
    local days = tonumber( words[2] )
    if not words[1] or not days then
        permaPrint( "Usage: glee_test_guilt_adddays <player> <days>" )
        return

    end

    -- IncrementPersistentGuilt works off a live player ( GetPData/SetPData/net ), so they must be online
    if not IsValid( ply ) then
        permaPrint( failReason or "GLEE: glee_test_guilt_adddays needs " .. steamId .. " to be online." )
        return

    end

    GAMEMODE:IncrementPersistentGuilt( ply, days )
    permaPrint( "GLEE: Added " .. days .. " guilt days to " .. ply:Nick() .. " (" .. steamId .. "), now at " .. GAMEMODE:GetStoredPersistentGuilt( ply ) .. " days." )

end )