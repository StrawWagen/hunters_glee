--announcer messages
-- func that sends announcement string to tbl of players
-- so like check the pvs of divine conduit and give people a massive warning on their screen
-- "weight" variable so grigori descending from the heavens will override a small "you got score"

AddCSLuaFile()

if SERVER then
    util.AddNetworkString( "glee_clean_announcement" )

    function huntersGlee_Announce( plys, priority, length, announcement )
        for _, ply in ipairs( plys ) do
            if not IsValid( ply ) then error( "GLEE: Tried to announce to invalid ply" ) return end
            local oldPriority = ply.glee_Announcement_Priority or 0
            -- if priority is equal, let it override
            if oldPriority > priority then continue end

            ply:SetNWString( "glee_announcement_theannounce", announcement )

            ply.glee_Announcement_Priority = priority

            net.Start( "glee_clean_announcement" )
            net.WriteFloat( length )
            net.WriteString( announcement )
            net.Send( ply )

            local timerName = "glee_genericannouncement_cancel_" .. ply:GetCreationID() .. "_" .. string.sub( announcement, 1, 8 )

            if timer.Exists( timerName ) then
                timer.Remove( timerName )

            end
            timer.Create( timerName, length, 1, function()
                if not IsValid( ply ) then return end
                if ply:GetNWString( "glee_announcement_theannounce" ) ~= announcement then return end
                ply.glee_Announcement_Priority = -math.huge -- any priority!

                net.Start( "glee_clean_announcement" )
                net.WriteFloat( 0 )
                net.WriteString( "" )
                net.Send( ply )

            end )
        end
    end
end

if not CLIENT then return end

local fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 40 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "huntersglee_announcingtext", fontData )

local currAnnouncement = nil
local expireTime = 0
local me = LocalPlayer()

local screenMiddleW = ScrW() / 2
local screenMiddleH = ScrH() / 2

-- set the local vars so that we will start checkin the announcement table
net.Receive( "glee_clean_announcement", function()
    expireTime = net.ReadFloat()
    currAnnouncement = net.ReadString()

    if expireTime and currAnnouncement then
        expireTime = CurTime() + expireTime

    else
        expireTime = nil
        currAnnouncement = nil

    end
end )

hook.Add( "HUDPaint", "huntersglee_paintannouncetext", function()
    if not currAnnouncement then return end
    if expireTime < CurTime() then return end
    local glee_BlockGenericAnnouncements = me.glee_BlockGenericAnnouncements or 0
    if glee_BlockGenericAnnouncements > CurTime() then return end

    if GetGlobalBool( "termHuntDisplayWinners", false ) == true then return end

    surface.drawShadowedTextBetter( currAnnouncement, "huntersglee_announcingtext", color_white, screenMiddleW, screenMiddleH + -256 )

end )

function huntersGlee_BlockAnnouncements( ply, time )
    ply.glee_BlockGenericAnnouncements = CurTime() + time

end
