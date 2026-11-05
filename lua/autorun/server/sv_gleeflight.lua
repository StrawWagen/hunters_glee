
AddCSLuaFile( "glee_flight/rescueheli/cl_rescuehelispotlight.lua" )

include( "glee_flight/sv_flightnavigator.lua" )
include( "glee_flight/sv_skycorridor.lua" ) -- needs RayHitsTriggerPush from the navigator
include( "glee_flight/sv_flightheavies.lua" )

-- shared between flyers, after the navigator
include( "glee_flight/behaviours/sv_wander.lua" )

-- after sv_glee_vehicles, by name, the heli needs gleeVehicles
include( "glee_flight/rescueheli/sv_rescueheli.lua" )
include( "glee_flight/rescueheli/sv_rescuehelistanding.lua" )
include( "glee_flight/rescueheli/sv_rescuehelispawn.lua" )
include( "glee_flight/rescueheli/sv_rescuehelibrain.lua" )
include( "glee_flight/rescueheli/sv_rescuehelicall.lua" )

include( "glee_flight/gunship/sv_gunship.lua" )
include( "glee_flight/gunship/sv_gunshipstanding.lua" )
include( "glee_flight/gunship/sv_gunshiprage.lua" )
include( "glee_flight/gunship/sv_gunshipskycheck.lua" )
include( "glee_flight/gunship/sv_gunshiporbit.lua" )
include( "glee_flight/gunship/sv_gunshipmissiles.lua" )
include( "glee_flight/gunship/sv_gunshipbellycannon.lua" )
include( "glee_flight/gunship/sv_gunshipbrain.lua" )
include( "glee_flight/gunship/sv_gunshipspawn.lua" )
