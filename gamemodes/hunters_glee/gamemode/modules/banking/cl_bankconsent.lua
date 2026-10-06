--[[
    The bank's paperwork: the terms a bank purchase makes you agree to first.

    A shop item opts in through clBeforePurchase, naming its document here:
        clBeforePurchase = function( buy, check ) GAMEMODE:OpenBankConsentForm( "skull_gains", buy, check ) end,

    Figures are read live as the form opens.
]]

local GAMEMODE = GAMEMODE or GM

local FRAME_MAX_H_1080P = 775 -- the settings menu's

local function realTimeDays( seconds )
    return math.Round( seconds / 86400, 2 )

end

-- the map's times the misery's, as the server multiplies them. The server pushes both on
-- joining, on a new misery, and after every round, so nil is rare: a misery name the push
-- didn't match
local function currentEscapeMultiplier()
    local mapName = game.GetMap()
    local spawnsetName = GetGlobalString( "GLEE_SpawnSetName", "" )

    -- 0 is the client cache's "not here yet", real multipliers never go below 0.15
    local mapMul = GAMEMODE:GetMapsEscapeMultiplier( mapName )
    if mapMul <= 0 then return end

    local spawnsetMul = 1 -- the server's answer for no misery
    if spawnsetName ~= "" then
        spawnsetMul = GAMEMODE:GetSpawnsetsEscapeMultiplier( spawnsetName )
        if spawnsetMul <= 0 then return end

    end

    return math.Round( mapMul * spawnsetMul, 2 )

end

local function multiplierClause( escapeMul )
    if escapeMul then
        return "At the time of reading, the Escape Multiplier on this map, under this Misery, stands at " .. escapeMul .. "x."

    end
    return "At the time of reading, the Bank declines to disclose the Escape Multiplier. It may be found on the scoreboard."

end


-- Documents -----------------------------------------------------------------

local documents = {}

documents.account = function( ply )
    local openingFee = GAMEMODE:shopItemCost( "bankopenaccount", ply )
    local processingFee = GAMEMODE:GetBankProcessingFee()
    local idleFee = GAMEMODE:GetBankChargePerPeriod()
    local chargePeriod = realTimeDays( GAMEMODE:GetBankChargePeriod() )
    local minFunds = GAMEMODE:GetBankMinFunds()

    return "THE BANK: ACCOUNT AGREEMENT", {
        {
            heading = "PARTIES",
            body = "This Account Agreement (the \"Agreement\") is entered into by and between THE BANK, including its parents, subsidiaries, affiliates, successors, assigns, ATMs, and any entity, Temporarily Bodied or otherwise, acting on its behalf (collectively, the \"Bank\"), and " .. ply:Nick() .. " (the \"Account Holder\"), as Free Soul, Temporarily Bodied, and Escaped Soul alike, and in any other state recognised or unrecognised by the Bank.",
        },
        {
            heading = "DEFINITIONS",
            body = table.concat( {
                "(a) \"Score\" means the unit in which every obligation under this Agreement is denominated, and which the Account Holder acknowledges having obtained by means the Bank declines to examine.",
                "(b) \"Funds\" means Score held by the Bank on the Account Holder's behalf. For the avoidance of doubt, the Bank holds the Funds. The Account Holder does not.",
                "(c) \"Real-Time\" means time as it passes outside the Hunt, which continues to pass whether or not the Account Holder is present, connected, or Temporarily Bodied.",
                "(d) The Account Holder is a Free Soul, save while occupying a temporary shell, when they are Temporarily Bodied, and once beyond the Hunt, when they are an Escaped Soul. An Account Holder who takes up a new temporary shell is Of New Body, and remains the Account Holder.",
                "(e) \"Hunter\" means any entity pursuing the Account Holder. The Bank is not a Hunter. The Bank is not responsible for Hunters.",
                "(f) Words importing the singular include the plural, words importing Free Souls include the Temporarily Bodied, and the word \"refund\" has no meaning under this Agreement.",
            }, "\n" ),
        },
        {
            heading = "OPENING OF THE ACCOUNT",
            body = table.concat( {
                "(a) In consideration of the opening of the Account, the Account Holder shall pay an opening fee of " .. openingFee .. " Score, immediately and in full.",
                "(b) The opening fee is non-refundable, non-transferable, non-negotiable, and is not deposited into the Account.",
                "(c) The Account Holder may hold no more than one (1) Account at a time. Where a previous Account has been closed, as Accounts left to idle tend to be, under the Closure provisions below, that Account, together with all Funds and Bank Items on it, shall be deemed never to have existed.",
            }, "\n" ),
        },
        {
            heading = "DEPOSITS",
            body = table.concat( {
                "(a) A processing fee of " .. processingFee .. "% shall be deducted from every deposit, rounded up, in the Bank's favour.",
                "(b) Deposits made at an ATM are subject to the same processing fee, a portion of which may be paid to the owner of said ATM, at the Bank's discretion and to the Account Holder's indifference.",
                "(c) The Bank accepts deposits from Free Souls, Temporarily Bodied, and Escaped Souls alike.",
            }, "\n" ),
        },
        {
            heading = "WITHDRAWALS",
            body = table.concat( {
                "(a) The Account Holder may withdraw Funds, provided the Account is left with a balance greater than zero (0).",
                "(b) Withdrawals made at an ATM are subject to the processing fee.",
                "(c) A withdrawal may leave the Account below the threshold of " .. minFunds .. " Score. See Closure.",
            }, "\n" ),
        },
        {
            heading = "IDLE FEES",
            body = table.concat( {
                "(a) Every " .. chargePeriod .. " Real-Time Day(s), the Bank shall charge an idle fee of " .. idleFee .. "% of the Account's entire balance.",
                "(b) Idle fees accrue whether or not the Account Holder is idle. \"Idle\" refers to the Funds.",
                "(c) Idle fees are charged on the Bank's schedule, not the Account Holder's. The Account Holder waives any right to be notified, consulted, awake, or Temporarily Bodied.",
            }, "\n" ),
        },
        {
            heading = "CLOSURE",
            body = table.concat( {
                "(a) Where, once an idle fee has been charged, the balance is below " .. minFunds .. " Score, the Account shall be closed without notice.",
                "(b) Upon closure, all remaining Funds, and all Bank Items held on the Account, are forfeit to the Bank.",
                "(c) Closure is final. A new Account may be opened under a new Agreement, for a new opening fee.",
            }, "\n" ),
        },
    }

