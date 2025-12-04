
-- shared between deposit and withdraw
local function hasBankAccount( purchaser )
    if not purchaser:BankHasAccount() then return false, "You haven't opened a bank account yet." end
    return true

end

local items = {
    [ "bankopenaccount" ] = {
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
    [ "bankdeposit" ] = {
        name = "Deposit",
        desc = function()
            local chargePeriod = gleefunc_BankChargePeriod()
            local chargePeriodDays = chargePeriod / 86400
            chargePeriodDays = math.Round( chargePeriodDays, 2 )

            local periodCharge = gleefunc_BankChargePerPeriod()

            local days = "days."
            if chargePeriodDays == 1 then
                days = "day."

            end

            local descTbl = {
                "Deposit score for another time.\n",
                "The bank has a 10% procesing fee when depositing.\n",
                "Idle fees of \"" .. periodCharge .. "\"% of your entire balance, ",
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

            toDeposit = toDeposit * 0.9 -- ten percent processing fee
            purchaser:BankDepositScore( toDeposit )

        end,
    },
    [ "bankwithdraw" ] = {
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
}

GAMEMODE:GobbleShopItems( items )
