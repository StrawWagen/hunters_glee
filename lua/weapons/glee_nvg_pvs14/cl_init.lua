include( "shared.lua" )

DEFINE_BASECLASS( "glee_nvg_base" )

--[[------------------------------------
    The haptic goggles' radar. All clientside, only the wearer sees it.

    Each file is read top to bottom, in the order they're included:
    cl_rays.lua, where one ray fired from the eyes ends up
    cl_sweep.lua, the cone's shape, the sweep across it, and the contacts it finds
    cl_overlay.lua, drawing it all over the wearer's view

    SetupWear, below, runs them while the goggles are worn.
--]]-------------------------------------

-- what the files hand each other, filled as they're included
SWEP.Haptic = {}

include( "cl_rays.lua" )
include( "cl_sweep.lua" )
include( "cl_overlay.lua" )

local haptic = SWEP.Haptic


-- Putting them on ------------------------------------------------------------

function SWEP.SetupWear( wear )
    BaseClass.SetupWear( wear )

    local wearer = wear.wearer

    wear:OnRemove( haptic.clearRadar )

    wear:Hook( "Think", function( wep )
        haptic.radarThink( wep, wearer )

    end )

    -- slides in and out with the goggles as they're flipped, see GleeFlipOffset in glee_nvg_base
    local flipShift = Matrix()
    local flipShiftPos = Vector( 0, 0, 0 )
    wear:Hook( "HUDPaint", function( wep )
        flipShiftPos.y = wep:GleeFlipOffset()
        flipShift:SetTranslation( flipShiftPos )
        cam.PushModelMatrix( flipShift )
            haptic.drawOverlay( wep, wearer )
        cam.PopModelMatrix()

    end )
end
