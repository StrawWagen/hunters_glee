AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "termhunt_immortalizer"

ENT.Category    = "Other"
ENT.PrintName   = "Glee Blessing"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Places a blessing upon a target"
ENT.Spawnable    = false
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local stringPt1 = "Blessing Cost: "

        local scoreString = stringPt1 .. tostring( scoreGained )

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

function ENT:CalculateCanPlace()
    if not IsValid( self:GetCurrTarget() ) then return false, "Nothing to bless." end
    if self:GetCurrTarget().glee_Blessed then return false, "That's already blessed." end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

function ENT:UpdateGivenScore()
    if not IsValid( self:GetCurrTarget() ) then return end
    if self:GetCurrTarget():IsPlayer() then
        self:SetGivenScore( -100 )

    elseif self:GetCurrTarget():IsNextBot() then
        self:SetGivenScore( -50 )

    end
end

local blessTime = 120 -- seconds
local blessTimeBackup = 140 -- in case the timer errors
local notifDistCutoff = 2500

function ENT:Place()
    local target = self:GetCurrTarget()
    local placer = self.player

    if not IsValid( target ) then return end

    local plysToAlert = {}
    local targetsPos = target:GetPos()
    for _, thing in ipairs( ents.FindInPVS( target:GetShootPos() ) ) do
        if not thing:IsPlayer() then continue end
        if thing == target then continue end
        if thing == placer then continue end
        if thing:GetPos():Distance( targetsPos ) > notifDistCutoff then continue end

        table.insert( plysToAlert, thing )

    end

    if target:IsPlayer() then
        huntersGlee_Announce( plysToAlert, 5, 6, "You feel... Jealous?\n" .. self.player:Nick() .. " has blessed...\n" .. target:Nick() )
        huntersGlee_Announce( { target }, 10, 10, "Something's right, you feel calmer, healthier, you feel... blessed.\n" .. self.player:Nick() .. " has blessed you from beyond the grave!" )
        huntersGlee_Announce( { placer }, 10, 10, "You've blessed " .. target:Nick() .. "!\nSurely they'll survive now...?" )

    else
        huntersGlee_Announce( plysToAlert, 5, 6, "Something isn't right..\n" .. self.player:Nick() .. " has blessed " .. GAMEMODE:GetNameOfBot( target ) .. "!" )
        huntersGlee_Announce( { placer }, 10, 10, "You've blessed " .. GAMEMODE:GetNameOfBot( target ) .. "!" )

    end

    local timerName = "glee_blessing_timer_" .. tostring( target:GetCreationID() )
    local hookName = "glee_blessing_reset" .. tostring( target:GetCreationID() )

    target.glee_Blessed = true
    target.glee_BlessedExpires = CurTime() + blessTimeBackup -- backup if timer errors
    target.glee_BlessRegen = 10

    target:EmitSound( "music/hl2_song10.mp3", 70, math.random( 60, 70 ), 1, CHAN_STATIC )
    target:EmitSound( "items/smallmedkit1.wav", 75, math.random( 50, 60 ), 1, CHAN_STATIC )

    util.ScreenShake( targetsPos, 5, 20, 1.5, 1500, true )

    local blessCancel = function()
        timer.Remove( timerName )
        hook.Remove( "huntersglee_player_reset", hookName )

        if not IsValid( target ) then return end

        target.glee_Blessed = nil
        target.glee_BlessedExpires = nil

    end

    hook.Add( "huntersglee_player_reset", hookName, function( ply )
        if not IsValid( ply ) then blessCancel() return end
        if not ply.glee_Blessed then blessCancel() return end
        blessCancel()

    end )

    timer.Create( timerName, 1, blessTime, function()
        if not IsValid( target ) then blessCancel() return end
        if not target.glee_Blessed then blessCancel() return end
        if target:Health() <= 0 then blessCancel() return end

        local newHealth = math.Round( target:Health() + target.glee_BlessRegen )
        newHealth = math.min( newHealth, target:GetMaxHealth() )
        target:SetHealth( newHealth )

        target:SetArmor( math.min( target:Armor() + 1, target:GetMaxArmor() ) ) -- :)

        GAMEMODE:GivePanic( target, -target.glee_BlessRegen ) -- calming!

        target.glee_BlessRegen = target.glee_BlessRegen * 0.99
        target.glee_BlessRegen = math.max( target.glee_BlessRegen, 1 )

        local timeLeft = timer.RepsLeft( timerName )
        timeLeft = timeLeft + -1

        local message

        if timeLeft <= 5 and timeLeft > 0 then
            message = "You feel your blessing fading...\n" .. tostring( timeLeft ) .. "."
            target.glee_BlessRegen = target.glee_BlessRegen * ( timeLeft / 5 )

        end
        if message and target:IsPlayer() then
            huntersGlee_Announce( { target }, 10, 1.5, message )

        end

        if timeLeft < 0 then
            blessCancel()
            target:EmitSound( "ambient/levels/citadel/portal_beam_shoot1.wav", 75, 60, 1, CHAN_STATIC )

        end
    end )

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end

    self:TellPlyToClearHighlighter()

    self.player.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )

    SafeRemoveEntity( self )

end

hook.Add( "PlayerDeath", "glee_blessing_stopmusic", function( died )
    died:StopSound( "music/hl2_song10.mp3" )

end )