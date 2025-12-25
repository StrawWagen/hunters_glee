AddCSLuaFile()

if SERVER then return end

if engine.ActiveGamemode() != "hunters_glee" then return end

local snowEnabled = CreateClientConVar( "snowflakes_enabled", "1", true, false )
local emitter = ParticleEmitter( Vector(), false )
local spawned = false

local windSounds = {
    "ambient/wind/wind_gust_10.wav",
    "ambient/wind/smallgust2.wav",
    "ambient/wind/wind_gust_2.wav",
    "ambient/wind/wind_snippet5.wav",
    "ambient/wind/wind_snippet4.wav"
}

// change grass to snow
local matWhitelist = {
    ["grass"] = true,
    ["dirt"] = true,
    ["paper"] = true,
    ["antlionsand"] = true
}

hook.Add( "InitPostEntity", "snow_initialize", function()
    for k, v in ipairs( game.GetWorld():GetBrushSurfaces() ) do
        local mat = string.lower( v:GetMaterial():GetString( "$surfaceprop" ) or "" )
        
        if matWhitelist[mat] then
            v:GetMaterial():SetTexture( "$basetexture", "nature/snowfloor002a" )
            v:GetMaterial():SetTexture( "$basetexture2", "nature/snowfloor002a" )
            v:GetMaterial():SetVector( "$color2", Vector( 0.55, 0.55, 0.55 ) ) // snow is kinda bright, tone it down a bit.
        end
    end

    Material( "infmap/flatgrass" ):SetTexture( "$basetexture", "nature/snowfloor002a" )
    Material( "infmap/flatgrass" ):SetVector( "$color2", Vector( 0.5, 0.5, 0.5 ) )
    
    spawned = true
end )

hook.Add( "Think", "snow_spawn", function()
    if !snowEnabled or !snowEnabled:GetBool() then return end
    if !util.IsSkyboxVisibleFromPoint( EyePos() ) then return end
    if !spawned then return end

    if math.random( 1, 500 ) == 1 then
        local sound = table.Random( windSounds )
        surface.PlaySound( sound )
    end

    for i = 1, 10 do
        local startPos = EyePos() + Vector( math.Rand( -3000, 3000 ), math.Rand( -3000, 3000 ), math.Rand( 1000, 2000 ) )
        local particle = emitter:Add( "particle/snow", startPos )
        
        if particle then
            local tr = util.QuickTrace( startPos, Vector( 0, 0, -2000 ) ).HitPos
            local dieTime = ( startPos[3] - tr[3] ) * 0.0035 // weird conversion
            particle:SetDieTime( math.min( dieTime, 10 ) )
            
            particle:SetStartAlpha( 255 )
            particle:SetEndAlpha( 255 )
            particle:SetAirResistance( 120 )

            local flakeSize = math.Rand( 2, 4 )
            particle:SetStartSize( flakeSize )
            particle:SetEndSize( flakeSize )

            particle:SetGravity( Vector( 0, 0, -600 ) )
            particle:SetVelocity( Vector( 0, 0, -600 ) )
            particle:SetNextThink( CurTime() )
            particle:SetRoll( math.Rand( 0, 360 ) )
            particle:SetRollDelta( math.Rand( -0.5, 0.5 ) )
        end
    end
end )

local function calcFog( mult )
    render.FogStart( 0 )
    render.FogMaxDensity( 0.80 ) // magic numbers that look good
    render.FogColor( 245, 248, 252 )
    render.FogEnd( 4500 * ( mult or 1 ) )
    render.FogMode( MATERIAL_FOG_LINEAR )
    
    return true
end

hook.Add( "SetupWorldFog", "snow_fog", calcFog )

hook.Add( "SetupSkyboxFog", "snow_fog", calcFog )
