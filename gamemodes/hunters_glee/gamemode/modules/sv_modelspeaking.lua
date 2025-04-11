local entMeta = FindMetaTable( "Entity" )
local GetModel = entMeta.GetModel

local string_find = string.find
local string_lower = string.lower
local string_replace = string.Replace

GM.allModelSounds = {}

function GM:AddModelSounds( partName, newSounds )
    local allSounds = self.allModelSounds
    if not allSounds then
        allSounds = {}
        self.allModelSounds = allSounds

    end

    local existingSounds = allSounds[partName]
    if not existingSounds then -- dont have to merge anything
        allSounds[partName] = newSounds

    else -- oh boy
        for addingCategory, currAddingSounds in pairs( newSounds ) do
            local existingSoundsForThis = existingSounds[addingCategory]
            local alreadyExists = {}
            if existingSoundsForThis then
                for _, existingSound in ipairs( existingSoundsForThis ) do
                    alreadyExists[existingSound] = true

                end
            else
                existingSoundsForThis = {}
                existingSounds[addingCategory] = existingSoundsForThis

            end
            for _, soundToAdd in ipairs( currAddingSounds ) do
                if alreadyExists[ soundToAdd ] then continue end
                local lower = string_lower( soundToAdd )
                table.insert( existingSoundsForThis, lower )

            end
        end
    end
end

local generic = {
    death = {
        "player/death1.wav",
        "player/death2.wav",
        "player/death3.wav",
        "player/death4.wav",
        "player/death5.wav",
        "player/death6.wav",

    },
    panicBuildingScreams = {
        "vo/npc/male01/help01.wav",
        "vo/npc/male01/pain01.wav",
        "vo/npc/male01/pain04.wav",
        "vo/npc/male01/pain08.wav",
        "vo/npc/male01/pain09.wav",
        "vo/npc/male01/startle01.wav",
        "vo/npc/male01/startle02.wav",

    },
    panicReleaseScreams = {
        "vo/npc/male01/pain07.wav",
        "vo/npc/male01/no01.wav",
        "vo/npc/male01/no02.wav",

    },
    panicReleaseScreamsChased = {
        "vo/npc/male01/strider_run.wav",
        "vo/npc/male01/runforyourlife01.wav",
        "vo/npc/male01/runforyourlife02.wav",
        "vo/npc/male01/runforyourlife03.wav",

    }
}

GM:AddModelSounds( "generic", generic )

local zombie = {
    death = {
        "npc/zombie/zombie_die1.wav",
        "npc/zombie/zombie_die2.wav",
        "npc/zombie/zombie_die3.wav",

    },
    panicBuildingScreams = {
        "npc/zombie/zombie_voice_idle10.wav",
        "npc/zombie/zombie_voice_idle5.wav",
        "npc/zombie/zombie_voice_idle8.wav",
        "npc/zombie/zombie_voice_idle14.wav",

    },
    panicReleaseScreams = {
        "npc/zombie/zombie_voice_idle5.wav",
        "npc/zombie/zombie_voice_idle13.wav",
        "npc/zombie/zombie_voice_idle11.wav",

    },
    panicReleaseScreamsChased = {
        "npc/zombie/zombie_alert3.wav",
        "npc/zombie/zo_attack1.wav",

    }
}

GM:AddModelSounds( "zombie", zombie )

local police = {
    death = {
        "npc/metropolice/die1.wav",
        "npc/metropolice/die2.wav",
        "npc/metropolice/die3.wav",
        "npc/metropolice/die4.wav",
        "npc/metropolice/knockout2.wav",

    },
    panicBuildingScreams = {
        "npc/metropolice/vo/cpiscompromised.wav",
        "npc/metropolice/vo/dispatchineed10-78.wav",
        "npc/metropolice/vo/help.wav",
        "npc/metropolice/vo/shit.wav",

    },
    panicReleaseScreams = {
        "npc/metropolice/vo/officerneedsassistance.wav",
        "npc/metropolice/vo/11-99officerneedsassistance.wav",
        "npc/metropolice/vo/officerneedshelp.wav",
        "npc/metropolice/vo/shit.wav",

    },
    panicReleaseScreamsChased = {
        "npc/metropolice/vo/takecover.wav",
        "npc/metropolice/vo/watchit.wav",
        "npc/metropolice/vo/lookout.wav",
        "npc/metropolice/vo/getdown.wav",
        "npc/metropolice/vo/cpisoverrunwehavenocontainment.wav",
        "npc/metropolice/vo/wehavea10-108.wav",

    }
}

