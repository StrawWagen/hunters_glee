-- rescue heli spotlight
-- from Dynamic Combine Flashlights by Zelektra
-- been optimized to hell and back
local nextBlinkToggle = 0
local blinkInterval = 0.5
local flashlightSprite = Material( "engine/lightsprite" )
local warningLightSprite = Material( "effects/blueflare1" )
local flashlightMaterial = Material( "sprites/glee/flashlight_beam" )
local blinkState

local function CreateProjectedTextureForHelicopter( helicopter )
    if not IsValid( helicopter ) then return end

    if not helicopter.ProjectedTexture then
        helicopter.ProjectedTexture = ProjectedTexture()

    end

    local attachmentIndex = helicopter:LookupAttachment( "Spotlight" )

    if attachmentIndex then
        local attachment = helicopter:GetAttachment( attachmentIndex )
        if attachment then
            helicopter.ProjectedTexture:SetPos( attachment.Pos )
            helicopter.ProjectedTexture:SetAngles( attachment.Ang )

        else
            helicopter.ProjectedTexture:SetPos( helicopter:GetPos() )
            helicopter.ProjectedTexture:SetAngles( helicopter:GetAngles() )

        end
    else
        -- Fallback to helicopter position if attachment is not valid
        helicopter.ProjectedTexture:SetPos( helicopter:GetPos() )
        helicopter.ProjectedTexture:SetAngles( helicopter:GetAngles() )

    end

    helicopter.ProjectedTexture:SetNearZ( 200 )
    helicopter.ProjectedTexture:SetFarZ( 5000 )
    helicopter.ProjectedTexture:SetFOV( 40 )
    helicopter.ProjectedTexture:SetBrightness( 1 )
    helicopter.ProjectedTexture:SetTexture( "effects/flashlight/hard" )
    helicopter.ProjectedTexture:Update()

end

local function RemoveProjectedTextureForHelicopter( helicopter )
    if not helicopter.ProjectedTexture then return end
    helicopter.ProjectedTexture:Remove()
    helicopter.ProjectedTexture = nil

end

local function DrawHelicopterBeams( npc, bDepth, bSkybox )
    if bSkybox then return end
    if bDepth then return end

    local spotlightOn = npc.spotlightOn
    if spotlightOn then

        -- Get the muzzle attachment
        local attachmentIndex = npc:LookupAttachment( "Spotlight" )
        if attachmentIndex == 0 then return end

        local attachment = npc:GetAttachment( attachmentIndex )
        if not attachment then return end

        local attachmentsForward = attachment.Ang:Forward()
        local startPos = attachment.Pos + ( attachmentsForward * 12 ) - ( attachment.Ang:Up() * 4 )
        local endPos = startPos + attachmentsForward * 2000

        -- Calculate dot product for scaling and visibility
        local dir = attachment.Ang:Forward() * -1
        local viewDir = ( startPos - EyePos() ):GetNormalized()
        local dotProduct = dir:Dot( viewDir )
        dotProduct = math.Clamp( dotProduct, 0, 1 ) -- Clamp to avoid very small or very large sizes

        local flaslightSpriteCheckResult = util.TraceLine( {
            start = EyePos(),
            endpos = startPos,
            filter = { npc, LocalPlayer() }
        } )

        if dotProduct > 0 and not flaslightSpriteCheckResult.Hit then -- Only draw for visible sprites
            local size = dotProduct * 400 -- Adjust base size multiplier as needed

            render.SetMaterial( flashlightSprite )
            render.DrawSprite( startPos, size, size, Color( 255, 255, 255, 255 * dotProduct ) )

        end

        local spotlightCheck = util.TraceLine( {
            start = startPos,
            endpos = endPos,
            filter = { npc },
            mask = MASK_OPAQUE
        } )

        render.SetMaterial( flashlightMaterial )
        render.DrawBeam( startPos, spotlightCheck.HitPos, 1000, 0, spotlightCheck.Fraction, Color( 255, 255, 255, ( 255 * 5 ) * ( 1 - dotProduct ) ) )

    end
    if blinkState == true then
        local attachmentIndexWarn1 = npc:LookupAttachment( "Light_Red0" )
        if attachmentIndexWarn1 == 0 then return end

        local attachmentWarn1 = npc:GetAttachment( attachmentIndexWarn1 )
        if not attachmentWarn1 then return end

        local startPosWarn = attachmentWarn1.Pos

        render.SetMaterial( warningLightSprite )
        render.DrawSprite( startPosWarn, 50, 50, Color( 255, 0, 0, 50 ) )

        local attachmentIndexWarn2 = npc:LookupAttachment( "Light_Red1" )
        if attachmentIndexWarn2 == 0 then return end

        local attachmentWarn2 = npc:GetAttachment( attachmentIndexWarn2 )
        if not attachmentWarn2 then return end

        local startPosWarn2 = attachmentWarn2.Pos

        render.DrawSprite( startPosWarn2, 50, 50, Color( 0, 255, 0, 50 ) )

        local attachmentIndexWarn3 = npc:LookupAttachment( "Light_Red2" )
        if attachmentIndexWarn3 == 0 then return end

        local attachmentWarn3 = npc:GetAttachment( attachmentIndexWarn3 )
        if not attachmentWarn3 then return end

        local startPosWarn3 = attachmentWarn3.Pos

        render.DrawSprite( startPosWarn3, 50, 50, Color( 255, 0, 0, 50 ) )

    end

    if CurTime() > nextBlinkToggle then
        nextBlinkToggle = CurTime() + blinkInterval
        if blinkState == false then
            blinkState = true

        else
            blinkState = false

        end
    end
end

local function CheckHelicopterLightLevel( helicopter )
    -- Check the light level around the helicopter.
    local lightLevel = render.ComputeLighting( helicopter:GetPos(), Vector( 0, 0, 1 ) ):Length()

    if lightLevel < 0.4 then
        CreateProjectedTextureForHelicopter( helicopter )
        helicopter.spotlightOn = true

    else
        RemoveProjectedTextureForHelicopter( helicopter )
        helicopter.spotlightOn = false

    end
end

local activeRescueHeli = NULL

local function stopRescueHeliHooks()
    RemoveProjectedTextureForHelicopter( activeRescueHeli )
    hook.Remove( "PostDrawTranslucentRenderables", "DrawHelicopterBeams" )
    hook.Remove( "Think", "CheckHelicopterLightLevel" )
    activeRescueHeli = NULL

end

local function startRescueHeliHooks( heli )
    activeRescueHeli = heli

    hook.Add( "PostDrawTranslucentRenderables", "DrawHelicopterBeams", function( bDepth, bSkybox )
        if not IsValid( activeRescueHeli ) then
            stopRescueHeliHooks()
            return

        end
        DrawHelicopterBeams( activeRescueHeli, bDepth, bSkybox )

    end )

    hook.Add( "Think", "CheckHelicopterLightLevel", function()
        if not IsValid( activeRescueHeli ) then
            stopRescueHeliHooks()
            return
        end
        CheckHelicopterLightLevel( activeRescueHeli )

    end )
end

local entMeta = FindMetaTable( "Entity" )

hook.Add( "NetworkEntityCreated", "glee_detectRescueHeli", function( ent )
    if entMeta.GetClass( ent ) ~= "npc_helicopter" then return end
    timer.Simple( 1, function() -- NWVars dont get there instantly :(
        if not IsValid( ent ) then return end
        if not ent:GetNWBool( "isGleeRescueHeli" ) then return end
        startRescueHeliHooks( ent )

    end )
end )
