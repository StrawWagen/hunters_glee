-- DRAMATIC announcer messages
-- slides text in from the side of the screen, holds, then slides out
-- meant to be a cooler, more impactful version of sh_glee_announcingText.lua
-- huntersGlee_AnnounceDramatic( plys, priority, length, announcement )

AddCSLuaFile()

if SERVER then
    util.AddNetworkString( "glee_dramatic_announcement" )

    function huntersGlee_AnnounceDramatic( plys, priority, length, announcement )
        for _, ply in ipairs( plys ) do
            if not IsValid( ply ) then error( "GLEE: Tried to dramatic announce to invalid ply" ) return end
            local oldPriority = ply.glee_DramaticAnnouncement_Priority or 0
            if oldPriority > priority then continue end

            ply.glee_DramaticAnnouncement_Priority = priority

            if ply:IsBot() then
                print( "GLEEBOTANNOUNCE_DRAMATIC ", ply, announcement )

            else
                net.Start( "glee_dramatic_announcement" )
                    net.WriteFloat( length )
                    net.WriteString( announcement )
                    net.WriteInt( priority, 16 ) -- max networked priority of + - 32,767
                net.Send( ply )

            end

            local timerName = "glee_dramaticannouncement_cancel_" .. ply:GetCreationID() .. "_" .. string.sub( announcement, 1, 8 )

            if timer.Exists( timerName ) then
                timer.Remove( timerName )

            end
            timer.Create( timerName, length, 1, function()
                if not IsValid( ply ) then return end
                ply.glee_DramaticAnnouncement_Priority = -math.huge

            end )
        end
    end
end

if not CLIENT then return end

include( "autorun/client/cl_gleescalingfunc.lua" )


-- TIMING (seconds)
local SLIDE_IN_TIME     = 0.4       -- how long the text takes to slide in
local HOLD_TIME_PAD     = 0.0       -- extra hold time added on top of what the server sends, for padding
local SLIDE_OUT_TIME    = 0.35      -- how long the text takes to slide out

-- EASING
-- power curve: 1 = linear, 2 = smooth, 3 = snappy, 0.5 = sluggish
local EASE_IN_POWER     = 3.0       -- how snappy the slide-in is (higher = faster start, overshooty)
local EASE_OUT_POWER    = 2.0       -- how snappy the slide-out is

-- DIRECTION
-- true = from/to the left side of the screen, false = from/to the right side
local SLIDE_IN_FROM_LEFT    = true      -- which side the text enters from
local SLIDE_OUT_TO_LEFT     = false     -- which side the text exits to

-- POSITION (relative to screen center, in 1080p pixels, gets scaled)
local Y_OFFSET          = -256      -- negative = above center

-- FONT
local FONT_SIZE         = 50        -- in 1080p pixels
local FONT_WEIGHT       = 500

-- TEXT COLOR
local TEXT_COLOR_R      = 255
local TEXT_COLOR_G      = 255
local TEXT_COLOR_B      = 255


local function defineFont()
    surface.CreateFont( "huntersglee_dramatic_announcingtext", {
        font = GAMEMODE and GAMEMODE.GLEE_FONT or "Arial",
        extended = false,
        size = glee_sizeScaled( nil, FONT_SIZE ),
        weight = FONT_WEIGHT,
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
    } )

    -- glow layer font for the bloom effect behind the text
    surface.CreateFont( "huntersglee_dramatic_announcingtext_glow", {
        font = GAMEMODE and GAMEMODE.GLEE_FONT or "Arial",
        extended = false,
        size = glee_sizeScaled( nil, FONT_SIZE ),
        weight = FONT_WEIGHT,
        blursize = glee_sizeScaled( nil, 8 ),
        scanlines = 0,
        antialias = true,
        underline = false,
        italic = false,
        strikeout = false,
        symbol = false,
        rotary = false,
        shadow = false,
        additive = true,
        outline = false,
    } )