end

documents.skull_gains = function( _ply )
    local standardRate = GAMEMODE:GetSkullReward()
    local enhancedRate = GAMEMODE:GetSkullRewardGains()
    local everyoneBonus = GAMEMODE:GetSkullRewardGainsEveryoneEscaped()
    local escapeReward = GAMEMODE:GetEscapeReward()
    local escapeRewardEveryone = GAMEMODE:GetEscapeRewardEveryoneEscaped()

    local escapeMul = currentEscapeMultiplier()
    local exampleMul = escapeMul or 1
    local exampleSkulls = 10
    local exampleGains = math.Round( exampleSkulls * ( enhancedRate + everyoneBonus ) * exampleMul, 2 )
    local exampleStandard = exampleSkulls * standardRate

    return "SKULL GAINS:\nADDENDUM TO THE ACCOUNT AGREEMENT", {
        {
            heading = "SCOPE",
            body = "This Addendum supplements, and does not replace, the Account Agreement previously accepted by the Account Holder, whether or not the Account Holder read it. Where the two conflict, whichever reading favours the Bank shall prevail.",
        },
        {
            heading = "THE SERVICE",
            body = table.concat( {
                "(a) Without Skull Gains, each skull carried out of an escape is cashed out at the standard rate of " .. standardRate .. " Score, which the Bank describes as \"a pittance\". The standard rate is not multiplied by anything.",
                "(b) With Skull Gains, each skull is instead cashed out at the enhanced rate of " .. enhancedRate .. " Score.",
                "(c) The enhanced rate, including any Boon, is then multiplied by the Escape Multiplier.",
                "(d) The enhanced rate is paid out as Score, to the Account Holder, and not into the Account. The Bank wants nothing to do with skulls.",
            }, "\n" ),
        },
        {
            heading = "THE BOON",
            body = table.concat( {
                "(a) A \"Boon\" occurs where every soul present at the End of the Hunt is an Escaped Soul.",
                "(b) Upon a Boon, the enhanced rate is increased by " .. everyoneBonus .. " Score per skull, to " .. ( enhancedRate + everyoneBonus ) .. " Score per skull, before the Escape Multiplier.",
                "(c) Upon a Boon, the escape reward of every Escaped Soul is increased by " .. escapeRewardEveryone .. " Score, with or without Skull Gains.",
                "(d) Whether a Boon occurs depends on souls other than the Account Holder. The Bank makes no representation as to their reliability.",
            }, "\n" ),
        },
        {
            heading = "THE ESCAPE MULTIPLIER",
            body = table.concat( {
                "(a) The \"Escape Multiplier\" is the map's multiplier, multiplied by the Misery's multiplier.",
                "(b) Each is calculated from how many souls have escaped it, against how many have not. The fewer that escape, the higher it climbs. The more that escape, the lower it sinks, to no lower than 0.15x. It also rises, slowly, while nothing escapes at all.",
                "(c) " .. multiplierClause( escapeMul ),
                "(d) The Escape Multiplier also applies to the escape reward of " .. escapeReward .. " Score, Boon included. That reward is paid with or without Skull Gains, and is not the subject of this Addendum.",
            }, "\n" ),
        },
        {
            heading = "ILLUSTRATION",
            body = "By way of illustration only: " .. exampleSkulls .. " skulls, upon a Boon, at " .. exampleMul .. "x, cash out at " .. exampleSkulls .. " x (" .. enhancedRate .. " + " .. everyoneBonus .. ") x " .. exampleMul .. " = " .. exampleGains .. " Score. Without Skull Gains, the same skulls cash out at " .. exampleSkulls .. " x " .. standardRate .. " = " .. exampleStandard .. " Score. Past performance does not guarantee future skulls.",
        },
        {
            heading = "PROVENANCE OF SKULLS",
            body = "Skulls are the precious remains of temporary shells. The Bank does not ask whose. The Account Holder warrants that every skull was obtained lawfully, or at least that its former occupant had no further use for it.",
        },
        {
            heading = "DURATION",
            body = "Skull Gains remains on the Account until the Account is closed, whereupon it is forfeit to the Bank along with everything else.",
        },
    }

