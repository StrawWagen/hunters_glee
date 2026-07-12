AddCSLuaFile()

ENT.DefaultWeapon = {
    "weapon_ar2",
    "weapon_smg1",
    "weapon_shotgun",
    "weapon_pistol",
}

ENT.Base = "terminator_nextbot_csoldier"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Soldier"
ENT.Author = "Boomertaters"
ENT.Spawnable = false -- dont show up in entity spawn category

list.Set( "NPC", "terminator_nextbot_soldier", {
    Name = "Military Soldier",
    Class = "terminator_nextbot_soldier",
    Category = "Hunter's Glee",
    Weapons = ENT.DefaultWeapon,
} )

ENT.PlayerColorVec = Vector( 0, 0, 0 ) -- used for player color

if CLIENT then
    language.Add( "terminator_nextbot_soldier", ENT.PrintName )
    return

end

ENT.CoroutineThresh = terminator_Extras.baseCoroutineThresh / 22
ENT.MaxPathingIterations = 3500
ENT.ThreshMulIfDueling = 4 -- CoroutineThresh is multiplied by this amount if we're closer than DuelEnemyDist
ENT.ThreshMulIfClose = 2.5 -- if we're closer than DuelEnemyDist * 2
ENT.IsFodder = false

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

-- just so they can not get beamed by a terminator a mile away when they spawn
function ENT:PostTookBulletDamage( dmg, hitGroup )
    dmg:ScaleDamage( 0.60 )
    local pos = dmg:GetDamagePosition()
    timer.Simple( 0, function()
        local Data = EffectData()
        Data:SetOrigin( pos )
        Data:SetColor( 1 )
        Data:SetScale( 1 )
        Data:SetRadius( 1 )
        Data:SetMagnitude( 1 )
        Data:SetNormal( VectorRand() )
        util.Effect( "Sparks", Data )
        self:EmitSound( self.Rics[math.random( 1, #self.Rics )], 75, math.random( 120, 140 ) )
    end )
end

function ENT:IsAngry()
    return true

end