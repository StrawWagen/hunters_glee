
local killIconColor = Color( 255, 80, 0, 255 )
killicon.Add( "glee_escapeicon", "vgui/hud/glee_escapeicon", killIconColor )

if not Glide then return end

local glideBasedCache = {}
local validBases = {
    ["base_glide_aircraft"] = true,
    ["base_glide_boat"] = true,
}

local function potentialEscapersCount()
    local escapablePlyCount = 0
    for _, ply in player.Iterator() do
        if ply:Alive() and ply:GetNWInt( "glee_spectateteam", 0 ) == GAMEMODE.TEAM_PLAYING then
            escapablePlyCount = escapablePlyCount + 1

        end
    end

    return escapablePlyCount

end

hook.Add( "huntersglee_cl_displayhint_poststack", "glee_escapeglidevehiclehint", function( me )
    local roundState = GAMEMODE:RoundState()
    if roundState ~= GAMEMODE.ROUND_ACTIVE then return end

    local vehicle = me:GetVehicle()
    if not IsValid( vehicle ) then return end

    local vehiclesParent = vehicle:GetParent()
    if IsValid( vehiclesParent ) and vehiclesParent:IsVehicle() then
        vehicle = vehiclesParent

    end

    local ourClass = vehicle:GetClass()

    if glideBasedCache[ourClass] == nil then
        local basedClass = false
        local lastClass = ""
        local currentClass = vehicle:GetClass()
        while currentClass ~= lastClass do
            lastClass = currentClass
            currentClass = scripted_ents.GetMember( currentClass, "Base" )
            if validBases[currentClass] then
                basedClass = currentClass
                break

            end
        end
        glideBasedCache[ourClass] = basedClass

    end
    local basedClass = glideBasedCache[ourClass]
    if basedClass then
        local hint
        if basedClass == "base_glide_boat" then
            hint = "Sail into the skybox to ESCAPE!"

        else
            hint = "Fly into the skybox to ESCAPE!"

        end
        local escapablePlyCount = potentialEscapersCount()
        if escapablePlyCount > 1 then
            hint = hint .. "\nThe more souls you bring with you... the better!"

        end
        return true, hint

    end
end )