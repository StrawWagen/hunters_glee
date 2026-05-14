
local desatAmount = 0
local satAmount = 0
local mulRAmount = 0

hook.Add( "RenderScreenspaceEffects", "glee_deaddesaturate", function()
    local me = LocalPlayer()
    if not IsValid( me ) then return end

    local targetDesat = 0
    local targetSat = 0
    local targetMulR = 0

    if me:HasEscaped() then
        targetDesat = 0
        targetSat = 0.5
        targetMulR = 0

    elseif me:Health() <= 0 then
        targetDesat = 0.15
        targetSat = 0
        targetMulR = 0.5

    else
        desatAmount = 0
        satAmount = 0
        mulRAmount = 0

    end

    if targetDesat == 0 and targetSat == 0 and targetMulR == 0 then return end

    if desatAmount ~= targetDesat then
        desatAmount = math.Approach( desatAmount, targetDesat, RealFrameTime() * 0.5 )

    end

    if satAmount ~= targetSat then
        satAmount = math.Approach( satAmount, targetSat, RealFrameTime() * 0.5 )

    end

    if mulRAmount ~= targetMulR then
        mulRAmount = math.Approach( mulRAmount, targetMulR, RealFrameTime() * 0.5 )

    end

    DrawColorModify( {
        ["$pp_colour_addr"]       = 0,
        ["$pp_colour_addg"]       = 0,
        ["$pp_colour_addb"]       = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"]   = 1,
        ["$pp_colour_colour"]     = 1 - desatAmount + satAmount,
        ["$pp_colour_mulr"]       = mulRAmount,
        ["$pp_colour_mulg"]       = 0,
        ["$pp_colour_mulb"]       = 0,
    } )

end )
