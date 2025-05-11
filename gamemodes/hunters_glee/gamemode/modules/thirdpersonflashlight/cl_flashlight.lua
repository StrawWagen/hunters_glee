-- override flashlight drawing locally so it looks pretty

local LocalPlayer = LocalPlayer
local IsValid = IsValid
local flashlights = {}
local badFlashlights = {}
local ourFlashlight

local notInWorldHull = Vector( 10, 10, 10 )
local operationAngle = Angle( 0, 0, 0 )

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

    local attId = flashlight:GetParentAttachment()
    if attId <= 0 then return end

    local obsMode = me:GetObserverMode()
    if obsMode ~= OBS_MODE_NONE then return end -- third person?

    local attData = me:GetAttachment( attId )
    if not attData then return end -- ???

    local boxCWorld = me:WorldSpaceCenter()
    local theFlashlightPos = attData.Pos

    local negative = -WorldToLocal( theFlashlightPos, operationAngle, me:GetPos(), operationAngle ) -- this is a stupid hack

    local traceFromCToFlashPos = {
        start = boxCWorld,
        endpos = theFlashlightPos,
        mins = -notInWorldHull,
        maxs = notInWorldHull,
        filter = me,

    }

    local result = util.TraceHull( traceFromCToFlashPos )

    if result.Hit then
        theFlashlightPos = result.HitPos

    end
    flashlight:SetPos( theFlashlightPos + negative ) -- stupid stupid hack

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