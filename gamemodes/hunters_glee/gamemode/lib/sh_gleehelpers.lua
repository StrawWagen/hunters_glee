
do
    local string = string

    -- Shared, so clients can name things themselves. Set a pretty name with
    -- SetNWString( "glee_PrettyName", ... )
    function GM:GetNameOfBot( bot )
        local name = ""
        if not IsValid( bot ) then
            return "Something"

        end
        if bot.Nick and isfunction( bot.Nick ) then
            return bot:Nick() or "Something"

        end

        local prettyName = bot:GetNWString( "glee_PrettyName", "" )
        if prettyName ~= "" then
            name = prettyName

        else
            name = bot.PrintName
            if not name then
                if bot:IsNPC() then
                    name = "A NPC"
                elseif bot:IsNextBot() then
                    name = "A Nextbot"
                else
                    name = "Something"
                end
            end

            local nameLower = string.lower( name )
            nameLower = string.Trim( nameLower )
            if not ( string.StartsWith( nameLower, "a " ) or string.StartsWith( nameLower, "the " ) ) then
                name = "A " .. name

            end
        end
        return name

    end
end

do
    local string = string

    local function partialNameMatch( arg )
        local lowerArg = string.lower( arg )
        local match
        for _, ply in player.Iterator() do
            local lowerNick = string.lower( ply:Nick() )
            if lowerNick == lowerArg then return ply end
            if not string.find( lowerNick, lowerArg, 1, true ) then continue end
            if match then return end -- ambiguous, unless an exact match turns up
            match = ply

        end
        return match

    end

    -- For console command args. Takes a SteamID, SteamID64, UserID, or a name, exact or a unique partial.
    -- Returns the player, and their SteamID. A SteamID or SteamID64 of someone offline returns nil and that SteamID
    function GM:FindPlayerByArg( arg )
        if not arg or arg == "" then return end

        if string.StartsWith( arg, "STEAM_" ) then
            local ply = player.GetBySteamID( arg )
            if IsValid( ply ) then return ply, arg end
            return nil, arg

        end

        if string.match( arg, "^7656%d+$" ) and #arg == 17 then
            local ply = player.GetBySteamID64( arg )
            if IsValid( ply ) then return ply, ply:SteamID() end
            return nil, util.SteamIDFrom64( arg )

        end

        local userID = tonumber( arg )
        if userID then
            local ply = Player( userID )
            if IsValid( ply ) then return ply, ply:SteamID() end

        end

        local ply = partialNameMatch( arg )
        if IsValid( ply ) then return ply, ply:SteamID() end

    end
end
