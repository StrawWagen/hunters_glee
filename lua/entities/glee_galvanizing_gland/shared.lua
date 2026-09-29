AddCSLuaFile()

-- invisible inflictor for the galvanizing gland's shocks, so the killfeed credits the gland
-- instead of whatever weapon its owner is holding

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName   = "Galvanizing Gland"
ENT.Author      = "StrawWagen"
ENT.Spawnable   = false

if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, "glee_galvanizing_gland", "vgui/hud/glee_lightning" )

end

ENT.IsGalvanizingGland = true

function ENT:Initialize()
    if not SERVER then return end
    self:SetNotSolid( true )
    self:SetNoDraw( true )
    self:DrawShadow( false )

end

function ENT:Draw() -- invis
end
