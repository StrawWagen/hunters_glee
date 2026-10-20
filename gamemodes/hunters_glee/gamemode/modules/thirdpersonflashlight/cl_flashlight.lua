-- places every player's flashlight each frame, at a gun's muzzle, a held lamp, or their body
-- the server only creates the light, see sv_flashlight. also draws the lamp and its glow

local LocalPlayer = LocalPlayer
local IsValid = IsValid
local flashlights = {}
local notPlayerFlashlights = setmetatable( {}, { __mode = "k" } )
local flashlitPlayers = {}

local notInWorldHull = Vector( 10, 10, 10 )
local hiddenLightPos = Vector( 0, 0, -32000 ) -- below any map, pointed further down at nothing
local hiddenLightAng = Angle( 90, 0, 0 )
local ownLightUpdated = false
local ownLightColor = Color( 255, 255, 255 )

local belowMuzzle = 1.75
local bodyLightForward = 8

local lampLensOffset = GM.FlashlightLampLensOffset
local lampHandInward = 1.5
local lampYawInward = 22
local lampTauntAngOffset = Angle( 0, 0, 0 ) -- from the hand attachment's angles to the lamp's, while taunting
local lampEnt

local glowMat = Material( "sprites/light_glow02_add" )
local glowSize = 24
local glowMinSizeStrength = 0.4
local glowColor = Color( 255, 255, 255, 255 )

local attachmentIdCache = {}

-- these sweps usually never draw their WorldModel, so its muzzle floats wherever the undrawn model left it
local emptyHandedHoldTypes = {
    none = true,
    normal = true,
}

-- "normal" holdtype activities, to the one handed pistol pose that holds the lamp out
local lampHoldActivities = {}
for offset = 0, 9 do
    lampHoldActivities[ACT_HL2MP_IDLE + offset] = ACT_HL2MP_IDLE_PISTOL + offset

end
lampHoldActivities[ACT_HL2MP_JUMP_SLAM] = ACT_HL2MP_IDLE_PISTOL + 7

local function getAttachment( ent, name )
    local mdl = ent:GetModel()
    if not mdl then return end

    local modelsIds = attachmentIdCache[mdl]
    if not modelsIds then
        modelsIds = {}
        attachmentIdCache[mdl] = modelsIds

    end

    local id = modelsIds[name]
    if not id then
        id = ent:LookupAttachment( name )
        -- a model that hasn't loaded yet has no bones, and finds no attachments either
        if id > 0 or ent:GetBoneCount() > 0 then
            modelsIds[name] = id

        end
    end
    if id <= 0 then return end

    return ent:GetAttachment( id )

end

local function getAttachmentPos( ent, name )
    local attData = getAttachment( ent, name )
    if not attData then return end

    return attData.Pos

end

-- weapon models that shine from somewhere of their own, in their root bone's space
-- pos is offset from the top front middle of their bounds, ang turns the root bone's forward down the barrel
local lightSourceModels = {
    ["models/maxofs2d/camera.mdl"] = { pos = Vector( 3, -5, -12 ), ang = Angle( 0, 0, 0 ) }, -- the flash, above the lens
    ["models/weapons/taummod/w_gauss.mdl"] = { pos = Vector( -12, 5, -15 ), ang = Angle( 0, 0, 0 ) }, -- termhunt_taucannon, on top of the body, behind the prongs
    ["models/weapons/w_rocket_launcher.mdl"] = { pos = Vector( -30, 4, -26 ), ang = Angle( 0, 0, 0 ) }, -- termhunt_taucannon, on top of the body, behind the prongs
}
local lowerModelNames = {}

-- pos and ang of ent's entry in lightSourceModels, nil if it has none
local function getModelLightSource( ent )
    local mdl = ent:GetModel()
    if not mdl then return end

    local lowerMdl = lowerModelNames[mdl]
    if not lowerMdl then
        lowerMdl = string.lower( mdl )
        lowerModelNames[mdl] = lowerMdl

    end

    local lightSource = lightSourceModels[lowerMdl]
    if not lightSource then return end

    -- a held weapon is bonemerged, its root bone is where its model actually draws
    local rootMatrix = ent:GetBoneMatrix( 0 )
    if not rootMatrix then return end

    local mins, maxs = ent:GetModelBounds()
    local topFront = Vector( maxs.x, ( mins.y + maxs.y ) / 2, maxs.z )

    return LocalToWorld( topFront + lightSource.pos, lightSource.ang, rootMatrix:GetTranslation(), rootMatrix:GetAngles() )

