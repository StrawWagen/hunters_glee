
local meta = FindMetaTable( "Player" )

-- func that teleports ply to new pos, updating unstuck origin and handling unstuck process

function meta:TeleportTo( pos )
    self.unstuckOrigin = pos
    if self:InVehicle() then
        self:ExitVehicle()

    end
    self:SetPos( pos )
    self:unstuckFullHandle()

    timer.Simple( 0.5, function()
        if not IsValid( self ) then return end
        if self:GetPos():DistToSqr( pos ) < 750^2 then return end

        -- didnt teleport ply... try AGAIN!
        self.unstuckOrigin = pos
        self:SetPos( pos )
        self:unstuckFullHandle()

    end )
end

function meta:BeginUnstuck()
    self.unstuckOrigin = nil
    self:unstuckFullHandle()

end


function meta:IsStuckBasic()
    if self:IsOnGround() then return end

    -- 15^2
    if self:GetVelocity():LengthSqr() > 225 then return end
    local move = self:GetMoveType()
    if move == MOVETYPE_NOCLIP then return end
    if move == MOVETYPE_LADDER then return end
    if move == MOVETYPE_OBSERVER then return end

    return true

end


-- this func should be ran after player's pos is set
function meta:unstuckFullHandle()
    timer.Simple( 0.1, function()
        if not self:IsValid() then return end
        self.glee_Unstucking = true
        local shouldBeValid

        local origin = self.unstuckOrigin or self:GetPos()
        local result = self:checkIfPlyIsStuckAndHandle( origin )

        -- they are stuck
        if result == true then
            local old = self.glee_UnstuckFails or 0
            self.glee_UnstuckFails = old + 1
            -- recursive yay
            self:unstuckFullHandle()

        -- not stuck anymore!!! break the recursion!
        elseif result == false then
            if self.unstuckOrigin ~= nil then
                self.unstuckOrigin = nil

            end
            self.glee_Unstucking = nil
            self.glee_UnstuckFails = nil
            shouldBeValid = true

        end
        if shouldBeValid then
            timer.Simple( 0.1, function()
                if not IsValid( self ) then return end
                if self:IsStuckBasic() then
                    -- oops im actually still stuck
                    self:unstuckFullHandle()

                end
            end )
        end
    end )
end

-- take a player's pos, then iterate until we find a pos that is,
    -- empty, nothing there already
    -- not under a displacement

-- starts off checking right next to player, then goes crazy and checks far away

