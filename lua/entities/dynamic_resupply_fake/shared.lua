AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Normal"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops either armor or medkits"
ENT.Spawnable   = true
ENT.Category    = "Hunter's Glee"
ENT.AdminOnly   = false

-- can't just set a table per-based entity, thanks garry
function ENT:commonCreationOptions()
    local tbl = {
        { class = "item_battery" },
        { class = "item_healthkit" },
        { class = "termhunt_score_pickup" },
        { class = "item_healthvial" }, -- spawn crappy more often
        { class = "item_healthvial" },
        { class = "item_healthvial" },

    }
    return tbl

end


ENT.rareCreationChance = 5

function ENT:rareCreationOptions()
    local tbl = {
        { class = "item_battery", count = 2 },
        { class = "item_ammo_smg1_grenade", count = 2 },
        { class = "item_ammo_ar2_altfire" },
        { class = "item_rpg_round", count = 2 },
        { class = "termhunt_score_pickup", count = 3 },
        { class = "weapon_frag", count = 4 },
        { class = "weapon_slam", count = 2 },
        { class = "weapon_stunstick" },
        { class = "termhunt_aeromatix_flare_gun" },
        { class = "termhunt_weapon_beartrap" },
        { class = "weapon_shotgun" },
        { class = "weapon_rpg" },
        { class = "weapon_pistol" }

    }
    return tbl

end

ENT.AmmoInsideWeaponsScale = 2

local upOffset = Vector( 0, 0, 5 )

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

        local randPitch = math.random( -1, 1 ) * 45
        local myPos = self:GetPos()

        for index = 1, count do
            local randYaw = math.random( -4, 4 ) * 45
            local angle = Angle( randPitch, randYaw, 0 )
            local pos = myPos + upOffset * index

            local item = ents.Create( class )
            item:SetAngles( angle )
            item:SetPos( pos )
            item:Spawn()

            if item:IsWeapon() and GAMEMODE.GiveWeaponClipsOfAmmo then
                local clipsToGive = math.Rand( 0.5, 1.5 )
                if math.random( 0, 100 ) < 15 then
                    clipsToGive = math.max( clipsToGive, 1 )
                    clipsToGive = clipsToGive * math.Rand( 3, 6 )

                elseif math.random( 0, 100 ) < 50 then
                    clipsToGive = math.max( clipsToGive, 1 )
                    clipsToGive = clipsToGive * math.Rand( 1, 2 )

                end
                clipsToGive = clipsToGive * self.AmmoInsideWeaponsScale
                GAMEMODE:GiveWeaponClipsOfAmmo( item, clipsToGive )

            end

            terminator_Extras.SmartSleepEntity( item, 20 )

            timer.Simple( 60 * 15, function()
                if not IsValid( item ) then return end
                if IsValid( item:GetParent() ) then return end
                SafeRemoveEntity( item )

            end )
        end

        SafeRemoveEntity( self )

    end
end