-- the lamp a flashlight is held as, and dropped as

GM.FlashlightLampModel = "models/maxofs2d/lamp_flashlight.mdl"
GM.FlashlightLampScale = 0.5
GM.FlashlightLampLensOffset = 8.5 * GM.FlashlightLampScale -- the lamp stool's LampModels offset for this model

-- where a player's light waits while nothing's placing it, below any map, pointed further down at nothing
-- it spawns there too, so the frame before cl_flashlight first places it lights nothing
GM.FlashlightHiddenPos = Vector( 0, 0, -32000 )
GM.FlashlightHiddenAng = Angle( 90, 0, 0 )
