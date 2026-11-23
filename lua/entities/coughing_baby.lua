-- credit to https://steamcommunity.com/sharedfiles/filedetails/?id=3393889422 for the og addon

AddCSLuaFile()

ENT.Base = "base_gmodentity"
ENT.Type = "anim"

ENT.PrintName = "Coughing Baby"
ENT.Author = "Hockernusious"
ENT.Category = "Hunter's Glee"
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Soul constants
local SOUL_SOUND = "ambient/voices/crying_loop1.wav"
local SOUL_COLOR = Color(52, 133, 132, 100)

-- Other sound and decal constants
local coughSounds = {
    "ambient/voices/cough1.wav",
    "ambient/voices/cough2.wav",
    "ambient/voices/cough3.wav",
    "ambient/voices/cough4.wav"
}

local bloodDecals = {
    "Blood",
    "BloodDecal",
    "BloodSplat",
    "BloodSplatLarge",
    "BloodSplatSmall"
}

local yellowBloodDecals = {
    "YellowBlood",
    "YellowBloodSplatter",
    "YellowBloodSpurt"
}

local painSounds = {
    "npc/headcrab_poison/ph_pain1.wav",
    "npc/headcrab_poison/ph_pain2.wav",
    "npc/headcrab_poison/ph_pain3.wav",
    "npc/headcrab_poison/ph_wallpain1.wav",
    "npc/headcrab_poison/ph_wallpain2.wav",
    "npc/headcrab_poison/ph_wallpain3.wav"
}

local vomitSounds = {
    "ambient/levels/canals/toxic_slime_gurgle2.wav",
    "ambient/levels/canals/toxic_slime_gurgle3.wav",
    "ambient/levels/canals/toxic_slime_gurgle4.wav",
    "ambient/levels/canals/toxic_slime_gurgle5.wav",
    "ambient/levels/canals/toxic_slime_gurgle6.wav",
    "ambient/levels/canals/toxic_slime_gurgle7.wav",
    "ambient/levels/canals/toxic_slime_gurgle8.wav"
}

local chunkModels = {
    "models/props_junk/watermelon01_chunk02b.mdl",
    "models/props_junk/watermelon01_chunk02c.mdl"
}

local gibModels = {
    "models/Gibs/HGIBS.mdl",  -- Correct special gib model
    "models/Gibs/HGIBS_spine.mdl"  -- Correct special gib model
}

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_c17/doll01.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        -- Scale the model to 1.5x
        self:SetModelScale(1.5, 0)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self:SetCustomCollisionCheck(true)
        self.NextCough = CurTime() + math.random(2, 5)
    end
end

