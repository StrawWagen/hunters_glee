local entMeta = FindMetaTable( "Entity" )
local GetModel = entMeta.GetModel

local string_find = string.find
local string_lower = string.lower
local string_replace = string.Replace

GM.modelSoundAliases = {}
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

function GM:AddModelSoundAlias( alias, aliasOf )
    local aliases = self.modelSoundAliases
    if not aliases then
        aliases = {}
        self.modelSoundAliases = aliases

    end

    aliases[alias] = aliasOf

end

local silent = {
    death = {
    },
    panicBuildingScreams = {
    },
    panicReleaseScreams = {
    },
    panicReleaseScreamsChased = {
    }
}
GM:AddModelSounds( "chell", silent ) -- i wonder if she has vocal cords
GM:AddModelSounds( "soldier_stripped", silent ) -- i dont think this guy has vocal cords
GM:AddModelSounds( "corpse1", silent ) -- ditto
GM:AddModelSounds( "charple", silent ) -- ditto

local skeleton = {
    death = {
        "hunters_glee/skeleton_death_sound.mp3" -- lmao
    },
    panicBuildingScreams = {
    },
    panicReleaseScreams = {
    },
    panicReleaseScreamsChased = {
    }
}
GM:AddModelSounds( "skeleton", skeleton )

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
GM:AddModelSoundAlias( "skeleton", "zombie" )

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
        "npc/metropolice/pain1.wav",
        "npc/metropolice/vo/help.wav",
        "npc/metropolice/pain3.wav",
        "npc/metropolice/vo/shit.wav",

    },
    panicReleaseScreams = {
        "npc/metropolice/vo/officerneedsassistance.wav",
        "npc/metropolice/vo/officerneedshelp.wav",
        "npc/metropolice/vo/cpisoverrunwehavenocontainment.wav",
        "npc/metropolice/vo/shit.wav",

    },
    panicReleaseScreamsChased = {
        "npc/metropolice/vo/takecover.wav",
        "npc/metropolice/vo/watchit.wav",
        "npc/metropolice/vo/lookout.wav",
        "npc/metropolice/vo/getdown.wav",
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
        "npc/combine_soldier/pain2.wav",
        "npc/combine_soldier/vo/ripcord.wav",
        "npc/combine_soldier/pain3.wav",
        "npc/combine_soldier/vo/outbreak.wav",

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
        "vo/npc/barney/ba_pain06.wav",
        "vo/npc/barney/ba_pain07.wav",
        "vo/npc/barney/ba_pain09.wav",
        "vo/npc/barney/ba_ohshit03.wav",
        "vo/npc/barney/ba_no01.wav",

    },
    panicBuildingScreams = {
        "vo/npc/barney/ba_pain05.wav",
        "vo/npc/barney/ba_pain07.wav",
        "vo/npc/barney/ba_pain10.wav",
        "vo/npc/barney/ba_pain04.wav",

    },
    panicReleaseScreams = {
        "vo/npc/barney/ba_no01.wav",
        "vo/npc/barney/ba_no02.wav",
        "vo/npc/barney/ba_no01.wav",

    },
    panicReleaseScreamsChased = {
        "vo/npc/barney/ba_hereitcomes.wav",
        "vo/npc/barney/ba_getdown.wav",
        "vo/npc/barney/ba_getoutofway.wav",

    }
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
GM:AddModelSoundAlias( "mossman", "group" ) -- mossman doesnt have any good sounds :(

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

local alyx = {
    death = {
        "vo/npc/alyx/uggh02.wav",
        "vo/npc/alyx/hurt04.wav",
        "vo/npc/alyx/no02.wav",
        "vo/novaprospekt/al_combinespy01.wav",

    },
    panicBuildingScreams = {
        "vo/novaprospekt/al_horrible01.wav",
        "vo/novaprospekt/al_gasp01.wav",
        "vo/npc/alyx/gasp03.wav",
        "vo/npc/alyx/gasp02.wav",
        "vo/eli_lab/al_dogairlock01.wav",

    },
    panicReleaseScreams = {
        "vo/novaprospekt/al_ohmygod.wav",
        "vo/npc/alyx/hurt05.wav",
        "vo/npc/alyx/uggh02.wav",
        "vo/npc/alyx/ohno_startle01.wav",
        "vo/npc/alyx/ohno_startle03.wav",

    },
    panicReleaseScreamsChased = {
        "vo/novaprospekt/al_backdown.wav",
        "vo/npc/alyx/getback01.wav",
        "vo/npc/alyx/watchout01.wav",
        "vo/npc/alyx/watchout02.wav",
        "vo/eli_lab/al_getitopen01.wav",

    }
}
GM:AddModelSounds( "alyx", alyx )

local breen = {
    death = {
        "vo/citadel/br_no.wav",
        "vo/citadel/br_youneedme.wav",

    },
    panicBuildingScreams = {
        "vo/k_lab/br_tele_02.wav",
        "vo/citadel/br_no.wav",
        "vo/citadel/br_failing11.wav",

    },
    panicReleaseScreams = {
        "vo/citadel/br_ohshit.wav",
        "vo/citadel/br_youfool.wav",
        "vo/citadel/br_no.wav",
        "vo/citadel/br_whatittakes.wav",

    },
    panicReleaseScreamsChased = {
        "vo/citadel/br_justhurry.wav",
        "vo/citadel/br_mock06.wav",
        "vo/citadel/br_guards.wav",

    }
}
GM:AddModelSounds( "breen", breen )

local eli = {
    death = {
        "vo/citadel/eli_alyx01.wav",
        "vo/citadel/eli_alyxsweetheart.wav",

    },
    panicBuildingScreams = {
        "vo/citadel/eli_goodgod.wav",
        "vo/eli_lab/eli_safety.wav",

    },
    panicReleaseScreams = {
        "vo/citadel/eli_notobreen.wav",

    },
    panicReleaseScreamsChased = {
        "vo/k_lab/eli_seeforyourself.wav",
        "vo/k_lab/eli_behindyou.wav",
        "vo/novaprospekt/eli_nevermindme01.wav",

    }
}
GM:AddModelSounds( "/eli", eli )

local gman = {
    death = {
        "vo/citadel/gman_exit10.wav",

    },
    panicBuildingScreams = {
    },
    panicReleaseScreams = {
        "vo/citadel/gman_exit02.wav",
        "vo/citadel/gman_exit03.wav",
        "vo/citadel/gman_exit08.wav",

    },
    panicReleaseScreamsChased = {
        "vo/citadel/gman_exit03.wav",
        "vo/k_lab/eli_behindyou.wav",
        "vo/novaprospekt/eli_nevermindme01.wav",

    }
}
GM:AddModelSounds( "gman", gman )

local grigori = {
    death = {
        "vo/ravenholm/monk_helpme01.wav",
        "vo/ravenholm/monk_helpme04.wav",
        "vo/ravenholm/monk_pain08.wav",
        "vo/ravenholm/monk_pain04.wav",
        "vo/ravenholm/monk_pain09.wav",

    },
    panicBuildingScreams = {
        "vo/ravenholm/monk_pain01.wav",
        "vo/ravenholm/monk_pain02.wav",
        "vo/ravenholm/monk_pain03.wav",
        "vo/ravenholm/monk_pain05.wav",
        "vo/ravenholm/monk_pain06.wav",
        "vo/ravenholm/monk_pain07.wav",
        "vo/ravenholm/monk_pain06.wav",
    },
    panicReleaseScreams = {
        "vo/ravenholm/monk_pain08.wav",
        "vo/ravenholm/monk_pain04.wav",
        "vo/ravenholm/monk_pain09.wav",
        "vo/ravenholm/monk_pain12.wav",
        "vo/ravenholm/madlaugh03.wav",

    },
    panicReleaseScreamsChased = {
        "vo/ravenholm/monk_quicklybro.wav",
        "vo/ravenholm/exit_nag01.wav",
        "vo/ravenholm/monk_danger01.wav",
        "vo/ravenholm/monk_danger02.wav",
        "vo/ravenholm/monk_danger03.wav",
        "vo/ravenholm/monk_helpme02.wav",

    }
}
GM:AddModelSounds( "monk", grigori )


local yapped = {}
local function yap( key, ... )
    if yapped[key] then return end
    yapped[key] = true
    print( ... )

end

local genericStr = "generic"
local cachedCategories = {}

function GM:GetCorrectSoundsForModel( ply, category )
    local allSounds = self.allModelSounds

    local plysModelPart = genericStr
    local theGenericCategories = allSounds[plysModelPart]
    local theGenericSounds = theGenericCategories[category]
    if not theGenericSounds then yap( plysModelPart, "GLEE: Tried to get invalid sound category " .. category ) return end

    local plysMdl = string_lower( GetModel( ply ) )
    local cache = cachedCategories[plysMdl]
    if not cache then
        for partName, _ in pairs( allSounds ) do
            if string.find( plysMdl, partName ) then
                plysModelPart = partName
                break

            end
        end
        if plysModelPart == genericStr then
            local aliases = self.modelSoundAliases
            for alias, aliasOf in pairs( aliases ) do
                if string.find( plysMdl, alias ) then
                    plysModelPart = aliasOf
                    break

                end
            end
        end

        local categories = allSounds[plysModelPart]
        local sounds = categories[category]

        if not sounds then
            sounds = theGenericSounds

        end
        cache = sounds
        cachedCategories[plysMdl] = cache
        return cache

    else
        return cache

    end
end

local hardcodedFemale = {
    ["models/player/p2_chell.mdl"] = true,
    ["models/player/mossman.mdl"] = true,

}

function GM:GenderizeSound( ply, snd )
    if not string_find( snd, "male" ) then return snd end

    local plyModel = GetModel( ply )
    if hardcodedFemale[ plyModel ] or string_find( string_lower( plyModel ), "fem" ) then
        return string_replace( snd, "male", "female" )

    end
    return snd

end


function GM:GetRandModelLine( ply, category )
    local sounds = self:GetCorrectSoundsForModel( ply, category )
    if #sounds <= 0 then return end
    local snd = sounds[math.random( 1, #sounds )]
    return self:GenderizeSound( ply, snd )

end