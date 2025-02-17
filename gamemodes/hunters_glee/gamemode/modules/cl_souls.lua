
local doSoulRagdolls = CreateClientConVar( "huntersglee_cl_dosoulragdolls", 1, true, false, "Enable funny client ragdolls on dead players", 0, 1 )
local doOwnSoul = CreateClientConVar( "huntersglee_cl_seeownsoul", 1, true, false, "See your own soul?", 0, 1 )
local ownSoulNearFade = CreateClientConVar( "huntersglee_cl_ownsoul_nearfade", 0.1, true, false, "How transparent should your own soul be when it's near you?", 0, 1 )

local LocalPlayer = LocalPlayer
local IsValid = IsValid

local upToDateData = {}
local souls = {}
local vec_zero = Vector( 0, 0, 0 )
local fallbackHeadBone = 10
local rotator = Angle( -89.9, 90, 0 )

local function inWall( pos )
    return bit.band( util.PointContents( pos ), MASK_SOLID_BRUSHONLY ) > 0

end

local function boneCountFixed( soul ) -- "Entity:GetPhysicsObjectNum - Out of bounds physics object - max 14, got 15 (x28)"
    return soul:GetPhysicsObjectCount() + -1

end

local function stopShowing( soul )
    if not IsValid( soul ) then return end

    local owner = soul:GetOwner()
    if IsValid( owner ) then
        souls[owner] = nil

    end

    -- dont remove instantly so we never create permanent ragdoll sounds
    soul:SetNoDraw( true )
    for bone = 0, boneCountFixed( soul ) do
        local soulsObj = soul:GetPhysicsObjectNum( bone )
        if IsValid( soulsObj ) then
            soulsObj:EnableMotion( false )

        end
    end
    SafeRemoveEntityDelayed( soul, 0.1 )

end

local function updateDisplayPos( ply, pos )
    ply.glee_SoulDisplayPos = pos
    ply.glee_SoulDisplayPosTime = CurTime() + 1

end

local function soulSetPosSimple( soul, pos )
    for bone = 0, boneCountFixed( soul ) do
        local soulsObj = soul:GetPhysicsObjectNum( bone )
        if IsValid( soulsObj ) then
            soulsObj:SetPos( pos, true )

        end
    end
end

local function soulSetup( soul )
    local owner = soul:GetOwner()
    local rag = owner:GetRagdollEntity()
    local insideEnt = owner.glee_LastInsideEnt
    local anInsideEnt = IsValid( insideEnt )
    local comeOutOfTheirCorpse = IsValid( rag ) and not anInsideEnt
    if comeOutOfTheirCorpse then
        for bone = 0, boneCountFixed( soul ) do
            local ragsObj = rag:GetPhysicsObjectNum( bone )
            local soulsObj = soul:GetPhysicsObjectNum( bone )
            if IsValid( ragsObj ) and IsValid( soulsObj ) then
                local pos = ragsObj:GetPos()
                local ang = ragsObj:GetAngles()
                soulsObj:SetPos( pos )
                soulsObj:SetAngles( ang )
                soulsObj:EnableMotion( false )
                timer.Simple( math.Rand( 0, 4 ), function()
                    if not IsValid( soulsObj ) then return end
                    soulsObj:EnableMotion( true )

                end )
            end
        end
    else
        local pos = owner:GetPos()
        if anInsideEnt then
            pos = insideEnt:WorldSpaceCenter()

        end
        soulSetPosSimple( soul, pos )
    end
    for bone = 0, boneCountFixed( soul ) do
        local soulsObj = soul:GetPhysicsObjectNum( bone )
        if IsValid( soulsObj ) then
            soulsObj:SetMass( 1 )

        end
    end

    local headPhysBoneId = fallbackHeadBone
    local headBoneId

    local eyes = soul:LookupAttachment( "eyes" )
    if eyes > 0 then
        local attachDat = soul:GetAttachment( eyes )
        headBoneId = attachDat.Bone
        headPhysBoneId = soul:TranslateBoneToPhysBone( headBoneId )

    end

    local headPhysBone = soul:GetPhysicsObjectNum( headPhysBoneId )
    if not IsValid( headPhysBone ) then return end

    if owner == LocalPlayer() then
        soul:ManipulateBoneScale( headBoneId, vec_zero )

    end

    headPhysBone:SetMass( headPhysBone:GetMass() * 10000 ) -- so it pulls the other bones along

    soul.glee_HeadPhysBoneId = headPhysBoneId
    soul.glee_HeadPhysBone = headPhysBone

