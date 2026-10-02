-- The bank lives in bankdata.json.
-- A save is written to staged_bankdata.json first, read back to check it, then swapped in over bankdata.json.
-- So a failed save never touches bankdata.json, and a crash mid-swap leaves the staged file for the next load to finish the swap with.

local bankFunctions = GM.bankFunctions
local GAMEMODE = GAMEMODE or GM

local bankDir = GM.DataFileDirectory
local bankFile = bankDir .. "/bankdata.json"

bankFunctions.bankDataFile = bankFile


-- Writing and reading

local function stagedPathOf( path )
    return string.GetPathFromFilename( path ) .. "staged_" .. string.GetFileFromFilename( path )

end

-- Writes contents to the staged file, then swaps it in over path once it reads back intact.
-- Returns whether path now holds contents.
bankFunctions.writeStaged = function( path, contents )
    local stagedPath = stagedPathOf( path )

    file.Write( stagedPath, contents )
    if file.Read( stagedPath, "DATA" ) ~= contents then
        file.Delete( stagedPath )
        return false

    end

    file.Delete( path )
    if file.Exists( path, "DATA" ) then return false end

    return file.Rename( stagedPath, path )

end

-- Returns the bank table, or nil when the file is missing or isn't a valid bank.
local function readBank( path )
    local contents = file.Read( path, "DATA" )
    local bank = contents and util.JSONToTable( contents, true )
    if not bank or not bank.savedTime or not istable( bank.accounts ) then return end

    return bank

end


-- Saving and loading

-- Does nothing while saving is locked, see loadBankFile.
bankFunctions.saveBank = function()
    if GAMEMODE.bankFileState == "unreadable" then return end

    GAMEMODE.bankInfoTable.savedTime = os.time()
    if not file.Exists( bankDir, "DATA" ) then
        file.CreateDir( bankDir )

    end

    if not bankFunctions.writeStaged( bankFile, util.TableToJSON( GAMEMODE.bankInfoTable, true ) ) then
        ErrorNoHalt( "GLEE: Failed to save the bank to data/" .. bankFile .. ", is the disk full?\n" )

    end
end

-- Runs once per map. The state is kept on GAMEMODE, so a Lua refresh doesn't load over unsaved changes, or forget the lock.
-- When bankdata.json exists but can't be loaded, saving is locked until the next map. Otherwise the empty bank would be saved over it, wiping every account.
local function loadBankFile()
    if GAMEMODE.bankFileState then return end

    -- A save crashed between deleting bankdata.json and renaming the staged file over it.
    local stagedFile = stagedPathOf( bankFile )
    if not file.Exists( bankFile, "DATA" ) and readBank( stagedFile ) then
        file.Rename( stagedFile, bankFile )

    end

    local bank = readBank( bankFile )
    if bank then
        GAMEMODE.bankFileState = "loaded"
        GAMEMODE.bankInfoTable = bank

    elseif file.Exists( bankFile, "DATA" ) then
        GAMEMODE.bankFileState = "unreadable"
        ErrorNoHalt( "GLEE: data/" .. bankFile .. " couldn't be loaded! Bank saving is DISABLED so it isn't overwritten. Fix it, or copy a backup from bankbackups/ over it, then change map.\n" )

    else
        GAMEMODE.bankFileState = "missing"

    end
end

-- "loaded", "missing" when there was no bank to load, or "unreadable" when saving is locked.
bankFunctions.bankFileState = function()
    return GAMEMODE.bankFileState

end

loadBankFile()
