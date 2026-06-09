
-- keep track of who's pissed off who this round

util.AddNetworkString( "glee_dealtpvpdamage" )
util.AddNetworkString( "glee_homicidallygleeful" )

hook.Add( "huntersglee_round_into_active", "glee_slighting_initialize", function()
    GAMEMODE.roundExtraData.hasSlighted = {}
    GAMEMODE.roundExtraData.slightReasons = {}
    GAMEMODE.roundExtraData.generalMischievousness = {}
    GAMEMODE.roundExtraData.mischievousnessReasons = {}
    GAMEMODE.roundExtraData.nextHomicidalGleeSurfaces = {}

end )

local autoHomicidalEvilnessIncrements = 200
local extraAfterFirstSurface = 100
local evilnessPerPersistGuilt = 5


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
    if not self.roundExtraData.hasSlighted then return true, 0 end

    local plysId = ply:SteamID()

    -- have they been placing lots of beartraps?
    local totalEvilness = self.roundExtraData.generalMischievousness[plysId] or 0

    -- is this person a persistently evil presence?
    local persistentEvilness = self:GetPersistentGuilt( ply ) * evilnessPerPersistGuilt
    totalEvilness = totalEvilness + persistentEvilness

    -- have they been killing people? damaging people?
    local slightersSlights = self.roundExtraData.hasSlighted[plysId]
    if not slightersSlights then return totalEvilness < innocentTolerance, totalEvilness end

    for _, amount in pairs( slightersSlights ) do
        totalEvilness = totalEvilness + amount

    end
    return totalEvilness < innocentTolerance, totalEvilness

end

--[[---------------------------------------------------------
    GM:IsHorriblyEvil
    @desc Is this player's total evilness above autoHomicidalEvilnessIncrements, x2?
    @param ply: The player to check.
    @return: Boolean
--]]---------------------------------------------------------
function GM:IsHorriblyEvil( ply )
    local innocent, evilness = self:IsInnocent( ply )
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
    @param died: The player who died.
    @return: None
--]]---------------------------------------------------------
function GM:OnKilledTrulyInnocentSoul( attacker, died )

    hook.Run( "glee_onkilledtrulyinnocentsoul", attacker, died )

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

hook.Add( "PlayerDeath", "glee_storeslights", function( died, _, attacker )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    if not attacker:IsPlayer() then return end

    -- the chosen doesn't get guilt
    if attacker:HasStatusEffect( "divine_chosen" ) then return end

    if not IsValid( attacker ) then return end
    if attacker == died then return end

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

    -- automatic homicidal glee surfacing below

    -- only for killing innocent people
    if not GAMEMODE:IsInnocent( died ) then return end

    GAMEMODE:OnKilledTrulyInnocentSoul( attacker, died )

end )

hook.Add( "glee_shover_shove", "glee_shover_slights", function( shoved, shover )
    if not shoved:IsPlayer() then return end
    GAMEMODE:AddSlight( shover, shoved, 0.5, "shoved them" )

end )

hook.Add( "huntersglee_player_reset", "glee_reset_autohomicidalgleehint", function( ply )
    ply.glee_autoHomicidalGleeHint = nil

end )


hook.Add( "EntityTakeDamage", "huntersglee_makepvpreallybad", function( dmgTarg, dmg )
    if dmg:IsFallDamage() then return end -- shoving and goomba doesnt get scaled

    local attacker = dmg:GetAttacker()
    local inflictor = dmg:GetInflictor()
    local areBothPlayers = dmgTarg:IsPlayer() and attacker:IsPlayer()
    local selfDamage = dmgTarg == attacker

    if selfDamage then return end -- they're damaging themselves? go ahead
    if not areBothPlayers then return end

    local attackerIsHorriblyEvil = GAMEMODE:IsHorriblyEvil( attacker )
    local targIsHorriblyEvil = GAMEMODE:IsHorriblyEvil( dmgTarg )

    if attackerIsHorriblyEvil and targIsHorriblyEvil then return end -- if both are evil, they can fight eachother fine

    if GAMEMODE.blockPvp == true then
        dmg:ScaleDamage( 0 )

    else
        -- for items that should always do full damage
        -- eg, items placed by dead players
        if inflictor and inflictor.glee_AlwaysFullPVPDamage then
            return

        end

        if dmg:IsDamageType( DMG_DISSOLVE ) and inflictor and inflictor:GetClass() == "prop_combine_ball" then -- special cball case
            local nextpermittedballdamage = dmgTarg.huntersglee_nextpermittedballdamage or 0
            if nextpermittedballdamage > CurTime() then
                dmg:ScaleDamage( 0 )
                return

            end
            dmgTarg.huntersglee_nextpermittedballdamage = CurTime() + 0.5

            dmg:SetDamage( dmgTarg:GetMaxHealth() * 0.9 )
            dmg:SetDamageForce( dmg:GetDamageForce() * 12 )
            dmgTarg:EmitSound( "NPC_CombineBall.KillImpact" )

            damagedplayercount = inflictor.huntersglee_ball_damagedplayercount or 0
            inflictor.huntersglee_ball_damagedplayercount = damagedplayercount + 1

            if inflictor.huntersglee_ball_damagedplayercount >= 6 then
                inflictor:Fire( "Explode" )

            end
        elseif dmg:IsExplosionDamage() then
            dmg:ScaleDamage( 0.75 )

        else
            dmg:ScaleDamage( 0.5 )

        end

        net.Start( "glee_dealtpvpdamage" )
            net.WriteInt( math.Round( dmg:GetDamage() ), 16 )
        net.Send( attacker )

    end
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

function GM:GetPersistentGuilt( ply )
    local oldPersistentGuilt = ply:GetPData( "glee_persistentguilt", 0 )
    local guiltInDays = getGuiltInDays( oldPersistentGuilt )
    return guiltInDays

end

function GM:IncrementPersistentGuilt( ply, add )
    local daysToAdd = dayInSeconds * ( add or 1 )
    local currentTime = os.time()
    local oldPersistentGuilt = ply:GetPData( "glee_persistentguilt", currentTime )
    local newPersistentGuilt = oldPersistentGuilt + daysToAdd
    ply:SetPData( "glee_persistentguilt", newPersistentGuilt )
    ply:SetNWFloat( "glee_persistentguilt_days", getGuiltInDays( newPersistentGuilt ) )

end

hook.Add( "PlayerInitialSpawn", "glee_checkpersistentguilt", function( ply )
    local guiltInDays = GAMEMODE:GetPersistentGuilt( ply )
    if guiltInDays <= 0 then return end

    ply:SetNWFloat( "glee_persistentguilt_days", guiltInDays )

end )

local developerVar = GetConVar( "developer" )

hook.Add( "glee_onkilledtrulyinnocentsoul", "glee_incrementpersistentguilt", function( attacker, _died )
    -- persistent guilt is a dedicated server only mechanic
    -- developer 1 enables it for testing
    if not game.IsDedicated() and not developerVar:GetBool() then return end

    GAMEMODE:IncrementPersistentGuilt( attacker )

end )