end

documents.skull_loophole = function( ply )
    local connectionFee = GAMEMODE:shopItemCost( "bankskullloophole", ply )
    local connectionDays = realTimeDays( GAMEMODE.bankItems.skull_loophole.lifetime )
    local processingFee = GAMEMODE:GetBankProcessingFee()

    local relayMul = GAMEMODE:GetSkullRelayMultiplier()
    local enhancedRate = GAMEMODE:GetSkullRewardGains()
    local everyoneBonus = GAMEMODE:GetSkullRewardGainsEveryoneEscaped()

    local escapeMul = currentEscapeMultiplier()
    local ratesClause
    if escapeMul then
        local relayedRate = math.Round( relayMul * enhancedRate * escapeMul, 2 )
        local relayedRateEveryone = math.Round( relayMul * ( enhancedRate + everyoneBonus ) * escapeMul, 2 )
        ratesClause = "At the Escape Multiplier in effect at the time of reading, " .. escapeMul .. "x, each relayed skull deposits " .. relayedRate .. " Score, or " .. relayedRateEveryone .. " Score upon a Boon."

    else
        ratesClause = "Each relayed skull deposits " .. relayMul .. " x " .. enhancedRate .. " x the Escape Multiplier, or " .. relayMul .. " x (" .. enhancedRate .. " + " .. everyoneBonus .. ") x the Escape Multiplier upon a Boon. The Bank declines to disclose the Escape Multiplier at this time."

    end

    return "OFF-WORLD SKULL RELAY: SERVICE AGREEMENT", {
        {
            heading = "PARTIES",
            body = "This Service Agreement is between the Account Holder, the Bank, and the Relay's caretakers (the \"Caretakers\"), a third party whose identity, location, and planet of residence the Bank is not at liberty to disclose.",
        },
        {
            heading = "FEES",
            body = table.concat( {
                "(a) The connection fee is " .. connectionFee .. " Score, being a base fee of " .. GAMEMODE.SkullRelayBaseFee .. " Score, plus a surcharge of " .. GAMEMODE.SkullRelayBalanceFee .. "% of the Account's current balance.",
                "(b) The Account Holder acknowledges that the Caretakers can see their balance, and that this is why.",
                "(c) Surge pricing is in effect at all times.",
            }, "\n" ),
        },
        {
            heading = "THE SERVICE",
            body = table.concat( {
                "(a) While connected, the enhanced rate under the Skull Gains Addendum, including any Boon as defined therein, is multiplied by " .. relayMul .. ", before the Escape Multiplier is applied.",
                "(b) " .. ratesClause,
                "(c) Relayed skulls are deposited directly into the Account, and are exempt from the processing fee of " .. processingFee .. "%, which the Bank notes with regret.",
                "(d) Only skulls are relayed. The escape reward itself is paid as Score, as it always was.",
                "(e) Relayed deposits remain subject to idle fees, closure, forfeiture, and everything else.",
                "(f) The Relay is offered only to holders of Skull Gains. The Caretakers do not deal with amateurs.",
            }, "\n" ),
        },
        {
            heading = "DURATION",
            body = table.concat( {
                "(a) The connection lasts " .. connectionDays .. " Real-Time Day(s) from purchase, after which the Caretakers disconnect the Account Holder without notice.",
                "(b) The connection's time is not paused by the Account Holder ceasing to be Temporarily Bodied, disconnection, sleep, or the End of a Hunt.",
                "(c) The Caretakers reserve the right to disconnect the Account Holder at any time, for any reason, or for none.",
            }, "\n" ),
        },
    }

