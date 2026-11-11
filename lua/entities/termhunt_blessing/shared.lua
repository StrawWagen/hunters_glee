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

ENT.CanInstantlyProfit = false
ENT.CanProfitLater = false

if CLIENT then
    function ENT:DoHudStuff()
        local scoreGained = math.Round( self:GetGivenScore() )

        self:DrawPlacingLine( "Blessing Cost: " .. scoreGained )

    end
end

function ENT:CalculateCanPlace()
    if not IsValid( self:GetCurrTarget() ) then return false, "Nothing to bless." end
    if self:GetCurrTarget().glee_Blessed then return false, "That's already blessed." end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

local newPlayerCostMul = 0.5

function ENT:UpdateGivenScore()
    if not IsValid( self:GetCurrTarget() ) then return end
    if self:GetCurrTarget():IsPlayer() then
        local cost = -100
        if GAMEMODE:IsFirstTimePlayer( self:GetCurrTarget() ) then
            cost = cost * newPlayerCostMul

        end
        self:SetGivenScore( cost )

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
    for _, thing in ipairs( ents.FindInPVS( target:WorldSpaceCenter() ) ) do
        if not thing:IsPlayer() then continue end
        if thing == target then continue end
        if thing == placer then continue end
        if thing:GetPos():Distance( targetsPos ) > notifDistCutoff then continue end

        table.insert( plysToAlert, thing )

    end

    local targetName = GAMEMODE:GetNameOfBot( target )
    local looksLikePlayer = GAMEMODE:LooksLikePlayer( target )
    local advice = looksLikePlayer and "" or "\nAvoid " .. targetName .. "."
    huntersGlee_NotifyLivingAndDead( plysToAlert, {
        text = "DIVINE BLESSING DETECTED",
        description = GAMEMODE:SuitNameOf( self.player ) .. " has blessed " .. targetName .. "." .. advice,
        time = 10,
    }, {
        text = self.player:Nick() .. " has blessed " .. targetName .. "!",
        time = 10,
    } )

    if target:IsPlayer() then
        huntersGlee_Notify( { target }, {
            text = "DIVINE BLESSING DETECTED",
            description = "Soul to thank? is MOST LIKELY:\n " .. GAMEMODE:SuitNameOf( self.player ),
            kind = "good",
            time = 15,
            replaceKey = "divineBlessed",
            style = "hl2",
        } )
    end

    if looksLikePlayer then
        huntersGlee_Notify( { placer }, {
            text = "You've blessed " .. targetName .. "!",
            description = "Surely they'll survive now...?",
            kind = "good",
            time = 12,
            style = "soulthought",
        } )

    else
        huntersGlee_Notify( { placer }, {
            text = "You've blessed " .. targetName .. "!",
            kind = "good",
            time = 12,
            style = "soulthought",
        } )

    end

    local timerName = "glee_blessing_timer_" .. tostring( target:GetCreationID() )
    local hookName = "glee_blessing_reset" .. tostring( target:GetCreationID() )

    if not target:IsPlayer() then
        target.glee_InterestingHunter = true

    end

    target.glee_Blessed = true
    target.glee_BlessedExpires = CurTime() + blessTimeBackup -- backup if timer errors
    target.glee_BlessRegen = 10

    target:EmitSound( "music/hl2_song10.mp3", 70, math.random( 60, 70 ), 0.5, CHAN_STATIC )
    target:EmitSound( "items/smallmedkit1.wav", 75, math.random( 50, 60 ), 1, CHAN_STATIC )

    util.ScreenShake( targetsPos, 5, 20, 1.5, 1500, true )

    local blessCancel = function()
        timer.Remove( timerName )
        hook.Remove( "huntersglee_player_reset", hookName )

        if not IsValid( target ) then return end

        target.glee_Blessed = nil
        target.glee_BlessedExpires = nil

        if target:IsPlayer() then
            huntersGlee_CancelNotify( { target }, "divineBlessed", { noFade = true } )

        end
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
        target.glee_LastSetHealthReason = "glee_blessing"

        local armor = target:Armor()
        target:SetArmor( math.min( armor + 1, math.max( target:GetMaxArmor(), armor ) ) ) -- :)

        GAMEMODE:GivePanic( target, -target.glee_BlessRegen ) -- calming!

        target.glee_BlessRegen = target.glee_BlessRegen * 0.99
        target.glee_BlessRegen = math.max( target.glee_BlessRegen, 1 )

        local timeLeft = timer.RepsLeft( timerName )
        timeLeft = timeLeft + -1

        local fading = timeLeft <= 10 and timeLeft > 0
        if fading then
            target.glee_BlessRegen = target.glee_BlessRegen * ( timeLeft / 5 )

        end
        if fading and target:IsPlayer() then
            huntersGlee_Notify( { target }, {
                text = "DIVINE BLESSING FADING",
                description = "Blessing projected to end in... " .. timeLeft,
                kind = "bad",
                time = 1.5,
                replaceKey = "blessing_countdown",
            } )

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

    if target:IsPlayer() then
        GAMEMODE:AddMischievousness( self.player, -5, "blessed a player, reduction" )

        -- one forgiveness per person blessed, so nobody farms it off the same target
        GAMEMODE.roundExtraData.hasBlessedTbl = GAMEMODE.roundExtraData.hasBlessedTbl or {}
        if GAMEMODE:GetStoredPersistentGuilt( self.player ) > 0 and not GAMEMODE.roundExtraData.hasBlessedTbl[target] then
            GAMEMODE.roundExtraData.hasBlessedTbl[target] = true
            local isFirst = GAMEMODE:IsFirstTimePlayer( target )
            local reduction = isFirst and -0.5 or -0.05
            local msg = isFirst and "A new soul!\nYour guilt lifts..." or "Your guilt barely lifts..."

            GAMEMODE:IncrementPersistentGuilt( self.player, reduction, msg )

        end
    else
        GAMEMODE:AddMischievousness( self.player, 1, "blessed a hunter..." )

    end

    self:DetachFromOwner()

    SafeRemoveEntity( self )

end

hook.Add( "PlayerDeath", "glee_blessing_stopmusic", function( died )
    died:StopSound( "music/hl2_song10.mp3" )

end )