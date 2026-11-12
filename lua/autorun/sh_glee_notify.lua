--[[------------------------------------
    One time messages, stacked in a feed instead of fighting over the middle of the screen.

        huntersGlee_Notify( { ply }, {
            text = "A Prospective Account Holder has arrived...",
            description = "Get them up to speed!",
            kind = "good",
        } )

    The same message again flashes the one already up and restarts its time.
    Messages sharing a replaceKey replace each other, for a count that keeps changing.
    huntersGlee_CancelNotify takes one down early, by that key.
    The server sends to the players in the table, the client shows it to itself, plys nil or { LocalPlayer() }.
    Call it from one realm, shared code that runs on both shows it twice.

    The living read the feed as their suit talking, the dead have no suit, only their own thoughts.
    Anything sent to everyone, or to whoever's nearby, reaches both, see huntersGlee_NotifyLivingAndDead.

    Lives in autorun so it exists under any gamemode, it falls back to chat outside glee.
    The feed itself is the gamemode's, see modules/clhud/cl_noticefeed.lua.
--]]-------------------------------------

AddCSLuaFile()

-- role is a style colour role, sound a style sound set.
-- chatColor is a FALLBACK for OUTSIDE of glee, where there are no styles
huntersGlee_NotifyKinds = {
    info    = { role = "text",    chatColor = Color( 225, 200, 0 ) },
    good    = { role = "happy",   chatColor = Color( 255, 230, 0 ) },
    bad     = { role = "urgent",  chatColor = Color( 255, 80, 80 ) },
    alert   = { role = "alert",   chatColor = Color( 255, 50, 50 ), sound = "alert" },
    jackpot = { role = "jackpot", chatColor = Color( 255, 255, 0 ) },
}

local defaultKind = "info"
local defaultTime = 6
local maxExtraFlashes = 255 -- sent as 8 bits

local function inGlee()
    return GAMEMODE and GAMEMODE.IsReallyHuntersGlee

end

-- data with its defaults filled in, as a new table. Errors at the caller of huntersGlee_Notify
local function checkedData( data )
    if not istable( data ) then error( "GLEE: notify needs a data table", 3 ) end
    if not isstring( data.text ) or data.text == "" then error( "GLEE: notify needs text", 3 ) end

    local kind = data.kind or defaultKind
    if not huntersGlee_NotifyKinds[kind] then error( "GLEE: no notify kind \"" .. tostring( kind ) .. "\"", 3 ) end

    local extraFlashes = data.extraFlashes
    if extraFlashes ~= nil and ( not isnumber( extraFlashes ) or extraFlashes < 0 or extraFlashes > maxExtraFlashes ) then
        error( "GLEE: notify extraFlashes has to be 0 to " .. maxExtraFlashes, 3 )

    end

    local time = data.time or defaultTime
    if not isnumber( time ) then error( "GLEE: notify time has to be a number", 3 ) end

    local onlyWhile = data.onlyWhile
    if onlyWhile ~= nil and onlyWhile ~= false and onlyWhile ~= "alive" and onlyWhile ~= "dead" then
        error( "GLEE: notify onlyWhile has to be \"alive\", \"dead\" or false", 3 )

    end

    return {
        text = data.text,
        description = data.description ~= "" and data.description or nil,
        kind = kind,
        time = time,
        replaceKey = data.replaceKey,
        style = data.style,
        extraFlashes = extraFlashes,
        flashInterval = data.flashInterval,
        onlyWhile = onlyWhile or nil,
    }

end

local function checkedReplaceKey( replaceKey )
    if not isstring( replaceKey ) or replaceKey == "" then error( "GLEE: cancelling a notify needs its replaceKey", 3 ) end

end

local function isAlive( ply )
    return ply:Health() > 0

end

-- an onlyWhile message for someone who isn't that already, nothing would ever take it down
local function outsideOnlyWhile( ply, onlyWhile )
    if not onlyWhile then return false end
    return isAlive( ply ) ~= ( onlyWhile == "alive" )

end

-- chat prints each line apart
local function oneLine( data )
    local text = data.text
    if data.description then
        text = text .. " " .. data.description

    end

    return ( string.gsub( text, "\n", " " ) )

end

