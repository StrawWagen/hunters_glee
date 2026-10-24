
-- Client sets, see sv_clientsets for why these live on the client.
-- Every save restamps the whole file, so expireAfter only bites once a player has been away that long,
-- and then the whole set goes at once

local modeAdd = 1
local modeReset = 2

local dataDir = GM.DataFileDirectory
local saveInterval = 5

local setMeta = {}
setMeta.__index = setMeta

-- [name] = set
local sets = {}

-- set inside InitPostEntity, and kept on terminator_Extras so it survives autorefresh,
-- where InitPostEntity has long since fired and won't fire again
local function entitiesReady()
    return terminator_Extras.glee_ClientSetsReady

end

-- options.fileName is the file in the gamemode's data folder, options.expireAfter is in seconds, nil never expires
function GM:CreateClientSet( name, options )
    local set = setmetatable( {
        name = name,
        fileName = dataDir .. "/" .. options.fileName,
        expireAfter = options.expireAfter,
        -- nil until the file is read. adds that land before then, eg the server adding to a
        -- still-loading client, wait in pending, saving then would overwrite the file with just them
        keys = nil,
        pending = {},
        nextSave = 0,
    }, setMeta )

    sets[name] = set

    if entitiesReady() then
        set:Init()

    end

    return set

end

function setMeta:Load()
    local raw = file.Read( self.fileName, "DATA" )
    if not raw then return {} end

    local loaded = util.JSONToTable( raw )
    if not loaded then return {} end

    local savedTime = loaded._savedTime
    loaded._savedTime = nil

    if self.expireAfter then
        if not savedTime then return {} end
        if os.time() - savedTime > self.expireAfter then return {} end

    end

    return loaded

end

function setMeta:Save()
    local toWrite = table.Copy( self.keys )
    toWrite._savedTime = os.time()

    if not file.Exists( dataDir, "DATA" ) then
        file.CreateDir( dataDir )

    end
    file.Write( self.fileName, util.TableToJSON( toWrite, true ) )

end

-- Writes at most once every saveInterval, pass force to write anyway.
-- A throttled save is dropped rather than queued, the ShutDown flush at the bottom catches those
function setMeta:RequestSave( force )
    if not force and self.nextSave > CurTime() then
        self.unsaved = true
        return

    end

    self.nextSave = CurTime() + saveInterval
    self.unsaved = nil
    self:Save()

end

function setMeta:LazySync()
    -- repeatedly override the old timer until there's a break in adding
    timer.Create( "glee_clientsets_sync_" .. self.name, 0.01, 1, function()
        if not self.keys then return end

        local keys = table.GetKeys( self.keys )

        -- always the whole set, even when it's empty, see sv_clientsets' receive
        net.Start( "glee_clientsets" )
            net.WriteString( self.name )
            net.WriteUInt( #keys, 12 )
            for _, key in ipairs( keys ) do
                net.WriteString( key )

            end
        net.SendToServer()

    end )
end

function setMeta:Init()
    self.keys = self:Load()

    if next( self.pending ) then
        for key, _ in pairs( self.pending ) do
            self.keys[key] = true

        end
        table.Empty( self.pending )
        self:RequestSave( true )

    end

    self:LazySync()

end

function setMeta:Has( key )
    if not self.keys then return self.pending[key] == true end
    return self.keys[key] == true

end

-- Returns true only the first time, so a caller can act on something and mark it in the one call
function setMeta:Add( key )
    if not self.keys then
        if self.pending[key] then return false end
        self.pending[key] = true
        return true

    end

    if self.keys[key] then return false end
    self.keys[key] = true

    self:RequestSave()
    self:LazySync()

    return true

end

net.Receive( "glee_clientsets", function()
    local set = sets[net.ReadString()]
    if not set then return end

    local mode = net.ReadUInt( 2 )
    if mode == modeReset then
        table.Empty( set.pending )
        if not set.keys then return end

        table.Empty( set.keys )
        set:RequestSave( true )
        set:LazySync()

    elseif mode == modeAdd then
        -- the server added this one, so it already knows, no sync back
        local key = net.ReadString()
        if not set.keys then
            set.pending[key] = true
            return

        end

        if set.keys[key] then return end
        set.keys[key] = true
        set:RequestSave()

    end
end )

hook.Add( "InitPostEntity", "glee_clientsets_init", function()
    terminator_Extras.glee_ClientSetsReady = true
    for _, set in pairs( sets ) do
        set:Init()

    end
end )

hook.Add( "ShutDown", "glee_clientsets_flush", function()
    for _, set in pairs( sets ) do
        if not set.unsaved then continue end
        set:Save()

    end
end )
