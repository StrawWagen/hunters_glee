AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Random weapons"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Spawns random weapons"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = false

function ENT:Initialize()
    if SERVER then
        self:SetNoDraw( true )

        local toCreate = { "weapon_stunstick",
            "termhunt_aeromatix_flare_gun",
            { "weapon_slam", 3 },
            { "weapon_frag", 4 },
            "weapon_shotgun",
            "weapon_rpg",
            "weapon_pistol",
            "weapon_ar2",
            "weapon_357",
            "weapon_crossbow"
        }

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