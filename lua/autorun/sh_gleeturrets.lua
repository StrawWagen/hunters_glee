
AddCSLuaFile( "glee_turrets/sh_turrets.lua" )
AddCSLuaFile( "glee_turrets/cl_turrets.lua" )

-- after sh_gleecarrying, by name, sh_turrets needs its PickUpAction
include( "glee_turrets/sh_turrets.lua" )

if SERVER then
    include( "glee_turrets/sv_turrets.lua" )

else
    include( "glee_turrets/cl_turrets.lua" )

end
