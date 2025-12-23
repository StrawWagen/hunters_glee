AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Homicidal Glee"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Makes a player immortal"
ENT.Spawnable    = false
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

local function getDanceSeq( targ )
    return targ:SelectWeightedSequence( ACT_GMOD_TAUNT_DANCE )

end

if CLIENT then
    function ENT:DoHudStuff()
        if not IsValid( self:GetCurrTarget() ) then return end
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2
        local scoreGained = math.Round( self:GetGivenScore() )
        local scoreString = "They've killed you before.\nTheir Homicidal Glee costs nothing to surface!"
        if scoreGained < -75 then
            scoreString = "Cost: " .. tostring( scoreGained )
        elseif scoreGained < 0 then
            scoreString = "They've... Wronged you before.\nTheir Homicidal glee Costs... " .. tostring( scoreGained ) .. " To surface."

        end

        surface.SetFont( "scoreGainedOnPlaceFont" )
        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
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

function ENT:CalculateCanPlace()
    local currTarget = self:GetCurrTarget()
    if not IsValid( currTarget ) then return false, "You have to find a vessel for Homicidal Glee." end
    if currTarget:HasStatusEffect( "divine_chosen" ) then return false, "They're already as gleefully homicidal as one can be..." end
    if getDanceSeq( currTarget ) < 0 then return false, "They're too boring to dance." end -- lol if this happens
    if currTarget:IsPlayingTaunt2() then return false, "They're already dancing!" end
    if self.player.glee_nextHomicidalGleePlace and self.player.glee_nextHomicidalGleePlace > CurTime() then return false, "Wait. It's too soon for you to surface one's Homicidal Glee." end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

local baseCost = 200

function ENT:UpdateGivenScore()
    local currTarget = self:GetCurrTarget()
    if not IsValid( currTarget ) then return end

    local slightSize = 0
    if GAMEMODE.HasSlighted then
        slightSize = GAMEMODE:HasSlighted( currTarget, self.player )

    end

    local reduction = slightSize * 2
    reduction = math.Clamp( reduction, -baseCost, baseCost )

    local cost = -baseCost + reduction

    self:SetGivenScore( cost )

end

local happyLines = {
    "vo/npc/male01/fantastic01.wav",
    "vo/npc/male01/fantastic02.wav",
    "vo/npc/male01/finally.wav",
    "vo/npc/male01/yeah02.wav",
    "vo/npc/male01/yougotit02.wav",

}
local cheers = {
    "vo/coast/odessa/male01/nlo_cheer01.wav",
    "vo/coast/odessa/male01/nlo_cheer02.wav",
    "vo/coast/odessa/male01/nlo_cheer03.wav",
    "vo/coast/odessa/male01/nlo_cheer04.wav",

}

function ENT:Place()

    GAMEMODE:SurfaceHomicidalGlee( self:GetCurrTarget(), self.player )

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end

    self.player.glee_nextHomicidalGleePlace = CurTime() + 15

end

hook.Add( "glee_slightsizeoverride", "noguilt_forkilling_dancers", function( died )
    if not died:IsPlayingTaunt2() then return end
    if not died.glee_evilHomicidalGlee then return end

    return 25, "killed them while they were guiltily dancing"

end )

function GAMEMODE:SurfaceHomicidalGlee( dancer, surfacer )
    if not IsValid( dancer ) then return end

    local danceSeq = getDanceSeq( dancer )
    if danceSeq < 0 then return end

    if dancer:InVehicle() then
        dancer:ExitVehicle()

    end

    if not dancer:TauntDance() then return end -- starts the taunt

    dancer:EmitSound( happyLines[math.random( 1, #happyLines )], 75, math.random( 95, 105 ) )
    timer.Simple( 1, function()
        dancer:EmitSound( cheers[math.random( 1, #cheers )], 75, math.random( 95, 105 ) )

    end )

    local timerName = "homicidal_glee_cheering_" .. dancer:GetCreationID()

    timer.Create( timerName, 3, 0, function()
        -- rage quit!
        if not IsValid( dancer ) then
            timer.Remove( timerName )
            return

        end
        -- F
        if dancer:Health() < 0 then
            timer.Remove( timerName )
            dancer.glee_evilHomicidalGlee = nil
            return

        end
        if not dancer:IsPlayingTaunt2() then
            dancer.glee_evilHomicidalGlee = nil
            timer.Remove( timerName )
            return

        end

        dancer:EmitSound( cheers[math.random( 1, #cheers )], 75, math.random( 95, 105 ) )

    end )

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( dancer:GetShootPos() ) ) do
        if thing:IsPlayer() and thing ~= dancer then
            table.insert( plysToAlert, thing )

        end
    end

    local validSurfacer = IsValid( surfacer )
    local oldSlight = 0
    if validSurfacer then
        GAMEMODE:HasSlighted( dancer, surfacer )

    end

    local reason = ""
    local reasonGlobal = ""
    if validSurfacer then
        if oldSlight >= 75 then
            reason = "You can't help but dance as the GUILTY HOMICIDAL GLEE\nof killing " .. surfacer:Nick() .. "\nflashes through your mind..."
            reasonGlobal = dancer:Nick() .. " is overcome by their Guilty Homicidal Glee."
            dancer.glee_evilHomicidalGlee = true

        else
            reason = "You can't help but dance as " .. surfacer:Nick() .. "\nbrings your HOMICIDAL GLEE to the surface..."
            reasonGlobal = dancer:Nick() .. " is overcome with Homicidal Glee."
            dancer.glee_evilHomicidalGlee = false

        end

        if GAMEMODE:IsInnocent( dancer ) then
            GAMEMODE:AddSlight( surfacer, dancer, 15, "forced to dance" )

        end

        GAMEMODE:AddSlight( dancer, surfacer, -25, "used homicidal glee, decay" ) -- slowly remove slight

    else
        reason = "Killing all those innocent people has left you boiling with GUILTY HOMICIDAL GLEE...\nYou can't help but let it out!"
        reasonGlobal = dancer:Nick() .. "'s Guilty Homicidal Glee boils to the surface..."
        dancer.glee_evilHomicidalGlee = true

    end


    huntersGlee_Announce( { dancer }, 10, 8, reason )
    huntersGlee_Announce( plysToAlert, 5, 6, reasonGlobal )

end