
-- ─── Helpers (shared + server) ────────────────────────────────────────────────

local function atmAlreadyExists()
    for _, ent in ipairs( ents.FindByClass( "glee_bank_atm" ) ) do
        if IsValid( ent ) then return true end

    end
    return false

end

local function hasBankAccount( purchaser )
    if not purchaser:BankHasAccount() then return false, "You haven't opened a bank account yet." end
    return true

end

local function noExistingAtm()
    if atmAlreadyExists() then return false, "An ATM is already active." end
    return true

end

-- ─── Server-only: spawn helpers & auto-spawn ─────────────────────────────────

if SERVER then

    local function spawnATMNearPlayer( ply, isOwner )
        local forward = ply:GetForward()
        forward.z = 0
        if forward:LengthSqr() < 0.01 then forward = Vector( 1, 0, 0 ) end
        forward:Normalize()

        local aheadPos = ply:GetPos() + forward * 150

        local tr = util.QuickTrace( aheadPos + Vector( 0, 0, 200 ), Vector( 0, 0, -400 ), ply )

        local surfacePos
        if tr.Hit then
            surfacePos = tr.HitPos + tr.HitNormal * 2

        else
            surfacePos = ply:GetPos()

        end

        local ent = ents.Create( "glee_bank_atm" )
        if not IsValid( ent ) then return end

        ent:SetPos( surfacePos + Vector( 0, 0, -200 ) )
        ent:SetAngles( ( -forward ):Angle() )
        ent:Spawn()
        ent:StartBurrowingToPos( surfacePos, ent.BurrowDuration, isOwner and ply or nil )

        return ent

    end

    -- Auto-spawn: arrive when any alive player exceeds 10 000 score.
    local ATM_AUTO_SCORE = 10000

    timer.Create( "glee_atm_autospawn", 30, 0, function()
        if not GAMEMODE then return end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
        if atmAlreadyExists() then return end

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

        spawnATMNearPlayer( richest, false ) -- no owner for auto-spawns
        huntersGlee_Announce( player.GetAll(), 5, 6, "An ATM has arrived!" )

    end )

    -- Purchase handler (captured in closure so it can reference spawnATMNearPlayer)
    local function svBuyATM( purchaser )
        spawnATMNearPlayer( purchaser, true )

    end

    -- Register via post-gobble so the closure survives the file include.
    hook.Add( "glee_post_shopitemgobble", "glee_atm_register_svfunc", function()
        local item = GAMEMODE.shopItems and GAMEMODE.shopItems["bankATM"]
        if not item then return end

        item.svOnPurchaseFunc = svBuyATM
        hook.Remove( "glee_post_shopitemgobble", "glee_atm_register_svfunc" )

    end )

end

-- ─── Shop item ────────────────────────────────────────────────────────────────

local items = {
    ["bankATM"] = {
        name = "Bank ATM",
        desc = "Deploy an ATM nearby.\n"
             .. "Enables large deposits and withdrawals ($100 / $500 / $1000).\n"
             .. "Half of the deposit fee goes into the ATM pool.\n"
             .. "Purchasing makes you the owner — only you can withdraw the pool.\n"
             .. "Very tanky. Can be destroyed to claim the pool.",
        shCost    = 1000,
        cooldown  = 0,
        tags      = { "BANK" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 200,
        shPurchaseCheck = { hasBankAccount, noExistingAtm },
        svOnPurchaseFunc = function() end, -- replaced post-gobble on server
    },
}

GAMEMODE:GobbleShopItems( items )
