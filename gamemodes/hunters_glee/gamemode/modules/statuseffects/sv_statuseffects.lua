
local plyMeta = FindMetaTable( "Player" )
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

function plyMeta:HasStatusEffect( name )
    if not self.glee_StatusEffects then return end

    return self.glee_StatusEffects[name] ~= nil

end

function plyMeta:GiveStatusEffect( name )
    local registeredEffect = GAMEMODE.RegisteredStatusEffects and GAMEMODE.RegisteredStatusEffects[name] or nil
    if not registeredEffect then ErrorNoHaltWithStack( "GLEE: Tried to give player invalid status effect; " .. name ) return end

    local plysEffects = self.glee_StatusEffects
    if not plysEffects then
        plysEffects = {}
        self.glee_StatusEffects = plysEffects

    end

    if plysEffects[name] then return end

    local effect = include( "hunters_glee/gamemode/modules/statuseffects/sh_statuseffectbase.lua" )

    effect:SetPrintName( name )
    effect:SetOwner( self )

    effect:SetSetupFunc( registeredEffect.setup )
    effect:SetTeardownFunc( registeredEffect.teardown )

    effect:Apply( self )

    plysEffects[name] = effect
    local nw2Name = nw2NamePrefix .. name
    self:SetNW2Bool( nw2Name, true )

end

include( "sh_statuseffectbase.lua" )

function plyMeta:RemoveStatusEffect( name )
    local plysEffects = self.glee_StatusEffects
    if not plysEffects then return end

    local effect = plysEffects[name]
    if not effect then return end

    effect:InternalTeardown( self )

    plysEffects[name] = nil
    local nw2Name = nw2NamePrefix .. name
    self:SetNW2Bool( nw2Name, false )

end


hook.Add( "PlayerDisconnected", "glee_statuseffects_cleanup", function( ply )
    local plysEffects = ply.glee_StatusEffects
    if not plysEffects then return end

    for name, _ in pairs( plysEffects ) do
        ply:RemoveStatusEffect( name )

    end
end )

hook.Add( "glee_PostCleanupMap", "glee_statuseffects_cleanup", function()
    for _, ply in ipairs( player.GetAll() ) do
        local plysEffects = ply.glee_StatusEffects
        if not plysEffects then continue end

        for name, _ in pairs( plysEffects ) do
            ply:RemoveStatusEffect( name )

        end
    end
end )

hook.Add( "PlayerDeath", "glee_statuseffects_doremoveondeath", function( ply )
    local plysEffects = ply.glee_StatusEffects
    if not plysEffects then return end

    for name, effect in pairs( plysEffects ) do
        if effect.removeOnDeath then
            ply:RemoveStatusEffect( name )

        end
    end
end )