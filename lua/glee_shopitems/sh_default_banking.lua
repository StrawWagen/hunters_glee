
-- shared between deposit and withdraw
local function hasBankAccount( purchaser )
    if not purchaser:BankHasAccount() then return false, "You haven't opened a bank account yet." end
    return true

end

local function atmAlreadyExists()
    for _, ent in ipairs( ents.FindByClass( "glee_bank_atm" ) ) do
        if CLIENT and ent:IsDormant() then continue end
        if IsValid( ent ) then return true end

    end
    return false

end

local function noExistingAtm()
    if atmAlreadyExists() then return false, "The ATM is already active." end
    return true

end

local ATM_AUTO_SCORE = 10000
local spawnATMNearPlayer
local belowCenterChecks = {
    Vector( 0, 0, -100 ),
    Vector( 0, 0, -200 ),
    Vector( 0, 0, -300 ),
    Vector( 0, 0, -400 ),
    Vector( 0, 0, -800 ),
}

local tooCloseDist = 200^2

local function isGoodATMPos( pos, tooClosePos )
    for _, check in ipairs( belowCenterChecks ) do
        local checkPos = pos + check
        local solid = bit.band( util.PointContents( checkPos ), CONTENTS_SOLID ) ~= 0
        -- TODO: optimize
        if not solid then
            local underDisplacement = terminator_Extras.posIsUnderDisplacement( checkPos )
            if underDisplacement then
                solid = true

            end
        end
        if not solid then return nil end

    end

    if tooClosePos and pos:DistToSqr( tooClosePos ) < tooCloseDist then return nil end

    local tr = util.TraceLine( {
        start  = pos,
        endpos = pos + Vector( 0, 0, 45 ),
        mask   = MASK_SOLID_BRUSHONLY,
    } )

    if tr.Hit then return nil end
    return pos

end

local function isATMPlacable( purchaser )
    if not purchaser:IsOnNavmesh() then return false, "You're somewhere wrong... The ATM has nowhere to surface..." end
    if not isGoodATMPos( purchaser:GetPos() ) then return false, "You're somewhere wrong... There's some kind of void or overhang below you..." end
    return true

end

if SERVER then

    local function marchForSurfacePos( startArea, tooClosePos )
        -- skip the player's own area; march outward through adjacent areas
        local checked = { [startArea] = true }
        local queue   = {}

        for _, adj in ipairs( startArea:GetAdjacentAreas() ) do
            checked[adj] = true
            queue[#queue + 1] = adj

        end

        local i = 1
        while i <= #queue and i <= 80 do
            local area = queue[i]
            i = i + 1

            local pos = isGoodATMPos( area:GetCenter(), tooClosePos )
            if pos then return pos end

            for _, adj in ipairs( area:GetAdjacentAreas() ) do
                if checked[adj] then continue end
                checked[adj] = true
                queue[#queue + 1] = adj

            end
        end

        return nil

    end

    spawnATMNearPlayer = function( ply, isOwner )
        local startArea = ply:GetNavAreaData()
        if not IsValid( startArea ) then return end

        local surfacePos = marchForSurfacePos( startArea, ply:WorldSpaceCenter() )

        -- no good pos? try under player!
        -- very evil
        if not surfacePos then
            surfacePos = ply:GetPos()
            if not isGoodATMPos( surfacePos ) then return end

        end

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

        ent:SetPos( surfacePos + Vector( 0, 0, -ent.BurrowDepth ) )
        ent:SetAngles( toPlayer:Angle() )
        ent:Spawn()
        ent:StartBurrowingToPos( surfacePos, ent.BurrowDuration, isOwner and ply or nil )

        return ent

    end

    -- Auto-spawn: arrive when any alive player exceeds 10 000 score.

    local function ATMArriveFor( ply )
        local atm = spawnATMNearPlayer( ply, false ) -- no owner for auto-spawns
        if not IsValid( atm ) then return end

        timer.Simple( 2, function()
            if not IsValid( ply ) then return end
            huntersGlee_Announce( player.GetAll(), 100, 6, ply:Nick() .. "'s gluttonous wealth knows no bounds...\nThe ATM has arrived..." )

        end )
    end

    hook.Add( "huntersglee_givenscore", "glee_atm_autospawn_check", function( scorer, addedscore )
        if not IsValid( scorer ) then return end
        if addedscore < 1 then return end

        local newScore = scorer:GetScore()
        if newScore >= ATM_AUTO_SCORE then
            if atmAlreadyExists() then return end
            ATMArriveFor( scorer )

        end
    end )

    hook.Add( "huntersglee_round_pre_into_inactive", "glee_atm_autospawn", function()
        timer.Create( "glee_atm_autospawn", 5, 10, function()
            if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_INACTIVE then return end
            if atmAlreadyExists() then timer.Remove( "glee_atm_autospawn" ) return end

            local richest      = nil
            local richestScore = ATM_AUTO_SCORE

            for _, ply in ipairs( player.GetAll() ) do
                if not ply:IsPlayer() then continue end
                if ply:Health() <= 0 then continue end
                local s = ply:GetScore()
                if s <= richestScore then continue end

                richestScore = s
                richest = ply

            end

            if not IsValid( richest ) then return end

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
            return math.Clamp( purchaser:GetScore(), 10, 200 )

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
            local toDeposit = math.Clamp( purchaser:GetScore(), 10, 200 )
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
             .. "A Complimentary ATM will arrive if anyone exceeds " .. ATM_AUTO_SCORE .. " score!",
        shCost    = 1000,
        cooldown  = 0,
        tags      = { "BANK" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 200,
        shCanShowInShop = { hasBankAccount },
        shPurchaseCheck = { hasBankAccount, noExistingAtm, isATMPlacable },
        svOnPurchaseFunc = function( purchaser )
            spawnATMNearPlayer( purchaser, true )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )
