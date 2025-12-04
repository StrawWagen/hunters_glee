
local developerVar = GetConVar( "developer" )

local plyMeta = FindMetaTable( "Player" )
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
    return self:GetNW2Bool( nw2NamePrefix .. name, false )

end

function plyMeta:GetStatusEffect( name )
    local plysEffects = self.glee_StatusEffects
    if not plysEffects then return nil end

    return plysEffects[name]

end

function plyMeta:StatusEffectApplyCL( name ) -- no way to give status effects on client, GIVE THEM ON SERVER!
    local registeredEffect = GAMEMODE.RegisteredStatusEffects and GAMEMODE.RegisteredStatusEffects[name] or nil
    if not registeredEffect then return end -- this effect only has server logic!

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

    self:CallOnRemove( "glee_statuseffectcleanup_" .. name, function()
        if developerVar:GetBool() then
            print( "statuseffect ", name, " being removed on ply removal for ", self )

        end

        self:StatusEffectRemoveCL( name )

    end )
end

function plyMeta:StatusEffectRemoveCL( name )
    local plysEffects = self.glee_StatusEffects
    if not plysEffects then return end

    local effect = plysEffects[name]
    if not effect then return end

    effect:InternalTeardown( self )

    plysEffects[name] = nil
    self:RemoveCallOnRemove( "glee_statuseffectcleanup_" .. name )

end

do
    local string_StartWith = string.StartWith
    hook.Add( "EntityNetworkedVarChanged", "glee_detecteffectadd", function( ent, varName, old, new )
        if not string_StartWith( varName, nw2NamePrefix ) then return end

        local effectName = string.sub( varName, #nw2NamePrefix + 1 )
        if developerVar:GetBool() then
            print( "statuseffect ", effectName, " changed to ", new, "for ", ent )

        end

        if new == true then
            ent:StatusEffectApplyCL( effectName )

        else
            ent:StatusEffectRemoveCL( effectName )

        end
    end )
end