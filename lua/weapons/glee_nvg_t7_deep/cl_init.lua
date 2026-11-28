include( "shared.lua" )

-- Anything alive nearby is added on top of the world, flat, through walls, before the T-7 makes its picture.
-- Walls never move, so they still cancel to black, only these moving shows. Held still, they vanish too.
-- The motion camera itself is glee_nvg_t7's cl_init.lua.

local silhouetteMat = CreateMaterial( "glee_nvg_t7_deep_silhouette", "UnlitGeneric", {
    ["$basetexture"] = "vgui/white",
    ["$model"] = 1,
    ["$ignorez"] = 1,
} )

local isAliveThing = terminator_Extras.glee_IsAliveThing

-- other addons' creatures draw themselves their own way, their model's often a stand-in, the evil crawler's is a popcan
-- so they're their collision box instead, the same as the haptic goggles see them
local function hasRealModel( ent )
    return ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()

end

local boxAngles = Angle( 0, 0, 0 )
local boxColor = Color( 255, 255, 255 )

-- ent, as bright as brightness, out of 1
local function drawSilhouette( ent, brightness )
    if hasRealModel( ent ) then
        render.MaterialOverride( silhouetteMat )
        render.SetColorModulation( brightness, brightness, brightness )
        ent:DrawModel()
        render.MaterialOverride()
        return

    end

    local level = brightness * 255
    boxColor:SetUnpacked( level, level, level, 255 )
    local mins, maxs = ent:GetCollisionBounds()
    render.SetColorMaterial()
    render.DrawBox( ent:GetPos(), boxAngles, mins, maxs, boxColor )

end

--[[---------------------------------------------------------
    SWEP:DrawGleeWorld
    @desc Adds everything alive within SWEP.Deep's range on top of the world, through walls, dimmer further out.
    Added, not drawn over, so what's behind one shifts by exactly its brightness, whatever's lit there.
    @param wearer: Who's seeing, never drawn.
    @return: None
--]]---------------------------------------------------------
function SWEP:DrawGleeWorld( wearer )
    local deep = self.Deep
    local motion = self.Motion
    local eyePos = wearer:EyePos()
    local range = deep.range
    local fadeLength = range - deep.fadeFrom

    render.SuppressEngineLighting( true )
    render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD )
    cam.IgnoreZ( true )

    for _, ent in ipairs( ents.FindInSphere( eyePos, range ) ) do
        if ent ~= wearer and not ent:IsDormant() and isAliveThing( ent ) then
            local fade = math.Clamp( ( range - eyePos:Distance( ent:GetPos() ) ) / fadeLength, 0, 1 )
            -- the motion camera drops threshold then multiplies by gain, this undoes that,
            -- so the glow it ends up as fades evenly to nothing at range
            drawSilhouette( ent, math.min( motion.threshold + fade / motion.gain, 1 ) )

        end
    end

    cam.IgnoreZ( false )
    render.OverrideBlend( false )
    render.SuppressEngineLighting( false )
    render.SetColorModulation( 1, 1, 1 )

end
