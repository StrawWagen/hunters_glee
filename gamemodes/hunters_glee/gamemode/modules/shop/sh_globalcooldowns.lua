-- Shop item cooldowns everyone shares, eg one Divine Clap at a time across the whole server.
-- Items declare them in .globalCooldowns, keyed by the trigger that starts them.
-- What's networked is when each trigger last happened, so durations can be rescaled at any time.

local shopHelpers = GM.shopHelpers

GM.globalCooldownTriggers = {
    onGhostPlace = true, -- a placable bought as this item was placed
    onRoundStart = true, -- the hunt began
}

local function triggerKey( identifier, trigger )
    return "glee_cd_" .. identifier .. "_" .. trigger

end

-- nil if it hasn't happened
function GM:globalCooldownTriggeredAt( identifier, trigger )
    local triggeredAt
    if trigger == "onRoundStart" then
        triggeredAt = GetGlobalInt( "huntersglee_round_begin_active", 0 )

    else
        triggeredAt = GetGlobal2Int( triggerKey( identifier, trigger ), 0 )

    end

    if triggeredAt <= 0 then return end
    return triggeredAt

end

local sv_cheats = GetConVar( "sv_cheats" )

local globalCooldownSpec = {
    check = isnumber,
    typeName = "number",
    hook = "glee_shop_itemglobalcooldownmul",
}

-- The CurTime the item's latest global cooldown ends, and that cooldown's reason. 0 if it has none
function GM:shopItemGlobalCooldownEnd( identifier )
    local itemData = self:GetShopItemData( identifier )
    if not itemData or not itemData.globalCooldowns then return 0 end

    local cheats = sv_cheats:GetBool()
    local latestEnd = 0
    local reason
    for trigger, cooldown in pairs( itemData.globalCooldowns ) do
        if cheats and cooldown.ignoredWithCheats then continue end

        local triggeredAt = self:globalCooldownTriggeredAt( identifier, trigger )
        if not triggeredAt then continue end

        -- hook.Run( "glee_shop_itemglobalcooldownmul", itemData, trigger, adjust ) -- adjust.value is the cooldown's time, adjust.mul scales it
        -- no player, so everyone sees the same cooldown
        local time = shopHelpers.runAdjustHook( identifier, globalCooldownSpec, cooldown.time, itemData, trigger )
        local cooldownEnd = triggeredAt + time
        if cooldownEnd > latestEnd then
            latestEnd = cooldownEnd
            reason = cooldown.reason

        end
    end

    return latestEnd, reason

end

if SERVER then
    local triggeredKeys = {}

    hook.Add( "PostCleanupMap", "glee_ResetGlobalCooldowns", function()
        for key in pairs( triggeredKeys ) do
            SetGlobal2Int( key, 0 )

        end
        triggeredKeys = {}

    end )

    function GM:triggerGlobalCooldowns( identifier, trigger )
        local itemData = self:GetShopItemData( identifier )
        if not itemData or not itemData.globalCooldowns then return end
        if not itemData.globalCooldowns[trigger] then return end

        local key = triggerKey( identifier, trigger )
        SetGlobal2Int( key, math.ceil( CurTime() ) )
        triggeredKeys[key] = true

    end
end