end

-- weapons made to carry a flashlight put this attachment where it goes, trusted over everything else
local flashlightMountName = "gmod_flashlight"

-- "1" is the CS:S style muzzle, eg the annabelle's
local muzzleNames = { "muzzle", "muzzle_flash", "1" }

-- most muzzle attachments' forward runs down the barrel, below this dot with the root->muzzle line, it doesn't
local minBarrelAlignment = math.cos( math.rad( 45 ) )
local offBarrelMuzzles = {} -- model -> true when its muzzle's forward is off the barrel

local function getRootToMuzzle( ent, muzzlePos )
    local rootMatrix = ent:GetBoneMatrix( 0 )
    if not rootMatrix then return end

    local rootToMuzzle = muzzlePos - rootMatrix:GetTranslation()
    if rootToMuzzle:LengthSqr() < 1 then return end -- muzzle on the root, nothing to measure against
    rootToMuzzle:Normalize()

    return rootToMuzzle

end

-- some models' muzzle attachments point 90 or 180 degrees off the barrel, likely mirrored, so their angles can't be trusted at all
-- the root bone and muzzle are both points fixed to the gun though, so the line between them follows the barrel in any pose
local function isOffBarrel( ent, muzzlePos, muzzleAng )
    local mdl = ent:GetModel()
    local cached = offBarrelMuzzles[mdl]
    if cached ~= nil then return cached end

    local rootToMuzzle = getRootToMuzzle( ent, muzzlePos )
    if not rootToMuzzle then return false end

    local offBarrel = rootToMuzzle:Dot( muzzleAng:Forward() ) < minBarrelAlignment
    offBarrelMuzzles[mdl] = offBarrel
    return offBarrel

end

-- the muzzle's pos, and angles pointing down the barrel
local function getMuzzle( ent )
    for _, name in ipairs( muzzleNames ) do
        local attData = getAttachment( ent, name )
        if attData then
            local muzzlePos, muzzleAng = attData.Pos, attData.Ang
            if not isOffBarrel( ent, muzzlePos, muzzleAng ) then return muzzlePos, muzzleAng end

            local rootToMuzzle = getRootToMuzzle( ent, muzzlePos )
            if not rootToMuzzle then return muzzlePos, muzzleAng end

            return muzzlePos, rootToMuzzle:Angle()

        end
    end
end

local function isEmptyHanded( ply )
    local wep = ply:GetActiveWeapon()
    return not IsValid( wep ) or emptyHandedHoldTypes[wep:GetHoldType()]

end

-- while taunting, eye angles follow the orbiting taunt camera, so aim off the body instead
local function getTauntAimAng( ply )
    local eyes = getAttachment( ply, "eyes" )
    if eyes then return eyes.Ang end

    return ply:GetRenderAngles()

end

local handLedBlendTime = 0.25

-- 0 is held out along the aim, 1 follows the hand, eases between them over handLedBlendTime
-- advances once a frame, this gets asked a few times per frame per player
local function getHandLedBlend( ply, handLed )
    local frame = FrameNumber()
    local blend = ply.glee_LampHandLedBlend or 0
    if ply.glee_LampHandLedBlendFrame == frame then return blend end
    ply.glee_LampHandLedBlendFrame = frame

    local step = FrameTime() / handLedBlendTime
    if handLed then
        blend = math.min( blend + step, 1 )

    else
        blend = math.max( blend - step, 0 )

    end
    ply.glee_LampHandLedBlend = blend
    return blend

end

-- seeing through our own eyes, with a viewmodel
local function isInOwnFirstPerson( ply )
    return ply == LocalPlayer() and not ply:IsPlayingTaunt2() and not ply:ShouldDrawLocalPlayer() and ply:GetObserverMode() == OBS_MODE_NONE

end