GM:AddModelSounds( "police", police )

local combine = {
    death = {
        "npc/combine_soldier/die1.wav",
        "npc/combine_soldier/die2.wav",
        "npc/combine_soldier/die3.wav",

    },
    panicBuildingScreams = {
        "npc/combine_soldier/vo/coverhurt.wav",
        "npc/combine_soldier/vo/outbreak.wav",
        "npc/combine_soldier/vo/ripcord.wav",

    },
    panicReleaseScreams = {
        "npc/combine_soldier/vo/flaredown.wav",
        "npc/combine_soldier/vo/displace.wav",
        "npc/combine_soldier/vo/displace2.wav",
        "npc/combine_soldier/vo/ripcordripcord.wav",

    },
    panicReleaseScreamsChased = {
        "npc/combine_soldier/vo/heavyresistance.wav",
        "npc/combine_soldier/vo/contactconfim.wav",
        "npc/combine_soldier/vo/overwatchrequestskyshield.wav",

    }
}

GM:AddModelSounds( "combine_", combine )

local barney = {
    death = {
        "vo/npc/Barney/ba_pain06.wav",
        "vo/npc/Barney/ba_pain07.wav",
        "vo/npc/Barney/ba_pain09.wav",
        "vo/npc/Barney/ba_ohshit03.wav", --heh
        "vo/npc/Barney/ba_no01.wav",

    },
}

GM:AddModelSounds( "barney", barney )

local citizen = {
    death = {
        "vo/npc/male01/pain07.wav",
        "vo/npc/male01/pain08.wav",
        "vo/npc/male01/pain09.wav",
        "vo/npc/male01/pain04.wav",
        "vo/npc/male01/no02.wav",

    },
}

GM:AddModelSounds( "group", citizen )

local kleiner = {
    death = {
        "vo/k_lab/kl_ahhhh.wav",
        "vo/k_lab/kl_dearme.wav",

    },
    panicBuildingScreams = {
        "vo/k_lab/kl_mygoodness01.wav",
        "vo/k_lab/kl_ohdear.wav",
        "vo/k_lab/kl_hedyno03.wav",

    },
    panicReleaseScreams = {
        "vo/k_lab2/kl_greatscott.wav",
        "vo/trainyard/kl_morewarn01.wav",
        "vo/k_lab/kl_ahhhh.wav",

    },
    panicReleaseScreamsChased = {
        "vo/k_lab/kl_interference.wav",
        "vo/k_lab/kl_getoutrun02.wav",
        "vo/k_lab/kl_getoutrun03.wav",

    }
}

GM:AddModelSounds( "kleiner", kleiner )

local developer = GetConVar( "Developer")

local yapped = {}
local function yap( key, ... )
    if yapped[key] then return end
    yapped[key] = true
    if developer:GetBool() then
        ErrorNoHaltWithStack( ... )

    else
        print( ... )

    end
end

function GM:GetCorrectSoundsForModel( ply, category )
    local allSounds = self.allModelSounds

    local plysModelPart = "generic"
    local theGenericCategories = allSounds[plysModelPart]
    local theGenericSounds = theGenericCategories[category]
    if not theGenericSounds then yap( plysModelPart, "GLEE: Tried to get invalid sound category " .. category ) return end

    local plysMdl = string_lower( GetModel( ply ) )

    for partName, _ in pairs( allSounds ) do
        if string.find( plysMdl, partName ) then
            plysModelPart = partName
            break

        end
    end

    local categories = allSounds[plysModelPart]
    local sounds = categories[category]

    if not sounds or #sounds <= 0 then
        sounds = theGenericSounds

    end
    return sounds

end

function GM:GenderizeSound( ply, snd )
    if not string_find( snd, "male" ) then return snd end

    if string_find( string_lower( GetModel( ply ) ), "fem" ) then
        return string_replace( snd, "male", "female" )

    end
    return snd

end


function GM:GetRandModelLine( ply, category )
    local sounds = self:GetCorrectSoundsForModel( ply, category )
    local snd = sounds[math.random( 1, #sounds )]
    return self:GenderizeSound( ply, snd )

end