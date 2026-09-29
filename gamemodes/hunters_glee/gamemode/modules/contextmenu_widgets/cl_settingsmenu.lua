--[[
    The client settings menu. Client convars only.

    Every setting is a glee_row, sliders with a glee_meter in the middle, all docked into
    a glee_frame that sizes itself around them.
    Add a setting by adding to settingsCategories; nothing else needs touching.

    Every other glee gui scales with cl_huntersglee_guiscale. This one must not: it is
    the only menu that can undo a bad guiscale, so it has to stay readable at values
    that make the shop unusable. Its frame is pinned to the fixed scale for that.

    Opened by the glee_settings_open concommand.
]]

local GAMEMODE = GAMEMODE or GM

local HEADER_FONT = "mediumLarge" -- a font role

local FRAME_MAX_H_1080P = 775
local METER_MIN_W_1080P = 200

-- the widest string a value column can print, reserved so no bar runs under a number
local WIDEST_VALUE = "(0.00)"

-- min/max are the ends of the bar, not the convar's own limits: music accepts -1, its
-- bar starts at 0. decimals sets the step size as well as the print precision.
-- defaultValue is only for convars that default to -1, and is what -1 means to the
-- feature that owns it. changeWhenDone writes on release instead of during the drag.
local settingsCategories = {
    {
        name = "GLEE",
        items = {
            {
                cvar = "cl_huntersglee_musicvolume",
                type = "slider",
                min = 0,
                max = 1,
                decimals = 1,
                defaultValue = 0.5, -- what the -1 default resolves to, see cl_music.lua
                prettyName = "Music volume",
                desc = "Change the music's volume. Default is -1 which translates to 0.5",
            },
            {
                cvar = "cl_huntersglee_guiscale",
                type = "slider",
                min = 0.2,
                max = 1,
                decimals = 2,
                defaultValue = 0.9, -- what the -1 default resolves to, see cl_shopstandards.lua
                prettyName = "GUI scale",
                desc = "Scale all GUIs, shop, bank leaderboard, etc. Default is -1, which translates to 0.9",
                changeWhenDone = true, -- every write rebuilds all the shop fonts
            },
            {
                cvar = "cl_huntersglee_heartbeat_volume",
                type = "slider",
                min = 0,
                max = 1,
                decimals = 1,
                prettyName = "Heartbeat volume",
                desc = "Turn down the beat.",
            },
            {
                cvar = "cl_glee_fallingwind_volume",
                type = "slider",
                min = 0,
                max = 1,
                decimals = 1,
                prettyName = "Wind sound volume",
                desc = "Volume of the wind sound when falling at high speed.",
            },
            {
                cvar = "cl_huntersglee_lightningvolume",
                type = "slider",
                min = 0,
                max = 1,
                decimals = 1,
                prettyName = "Lightning volume",
                desc = "Volume of lightning.",
            },
            {
                cvar = "cl_huntersglee_gleetingsask",
                type = "check",
                prettyName = "Gleetings message?",
                desc = "Get a chat print when someone who's never played glee joins?",
                showSettingFunc = function() return game.IsDedicated() end,
            },
        }
    },
    {
        name = "HUD",
        items = {
            {
                cvar = "cl_huntersglee_nevershowtoplefthud",
                type = "check",
                prettyName = "Never show top left info",
                desc = "Never show score, round type, and skull count? (unless tab was held)",
            },
            {
                cvar = "cl_huntersglee_alwaysshowtoplefthud",
                type = "check",
                prettyName = "Always show top left info",
                desc = "Always show round info, score, and skull count?",
            },
            {
                cvar = "cl_huntersglee_hideplacingbeamhints",
                type = "check",
                prettyName = "Hide placing beam hints?",
                desc = "Hide the beam hints when placing items?",
            },
            {
                cvar = "cl_huntersglee_draw_nearby_players",
                type = "check",
                prettyName = "Reveal nearby player locations?",
                desc = "Draw the location of nearby players on your HUD?\n(Note, this requires suit to be above 0)",
            },
            {
                cvar = "cl_huntersglee_draw_nearby_friendsonly",
                type = "check",
                prettyName = "Only reveal the location of friends?",
                desc = "Only draw the location of nearby players on your HUD if they're on your friends list?",
            },
            {
                cvar = "cl_huntersglee_draw_playernames_whendead",
                type = "check",
                prettyName = "Draw player names when dead?",
                desc = "Draw player names on the HUD when you're dead?",
            },
            {
                cvar = "cl_huntersglee_highcontrast",
                type = "check",
                prettyName = "High contrast",
                desc = "All HUD and menu text in plain white.",
            },
        },
    },
    {
        name = "Souls",
        items = {
            {
                cvar = "cl_huntersglee_dosoulragdolls",
                type = "check",
                prettyName = "Enable 'Souls'",
                desc = "Enable funny client ragdolls on dead players",
            },
            {
                cvar = "cl_huntersglee_seeownsoul",
                type = "check",
                prettyName = "Draw your own soul?",
                desc = "Let your own soul be visible to you",
            },
            {
                cvar = "cl_huntersglee_ownsoul_nearfade",
                type = "slider",
                min = 0,
                max = 1,
                decimals = 2,
                prettyName = "Own soul transparency",
                desc = "How transparent should your own soul be when it's near you",
            },
        }
    },
}


