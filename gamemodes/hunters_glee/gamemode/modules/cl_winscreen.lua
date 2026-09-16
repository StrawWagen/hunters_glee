
local GAMEMODE = GAMEMODE or GM

-- cl_winscreen.lua
-- the round end verdict, a godlyDecreeHud decree with godHud's sounds and jitter
-- each line spirals in out of faint ghosts, holds, then the next section arrives

local godHud = terminator_Extras.godHud
local godlyDecreeHud = terminator_Extras.godlyDecreeHud
local hudHelpers = terminator_Extras.glee_HudHelpers

-- stagger: delay between each entry starting to arrive
local ENTRY_STAGGER     = 0.08

-- how long each section waits before the NEXT section starts entering
-- the section holds on screen until the screen clears
local SECTION_DELAY     = 3.5

-- the verdict, when the last line in a section lands, is one of godHud.textLandingSounds
local HIT_SNDLVL        = 100

local screenMiddleW = ScrW() / 2
local screenMiddleH = ScrH() / 2

-- a "section" is a group of text lines that arrive together with stagger
-- sections = { { startTime, hitPitch, entries = { { text, color, font, jitter }, ... } }, ... }
-- color names a godlyDecreeHud color, font defaults to godlyDecreeHud.fonts.triumphant, jitter shakes the line once it lands
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
            { text = "Hunt's Tally",         color = "textEndscreenColor" },
            { text = tostring( totalScore ), color = "textEndscreenColor" },
        },
    }


    -- SECTION 2: Finest Prey
    local winner = GetGlobalEntity( "glee_Winner", NULL )
    local winnerSkulls = GetGlobalInt( "glee_WinnerSkulls", 0 )

    local preyEntries = {
        { text = "Finest Prey", color = "textEndscreenColor" },
    }

    if IsValid( winner ) then
        preyEntries[#preyEntries + 1] = { text = winner:Nick(), color = "textEndscreenColor", font = godlyDecreeHud.fonts.playerName }
        local sIfMultiple = winnerSkulls == 1 and "" or "s"
        preyEntries[#preyEntries + 1] = { text = winnerSkulls .. " Skull" .. sIfMultiple, color = "textEndscreenColor" }

    else
        preyEntries[#preyEntries + 1] = { text = "Nobody", color = "textEndscreenColor" }
        preyEntries[#preyEntries + 1] = { text = "No skulls were collected", color = "textDoomColor", jitter = true }

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
        escapedEntries[1] = { text = "Nobody Escaped", color = "textDoomColor", jitter = true }

    else
        local sIfMultipleEscaped = escapedCount == 1 and "" or "s"
        escapedEntries[1] = { text = escapedCount .. " Soul" .. sIfMultipleEscaped .. " Escaped", color = "textEndscreenColor" }
        if remainedCount <= 0 then
            escapedEntries[2] = { text = "A great boon awaits...", color = "textBoonColor", jitter = true }

        else
            local sIfMultipleRemained = remainedCount == 1 and "" or "s"
            local noSifMultiple = remainedCount <= 1 and "s" or ""
            escapedEntries[2] = { text = remainedCount .. " Soul" .. sIfMultipleRemained .. " Remain" .. noSifMultiple, color = "textEndscreenColor" }

        end
    end

    sections[3] = {
        startTime = startTime + SECTION_DELAY * 3,
        hitPitch = 20,
        entries = escapedEntries,
    }
end

-- copies, DrawGhosts writes their alpha
local ghostTextColor = Color( 255, 255, 255 )
local ghostShadowColor = ColorAlpha( godlyDecreeHud.shadowColor, 255 )

local ghostData = {
    textColor = ghostTextColor,
    shadowColor = ghostShadowColor,
    shadowOffsetX = godlyDecreeHud.shadowOffsetX,
    shadowOffsetY = godlyDecreeHud.shadowOffsetY,
}

local solidData = {
    shadowColor = godlyDecreeHud.shadowColor,
    shadowOffsetX = godlyDecreeHud.shadowOffsetX,
    shadowOffsetY = godlyDecreeHud.shadowOffsetY,
}

local lastHitPlay = 0

local function paintEntry( entry, entryIndex, isLast, sectionStartTime, hitPitch, ply, now )
    local entryStart = sectionStartTime + ( entryIndex - 1 ) * ENTRY_STAGGER
    if now < entryStart then return end -- not yet

    local ghostSettings = godlyDecreeHud.ghosts.triumphant
    local elapsed = now - entryStart

    entry.ghosts = entry.ghosts or hudHelpers.BuildGhosts( ghostSettings )
    local appeared = hudHelpers.AdvanceGhosts( entry.ghosts, elapsed, ghostSettings )
    if appeared > 0 and not entry.whooshed then
        entry.whooshed = true
        hudHelpers.PlaySound( godHud.textArrivalSounds, hitPitch + math.random( 40, 60 ), CHAN_STATIC, 0.4 )

    end

    local materialised = hudHelpers.GhostsMaterialised( elapsed, ghostSettings )
    if materialised >= 1 and not entry.landed then
        entry.landed = true

        if isLast then
            local volume = 0.75
            if lastHitPlay == now then
                volume = 0.1

            end
            lastHitPlay = now
            local landingSounds = godHud.textLandingSounds
            ply:EmitSound( landingSounds[math.random( #landingSounds )], HIT_SNDLVL, hitPitch, volume )
            ply:EmitSound( "doors/heavy_metal_stop1.wav", HIT_SNDLVL, hitPitch + math.random( 20, 25 ), volume )

        end
    end

    local jitterX = 0
    local jitterY = 0
    if entry.landed and entry.jitter then
        hudHelpers.DoJitter( entry, godHud.jitter )
        jitterX = entry.jitterX
        jitterY = entry.jitterY

    end

    local font = entry.font or godlyDecreeHud.fonts.triumphant
    local textColor = godlyDecreeHud[entry.color]

    if materialised < 1 then
        ghostTextColor.r, ghostTextColor.g, ghostTextColor.b = textColor.r, textColor.g, textColor.b
        ghostData.text = entry.text
        ghostData.font = font
        hudHelpers.DrawGhosts( entry.ghosts, ghostSettings, ghostData, screenMiddleW, entry.drawY )

    end

    solidData.text = entry.text
    solidData.font = font
    solidData.textColor = textColor
    solidData.posX = screenMiddleW + jitterX
    solidData.posY = entry.drawY + jitterY

    -- squared, so it stays hidden while the ghosts are spread out
    surface.SetAlphaMultiplier( materialised ^ 2 )
    surface.drawShadowedTextBetterData( solidData )
    surface.SetAlphaMultiplier( 1 )

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
    local currentY = screenMiddleH + glee_sizeScaled( nil, -200 )
    local sectionGap = glee_sizeScaled( nil, 14 )

    for _, section in ipairs( sections ) do
        if cur < section.startTime then break end

        for entryIdx, entry in ipairs( section.entries ) do
            local isLast = entryIdx == #section.entries
            entry.drawY = currentY
            paintEntry( entry, entryIdx, isLast, section.startTime, section.hitPitch, ply, cur )

            local font = entry.font or godlyDecreeHud.fonts.triumphant
            currentY = currentY + draw.GetFontHeight( font ) * 0.9

        end
        currentY = currentY + sectionGap

    end

    return true

end )