end

-- under every document. Fresh each call, the opener numbers headings in place
local function generalProvisions()
    return {
        {
            heading = "LIMITATION OF LIABILITY",
            body = table.concat( {
                "(a) The Bank is not liable for any loss of Score, Funds, temporary shells, skulls or sanity, arising from the Hunt, from Hunters, from other Account Holders, from the ATM, or from this Agreement.",
                "(b) Without limiting the above, the Bank is not liable for any ATM landing on, burrowing beneath, or otherwise arriving near the Account Holder.",
                "(c) The Account Holder's sole remedy for any dissatisfaction is to stop being dissatisfied.",
            }, "\n" ),
        },
        {
            heading = "EMBODIMENT",
            body = "This Agreement binds the Account Holder as a Free Soul, Temporarily Bodied, and as an Escaped Soul, and is unaffected by any change between them, or by the Account Holder being Of New Body.",
        },
        {
            heading = "AMENDMENT",
            body = "The Bank may amend any fee, rate, period or threshold herein at any time, by changing the Hunt's parameters. Continued existence, in any state, constitutes acceptance.",
        },
        {
            heading = "GOVERNING LAW",
            body = "This Agreement is governed by the laws of the Hunt. Any dispute shall be submitted to the Bank in writing, and placed on file.",
        },
        {
            heading = "SEVERABILITY",
            body = "Should any provision of this Agreement be held unenforceable, it shall be enforced anyway.",
        },
        {
            heading = "ENTIRE AGREEMENT",
            body = "This Agreement constitutes the entire agreement between the parties, and supersedes all prior representations, including anything said in the shop. By signing below, the Account Holder confirms they have read this Agreement in full, and that they are in fact, a Garry's Mod player with the rare and exceptional ability to read.",
        },
    }

end


-- The form --------------------------------------------------------------------

local currentFrame

-- buy is called on agreeing, nothing is on declining. check is clBeforePurchase's, the
-- form won't be signed while it says no
function GAMEMODE:OpenBankConsentForm( documentName, buy, check )
    local document = documents[documentName]
    if not document then
        ErrorNoHaltWithStack( "glee bank consent: no document named " .. tostring( documentName ) .. "\n" )
        return

    end

    local ply = LocalPlayer()

    local title, sections = document( ply )
    table.Add( sections, generalProvisions() )

    for index, section in ipairs( sections ) do
        section.heading = "ARTICLE " .. index .. ". " .. section.heading

    end

    if IsValid( currentFrame ) then currentFrame:Remove() end

    local frame = vgui.Create( "glee_frame" )
    frame:SetPadContents( false ) -- the form brings its own

    local form = vgui.Create( "glee_consentform", frame )
    form:SetTitle( title )
    form:SetSigner( ply:Nick() )
    form:SetCheck( check )
    form:SetSections( sections )
    form:Dock( FILL )

    -- bought on signing, so closing the frame mid-stamp can't undo it
    function form:OnAgree()
        buy()

    end

    function form:OnStamped()
        frame:AlphaTo( 0, 0.35, 0, function()
            if IsValid( frame ) then frame:Close() end

        end )
    end

    function form:OnDecline()
        frame:Close()

    end

    frame:SizeToContents( math.min( frame:Style():Scaled( FRAME_MAX_H_1080P ), ScrH() * 0.9 ) )
    frame:Center()

    terminator_Extras.easyClosePanel( frame )
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    currentFrame = frame

end
