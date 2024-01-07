
local LocalPlayer = LocalPlayer
local CurTime = CurTime

function GM:IsObscured()
    return LocalPlayer():Health() > 0

end

local mysteryColor = Color( 250, 50, 50, 255 )
local nextShouldKnowCache = 0
local cachedShouldOverride
local cachedName
local cachedColor

hook.Add( "glee_killfeed_overridevictim", "glee_obfuscate_deaths", function()
    if nextShouldKnowCache > CurTime() then return cachedShouldOverride, cachedName, cachedColor end
    nextShouldKnowCache = CurTime() + 0.05

    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then cachedShouldOverride = nil return end

    local obscured = GAMEMODE:IsObscured()
    -- it is not obscured
    if not obscured then cachedShouldOverride = nil return end

    cachedShouldOverride = true
    cachedName = "?"
    cachedColor = mysteryColor
    return cachedShouldOverride, cachedName, cachedColor

end )