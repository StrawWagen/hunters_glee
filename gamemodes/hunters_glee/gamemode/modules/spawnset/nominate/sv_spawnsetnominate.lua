
util.AddNetworkString( "glee_misery_nominations" )
util.AddNetworkString( "glee_misery_nominate" )
util.AddNetworkString( "glee_misery_withdraw" )

-- each player is also sent their own suspended nomination, if they have one
function GM:SyncMiseryNominations( plys )
    if not istable( plys ) then plys = { plys } end

    local nominations = self.glee_MiseryNominations

    for _, ply in ipairs( plys ) do
        local suspended = self.glee_SuspendedMiseryNominations[ply:SteamID64()]

        net.Start( "glee_misery_nominations" )
            net.WriteUInt( table.Count( nominations ), 8 )
            for steamID64, nomination in pairs( nominations ) do
                net.WriteString( steamID64 )
                net.WriteString( nomination.setName )
                net.WriteUInt( nomination.cost, 32 )

            end

            net.WriteBool( suspended ~= nil )
            if suspended then
                net.WriteString( suspended.setName )
                net.WriteUInt( suspended.cost, 32 )

            end
        net.Send( ply )

    end
end

-- Paid score is never refunded
function GM:NominateMisery( ply, setName )
    local can, reason = self:CanNominateMisery( ply, setName )
    if not can then
        ply:PrintMessage( HUD_PRINTTALK, reason )
        return

    end

    local cost = self:GetMiseryNominationCost( ply, setName )
    ply:GivePlayerScore( -cost )
    self.glee_MiseryNominations[ply:SteamID64()] = { setName = setName, cost = cost }
    self:MarkMiserySeen( ply, setName )

    PrintMessage( HUD_PRINTTALK, ply:Nick() .. " has nominated " .. self:GetPrettyNameOfSpawnSet( setName ) .. " for the next Misery vote." )

    self:SyncMiseryNominations( player.GetAll() )

end

-- What they paid is forfeit
function GM:WithdrawMiseryNomination( ply )
    local can, reason = self:CanWithdrawMiseryNomination( ply )
    if not can then
        ply:PrintMessage( HUD_PRINTTALK, reason )
        return

    end

    local nominations = self.glee_MiseryNominations
    local suspended = self.glee_SuspendedMiseryNominations
    local steamID64 = ply:SteamID64()
    local setName = ( nominations[steamID64] or suspended[steamID64] ).setName
    nominations[steamID64] = nil
    suspended[steamID64] = nil

    PrintMessage( HUD_PRINTTALK, ply:Nick() .. " has withdrawn their nomination of " .. self:GetPrettyNameOfSpawnSet( setName ) .. "." )

    self:SyncMiseryNominations( player.GetAll() )

end

-- Empties the nominations, returning them as [steamID64] = nomination. All of them are spent,
-- even ones the vote can no longer use. Suspended ones aren't on the ballot, so aren't spent
function GM:SpendMiseryNominations()
    local spent = table.Copy( self.glee_MiseryNominations )

    table.Empty( self.glee_MiseryNominations )
    self:SyncMiseryNominations( player.GetAll() )

    return spent

end

-- Tells the nominator, if they're still here, that a vote spent their nomination
function GM:NotifyMiseryNominationSpent( steamID64, setName, madeBallot )
    local ply = player.GetBySteamID64( steamID64 )
    if not IsValid( ply ) then return end

    local prettyName = self:GetPrettyNameOfSpawnSet( setName )
    if madeBallot then
        ply:PrintMessage( HUD_PRINTTALK, "Your nomination of " .. prettyName .. " has been placed on the ballot." )

    else
        ply:PrintMessage( HUD_PRINTTALK, "Your nomination of " .. prettyName .. " was spent, but could not be placed on the ballot." )

    end
end

-- Puts ply's suspended nomination back on the ballot, if it fits. It was paid for, so the bank item isn't needed again
function GM:TryRestoreMiseryNomination( ply )
    local steamID64 = ply:SteamID64()
    local nomination = self.glee_SuspendedMiseryNominations[steamID64]
    if not nomination then return end
    if self:IsMiseryVoteRunning() then return end
    if not self:CanMiseryTakeNomination( nomination.setName ) then return end

    self.glee_SuspendedMiseryNominations[steamID64] = nil
    self.glee_MiseryNominations[steamID64] = nomination

    PrintMessage( HUD_PRINTTALK, ply:Nick() .. "'s nomination of " .. self:GetPrettyNameOfSpawnSet( nomination.setName ) .. " has been restored." )

    self:SyncMiseryNominations( player.GetAll() )

end

-- a refusal is a chat message, so this keeps a client from flooding its own chat
local function tooSoon( ply )
    local nextRequest = ply.glee_NextMiseryNominate or 0
    if nextRequest > CurTime() then return true end
    ply.glee_NextMiseryNominate = CurTime() + 0.2

    return false

end

-- from cl_spawnsetnominate's huntersglee_misery_nominate
net.Receive( "glee_misery_nominate", function( _, ply )
    if tooSoon( ply ) then return end
    GAMEMODE:NominateMisery( ply, net.ReadString() )

end )

-- from cl_spawnsetnominate's huntersglee_misery_withdraw
net.Receive( "glee_misery_withdraw", function( _, ply )
    if tooSoon( ply ) then return end
    GAMEMODE:WithdrawMiseryNomination( ply )

end )

hook.Add( "glee_full_load", "glee_misery_nominations_sync", function( ply )
    GAMEMODE:SyncMiseryNominations( ply )

end )

-- a nomination is only on the ballot while its nominator is around to see it
hook.Add( "PlayerDisconnected", "glee_misery_nominations_suspend", function( ply )
    local nominations = GAMEMODE.glee_MiseryNominations
    local steamID64 = ply:SteamID64()
    local nomination = nominations[steamID64]
    if not nomination then return end

    nominations[steamID64] = nil
    GAMEMODE.glee_SuspendedMiseryNominations[steamID64] = nomination
    GAMEMODE:SyncMiseryNominations( player.GetAll() )

end )

-- room on the ballot opens up in too many ways to hook them all: withdrawals, votes, misery changes, departures
timer.Create( "glee_misery_nominations_restore", 1, 0, function()
    if table.IsEmpty( GAMEMODE.glee_SuspendedMiseryNominations ) then return end

    for _, ply in ipairs( player.GetAll() ) do
        GAMEMODE:TryRestoreMiseryNomination( ply )

    end
end )