end
defineFont()
hook.Add( "glee_rebuildfonts", "glee_rebuild_dramatic_announcement_font", function()
    defineFont()

end )

local currAnnouncement = nil
local currPriority = 0
local startTime = 0     -- when the announcement started
local holdEnd = 0       -- when sliding out begins
local totalEnd = 0      -- when the whole thing is done

local announcementColor = Color( TEXT_COLOR_R, TEXT_COLOR_G, TEXT_COLOR_B, 255 )

local screenW = ScrW()
local screenH = ScrH()
local screenMiddleW = screenW / 2
local screenMiddleH = screenH / 2

-- easing: fast deceleration
local function easeOut( t, power )
    t = math.Clamp( t, 0, 1 )
    return 1 - ( 1 - t ) ^ power
end

-- simple ease in (accelerating)
local function easeIn( t, power )
    t = math.Clamp( t, 0, 1 )
    return t ^ power
end

net.Receive( "glee_dramatic_announcement", function()
    local length = net.ReadFloat()
    local text = net.ReadString()
    local priority = net.ReadInt( 16 )

    if not length or not text then
        currAnnouncement = nil
        return
    end

    currAnnouncement = text
    startTime = CurTime()
    currPriority = priority

    -- the "length" from server is the total visible time
    -- we split it: slide in -> hold -> slide out
    local holdDuration = math.max( 0, length - SLIDE_IN_TIME - SLIDE_OUT_TIME ) + HOLD_TIME_PAD
    holdEnd = startTime + SLIDE_IN_TIME + holdDuration
    totalEnd = holdEnd + SLIDE_OUT_TIME

end )

hook.Add( "HUDPaint", "huntersglee_paintdramaticannouncetext", function()
    if not currAnnouncement then return end

    local block = hook.Run( "glee_blockDramaticAnnouncements", currAnnouncement, currPriority )
    if block then return end

    local now = CurTime()

    -- done?
    if now > totalEnd then
        currAnnouncement = nil
        return

    end

    -- figure out which phase we're in and compute the X offset
    local slideInEnd = startTime + SLIDE_IN_TIME
    local fraction -- 0 = off screen, 1 = at center
    local alpha = 255

    if now < slideInEnd then
        -- SLIDING IN
        local t = ( now - startTime ) / SLIDE_IN_TIME
        fraction = easeOut( t, EASE_IN_POWER )

    elseif now < holdEnd then
        -- HOLDING
        fraction = 1

    else
        -- SLIDING OUT
        local t = ( now - holdEnd ) / SLIDE_OUT_TIME
        local eased = easeIn( t, EASE_OUT_POWER )
        fraction = 1 - eased
        alpha = math.Clamp( 255 * ( 1 - eased ), 0, 255 )

    end

    -- compute X position
    local inOffScreenX  = SLIDE_IN_FROM_LEFT  and ( -screenW * 0.4 ) or ( screenW * 1.4 )
    local outOffScreenX = SLIDE_OUT_TO_LEFT   and ( -screenW * 0.4 ) or ( screenW * 1.4 )
    local centerX = screenMiddleW

    local drawX
    if now < startTime + SLIDE_IN_TIME then
        drawX = Lerp( fraction, inOffScreenX, centerX )

    elseif now < holdEnd then
        drawX = centerX

    else
        -- fraction goes 1->0 during slide-out, so invert for lerp
        drawX = Lerp( 1 - fraction, centerX, outOffScreenX )

    end

    local drawY = screenMiddleH + glee_sizeScaled( nil, Y_OFFSET )

    announcementColor.a = alpha

    -- MAIN TEXT
    surface.drawShadowedTextBetter( currAnnouncement, "huntersglee_dramatic_announcingtext", announcementColor, drawX, drawY )

end )

hook.Add( "glee_blockGenericAnnouncements", "glee_noDoubleAnnouncements", function()
    if not currAnnouncement then return end
    return true

end )