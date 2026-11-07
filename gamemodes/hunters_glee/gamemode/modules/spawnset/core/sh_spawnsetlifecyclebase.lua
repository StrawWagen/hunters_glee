local lifecycle = {
    _teardownTasks = {},
    _unparsedSpawnset = nil,
}


--[[---------------------------------------------------------
    lifecycle:Activate
    @desc Optional, written by the spawnset. Called when the spawnset becomes the active misery.
    @return: None
--]]---------------------------------------------------------
--function lifecycle:Activate()
--end

--[[---------------------------------------------------------
    lifecycle:OnRemove
    @desc Optional, written by the spawnset. Called when the misery is changed away from this spawnset.
    @return: None
--]]---------------------------------------------------------
--function lifecycle:OnRemove()
--end

--[[---------------------------------------------------------
    lifecycle:Apply
    @desc Starts a lifecycle object, calling the spawnset's Activate.
    @param unparsedSpawnset: The spawnset, before its random ranges are rolled.
    @return: None
--]]---------------------------------------------------------
function lifecycle:Apply( unparsedSpawnset )

    -- direct ref to unparsed spawnset
    -- editing this is unsafe
    self._unparsedSpawnset = unparsedSpawnset

    -- all spawnset's values are provided for convenience
    -- BUT editing them here won't do anything
    local unparsedCopy = table.Copy( unparsedSpawnset )
    table.Merge( self, unparsedCopy )

    if self.Activate then
        ProtectedCall( self.Activate, self )

    end
end

--[[---------------------------------------------------------
    lifecycle:InternalTeardown
    @desc Ends a lifecycle object, calling the spawnset's OnRemove and shutting down all hooks and timers.
    @return: None
--]]---------------------------------------------------------
function lifecycle:InternalTeardown()
    if self.OnRemove then
        ProtectedCall( self.OnRemove, self )

    end
    for _, func in ipairs( self._teardownTasks ) do
        ProtectedCall( func )

    end
end


--[[---------------------------------------------------------
    lifecycle:Hook
    @desc Adds a hook that is tied to this spawnset. When the spawnset is swapped away, the hook is removed.

    self:Hook( "PlayerSay", function( ply, text ) end )
    self:Hook( "PlayerSay", "secondOne", function( ply, text ) end )

    One hook per hookName, a second replaces the first.
    Give each extra one its own id to keep both.
    @return: The hook's identifier.
--]]---------------------------------------------------------
function lifecycle:Hook( hookName, id, func )
    if func == nil then
        func = id
        id = ""

    end
    if not isfunction( func ) then
        error( "GLEE: lifecycle:Hook takes ( hookName, func ), or ( hookName, id, func )", 2 )

    end
    local fullHookIdentifier = "glee_lifecycle_" .. self.name .. "_" .. hookName .. "_" .. id .. "_" .. tostring( self )
    table.insert( self._teardownTasks, function()
        hook.Remove( hookName, fullHookIdentifier )

    end )

    hook.Add( hookName, fullHookIdentifier, func )

    return fullHookIdentifier

end

--[[---------------------------------------------------------
    lifecycle:Timer
    @desc Adds a timer that is tied to this spawnset. When the spawnset is swapped away, the timer is removed.
    @param timerName: A unique name for the timer.
    @param delay: The delay between timer calls.
    @param reps: How many times to repeat the timer. Use 0 for infinite.
    @param func: The function to call when the timer triggers.
    @return: The timer's full name.
--]]---------------------------------------------------------
function lifecycle:Timer( timerName, delay, reps, func )
    local fullTimerName = "glee_lifecycle_" .. self.name .. "_" .. timerName .. "_" .. tostring( self )

    table.insert( self._teardownTasks, function()
        timer.Remove( fullTimerName )

    end )

    timer.Create( fullTimerName, delay, reps, func )

    return fullTimerName

end

--[[---------------------------------------------------------
    lifecycle:TimerRemove
    @desc Removes a timer that is tied to this spawnset.
    @param timerName: The unique name for the timer to remove.
    @return: None
--]]---------------------------------------------------------
function lifecycle:TimerRemove( timerName )
    local fullTimerName = "glee_lifecycle_" .. self.name .. "_" .. timerName .. "_" .. tostring( self )
    timer.Remove( fullTimerName )

end

--[[---------------------------------------------------------
    lifecycle:AddTeardown
    @desc Runs func when the spawnset is swapped away, for undoing what hooks and timers can't.
    Teardown runs in the order things were added, so the hooks and timers made before this are already gone.
    @param func: The function to call on teardown.
    @return: None
--]]---------------------------------------------------------
function lifecycle:AddTeardown( func )
    table.insert( self._teardownTasks, func )

end

return lifecycle
