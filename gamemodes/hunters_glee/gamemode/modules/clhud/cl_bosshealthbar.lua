--[[------------------------------------
    The nearest boss's name and health, across the top of the screen.

    Alive, it shows once you've spotted a boss: near enough, with line of sight. Spotted
    lasts the round, so it's back when you respawn. It needs suit power: without, the name
    corrupts to NO POWER and fades.
    Dead, it shows whenever you're near a boss, spotted or not.

    A boss outside our PVS shows the health it last had here.
--]]-------------------------------------

local GAMEMODE = GAMEMODE or GM

local NAME_FONT = "mediumLarge" -- the round info's, which names the Misery

local METER_MIN_WIDTH = 460 -- 1080p pixels, the guilt checker's
local METER_BAR_HEIGHT = 12

local topPadding = terminator_Extras.defaultHudPaddingFromBottom * 2 -- level with the top left lane

local lookInterval = 0.25
local nearDistance = 2000 -- to spot a boss alive, and to see its bar dead

local revealFlash = 0.4 -- the round info's
local revealSound = "common/warning.wav"
local changeFlash = 0.15 -- the score's

local fadeSpeed = 24 -- the score's
local deadFadeSpeed = 600 -- a ghost leaves range fast, a slow fade lags behind it
local fadeStartDelay = 3 -- alive, how long it holds before fading, a killed boss's empty bar included
local noPowerFadeSpeed = 300

local NO_POWER_TEXT = "NO POWER"
local corruptDuration = 3 -- seconds until every letter is gone, it fades then
local corruptCurve = 4 -- higher stays legible longer, then fizzles faster. 1 is linear
local corruptRerollInterval = 0.08
local corruptGlyphs = { "#", "%", "&", "@", "$", "*", "!", "?", "/", "\\", "|", "_", "=", "+", "<", ">", "~" }

local knownBossIndexes = {}
local spotted = false
local nextLook = 0

local trackedBoss -- a killed boss stays tracked, so its bar empties before fading
local bossName = ""
local introAt -- nil until it first shows this round
local noPowerSince -- nil while powered

local nameBox
local meter


-- Bosses --------------------------------------------------------------------

net.Receive( "glee_bossspawned", function()
    knownBossIndexes[net.ReadUInt( MAX_EDICT_BITS )] = true

end )

-- An index outlives its boss, and can come back as anything
local function bossAt( index )
    local ent = Entity( index )
    if not IsValid( ent ) then return end
    if not GAMEMODE:IsActiveBoss( ent ) then return end

    return ent

end

local function isAlive( boss )
    return IsValid( boss ) and boss:Health() > 0

end

local function nearestLivingBoss( fromPos )
    local nearest
    local nearestDistSqr = math.huge

    for index in pairs( knownBossIndexes ) do
        local boss = bossAt( index )
        if not isAlive( boss ) then continue end

        local distSqr = fromPos:DistToSqr( boss:GetPos() )
        if distSqr >= nearestDistSqr then continue end

        nearest = boss
        nearestDistSqr = distSqr

    end

    return nearest

end

-- A dormant boss's position is wherever we last saw it, so it can't be looked at
local function bossInSight( ply, cur )
    if nextLook > cur then return false end
    nextLook = cur + lookInterval

    local eyePos = ply:EyePos()

    for index in pairs( knownBossIndexes ) do
        local boss = bossAt( index )
        if not isAlive( boss ) then continue end
        if boss:IsDormant() then continue end

        local bossesShoot = boss:GetShootPos()
        if eyePos:DistToSqr( bossesShoot ) > nearDistance ^ 2 then continue end

        if terminator_Extras.PosCanSee( eyePos, bossesShoot, MASK_SOLID_BRUSHONLY ) then return true end

    end

    return false

end

local function wantsBar( alive, viewPos, nearest )
    if not nearest then return false end
    if alive then return spotted end

    return viewPos:DistToSqr( nearest:GetPos() ) < nearDistance ^ 2

end

local function healthFraction( boss )
    if not isAlive( boss ) then return 0 end

    local maxHealth = boss:GetMaxHealth()
    if maxHealth <= 0 then return 1 end

    return math.Clamp( boss:Health() / maxHealth, 0, 1 )

end

local function healthPercent()
    return math.ceil( healthFraction( trackedBoss ) * 100 )

end


-- NO POWER ------------------------------------------------------------------

local corrupted = ""
local nextReroll = 0