local function stepSize( def )
    return 1 / ( 10 ^ ( def.decimals or 0 ) )

end

local function roundToStep( def, value )
    local step = stepSize( def )
    return math.Round( value / step ) * step

end

local function formatValue( def, value )
    return string.format( "%." .. ( def.decimals or 0 ) .. "f", value )

end

-- brackets mean "still the shipped default", whether that default is a number or -1
local function bracketed( text )
    return "(" .. text .. ")"

end

local function isAtDefault( cvarRef )
    local default = tonumber( cvarRef:GetDefault() )
    if not default then return false end -- a non numeric setting can't be compared this way

    return cvarRef:GetFloat() == default

end

-- Returns the number to fill the bar to, and the text to print beside it. Both differ
-- from the convar when it holds -1, which means "whatever the feature picked itself".
local function readSetting( def, cvarRef )
    local raw       = cvarRef:GetFloat()
    local autoing   = def.defaultValue and raw < 0
    local value     = math.Clamp( autoing and def.defaultValue or raw, def.min, def.max )

    -- 0.35 through a one decimal slider's own format would print as 0.3, so an
    -- auto-default prints itself rather than what the bar can express
    local text = autoing and tostring( def.defaultValue ) or formatValue( def, value )

    if isAtDefault( cvarRef ) then
        text = bracketed( text )

    end

    return value, text

end


-- Shared by both row types. The caller overrides UpdateFromCvar, which runs every frame
local function makeRow( parent, def )
    local cvarRef = GetConVar( def.cvar )

    local row = vgui.Create( "glee_row", parent )
    row:SetLabel( def.prettyName or def.cvar )
    row:SetReservedValue( WIDEST_VALUE )
    row:SetTooltip( ( def.desc or "" ) .. "\n\nRight click to reset to default." )

    -- stub, the subtypes read the cvar their own way
    function row:UpdateFromCvar()
    end

    function row:AdditionalThink()
        self:UpdateFromCvar()

    end

    function row:ResetToDefault()
        -- written verbatim so the -1 sliders go back to meaning "let the feature decide"
        RunConsoleCommand( def.cvar, cvarRef:GetDefault() )
        self:ShowPress( "switch", 100, 0.14 )

    end

    function row:DoRightClick()
        self:ResetToDefault()

    end

    return row, cvarRef

end


local function makeSliderRow( parent, def, sliderColumn )
    local row, cvarRef = makeRow( parent, def )
    row:SetLabelColumn( sliderColumn )
    table.insert( sliderColumn, row )

    local span = def.max - def.min

    -- The row is the box, so the meter contributes the bar only.
    local meter = vgui.Create( "glee_meter", row )
    meter:SetPaintBackground( false )
    meter:SetEmptyColor( "bgDark" )
    meter:SetFillColor( "happy" )
    meter:SetState( meter.STATE_NORMAL )

    -- one chunk per step, until the steps are too fine to chunk and it becomes a plain bar
    if def.decimals >= 2 then
        meter:SetSmooth( true )

    else
        meter:SetChunks( math.Round( span / stepSize( def ) ) )

    end

    row:SetMiddle( meter, METER_MIN_W_1080P )

    function row:ShowValue( value )
        self:SetValue( formatValue( def, value ) )
        meter:SetFill( ( value - def.min ) / span )

    end

    function row:UpdateFromCvar()
        if self._dragging then return end -- their hand is on it, the cvar is behind

        -- the convar no longer holds what this row last wrote, so someone else moved
        -- it, and the value we remember must stop suppressing clicks. see ApplyValue
        if self._appliedValue and self._appliedValue ~= cvarRef:GetFloat() then
            self._appliedValue = nil

        end

        local value, text = readSetting( def, cvarRef )
        self:SetValue( text )
        meter:SetFill( ( value - def.min ) / span )

    end

    -- The bar has no grip to grab, so the value is wherever along it they clicked.
    function row:ValueFromCursor()
        local pad  = meter:Style():Metric( "blockPadding" )
        local barW = meter:GetWide() - pad * 2 -- the meter insets its own bar by this
        if barW <= 0 then return def.min end

        local mx   = meter:CursorPos()
        local frac = math.Clamp( ( mx - pad ) / barW, 0, 1 )

        return roundToStep( def, def.min + frac * span )

    end

    -- only writes when the value moved, so a drag doesn't fire a console command every
    -- frame. UpdateFromCvar drops the remembered value when the convar stops matching it
    function row:ApplyValue( value )
        if value == self._appliedValue then return end
        self._appliedValue = value

        self:ShowValue( value )

        if def.changeWhenDone then return end

        RunConsoleCommand( def.cvar, tostring( value ) )

    end

    function row:CommitValue()
        if not def.changeWhenDone then return end
        if not self._appliedValue then return end

        RunConsoleCommand( def.cvar, tostring( self._appliedValue ) )

    end

    function row:DoRightClick()
        self._appliedValue = nil
        self:ResetToDefault()

    end

    -- a press starts a drag rather than being a click, so this replaces the row's own
    function row:OnMousePressed( code )
        if code == MOUSE_RIGHT then
            self:DoRightClick()
            return

        end

        if code ~= MOUSE_LEFT then return end

        self:ShowPress()

        self._dragging = true
        self:MouseCapture( true ) -- so a drag that leaves the row still ends here
        self:ApplyValue( self:ValueFromCursor() )

    end

    function row:OnCursorMoved()
        if not self._dragging then return end

        self:ApplyValue( self:ValueFromCursor() )

    end

    function row:OnMouseReleased( code )
        if code ~= MOUSE_LEFT then return end
        if not self._dragging then return end

        self._dragging = false
        self:MouseCapture( false )
        self:CommitValue()

    end

    row:UpdateFromCvar()

    return row

