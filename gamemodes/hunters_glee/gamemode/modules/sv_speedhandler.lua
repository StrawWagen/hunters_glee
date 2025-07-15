
local plyMeta = FindMetaTable( "Player" )

--[[--------------
    ply:doSpeedModifier
    Adds or removes a speed modifier for the player.
    @param speedKey: A unique key for the speed modifier.
    @param speedModifier: The speed modifier to apply. If nil, the modifier is removed.
    @return: None
--]]--------------
function plyMeta:doSpeedModifier( speedKey, speedModifier )
    self.glee_speedmodifiers = self.glee_speedmodifiers or {}

    if speedModifier then
        self.glee_speedmodifiers[speedKey] = speedModifier

    else
        self.glee_speedmodifiers[speedKey] = nil

    end

    self:refeshPlayerSpeed( self )

end

--[[--------------
    ply:doSpeedClamp
    Adds or removes a speed clamp for the player.
    @param speedKey: A unique key for the speed clamp.
    @param speedClamp: The speed clamp to apply. If nil, the clamp is removed.
    @return: None
--]]--------------
function plyMeta:doSpeedClamp( speedKey, speedClamp )
    self.glee_maxspeedmodifiers = self.glee_maxspeedmodifiers or {}

    if speedClamp then
        self.glee_maxspeedmodifiers[speedKey] = speedClamp

    else
        self.glee_maxspeedmodifiers[speedKey] = nil

    end

    self:refeshPlayerSpeed( self )

end

--[[--------------
    ply:refeshPlayerSpeed
    Refreshes the player's speed based on current modifiers and clamps.
    @return: None
--]]--------------

function plyMeta:refeshPlayerSpeed()
    self.glee_speedmodifiers = self.glee_speedmodifiers or {}
    self.glee_maxspeedmodifiers = self.glee_maxspeedmodifiers or {}
    self.glee_defaultspeed = self.glee_defaultspeed or self:GetRunSpeed() -- sets the default here!

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