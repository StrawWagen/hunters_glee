
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
    if old == 0 and new > 0 then
        hook.Run( "glee_battery_onnotempty", ply )

    end

    batteryChargesLocal[ply] = new
    ply:SetNW2Float( "glee_precicebatterycharge", new )

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
local flashlightPowerUse = 100 / ( 60 * 6 ) -- depletes 100 suit in X minutes
local zoomPowerUse = 100 / ( 60 * 4 )

flashlightPowerUse = math.Round( flashlightPowerUse, 2 ) -- dont store all those decimals!
zoomPowerUse = math.Round( zoomPowerUse, 2 )

hook.Add( "glee_battery_think", "glee_flashlightdrain", function( ply, powerData )
    if ply:FlashlightIsOn() then
        powerData[1] = powerData[1] + -flashlightPowerUse

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


hook.Add( "glee_battery_onempty", "disableflashlight", function( ply )
    if not ply:FlashlightIsOn() then return end
    ply:Flashlight( false )

end )

hook.Add( "PlayerSwitchFlashlight", "glee_battery_flashlight", function( ply, enabled ) 
    if not ply:PlayerHasBatteryCharge() then
        ply:BatteryNag( 0.5 )
        return not enabled

    end
    -- check
    if ply:FlashlightIsOn() then return end
    ply:GivePlayerBatteryCharge( -( flashlightPowerUse / 2 ) )

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