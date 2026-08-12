local statusEffect = {
    _teardownTasks = {},
    _printName = "NULL",
    _owner = NULL,
    _setup = nil,
    _teardown = nil,

}

function statusEffect:SetPrintName( name )
    self._printName = name

end
function statusEffect:GetPrintName()
    return self._printName

end


function statusEffect:SetOwner( ply )
    self._owner = ply

end
function statusEffect:GetOwner()
    return self._owner

end


if SERVER then
    function statusEffect:SetRemoveOnDeath( shouldRemove )
        self._removeOnDeath = shouldRemove

    end
end


function statusEffect:SetSetupFunc( func )
    self._setup = func

end
function statusEffect:SetTeardownFunc( func )
    self._teardown = func

end

--[[---------------------------------------------------------
    statusEffect:Apply
    @desc Applies a status effect object to some player.
    @param ply: The player to apply the effect to.
    @return: None
--]]---------------------------------------------------------
function statusEffect:Apply( ply )
    if self._setup then
        ProtectedCall( self._setup, self, ply )

    end
end

--[[---------------------------------------------------------
    statusEffect:InternalTeardown
    @desc Prepares a status effect object for removal, shutting down all hooks and timers.
    @param ply: The player to remove the effect from.
    @return: None
--]]---------------------------------------------------------
function statusEffect:InternalTeardown( ply )
    if self._teardown then
        ProtectedCall( self._teardown, self, ply )

    end
    for _, func in ipairs( self._teardownTasks ) do
        ProtectedCall( func, ply )

    end
end


--[[---------------------------------------------------------
    statusEffect:Hook
    @desc Adds a hook that is tied to this status effect. When the effect is torn down, the hook is removed.
    @param hookName: What should we hook into?
    @param func: The function to insert into the hook.
    @return: None
--]]---------------------------------------------------------
function statusEffect:Hook( hookName, func )
    if isstring( func ) then
        error( "GLEE: statusEffect:Hook doesn't need a hook name!" )

    end
    local fullHookIdentifier = "glee_statuseffect_" .. self:GetPrintName() .. "_" .. hookName .. "_" .. tostring( self )
    table.insert( self._teardownTasks, function()
        hook.Remove( hookName, fullHookIdentifier )

    end )

    hook.Add( hookName, fullHookIdentifier, func )

    return fullHookIdentifier

end

--[[---------------------------------------------------------
    statusEffect:HookOnce
    @desc Adds a hook that is tied to a registered status effect, multiple of these hooks will not be added.
          When the last effect is torn down, the hook is removed.
          For stuff like adding visual effects without creating a billion hooks.
    @param hookName: What should we hook into?
    @param func: The function to insert into the hook.
    @return: None
--]]---------------------------------------------------------

GAMEMODE.activeEffectsCount = GAMEMODE.activeEffectsCount or {}

function statusEffect:HookOnce( hookName, func )
    if isstring( func ) then
        error( "GLEE: statusEffect:HookOnce doesn't need a hook name!" )

    end

    local activeEffectsCount = GAMEMODE.activeEffectsCount
    local myName = self:GetPrintName()

    local fullHookIdentifier = "glee_statuseffect_" .. myName .. "_" .. hookName

    local count = activeEffectsCount[fullHookIdentifier] or 0
    table.insert( self._teardownTasks, function()
        local countRemove = activeEffectsCount[fullHookIdentifier]
        countRemove = countRemove - 1
        activeEffectsCount[fullHookIdentifier] = countRemove

        if countRemove <= 0 then
            hook.Remove( hookName, fullHookIdentifier )

        end
    end )
    if count <= 0 then
        hook.Add( hookName, fullHookIdentifier, func )

    end
    activeEffectsCount[fullHookIdentifier] = count + 1

    return fullHookIdentifier

end

--[[---------------------------------------------------------
    statusEffect:Timer
    @desc Adds a timer that is tied to this status effect. When the effect is torn down, the timer is removed.
    @param timerName: A unique name for the timer.
    @param delay: The delay between timer calls.
    @param reps: How many times to repeat the timer. Use 0 for infinite.
    @param func: The function to call when the timer triggers.
    @return: None
--]]---------------------------------------------------------
function statusEffect:Timer( timerName, delay, reps, func )
    local fullTimerName = "glee_statuseffect_" .. self:GetPrintName() .. "_" .. timerName .. "_" .. tostring( self )

    table.insert( self._teardownTasks, function()
        timer.Remove( fullTimerName )

    end )

    timer.Create( fullTimerName, delay, reps, func )

    return fullTimerName

end

--[[---------------------------------------------------------
    statusEffect:TimerRemove
    @desc Removes a timer that is tied to this status effect.
    @param timerName: The unique name for the timer to remove.
    @return: None
--]]---------------------------------------------------------
function statusEffect:TimerRemove( timerName )
    local fullTimerName = "glee_statuseffect_" .. self:GetPrintName() .. "_" .. timerName .. "_" .. tostring( self )
    timer.Remove( fullTimerName )

end

return statusEffect
