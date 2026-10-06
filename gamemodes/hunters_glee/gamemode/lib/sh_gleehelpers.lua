
do
    local string = string

    -- Shared, so clients can name things themselves. Set a pretty name with
    -- SetNWString( "glee_PrettyName", ... )
    function GM:GetNameOfBot( bot )
        local name = ""
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
