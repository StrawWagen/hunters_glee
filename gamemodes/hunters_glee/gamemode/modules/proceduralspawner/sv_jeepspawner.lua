-- jeep jeep!

local jeepVar = CreateConVar( "huntersglee_randomlyspawn_jeeps", 1, FCVAR_ARCHIVE, "randomly spawn jeeps in big maps" )

local gm_goldencitySky = 531714625
local jeepsPerGoldencity = 8
local actualMaxJeeps = math.random( 1, 2 ) -- there were too many jeeps

local jeepSurfaceArea = gm_goldencitySky / jeepsPerGoldencity

local function preSpawnJeepFunc( jeep )
    local gunOn = 0
    if math.random( 0, 100 ) < 25 then
        gunOn = 1

    end
    jeep:SetModel( "models/buggy.mdl" ) -- this is the jeep model
    jeep:SetKeyValue( "EnableGun", gunOn )
    jeep:SetKeyValue( "vehiclescript", "scripts/vehicles/jeep_test.txt" )

    --print( "JEEP!" )

end

hook.Add( "glee_connectedgroups_end", "glee_spawnajeepifwewant", function()
    if not jeepVar:GetBool() then return end
    if GAMEMODE.navmeshUnderSkySurfaceArea < jeepSurfaceArea then return end

    local jeepsOnThisMap = GAMEMODE.navmeshUnderSkySurfaceArea / jeepSurfaceArea
    jeepsOnThisMap = math.min( jeepsOnThisMap, actualMaxJeeps )

    local jeepAreaSize = math.random( 350, 450 )

    GAMEMODE:RandomlySpawnEnt( "prop_vehicle_jeep_old", jeepsOnThisMap, 100, jeepAreaSize, 16000, preSpawnJeepFunc )

end )
