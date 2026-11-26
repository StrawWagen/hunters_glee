AddCSLuaFile( "glee_actions/sh_actions.lua" )
AddCSLuaFile( "glee_actions/cl_actions.lua" )

-- before sh_gleecarrying, by name, carrying's use is one of its reaches
include( "glee_actions/sh_actions.lua" )

if SERVER then
    include( "glee_actions/sv_actions.lua" )

else
    include( "glee_actions/cl_actions.lua" )

end
