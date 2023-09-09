AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Normal"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops either armor or medkits"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = false

-- can't just set a table per-based entity, thanks garry
function ENT:commonCreationOptions()
    local tbl = {
        { class = "item_battery" },
        { class = "item_healthkit" },
        { class = "item_healthvial" },
        { class = "termhunt_score_pickup" }

    }
    return tbl

end

ENT.rareCreationChance = 5

function ENT:rareCreationOptions()
    local tbl = {
        { class = "item_ammo_smg1_grenade", count = 3 },
        { class = "weapon_frag", count = 4 },
        { class = "weapon_slam", count = 2 },
        { class = "weapon_stunstick" },
        { class = "termhunt_aeromatix_flare_gun" },
        { class = "weapon_shotgun" },
        { class = "weapon_rpg" },
        { class = "weapon_pistol" }

    }
    return tbl

end

function ENT:Initialize()
    if SERVER then
        self:SetNoDraw( true )

        local toCreate = self:commonCreationOptions()
        local random = math.random( 0, 100 )

        if random <= self.rareCreationChance then
            toCreate = self:rareCreationOptions()

        end

        local selected = table.Random( toCreate )

        local count = selected.count or 1
        local class = selected.class

        PrintTable( selected )
        print( random, self.rareCreationChance )

        for _ = 1, count do
            local item = ents.Create( class )
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