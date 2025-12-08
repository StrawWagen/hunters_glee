

local distToBlockProxy = 1500^2
local doProxChatCached = nil

hook.Add( "Think", "glee_cachedoproxchat", function()
    doProxChatCached = GAMEMODE.doProxChat

end )


local GM = GM or GAMEMODE


local entMeta = FindMetaTable( "Entity" )
local ent_Health = entMeta.Health
local ent_GetPos = entMeta.GetPos

local function listenerCanHear( listener, talker )
    if not doProxChatCached then
        return true, false

    end

    local listenersHealth = ent_Health( listener )
    local talkersHealth = ent_Health( talker )

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

    if listenerIsSpectator then
        -- hearing dead talker or alive talker with 666
        if talkerIsSpectator or radioLink then
            return true, false

        -- alive talker, but we're dead. play them in prox.
        elseif talkerIsPlaying and ent_GetPos( listener ):DistToSqr( ent_GetPos( talker ) ) < distToBlockProxy then
            return true, true

        else
            return false, false

        end
    elseif listenerIsPlaying then
        -- another ply with radio or dead ply and we have 666
        if radioLink then
            return true, false

        -- alive ply and they are close enough for proxy
        elseif talkerIsPlaying and ent_GetPos( listener ):DistToSqr( ent_GetPos( talker ) ) < distToBlockProxy then
            return true, true

        -- dead ply or they're too far
        else
            return false, false

        end
    end
end


function GM:PlayerCanHearPlayersVoice( listener, talker )
    local canHear, proxy = listenerCanHear( listener, talker )
    return canHear, proxy

end


-- text chat is always global
function GM:PlayerCanSeePlayersChat( _text, _teamOnly, listener, talker )
    if not IsValid( talker ) or not IsValid( listener ) then return end
    if not doProxChatCached then
        --print( listener, talker, "1", true )
        return true

    end
    local talkersHealth = talker:Health()
    local listenersHealth = listener:Health()

    local talkerIsSpectator = talkersHealth <= 0
    local talkerIsPlaying = talkersHealth > 0

    local listenerIsSpectator = listenersHealth <= 0

    -- only other dead people, and channel 666'ers can see dead player's messages
    if talkerIsSpectator then
        local listenersChannel = listener:GetGleeRadioChannel()
        local talkersChannel = talker:GetGleeRadioChannel()
        if listenerIsSpectator then
            --print( listener, talker, "2", true )
            return true

        elseif listenersChannel == talkersChannel then
            --print( listener, talker, "3", true )
            return true

        else
            --print( listener, talker, "4", false )
            return false

        end
    -- everyone can see messages from alive people
    elseif talkerIsPlaying then
        --print( listener, talker, "5", true )
        return true

    end

    --print( listener, talker, "6", false )

end