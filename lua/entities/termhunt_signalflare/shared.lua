AddCSLuaFile()

DEFINE_BASECLASS( "termhunt_flare" )

ENT.Category    = "Hunter's Glee"
ENT.PrintName   = "Escape Flare"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Flares"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/plates/plate.mdl"

ENT.Lifetime = 50

local className = "termhunt_signalflare"
if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, className, "vgui/hud/killicon/" .. className .. ".png" )

end

--sandbox support
function ENT:SpawnFunction( ply, tr )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 20

    local ent = ents.Create( "termhunt_signalflare" )
    ent:Spawn()
    ent:SetPos( SpawnPos )
    ent:SetOwner( ply )

    return ent

end

if SERVER and terminator_Extras then

    local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator
    local rescueHeli = terminator_Extras.glee_RescueHeli

    local debugging = rescueHeli.Debugging

    local zHeightToStartCalling = 350

    function ENT:AdditionalInitialize()
        self.skyCorridorSearch = gleeFlightNavigator.NewSkyCorridorSearch( rescueHeli.SkyCorridorCfg )

        local brightness = 5
        -- bright blue light
        local dlight = ents.Create( "light_dynamic" )
        dlight:SetKeyValue( "_light", "255 255 255 200" )
        dlight:SetKeyValue( "distance", "450" )
        dlight:SetKeyValue( "brightness", tostring( brightness ) )
        dlight:SetPos( self:GetPos() )
        dlight:SetParent( self )
        dlight:Spawn()

        dlight:Fire( "brightness", brightness * 0.75, 3 )
        dlight:Fire( "brightness", brightness * 0.5, 5 )
        dlight:Fire( "brightness", brightness * 0.25, 10 )

        self.signalflare_dLight = dlight

    end

    function ENT:ResetCallability()
        self.wastedFlare = nil
        self.skyCorridorSearch:Reset()

    end

    ENT.FastThinks = true

    function ENT:AdditionalThink()
        if self.wastedFlare then return end
        if self.calledForHeli then return end

        local myPos = self:GetPos()

        local myPhysObj = self:GetPhysicsObject()
        if IsValid( myPhysObj ) then
            local velLengSqr = myPhysObj:GetVelocity():LengthSqr()
            if velLengSqr < 10^2 then
                local floorCheck = terminator_Extras.getFloorTr( myPos ).HitPos
                if floorCheck:Distance( myPos ) < 25 then
                    self.wastedFlare = true

                    local fallbackPos = self.skyCorridorSearch:GetFallbackPos()
                    if fallbackPos then
                        self:CallHeli( fallbackPos, myPos )
                        return

                    end

                    if IsValid( self.MyOwner ) and self.MyOwner:IsPlayer() and not self.glee_SignalFlareHint then
                        self.glee_SignalFlareHint = true
                        huntersGlee_Announce( { self.MyOwner }, 500, 5, "God, that's bright\nI bet you could see it from miles away..." )

                    end

                    return

                end
            end
        end

        if rescueHeli.IsCalledOrPresent() then return end

        if not self.HitSkyboxAtLeastOnce then
            local lastFloor = self.LastFloorPos
            if not lastFloor then
                lastFloor = terminator_Extras.getFloorTr( myPos ).HitPos
                self.LastFloorPos = lastFloor
                timer.Simple( 2, function()
                    if not IsValid( self ) then return end
                    self.LastFloorPos = nil

                end )
            end

            local heightFromStart = myPos.z - lastFloor.z

            if heightFromStart < zHeightToStartCalling then
                if debugging:GetBool() then
                    permaPrint( "closetoground" )

                end
                return

            end
        end

        -- if the flare crashed into the skybox, this is a tight space, just call it!
        local spawnPos, goalPos = self.skyCorridorSearch:Step( myPos, self.HitSkyboxAtLeastOnce )
        if not spawnPos then return end

        self:CallHeli( spawnPos, goalPos )

    end

    function ENT:CallHeli( spawnPos, goalPos )
        self.calledForHeli = true
        rescueHeli.Call( spawnPos, goalPos, self.MyOwner )

    end

    hook.Add( "GravGunOnPickedUp", "glee_signalflare_resetcall", function( _ply, ent )
        if ent:GetClass() ~= "termhunt_signalflare" then return end
        ent:ResetCallability()

    end )

end

if not CLIENT then return end

local lifetime = 20

local signalFlaresThatPierceFog = {}

local bigFlareMatId   = surface.GetTextureID( "effects/strider_bulge_dudv_dx60" )
local flareColorBig   = Color( 255, 255, 255, 255 )
local smallFlareMatId = surface.GetTextureID( "effects/huntermuzzle" )
local flareColorSmall = Color( 150, 150, 255, 255 )
local maxFlareSize = 400

hook.Add( "RenderScreenspaceEffects", "glee_predraw_fogpiercing_signalflares", function()

    if not next( signalFlaresThatPierceFog ) then return end

    local me = LocalPlayer()
    local eyePos = EyePos()

    local startMakingBiggerDist = 450

    for _, flare in pairs( signalFlaresThatPierceFog ) do
        local sizeMul = 400

        local flaresRealPos = flare:WorldSpaceCenter()
        local pos2d = flaresRealPos:ToScreen()

        if not pos2d.visible then continue end

        local distanceToIt = eyePos:Distance( flaresRealPos )
        -- smoothly scale up as viewer gets closer (1x at 450+, 2x at 0)
        local proxMul = 1 + ( 1 - math.Clamp( distanceToIt / startMakingBiggerDist, 0, 1 ) )
        sizeMul = sizeMul * proxMul

        local canSee = terminator_Extras.PosCanSeeComplex( eyePos, flaresRealPos, me )
        if not canSee then continue end

        -- magic num
        local distBite = math.log( distanceToIt, 4 ) * 5

        local timeToDeath = math.abs( flare:GetDeathTime() - CurTime() )
        local size = math.Clamp( timeToDeath / lifetime, 0, 1 )
        size = size * sizeMul

        local width  = size - distBite
        local height = size - distBite
        width  = math.min( width, maxFlareSize )
        height = math.min( height, maxFlareSize )

        local bigJitter = width * 0.05
        local bigJitterx = math.Rand( -bigJitter, bigJitter )
        local bigJittery = math.Rand( -bigJitter, bigJitter )
        local halfWidth = width / 2

        -- draw big dim one
        local bigStruc = {
            texture = bigFlareMatId,
            color   = flareColorBig,
            x 	= pos2d.x + -halfWidth + bigJitterx,
            y 	= pos2d.y + -halfWidth + bigJittery,
            w 	= width,
            h 	= height
        }

        draw.TexturedQuad( bigStruc )

        -- draw small bright one

        local smallWidth = width / 6
        local smallJitter = smallWidth * 0.05
        local smallJitterx = math.Rand( -smallJitter, smallJitter )
        local smallJittery = math.Rand( -smallJitter, smallJitter )
        local smallWidthHalf = smallWidth / 2

        local smallStruc = {
            texture = smallFlareMatId,
            color = flareColorSmall,
            x = pos2d.x + -smallWidthHalf + smallJitterx / 2,
            y = pos2d.y + -smallWidthHalf + smallJittery / 2,
            w = smallWidth,
            h = smallWidth
        }

        draw.TexturedQuad( smallStruc )

    end
end )

function ENT:Think()
    local myId = self:GetCreationID()

    if not signalFlaresThatPierceFog[myId] then
        signalFlaresThatPierceFog[myId] = self

    end
end

function ENT:OnRemove()
    signalFlaresThatPierceFog[self:GetCreationID()] = nil

end
