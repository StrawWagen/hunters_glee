
local GAMEMODE = GAMEMODE or GM

-- cl_winscreen.lua
-- the round end verdict, drawn in the godlyDecree style
-- each line spirals in out of faint ghosts, holds, then the next section arrives

local decree = terminator_Extras.glee_Style( "godlyDecree" )

-- every line arrives as the verdict does, whatever font it is set in
local VERDICT_FONT = "triumphant"

-- stagger: delay between each entry starting to arrive
local ENTRY_STAGGER     = 0.08

-- how long each section waits before the NEXT section starts entering
-- the section holds on screen until the screen clears
local SECTION_DELAY     = 3.5

-- the verdict, when the last line in a section lands, is one of the style's landing sounds
local HIT_SNDLVL        = 100

local screenMiddleW = ScrW() / 2
local screenMiddleH = ScrH() / 2

-- a "section" is a group of text lines that arrive together with stagger
-- sections = { { startTime, hitPitch, entries = { { text, color, font, jitter }, ... } }, ... }
-- color and font are roles of the godlyDecree style, font defaulting to VERDICT_FONT.
-- jitter shakes the line once it lands
local sections = {}
local winScreenActive = false

local function buildSections( startTime )
    sections = {}

    -- SECTION 1: Hunt's Tally
    local totalScore = GetGlobalInt( "glee_TotalScore", 0 )
    totalScore = math.Round( totalScore )

    sections[1] = {
        startTime = startTime + SECTION_DELAY,
        hitPitch = 30,
        entries = {
            { text = "Hunt's Tally",         color = "endscreen" },
            { text = tostring( totalScore ), color = "endscreen" },
        },
    }


    -- SECTION 2: Finest Prey
    local winner = GetGlobalEntity( "glee_Winner", NULL )
    local winnerSkulls = GetGlobalInt( "glee_WinnerSkulls", 0 )

    local preyEntries = {
        { text = "Finest Prey", color = "endscreen" },
    }

    if IsValid( winner ) then
        preyEntries[#preyEntries + 1] = { text = winner:Nick(), color = "endscreen", font = "playerName" }
        local sIfMultiple = winnerSkulls == 1 and "" or "s"
        preyEntries[#preyEntries + 1] = { text = winnerSkulls .. " Skull" .. sIfMultiple, color = "endscreen" }

    else
        preyEntries[#preyEntries + 1] = { text = "Nobody", color = "endscreen" }
        preyEntries[#preyEntries + 1] = { text = "No skulls were collected", color = "doom", jitter = true }

    end

    sections[2] = {
        startTime = startTime + SECTION_DELAY * 2,
        hitPitch = 25,
        entries = preyEntries,
    }


    -- SECTION 3: Souls Escaped
    local escapedCount = GetGlobalInt( "glee_EscapedCount", 0 )
    local remainedCount = GetGlobalInt( "glee_RemainedCount", 0 )

    local escapedEntries = {}

    if escapedCount <= 0 then
        escapedEntries[1] = { text = "Nobody Escaped", color = "doom", jitter = true }

    else
        local sIfMultipleEscaped = escapedCount == 1 and "" or "s"
        escapedEntries[1] = { text = escapedCount .. " Soul" .. sIfMultipleEscaped .. " Escaped", color = "endscreen" }
        if remainedCount <= 0 then
            escapedEntries[2] = { text = "A great boon awaits...", color = "boon", jitter = true }

        else
            local sIfMultipleRemained = remainedCount == 1 and "" or "s"
            local noSifMultiple = remainedCount <= 1 and "s" or ""
            escapedEntries[2] = { text = remainedCount .. " Soul" .. sIfMultipleRemained .. " Remain" .. noSifMultiple, color = "endscreen" }

        end
    end

    sections[3] = {
        startTime = startTime + SECTION_DELAY * 3,
        hitPitch = 20,
        entries = escapedEntries,
    }
end

local lastHitPlay = 0

local function paintEntry( entry, entryIndex, isLast, sectionStartTime, hitPitch, ply, now )
    local entryStart = sectionStartTime + ( entryIndex - 1 ) * ENTRY_STAGGER
    if now < entryStart then return end -- not yet

    local line = entry.line
    if not line then
        line = decree:NewArrival( entry.font or VERDICT_FONT, VERDICT_FONT )
        line:SetText( entry.text )
        entry.line = line

    end

    local appeared, justLanded = line:Update( now - entryStart )

    if appeared > 0 and not entry.whooshed then
        entry.whooshed = true
        decree:PlaySound( "arrival", hitPitch + math.random( 40, 60 ), CHAN_STATIC, 0.4 )

    end

    if justLanded and isLast then
        local volume = 0.75
        if lastHitPlay == now then
            volume = 0.1

        end
        lastHitPlay = now
        decree:PlaySound( "landing", hitPitch, nil, volume, HIT_SNDLVL )
        ply:EmitSound( "doors/heavy_metal_stop1.wav", HIT_SNDLVL, hitPitch + math.random( 20, 25 ), volume )

    end

    local jitterX = 0
    local jitterY = 0
    if line.landed and entry.jitter then
        decree:Jitter( entry )
        jitterX = entry.jitterX
        jitterY = entry.jitterY

    end

    line:Draw( screenMiddleW + jitterX, entry.drawY + jitterY, entry.color )

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
    local currentY = screenMiddleH + glee_sizeScaled( nil, -300 ) -- up offset
    local sectionGap = glee_sizeScaled( nil, 14 )

    for _, section in ipairs( sections ) do
        if cur < section.startTime then break end

        for entryIdx, entry in ipairs( section.entries ) do
            local isLast = entryIdx == #section.entries
            entry.drawY = currentY
            paintEntry( entry, entryIdx, isLast, section.startTime, section.hitPitch, ply, cur )

            local font = decree:Font( entry.font or VERDICT_FONT )
            currentY = currentY + draw.GetFontHeight( font ) * 0.9

        end
        currentY = currentY + sectionGap

    end
end )
