AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Player Swapper"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Swaps players with terminators"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

if SERVER then
    util.AddNetworkString( "nomoretemporalinversion" )

end

if CLIENT then
    local nextNoMoreInversion = 0
    net.Receive( "nomoretemporalinversion", function()
        if nextNoMoreInversion > CurTime() then return end
        nextNoMoreInversion = CurTime() + 0.1

        LocalPlayer().playerSwapper:NukeHighlighter()

        LocalPlayer().playerSwapper = nil
        LocalPlayer().ghostEnt = nil

    end )

end


function ENT:PostInitializeFunc()
    if CLIENT then
        -- HACK
        self:SetNoDraw( true )

    end
    --self:SetOwner( Entity( 1 ) )
end

function ENT:GetGivenScore()
    return -400

end

hook.Add( "HUDPaint", "plyswapper_paintscore", function()
    if not GAMEMODE.CanShowDefaultHud or not GAMEMODE:CanShowDefaultHud() then return end
    if not IsValid( LocalPlayer().playerSwapper ) then return end

    local screenMiddleW = ScrW() / 2
    local screenMiddleH = ScrH() / 2

    local scoreGained = math.Round( GAMEMODE:ValidNum( LocalPlayer().playerSwapper:GetGivenScore() ) )
    local stringPt1 = ""
    if scoreGained < 0 then
        stringPt1 = "Cost: "

    end

    local scoreString = stringPt1 .. tostring( math.abs( scoreGained ) )

    surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

end )

function ENT:GetNearestPlayer()
    local nearestPly = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all players within a radius of x units
    local stuff = ents.FindInSphere( myPos, 512 )
    for _, thing in ipairs( stuff ) do
        if thing:GetClass() == "player" and thing:Health() > 0 then
            -- Calculate the distance between the ply and the entity
            local distance = myPos:DistToSqr( thing:GetPos() )
            if distance < nearestDistance then
                nearestPly = thing
                nearestDistance = distance

            end
        end
    end

    return nearestPly
end

function ENT:GetFurthestTerminator()
    local furthestTerminator = nil
    local furthestDistance = 0
    local myPos = self:GetPos()

    for _, thing in ipairs( ents.GetAll() ) do
        if thing.isTerminatorHunterBased then
            local distance = thing:GetPos():Distance( myPos )
            if distance > furthestDistance then
                furthestTerminator = thing
                furthestDistance = distance
            end
        end
    end

    return furthestTerminator
end

function ENT:SwapPlayerAndTerminator( player, terminator )
    local playerPos = player:GetPos()
    local terminatorPos = terminator:GetPos()

    util.ScreenShake( terminatorPos, 10, 20, 4, 1000 )
    util.ScreenShake( playerPos, 10, 20, 4, 1000 )

    local beam = EffectData()
    beam:SetStart( playerPos )
    beam:SetOrigin( terminatorPos )
    beam:SetScale( 1.8 )
    util.Effect( "eff_huntersglee_dicebeam", beam, true )

    -- reverse it to make sure it renders for ppl at both ends?
    beam:SetStart( terminatorPos )
    beam:SetOrigin( playerPos )
    beam:SetScale( 1.8 )
    util.Effect( "eff_huntersglee_dicebeam", beam, true )

    player:SetPos( terminatorPos )
    terminator:SetPos( playerPos )

    player:unstuckFullHandle()

    terminator:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 85, 50, 0.4, CHAN_STATIC )
    player:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 85, 50, 1, CHAN_STATIC )

    terminator:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 85, 100, 1, CHAN_STATIC )
    player:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 85, 100, 1, CHAN_STATIC )

    terminator:EmitSound( "physics/concrete/concrete_impact_hard3.wav", 85, 100, 1, CHAN_STATIC )
    player:EmitSound( "physics/concrete/concrete_impact_hard3.wav", 85, 100, 1, CHAN_STATIC )

end

function ENT:NukeHighlighter()
    if SERVER then return end
    SafeRemoveEntity( self.player.playerHighliter )

end

