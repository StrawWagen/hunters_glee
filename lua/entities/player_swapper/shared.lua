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

ENT.SwapSound = "ambient/levels/labs/electric_explosion5.wav"

if SERVER then
    util.AddNetworkString( "glee_cleartargetedplacable" )

end

if CLIENT then
    local nextNoMoreInversion = 0
    net.Receive( "glee_cleartargetedplacable", function()
        if nextNoMoreInversion > CurTime() then return end
        nextNoMoreInversion = CurTime() + 0.1

        local toWipe = net.ReadEntity()
        if IsValid( toWipe ) then
            toWipe:NukeHighlighter()

        end

        if toWipe ~= LocalPlayer().ghostEnt then return end

        LocalPlayer().placableTargeted = nil
        LocalPlayer().ghostEnt = nil

    end )

    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local stringPt1 = ""
        if scoreGained < 0 then
            stringPt1 = "Cost: "

        end

        local scoreString = stringPt1 .. math.abs( scoreGained )

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end

    function ENT:NukeHighlighter()
        SafeRemoveEntity( self.player.placableSnapHighligher )

    end

    local green = { 0, 255, 0 }
    local red = { 255, 0, 0 }

    local materialOverride = render.MaterialOverride
    local setColorModulation = render.SetColorModulation
    local cam_Start3D = cam.Start3D
    local cam_End3D = cam.End3D

    local playerOverrideMat = CreateMaterial( "CHAMSMATPLAYERSWAPPER1", "UnlitGeneric", { ["$basetexture"] = "lights/white001", ["$model"] = 1, ["$ignorez"] = 1 } )

    function ENT:HighlightNearestTarget()
        if not IsValid( self:GetCurrTarget() ) then return end
        if not IsValid( self.player.placableSnapHighligher ) then
            self.player.placableSnapHighligher = ClientsideModel( self:GetCurrTarget():GetModel() )

            self.player.placableSnapHighligher:Spawn()

        elseif self.lastNearestTarget ~= self:GetCurrTarget() then
            self.lastNearestTarget = self:GetCurrTarget()
            self:GetCurrTarget():EmitSound( self.SwapSound, 100, 200 )
            self.player.placableSnapHighligher:SetParent( self:GetCurrTarget() )
            self.player.placableSnapHighligher:SetModel( self:GetCurrTarget():GetModel() )
            self.player.placableSnapHighligher:SetPos( self:GetCurrTarget():GetPos() )
            self.player.placableSnapHighligher:SetAngles( self:GetCurrTarget():GetAngles() )

        end
        if IsValid( self.player.placableSnapHighligher ) then
            cam_Start3D();
                materialOverride( playerOverrideMat )

                local color = green
                if not self:GetCanPlace() then
                    color = red

                end

                setColorModulation( color[1], color[2], color[3] )

                self.player.placableSnapHighligher:DrawModel()
                materialOverride()

            cam_End3D();

        end
    end
    function ENT:ClientThink()
        self:SetNoDraw( true )

    end
end

function ENT:SetupDataTablesExtra()
    self:NetworkVar( "Entity", 1, "CurrTarget" )

end

function ENT:PostInitializeFunc()
    if CLIENT then
        -- HACK
        self:SetNoDraw( true )

    end
    --self:SetOwner( Entity( 1 ) )
end

function ENT:GetNearestTarget()
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
            local distance = thing:GetPos():DistToSqr( myPos )
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

    player:TeleportTo( terminatorPos )
    terminator:SetPos( playerPos )

    player:unstuckFullHandle()

    terminator:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 85, 50, 0.4, CHAN_STATIC )
    player:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 85, 50, 1, CHAN_STATIC )

    terminator:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 85, 100, 1, CHAN_STATIC )
    player:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 85, 100, 1, CHAN_STATIC )

    terminator:EmitSound( "physics/concrete/concrete_impact_hard3.wav", 85, 100, 1, CHAN_STATIC )
    player:EmitSound( "physics/concrete/concrete_impact_hard3.wav", 85, 100, 1, CHAN_STATIC )

end

function ENT:CalculateCanPlace()
    if not IsValid( self:GetCurrTarget() ) then return false, "You need to be looking at a player." end
    if not IsValid( self:GetFurthestTerminator() ) then return false, "No hunters are currently spawned." end
    if GAMEMODE:isTemporaryTrueBool( "terhunt_player_swapper" ) then return false, "It's too soon for another inversion to begin." end
    if not self:HasEnoughToPurchase() then return false, self.noPurchaseReason_TooPoor end
    return true

end

function ENT:OnNewTarget()
end

function ENT:ManageMyPos()
    self:SetPos( self.player:GetEyeTrace().HitPos + self.PosOffset )
    local oldTarg = self:GetCurrTarget()
    local newTarg = self:GetNearestTarget()
    self:SetCurrTarget( newTarg )
    if oldTarg ~= newTarg then
        self:OnNewTarget( oldTarg, newTarg )

    end
end

function ENT:SetupPlayer()
    self.player.placableTargeted = self
    self.player.ghostEnt = self
    if CLIENT and LocalPlayer() == self.player then
        hook.Add( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper", function()
            if not IsValid( self ) or not IsValid( self.player ) then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper" ) return end
            if self.player ~= LocalPlayer() then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper" ) return end
            if not self.player.placableTargeted then self:NukeHighlighter() hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestPlayerSwapper" ) return end
            self:HighlightNearestTarget()
        end )
    end
end

function ENT:OnRemove()
    if not CLIENT then return end
    self:NukeHighlighter()

end

if not SERVER then return end

function ENT:TellPlyToClearHighlighter()
    net.Start( "glee_cleartargetedplacable" )
        net.WriteEntity( self )

    net.Send( self.player )

end

function ENT:UpdateGivenScore()
    self:SetGivenScore( -300 )

end

function ENT:Place()
    local plyToSwap = self:GetCurrTarget()
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
    local steps = 14

    timer.Create( timerName, 1, steps, function()
        if not IsValid( self ) then timer.Remove( timerName ) return end
        if not IsValid( plyToSwap ) then timer.Remove( timerName ) return end
        furthestTerminator = furthestTerminator or self:GetFurthestTerminator()
        if not IsValid( furthestTerminator ) then return end
        if not plyToSwap:Alive() then
            self:SwapPlayerAndTerminator( plyToSwap, furthestTerminator )
            timer.Remove( timerName )
            return

        end

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
            SafeRemoveEntity( self )

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

    self:TellPlyToClearHighlighter()

    self.player.placableTargeted = nil
    self.player.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )

    GAMEMODE:setTemporaryTrueBool( "terhunt_player_swapper", 180 + steps )

end