-- one wearable on one wearer, handed to its SetupWear
-- putOn in sh_wearing.lua includes this file for a fresh one each time something's put on
-- it notices it's been taken off itself, the next time one of its hooks runs

local wear = {
    wearer = NULL,
    slot = "",
    class = "",
    weapon = NULL, -- the worn SWEP, once it's here, see checkWorn

    -- hook ids, the hook's number goes on the end
    -- every wear in a slot gets the same prefix, putOn removes the old wear before this one adds any
    _idPrefix = "",
    _hooks = {}, -- { name, id } of each, for Remove
    _cleanups = {}, -- see OnRemove
    _removed = false,

}

-- the worn SWEP, nil while it isn't here
-- clientside, the var can arrive before the weapon does
-- once it's been taken off, this removes the wear too
local function checkWorn( self )
    local wearer = self.wearer
    local wep = self.weapon
    if IsValid( wep ) and wep:GetOwner() == wearer then return wep end

    if not IsValid( wearer ) or wearer:GetGleeWornClass( self.slot ) ~= self.class then
        self:Remove()
        return

    end

    wep = wearer:GetWeapon( self.class )
    if not IsValid( wep ) then return end

    self.weapon = wep
    return wep

end

--[[---------------------------------------------------------
    wear:Hook
    @desc Adds a hook that runs while this is worn, and comes off with it.
    @param hookName: What should we hook into?
    @param func: Gets the worn SWEP, then the hook's own arguments. Skipped while the SWEP isn't here yet.
    @return: None
--]]---------------------------------------------------------
function wear:Hook( hookName, func )
    local hooks = self._hooks
    local id = self._idPrefix .. ( #hooks + 1 )
    hooks[#hooks + 1] = { name = hookName, id = id }

    hook.Add( hookName, id, function( ... )
        local wep = checkWorn( self )
        if not wep then return end

        return func( wep, ... )

    end )
end

--[[---------------------------------------------------------
    wear:OnRemove
    @desc Runs func as this comes off. For what the hooks made, eg a projected texture.
    @param func: Gets nothing.
    @return: None
--]]---------------------------------------------------------
function wear:OnRemove( func )
    self._cleanups[#self._cleanups + 1] = func

end

-- takes its hooks off, and runs its cleanups, once
function wear:Remove()
    if self._removed then return end
    self._removed = true

    for _, added in ipairs( self._hooks ) do
        hook.Remove( added.name, added.id )

    end

    for _, cleanup in ipairs( self._cleanups ) do
        ProtectedCall( cleanup )

    end
end

return wear
