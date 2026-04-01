
local killIconColor = Color( 255, 80, 0, 255 )
killicon.Add( "glee_escapeicon", "vgui/hud/glee_escapeicon", killIconColor )

if not Glide then return end

local isGlideAircraftBasedCache = {}

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

    if isGlideAircraftBasedCache[ourClass] == nil then
        local isBased = false
        local lastClass = ""
        local currentClass = vehicle:GetClass()
        while currentClass ~= lastClass do
            lastClass = currentClass
            currentClass = scripted_ents.GetMember( currentClass, "Base" )
            if currentClass == "base_glide_aircraft" then
                isBased = true
                break

            end
        end
        isGlideAircraftBasedCache[ourClass] = isBased

    end
    if isGlideAircraftBasedCache[ourClass] then
        local hint = "Fly into the skybox to ESCAPE!"
        local escapablePlyCount = potentialEscapersCount()
        if escapablePlyCount > 1 then
            hint = hint .. "\nThe more souls you bring with you... the better!"

        end
        return true, hint
    end
end )