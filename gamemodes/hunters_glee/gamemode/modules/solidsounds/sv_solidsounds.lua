
util.AddNetworkString( "glee_sendsolidsound" )

local DEFAULT_FADE_IN  = 0
local DEFAULT_FADE_OUT = 0.5

function GM:SendSolidSound( path, data )
    data = data or {}
    data.pitch         = data.pitch or 100
    data.vol           = data.vol or 1
    data.dsp           = data.dsp or 0
    data.fadeInLength  = data.fadeInLength or DEFAULT_FADE_IN
    data.fadeOutLength = data.fadeOutLength or DEFAULT_FADE_OUT
    net.Start( "glee_sendsolidsound" )
        net.WriteString( path )
        net.WriteFloat( data.pitch )
        net.WriteFloat( data.vol )
        net.WriteFloat( data.dsp )
        net.WriteFloat( data.fadeInLength )
        net.WriteFloat( data.fadeOutLength )
    net.Broadcast()

end