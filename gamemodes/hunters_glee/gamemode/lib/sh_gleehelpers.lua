
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

    -- Players, and anything passing as one, like a doppelganger wearing a player's name.
    -- Word messages about a thing with this, not IsPlayer, or a different line gives the disguise away
    -- What the living's suit calls ent. A dead or escaped player's signal confuses it, so they're tagged.
    -- Only in a notice's description, and only for the living, the dead have no suit
    function GM:SuitNameOf( ent )
        local name = self:GetNameOfBot( ent )
        if not IsValid( ent ) or not ent:IsPlayer() or ent:Health() > 0 then return name end

        if ent:HasEscaped() then
            return name .. "[ESCAPED]"

        end
        return name .. "[DECEASED?]"

    end

    function GM:LooksLikePlayer( ent )
        if ent:IsPlayer() then return true end
        return isfunction( ent.Nick ) and ent:Nick() ~= nil

    end
end

do
    local string = string

    local function partialNameMatch( arg )
        local lowerArg = string.lower( arg )
        local match
        local matches = 0
        for _, ply in player.Iterator() do
            local lowerNick = string.lower( ply:Nick() )
            if lowerNick == lowerArg then return ply end
            if not string.find( lowerNick, lowerArg, 1, true ) then continue end
            match = ply
            matches = matches + 1

        end

        if matches == 1 then return match end
        if matches > 1 then return nil, "GLEE: " .. arg .. " matches " .. matches .. " players." end
        return nil, "GLEE: No one called " .. arg .. "."

    end

    -- A console command's argStr, split on spaces with quotes dropped.
    -- Source's own args split on colons too, so an unquoted SteamID arrives in pieces
    function GM:ArgWords( argStr )
        local words = {}
        for word in string.gmatch( argStr, "[^%s\"]+" ) do
            words[#words + 1] = word

        end

        return words

    end

    -- For console command args, one word of ArgWords. Takes a SteamID, SteamID64, UserID, or a name, exact or a unique partial.
    -- Returns the player, and their SteamID. A SteamID or SteamID64 of someone offline returns nil and that SteamID
    -- A name that finds nobody returns nil, nil, and a message saying why
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

        local ply, failReason = partialNameMatch( arg )
        if IsValid( ply ) then return ply, ply:SteamID() end
        return nil, nil, failReason

    end
end
