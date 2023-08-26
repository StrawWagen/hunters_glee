-- three needed functionalities of this folder

-- add one function that lets you add/remove speed modifiers
-- remove speed modifiers by giving a speedKey with a nil speedModifier
-- add a speed modifier to a player by giving a speedKey with a speed modifer

-- use the self.glee_speedmodifiers to store speed modifiers

-- second function will allow the setting of a player's max speed
-- it will be another table of modifiers with the same structure as the first function
-- this function will add a "clamp" to the final result of all the added glee_speedmodifiers when the third function, refeshPlayerSpeed is ran

-- third and final function will be ran at the end of doSpeedModifier
-- it will take and store the player's current speed as self.glee_defaultspeed
-- then it will loop over all of the speed modifiers in the self.glee_speedmodifiers table, and add them to the default speed

-- so as an example i should be able to add two speed modifiers with the first function
-- "speedmod1" with a modifier of 10
-- "speedmod2" with a modifier of 40
-- and add a speed clamp with the second function
-- "speedclamp1" with a modifier of 40

-- the result of adding all of these modifers to one player means that the player has a movement speed of 40 above their normal speed
-- 10 + 50 clamped to 40
-- equals 40

-- GPT-4 result according to comments above ( i modified it a bit but it got close )
-- had to add isnumber check

local plyMeta = FindMetaTable( "Player" )

function plyMeta:doSpeedModifier( speedKey, speedModifier )
    self.glee_speedmodifiers = self.glee_speedmodifiers or {}

    if speedModifier then
        self.glee_speedmodifiers[speedKey] = speedModifier

    else
        self.glee_speedmodifiers[speedKey] = nil

    end

    self:refeshPlayerSpeed( self )

end

function plyMeta:doSpeedClamp( speedKey, speedClamp )
    self.glee_maxspeedmodifiers = self.glee_maxspeedmodifiers or {}

    if speedClamp then
        self.glee_maxspeedmodifiers[speedKey] = speedClamp

    else
        self.glee_maxspeedmodifiers[speedKey] = nil

    end

    self:refeshPlayerSpeed( self )

end

function plyMeta:refeshPlayerSpeed()
    self.glee_speedmodifiers = self.glee_speedmodifiers or {}
    self.glee_maxspeedmodifiers = self.glee_maxspeedmodifiers or {}
    self.glee_defaultspeed = self.glee_defaultspeed or self:GetRunSpeed()

    local walkSpeed = self:GetWalkSpeed()
    local defaultSpeed = self.glee_defaultspeed
    local totalSpeedModifier = 0

    for key, modifier in pairs( self.glee_speedmodifiers ) do
        if isnumber( modifier ) then
            totalSpeedModifier = totalSpeedModifier + modifier

        else -- take out the trash
            self.glee_speedmodifiers[key] = nil

        end
    end

    local newSpeed = defaultSpeed + totalSpeedModifier

    local maxSpeedModifier = math.huge
    for key, modifier in pairs( self.glee_maxspeedmodifiers ) do
        if isnumber( modifier ) then
            maxSpeedModifier = math.min( maxSpeedModifier, modifier )

        else
            self.glee_maxspeedmodifiers[key] = nil

        end
    end

    local speedMax = defaultSpeed + maxSpeedModifier
    speedMax = math.max( speedMax, walkSpeed )

    newSpeed = math.Clamp( newSpeed, walkSpeed, speedMax )

    self:SetRunSpeed( newSpeed )

end