local statusEffect = {
    _setupTasks = {},
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


function statusEffect:SetSetupFunc( func )
    self._setup = func

end
function statusEffect:SetTeardownFunc( func )
    self._teardown = func

end


function statusEffect:Apply( ply )
    local allGood = true
    if self._setup then
        allGood = ProtectedCall( self._setup, self, ply )

    end
    if not allGood then return end

    for _, func in ipairs( self._setupTasks ) do
        ProtectedCall( func, ply )

    end
end

function statusEffect:InternalTeardown( ply )
    local allGood = true
    if self._teardown then
        allGood = ProtectedCall( self._teardown, self, ply )

    end
    if not allGood then return end
    for _, func in ipairs( self._teardownTasks ) do
        ProtectedCall( func, ply )

    end
end

function statusEffect:Hook( hookName, func )
    local hookIdentifier = "glee_statuseffect_" .. self:GetPrintName() .. "_" .. hookName
    table.insert( self._teardownTasks, function()
        hook.Remove( hookName, hookIdentifier )

    end )

    table.insert( self._setupTasks, function()
        hook.Add( hookName, hookIdentifier, func )

    end )
end

function statusEffect:Timer( timerName, delay, reps, func )
    local fullTimerName = "glee_statuseffect_" .. self:GetPrintName() .. "_" .. timerName

    table.insert( self._teardownTasks, function()
        timer.Remove( fullTimerName )

    end )

    table.insert( self._setupTasks, function()
        timer.Create( fullTimerName, delay, reps, func )

    end )
end

return statusEffect
