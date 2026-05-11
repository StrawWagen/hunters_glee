
terminator_Extras = terminator_Extras or {}

AddCSLuaFile()

if SERVER then
    util.AddNetworkString( "termhunt_ectoplasmeffect" )
    function terminator_Extras.DoEctoplasmAtPos( pos, scale )
        local recipFilter = RecipientFilter()
        recipFilter:AddPAS( pos )
        net.Start( "termhunt_ectoplasmeffect" )
            net.WriteVector( pos )
            net.WriteFloat( scale )
        net.Send( recipFilter )
    end
else
    net.Receive( "termhunt_ectoplasmeffect", function()
        local pos = net.ReadVector()
        local scale = net.ReadFloat()

        local effectdata = EffectData()
            effectdata:SetOrigin( pos )
            effectdata:SetScale( scale )
        util.Effect( "eff_huntersglee_ectoplasmprojectiles", effectdata )
    end )
end