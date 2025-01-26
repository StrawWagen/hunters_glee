
resource.AddFile( "materials/vgui/hud/losingcharge.png" )
resource.AddFile( "materials/vgui/hud/nobattery.png" )

util.AddNetworkString( "glee_batterychangedcharge" )

local batteryChargesLocal = {}

local function doBatteryNag( ply, length )
    net.Start( "glee_batterychangedcharge" )
        net.WriteFloat( CurTime() + length )

    net.Send( ply )

end

local function updateBatteryInternal( ply, new )
    local old = batteryChargesLocal[ply] or 0

    batteryChargesLocal[ply] = new
    ply:SetNW2Float( "glee_precicebatterycharge", new )

    if old == 0 and new > 0 then
        hook.Run( "glee_battery_onnotempty", ply )

    end
end

local function armorFollowBatteryInternal( ply )
    local newCharge = batteryChargesLocal[ply]
    if ply:Armor() == math.ceil( newCharge ) then return end

    ply:SetArmor( math.ceil( newCharge ) )

end

local function batteryFollowArmorInternal( ply )
    local oldBattery = batteryChargesLocal[ply] or 0

    if ply:Armor() == math.ceil( oldBattery ) then return end
    local new = ply:Armor()
    updateBatteryInternal( ply, new )

    return new

end


local plyMeta = FindMetaTable( "Player" )

function plyMeta:SetBatteryCharge( newBattery )
    updateBatteryInternal( self, newBattery )
    armorFollowBatteryInternal( self )

end

function plyMeta:BatteryNag( time )
    doBatteryNag( self, time )

end

function plyMeta:GivePlayerBatteryCharge( add )
    if hook.Run( "huntersglee_givebattery", self, add ) == false then return end

    local newCharge = batteryFollowArmorInternal( self )

    if add == 0 then return newCharge end
    local old = batteryChargesLocal[self] or 0
    local new = old + add
    new = math.Clamp( new, 0, self:Armor() )

    updateBatteryInternal( self, new )
    armorFollowBatteryInternal( self, new )

    if new < old then
        self:BatteryNag( 1.1 )

    end

    return new

end


local nextPowerUse = 0
local flashlightPowerUse = 100 / ( 60 * 5 ) -- depletes 100 suit in X minutes
local zoomPowerUse = 100 / ( 60 * 4 )

flashlightPowerUse = math.Round( flashlightPowerUse, 2 ) -- dont store all those decimals!
zoomPowerUse = math.Round( zoomPowerUse, 2 )

hook.Add( "glee_battery_think", "glee_flashlightdrain", function( ply, powerData )
    if ply:Glee_FlashlightIsOn() then
        local currUse = flashlightPowerUse
        local returnedPowerUse = hook.Run( "glee_flashlight_poweruse", ply, currUse )
        if returnedPowerUse then
            currUse = returnedPowerUse

        end
        powerData[1] = powerData[1] + -currUse

    end
end )

hook.Add( "glee_battery_think", "glee_zoomdrain", function( ply, powerData )
    if ply:KeyDown( IN_ZOOM ) and ply:GetCanZoom() then
        powerData[1] = powerData[1] + -zoomPowerUse

    end
end )

hook.Add( "glee_sv_validgmthink", "glee_depletebatteries", function( players, _, cur )
    if nextPowerUse > cur then return end
    nextPowerUse = cur + 1

    local alivePlayers = GAMEMODE:returnAliveInTable( players )

    for _, ply in ipairs( alivePlayers ) do
        local powerDataTable = { 0 }
        hook.Run( "glee_battery_think", ply, powerDataTable )

        local newBattery = ply:GivePlayerBatteryCharge( powerDataTable[1] )
        if not newBattery then continue end
        if newBattery <= 0 then
            hook.Run( "glee_battery_onempty", ply )

        end
    end
end )

local function checkFlashlightBrightness( ply )
    local oldBright = ply.glee_FlashlightBrightness or 255
    if ply:GetBatteryCharge() <= 0 then
        if oldBright >= 35 then
            ply:EmitSound( "buttons/lightswitch2.wav", 60, 120, 0.4 )

        end
        ply:SetFlashlightBrightness( 20 + math.random( -15, 5 ) )
        timer.Simple( math.Rand( 0.05, 0.25 ), function()
            if not IsValid( ply ) then return end
            ply:SetFlashlightBrightness( 20 + math.random( -2, 2 ) )

        end )
    else
        if oldBright == 255 then return end
        ply:SetFlashlightBrightness( 255 )
        ply:EmitSound( "buttons/lightswitch2.wav", 60, 150, 0.4 )

    end
end

hook.Add( "glee_battery_onempty", "disableflashlight", checkFlashlightBrightness )

hook.Add( "glee_battery_onnotempty", "fixflashlight", checkFlashlightBrightness )

hook.Add( "glee_PlayerSwitchFlashlight", "glee_battery_flashlight", function( ply, enabling )
    local charged = ply:PlayerHasBatteryCharge()
    if not charged and enabling then
        ply:BatteryNag( 0.5 )

    elseif charged then
        -- check
        checkFlashlightBrightness( ply )
        if ply:Glee_FlashlightIsOn() then return end
        local currUse = flashlightPowerUse
        local returnedPowerUse = hook.Run( "glee_flashlight_poweruse", ply, currUse )
        if returnedPowerUse then
            currUse = returnedPowerUse

        end
        ply:GivePlayerBatteryCharge( -( currUse / 2 ) )

    end
end )

hook.Add( "glee_battery_onempty", "disablezoom", function( ply )
    ply:StopZooming()
    ply:SetCanZoom( false )

end )

hook.Add( "glee_battery_onnotempty", "disablezoom", function( ply )
    ply:SetCanZoom( true )

end )


hook.Add( "KeyPress", "glee_zoomcost", function( ply, key )
    if key ~= IN_ZOOM then return end
    if not ply:PlayerHasBatteryCharge() then
        ply:BatteryNag( 0.5 )
        return

    end
    ply:GivePlayerBatteryCharge( -( zoomPowerUse / 2 ) )

end )


local minCharge = 40

hook.Add( "huntersglee_round_into_inactive", "glee_chargeplayersbatteries", function()
    local alivePlayers = GAMEMODE:getAlivePlayers()
    for _, ply in ipairs( alivePlayers ) do
        if ply:GetBatteryCharge() >= minCharge then continue end
        ply:SetBatteryCharge( minCharge )

    end
end )

hook.Add( "PlayerSpawn", "glee_chargeplayersbatteries", function( spawned )
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE then return end
    timer.Simple( 0, function()
        if not IsValid( spawned ) then return end
        spawned:SetBatteryCharge( minCharge )

    end )
end )