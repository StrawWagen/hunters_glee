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

function ENT:SetupDataTables()
    self:NetworkVar( "Int", 0, "Channel" )

end