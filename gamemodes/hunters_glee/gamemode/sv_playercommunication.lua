

local distToBlockProxy = 1250^2
local doProxChatCached = nil

hook.Add( "Think", "glee_cachedoproxchat", function()
    doProxChatCached = GAMEMODE.doProxChat

end )

--[[
local shouldChatCache = {}
local needsRebuild = {}

function GM:EarlyVoiceCache( ply )
    needsRebuild[ ply ] = true

end

local function vcCache( listener, talker, canHear, doProx )
    local listenersCache = shouldChatCache[listener] or {}
    currCache = listenersCache[talker] or {}

    currCache[1] = canHear
    currCache[2] = doProx

    listenersCache[talker] = currCache
    shouldChatCache[listener] = listenersCache


    local canOrCannot = " CANNOT BE HEARD BY "
    if canHear == true then
        canOrCannot = " CAN BE HEARD BY "
    end

    print( talker, canOrCannot, listener )

end

local function getCache( listener, talker )
    local listenersCache = shouldChatCache[listener]
    if not listenersCache then
        buildVCCache( listener, talker )
        listenersCache = shouldChatCache[listener]

    end
    local theCurrCache = listenersCache[talker]
    -- invalid or a rebuild was requested
    if not theCurrCache or needsRebuild[listener] == true or needsRebuild[talker] == true then
        buildVCCache( listener, talker )
        theCurrCache = shouldChatCache[listener][talker]

    end
    return theCurrCache

end

local timerName = "glee_managevoicechat"

local function restartVcTimer()
    timer.Create( timerName, 0.5, 0, function()
        local allPlayers = player.GetAll()
        for _, listener in ipairs( allPlayers ) do
            for _, talker in ipairs( allPlayers ) do
                buildVCCache( listener, talker )

            end
        end
    end )
end
restartVcTimer()

--timer erred and needs restarting!
hook.Add( "huntersglee_round_into_active", "glee_restartvctimer", function()
    if timer.Exists( timerName ) then return end
    restartVcTimer()

end )

hook.Add( "PlayerDeath", "glee_RebuildVoiceChat", function( dead )
    GAMEMODE:EarlyVoiceCache( dead )

end )

hook.Add( "PlayerSpawn", "glee_RebuildVoiceChat", function( whoSpawned )
    GAMEMODE:EarlyVoiceCache( whoSpawned )

end )

--]]

local function listenerCanHear( listener, talker )
    if not doProxChatCached then
        return true, false

    end

    local listenersHealth = listener:Health()
    local talkersHealth = talker:Health()

    local listenerIsSpectator = listenersHealth <= 0
    local listenerIsPlaying = listenersHealth > 0
    local listenersChannel = listener:GetGleeRadioChannel()

    local talkerIsSpectator = talkersHealth <= 0
    local talkerIsPlaying = talkersHealth > 0
    local talkersChannel = talker:GetGleeRadioChannel()

    -- radios are off!
    local talkersRadioIsOff = talkersChannel == 0
    -- same channel!
    local radioLink = ( listenersChannel == talkersChannel ) and not talkersRadioIsOff
    -- radio on talks to everyone
    if talkersChannel == 1 and listenersChannel == 0 then radioLink = true end

    if listenerIsSpectator then
        -- hearing dead ply or alive with 666
        if talkerIsSpectator or radioLink then
            return true, false

        -- hearing alive ply
        elseif listener:GetPos():DistToSqr( talker:GetPos() ) < distToBlockProxy then
            return true, true

        end
    elseif listenerIsPlaying then
        -- another ply with radio or dead ply and we have 666
        if radioLink then
            return true, false

        -- alive ply and they are close enough for proxy
        elseif talkerIsPlaying and listener:GetPos():DistToSqr( talker:GetPos() ) < distToBlockProxy then
            return true, true

        -- dead ply or they're too far
        else
            return false, false

        end
    end
end


hook.Add( "PlayerCanHearPlayersVoice", "glee_voicechat_system", function( listener, talker )
    local canHear, proxy = listenerCanHear( listener, talker )

    --local canOrCannot = " DOESNT HEAR "
    --if canHear == true then
    --    canOrCannot = " HEARS "
    --end
    --print( listener, canOrCannot, talker, proxy )

    return canHear, proxy

end )


-- text chat isn't ever proxy, new logic needed
hook.Add( "PlayerCanSeePlayersChat", "glee_chatblock", function( _, _, listener, talker )
    if not IsValid( talker ) or not IsValid( listener ) then return end
    local talkersHealth = talker:Health()
    local listenersHealth = listener:Health()

    local talkerIsSpectator = talkersHealth <= 0
    local talkerIsPlaying = talkersHealth > 0

    local listenerIsSpectator = listenersHealth <= 0

    if talkerIsSpectator then
        local listenersChannel = listener:GetGleeRadioChannel()
        local talkersChannel = talker:GetGleeRadioChannel()
        if listenerIsSpectator then
            return true

        elseif listenersChannel == talkersChannel then
            return true

        else
            return false

        end
    elseif talkerIsPlaying then
        return true

    end
end )