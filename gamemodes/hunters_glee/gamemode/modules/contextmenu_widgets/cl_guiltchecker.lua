local FRAME_W_1080P = 500
local FRAME_H_1080P = 300

local SKULL_SIZE_1080P = 90
local METER_H_1080P    = 9

local skullMat = Material( "vgui/hud/deadshopicon.png", "smooth noclamp" )

local function getTierData( guiltDays )
    local result = nil
    for threshold, data in SortedPairs( GAMEMODE.PermaGuiltInfo ) do
        if guiltDays >= threshold then
            result = data
        end
    end
    return result
end


local guiltChecker = {}

function guiltChecker:Create( container )
    local scale     = GAMEMODE.shopStandards.shpScale
    local padding   = math.floor( GAMEMODE.shopStandards.borderPadding * scale )
    local skullSize  = glee_sizeScaled( nil, SKULL_SIZE_1080P * scale )
    local meterBarH  = math.max( 1, glee_sizeScaled( nil, METER_H_1080P * scale ) )
    local itemGap    = math.floor( padding * 0.3 )

    container:DockPadding( 0, 0, 0, 0 )
    container:DockMargin( padding, padding, padding, padding )
    container:SetTitle( "" )
    container:ShowCloseButton( false )
    container:SetDraggable( false )
    function container:Paint() end

    local root = vgui.Create( "DPanel", container )
    root:Dock( FILL )

    local bobPx = glee_sizeScaled( nil, 2 * scale )

    function root:Paint( w, h )
        local guiltDays = LocalPlayer():GetNWInt( "glee_persistentguilt_days", 0 )

        -- Recompute tier-derived data only when guilt or panel width changes
        if guiltDays ~= self.lastGuiltDays or w ~= self.lastW then
            local tierData = getTierData( guiltDays )
            self.evilColor     = tierData.color
            self.cachedBigText = guiltDays .. " " .. ( ( guiltDays == 1 ) and "DAY" or "DAYS" ) .. " OF GUILT"

            surface.SetFont( "termhuntShopCategoryFont" )
            local _, bigH = surface.GetTextSize( self.cachedBigText )
            self.cachedBigH = bigH

            surface.SetFont( "termhuntShopItemFont" )
            local _, lineH = surface.GetTextSize( "A" )
            self.cachedLineH = lineH

            local maxTextW    = math.floor( w * 0.85 )
            local words       = string.Explode( " ", tierData.message )
            local lines       = {}
            local currentLine = ""
            for _, word in ipairs( words ) do
                local test = currentLine == "" and word or ( currentLine .. " " .. word )
                local tw   = surface.GetTextSize( test )
                if tw > maxTextW and currentLine ~= "" then
                    table.insert( lines, currentLine )
                    currentLine = word
                else
                    currentLine = test
                end
            end
            if currentLine ~= "" then table.insert( lines, currentLine ) end
            self.cachedLines = lines
            self.cachedTotalH = skullSize + itemGap
                              + self.cachedBigH + itemGap
                              + meterBarH + itemGap
                              + #lines * self.cachedLineH

            self.lastGuiltDays = guiltDays
            self.lastW         = w
        end

        local evilColor = self.evilColor

        -- Background
        surface.SetDrawColor( GAMEMODE.shopStandards.backgroundColor )
        surface.DrawRect( 0, 0, w, h )

        -- Pulsing red overlay at 10+ days (subtle at 10, clearly evil at 20)
        if guiltDays >= 10 then
            local t       = math.Clamp( ( guiltDays - 10 ) / 10, 0, 1 )
            local pulseHz = 0.8 + t * 1.5
            local pulse   = math.sin( CurTime() * pulseHz * math.pi * 2 ) * 0.5 + 0.5
            local maxA    = 8 + t * 20
            surface.SetDrawColor( 180, 0, 0, math.floor( pulse * maxA ) )
            surface.DrawRect( 0, 0, w, h )
        end

        local cx = w * 0.5
        local y  = math.floor( ( h - self.cachedTotalH ) * 0.5 )

        -- Skull icon: tinted by evil level, gently bobbing when guilty
        local bob = guiltDays > 0 and ( math.sin( CurTime() * 1.8 ) * bobPx ) or 0
        surface.SetMaterial( skullMat )
        surface.SetDrawColor( evilColor.r, evilColor.g, evilColor.b, 255 )
        surface.DrawTexturedRect( cx - skullSize * 0.5, y + bob, skullSize, skullSize )
        y = y + skullSize + itemGap

        -- Big guilt number
        draw.SimpleText( self.cachedBigText, "termhuntShopCategoryFont", cx, y, evilColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        y = y + self.cachedBigH + itemGap

        -- Evil meter bar
        local meterFill = math.Clamp( guiltDays / 40, 0, 1 )
        local meterW    = math.floor( w * 0.6 )
        local meterX    = math.floor( cx - meterW * 0.5 )
        surface.SetDrawColor( 30, 30, 30, 220 )
        surface.DrawRect( meterX, y, meterW, meterBarH )
        if meterFill > 0 then
            surface.SetDrawColor( evilColor.r, evilColor.g, evilColor.b, 220 )
            surface.DrawRect( meterX, y, math.floor( meterW * meterFill ), meterBarH )
        end
        y = y + meterBarH + itemGap

        -- Effect string
        for i, line in ipairs( self.cachedLines ) do
            draw.SimpleText( line, "termhuntShopItemFont", cx, y + ( i - 1 ) * self.cachedLineH, GAMEMODE.shopStandards.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        end
    end
end

local function createGuiltCheckerSafely()
    local frame = vgui.Create( "DFrame" )
    terminator_Extras.easyClosePanel( frame )
    local w, h = glee_sizeScaled(
        FRAME_W_1080P * GAMEMODE.shopStandards.shpScale,
        FRAME_H_1080P * GAMEMODE.shopStandards.shpScale
    )
    frame:SetSize( w, h )
    frame:Center()
    frame:MakePopup()
    frame:SetSizable( true )
    guiltChecker:Create( frame )
    -- open sound pitched lower the guiltier you are
    local guiltDays = LocalPlayer():GetNWInt( "glee_persistentguilt_days", 0 )
    local pitch = math.Clamp( 200 - math.floor( guiltDays * 4 ), 80, 200 )
    LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, pitch, 0.45 )
    return frame
end

concommand.Add( "glee_guiltchecker_open", function()
    local newFrame = createGuiltCheckerSafely()
    if not IsValid( newFrame ) then return end

    if IsValid( GAMEMODE.glee_GuiltChecker_Holder ) then
        GAMEMODE.glee_GuiltChecker_Holder:Remove()
    end

    GAMEMODE.glee_GuiltChecker_Holder = newFrame
    function newFrame:OnRemove()
        if GAMEMODE.glee_GuiltChecker_Holder == self then
            GAMEMODE.glee_GuiltChecker_Holder = nil
        end
    end
end )

local width, height = glee_sizeScaled( FRAME_W_1080P, FRAME_H_1080P )
list.Set( "DesktopWindows", "HuntersGlee_GuiltChecker", {
    title = "Guilt",
    icon = "icon16/heart_delete.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        if IsValid( window ) then window:Remove() end
        RunConsoleCommand( "glee_guiltchecker_open" )
    end
} )