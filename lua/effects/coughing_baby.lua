--Credit to https://steamcommunity.com/sharedfiles/filedetails/?id=3393889422 for the coughing baby

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
