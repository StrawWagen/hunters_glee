AddCSLuaFile()

ENT.DefaultWeapon = {
    "weapon_ar2",
    "weapon_smg1",
    "weapon_shotgun",
    "weapon_pistol",
}

ENT.Base = "terminator_nextbot_csoldier"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Grunt"
ENT.Author = "Boomertaters"
ENT.Spawnable = false -- dont show up in entity spawn category
ENT.SubCategory = "Hunter's Glee"

ENT.PlayerColorVec = Vector( 0, 0, 0 ) -- used for player color

terminator_Extras.RegisterNPC( "terminator_nextbot_gleesoldier_grunt", ENT, { Weapons = ENT.DefaultWeapon } )

if CLIENT then return end


ENT.CoroutineThresh = terminator_Extras.baseCoroutineThresh / 22
ENT.MaxPathingIterations = 3500
ENT.ThreshMulIfDueling = 4 -- CoroutineThresh is multiplied by this amount if we're closer than DuelEnemyDist
ENT.ThreshMulIfClose = 2.5 -- if we're closer than DuelEnemyDist * 2
ENT.IsFodder = true
ENT.HasBrains = false

ENT.JumpHeight = 68
ENT.SpawnHealth = 310
ENT.AimSpeed = 525
ENT.WalkSpeed = 90
ENT.MoveSpeed = 135
ENT.RunSpeed = 215

ENT.AccelerationSpeed = 2100

ENT.isTerminatorHunterChummy = "military"
ENT.DuelEnemyDist = 1200
ENT.ThrowingForceMul = 0.35

ENT.Models = {
    "models/player/riot.mdl",
    "models/player/urban.mdl",
    "models/player/gasmask.mdl",
}

ENT.Term_FootstepSoundWalking = {
    {
        path = "NPC_MetroPolice.RunFootstepLeft",
        pitch = 70,
    },
    {
        path = "NPC_MetroPolice.RunFootstepRight",
        pitch = 70,
    },
}
ENT.Term_FootstepSound = { -- running sounds
    {
        path = "NPC_MetroPolice.RunFootstepLeft",
        pitch = 70,
    },
    {
        path = "NPC_MetroPolice.RunFootstepRight",
        pitch = 70,
    },
}

function ENT:DoHardcodedRelations()
    self.term_HardCodedRelations = {
        ["player"] = { D_LI, D_LI, 1000 },
        ["npc_citizen"] = { D_LI, D_LI, 1000 },

    }
end