-- returns where the beam starts and which way it points
-- then where and how to draw the lamp, only when there's no weapon muzzle to shine from
local function getFlashlightOrigin( ply, eyeAng )
    local taunting = ply:IsPlayingTaunt2()
    if taunting then
        eyeAng = getTauntAimAng( ply )

    end

    local emptyHanded = isEmptyHanded( ply )
    if not emptyHanded then
        local muzzlePos, muzzleAng
        -- the world model's muzzle sits somewhere else entirely from the gun you see in first person
        if isInOwnFirstPerson( ply ) then
            local viewModel = ply:GetViewModel()
            if IsValid( viewModel ) then
                local mounted = getAttachment( viewModel, flashlightMountName )
                if mounted then
                    muzzlePos, muzzleAng = mounted.Pos, mounted.Ang

                else
                    muzzlePos, muzzleAng = getMuzzle( viewModel )
                    if muzzlePos then
                        muzzlePos = muzzlePos - muzzleAng:Up() * belowMuzzle

                    end
                end

                if muzzlePos then
                    -- the viewmodel only moves to this frame's view after PreRender, so carry it there ourselves
                    local localPos, localAng = WorldToLocal( muzzlePos, muzzleAng, viewModel:GetPos(), viewModel:GetAngles() )
                    return LocalToWorld( localPos, localAng, ply:EyePos(), ply:EyeAngles() )

                end
            end
        end

        local wep = ply:GetActiveWeapon()
        if not muzzlePos then
            local mounted = getAttachment( wep, flashlightMountName )
            if mounted then return mounted.Pos, mounted.Ang end

            muzzlePos, muzzleAng = getModelLightSource( wep )

        end
        if not muzzlePos then
            muzzlePos, muzzleAng = getMuzzle( wep )

        end
        if muzzlePos then
            -- along the gun, wherever sprinting or dancing swings it
            return muzzlePos - muzzleAng:Up() * belowMuzzle, muzzleAng

        end
    end

    -- empty hands hold the lamp out in the right, otherwise the right is busy with the weapon
    local rightHand = getAttachment( ply, "anim_attachment_RH" )
    local leftHand = getAttachment( ply, "anim_attachment_LH" )
    local hand
    local handSide -- 1 for the right hand, -1 for the left
    if rightHand and ( emptyHanded or not leftHand ) then
        hand = rightHand
        handSide = 1

    else
        hand = leftHand
        handSide = -1

    end
    if hand then
        -- full speed running flails the arms like a dance does, eg the shove's sprint
        local handLed = taunting or ply:GetSequenceActivity( ply:GetSequence() ) == ACT_HL2MP_RUN_FAST
        local handLedBlend = getHandLedBlend( ply, handLed )

        local heldPos, heldAng
        if handLedBlend < 1 then
            heldPos = hand.Pos - eyeAng:Right() * lampHandInward * handSide
            heldAng = Angle( eyeAng.p, eyeAng.y, eyeAng.r )
            heldAng:RotateAroundAxis( eyeAng:Up(), lampYawInward * handSide )

        end

        local lampPos, lampAng, beamAng
        if handLedBlend > 0 then
            -- the lamp goes wherever the dance throws the hand
            local _, flungAng = LocalToWorld( vector_origin, lampTauntAngOffset, vector_origin, hand.Ang )
            if heldPos then
                lampPos = LerpVector( handLedBlend, heldPos, hand.Pos )
                lampAng = LerpAngle( handLedBlend, heldAng, flungAng )
                beamAng = LerpAngle( handLedBlend, eyeAng, flungAng )

            else
                lampPos = hand.Pos
                lampAng = flungAng
                beamAng = flungAng

            end
        else
            lampPos = heldPos
            lampAng = heldAng
            beamAng = eyeAng -- the lamp's inward turn would drag the beam off the crosshair

        end

        return lampPos + lampAng:Forward() * lampLensOffset, beamAng, lampPos, lampAng

    end

    local bodyPos = getAttachmentPos( ply, "chest" ) or getAttachmentPos( ply, "eyes" )
    if bodyPos then
        return bodyPos + eyeAng:Forward() * bodyLightForward, eyeAng

    end

    return ply:WorldSpaceCenter() + eyeAng:Up() * ( ply:OBBMaxs().z * 0.3 ) + eyeAng:Forward() * bodyLightForward, eyeAng