if CLIENT then

    local green = {0,255,0}
    local red = {255,0,0}

    local materialOverride = render.MaterialOverride
    local setColorModulation = render.SetColorModulation
    local cam_Start3D = cam.Start3D
    local cam_End3D = cam.End3D

    local playerOverrideMat = CreateMaterial( "CHAMSMATPLAYERSWAPPER1", "UnlitGeneric", { ["$basetexture"] = "lights/white001", ["$model"] = 1, ["$ignorez"] = 1 } )

    function ENT:HighlightNearestPlayer()
        if not IsValid( self.nearestPlayer ) then return end
        if not IsValid( self.player.playerHighliter ) then
            self.player.playerHighliter = ClientsideModel( self.nearestPlayer:GetModel() )

            self.player.playerHighliter:Spawn()

        elseif self.lastNearestPlayer ~= self.nearestPlayer then
            self.lastNearestPlayer = self.nearestPlayer
            self.nearestPlayer:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 100, 200 )
            self.player.playerHighliter:SetParent( self.nearestPlayer )
            self.player.playerHighliter:SetModel( self.nearestPlayer:GetModel() )
            self.player.playerHighliter:SetPos( self.nearestPlayer:GetPos() )
            self.player.playerHighliter:SetAngles( self.nearestPlayer:GetAngles() )

        end
        if IsValid( self.player.playerHighliter ) then
            cam_Start3D();
                materialOverride( playerOverrideMat )

                local color = green
                if not self:HasEnoughToPurchase() then
                    color = red

                end

                setColorModulation( color[1], color[2], color[3] )

                self.player.playerHighliter:DrawModel()
                materialOverride()

            cam_End3D();

        end
    end
end

function ENT:CanPlace()
    if not IsValid( self.nearestPlayer ) then return end
    if not IsValid( self:GetFurthestTerminator() ) then return end
    if IsValid( GetGlobal2Entity( "terhunt_player_swapper", NULL ) ) then return false end
    if not self:HasEnoughToPurchase() then return false end
    return true

end

function ENT:ModifiableThink()

    self:SetPos( self.player:GetEyeTrace().HitPos + self.PosOffset )

    self.nearestPlayer = self:GetNearestPlayer()

    if CLIENT then
        -- HACK
        self:SetNoDraw( true )

    end

    if SERVER and self:AliveCheck() then return end

end

function ENT:SetupPlayer()
    self.player.playerSwapper = self
    self.player.ghostEnt = self
    if CLIENT and LocalPlayer() == self.player then
        hook.Add( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper", function()
            if not IsValid( self ) or not IsValid( self.player ) then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper" ) return end
            if self.player ~= LocalPlayer() then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper" ) return end
            if not self.player.playerSwapper then self:NukeHighlighter() hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper" ) return end
            self:HighlightNearestPlayer()
        end )
    end
end

function ENT:OnRemove()
    self:NukeHighlighter()

end

function ENT:Place()
    local plyToSwap = self.nearestPlayer
    local furthestTerminator = self:GetFurthestTerminator()

    if not IsValid( plyToSwap ) or not IsValid( furthestTerminator ) then return end

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( plyToSwap:GetShootPos() ) ) do
        if thing:IsPlayer() then
            table.insert( plysToAlert, thing )

        end
    end

    huntersGlee_Announce( plysToAlert, 5, 10, self.player:Name() .. " has begun a temporal inversion...\nGET AWAY FROM " .. plyToSwap:Name() .. "!" )
    plyToSwap:EmitSound( "buttons/combine_button3.wav", 100, 100 )
    plyToSwap:EmitSound( "hl1/ambience/port_suckin1.wav", 100, 80 )

    local timerName = "glee_playerswapper_timer_" .. tostring( plyToSwap:GetCreationID() )

    timer.Create( timerName, 1, 14, function()
        if not IsValid( plyToSwap ) then timer.Remove( timerName ) return end
        if not plyToSwap:Alive() then timer.Remove( timerName ) return end

        local countdown = timer.RepsLeft( timerName )

        if countdown == 12 then
            plyToSwap:EmitSound( "ambient/levels/labs/teleport_mechanism_windup5.wav", 75, 75, 1, CHAN_STATIC )

        end

        if countdown == 8 then
            plyToSwap:EmitSound( "ambient/levels/labs/teleport_preblast_suckin1.wav", 75, 28, 1, CHAN_STATIC )

        end

        if countdown == 1 then
            plyToSwap:EmitSound( "ambient/machines/teleport3.wav", 100, 80, 1, CHAN_STATIC )

        end

        if countdown == 0 then
            self:SwapPlayerAndTerminator( plyToSwap, furthestTerminator )
            timer.Remove( timerName ) -- redundancy!
            SafeRemoveEntityDelayed( self, 240 )
            SetGlobal2Entity( "terhunt_player_swapper", self )

        elseif countdown <= 8 then
            GAMEMODE:GivePanic( plyToSwap, 50 )
            local pitch = 80 + math.abs( countdown - 14 ) * 2
            plyToSwap:EmitSound( "Grenade.ImpactSoft", 75, pitch )
            huntersGlee_Announce( { plyToSwap }, 10, 2, "Inversion in... " .. countdown )

        else
            GAMEMODE:GivePanic( plyToSwap, 10 )

        end
    end )

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )

    end

    net.Start( "nomoretemporalinversion" )
    net.Send( self.player )

    self.player.playerSwapper = nil
    self.player.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )

    SetGlobal2Entity( "terhunt_player_swapper", self )


end