
local healthDefault = terminator_Extras.healthDefault
hook.Add( "InitPostEntity", "glee_sv_player_cache_healthdefault", function()
    healthDefault = terminator_Extras.healthDefault

end )

local navCheckDist = 150

function GM:GetBotScaryness( ply, bot ) -- AAH
    if bot.IsSilentStepping and bot:IsSilentStepping() then return 0 end

    local minScaryness = 0.15
    local maxScaryness = 1.25

    local plysHealth = ply:Health()
    if plysHealth <= 50 then
        minScaryness = 0.35

    elseif plysHealth <= 35 then
        minScaryness = 0.75

    elseif plysHealth <= 15 then
        minScaryness = 1.15

    elseif plysHealth <= 5 then
        minScaryness = 1.25

    end

    if bot.IsEldritch then -- scary!
        maxScaryness = math.Rand( 2, 4 )

    end

    local velLeng = bot:GetVelocity():Length()
    local hp = math.max( bot:Health(), bot:GetMaxHealth() ) -- some npcs have health set but not maxhealth set...
    local scaryNum = hp + ( velLeng / 2 ) -- fast things are scary!

    local scaryness = scaryNum / healthDefault

    if scaryness > 1.25 then -- let scaryness go crazy but not too crazy
        scaryness = scaryness - 1.25
        scaryness = scaryness / 6
        scaryness = scaryness + 1.25

    end

    scaryness = math.Clamp( scaryness, minScaryness, maxScaryness ) -- clamp with the mins after the above

    return scaryness

end

local meta = FindMetaTable( "Player" )

function meta:GetScore()
    return self:GetNWInt( "huntersglee_score", 0 )

end

function meta:GetSkulls()
    return self:GetNWInt( "huntersglee_skulls", 0 )

end

function meta:HasEscaped()
    return self:GetNWInt( "glee_spectateteam", 0 ) == GAMEMODE.TEAM_ESCAPED

end

function meta:GetEscapeCount()
    return self:GetNWInt( "glee_escape_count", 0 )

end

function meta:SeesDeadPeople()
    return self:Health() <= 0 or self:GetNWInt( "glee_radiochannel", 0 ) == 666 or self:HasStatusEffect( "divine_chosen" )

end

do
    local checkDist = navCheckDist^2

    function meta:IsOnNavmesh()
        return self:GetNW2Int( "glee_disttonavmeshsqr", math.huge ) < checkDist -- navCheckDist^2

    end

end

if SERVER then
    function meta:GivePlayerScore( add )
        if hook.Run( "huntersglee_givescore", self, add ) == false then return end
        local score = self:GetScore()
        self:SetNWInt( "huntersglee_score", math.Round( score + add ) )
        hook.Run( "huntersglee_givenscore", self, add )

    end

    function meta:SetScore( score )
        if hook.Run( "huntersglee_setscore", self, score ) == false then return end
        self:SetNWInt( "huntersglee_score", math.Round( score ) )
    end

    function meta:ResetScore()
        self:SetNWInt( "huntersglee_score", 0 )

    end

    function meta:GivePlayerSkulls( add )
        if hook.Run( "huntersglee_giveskulls", self, add ) == false then return end
        local skulls = self:GetSkulls()
        self:SetNWInt( "huntersglee_skulls", math.Round( skulls + add ) )
        hook.Run( "huntersglee_givenskulls", self, add )

    end

    function meta:ResetSkulls()
        self:SetNWInt( "huntersglee_skulls", 0 )

    end

    local math = math
    local IsValid = IsValid
    local util_IsInWorld = util.IsInWorld
    local plyMeta = FindMetaTable( "Player" )
    -- navarea caching, we get player's navmeshes alot, so it's worth it to cache

    function plyMeta:GetNavAreaData()
        if not IsValid( self.glee_CachedNavArea ) then
            self:CacheNavArea()

        end
        return self.glee_CachedNavArea, self.glee_SqrDistToCachedNavArea

    end

    function plyMeta:CacheNavArea()
        local myPos = self:GetPos()
        if not util_IsInWorld( myPos ) then -- stuck!!!
            self.glee_CachedNavArea = nil
            self.glee_SqrDistToCachedNavArea = math.huge
            return

        end
        local area = navmesh.GetNearestNavArea( myPos, true, navCheckDist, false, true )

        self.glee_CachedNavArea = area
        if area then
            if self:IsOnGround() then
                GAMEMODE.navmeshActivityHeatmap[area] = ( GAMEMODE.navmeshActivityHeatmap[area] or 0 ) + 1

            end
            self.glee_SqrDistToCachedNavArea = myPos:DistToSqr( area:GetClosestPointOnArea( myPos ) )
            self:SetNW2Int( "glee_disttonavmeshsqr", math.Round( self.glee_SqrDistToCachedNavArea ) )

            local oldArea = self.glee_CachedOldNavArea
            if oldArea and oldArea ~= area then
                hook.Run( "glee_ply_changednavareas", self, oldArea, area )
                self.glee_CachedOldNavArea = area

            elseif not oldArea then
                self.glee_CachedOldNavArea = area

            end
        else
            self.glee_SqrDistToCachedNavArea = math.huge

        end
    end

    hook.Add( "glee_sv_validgmthink", "glee_cachenavareas", function( players )
        for _, ply in ipairs( players ) do
            if ply:Health() > 0 then
                ply:CacheNavArea()

            end
        end
    end )
end

