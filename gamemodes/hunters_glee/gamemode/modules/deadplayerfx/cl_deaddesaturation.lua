
local maxDesat = 0.5 -- How greyscale the screen gets at peak (0 = no effect, 1 = fully greyscale)
local maxSaturate = 0.5 -- How much the screen saturates when escaped (0 = no effect, 1 = fully saturated)

local desatAmount = 0
local satAmount = 0

hook.Add( "RenderScreenspaceEffects", "glee_deaddesaturate", function()
    local me = LocalPlayer()
    if not IsValid( me ) then return end

    if me:HasEscaped() then
        if satAmount < maxSaturate then
            satAmount = math.Approach( satAmount, maxSaturate, RealFrameTime() * 0.5 )

        end
    elseif me:Health() <= 0 then
        if desatAmount < maxDesat then
            desatAmount = math.Approach( desatAmount, maxDesat, RealFrameTime() * 0.5 )

        end
    else
        desatAmount = 0
        satAmount = 0

    end

    if desatAmount <= 0 and satAmount <= 0 then return end

    DrawColorModify( {
        ["$pp_colour_addr"]       = 0,
        ["$pp_colour_addg"]       = 0,
        ["$pp_colour_addb"]       = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"]   = 1,
        ["$pp_colour_colour"]     = 1 - desatAmount + satAmount,
        ["$pp_colour_mulr"]       = 0,
        ["$pp_colour_mulg"]       = 0,
        ["$pp_colour_mulb"]       = 0,
    } )

end )
