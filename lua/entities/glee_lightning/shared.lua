AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Lightning"
ENT.Author      = "StrawWagen"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = true

ENT.powa = 1

if SERVER then
    resource.AddFile( "sounds/hunters_glee/wizardry_thunderimpact.wav" ) -- FROM SHADOW MONEY WIZARD https://steamcommunity.com/sharedfiles/filedetails/?id=3046835259
    resource.AddFile( "sounds/hunters_glee/wizardry_thunder.wav" ) -- DITTO!
    resource.AddFile( "sounds/hunters_glee/397952_kinoton_thunder-clap-and-rumble-1.wav" )
    resource.AddFile( "materials/vgui/hud/glee_lightning.vmt" )

else
    killicon.Add( "glee_lightning", "vgui/hud/glee_lightning" )

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