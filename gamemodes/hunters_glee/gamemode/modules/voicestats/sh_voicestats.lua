
-- How much each player's been talking, readable by every client.
-- Clientside IsSpeaking only means "I can hear them", and prox chat hides most players from the dead.
-- So the server, who hears everyone, samples it once a second and networks the totals.

GM.VoiceStatsWindow = 120 -- seconds of talking remembered

local meta = FindMetaTable( "Player" )

-- CurTime of the last second they were caught talking, -math.huge if never
function meta:GetLastSpokeTime()
    return self:GetNWFloat( "glee_LastSpokeTime", -math.huge )

end

-- how many of the last VoiceStatsWindow seconds they spent talking
function meta:GetRecentTalkSeconds()
    return self:GetNWInt( "glee_RecentTalkSeconds", 0 )

end

if not SERVER then return end

local nextSample = 0

hook.Add( "glee_sv_validgmthink", "glee_samplevoice", function( players, _, cur )
    if nextSample > cur then return end
    nextSample = cur + 1

    local window = GAMEMODE.VoiceStatsWindow

    for _, ply in ipairs( players ) do
        -- one slot per second, overwritten as the window rolls along
        local samples = ply.glee_VoiceSamples
        if not samples then
            samples = { slot = 0, total = 0 }
            ply.glee_VoiceSamples = samples

        end

        local slot = ( samples.slot % window ) + 1
        samples.slot = slot

        local speaking = ply:IsSpeaking() and 1 or 0
        local total = samples.total - ( samples[slot] or 0 ) + speaking
        samples[slot] = speaking

        if total ~= samples.total then
            samples.total = total
            ply:SetNWInt( "glee_RecentTalkSeconds", total )

        end
        if speaking == 1 then
            ply:SetNWFloat( "glee_LastSpokeTime", cur )

        end
    end
end )
