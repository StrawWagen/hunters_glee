-- copies of the saved bank file, the newest few kept, so a bad save can be rolled back by hand.

local bankFunctions = GM.bankFunctions

local backupDir = GM.DataFileDirectory .. "/bankbackups"
local backupPattern = backupDir .. "/bankdata_*.json"
local backupInterval = 86400 * 4
local maxBackups = 10

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

-- Deletes the oldest backups, until only maxBackups are left.
local function pruneOldBackups()
    local backups = getBackups()
    for i = 1, #backups - maxBackups do
        local backup = backups[i]
        file.Delete( backup.path )
        permaPrint( "GLEE: Deleted old bank backup " .. backup.path )

    end
end

local function makeBackup()
    local saved = file.Read( bankFunctions.bankDataFile, "DATA" )
    if not saved then return end

    if not file.Exists( backupDir, "DATA" ) then
        file.CreateDir( backupDir )

    end

    local backupPath = backupDir .. "/bankdata_" .. os.date( "%Y-%m-%d" ) .. ".json"
    if not bankFunctions.writeStaged( backupPath, saved ) then
        ErrorNoHalt( "GLEE: Failed to back up the bank to data/" .. backupPath .. ", is the disk full?\n" )
        return

    end

    permaPrint( "GLEE: Backed up the bank to " .. backupPath )
    pruneOldBackups()

end

-- Makes a backup when the newest one is older than backupInterval, or there are none.
local function backupIfDue()
    -- Don't back up an unreadable bank file.
    -- Each broken backup would push a good backup out.
    if bankFunctions.bankFileState() == "unreadable" then return end

    local backups = getBackups()
    local newest = backups[#backups]

    if not newest or os.time() - newest.time >= backupInterval then
        makeBackup()

    end
end

-- Warns when the bank file is missing but backups exist.
-- That means the bank was lost, not that this is a new server.
local function warnIfBankLost()
    if bankFunctions.bankFileState() ~= "missing" then return end
    if #getBackups() == 0 then return end

    ErrorNoHalt( "GLEE: The bank file is missing, but data/" .. backupDir .. "/ has backups! Started an empty bank. To restore, stop the server and copy the newest backup over data/" .. bankFunctions.bankDataFile .. "\n" )

end

warnIfBankLost()
backupIfDue()
timer.Create( "glee_bank_backups", 3600, 0, backupIfDue )
