
-- keep track of who's pissed off who this round

hook.Add( "huntersglee_round_into_active", "glee_slighting_initialize", function()
    GAMEMODE.roundExtraData.hasSlighted = {}
    GAMEMODE.roundExtraData.slightReasons = {}
    GAMEMODE.roundExtraData.generalMischievousness = {}
    GAMEMODE.roundExtraData.mischievousnessReasons = {}
    GAMEMODE.roundExtraData.nextHomicidalGleeSurfaces = {}

end )


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

    local slightersSlights = allSlighted[ slighterId ] or {}

    local slightersReasons = allSlightReasons[ slighterId ] or {}
    local slightersReasonsForTarget = slightersReasons[ slightedId ] or {}

    local oldAmount = slightersSlights[ slightedId ] or 0
    slightersSlights[ slightedId ] = oldAmount + amount
    self.roundExtraData.hasSlighted[ slighterId ] = slightersSlights

    hook.Run( "huntersglee_player_slighted", slighter, slighted, amount, reason )

    if not reason then ErrorNoHaltWithStack( "AAAH NO AddSlight REASON" ) end
    table.insert( slightersReasonsForTarget, reason ) -- for debugging
    slightersReasons[ slightedId ] = slightersReasonsForTarget
    self.roundExtraData.slightReasons[ slighterId ] = slightersReasons

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
    local slightersSlights = allSlighted[ slighter:SteamID() ]
    if not slightersSlights then return 0 end
    local amount = slightersSlights[ slighted:SteamID() ]
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
    local totalEvilness = self.roundExtraData.generalMischievousness[ plysId ] or 0

    -- have they been killing people? damaging people?
    local slightersSlights = self.roundExtraData.hasSlighted[ plysId ]
    if not slightersSlights then return totalEvilness < innocentTolerance, totalEvilness end

    for _, amount in pairs( slightersSlights ) do
        totalEvilness = totalEvilness + amount

    end
    return totalEvilness < innocentTolerance, totalEvilness

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
    local oldAmount = self.roundExtraData.generalMischievousness[ plysId ] or 0
    local oldReasons = self.roundExtraData.mischievousnessReasons[ plysId ] or {}

    self.roundExtraData.generalMischievousness[ plysId ] = oldAmount + amount

    hook.Run( "huntersglee_player_beingmischievous", ply, amount )

    if not reason then ErrorNoHaltWithStack( "AAAH NO AddMischievousness REASON" ) end
    table.insert( oldReasons, reason ) -- for debugging
    self.roundExtraData.mischievousnessReasons[ plysId ] = oldReasons

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
    local mischievousness = self.roundExtraData.generalMischievousness[ plysId ] or 0

    return mischievousness

end

local autoHomicidalEvilnessIncrements = 200
local extraAfterFirstSurface = 100

hook.Add( "PlayerDeath", "glee_storeslights", function( died, _, attacker )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    if not attacker:IsPlayer() then return end

    -- the chosen doesn't get guilt
    if attacker:HasStatusEffect( "divine_chosen" ) then return end

    if not IsValid( attacker ) then return end
    if attacker == died then return end

    local slightAmnt, reason

    local hookResult, hookReason = hook.Run( "glee_slightsizeoverride", died, attacker )
    if hookResult then
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

    -- every 2 innocent player kills, it surfaces
    local currentEvilnessToSurface = GAMEMODE.roundExtraData.nextHomicidalGleeSurfaces[ attacker:SteamID() ] or autoHomicidalEvilnessIncrements

    local _, attackersEvilness = GAMEMODE:IsInnocent( attacker )
    if attackersEvilness < currentEvilnessToSurface then return end

    GAMEMODE.roundExtraData.nextHomicidalGleeSurfaces[ attacker:SteamID() ] = currentEvilnessToSurface + autoHomicidalEvilnessIncrements + extraAfterFirstSurface

    if not attacker.glee_autoHomicidalGleeHint then
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
end )

hook.Add( "glee_shover_shove", "glee_shover_slights", function( shoved )
    if not shoved:IsPlayer() then return end
    GAMEMODE:AddSlight( shoved.glee_lastShover, shoved, 0.5, "shoved them" )

end )