function meta:checkIfPlyIsStuckAndHandle( overridePos )

    local unstuckOrigin = overridePos or self:GetPos()
    local forward = self:GetAimVector()
    local thePos = nil

    local unstuckFails = self.glee_UnstuckFails or 0
    local overFailed = unstuckFails >= 2

    local minBound, maxBound = self:GetCollisionBounds()
    minBound = minBound * 1.1
    maxBound = maxBound * 1.1

    local plyHeightOffset = Vector( 0, 0, maxBound.z )

    minBound.z = -4
    maxBound.z = 4
    local randomOffset = Vector( 0, 0, 0 )
    -- lots of traces for 1 tick lol
    local max = 500 -- bigger this is, the closer ply ends up to where they're stuck at, but it's also laggier...
    local doBigCheck = max * 0.5

    for index = 0, max do

        local scalar = 0.5
        -- nothing close, go ham
        if index > doBigCheck then
            scalar = math.Rand( 0.5, 4 )

        end
        -- go crazy instead of holding up the entire session
        if overFailed then
            scalar = scalar + math.Rand( 0, unstuckFails )

        end

        local randomOffsetScale = index * scalar
        local randomDirection = VectorRand( -1, 1 )
        randomOffset = randomDirection * randomOffsetScale
        local potentiallyClearPos = unstuckOrigin + randomOffset

        local contents = util.PointContents( potentiallyClearPos )
        local isSolidOrClipped = ( bit.band( contents, CONTENTS_SOLID ) ~= 0 ) or ( bit.band( contents, CONTENTS_PLAYERCLIP ) ~= 0 )

        if isSolidOrClipped then continue end

        local startPos = potentiallyClearPos + plyHeightOffset
        local endPos = potentiallyClearPos

        local traceDataDown = {}
        traceDataDown.start = startPos
        traceDataDown.endpos = endPos
        traceDataDown.filter = self
        traceDataDown.mask = MASK_PLAYERSOLID
        traceDataDown.mins = minBound
        traceDataDown.maxs = maxBound

        local trace = util.TraceHull( traceDataDown )

        if trace.Hit or trace.StartSolid or GAMEMODE:IsUnderDisplacementExtensive( potentiallyClearPos ) then continue end

        if index == 0 then -- first check is always directly ontop of player, if it's clear, then ply is not stuck
            return false

        end

        -- ok we are stuck
        -- do a reverse trace because sometimes ppls heads get stuck inside displacement roofs
        local traceDataUp = {}
        traceDataUp.start = endPos
        traceDataUp.endpos = startPos
        traceDataUp.filter = self
        traceDataUp.mask = MASK_PLAYERSOLID
        traceDataUp.mins = minBound
        traceDataUp.maxs = maxBound

        local traceUp = util.TraceHull( traceDataUp )

        if traceUp.Hit or traceUp.StartSolid then continue end


        -- another check
        local displaceCheck = {}
        -- people tend to look out of the displacement when stuck in one
        displaceCheck.start = endPos + ( forward * 40 )
        displaceCheck.endpos = startPos
        displaceCheck.filter = self
        displaceCheck.mask = MASK_SOLID_BRUSHONLY
        displaceCheck.mins = minBound
        displaceCheck.maxs = maxBound

        local displaceResult = util.TraceHull( displaceCheck )

        if displaceResult.HitTexture == "**displacement**" or displaceResult.StartSolid then continue end

        -- check behind player too
        displaceCheck.start = endPos + ( -forward * 40 )
        displaceResult = util.TraceHull( displaceCheck )

        if displaceResult.HitTexture == "**displacement**" or displaceResult.StartSolid then continue end

        local originPlyClipped = bit.band( util.PointContents( unstuckOrigin ), CONTENTS_PLAYERCLIP ) ~= 0
        local clearPlyClipped = bit.band( util.PointContents( potentiallyClearPos ), CONTENTS_PLAYERCLIP ) ~= 0
        if originPlyClipped and not clearPlyClipped then -- if player somehow ends up inside a playerclip, let them out!
            -- we were stuck and this spot will set us free
            thePos = potentiallyClearPos
            break

        end

        local finalClipCheck = {}
        finalClipCheck.start = unstuckOrigin + terminator_Extras.dirToPos( unstuckOrigin, potentiallyClearPos ) * 35
        finalClipCheck.endpos = potentiallyClearPos
        finalClipCheck.mins = minBound
        finalClipCheck.maxs = maxBound
        finalClipCheck.mask = CONTENTS_PLAYERCLIP

        local finalClipCheckResult = util.TraceHull( finalClipCheck )

        -- this pos would send us through a player clip ( just a sanity check, will fail if eg, a corner exists )
        local sendUsThruPlyClip = finalClipCheckResult.Hit
        if sendUsThruPlyClip then continue end

        -- we were stuck and this spot will set us free
        thePos = potentiallyClearPos
        break

    end

    if thePos then
        -- ply is not stuck anymore
        self:SetPos( thePos )
        --debugoverlay.Cross( thePos, 10, 10, color_white, true )
        hook.Run( "termhunt_plyescapestuck", self, unstuckOrigin, thePos )
        return false

    else
        -- ply is still stuck
        return true

    end
end

hook.Add( "glee_sv_validgmthink", "glee_manageunstucking", function( players )
    for _, ply in ipairs( players ) do
        if ply:Health() > 0 then
            local basicStuckCount = ply.glee_basicStuckCount or 0
            -- do not interrupt current unstuck
            if ply.glee_Unstucking then
                ply.glee_basicStuckCount = 0

            elseif basicStuckCount > 20 then
                ply.glee_basicStuckCount = 0
                ply:unstuckFullHandle()
                ply:EmitSound( "physics/rubber/rubber_tire_impact_hard2.wav", 65, math.random( 80, 100 ) )
                GAMEMODE:GivePanic( ply, 25 )

                print( "GLEE: unstucking " .. ply:Nick() )

            elseif ply:IsStuckBasic() then
                ply.glee_basicStuckCount = basicStuckCount + 1

                if basicStuckCount > 10 and not ply.glee_doneUnstuckWarn then
                    ply:EmitSound( "physics/cardboard/cardboard_box_impact_hard6.wav", 65, math.random( 50, 60 ) )
                    GAMEMODE:GivePanic( ply, 15 )
                    ply.glee_doneUnstuckWarn = true

                end
            elseif basicStuckCount > 0 then
                ply.glee_basicStuckCount = 0
                ply.glee_doneUnstuckWarn = nil

            end
        elseif ply.glee_Unstucking then -- broke
            ply.glee_Unstucking = nil
            ply.glee_doneUnstuckWarn = nil
            ply.glee_basicStuckCount = nil

        end
    end
end )
