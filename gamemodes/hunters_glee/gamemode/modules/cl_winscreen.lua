-- cl_winscreen.lua
-- dramatic sliding round end screen
-- each info block slides in from the side, holds, then the next one appears

-- per-entry slide timing
local SLIDE_IN_TIME     = 0.1      -- how fast each line slides in
local EASE_IN_POWER     = 3.0       -- snappiness of slide in, 1 = linear, 3 = snappy

-- stagger: delay between each entry starting its slide-in
local ENTRY_STAGGER     = 0.08

-- how long each section waits before the NEXT section starts entering
-- the section holds on screen until the screen clears
local SECTION_DELAY     = 3.5


-- the impact sound when a line lands
local HIT_SOUNDS        = { "physics/metal/metal_barrel_impact_hard5.wav", "physics/metal/metal_barrel_impact_hard6.wav" }
local HIT_SNDLVL        = 100

-- the impact sounds when the last line in a section xlands
local HIT_LAST_SOUNDS   = { "doors/heavy_metal_stop1.wav" }

-- slide direction per entry index: alternating feels cinematic
-- true = from left, false = from right
local function slideDirection( entryIndex )
    return entryIndex % 2 == 1 -- odd entries from left, even from right

end


local screenW = ScrW()
local screenMiddleW = screenW / 2
local screenMiddleH = ScrH() / 2

local color_red = Color( 255, 0, 0 )

-- easing
local function easeOut( t, power )
    t = math.Clamp( t, 0, 1 )
    return 1 - ( 1 - t ) ^ power

end

-- a "section" is a group of text lines that slide in together with stagger
-- sections = { { startTime, entries = { { text, font, color, yOffset }, ... } }, ... }
local sections = {}
local winScreenActive = false

local function buildSections( startTime )
    sections = {}

    -- SECTION 1: Hunt's Tally
    local totalScore = GetGlobalInt( "glee_TotalScore", 0 )
    totalScore = math.Round( totalScore )

    sections[1] = {
        startTime = startTime + SECTION_DELAY,
        hitPitch = 90,
        entries = {
            { text = "Hunt's Tally",                font = "termhuntTriumphantFont", color = color_white },
            { text = tostring( totalScore ),         font = "termhuntTriumphantFont", color = color_red },
        },
    }


    -- SECTION 2: Finest Prey
    local winner = GetGlobalEntity( "glee_Winner", NULL )
    local winnerSkulls = GetGlobalInt( "glee_WinnerSkulls", 0 )

    local preyEntries = {
        { text = "Finest Prey", font = "termhuntTriumphantFont", color = color_white },
    }

    if IsValid( winner ) then
        preyEntries[#preyEntries + 1] = { text = winner:Nick(), font = "termhuntTriumphantFont", color = color_white }
        local sIfMultiple = winnerSkulls == 1 and "" or "s"
        preyEntries[#preyEntries + 1] = { text = winnerSkulls .. " Skull" .. sIfMultiple, font = "termhuntTriumphantFont", color = color_red }

    else
        preyEntries[#preyEntries + 1] = { text = "Nobody", font = "termhuntTriumphantFont", color = color_white }
        preyEntries[#preyEntries + 1] = { text = "No skulls were collected", font = "termhuntTriumphantFont", color = color_red }

    end

    sections[2] = {
        startTime = startTime + SECTION_DELAY * 2,
        hitPitch = 80,
        entries = preyEntries,
    }


    -- SECTION 3: Souls Escaped
    local escapedCount = GetGlobalInt( "glee_EscapedCount", 0 )

    local escapedEntries = {
        { text = "Souls Escaped", font = "termhuntTriumphantFont", color = color_white },
    }

    if escapedCount <= 0 then
        escapedEntries[#escapedEntries + 1] = { text = "None, Nobody Escaped", font = "termhuntTriumphantFont", color = color_red }

    else
        local sIfMultiple = escapedCount == 1 and "" or "s"
        escapedEntries[#escapedEntries + 1] = { text = escapedCount .. " Soul" .. sIfMultiple .. " Escaped", font = "termhuntTriumphantFont", color = color_red }

    end

    sections[3] = {
        startTime = startTime + SECTION_DELAY * 3,
        hitPitch = 70,
        entries = escapedEntries,
    }
end

local entryColor = Color( 255, 255, 255, 255 )

local lastHitPlay = 0

local function paintEntry( entry, entryIndex, isLast, sectionStartTime, sectionPitch, ply, now )
    local entryStart = sectionStartTime + ( entryIndex - 1 ) * ENTRY_STAGGER
    if now < entryStart then return end -- not yet

    local age = now - entryStart

    -- always sliding in or holding, never sliding out while win screen is up
    local fraction
    if age < SLIDE_IN_TIME then
        local t = age / SLIDE_IN_TIME
        fraction = easeOut( t, EASE_IN_POWER )

    else
        fraction = 1

    end

    -- play sound once on landing
    if fraction >= 1 and not entry.hitPlayed then
        entry.hitPlayed = true
        local sounds = isLast and HIT_LAST_SOUNDS or HIT_SOUNDS
        local volume = 0.75
        if lastHitPlay == now then
            volume = 0.1

        end
        lastHitPlay = now
        ply:EmitSound( sounds[math.random( #sounds )], HIT_SNDLVL, sectionPitch, volume )
    end

    local fromLeft = slideDirection( entryIndex )
    local offScreenX = fromLeft and ( -screenW * 0.4 ) or ( screenW * 1.4 )
    local drawX = Lerp( fraction, offScreenX, screenMiddleW )

    entryColor.r = entry.color.r
    entryColor.g = entry.color.g
    entryColor.b = entry.color.b
    entryColor.a = 255

    surface.drawShadowedTextBetter( entry.text, entry.font, entryColor, drawX, entry.drawY )

end

hook.Add( "glee_blockGenericAnnouncements", "cl_winscreen_block_announcements", function()
    if winScreenActive then return true end

end )

hook.Add( "glee_winScreenEnded", "cl_winscreen_reset", function()
    winScreenActive = false
    sections = {}

end )

hook.Add( "glee_paintWinScreen", "cl_winscreen_paint", function( ply, cur )
    if not winScreenActive then
        winScreenActive = true
        buildSections( cur )

    end

    if not GAMEMODE:CanShowDefaultHud() then return end

    -- compute Y positions: stack sections vertically from a starting Y
    local currentY = screenMiddleH + glee_sizeScaled( nil, -130 )
    local lineSpacing = glee_sizeScaled( nil, 50 )
    local sectionGap = glee_sizeScaled( nil, 14 )

    for _, section in ipairs( sections ) do
        if cur < section.startTime then break end

        for entryIdx, entry in ipairs( section.entries ) do
            local isLast = entryIdx == #section.entries
            entry.drawY = currentY
            paintEntry( entry, entryIdx, isLast, section.startTime, section.hitPitch, ply, cur )
            currentY = currentY + lineSpacing

        end
        currentY = currentY + sectionGap

    end

    return true

end )
