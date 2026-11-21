ENT.Type = "anim"
ENT.Base = "swepts_radio_old"

-- CREDITS!
-- Christmas stations by ANOT

ENT.PrintName = "Christmas Radio"
ENT.Author = "StrawWagen"
ENT.Purpose = "Play some festive music."
ENT.Instructions = "Hold E to tune it, or pick it up."
ENT.Category = "Hunter's Glee"
ENT.Spawnable = true

-- paths are under sound/
local stations = {
    { name = "ANOT: It's Beginning to Look a Lot Like Christmas",   path = "hunters_glee/music/ANOT/its beginning to look alot like christmas.mp3" },
    { name = "ANOT: Let It Snow",                                   path = "hunters_glee/music/ANOT/letitsnow2.mp3" },
    { name = "ANOT: Man With the Bag",                              path = "hunters_glee/music/ANOT/man with the bag.mp3" },
    { name = "ANOT: Mele Kalikimaka",                               path = "hunters_glee/music/ANOT/mele kalikimaka.mp3" },
    { name = "ANOT: Santa Claus Is Coming to Town",                 path = "hunters_glee/music/ANOT/santaclausiscomingtotown.mp3" },
    { name = "ANOT: Sleigh Ride",                                   path = "hunters_glee/music/ANOT/sleighride.mp3" },
    { name = "ANOT: The Human Foins",                               path = "hunters_glee/music/ANOT/the human foins.mp3" },
}

function ENT:SetupStations()
    self.Stations = stations

end