if SERVER then
    util.AddNetworkString( "glee_notify" )
    util.AddNetworkString( "glee_notify_cancel" )

    -- the valid players in plys, complaining about the rest
    local function recipients( plys, onlyWhile )
        if not istable( plys ) then error( "GLEE: notify needs a table of players", 3 ) end

        local valid = {}
        for _, ply in ipairs( plys ) do
            if not IsValid( ply ) then ErrorNoHaltWithStack( "GLEE: Tried to notify invalid ply" ) continue end
            if outsideOnlyWhile( ply, onlyWhile ) then continue end
            valid[#valid + 1] = ply

        end
        return valid

    end

    --[[---------------------------------------------------------
        huntersGlee_Notify
        Shows a message in each player's notice feed, or their chat outside glee.
        @param plys: A table of players.
        @param data: text, the message, newlines and {+bind}s welcome.
            description, optional, drawn smaller under the text.
            kind, a key of huntersGlee_NotifyKinds, defaults to info.
            time, seconds before it fades, defaults to 6.
            replaceKey, any string, a later message with the same one replaces this.
            style, optional, a hud style to draw in whatever the player's own is.
                "soulthought" for news of something they did while dead.
            extraFlashes, optional, times it flashes again after the first, for messages that can't be missed.
            flashInterval, optional, seconds between those flashes, defaults to 0.5.
            onlyWhile, optional, "alive" or "dead". The message vanishes when the player stops being that.
                For a warning that means nothing once they've died.
                Whoever isn't that already doesn't get it at all.
                false is the same as leaving it out.
        @return: None
    --]]---------------------------------------------------------
    function huntersGlee_Notify( plys, data )
        data = checkedData( data )
        local sendTo = recipients( plys, data.onlyWhile )

        if not inGlee() then
            local line = oneLine( data )
            for _, ply in ipairs( sendTo ) do
                ply:ChatPrint( line )

            end
            return

        end

        for _, ply in ipairs( sendTo ) do
            if ply:IsBot() then permaPrint( "GLEEBOTNOTIFY ", ply, data.text, data.description ) end -- for easier debugging

        end

        net.Start( "glee_notify" )
            net.WriteString( data.text )
            net.WriteString( data.description or "" )
            net.WriteString( data.kind )
            net.WriteFloat( data.time )
            net.WriteString( data.replaceKey or "" )
            net.WriteString( data.style or "" )
            net.WriteUInt( data.extraFlashes or 0, 8 )
            net.WriteFloat( data.flashInterval or 0 )
            net.WriteString( data.onlyWhile or "" )
        net.Send( sendTo )

    end

    -- a copy, callers send the same table again, eg every second of a countdown
    local function withOnlyWhile( data, onlyWhile )
        if not istable( data ) or data.onlyWhile ~= nil then return data end

        local copy = {}
        for key, value in pairs( data ) do
            copy[key] = value

        end
        copy.onlyWhile = onlyWhile
        return copy

    end

    --[[---------------------------------------------------------
        huntersGlee_NotifyLivingAndDead
        huntersGlee_Notify, worded for each side of death.
        Escaped players count as dead, they're souls too.
        Each side's message vanishes once they cross over, set onlyWhile = false to keep it up.
        @param plys: A table of players.
        @param livingData: What their suit tells the living.
        @param deadData: What the dead think. nil sends them nothing.
        @return: None
    --]]---------------------------------------------------------
    function huntersGlee_NotifyLivingAndDead( plys, livingData, deadData )
        local living = {}
        local dead = {}
        for _, ply in ipairs( plys ) do
            if not IsValid( ply ) then continue end

            if isAlive( ply ) then
                living[#living + 1] = ply

            else
                dead[#dead + 1] = ply

            end
        end

        if #living > 0 then huntersGlee_Notify( living, withOnlyWhile( livingData, "alive" ) ) end
        if deadData and #dead > 0 then huntersGlee_Notify( dead, withOnlyWhile( deadData, "dead" ) ) end

    end

    --[[---------------------------------------------------------
        huntersGlee_CancelNotify
        Takes a message down before its time is up.
        Chat can't take a line back, so outside glee it does nothing.
        @param plys: A table of players.
        @param replaceKey: The replaceKey the message was sent with.
        @param options: optional.
            noFade, gone this frame instead of fading out.
                For a message that's wrong the moment things change, like a warning that came true.
        @return: None
    --]]---------------------------------------------------------
    function huntersGlee_CancelNotify( plys, replaceKey, options )
        checkedReplaceKey( replaceKey )
        local sendTo = recipients( plys )
        if not inGlee() then return end

        net.Start( "glee_notify_cancel" )
            net.WriteString( replaceKey )
            net.WriteBool( options and options.noFade or false )
        net.Send( sendTo )

    end

    return

end

local function checkLocal( plys )
    if plys == nil then return end
    if not istable( plys ) then error( "GLEE: notify needs a table of players, or nil", 3 ) end

    local me = LocalPlayer()
    for _, ply in ipairs( plys ) do
        if ply ~= me then error( "GLEE: the client can only notify itself", 3 ) end

    end
end

function huntersGlee_Notify( plys, data )
    checkLocal( plys )
    data = checkedData( data )
    if outsideOnlyWhile( LocalPlayer(), data.onlyWhile ) then return end

    if not inGlee() then
        chat.AddText( huntersGlee_NotifyKinds[data.kind].chatColor, oneLine( data ) )
        return

    end

    GAMEMODE:AddNotice( data )

end

function huntersGlee_CancelNotify( plys, replaceKey, options )
    checkLocal( plys )
    checkedReplaceKey( replaceKey )
    if not inGlee() then return end

    GAMEMODE:CancelNotice( replaceKey, options )

end
