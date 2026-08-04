AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "glee_infernal_persecutors"

ENT.Category    = "Other"
ENT.PrintName   = "Infernal Heckler"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Summons an infernal skeleton"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/misc/cone1x05.mdl"

ENT.HullCheckSize = Vector( 10, 10, 5 )

-- how many npcs, and what they are
ENT.NpcClass = "terminator_nextbot_infernalskeleton"
ENT.DoLeaderNpc = false
ENT.MinNpcs = 1
ENT.MaxNpcs = 1

ENT.PersistGuiltAdded = 0

-- configurable cost tiers
ENT.CostNobody = 10
ENT.CostAllInnocent = 200 -- nobody guilty nearby ( or nobody at all )
ENT.CostMixed = 100 -- both guilty and innocent nearby
ENT.CostAllGuilty = -100 -- only guilty nearby, profitable
ENT.CloseCostMult = 2
ENT.CostMulWhenEscaped = 0.15

if not SERVER then return end


ENT.WarningEffect = "fire_small_01"
ENT.SpawningEffect = "fire_medium_01"
