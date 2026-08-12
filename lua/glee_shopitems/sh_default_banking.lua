
local shopHelpers = GAMEMODE.shopHelpers

-- shared between deposit and withdraw
local function hasBankAccount( purchaser )
    if not purchaser:BankHasAccount() then return false, "You haven't opened a bank account yet." end
    return true

end

local function noExistingAtm()
    if terminator_Extras.glee_ATMExists() then return false, "The ATM is already active." end
    return true

end

local function ghostCanPurchase( purchaser )
    if IsValid( purchaser.ghostEnt ) then return false, "You're already placing something!\nPlace it, or right click to CANCEL placing it!" end
    return true

end

local ATM_AUTO_SCORE = 5000
local spawnATMNearPlayer

local tooCloseDist = 200^2

-- A cheap approximation of the sweep, which only the server can afford to run. It
-- passes players the sweep will then fail, hence the refund in svOnPurchaseFunc.
local function isATMPlacable( purchaser )
    if not purchaser:IsOnNavmesh() then return false, "You're somewhere wrong... The ATM has nowhere to surface..." end

    local cheapest = terminator_Extras.glee_CheapestATMCost()
    if purchaser:GetScore() < cheapest then return false, "The ATM costs at least " .. cheapest .. " to bring in." end

    return true

end

