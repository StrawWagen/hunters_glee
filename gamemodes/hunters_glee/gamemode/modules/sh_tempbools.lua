-- this system is mildly stupid

function GM:isTemporaryTrueBool( name )
    if GetGlobalBool( name, false ) == true then return true end

end

if SERVER then
    local temporaryTrueBoolIdentifiers = {}

    hook.Add( "PostCleanupMap", "glee_ResetTemporaryTrueBools", function()
        for _, tempBoolIdentifier in ipairs( temporaryTrueBoolIdentifiers ) do
            SetGlobalBool( tempBoolIdentifier, false )

        end
        temporaryTrueBoolIdentifiers = {}

    end )

    function GM:setTemporaryTrueBool( name, timeTilRemove )
        if not isnumber( timeTilRemove ) or timeTilRemove <= 0 then
            error( "GLEE: Tried to set temporary bool with non-number second argument." )
            return -- return, lol

        end
        SetGlobalBool( name, true )
        table.insert( temporaryTrueBoolIdentifiers, name )

        local timerName = "glee_TempTrueBoolManage_" .. name
        if timer.Exists( timerName ) then
            timer.Remove( timerName )

        end
        timer.Create( timerName, timeTilRemove, 1, function()
            SetGlobalBool( name, false )
            table.RemoveByValue( temporaryTrueBoolIdentifiers, name )

        end )
    end
end