-- amount 0 leaves every letter, 1 replaces them all. Rerolled on a timer rather than
-- every frame, so it reads as flicker, not noise. Byte by byte, so ASCII only
local function corruptText( text, amount, cur )
    if nextReroll > cur then return corrupted end
    nextReroll = cur + corruptRerollInterval

    local chars = {}
    for i = 1, #text do
        local char = string.sub( text, i, i )
        if char ~= " " and math.random() < amount then
            char = corruptGlyphs[math.random( #corruptGlyphs )]

        end
        chars[i] = char

    end

    corrupted = table.concat( chars )
    return corrupted

end

local function showNoPower( cur )
    local progress = math.Clamp( ( cur - noPowerSince ) / corruptDuration, 0, 1 )

    nameBox:SetText( corruptText( NO_POWER_TEXT, progress ^ corruptCurve, cur ) )
    nameBox:AutoSize()
    nameBox:SetContentColor( "flash" ) -- the battery box's, when it's empty
    nameBox:SetFadeSpeed( noPowerFadeSpeed )
    nameBox:SetFadeStartDelay( 0 )

    -- NORMAL shows a hidden box, so one that had gone stays gone
    if progress < 1 and nameBox:GetStateAlpha() > 0 then
        nameBox:SetState( nameBox.STATE_NORMAL )

    else
        nameBox:SetState( nameBox.STATE_FADING )

    end
end


-- Boxes ---------------------------------------------------------------------

local function createBoxes()
    if IsValid( nameBox ) then nameBox:Remove() end
    if IsValid( meter ) then meter:Remove() end

    nameBox = vgui.Create( "glee_countbox", GetAutoHidingHUDPanel() )
    nameBox:SetFont( NAME_FONT )
    nameBox:SetBaseColor( "happy" ) -- the round info's
    nameBox:SetCountFunc( healthPercent )
    nameBox:SetSuffix( "%" )
    nameBox:SetShowDiff( false )
    nameBox:SetChangeVisibleDuration( 4 ) -- the skulls', so every hit flashes

    meter = vgui.Create( "glee_meter", GetAutoHidingHUDPanel() )
    meter:SetSmooth( true ) -- health is in hundredths, too fine for a chunk each
    meter:SetEmptyColor( "bgDark" )

    -- the meter copies the name box's state, so it has to fade and flash at its pace
    for _, box in ipairs( { nameBox, meter } ) do
        box:SetFlashDuration( changeFlash )
        box:SetFadeSpeed( fadeSpeed )
        box:SetFadeStartDelay( fadeStartDelay )

    end
end

hook.Add( "OnGamemodeLoaded", "glee_bosshealthbar_create", createBoxes )
if GAMEMODE then createBoxes() end

local function hideBoxes()
    if not IsValid( nameBox ) then return end

    nameBox:SetState( nameBox.STATE_HIDDEN )
    meter:SetState( meter.STATE_HIDDEN )

end

-- a flash's length is read when it starts, so the usual one can go straight back
local function playIntro( cur )
    introAt = cur
    nameBox:SetStartingCount( healthPercent() )

    for _, box in ipairs( { nameBox, meter } ) do
        box:SetFlashDuration( revealFlash )
        box:SetState( box.STATE_FLASH )
        box:SetFlashDuration( changeFlash )

    end

    surface.PlaySound( revealSound )

end

local function forget()
    knownBossIndexes = {}
    spotted = false
    trackedBoss = nil
    introAt = nil
    noPowerSince = nil

    hideBoxes()

end

hook.Add( "glee_roundstatechanged", "glee_bosshealthbar_forget", function( _oldState, newState )
    if newState == GAMEMODE.ROUND_ACTIVE then return end

    forget()

end )

-- The name box fits its text like the top left lane's, centred over a meter that's
-- never narrower than it
local function layoutBoxes( xOffset )
    local style = meter:Style()
    local pad = style:Metric( "blockPadding" )
    local gap = style:Metric( "laneSpacing" )

    local width = math.max( style:Scaled( METER_MIN_WIDTH ), nameBox:GetWide() )
    meter:SetBarSize( width - pad * 2, style:Scaled( METER_BAR_HEIGHT ) )

    local height = nameBox:GetTall() + gap + meter:GetTall()
    local centerX = ScrW() * 0.5
    local x = centerX - width * 0.5
    local y = topPadding

    local inTheWay = GAMEMODE:HudSpaceInMyWay( x, y, width, height )
    if inTheWay then
        y = inTheWay + gap

    end

    nameBox:SetPos( centerX - nameBox:GetWide() * 0.5 + xOffset, y )
    meter:SetPos( x, y + nameBox:GetTall() + gap )

    if nameBox:GetStateAlpha() <= 0 then return end

    GAMEMODE:ImUsingHudSpace( "bossHealthBar", x, y, width, height )

end

hook.Add( "glee_cl_aliveordeadplyhud", "glee_bosshealthbar_draw", function( ply, cur )
    if not IsValid( nameBox ) or not IsValid( meter ) then return end

    local alive = ply:Health() > 0

    if alive and not spotted then
        spotted = bossInSight( ply, cur )

    end

    if not GAMEMODE:CanShowDefaultHud() then
        hideBoxes()
        return

    end

    -- EyePos() is the view, ply:EyePos() isn't while spectating
    local viewPos = EyePos()
    local nearest = nearestLivingBoss( viewPos )
    local wanted = wantsBar( alive, viewPos, nearest )
    local powered = not alive or ply:Armor() > 0

    -- the intro is held for power, so it's never spent on NO POWER
    if not introAt then
        if not wanted or not powered then return end

        trackedBoss = nearest
        playIntro( cur )

    elseif nearest and nearest ~= trackedBoss then
        trackedBoss = nearest
        nameBox:SetStartingCount( healthPercent() ) -- another boss's health isn't damage

    end

    if IsValid( trackedBoss ) then
        bossName = GAMEMODE:GetNameOfBot( trackedBoss )

    end

    local xOffset = 0

    if powered then
        noPowerSince = nil

        local speed = alive and fadeSpeed or deadFadeSpeed
        local delay = alive and fadeStartDelay or 0

        for _, box in ipairs( { nameBox, meter } ) do
            box:SetFadeSpeed( speed )
            box:SetFadeStartDelay( delay )

        end

        nameBox:SetLabel( bossName .. " : " )
        -- unwanted, nothing holds it up, so it fades, after the kill's flash if there was one
        xOffset = nameBox:ManageHudState( ply, cur, wanted, false )

        meter:SetFill( healthFraction( trackedBoss ) )
        meter:SetState( nameBox:GetState() )

    else
        noPowerSince = noPowerSince or cur
        showNoPower( cur )

        meter:SetState( meter.STATE_HIDDEN ) -- health is a suit reading

    end

    layoutBoxes( xOffset )

end )

-- The boxes keep painting whether or not the hud hooks run, and they stop on the win screen
hook.Add( "glee_paintWinScreen", "glee_bosshealthbar_hide", hideBoxes )