if SERVER then

    -- how the ATM ranks candidate spots: foot traffic matters more than being close
    local heatScoreWeight = 0.7 -- 0 = only care about proximity, 1 = only care about foot traffic

    -- An area's center as a priced candidate, or nil if the ATM has no business there.
    local function priceAreaSpot( area, tooClosePos, maxSpend )
        if math.min( area:GetSizeX(), area:GetSizeY() ) <= 50 then return end

        local pos = area:GetCenter()
        if pos:DistToSqr( tooClosePos ) < tooCloseDist then return end

        local method, cost = terminator_Extras.glee_ATMArrivalAt( pos )
        if not method then return end
        if cost > maxSpend then return end

        return {
            pos        = pos,
            method     = method,
            cost       = cost,
            heat       = GAMEMODE.navmeshActivityHeatmap[area] or 0,
            dist       = pos:Distance( tooClosePos ),
            underwater = area:IsUnderwater(),
        }

    end

    -- Every spot within reach, priced. The cheapest arrival wins outright, then dry land
    -- over water; heat and proximity only decide between spots that tie on both.
    local function marchForSurfaceSpot( startArea, tooClosePos, maxSpend )
        -- skip the player's own area; march outward through adjacent areas
        local checked = { [startArea] = true }
        local queue   = {}

        for _, adj in ipairs( startArea:GetAdjacentAreas() ) do
            checked[adj] = true
            queue[#queue + 1] = adj

        end

        local candidates = {}
        local cheapestCost = math.huge

        local i = 1
        while i <= #queue and i <= 80 do
            local area = queue[i]
            i = i + 1

            local candidate = priceAreaSpot( area, tooClosePos, maxSpend )
            if candidate then
                candidates[#candidates + 1] = candidate
                if candidate.cost < cheapestCost then cheapestCost = candidate.cost end

            end

            for _, adj in ipairs( area:GetAdjacentAreas() ) do
                if checked[adj] then continue end
                checked[adj] = true
                queue[#queue + 1] = adj

            end
        end

        if #candidates == 0 then return nil end

        local cheapest = {}
        local cheapestDry = {}

        for _, candidate in ipairs( candidates ) do
            if candidate.cost ~= cheapestCost then continue end

            cheapest[#cheapest + 1] = candidate
            if not candidate.underwater then
                cheapestDry[#cheapestDry + 1] = candidate

            end
        end

        -- an ATM standing in water is a last resort, only rank the wet ones when that's all there is
        local ranking = cheapest
        if #cheapestDry > 0 then
            ranking = cheapestDry

        end

        -- scale against what's actually being ranked, or a dropped wet spot could set the ceiling
        local maxHeat = 0
        local maxDist = 1

        for _, candidate in ipairs( ranking ) do
            if candidate.heat > maxHeat then maxHeat = candidate.heat end
            if candidate.dist > maxDist then maxDist = candidate.dist end

        end

        -- best blend of foot traffic ( want lots ) and distance ( want little ), both scaled to 0-1
        local bestSpot
        local bestScore = -math.huge
        for _, candidate in ipairs( ranking ) do
            local heatScore = maxHeat > 0 and ( candidate.heat / maxHeat ) or 0
            local nearScore = 1 - ( candidate.dist / maxDist )
            local score = heatScoreWeight * heatScore + ( 1 - heatScoreWeight ) * nearScore

            if score > bestScore then
                bestScore = score
                bestSpot = candidate

            end
        end

        return bestSpot

    end

    -- Returns the ATM, the method it is arriving by, and what that costs. maxSpend
    -- rules out arrivals the player can't pay for, so the purchase never has to be
    -- taken back after the sweep has already run.
    spawnATMNearPlayer = function( ply, isOwner, maxSpend )
        local startArea = ply:GetNavAreaData()
        if not IsValid( startArea ) then return end

        local spot = marchForSurfaceSpot( startArea, ply:WorldSpaceCenter(), maxSpend )

        -- no good pos? try under player!
        -- very evil
        if not spot then
            local pos = ply:GetPos()
            local method, cost = terminator_Extras.glee_ATMArrivalAt( pos )
            if not method or cost > maxSpend then return end

            spot = { pos = pos, method = method, cost = cost }

        end

        local surfacePos = spot.pos
        surfacePos.z = surfacePos.z - 2 -- bit into the ground

        local toPlayer = ply:GetPos() - surfacePos
        toPlayer.z = 0

        if toPlayer:LengthSqr() < 1 then
            toPlayer = ply:GetForward()
            toPlayer.z = 0

        end

        toPlayer:Normalize()

        local ent = ents.Create( "glee_bank_atm" )
        if not IsValid( ent ) then return end

        ent:SetPos( surfacePos )
        ent:SetAngles( toPlayer:Angle() )
        ent:Spawn()
        ent:StartArrival( spot.method, surfacePos, isOwner and ply or nil )

        return ent, spot.method, spot.cost

    end

    -- Auto-spawn: the house buys one, whatever the arrival ends up costing, once
    -- anyone passes ATM_AUTO_SCORE.

    local function ATMArriveFor( ply )
        local atm = spawnATMNearPlayer( ply, false, math.huge ) -- no owner for auto-spawns, and the house pays
        if not IsValid( atm ) then return end

        timer.Simple( 2, function()
            if not IsValid( ply ) then return end
            huntersGlee_Announce( player.GetAll(), 100, 6, ply:Nick() .. "'s gluttonous wealth knows no bounds...\nThe ATM has arrived..." )

        end )
    end

    local nextCheck = 0

    hook.Add( "huntersglee_givenscore", "glee_atm_autospawn_check", function( scorer, addedscore )
        if not IsValid( scorer ) then return end
        if addedscore < 1 then return end

        local newScore = scorer:GetScore()
        if newScore >= ATM_AUTO_SCORE then
            if nextCheck > CurTime() then return end
            nextCheck = CurTime() + 1
            if terminator_Extras.glee_ATMExists() then return end
            ATMArriveFor( scorer )

        end
    end )

    hook.Add( "huntersglee_round_pre_into_inactive", "glee_atm_autospawn", function()
        timer.Create( "glee_atm_autospawn", 5, 10, function()
            if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_INACTIVE then return end
            if terminator_Extras.glee_ATMExists() then timer.Remove( "glee_atm_autospawn" ) return end

            local richest, richestScore = GAMEMODE:GetRichestPlayer()

            if richestScore < ATM_AUTO_SCORE then return end

            ATMArriveFor( richest )

        end )
    end )
end

local items = {
    ["bankopenaccount"] = {
        name = "Bank Account",
        desc = "Open a bank account.",
        simpleCostDisplay = true,
        shCost = function( purchaser )
            if purchaser:BankHasAccount() then
                local existingAccount = purchaser:BankAccount()
                return existingAccount.funds

            end
            return 1000

        end,
        cooldown = 0,
        tags = { "BANK" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 0,
        shPurchaseCheck = function( purchaser )
            if purchaser:BankHasAccount() then return false, "You've already opened a bank account." end
            return true

        end,
        svOnPurchaseFunc = function( purchaser )
            timer.Simple( 0.05, function()
                if not IsValid( purchaser ) then return end
                purchaser:BankOpenAccount()

            end )
        end,
    },
    ["bankdeposit"] = {
        name = "Deposit",
        desc = function()
            local chargePeriod = gleefunc_BankChargePeriod()
            local chargePeriodDays = chargePeriod / 86400
            chargePeriodDays = math.Round( chargePeriodDays, 2 )

            local periodCharge = gleefunc_BankChargePerPeriod()
            local processingFee = gleefunc_BankProcessingFee()

            local days = "days."
            if chargePeriodDays == 1 then
                days = "day."

            end

            local descTbl = {
                "Deposit score for another time.\n",
                "The bank has a " .. processingFee .. "% processing fee when depositing.\n",
                "Idle FEES! of \"" .. periodCharge .. "\"% of your entire balance, ",
                "will apply every \"" .. chargePeriodDays .. "\" real-time " .. days,

            }

            return table.concat( descTbl, "" )

        end,
        fakeCost = true, -- score removal is handled in svOnPurchaseFunc
        shCost = function( purchaser )
            return math.Clamp( purchaser:GetScore(), 10, 100 )

        end,
        cooldown = 0.5,
        tags = { "BANK" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 100,
        shPurchaseCheck = hasBankAccount,
        svOnPurchaseFunc = function( purchaser )
            local toDeposit = math.Clamp( purchaser:GetScore(), 10, 100 )
            purchaser:GivePlayerScore( -toDeposit )

            purchaser:BankDepositScoreFullHandle( toDeposit )

        end,
    },
    ["bankwithdraw"] = {
        name = "Withdraw",
        desc = "Withdraw 100 score from your account.",
        fakeCost = true,
        shCost = -100,
        cooldown = 0.5,
        tags = { "BANK" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 150,
        shPurchaseCheck = { hasBankAccount, function( purchaser )
            if not purchaser:BankCanDeposit( -gleefunc_BankMinFunds() ) then return false, "Your account is below the withdrawl threshold!!\nIt will be closed when the next idle fee is applied!!!" end
            return true

        end },
        svOnPurchaseFunc = function( purchaser )
            purchaser:BankDepositScore( -gleefunc_BankMinFunds() )
            purchaser:GivePlayerScore( gleefunc_BankMinFunds() )

        end,
    },
    ["bankatm"] = {
        name = "Bank ATM",
        desc = "Request the ATM\n"
             .. "The one stop shop for large deposits, withdrawls\n"
             .. "Half of the deposit fee gets set aside, a cut for YOU, as the owner.\n"
             .. "But it can be stolen...\n"
             .. "Cost varies, requests on solid ground are the cheapest...\n"
             .. "A Complimentary ATM will arrive if anyone exceeds " .. ATM_AUTO_SCORE .. " score!",
        shCost    = 0,
        fakeCost  = true, -- the sweep decides the price, so it is charged in svOnPurchaseFunc
        costDecorative = { "-750", "-1500" },
        cooldown  = 0,
        tags      = { "BANK" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 200,
        shCanShowInShop = { hasBankAccount, shopHelpers.aliveCheck },
        shPurchaseCheck = { hasBankAccount, shopHelpers.aliveCheck, noExistingAtm, isATMPlacable },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            local atm, _method, cost = spawnATMNearPlayer( purchaser, true, purchaser:GetScore() )

            if not IsValid( atm ) then
                GAMEMODE:RefundShopItemCooldown( purchaser, itemIdentifier )
                huntersGlee_Announce( { purchaser }, 10, 5, "The ATM has nowhere to arrive that you can afford." )
                return

            end

            purchaser:GivePlayerScore( -cost )
            GAMEMODE:sendPurchaseConfirm( purchaser, -cost )

        end,
    },
    ["bankatmplace"] = {
        name = "The ATM",
        desc = "Send the ATM somewhere of your choosing.\n"
             .. "Place wisely.\n"
             .. "Burrowing is cheapest...",
        shCost = 0,
        costDecorative = { "-750", "-1500" },
        cooldown = 0,
        tags = { "BANK", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 201,
        shCanShowInShop = { hasBankAccount, shopHelpers.deadCheck },
        shPurchaseCheck = { hasBankAccount, shopHelpers.deadCheck, ghostCanPurchase, noExistingAtm },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            shopHelpers.setupPlacable( "glee_atm_placer", purchaser, itemIdentifier )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )
