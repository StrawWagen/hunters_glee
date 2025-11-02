-- system for items to add hooks, timers to players that are cleaned up in the correct places
-- do item = include("sh_fauxitemclass.lua") to get a new item 

local item = {
    setupTasks = {}, -- stuff to do on setup
    teardownTasks = {}, -- stuff to do when round ends
}

function item:InternalOnPurchased( data, ply )
    ply.glee_CurrentItems = ply.glee_CurrentItems or {}
    itemData = data
    self.itemData = data

    self.printName = data.name
    self.identifier = data.identifier

    ply.glee_CurrentItems[ data.identifier ] = self

    data.svOnPurchaseFunc( self, ply ) -- call this before, so hooks and timers can be added in there

    for _, task in ipairs( self.setupTasks ) do
        task( self, ply )

    end
end

function item:GetIdentifier()
    return self.identifier

end

function item:Teardown() end

function item:internalTeardown()
    for _, task in ipairs( self.teardownTasks ) do
        task()

    end
end

function item:Hook( hookName, callback )
    local hookIdentifier = "GLEEitems_HOOK_" .. self:GetIdentifier() .. "_" .. util.MD5( tostring( callback ) )
    table.insert( self.teardownTasks, function()
        hook.Remove( hookName, hookIdentifier )
    end )

    table.insert( self.setupTasks, function()
        hook.Add( hookName, hookIdentifier, callback )
    end )
end

function item:Timer( timerName, delay, repetitions, callback )
    local fullTimerName = "GLEEitems_TIMER_" .. self:GetIdentifier() .. "_" .. timerName
    table.insert( self.teardownTasks, function()
        timer.Stop( fullTimerName )
    end )

    table.insert( self.setupTasks, function()
        timer.Create( fullTimerName, delay, repetitions, callback )
    end )
end

return item