end

-- the owner of one of our tracked player lights, nil for anything else
local function getLightsOwner( flashlight )
    if not IsValid( flashlight ) then return end
    if notPlayerFlashlights[flashlight] then return end
    if IsValid( flashlight:GetParent() ) then return end

    local ply = flashlight:GetOwner()
    if not IsValid( ply ) or not ply:IsPlayer() then return end

    return ply

end

-- lights aren't parented, so they don't go dormant with their owner, and would hang wherever we last put them
-- and in our own first person, a clientside copy shines instead, see updateOwnFirstPersonLight
local function shouldHideLight( ply )
    return ply:IsDormant() or isInOwnFirstPerson( ply )

end

-- every frame, setting it once doesn't hold, the networked pos comes back
-- in Think, the engine reads lights before PreRender
hook.Add( "Think", "glee_HideFlashlights", function()
    for _, flashlight in ipairs( flashlights ) do
        local ply = getLightsOwner( flashlight )
        if ply and shouldHideLight( ply ) then
            flashlight:SetPos( hiddenLightPos )
            flashlight:SetAngles( hiddenLightAng )

        end
    end
end )

-- the engine reads the server's light before PreRender, but our view only settles right before rendering
-- so in first person, any server light trails or jitters behind the view, this copy is updated the same frame instead
-- kept on the player, so an autorefresh doesn't orphan it, lit forever
local function updateOwnFirstPersonLight( ply, origin, beamAng )
    local ownLight = ply.glee_OwnFirstPersonLight
    if not IsValid( ownLight ) then
        ownLight = ProjectedTexture()
        ownLight:SetTexture( "effects/flashlight001" )
        ownLight:SetEnableShadows( true )
        ownLight:SetNearZ( 10 ) -- sv_flashlight's nearz
        ply.glee_OwnFirstPersonLight = ownLight

    end

    local color = ply:GetNW2Vector( "glee_flashlightcolor", vector_origin )
    ownLightColor.r = color.x
    ownLightColor.g = color.y
    ownLightColor.b = color.z
    ownLight:SetColor( ownLightColor )
    ownLight:SetBrightness( ply:GetNW2Float( "glee_flashlightbrightness", 1 ) )
    ownLight:SetFarZ( ply:GetNW2Float( "glee_flashlightfarz", 635 ) )
    ownLight:SetFOV( ply:GetNW2Float( "glee_flashlightfov", 85 ) )
    ownLight:SetPos( origin )
    ownLight:SetAngles( beamAng )
    ownLight:Update()

end

local function removeOwnFirstPersonLight( ply )
    local ownLight = ply.glee_OwnFirstPersonLight
    if not IsValid( ownLight ) then return end

    ownLight:Remove()
    ply.glee_OwnFirstPersonLight = nil

end

-- returns false when the flashlight should stop being tracked
local function manageFlashlight( flashlight )
    if not IsValid( flashlight ) then return false end
    if notPlayerFlashlights[flashlight] then return true end

    -- players' lights are unparented, a parent means a map's light or one handed to a glee_dropped_flashlight
    if IsValid( flashlight:GetParent() ) then
        notPlayerFlashlights[flashlight] = true
        return true

    end

    local ply = flashlight:GetOwner()
    if not IsValid( ply ) or not ply:IsPlayer() then return true end -- owner can arrive after the light does

    if ply:IsDormant() then return true end -- hidden in glee_HideFlashlights
    if ply:GetObserverMode() ~= OBS_MODE_NONE then return true end

    flashlitPlayers[ply] = true

    local eyeAng = ply:EyeAngles()
    local origin, beamAng = getFlashlightOrigin( ply, eyeAng )

    local result = util.TraceHull( {
        start = ply:WorldSpaceCenter(),
        endpos = origin,
        mins = -notInWorldHull,
        maxs = notInWorldHull,
        filter = ply,

    } )
    if result.Hit then
        origin = result.HitPos

    end

    flashlight.glee_DebugPos = origin -- TEMP DEBUG
    flashlight.glee_DebugAng = beamAng -- TEMP DEBUG

    if isInOwnFirstPerson( ply ) then
        updateOwnFirstPersonLight( ply, origin, beamAng )
        ownLightUpdated = true
        return true

    end

    flashlight:SetPos( origin )
    flashlight:SetAngles( beamAng )

    return true

