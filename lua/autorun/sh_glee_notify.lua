--[[------------------------------------
    One time messages, stacked in a feed instead of fighting over the middle of the screen.

        huntersGlee_Notify( { ply }, {
            text = "A Prospective Account Holder has arrived...",
            description = "Get them up to speed!",
            kind = "good",
        } )

    The living read the feed as their suit talking, the dead have no suit, only their own thoughts.
    So any field can be a table, picked by whether the player is alive or dead.

        huntersGlee_Notify( plys, {
            text = { alive = "ANOMALOUS ENERGY DETECTED", dead = "Someone has gifted immortality..." },
            kind = { alive = "alert", dead = "info" },
            time = 10,
        } )

    No text and no icon for their state, no message. text = { alive = "..." } is for the living only.
    Beside that, a plain icon = "..." would still show the dead the icon alone, give it as { alive = "..." } too.
    A message up when the player dies or spawns switches to the other state's fields, or goes away if it has none.

    An icon sits on the right, drawn in the message's colour. Either can go without the other.

        huntersGlee_Notify( { ply }, {
            text = "Pulse Ammo +{num}",
            addNum = 100,
            icon = "entities/item_battery.png",
        } )

    addNum keeps a running total in the {num}, the same message again adds to it.

    The same message again flashes the one already up and restarts its time.
    Messages sharing a replaceKey replace each other, for a count that keeps changing.
    huntersGlee_CancelNotify takes one down early, by that key.
    The server sends to the players in the table, the client shows it to itself, plys nil or { LocalPlayer() }.
    Call it from one realm, shared code that runs on both shows it twice.

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

-- escaped players are at 0 health, they're souls too
function huntersGlee_NotifyStateOf( ply )
    return ply:Health() > 0 and "alive" or "dead"

end

-- a field's value for one state
local function pick( value, state )
    if istable( value ) then return value[state] end
    return value

end

local function checkedOptionalString( value, name )
    if value ~= nil and ( not isstring( value ) or value == "" ) then error( "GLEE: notify " .. name .. " has to be a string", 5 ) end

end

-- one state's fields, plain values with defaults filled in, nil if there's no text or icon for it.
-- Errors at the caller of huntersGlee_Notify
local function checkedState( data, state )
    local text = pick( data.text, state )
    local icon = pick( data.icon, state )
    local iconWeapon = pick( data.iconWeapon, state )
    if text == nil and icon == nil and iconWeapon == nil then return end

    checkedOptionalString( text, "text" )
    checkedOptionalString( icon, "icon" )
    checkedOptionalString( iconWeapon, "iconWeapon" )
    if icon and iconWeapon then error( "GLEE: notify takes an icon or an iconWeapon, not both", 4 ) end

    local iconSize = pick( data.iconSize, state )
    if iconSize ~= nil and ( not isnumber( iconSize ) or iconSize <= 0 ) then error( "GLEE: notify iconSize has to be above 0", 4 ) end

    local iconBadge = pick( data.iconBadge, state )
    checkedOptionalString( iconBadge, "iconBadge" )
    if iconBadge and not icon and not iconWeapon then error( "GLEE: notify iconBadge needs an icon to sit on", 4 ) end

    local addNum = pick( data.addNum, state )
    if addNum ~= nil and not isnumber( addNum ) then error( "GLEE: notify addNum has to be a number", 4 ) end

    local kind = pick( data.kind, state ) or defaultKind
    if not huntersGlee_NotifyKinds[kind] then error( "GLEE: no notify kind \"" .. tostring( kind ) .. "\"", 4 ) end

    local extraFlashes = pick( data.extraFlashes, state )
    if extraFlashes ~= nil and ( not isnumber( extraFlashes ) or extraFlashes < 0 or extraFlashes > maxExtraFlashes ) then
        error( "GLEE: notify extraFlashes has to be 0 to " .. maxExtraFlashes, 4 )

    end

    local time = pick( data.time, state ) or defaultTime
    if not isnumber( time ) then error( "GLEE: notify time has to be a number", 4 ) end

    local think = pick( data.think, state )
    if think ~= nil and not isfunction( think ) then error( "GLEE: notify think has to be a function", 4 ) end

    local description = pick( data.description, state )

    return {
        text = text,
        description = description ~= "" and description or nil,
        kind = kind,
        time = time,
        replaceKey = pick( data.replaceKey, state ),
        style = pick( data.style, state ),
        extraFlashes = extraFlashes,
        flashInterval = pick( data.flashInterval, state ),
        icon = icon,
        iconWeapon = iconWeapon,
        iconSize = iconSize,
        iconBadge = iconBadge,
        addNum = addNum,
        think = think,
    }

end

-- { alive = fields or nil, dead = fields or nil }, as new tables
local function checkedData( data )
    if not istable( data ) then error( "GLEE: notify needs a data table", 3 ) end

    for key, value in pairs( data ) do
        if not istable( value ) then continue end

        for state in pairs( value ) do
            if state ~= "alive" and state ~= "dead" then
                error( "GLEE: notify " .. tostring( key ) .. " has \"" .. tostring( state ) .. "\", only alive and dead go in there", 3 )

            end
        end
    end

    local states = {
        alive = checkedState( data, "alive" ),
        dead = checkedState( data, "dead" ),
    }
    if not states.alive and not states.dead then error( "GLEE: notify needs text or an icon", 3 ) end

    return states

end

local function checkedReplaceKey( replaceKey )
    if not isstring( replaceKey ) or replaceKey == "" then error( "GLEE: cancelling a notify needs its replaceKey", 3 ) end

end

-- chat prints each line apart. nil for an icon alone, chat can't show it.
-- {num} is just the one addNum, chat can't add up
local function oneLine( fields )
    local text = fields.text
    if not text then return end

    if fields.description then
        text = text .. " " .. fields.description

    end

    if fields.addNum then
        text = string.gsub( text, "{num}", tostring( fields.addNum ) )

    end

    return ( string.gsub( text, "\n", " " ) )

end

if SERVER then
    util.AddNetworkString( "glee_notify" )
    util.AddNetworkString( "glee_notify_cancel" )

    -- the valid players in plys, complaining about the rest.
    -- With states, only those who have text for the state they're in
    local function recipients( plys, states )
        local valid = {}
        for _, ply in ipairs( plys ) do
            if not IsValid( ply ) then ErrorNoHaltWithStack( "GLEE: Tried to notify invalid ply" ) continue end
            if states and not states[huntersGlee_NotifyStateOf( ply )] then continue end
            valid[#valid + 1] = ply

        end
        return valid

    end

    -- read in the same order by cl_noticefeed.lua
    local function writeState( fields )
        net.WriteBool( fields ~= nil )
        if not fields then return end

        net.WriteString( fields.text or "" )
        net.WriteString( fields.description or "" )
        net.WriteString( fields.kind )
        net.WriteFloat( fields.time )
        net.WriteString( fields.replaceKey or "" )
        net.WriteString( fields.style or "" )
        net.WriteUInt( fields.extraFlashes or 0, 8 )
        net.WriteFloat( fields.flashInterval or 0 )
        net.WriteString( fields.icon or "" )
        net.WriteString( fields.iconWeapon or "" )
        net.WriteFloat( fields.iconSize or 0 )
        net.WriteString( fields.iconBadge or "" )

        net.WriteBool( fields.addNum ~= nil )
        if fields.addNum then net.WriteDouble( fields.addNum ) end

    end

    local function send( plys, states )
        local sendTo = recipients( plys, states )

        if not inGlee() then
            for _, ply in ipairs( sendTo ) do
                local line = oneLine( states[huntersGlee_NotifyStateOf( ply )] )
                if line then ply:ChatPrint( line ) end

            end
            return

        end

        for _, ply in ipairs( sendTo ) do
            if ply:IsBot() then permaPrint( "GLEEBOTNOTIFY ", ply, oneLine( states[huntersGlee_NotifyStateOf( ply )] ) ) end -- for easier debugging

        end

        net.Start( "glee_notify" )
            writeState( states.alive )
            writeState( states.dead )
        net.Send( sendTo )

    end

    --[[---------------------------------------------------------
        huntersGlee_Notify
        Shows a message in each player's notice feed, or their chat outside glee.
        Sent next tick, so a death or spawn this tick reaches the client first.
        @param plys: A table of players.
        @param data: Any field can be { alive = ..., dead = ... } instead, see the top of the file.
            text, the message, newlines and {+bind}s welcome. Optional with an icon.
            description, optional, drawn smaller under the text.
            icon, optional, a material path. Drawn in the message's colour, if it has transparency.
            iconWeapon, optional, a weapon class, instead of icon.
                Its own selection icon while you hold one, its spawn icon otherwise.
            iconSize, optional, the icon's height as a fraction of the screen's. Left out, it's capped small.
            iconBadge, optional, a few characters at the icon's top left, like a weapon's slot.
            addNum, optional, added to a total that goes in the text's {num}.
                The same message again, while it's up, adds to the total instead of starting over.
            kind, a key of huntersGlee_NotifyKinds, defaults to info.
            time, seconds before it fades, defaults to 6.
            replaceKey, any string, a later message with the same one replaces this.
            style, optional, a hud style to draw in whatever the player's own is.
                "soulthought" for news of something they did while dead.
            extraFlashes, optional, times it flashes again after the first, for messages that can't be missed.
            flashInterval, optional, seconds between those flashes, defaults to 0.5.
            think, client only, a function run every frame it's up, handed the notice.
                It can change its time or take it down, see noticeMeta in cl_noticefeed.lua.
        @return: None
    --]]---------------------------------------------------------
    function huntersGlee_Notify( plys, data )
        if not istable( plys ) then error( "GLEE: notify needs a table of players", 2 ) end
        local states = checkedData( data )
        if data.think ~= nil then error( "GLEE: notify think is client only, a function can't be sent", 2 ) end

        timer.Simple( 0, function()
            send( plys, states )

        end )
    end

    --[[---------------------------------------------------------
        huntersGlee_NotifyLivingAndDead
        huntersGlee_Notify, with every field of livingData as its alive, and deadData's as its dead.
        @param plys: A table of players.
        @param livingData: What their suit tells the living.
        @param deadData: What the dead think. nil sends them nothing.
        @return: None
    --]]---------------------------------------------------------
    function huntersGlee_NotifyLivingAndDead( plys, livingData, deadData )
        local data = {}
        for key, value in pairs( livingData ) do
            data[key] = { alive = value }

        end

        for key, value in pairs( deadData or {} ) do
            data[key] = data[key] or {}
            data[key].dead = value

        end

        huntersGlee_Notify( plys, data )

    end

    --[[---------------------------------------------------------
        huntersGlee_CancelNotify
        Takes a message down before its time is up.
        Chat can't take a line back, so outside glee it does nothing.
        Sent next tick too, so it lands after a message sent before it.
        @param plys: A table of players.
        @param replaceKey: The replaceKey the message was sent with.
        @param options: optional.
            noFade, gone this frame instead of fading out.
                For a message that's wrong the moment things change, like a warning that came true.
        @return: None
    --]]---------------------------------------------------------
    function huntersGlee_CancelNotify( plys, replaceKey, options )
        if not istable( plys ) then error( "GLEE: cancelling a notify needs a table of players", 2 ) end
        checkedReplaceKey( replaceKey )
        local noFade = options and options.noFade or false

        timer.Simple( 0, function()
            local sendTo = recipients( plys )
            if not inGlee() then return end

            net.Start( "glee_notify_cancel" )
                net.WriteString( replaceKey )
                net.WriteBool( noFade )
            net.Send( sendTo )

        end )
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
    local states = checkedData( data )

    if not inGlee() then
        local fields = states[huntersGlee_NotifyStateOf( LocalPlayer() )]
        local line = fields and oneLine( fields )
        if line then chat.AddText( huntersGlee_NotifyKinds[fields.kind].chatColor, line ) end
        return

    end

    GAMEMODE:AddNotice( states )

end

function huntersGlee_CancelNotify( plys, replaceKey, options )
    checkLocal( plys )
    checkedReplaceKey( replaceKey )
    if not inGlee() then return end

    GAMEMODE:CancelNotice( replaceKey, options )

end
