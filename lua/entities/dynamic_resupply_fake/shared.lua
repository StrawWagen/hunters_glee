AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Fake dynamic resupply"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops either armor or medkits"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = false

function ENT:Initialize()
    if SERVER then
        self:SetNoDraw( true )

        local rareCreationOptions = { { "item_ammo_smg1_grenade", 3 }, { "weapon_frag", 4 }, "weapon_stunstick", { "weapon_slam", 2 }, "weapon_shotgun", "weapon_rpg", "weapon_pistol" }
        local toCreate = { "item_battery", "item_healthkit", "item_healthvial", "termhunt_score_pickup" }

        if math.random( 0, 100 ) > 95 then
            toCreate = rareCreationOptions
        end

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