end

local function getLampEnt()
    if IsValid( lampEnt ) then return lampEnt end

    lampEnt = ClientsideModel( GAMEMODE.FlashlightLampModel, RENDERGROUP_OPAQUE )
    if not IsValid( lampEnt ) then return end

    lampEnt:SetNoDraw( true )
    lampEnt:SetModelScale( GAMEMODE.FlashlightLampScale )

    return lampEnt

end

function GM:GleeDrawFlashlightLamp( pos, ang )
    local lamp = getLampEnt()
    if not lamp then return end

    lamp:SetPos( pos )
    lamp:SetAngles( ang )
    lamp:SetupBones() -- one model drawn for every lamp, bones are stale after moving it
    lamp:DrawModel()

end

-- strength 1 is a plain flashlight at full brightness, glares brightest when the beam points at the viewer
function GM:GleeDrawFlashlightGlow( lensPos, beamDir, strength )
    if strength <= 0 then return end

    local toViewer = EyePos() - lensPos
    toViewer:Normalize()

    local facing = toViewer:Dot( beamDir )
    if facing <= 0 then return end

    -- shrinks as it dims, until it's as small as a lit lens gets, then only dulls
    local size = glowSize * math.max( strength, glowMinSizeStrength ) * facing
    local brightness = math.min( strength / glowMinSizeStrength, 1 ) * 255
    glowColor.r = brightness
    glowColor.g = brightness
    glowColor.b = brightness
    glowColor.a = facing * facing * 255

    render.SetMaterial( glowMat )
    render.DrawSprite( lensPos + beamDir, size, size, glowColor )

end


hook.Add( "OnEntityCreated", "glee_capture_thirdpersonflashlights", function( ent )
    if not ent then return end
    local entsClass = ent:GetClass()
    if entsClass ~= "class C_EnvProjectedTexture" then return end

    table.insert( flashlights, ent )

end )

-- after interpolation, so lights land where players are drawn, Think runs before it and jitters
hook.Add( "PreRender", "glee_ManageFlashlights", function()
    table.Empty( flashlitPlayers )
    ownLightUpdated = false

    for index = #flashlights, 1, -1 do
        if not manageFlashlight( flashlights[index] ) then
            table.remove( flashlights, index )

        end
    end

    -- out of first person, or our flashlight's off or dropped
    if not ownLightUpdated then
        removeOwnFirstPersonLight( LocalPlayer() )

    end
end )

-- clientside only, the server still animates them empty handed
hook.Add( "TranslateActivity", "glee_FlashlightLampHoldPose", function( ply, act )
    if not flashlitPlayers[ply] then return end
    if not isEmptyHanded( ply ) then return end

    local translated = GAMEMODE:TranslateActivity( ply, act )
    return lampHoldActivities[translated] -- nil keeps whatever else the weapon picked, like the shove's sprint

end )

hook.Add( "PostPlayerDraw", "glee_DrawFlashlightLamp", function( ply )
    if not flashlitPlayers[ply] then return end

    local _, _, lampPos, lampAng = getFlashlightOrigin( ply, ply:EyeAngles() )
    if not lampPos then return end

    GAMEMODE:GleeDrawFlashlightLamp( lampPos, lampAng )

end )

hook.Add( "PostDrawTranslucentRenderables", "glee_DrawFlashlightGlow", function( drawingDepth, drawingSkybox )
    if drawingDepth or drawingSkybox then return end

    local me = LocalPlayer()

    for ply in pairs( flashlitPlayers ) do
        if IsValid( ply ) and ( ply ~= me or ply:ShouldDrawLocalPlayer() ) then
            local origin, beamAng, _, lampAng = getFlashlightOrigin( ply, ply:EyeAngles() )
            local glareAng = lampAng or beamAng
            GAMEMODE:GleeDrawFlashlightGlow( origin, glareAng:Forward(), ply:GetNW2Float( "glee_flashlightglow", 1 ) )

        end
    end
end )
