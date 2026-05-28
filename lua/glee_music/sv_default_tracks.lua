
local vacant = "VACANT"
local compakt = "COMPAKT"

local tracks = {
    heliEvac = {
        sounds = {
            { -- played first evac of a round
                maxDifficulty = 75,
                author = vacant,
                snd = "hunters_glee/music/VACANT/8.23.GleeExp2.ogg",
            },
            { -- played second evac of a round
                maxDifficulty = 75,
                author = vacant,
                snd = "hunters_glee/music/VACANT/__more_glee.ogg",
            },
            { -- played if difficulty is above 75, so if evac is late or difficulty is being bumped
                minDifficulty = 75,
                maxDifficulty = 150,
                author = vacant,
                snd = "hunters_glee/music/VACANT/8.23.GleeExp3.ogg",
            },
            { -- ditto
                minDifficulty = 150,
                author = vacant,
                snd = "hunters_glee/music/VACANT/HARD_EAS_gori_scuffle.ogg",
            },
            {
                minDifficulty = 150,
                author = vacant,
                snd = "hunters_glee/music/VACANT/8.24.to_noone.ogg",
            },
            {
                minDifficulty = 150,
                author = vacant,
                snd = "hunters_glee/music/VACANT/8.22.theGLEE.ogg",
            },
            {
                minDifficulty = 200,
                author = compakt,
                snd = "hunters_glee/music/COMPAKT/COMPAKT_Operating_Systems_09_Operator.mp3",
            },
        },
        priority     = 0,
        fadeInLength = 1,
        neverOverrides = { "grigoriArrival", "secondGrigoriArrival" },
    },

    highIntensity = {
        sounds = {
            {
                maxDifficulty = 100,
                author = vacant,
                snd = "hunters_glee/music/VACANT/clocklore.mp3",
            },
            {
                minDifficulty = 50,
                maxDifficulty = 200,
                author = vacant,
                snd = "hunters_glee/music/VACANT/8.23.GleeExp3.ogg",
            },
            {
                minDifficulty = 100,
                author = compakt,
                snd = "hunters_glee/music/COMPAKT/COMPAKT_Operating_Systems_05_Busy-Noisy.mp3",
            },
            {
                minDifficulty = 100,
                author = vacant,
                snd = "hunters_glee/music/VACANT/8.22.theGLEE.ogg",
            },
        },
        priority       = 0,
        neverOverrides = { "highIntensity", "grigoriArrival", "secondGrigoriArrival" },
    },

    grigoriArrival = {
        sounds = {
            {
                maxDifficulty = 200,
                author = vacant,
                snd = "hunters_glee/music/VACANT/gorihaunt.ogg",
            },
            {
                minDifficulty = 75,
                author = vacant,
                snd = "hunters_glee/music/VACANT/gorihaunt2.ogg",
            },
        },
        priority    = 0,
        randomOrder = true,
    },

    -- TODO: get updated song from vacancy
    secondGrigoriArrival = {
        sounds = {
            {
                author = vacant,
                snd = "hunters_glee/music/VACANT/___gorymphony.ogg",
            },
        },
        priority = 0,
    },

    roundEarlyStart = {
        sounds = {
            {
                author = vacant,
                snd = "hunters_glee/music/VACANT/wmrs.ogg",
            },
            {
                minDifficulty = 50,
                author = vacant,
                snd = "hunters_glee/music/VACANT/wmrs-crowbar.ogg",
            },
            {
                minDifficulty = 100,
                author = vacant,
                snd = "hunters_glee/music/VACANT/roundstart2.ogg",
            },
        },
        priority = 0,
    },

    roundEnd = {
        sounds = {
            {
                author = vacant,
                snd = "hunters_glee/music/VACANT/gleeroundendhoot6simple.ogg",
            },
        },
        priority = 0,
    },

    roundWin = {
        sounds = {
            {
                author = vacant,
                snd = "hunters_glee/music/VACANT/qutedeath-re.ogg",
            },
        },
        priority = 50,
    },

    roundPerfectWin = {
        sounds = {
            {
                maxDifficulty = 150,
                author = vacant,
                snd = "hunters_glee/music/VACANT/8.25.GleeFree-Early.ogg",
            },
            {
                minDifficulty = 100,
                author = vacant,
                snd = "hunters_glee/music/VACANT/ROOT_ESTRANGE.ogg",
            },
        },
        priority = 1000,
    },

    mapvoteMusic = {
        sounds = {
            {
                maxDifficulty = 75,
                author = vacant,
                snd = "hunters_glee/music/VACANT/wkc-rtv.ogg",
            },
            {
                minDifficulty = 75,
                maxDifficulty = 100,
                author = vacant,
                snd = "hunters_glee/music/VACANT/loop1-rtv.ogg",
            },
            {
                minDifficulty = 75,
                author = vacant,
                snd = "hunters_glee/music/VACANT/SEWERSiN.mp3",
            },
        },
        priority        = 5000,
        randomOrder     = true,
    },
}

GAMEMODE:GobbleMusicTracks( tracks )
