AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Door Locker"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Locks doors"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

if CLIENT then
    function ENT:DoHudStuff()
    end

end

if not SERVER then return end

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

function ENT:GetNearestTarget()
    local nearestDoor = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all prop_door_rotating entities within a radius of 2048 units
    local doors = ents.FindInSphere( myPos, 2048 )
    for _, door in ipairs( doors ) do
        if door:GetClass() == "prop_door_rotating" then
            if not util.doorIsUsable( door ) then continue end
            if not door:IsSolid() then continue end
            -- Calculate the distance between the door and the entity
            local distance = myPos:Distance( door:GetPos() )
            if distance < nearestDistance then
                nearestDoor = door
                nearestDistance = distance

            end
        end
    end

    return nearestDoor

end

function ENT:UpdateGivenScore()
    self:SetGivenScore( "0" )

end

function ENT:CalculateCanPlace()
    local door = self:GetCurrTarget()
    if not IsValid( door ) then return false, "You need to aim at a door." end
    if door:GetInternalVariable( "m_eDoorState" ) == 2 then return false, "That door is open." end
    if door:GetInternalVariable( "m_bLocked" ) == true then return false, "That door is already locked." end

    return true

end

-- lock a prop_door_rotating
-- then run a function when the door is used by something

function LockDoorAndRunAFunctionWhenTheDoorIsUsed( door, playerAttaching, functionToRun )
    -- fire the "lock" input to lock the door
    door:Fire( "Lock" )
    door:EmitSound( "doors/door_locked2.wav", 80 )

    door.doorPlayers = door.doorPlayers or {}
    table.insert( door.doorPlayers, playerAttaching )

    local hookName = "CheckUsedEntity_DoorLocker_" .. door:GetCreationID()

    local function UsedCheckIfIsDoor( thingUsingTheDoor, entity )
        if not IsValid( door ) then
            hook.Remove( "PlayerUse", hookName )
            hook.Remove( "TerminatorUse", hookName )
            return

        end
        -- check if the used entity is the door
        -- the used entity is the door, so check if it is locked
        if entity == door and door:GetSaveTable().m_bLocked then
            -- not necessary since doors now cant be locked twice, good to keep it tho
            for _, currentlyProcessingPlayer in ipairs( door.doorPlayers ) do
                if not IsValid( currentlyProcessingPlayer ) then continue end

                -- the door is locked, so run the function
                functionToRun( door, thingUsingTheDoor, currentlyProcessingPlayer )

            end
            hook.Remove( "PlayerUse", hookName )
            hook.Remove( "TerminatorUse", hookName )

            -- clear the table
            door.doorPlayers = {}

        end
    end

    -- add a hook to run when a player uses an entity
    hook.Add( "PlayerUse", hookName, UsedCheckIfIsDoor )
    hook.Add( "TerminatorUse", hookName, UsedCheckIfIsDoor )

end

-- this is ran once on a door, when it's first used by something
-- if it's used by a player then it give currentlyProcessingPlayer some score via player:GivePlayerScore( score )
-- if it's used by a nextbot then give currentlyProcessingPlayer a bit less score
-- if it's used by a player with a specific value, give currentlyProcessingPlayer a bunch of score

local function DoorOnUsedInitial( _, thingUsingTheDoor, currentlyProcessingPlayer )
    if not currentlyProcessingPlayer.GivePlayerScore then return end

    local msg = ""

    -- check if the thing using the door is a player
    if thingUsingTheDoor:IsPlayer() then
        if thingUsingTheDoor == currentlyProcessingPlayer then
            currentlyProcessingPlayer:GivePlayerScore( -50 )
            msg = "You locked this door, -50 score."

        -- check if the player has a specific value
        elseif IsValid( thingUsingTheDoor.huntersGleeHunterThatIsTargetingPly ) then
            -- give the player a bunch of score
            currentlyProcessingPlayer:GivePlayerScore( 250 )
            msg = "A fleeing player used one of your locked doors, you gain 250 score!"

        else
            -- give the player some score
            currentlyProcessingPlayer:GivePlayerScore( 150 )
            msg = "A player used one of your locked doors, you gain 150 score!"

        end
    -- check if the thing using the door is a nextbot
    elseif thingUsingTheDoor:IsNextBot() then
        -- give the player a bit less score
        currentlyProcessingPlayer:GivePlayerScore( 80 )
        msg = GAMEMODE:GetNameOfBot( thingUsingTheDoor ) .. " used one of your locked doors, you gain 80 score!"

    end
    huntersGlee_Announce( { currentlyProcessingPlayer }, 5, 6, msg )

end

function ENT:Place()
    if not SERVER then return end
    local door = self:GetCurrTarget()
    LockDoorAndRunAFunctionWhenTheDoorIsUsed( door, self.player, DoorOnUsedInitial )
    door:EmitSound( "doors/door_locked2.wav", 80 )

    GAMEMODE:AddMischievousness( self.player, 1, "locked a door" )

    self:TellPlyToClearHighlighter()

    SafeRemoveEntity( self )

end