end


local function makeCheckRow( parent, def )
    local row, cvarRef = makeRow( parent, def )

    function row:UpdateFromCvar()
        local on   = cvarRef:GetBool()
        local text = on and "ON" or "OFF"

        if isAtDefault( cvarRef ) then
            text = bracketed( text )

        end

        self:SetValue( text )
        self:SetContentColor( on and "happy" or "text" )

    end

    function row:DoClick()
        RunConsoleCommand( def.cvar, cvarRef:GetBool() and "0" or "1" )

    end

    row:UpdateFromCvar()

    return row

end


local function buildSettingsMenu()
    local frame = vgui.Create( "glee_frame" )
    terminator_Extras.glee_SetPanelScale( frame, "fixed" )

    local style = frame:Style()
    local pad   = style:Metric( "blockPadding" )
    local gap   = style:Metric( "laneSpacing" )

    local scroll = vgui.Create( "glee_scrollpanel", frame )
    scroll:Dock( FILL )

    -- the right margin keeps rows off the scroll bar
    local function dockIntoList( panel, topGap )
        panel:Dock( TOP )
        panel:DockMargin( 0, topGap or 0, pad, gap )

    end

    -- only a slider shares its row with a bar, so only sliders line their labels up
    local sliderColumn = {}

    for catIndex, cat in ipairs( settingsCategories ) do
        local heading = vgui.Create( "glee_heading", scroll )
        heading:SetFont( HEADER_FONT )
        heading:SetText( cat.name )
        dockIntoList( heading, catIndex > 1 and gap * 3 or nil )

        for _, def in ipairs( cat.items ) do
            if not GetConVar( def.cvar ) then
                ErrorNoHaltWithStack( "glee settings menu: no such convar, " .. tostring( def.cvar ) .. "\n" )

            elseif def.showSettingFunc and not def.showSettingFunc() then
                continue

            elseif def.type == "slider" then
                dockIntoList( makeSliderRow( scroll, def, sliderColumn ) )

            elseif def.type == "check" then
                dockIntoList( makeCheckRow( scroll, def ) )

            end
        end
    end

    frame:SizeToContents( math.min( style:Scaled( FRAME_MAX_H_1080P ), ScrH() * 0.9 ) )
    frame:Center()

    terminator_Extras.easyClosePanel( frame )
    LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    return frame

end

concommand.Add( "glee_settings_open", function()
    local newFrame = buildSettingsMenu()
    if not IsValid( newFrame ) then return end

    -- the old frame's OnRemove clears the holder, so it has to go before the new one
    -- is stored, not after
    if IsValid( GAMEMODE.glee_SettingsMenu_Holder ) then
        GAMEMODE.glee_SettingsMenu_Holder:Remove()

    end

    GAMEMODE.glee_SettingsMenu_Holder = newFrame

    function newFrame:OnRemove()
        if GAMEMODE.glee_SettingsMenu_Holder ~= self then return end

        GAMEMODE.glee_SettingsMenu_Holder = nil

    end
end )

function GAMEMODE:OpenSettingsMenu()
    RunConsoleCommand( "glee_settings_open" )

end

local width, height = glee_sizeScaled( 720, FRAME_MAX_H_1080P )
list.Set( "DesktopWindows", "HuntersGlee_Settings", {
    title = "Glee Settings",
    icon = "icon16/wrench.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        -- the list gives us a window we don't want, the concommand builds the real one
        if IsValid( window ) then window:Remove() end
        RunConsoleCommand( "glee_settings_open" )

    end
} )
