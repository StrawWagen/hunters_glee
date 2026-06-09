local mapCache      = {}
local spawnsetCache = {}

net.Receive( "glee_escapemul_data", function()
    local count = math.min( net.ReadUInt( 8 ), 64 )
    for _ = 1, count do
        local isSpawnset = net.ReadBool()
        local key        = net.ReadString()
        local mul        = net.ReadFloat()
        local escaped    = net.ReadUInt( 32 )
        local remained   = net.ReadUInt( 32 )

        local entry = { mul = mul, escaped = escaped, remained = remained }
        if key == "" then continue end

        if isSpawnset then
            spawnsetCache[key] = entry

        else
            mapCache[key] = entry

        end
    end
end )

-- Explicitly request multipliers for a batch of maps/spawnsets.
-- list format: { { isSpawnset = bool, key = string }, ... }
-- Skips keys that are already cached or already in-flight.
function GM:RequestEscapeMultipliers( list )
    local toRequest = {}
    for _, entry in ipairs( list ) do
        local cache = entry.isSpawnset and spawnsetCache or mapCache
        if cache[entry.key] then continue end

        toRequest[#toRequest + 1] = entry

    end

    if #toRequest == 0 then return end

    net.Start( "glee_escapemul_request" )
        net.WriteUInt( #toRequest, 8 )
        for _, entry in ipairs( toRequest ) do
            net.WriteBool( entry.isSpawnset )
            net.WriteString( entry.key )

        end
    net.SendToServer()

end

function GM:GetMapsEscapeMultiplier( mapName )
    local entry = mapCache[mapName]
    if not entry then return 0, 0, 0 end
    return entry.mul, entry.escaped, entry.remained

end

function GM:GetSpawnsetsEscapeMultiplier( spawnSetName )
    local entry = spawnsetCache[spawnSetName]
    if not entry then return 0, 0, 0 end
    return entry.mul, entry.escaped, entry.remained

end

hook.Add( "MapVote_MapIconCreated", "glee_escapecounts_mapicon", function( icon )
    timer.Simple( 0, function()
        if not IsValid( icon ) then return end

        local iconLabel = icon.label
        if not IsValid( iconLabel ) then return end

        local percentLabel = icon.percentLabel
        if not IsValid( percentLabel ) then return end

        local mapnameRaw = iconLabel:GetText()
        local mapName = string.lower( mapnameRaw )

        icon.escapeRewardLabel = vgui.Create( "DLabel", icon.infoRow ) --[[@as DLabel]]
        icon.escapeRewardLabel:DockMargin( 5, 0, 0, 0 )
        icon.escapeRewardLabel:SetContentAlignment( 4 )
        icon.escapeRewardLabel:SetFont( percentLabel:GetFont() )
        icon.escapeRewardLabel:SetTextColor( MapVote.style.colorTextPrimary )
        icon.escapeRewardLabel:SetText( "" )

        if MapVote.style.bottomUpIconFilling then
            icon.escapeRewardLabel:Dock( TOP )

        else
            icon.escapeRewardLabel:Dock( BOTTOM )

        end

        function icon.escapeRewardLabel:Think()
            self:SetFont( percentLabel:GetFont() )

            local mul, _escaped, _remained = GAMEMODE:GetMapsEscapeMultiplier( mapName )
            local text = math.Round( mul, 2 ) .. "x Escape Reward"
            self:SetText( text )
            self:SizeToContents()

        end
    end )
end )
