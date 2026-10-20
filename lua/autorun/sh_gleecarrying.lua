
AddCSLuaFile( "glee_carrying/sh_carrying.lua" )
AddCSLuaFile( "glee_carrying/cl_carrying.lua" )

include( "glee_carrying/sh_carrying.lua" )

if SERVER then
    include( "glee_carrying/sv_carrying.lua" )

else
    include( "glee_carrying/cl_carrying.lua" )

end