function ENT:Think()
    if SERVER then
        -- Handle coughing
        if CurTime() > (self.NextCough or 0) then
            self:EmitSound(coughSounds[math.random(#coughSounds)])

            -- Apply random rolling force
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                local rollForce = Vector(math.random(-200, 200), math.random(-200, 200), math.random(50, 150))
                phys:ApplyForceCenter(rollForce)
            end

            self.NextCough = CurTime() + math.random(0.5, 3)
        else
            -- Handle vomiting with a 1 in 10,000 chance
            if math.random(0, 10000) == 1 then
                self:Vomit()
            end
        end
    end

    self:NextThink(CurTime())
    return true
end

function ENT:Vomit()
    if SERVER then
        self:EmitSound(vomitSounds[math.random(#vomitSounds)], 75, math.random(90, 110))

        -- Apply random rolling force during vomiting
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            local rollForce = Vector(math.random(-200, 200), math.random(-200, 200), math.random(50, 150))
            phys:ApplyForceCenter(rollForce)
        end

        -- Leave behind yellow blood decals
        local numDecals = math.random(50, 100)
        local radius = 50 -- Concentrated radius
        for i = 1, numDecals do
            local decalPos = self:GetPos() + Vector(math.random(-radius, radius), math.random(-radius, radius), 0)
            local decalType = yellowBloodDecals[math.random(#yellowBloodDecals)]
            util.Decal(decalType, decalPos + Vector(0, 0, 10), decalPos - Vector(0, 0, 10))
        end

        -- Spawn yellow blood particles
        local effectData = EffectData()
        effectData:SetOrigin(self:GetPos())
        util.Effect("BloodImpact", effectData)
    end
end

function ENT:OnTakeDamage(dmginfo)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        local rollForce = Vector(math.random(-200, 200), math.random(-200, 200), math.random(50, 150))
        phys:ApplyForceCenter(rollForce)
    end

    -- Leave blood decals on damage (non-explosion)
    local numBloodDecals = math.random(5, 10)
    for i = 1, numBloodDecals do
        local decalPos = self:GetPos() + Vector(math.random(-50, 50), math.random(-50, 50), 0)
        local decalType = bloodDecals[math.random(#bloodDecals)]
        util.Decal(decalType, decalPos + Vector(0, 0, 10), decalPos - Vector(0, 0, 10))
    end

    if dmginfo:IsExplosionDamage() then
        self:Explode()
    else
        if math.random(0, 1000000) == 1 then
            self:Explode()
        else
            self:EmitSound(painSounds[math.random(#painSounds)], 75, math.random(90, 110))

            local effectData = EffectData()
            effectData:SetOrigin(self:GetPos())
            util.Effect("BloodImpact", effectData)
        end
    end
end

function ENT:Explode()
    local effectData = EffectData()
    effectData:SetOrigin(self:GetPos())
    util.Effect("BloodImpact", effectData, true, true)

    local numChunks = math.random(4, 16)
    local gibsSpawned = 0 -- Track number of special gibs spawned
    for i = 1, numChunks do
        local gib = ents.Create("prop_physics")
        if IsValid(gib) then
            -- 1 in 8 chance for a special gib model (HGIBS or HGIBS_spine)
            if math.random(1, 8) == 1 and gibsSpawned < 2 then
                local gibModel = math.random(1, 2) == 1 and "models/Gibs/HGIBS.mdl" or "models/Gibs/HGIBS_spine.mdl"
                gib:SetModel(gibModel)
                gibsSpawned = gibsSpawned + 1
            else
                gib:SetModel(chunkModels[math.random(#chunkModels)])
            end

            gib:SetPos(self:GetPos())
            gib:SetAngles(AngleRand())
            gib:Spawn()
            gib:Activate()

            local phys = gib:GetPhysicsObject()
            if IsValid(phys) then
                local force = Vector(math.random(-100, 100), math.random(-100, 100), math.random(100, 200))
                phys:ApplyForceCenter(force)

                -- Decrease size for special gibs
                if gib:GetModel() == "models/Gibs/HGIBS.mdl" or gib:GetModel() == "models/Gibs/HGIBS_spine.mdl" then
                    gib:SetModelScale(0.5, 0)
                end
            end

            gib:AddCallback("PhysicsCollide", function(ent, data)
                local hitPos = data.HitPos
                -- Apply normal blood decals when gibs collide
                util.Decal(bloodDecals[math.random(#bloodDecals)], hitPos + data.HitNormal, hitPos - data.HitNormal)
            end)
        end
    end

    -- Spawn soul
    self:SpawnSoul()

    self:Remove()
end

function ENT:SpawnSoul()
    local soul = ents.Create("prop_physics")
    if not IsValid(soul) then return end

    soul:SetModel("models/props_c17/doll01.mdl") -- Adjust model if necessary
    soul:SetPos(self:GetPos() + Vector(0, 0, 10))
    soul:SetRenderMode(RENDERMODE_TRANSALPHA)
    soul:SetColor(SOUL_COLOR)
    soul:SetModelScale(1.5, 0)
    soul:Spawn()
    soul:Activate()

    soul:SetCollisionGroup(COLLISION_GROUP_WORLD)
    local phys = soul:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableGravity(false)
        phys:SetMass(1)
        phys:ApplyForceCenter(Vector(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))) -- Increased force
    end

    soul:EmitSound(SOUL_SOUND, 75, 100) -- Quieter crying sound
    soul:SetRenderFX(kRenderFxHologram) -- Set as hologram render effect
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
