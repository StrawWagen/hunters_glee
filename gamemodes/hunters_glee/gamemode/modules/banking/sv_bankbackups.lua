-- Weekly copies of the saved bank file, the newest few kept, so a bad save can be rolled back by hand.

local bankFunctions = GM.bankFunctions

local backupDir = GM.DataFileDirectory .. "/bankbackups"
local backupPattern = backupDir .. "/bankdata_*.json"
local backupInterval = 86400 * 7
local maxBackups = 4

-- oldest first, as { path, time }
local function getBackups()
    local backups = {}
    for _, name in ipairs( file.Find( backupPattern, "DATA" ) ) do
        local path = backupDir .. "/" .. name
        backups[#backups + 1] = { path = path, time = file.Time( path, "DATA" ) }

    end

    table.sort( backups, function( a, b ) return a.time < b.time end )

    return backups

end

local function makeBackup()
    local saved = file.Read( bankFunctions.bankDataFile, "DATA" )
    if not saved then return end

    if not file.Exists( backupDir, "DATA" ) then
        file.CreateDir( backupDir )

    end

    local backupPath = backupDir .. "/bankdata_" .. os.date( "%Y-%m-%d" ) .. ".json"
    file.Write( backupPath, saved )
    permaPrint( "GLEE: Backed up the bank to " .. backupPath )

end

local function pruneOldBackups( backups )
    for i = 1, #backups - maxBackups do
        local backup = backups[i]
        file.Delete( backup.path )
        permaPrint( "GLEE: Deleted old bank backup " .. backup.path )

    end
end

local function manageBackups()
    local backups = getBackups()
    local newest = backups[#backups]

    if not newest or os.time() - newest.time >= backupInterval then
        makeBackup()
        backups = getBackups()

    end

    pruneOldBackups( backups )

end

manageBackups()
timer.Create( "glee_bank_backups", 3600, 0, manageBackups )
