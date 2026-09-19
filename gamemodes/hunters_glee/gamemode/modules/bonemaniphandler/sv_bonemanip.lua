
-- Keyed bone manipulations. Every source owns its own entries per bone, and the bone is set to all its entries combined.
-- ManipulateBoneScale/Position/Angles are overridden, so plain calls from anywhere become entries under the "default" key.

local entMeta = FindMetaTable( "Entity" )

-- stashed on the metatable so an autorefresh doesn't capture our own overrides as the originals
entMeta.glee_RawManipulateBoneScale = entMeta.glee_RawManipulateBoneScale or entMeta.ManipulateBoneScale
entMeta.glee_RawManipulateBonePosition = entMeta.glee_RawManipulateBonePosition or entMeta.ManipulateBonePosition
entMeta.glee_RawManipulateBoneAngles = entMeta.glee_RawManipulateBoneAngles or entMeta.ManipulateBoneAngles

-- combine must not depend on order, entries are iterated with pairs
local manipTypes = {
    scale = {
        raw = entMeta.glee_RawManipulateBoneScale,
        get = entMeta.GetManipulateBoneScale,
        copy = Vector,
        identity = Vector( 1, 1, 1 ),
        combine = function( a, b ) return a * b end,
    },
    pos = {
        raw = entMeta.glee_RawManipulateBonePosition,
        get = entMeta.GetManipulateBonePosition,
        copy = Vector,
        identity = Vector( 0, 0, 0 ),
        combine = function( a, b ) return a + b end,
    },
    ang = {
        raw = entMeta.glee_RawManipulateBoneAngles,
        get = entMeta.GetManipulateBoneAngles,
        copy = Angle,
        identity = Angle( 0, 0, 0 ),
        combine = function( a, b ) return a + b end,
    },
}

local function writeBone( ent, typeName, bone )
    local manipType = manipTypes[typeName]

    -- a bone with no entries left still gets written, that's what puts it back to normal
    local result = manipType.copy( manipType.identity )
    local entries = ent.glee_bonemanips[typeName][bone]
    if entries then
        for _, value in pairs( entries ) do
            result = manipType.combine( result, value )

        end
    end

    if manipType.get( ent, bone ) ~= result then
        manipType.raw( ent, bone, result )

    end
end

local function setManip( ent, typeName, key, bone, value )
    local manips = ent.glee_bonemanips
    if not manips then
        manips = { scale = {}, pos = {}, ang = {} }
        ent.glee_bonemanips = manips

    end

    local bones = manips[typeName]
    local entries = bones[bone]

    -- an identity entry combines to nothing, so it's stored as no entry
    if value == nil or value == manipTypes[typeName].identity then
        if entries then
            entries[key] = nil
            if not next( entries ) then
                bones[bone] = nil

            end
        end
    else
        if not entries then
            entries = {}
            bones[bone] = entries

        end

        -- copied, callers pass shared module-level vectors
        entries[key] = manipTypes[typeName].copy( value )

    end

    writeBone( ent, typeName, bone )

end

--[[---------------------------------------------------------
    ent:ApplyBoneScaleManip
    Sets this key's scale entry on a bone. All keys' scale entries on a bone are multiplied together.
    @param key: Any table key identifying the source.
    @param bone: Bone id.
    @param scale: Vector, or nil to remove this key's entry.
--]]---------------------------------------------------------
function entMeta:ApplyBoneScaleManip( key, bone, scale )
    setManip( self, "scale", key, bone, scale )

end

--[[---------------------------------------------------------
    ent:ApplyBonePosManip
    Sets this key's position entry on a bone. All keys' position entries on a bone are added together.
    @param key: Any table key identifying the source.
    @param bone: Bone id.
    @param pos: Vector, or nil to remove this key's entry.
--]]---------------------------------------------------------
function entMeta:ApplyBonePosManip( key, bone, pos )
    setManip( self, "pos", key, bone, pos )

end

--[[---------------------------------------------------------
    ent:ApplyBoneAngleManip
    Sets this key's angle entry on a bone. All keys' angle entries on a bone are added together.
    @param key: Any table key identifying the source.
    @param bone: Bone id.
    @param ang: Angle, or nil to remove this key's entry.
--]]---------------------------------------------------------
function entMeta:ApplyBoneAngleManip( key, bone, ang )
    setManip( self, "ang", key, bone, ang )

end

--[[---------------------------------------------------------
    ent:RemoveBoneManips
    Removes every scale, position and angle entry this key has, on every bone.
    @param key: The key passed to the Apply functions.
--]]---------------------------------------------------------
function entMeta:RemoveBoneManips( key )
    local manips = self.glee_bonemanips
    if not manips then return end

    for typeName, bones in pairs( manips ) do
        for bone, entries in pairs( bones ) do
            if entries[key] ~= nil then
                entries[key] = nil
                if not next( entries ) then
                    bones[bone] = nil

                end

                writeBone( self, typeName, bone )

            end
        end
    end
end

--[[---------------------------------------------------------
    ent:CopyBoneManipsTo
    Gives target every keyed entry this entity has, under the same keys, so they can still be removed per key there.
    Bones are matched by name, bones target doesn't have are skipped.
    Target's entries under other keys are kept, entries under the same key and bone are replaced.
    @param target: The entity to copy onto, eg a ragdoll of this entity.
--]]---------------------------------------------------------
function entMeta:CopyBoneManipsTo( target )
    local manips = self.glee_bonemanips
    if not manips then return end

    for typeName, bones in pairs( manips ) do
        for bone, entries in pairs( bones ) do
            local targetBone = target:LookupBone( self:GetBoneName( bone ) )
            if targetBone then
                for key, value in pairs( entries ) do
                    setManip( target, typeName, key, targetBone, value )

                end
            end
        end
    end
end

-- The Get functions are left alone. They return what the engine has, which includes every key.

-- NOTE: the engine's optional third 'networking' arg on ManipulateBonePosition/Angles is dropped, these always network.

function entMeta:ManipulateBoneScale( bone, scale )
    setManip( self, "scale", "default", bone, scale )

end

function entMeta:ManipulateBonePosition( bone, pos )
    setManip( self, "pos", "default", bone, pos )

end

function entMeta:ManipulateBoneAngles( bone, ang )
    setManip( self, "ang", "default", bone, ang )

end
