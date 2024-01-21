-- override flashlight drawing locally so it looks pretty

local LocalPlayer = LocalPlayer
local IsValid = IsValid
local flashlights = {}
local badFlashlights = {}
local ourFlashlight

local dist = 75
local notInWorldHull = Vector( 20, 20, 20 )

local function manageFlashlight( flashlight, me )
    if not IsValid( flashlight ) then return end
    local notOurs = badFlashlights[flashlight]
    if notOurs then return true end
    local parent = flashlight:GetParent()
    if flashlight ~= ourFlashlight then
        if not IsValid( parent ) then return true end
        if parent == me then
            ourFlashlight = flashlight

        else
            badFlashlights[flashlight] = true
            return true

        end
    end

    local attData = parent:GetAttachment( flashlight:GetParentAttachment() )
    local theFlashlightPos = attData.Pos
    local shoot = me:GetShootPos()

    local negative = -parent:WorldToLocal( theFlashlightPos ) -- this is a stupid hack

    local traceFromShootToPos = {
        start = shoot,
        endpos = theFlashlightPos,
        mins = -notInWorldHull,
        maxs = notInWorldHull,
        filter = me,

    }

    local res = util.TraceHull( traceFromShootToPos )
    if res.StartSolid then
        theFlashlightPos = shoot

    elseif res.Hit then
        theFlashlightPos = res.HitPos

    end

    local checkDir = attData.Ang:Forward()
    local trForwardStruc = {
        start = theFlashlightPos,
        endpos = theFlashlightPos + checkDir * dist,
        mins = -notInWorldHull / 2,
        maxs = notInWorldHull / 2,
        filter = me,

    }

    local tooCloseToWallsTr = util.TraceHull( trForwardStruc )

    if tooCloseToWallsTr.Hit then
        local traceDist = ( tooCloseToWallsTr.Fraction * dist ) - dist
        if tooCloseToWallsTr.StartSolid then
            traceDist = -dist

        end
        local offset = checkDir * traceDist
        theFlashlightPos = theFlashlightPos + offset

    end

    flashlight:SetPos( theFlashlightPos + negative )

    return true

end


hook.Add( "OnEntityCreated", "glee_capture_thirdpersonflashlights", function( ent )
    if not ent then return end
    local entsClass = ent:GetClass()
    if entsClass ~= "class C_EnvProjectedTexture" then return end

    table.insert( flashlights, ent )
    manageFlashlight( ent, LocalPlayer() )

end )

hook.Add( "Think", "glee_ManageFlashlights", function()
    local me = LocalPlayer()
    for currIndex, flashlight in ipairs( flashlights ) do
        if not manageFlashlight( flashlight, me ) then table.remove( flashlights, currIndex ) end

    end
end )