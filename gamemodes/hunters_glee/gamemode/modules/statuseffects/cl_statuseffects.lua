
local developerVar = GetConVar( "developer" )

local entMeta = FindMetaTable( "Entity" )
local nw2NamePrefix = "glee_hasstatuseffect_"

-- data.extraModels, MyExtraModels entries stuck on the owner while the effect's on
-- not made in setup, so this can potentially work with autorefresh down the line
-- different from statusEffect:AddExtraModel, that can add extra models live
local function dataExtrasKey( name )
    return "glee_statuseffect_" .. name .. "_data"

end

local function attachDataExtras( ent, name, data )
    local key = dataExtrasKey( name )
    if data.extraModels then
        terminator_Extras.AttachMyExtraModels( ent, data.extraModels, key )

    else
        terminator_Extras.RemoveMyExtraModels( ent, key )

    end
end

function GM:RegisterStatusEffect( name, setup, teardown, data )
    data = data or {}

    self.RegisteredStatusEffects = self.RegisteredStatusEffects or {}
    self.RegisteredStatusEffects[name] = {
        setup = setup,
        teardown = teardown,
        data = data,

    }

    -- registered again, an autorefresh. effects already running get the new extras
    for _, ent in ipairs( ents.GetAll() ) do
        if ent:GetStatusEffect( name ) then
            attachDataExtras( ent, name, data )

        end
    end
end

function entMeta:HasStatusEffect( name )
    return self:GetNW2Bool( nw2NamePrefix .. name, false )

end

function entMeta:GetStatusEffect( name )
    local entsEffects = self.glee_StatusEffects
    if not entsEffects then return nil end

    return entsEffects[name]

end

function entMeta:StatusEffectApplyCL( name ) -- no way to give status effects on client, GIVE THEM ON SERVER!
    local registeredEffect = GAMEMODE.RegisteredStatusEffects and GAMEMODE.RegisteredStatusEffects[name] or nil
    if not registeredEffect then return end -- this effect only has server logic!

    local entsEffects = self.glee_StatusEffects
    if not entsEffects then
        entsEffects = {}
        self.glee_StatusEffects = entsEffects

    end

    if entsEffects[name] then return end

    local effect = include( "hunters_glee/gamemode/modules/statuseffects/sh_statuseffectbase.lua" )

    effect:SetPrintName( name )
    effect:SetOwner( self )

    effect:SetSetupFunc( registeredEffect.setup )
    effect:SetTeardownFunc( registeredEffect.teardown )

    effect:Apply( self )

    entsEffects[name] = effect
    attachDataExtras( self, name, registeredEffect.data )

    self:CallOnRemove( "glee_statuseffectcleanup_" .. name, function()
        if developerVar:GetBool() then
            permaPrint( "statuseffect ", name, " being removed on ply removal for ", self )

        end

        self:StatusEffectRemoveCL( name )

    end )
end

function entMeta:StatusEffectRemoveCL( name )
    local entsEffects = self.glee_StatusEffects
    if not entsEffects then return end

    local effect = entsEffects[name]
    if not effect then return end

    effect:InternalTeardown( self )

    entsEffects[name] = nil
    terminator_Extras.RemoveMyExtraModels( self, dataExtrasKey( name ) )
    self:RemoveCallOnRemove( "glee_statuseffectcleanup_" .. name )

end

do
    local string_StartWith = string.StartWith

    local function syncEffect( ent, effectName, has )
        if has then
            ent:StatusEffectApplyCL( effectName )

        else
            ent:StatusEffectRemoveCL( effectName )

        end
    end

    -- setups can lean on LocalPlayer(), which isn't valid while we're still loading in
    -- so changes wait here until InitPostEntity. already loaded means an autorefresh
    local loadedIn = IsValid( LocalPlayer() )
    local waitingChanges = {}

    hook.Add( "InitPostEntity", "glee_statuseffects_applywaiting", function()
        loadedIn = true

        for ent, effectNames in pairs( waitingChanges ) do
            if not IsValid( ent ) then continue end

            -- read it fresh, it may have flipped more than once while we waited
            for effectName in pairs( effectNames ) do
                syncEffect( ent, effectName, ent:GetNW2Bool( nw2NamePrefix .. effectName, false ) )

            end
        end
        waitingChanges = {}

    end )

    hook.Add( "EntityNetworkedVarChanged", "glee_detecteffectadd", function( ent, varName, old, new )
        if not string_StartWith( varName, nw2NamePrefix ) then return end

        local effectName = string.sub( varName, #nw2NamePrefix + 1 )
        if developerVar:GetBool() then
            permaPrint( "statuseffect ", effectName, " changed to ", new, "for ", ent )

        end

        if not loadedIn then
            waitingChanges[ent] = waitingChanges[ent] or {}
            waitingChanges[ent][effectName] = true
            return

        end

        syncEffect( ent, effectName, new == true )

    end )
end
