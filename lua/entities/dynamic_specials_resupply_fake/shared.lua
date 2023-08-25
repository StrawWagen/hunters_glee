AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Dynamic specials"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops SMG nades, ar2 balls"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = false

function ENT:Initialize()
    if SERVER then
        self:SetNoDraw( true )

        local toCreate = { "item_ammo_smg1_grenade", "item_ammo_ar2_altfire", "item_rpg_round", { "termhunt_score_pickup", 3 } }

        local selected = table.Random( toCreate )
        local count = 1

        if istable( selected ) then
            count = selected[2]
            selected = selected[1]

        end

        for _ = 1, count do
            local item = ents.Create( selected )
            item:SetPos( self:GetPos() )
            item:Spawn()

        end

        timer.Simple( 60 * 8, function()
            if not IsValid( item ) then return end
            if IsValid( item:GetParent() ) then return end
            SafeRemoveEntity( item )

        end )

        SafeRemoveEntity( self )

    end
end