end

local function createSoul( ply )
    if IsValid( ply.glee_soul ) then
        SafeRemoveEntity( ply.glee_soul )
        ply.glee_soul = nil

    end

    local soul = ClientsideRagdoll( ply:GetModel(), RENDERGROUP_TRANSLUCENT )
    if not IsValid( soul ) then return end -- :(

    ply:CallOnRemove( "glee_deletesoul", function( ent )
        stopShowing( ent.glee_soul )
    end )

    soul:SetOwner( ply )
    souls[ ply ] = soul
    ply.glee_soul = soul

    soulSetup( soul )
    ply.glee_LastInsideEnt = nil

    local bodyGroups = ply:GetBodyGroups()

    for _, bGroup in pairs( bodyGroups ) do
        soul:SetBodygroup( bGroup["id"], ply:GetBodygroup( bGroup["id"] ) )

    end
    function soul.GetPlayerColor( self )
        local owner = self:GetOwner()
        if not IsValid( owner ) then return vec_zero end

        return owner:GetPlayerColor()

    end
    soul:SetNoDraw( false )

    function soul.RenderOverride( self )
        local blend = 0.5
        local me = LocalPlayer()
        if soul:GetOwner() == me and soul:GetPos():DistToSqr( me:GetShootPos() ) < 50^2 then
            blend = ownSoulNearFade:GetFloat()

        end
        render.SetBlend( blend )
        self:DrawModel()
        render.SetBlend( 1 )

    end
end

local tooFarWake = 35^2
local tooFarNocollide = 50^2
local tooFarSetpos = 2000^2

local function soulGotoPos( soul, pos, ang )
    local headBone = soul.glee_HeadPhysBone
    if not IsValid( headBone ) then return end

    local obj = soul:GetPhysicsObject()

    local collisionsDesired
    local tryWake

    local soulsPos = soul:GetPos()
    local dist = soulsPos:DistToSqr( pos )
    if dist > tooFarSetpos then
        collisionsDesired = false
        tryWake = true

        local dir = soulsPos - pos
        dir:Normalize()
        soulSetPosSimple( soul, pos + dir * 1500 )
        if not soul.glee_DoneIncoming then
            soul:EmitSound( "weapons/mortar/mortar_shell_incomming1.wav", 75, math.random( 150, 175 ), 1, CHAN_STATIC )
            soul.glee_DoneIncoming = true

        end
    elseif dist > tooFarNocollide then
        collisionsDesired = false
        tryWake = true

    elseif dist > tooFarWake then
        tryWake = true
    elseif not inWall( pos ) and not inWall( soulsPos ) then
        collisionsDesired = true

    end

    if collisionsDesired ~= nil and collisionsDesired ~= obj:IsCollisionEnabled() then
        if collisionsDesired then
            obj:EnableCollisions( true )
            soul.glee_DoneIncoming = nil

        else
            obj:EnableCollisions( false )

        end
    elseif tryWake and IsValid( obj ) and obj:IsAsleep() then
        obj:EnableMotion( true )
        obj:Wake()

    end

    headBone:SetPos( pos )
    headBone:SetAngles( ang + rotator ) -- the angles are wrong but w/e

    return headBone

end

local function followPly( soul, ply, data )
    local pos = data and data.pos or ply:GetPos()
    local ang = data and data.ang or ply:GetAngles()

    if ply == LocalPlayer() then
        pos = ply:GetShootPos()

    end

    updateDisplayPos( soul:GetOwner(), soul:GetPos() )
    soulGotoPos( soul, pos, ang )

end

local deleteDist = 100^2

local function soulGoInto( soul, goInto )
    local toPos = goInto:WorldSpaceCenter()
    local dist = soul:GetPos():DistToSqr( toPos )
    if dist < deleteDist then
        stopShowing( soul )
        soul:GetOwner().glee_LastInsideEnt = goInto
        goInto:EmitSound( "physics/body/body_medium_impact_hard" .. math.random( 1, 6 ) .. ".wav", 65, math.random( 150, 160 ), 1, CHAN_STATIC )
        goInto:EmitSound( "physics/cardboard/cardboard_box_impact_hard" .. math.random( 1, 3 ) .. ".wav", 65, math.random( 190, 200 ) )

    end

    updateDisplayPos( soul:GetOwner(), soul:GetPos() )
    soulGotoPos( soul, toPos, goInto:GetAngles() )

    local obj = soul:GetPhysicsObject()
    if not IsValid( obj ) then return end

    obj:EnableCollisions( false )

end

local function soulThink( ply )
    local soul = souls[ply]
    if not doSoulRagdolls:GetBool() then
        if soul then
            stopShowing( soul )

        end
        return

    end
    local targetParent

    if ply:Health() <= 0 then -- show their soul
        local data = upToDateData[ply]
        if data then
            local spectatingSmth = IsValid( data.targ )
            if data.mode == OBS_MODE_ROAMING then
                if not IsValid( soul ) or ( soul:GetModel() ~= ply:GetModel() ) then
                    createSoul( ply )

                else
                    followPly( soul, ply, data )

                end
            elseif spectatingSmth then
                targetParent = data.targ
                if soul then
                    soulGoInto( soul, data.targ )
                    targetParent = soul

                else
                    ply.glee_LastInsideEnt = data.targ
                    if data.mode == OBS_MODE_CHASE then
                        local pos = data.targ:WorldSpaceCenter()
                        local dir = data.ang:Forward()
                        pos = pos + -dir * 50
                        updateDisplayPos( ply, pos )

                    else
                        updateDisplayPos( ply, data.targ:WorldSpaceCenter() )

                    end
                end
            end
        end
    elseif IsValid( soul ) then -- they alive now, their soul has a place
        soulGoInto( soul, ply )

    end
    if IsValid( targetParent ) then
        local currParent = ply:GetParent()
        if not ( IsValid( currParent ) and currParent == targetParent ) then
            ply:SetParent( targetParent )

        end
    else
        ply:SetParent()

    end
end

local nextThink = 0

hook.Add( "Tick", "glee_souls", function()
    local cur = CurTime()
    if nextThink > cur then return end

    local me = LocalPlayer()
    if not IsValid( me ) then nextThink = cur + 5 return end -- spawning in

    local seesDeadPeople = ( me:Health() <= 0 or me:GetNWInt( "glee_radiochannel", 0 ) == 666 )
    if not seesDeadPeople then
        nextThink = cur + 5
        for _, ply in player.Iterator() do
            local soul = ply.glee_soul
            if soul then
                stopShowing( soul )

            end
        end

        return
    end

    local doOwn = doOwnSoul:GetBool()

    for _, ply in player.Iterator() do
        if doOwn or ply ~= me then
            soulThink( ply )

        end
    end
end )

net.Receive( "glee_sendtruesoullocations", function()
    if nextThink > CurTime() then return end

    local ply = net.ReadEntity()
    local pos = net.ReadVector()
    local ang = net.ReadAngle()
    local mode = net.ReadInt( 6 )
    local targ = net.ReadEntity()

    upToDateData[ply] = {
        pos = pos,
        ang = ang,
        mode = mode,
        targ = targ,
    }
end )

hook.Add( "PostCleanupMap", "glee_clcleanupsouls", function()
    for _, soul in pairs( souls ) do
        stopShowing( soul )

    end
end )