--[[------------------------------------
    Has a bot buy a placable and place it on someone, the way a dead player would.

        glee_test_placeghostlyplysnappable temporalinversion Bot01

    The player is one word, a name or a SteamID, no quotes needed.
    Leave them off to target yourself.
    Stand near the target to see what bystanders see.
    Bots print what they're told to console too, look for GLEEBOTNOTIFY.

    It buys through the real shop, so a cooldown or the wrong round state stops it.
    Start reading at the concommand, at the bottom.
--]]-------------------------------------

local reloadHook = "glee_test_place_holdreload"
local timerName = "glee_test_place"
local tickInterval = 0.1
local maxTicks = 100
local testScore = 100000 -- more than anything costs
local standoff = 100 -- how far the bot hovers from the target

local run -- the test in progress, there's only ever one

local function finish( message )
    timer.Remove( timerName )
    hook.Remove( "StartCommand", reloadHook )

    -- a ghost left behind would block the next purchase
    local ghost = IsValid( run.bot ) and run.bot.ghostEnt
    if IsValid( ghost ) then
        ghost:Cancel()

    end

    run = nil
    permaPrint( "GLEE: " .. message )

end

local function holdReload( ply, cmd )
    if not run or ply ~= run.bot then return end

    cmd:ClearMovement()
    cmd:SetButtons( IN_RELOAD ) -- the loss gate lets a held R through

end

-- placables all read the owner's eye trace, and a ghost bot's view won't turn
-- so put it wherever it's already looking at the target
local function moveToFaceTarget( bot, target )
    local eyeOffset = bot:EyePos() - bot:GetPos()
    bot:SetPos( target:WorldSpaceCenter() - bot:GetAimVector() * standoff - eyeOffset )

end

local function whyStuck( bot )
    local ghost = bot.ghostEnt
    if not IsValid( ghost ) then return "The bot never started placing, is it a placable?" end
    return "Couldn't place: " .. ( ghost.cannotPurchaseReason or "it never became placable." )

end

local function tick()
    local bot = run.bot
    local target = run.target

    if not IsValid( bot ) or not IsValid( target ) then finish( "Lost the bot or the target." ) return end
    if target:Health() <= 0 then finish( target:Nick() .. " died before the bot could place." ) return end

    if timer.RepsLeft( timerName ) <= 0 then finish( whyStuck( bot ) ) return end

    if not bot.shopItemCooldowns then return end -- a brand new bot hasn't spawned yet

    if not run.madeGhost then
        run.madeGhost = true
        GAMEMODE:spectatifyPlayer( bot )
        bot:SetScore( testScore )

    end

    moveToFaceTarget( bot, target )

    if bot:Health() > 0 or bot:GetObserverMode() ~= OBS_MODE_ROAMING then return end

    if not run.purchased then
        run.purchased = true
        GAMEMODE:purchaseItem( bot, run.item )

    end

    local ghost = bot.ghostEnt
    if not IsValid( ghost ) then return end
    if ( ghost.nextPlaceThink or 0 ) > CurTime() then return end
    if not ghost:GetCanPlace() or ghost:BlockedForLoss( bot ) then return end
    if ghost.GetCurrTarget and ghost:GetCurrTarget() ~= target then return end

    ghost:HandleKeys( bot, IN_ATTACK )
    finish( bot:Nick() .. " placed " .. run.item .. " on " .. target:Nick() .. "." )

end

-- purchaseItem already printed why
hook.Add( "glee_CouldntPurchase", "glee_test_place_failed", function( ply, toPurchase )
    if not run or ply ~= run.bot then return end
    finish( ply:Nick() .. " couldn't buy " .. toPurchase .. "." )

end )

-- a dead bot first, nothing's lost by using it
local function findPlacer( target )
    local alive
    for _, ply in player.Iterator() do
        if not ply:IsBot() or ply == target then continue end
        if ply:Health() <= 0 then return ply end
        alive = ply

    end

    return alive or player.CreateNextBot( "Glee Test Placer" )

end

concommand.Add( "glee_test_placeghostlyplysnappable", function( caller, _, _args, argStr )
    if IsValid( caller ) and not caller:IsAdmin() then return end

    local words = GAMEMODE:ArgWords( argStr )
    local item = words[1]
    if not GAMEMODE:GetShopItemData( item ) then
        permaPrint( "Usage: glee_test_placeghostlyplysnappable <shop item> [player], no shop item called " .. tostring( item ) )
        if IsValid( caller ) then
            huntersGlee_Notify( { caller }, { text = "That isn't a real thing for sale.", kind = "bad", time = 6 } )

        end
        return

    end

    -- checked here, before a bot gets killed for nothing
    local rightStage = table.HasValue( GAMEMODE:GetShopItemData( item ).purchaseTimes, GAMEMODE:RoundState() )
    if not rightStage or GAMEMODE:shopItemGlobalCooldownEnd( item ) > CurTime() then
        permaPrint( "glee_test_placeghostlyplysnappable: Nothing placed, " .. item .. " can't be bought right now. Wrong round stage, or on global cooldown." )
        return

    end

    local target = caller
    local failReason
    if words[2] then
        target, _, failReason = GAMEMODE:FindPlayerByArg( words[2] )

    end

    if not IsValid( target ) then
        permaPrint( failReason or "GLEE: Needs a player who's online." )
        return

    end

    if target:Health() <= 0 then
        permaPrint( "GLEE: " .. target:Nick() .. " is dead, placables want a living target." )
        return

    end

    if run then
        finish( "Replaced by a new test." )

    end

    local bot = findPlacer( target )
    if not IsValid( bot ) then
        permaPrint( "GLEE: No bot to place with, and couldn't make one. Is the server full?" )
        return

    end

    run = { bot = bot, target = target, item = item }
    hook.Add( "StartCommand", reloadHook, holdReload )
    timer.Create( timerName, tickInterval, maxTicks, tick )

    permaPrint( "GLEE: " .. bot:Nick() .. " is going to place " .. item .. " on " .. target:Nick() .. "..." )

end, nil, "Has a bot buy a placable and place it on a player.", FCVAR_CHEAT )
