ENT.Type = "anim"
ENT.Base = "base_anim"

-- CREDITS!
-- Swept's Radios 2 https://steamcommunity.com/sharedfiles/filedetails/?id=1368958015 by SweptThrone

ENT.PrintName = "Radio"
ENT.Author = "SweptThrone + StrawWagen"
ENT.Contact = "sweptthrone971@gmail.com"
ENT.Purpose = "Play some good music."
ENT.Instructions = "Press E to play music."
ENT.Category = "Hunter's Glee"
ENT.Spawnable = true

-- How near a player has to stay to tune it. Its menu closes past this
ENT.TuneRange = 400

-- Song 0 is off. https://combineoverwiki.net/wiki/Half-Life_2_soundtrack
ENT.OffSound = "ambient/_period.wav"
ENT.Stations = {
    { name = "The Innsbruck Experiment",        path = "music/hl2_song4.mp3" },
    { name = "Brane Scan",                      path = "music/hl2_song31.mp3" },
    { name = "Dark Energy",                     path = "music/hl2_song3.mp3" },
    { name = "Requiem For Ravenholm",           path = "music/ravenholm_1.mp3" },
    { name = "Pulse Phase",                     path = "music/hl2_song6.mp3" },
    { name = "Ravenholm Reprise",               path = "music/hl2_song7.mp3" },
    { name = "Probably Not a Problem",          path = "music/hl2_song33.mp3" },
    { name = "Calabi-Yau Model",                path = "music/hl2_song30.mp3" },
    { name = "Slow Light",                      path = "music/hl2_song32.mp3" },
    { name = "Apprehension and Evasion",        path = "music/hl2_song29.mp3" },
    { name = "Our Resurrected Teleport",        path = "music/hl2_song26.mp3" },
    { name = "Triage at Dawn",                  path = "music/hl2_song23_SuitSong3.mp3" },
    { name = "Lab Practicum",                   path = "music/hl2_song2.mp3" },
    { name = "Nova Prospekt",                   path = "music/hl2_song19.mp3" },
    { name = "Broken Symmetry",                 path = "music/hl2_song17.mp3" },
    { name = "LG Orbifold",                     path = "music/hl2_song16.mp3" },
    { name = "Kaon",                            path = "music/hl2_song15.mp3" },
    { name = "You're Not Supposed to Be Here",  path = "music/hl2_song14.mp3" },
    { name = "Hard Fought",                     path = "music/hl2_song12_long.mp3" },
    { name = "Particle Ghost",                  path = "music/hl2_song1.mp3" },
    { name = "Neutrino Trap",                   path = "music/hl1_song9.mp3" },
    { name = "Zero Point Energy Field",         path = "music/hl1_song6.mp3" },
    { name = "Echoes of a Resonance Cascade",   path = "music/hl1_song5.mp3" },
    { name = "Black Mesa Inbound",              path = "music/hl1_song3.mp3" },
    { name = "Xen Relay",                       path = "music/hl1_song26.mp3" },
    { name = "Singularity",                     path = "music/hl1_song24.mp3" },
    { name = "Dirac Shore",                     path = "music/hl1_song21.mp3" },
    { name = "Escape Array",                    path = "music/hl1_song20.mp3" },
    { name = "Negative Pressure",               path = "music/hl1_song19.mp3" },
    { name = "Tau-9",                           path = "music/hl1_song17.mp3" },
    { name = "Something Secret Steers Us",      path = "music/hl1_song15.mp3" },
    { name = "Triple Entanglement",             path = "music/hl1_song14.mp3" },
    { name = "Lambda Core",                     path = "music/hl1_song10.mp3" },
    { name = "Entanglement",                    path = "music/hl2_song0.mp3" },
    { name = "Train Station 1",                 path = "music/hl2_song26_trainstation1.mp3" },
    { name = "Train Station 2",                 path = "music/hl2_song27_trainstation2.mp3" },
    { name = "---",                             path = "music/radio1.mp3" },
    { name = "CSS: The Sweet Sound of Bongo",   path = "ambient/music/bongo.wav" },
    { name = "CSS: Only the Classics",          path = "ambient/music/piano1.wav" },
    { name = "CSS: Country Rockin' Radio",      path = "ambient/music/country_rock_am_radio_loop.wav" },
    { name = "CSS: Cubic Cuban",                path = "ambient/music/cubanmusic1.wav" },
    { name = "CSS: Desert Sands FM",            path = "ambient/music/dustmusic2.wav" },
    { name = "CSS: Fine-Tuned Tunes",           path = "ambient/music/piano2.wav" },
    { name = "CSS: Flamenco Folk Music",        path = "ambient/music/flamenco.wav" },
    { name = "CSS: Glamorous Guitar",           path = "ambient/guit1.wav" },
    { name = "CSS: Countryside Jams",           path = "test/temp/soundscape_test/tv_music.wav" },
    { name = "CSS: Latin Listening",            path = "ambient/music/latin.wav" },
    { name = "CSS: Tunes of the Middle East",   path = "ambient/music/dustmusic1.wav" },
    { name = "CSS: Outstanding Opera",          path = "ambient/opera.wav" },
    { name = "CSS: Songs of the Salsa",         path = "ambient/music/mirame_radio_thru_wall.wav" },
    { name = "CSS: Syrian Serenade",            path = "ambient/music/dustmusic3.wav" },
}

function ENT:SetupDataTables()
    self:NetworkVar( "Int", 0, "Song" ) -- index into Stations, 0 is off

end

-- The server's check before a tune, and what keeps the client's menu open
function ENT:CanBeTunedBy( ply )
    if not ply:Alive() then return false end

    return ply:GetShootPos():DistToSqr( self:WorldSpaceCenter() ) < self.TuneRange ^ 2

end
