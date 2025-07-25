AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Lightning"
ENT.Author      = "StrawWagen"
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.Category = "Hunter's Glee"

ENT.powa = 1

    -- "sounds/hunters_glee/wizardry_thunderimpact.wav" FROM SHADOW MONEY WIZARD https://steamcommunity.com/sharedfiles/filedetails/?id=3046835259
    -- "sounds/hunters_glee/wizardry_thunder.wav" -- DITTO!
if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, "glee_lightning", "vgui/hud/glee_lightning" )

end

function ENT:SetPowa( newPowa )
    self.powa = newPowa

end

function ENT:Initialize()
    if not SERVER then return end
    self:SetNotSolid( true )
    self:SetNoDraw( true )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        termHunt_PowafulLightning( self, self:GetOwner(), self:GetPos() + ( vector_up * 10 ), self.powa )

        SafeRemoveEntityDelayed( self, 0.1 )

    end )
end