
local healthDefault = terminator_Extras.healthDefault
hook.Add( "InitPostEntity", "glee_sv_player_cache_healthdefault", function()
    healthDefault = terminator_Extras.healthDefault

end )

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
    local scaryNum = bot:GetMaxHealth() + ( velLeng / 2 ) -- fast things are scary!

    local scaryness = scaryNum / healthDefault

    if scaryness > 1.25 then -- let scaryness go crazy but not too crazy
        scaryness = scaryness - 1
        scaryness = scaryness / 6
        scaryness = scaryness + 1

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

function meta:SeesDeadPeople()
    return self:Health() <= 0 or self:GetNWInt( "glee_radiochannel", 0 ) == 666 or self:HasStatusEffect( "divine_chosen" )

end

if SERVER then
    function meta:GivePlayerScore( add )
        if hook.Run( "huntersglee_givescore", self, add ) == false then return end
        local score = self:GetScore()
        self:SetNWInt( "huntersglee_score", math.Round( score + add ) )
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
    end

    function meta:ResetSkulls()
        self:SetNWInt( "huntersglee_skulls", 0 )

    end
end

