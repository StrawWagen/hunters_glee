
util.AddNetworkString( "glee_statuseffects_syncrequest" )

local entMeta = FindMetaTable( "Entity" )
local GM = GAMEMODE or GM
local nw2NamePrefix = "glee_hasstatuseffect_"

function GM:RegisterStatusEffect( name, setup, teardown, data )
    self.RegisteredStatusEffects = self.RegisteredStatusEffects or {}
    self.RegisteredStatusEffects[name] = {
        setup = setup,
        teardown = teardown,
        data = data or {},

    }
end

function GM:GetRegisteredStatusEffect( name )
    return self.RegisteredStatusEffects[name]

end

function entMeta:HasStatusEffect( name )
    if not self.glee_StatusEffects then return end

    return self.glee_StatusEffects[name] ~= nil

end

function entMeta:GetStatusEffect( name )
    local entsEffects = self.glee_StatusEffects
    if not entsEffects then return nil end

    return entsEffects[name]

end

function entMeta:GiveStatusEffect( name )
    local registeredEffect = GAMEMODE.RegisteredStatusEffects and GAMEMODE.RegisteredStatusEffects[name] or nil
    if not registeredEffect then ErrorNoHaltWithStack( "GLEE: Tried to give invalid status effect; " .. name ) return end

    local entsEffects = self.glee_StatusEffects
    if not entsEffects then
        entsEffects = {}
        self.glee_StatusEffects = entsEffects

    end

    if entsEffects[name] then return end

    -- the effect isn't stored until setup is done, so this is how Give and Remove spot a setup reaching back for its own effect
    local applying = self.glee_ApplyingStatusEffects
    if not applying then
        applying = {}
        self.glee_ApplyingStatusEffects = applying

    end
    if applying[name] then error( "GLEE: status effect " .. name .. " tried to give itself again during its own setup" ) end

    local effect = include( "hunters_glee/gamemode/modules/statuseffects/sh_statuseffectbase.lua" )

    effect:SetPrintName( name )
    effect:SetOwner( self )

    effect:SetSetupFunc( registeredEffect.setup )
    effect:SetTeardownFunc( registeredEffect.teardown )

    applying[name] = true
    effect:Apply( self )
    applying[name] = nil

    entsEffects[name] = effect
    local nw2Name = nw2NamePrefix .. name
    self:SetNW2Bool( nw2Name, true )

    self:CallOnRemove( "glee_statuseffectcleanup_" .. name, function()
        self:RemoveStatusEffect( name )

    end )

    return effect

end

function entMeta:RemoveStatusEffect( name )
    local applying = self.glee_ApplyingStatusEffects
    if applying and applying[name] then error( "GLEE: status effect " .. name .. " tried to remove itself during its own setup" ) end

    local entsEffects = self.glee_StatusEffects
    if not entsEffects then return end

    local effect = entsEffects[name]
    if not effect then return end

    -- teardown runs while the effect is still stored, so removing it again from in there would recurse forever
    if effect._tearingDown then error( "GLEE: status effect " .. name .. " tried to remove itself during its own teardown" ) end
    effect._tearingDown = true

    effect:InternalTeardown( self )

    entsEffects[name] = nil
    local nw2Name = nw2NamePrefix .. name
    self:SetNW2Bool( nw2Name, false )
    self:RemoveCallOnRemove( "glee_statuseffectcleanup_" .. name )

end

local function removeAllStatusEffects( ent )
    local entsEffects = ent.glee_StatusEffects
    if not entsEffects then return end

    for name, _ in pairs( entsEffects ) do
        ent:RemoveStatusEffect( name )

    end
end

function GM:GetAllPlayersWithStatusEffect( name )
    local playersWith = {}

    for _, ply in ipairs( player.GetAll() ) do
        if not ply:HasStatusEffect( name ) then continue end
        table.insert( playersWith, ply )

    end

    return playersWith

end

function GM:GetAllPlayersWithAStatusEffect( names )
    local playersWith = {}

    for _, ply in ipairs( player.GetAll() ) do
        local has
        for _, name in ipairs( names ) do
            if not ply:HasStatusEffect( name ) then continue end
            has = true

        end
        if not has then continue end
        table.insert( playersWith, ply )

    end

    return playersWith

end


hook.Add( "PlayerDisconnected", "glee_statuseffects_cleanup", removeAllStatusEffects )

hook.Add( "glee_post_cleanupmap", "glee_statuseffects_cleanup", function()
    for _, ply in ipairs( player.GetAll() ) do
        removeAllStatusEffects( ply )

    end
end )

hook.Add( "PlayerDeath", "glee_statuseffects_doremoveondeath", function( ply )
    local plysEffects = ply.glee_StatusEffects
    if not plysEffects then return end

    for name, effect in pairs( plysEffects ) do
        if effect._plyRemoveOnDeath then
            ply:RemoveStatusEffect( name )

        end
    end
end )

-- npcs and nextbots don't come back, so they always lose everything
hook.Add( "OnNPCKilled", "glee_statuseffects_removeondeath", removeAllStatusEffects )
