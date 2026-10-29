-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=3504739480
-- modified so tapes outlive the recorder: once you die or get grabbed out of your own eyes,
-- it keeps rolling from the dropped cam, then from whoever picks it up, until it loses sight of you

AddCSLuaFile()

sound.Add( {
    name = "CrapVidCam.ToggleCamera_Glee",
    channel = CHAN_WEAPON,
    volume = 0.5,
    level = 70,
    pitch = 112,
    sound = "buttons/lightswitch2.wav",
} )

SWEP.PrintName = "Crappy Video Camera"
SWEP.Instructions = [[
<color=green>[LMB]</color> Start/stop recording

<color=#00ffff>Videos will be saved in your garrysmod/videos folder in WEBM format.</color>
Credit teapot 3504739480]]

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "weapon_glee_crapvidcam", "vgui/entities/glee_weapon_crapvidcam" )

end

SWEP.Author = "teapot"
SWEP.Category = "Hunter's Glee"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "rpg"

SWEP.WorldModel = Model( "models/dav0r/camera.mdl" )
SWEP.ViewModel = Model( "models/dav0r/camera.mdl" )
SWEP.ViewModelFOV = 55
SWEP.UseHands = false

SWEP.Slot = 4
SWEP.SlotPos = 3
SWEP.Weight = 1

SWEP.AutoSwitchFrom = false
SWEP.AutoSwitchTo = true

SWEP.Primary.Sound = Sound( "CrapVidCam.ToggleCamera_Glee" )
SWEP.Primary.Recoil = 8.5
SWEP.Primary.Damage = 60
SWEP.Primary.NumShots = 1
SWEP.Primary.Cone = 0.02
SWEP.Primary.Delay = 0.15

SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1

SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1

SWEP.Spread = {}
SWEP.Spread.Min = 0
SWEP.Spread.Max = 0.25
SWEP.Spread.IronsightsMod = 0.2
SWEP.Spread.CrouchMod = 0.6
SWEP.Spread.AirMod = 1.2
SWEP.Spread.RecoilMod = 0.05
SWEP.Spread.VelocityMod = 0.5

SWEP.IronsightsPos = Vector( 16, 30, -6 )
SWEP.IronsightsAng = Angle( 0, 0, 0 )
SWEP.IronsightsFOV = 0.8
SWEP.IronsightsSensitivity = 0.8
SWEP.IronsightsCrosshair = false
SWEP.UseIronsightsRecoil = true

SWEP.LoweredPos = Vector( 16, 30, -6 )
SWEP.LoweredAng = Angle( 0, 0, 0 )
SWEP.SelectFont = "HudDefault"
SWEP.IronAnimSpeed = 0.05
SWEP.NoEmptyAnims = true
SWEP.ReloadSpeed = 1.6
SWEP.IronAdjust = 0.5

SWEP.DefaultPos = Vector( 16, 30, -6 )

SWEP.DrawCrosshair = false

function SWEP:SetupDataTables()
    self:NetworkVar( "Float", "Quality" )
    self:NetworkVar( "Float", "FOVScale" )

end

function SWEP:Initialize()
    self:SetHoldType( "rpg" )
    self:SetQuality( math.Rand( 0.75, 3 ) )
    self:SetFOVScale( math.Rand( 0.75, 1.5 ) )

end

function SWEP:CanBePickedUpByNPCs()
    return true

end

local handBoneCandidates = {
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_R_Forearm",
    "RightHand",
    "r_hand",
}

local function handBonePose( holder )
    for _, boneName in ipairs( handBoneCandidates ) do
        local bone = holder:LookupBone( boneName )
        if not bone then continue end

        local matrix = holder:GetBoneMatrix( bone )
        if matrix then return matrix:GetTranslation(), matrix:GetAngles() end

        local bonePos, boneAng = holder:GetBonePosition( bone )
        if bonePos and boneAng then return bonePos, boneAng end

    end
end

-- where the cam sits in a holder's hand, players or hunters
local function heldPose( holder )
    local att = holder:GetAttachment( holder:LookupAttachment( "anim_attachment_RH" ) )
    if att then
        local ang = att.Ang
        return att.Pos + ang:Up() * 10 + ang:Right() + ang:Forward() * 2, ang

    end

    -- model without the attachment
    local pos, ang = handBonePose( holder )
    if pos then
        return pos + ang:Up() * 8 + ang:Right() * 2 + ang:Forward() * 2, ang

    end

    ang = holder:EyeAngles()
    return holder:EyePos() + ang:Right() * 11 + ang:Forward() * 4, ang

end

local toggleRecording -- clientside only

if SERVER then
    util.AddNetworkString( "glee_crapvidcam_stoprecording" )
    util.AddNetworkString( "glee_crapvidcam_endtapes" )

    hook.Add( "PlayerSpawn", "glee_crapvidcam_stoprecording", function( ply )
        net.Start( "glee_crapvidcam_stoprecording" )
        net.Send( ply )

    end )

    -- cinematically aim towards player on drop
    local aimBiasStrength = 800
    local bodyRestingOffset = Vector( 0, 0, 8 ) -- ragdolls settle near the feet
    local landedSpeed = 10
    -- DropWeaponKeepAmmo throws the cam a tick after the drop, before then it may not be moving yet
    local throwGrace = 0.2

    -- aims at what the holder is spectating, eg their body being dragged off, else where they dropped it
    local function biasAimTowards( cam, holder, dropSpot )
        local timerName = "glee_crapvidcam_aimbias_" .. cam:GetCreationID()
        local checkLandedAfter = CurTime() + throwGrace

        timer.Create( timerName, 0, 0, function()
            if not IsValid( cam ) or IsValid( cam:GetOwner() ) then
                timer.Remove( timerName )
                return

            end
            local phys = cam:GetPhysicsObject()
            if not IsValid( phys ) then
                timer.Remove( timerName )
                return

            end
            if CurTime() > checkLandedAfter and cam:GetVelocity():Length() < landedSpeed then
                timer.Remove( timerName )
                return

            end

            local target = dropSpot
            local watched = IsValid( holder ) and holder:GetObserverTarget()
            if IsValid( watched ) and watched ~= cam then
                target = watched:WorldSpaceCenter()

            end

            local forward = cam:GetForward()
            local toTarget = ( target - cam:GetPos() ):GetNormalized()
            local offAngleFrac = math.acos( math.Clamp( forward:Dot( toTarget ), -1, 1 ) ) / math.pi

            local turnAxis = forward:Cross( toTarget )
            if turnAxis:LengthSqr() < 0.0001 then
                -- facing dead away, the cross product vanishes; any perpendicular turns it
                turnAxis = cam:GetUp()

            else
                turnAxis:Normalize()

            end

            phys:AddAngleVelocity( phys:WorldToLocalVector( turnAxis ) * offAngleFrac * aimBiasStrength * FrameTime() )

        end )
    end

    -- KillSilent leaves health above 0, and Alive() can lag behind health during DoPlayerDeath, so check both
    local function seesThroughOwnEyes( ply )
        return ply:Alive() and ply:Health() > 0 and ply:GetObserverMode() == OBS_MODE_NONE

    end

    -- their cam, if it's out and droppable
    local function holdingCamActive( ply )
        local cam = ply:GetActiveWeapon()
        if not IsValid( cam ) or cam:GetClass() ~= "weapon_glee_crapvidcam" then return end
        if not ply:CanDropWeaponKeepAmmo( cam ) then return end

        return cam

    end

    -- polls every tick while they hold it, nothing announces an observer mode change
    local function dropWhenNotInOwnEyes( cam, holder )
        local timerName = "glee_crapvidcam_eyesdrop_" .. cam:GetCreationID()

        timer.Create( timerName, 0, 0, function()
            if not IsValid( cam ) or not IsValid( holder ) or cam:GetOwner() ~= holder then
                timer.Remove( timerName )
                return

            end
            -- still held while dead means a KillSilent skipped DoPlayerDeath's drop
            if seesThroughOwnEyes( holder ) then return end
            if holdingCamActive( holder ) ~= cam then return end

            timer.Remove( timerName )
            holder:DropWeaponKeepAmmo( cam )

        end )
    end

    -- grabbers like the evil crawler strip weapons the same tick they take your eyes, before any timer can see it.
    -- so drop the cam first, then if a tick later you're still in your own eyes it was a normal strip, finish it
    -- known dupe: the crawler snapshots your weapons before stripping, so escaping it hands you a fresh cam while the dropped one stays.
    -- leaving it, the dropped cam filming you get dragged off is worth a spare camera
    hook.Add( "glee_PreStripWeapons", "glee_crapvidcam_dropbeforestrip", function( ply )
        local cam = holdingCamActive( ply )
        if not cam or ply:Health() <= 0 then return end

        ply:DropWeaponKeepAmmo( cam )
        timer.Simple( 0, function()
            if not IsValid( cam ) or IsValid( cam:GetOwner() ) then return end
            if IsValid( ply ) and not seesThroughOwnEyes( ply ) then return end

            cam:Remove()

        end )
    end )

    function SWEP:Equip( newOwner )
        self.glee_lastHolder = newOwner
        if not newOwner:IsPlayer() then return end

        dropWhenNotInOwnEyes( self, newOwner )

    end

    function SWEP:OnDrop()
        local holder = self.glee_lastHolder
        if not IsValid( holder ) or not holder:IsPlayer() then return end

        local dropSpot = holder:GetPos() + bodyRestingOffset
        -- a stripping grabber takes your eyes right after the drop
        timer.Simple( 0, function()
            if not IsValid( self ) or not IsValid( holder ) then return end
            if seesThroughOwnEyes( holder ) then return end

            biasAimTowards( self, holder, dropSpot )

        end )
    end

else
    -- how long a tape keeps going once it's out of our hands, restarted each time it changes hands
    local tapeSecondsRanges = {
        pendingDrop = { 5, 10 },
        dropped = { 5, 10 },
        borrowed = { 15, 15 },
    }
    -- this close it's almost always still in our PVS, so a cam landing behind a prop doesn't cut the tape
    local losGraceDist = 400
    local lastTapeState
    local stopTapeAt
    local recordingCam
    local writer
    local errColor = Color( 255, 0, 0 )
    local savedColor = Color( 0, 255, 255 )
    local baseConfig = {
        container = "webm",
        video = "vp8",
        audio = "vorbis",
        quality = 22,
        bitrate = 30,
        fps = 24,
        lockfps = false,
        width = 480,
        height = 360,
        fovScale = 0.5,
    }

    local currConfig

    -- steam's F12 screenshot crashes mid recording and Lua can't block it, so no frames get written around the press
    local f12SkipSeconds = 0.5
    local skipFramesUntil
    local skippedFrameTime = 0

    -- sized off the player's screen, and vp8 rejects some odd sizes. multiples of 8 dodge every common restriction
    local function encoderSafeSize( size )
        return math.floor( size / 8 ) * 8

    end
    -- a 32:9 screen still makes 480x128
    local minRecordSize = 120

    local function seesThroughOwnEyes( ply )
        return ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE

    end

    -- in the holder's hand while held, otherwise wherever the cam itself lies
    local function lensPose( cam )
        local holder = cam:GetOwner()
        local pos, ang
        if IsValid( holder ) then
            pos, ang = heldPose( holder )

        else
            pos, ang = cam:GetPos(), cam:GetAngles()

        end

        local lens = cam:OBBCenter()
        lens.x = cam:OBBMaxs().x

        return LocalToWorld( lens, angle_zero, pos, ang ), ang

    end

    -- "ours": in our hands and eyes. "pendingDrop": still ours, but we're out of our eyes and the drop hasn't networked yet
    -- "dropped" / "borrowed": on the floor, or out in someone else's hands. nil when the tape should end
    local function tapeState( me )
        if not IsValid( recordingCam ) then return end

        local holder = recordingCam:GetOwner()
        if seesThroughOwnEyes( me ) then
            -- dropped by hand, the server only drops it for us once we're out of our eyes
            if holder ~= me then return end
            return "ours"

        end
        if holder == me then return "pendingDrop" end

        if recordingCam:IsDormant() then return end
        if IsValid( holder ) and holder:GetActiveWeapon() ~= recordingCam then return end
        -- seeing us keeps it in our PVS, out of it, it'd go dormant and freeze
        local lensPos = lensPose( recordingCam )
        local myEyes = me:EyePos()
        local closeEnough = lensPos:DistToSqr( myEyes ) < losGraceDist^2
        if not closeEnough and not terminator_Extras.PosCanSee( lensPos, myEyes, MASK_SOLID_BRUSHONLY ) then return end

        if IsValid( holder ) then return "borrowed" end
        return "dropped"

    end

    local function beginRecording()
        -- captured before viewmodels and the HUD draw, so neither ends up on tape
        hook.Add( "PreDrawViewModels", "glee_crapvidcam_recordframe", function()
            if not writer then return end

            local me = LocalPlayer()
            local state = IsValid( me ) and tapeState( me )
            if not state then
                toggleRecording()
                return

            end

            if state ~= lastTapeState then
                lastTapeState = state
                local range = tapeSecondsRanges[state]
                stopTapeAt = range and CurTime() + math.Rand( range[1], range[2] )

            end
            if stopTapeAt and stopTapeAt < CurTime() then
                toggleRecording()
                return

            end

            if input.IsKeyDown( KEY_F12 ) then
                skipFramesUntil = RealTime() + f12SkipSeconds

            end
            if skipFramesUntil and skipFramesUntil > RealTime() then
                skippedFrameTime = skippedFrameTime + FrameTime()
                return

            end

            -- the skipped time goes on the next frame, or the tape shortens and the audio runs ahead of it
            writer:AddFrame( FrameTime() + skippedFrameTime, true )
            skippedFrameTime = 0
            me:SetDSP( 38, true )

        end )
    end

    -- stops the running tape if there is one, camera ignored. otherwise starts one on camera
    toggleRecording = function( camera )
        if writer then
            hook.Remove( "PreDrawViewModels", "glee_crapvidcam_recordframe" )
            chat.AddText( savedColor, "Saved video to garrysmod/videos/" .. currConfig.name .. ".webm" )
            writer:Finish()
            writer = nil
            recordingCam = nil
            lastTapeState = nil
            stopTapeAt = nil
            skipFramesUntil = nil
            skippedFrameTime = 0
            LocalPlayer():SetDSP( 0, true )

        elseif IsValid( camera ) then
            local w, h = ScrW(), ScrH()
            local width = encoderSafeSize( math.min( w, baseConfig.width ) )
            local height = encoderSafeSize( ( width * h ) / w )
            if width < minRecordSize or height < minRecordSize then
                chat.AddText( errColor, "Couldn't record video: your game window is too small or too stretched." )
                return

            end

            recordingCam = camera
            currConfig = table.Copy( baseConfig )
            currConfig.width = width
            currConfig.height = height
            currConfig.quality = baseConfig.quality * camera:GetQuality()
            currConfig.fps = math.Clamp( baseConfig.fps * camera:GetQuality(), 5, 60 )
            currConfig.bitrate = baseConfig.bitrate * camera:GetQuality()
            currConfig.fovScale = baseConfig.fovScale * camera:GetFOVScale()

            currConfig.name = "GLEE_vidcam-" .. util.DateStamp()

            local recordErr
            writer, recordErr = video.Record( currConfig )
            if writer then
                writer:SetRecordSound( true )
                beginRecording()

            else
                chat.AddText( errColor, "Couldn't record video: " .. recordErr )

            end
        end
    end

    net.Receive( "glee_crapvidcam_stoprecording", function()
        if not writer then return end
        toggleRecording()

    end )

    net.Receive( "glee_crapvidcam_endtapes", function()
        local cam = net.ReadEntity()
        if not writer or cam ~= recordingCam then return end
        -- our own press, toggled locally already
        if cam:GetOwner() == LocalPlayer() then return end

        toggleRecording()

    end )

    local recTextColor = Color( 255, 100, 100 )
    local recOutlineColor = Color( 20, 20, 20 )

    hook.Add( "HUDPaint", "glee_crapvidcam_recordingtext", function()
        if not writer then return end
        if math.sin( CurTime() * 8 ) <= 0 then return end

        draw.SimpleTextOutlined( "RECORDING", "DermaLarge", ScrW() * 0.5, 0, recTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, recOutlineColor )

    end )

    -- the engine crashes if "jpeg" runs mid recording. it's an engine command, so Lua can't intercept it, only the inputs that run it
    hook.Add( "PlayerBindPress", "glee_crapvidcam_blockjpeg", function( _, bind )
        if not writer then return end
        if string.find( bind, "jpeg", 1, true ) then return true end

    end )

    -- gmod_camera runs "jpeg" on fire, dropping the attack here stops it in singleplayer too, where the server runs it
    hook.Add( "CreateMove", "glee_crapvidcam_blockcamera", function( cmd )
        if not writer then return end

        local wep = LocalPlayer():GetActiveWeapon()
        if not IsValid( wep ) or wep:GetClass() ~= "gmod_camera" then return end

        cmd:RemoveKey( IN_ATTACK )

    end )

    -- ours, first person through the cam. dropped or borrowed, out of its lens
    hook.Add( "glee_CalcView", "glee_crapvidcam_view", function( ply, pos, ang, fov )
        if not writer then return end

        local state = tapeState( ply )
        if not state or state == "pendingDrop" then return end

        fov = fov * currConfig.fovScale

        if state == "ours" then
            return {
                origin = pos,
                angles = ang,
                fov = fov,
                drawviewer = false,

            }
        end

        local lensPos, lensAng = lensPose( recordingCam )
        return {
            origin = lensPos,
            angles = lensAng,
            fov = fov,

        }
    end )
end

function SWEP:CanSecondaryAttack()
    return false

end

function SWEP:PrimaryAttack()
    if SERVER and game.SinglePlayer() then
        self:CallOnClient( "PrimaryAttack" )
        return

    end

    local cur = CurTime()
    if cur < self:GetNextPrimaryFire() then return end
    self:SetNextPrimaryFire( cur + 0.1 )
    self:EmitSound( self.Primary.Sound )

    -- hunters "attack" with it nonstop, only players pressing record end tapes
    local owner = self:GetOwner()
    if SERVER and IsValid( owner ) and owner:IsPlayer() then
        net.Start( "glee_crapvidcam_endtapes" )
        net.WriteEntity( self )
        net.Broadcast()

    end

    if CLIENT and ( IsFirstTimePredicted() or game.SinglePlayer() ) then
        toggleRecording( self )

    end
end

function SWEP:DrawWorldModel()
    local holder = self:GetOwner()
    if not IsValid( holder ) or holder:GetActiveWeapon() ~= self then
        self:DrawModel()
        return

    end

    local pos, ang = heldPose( holder )
    self:SetPos( pos )
    self:SetAngles( ang )
    self:SetupBones()
    self:DrawModel()

end

local camPos = Vector( 16, 30, -6 )

function SWEP:GetViewModelPosition( pos, ang )
    pos:Add( camPos[1] * ang:Right() )
    pos:Add( camPos[2] * ang:Forward() )
    pos:Add( camPos[3] * ang:Up() )
    return pos, ang

end

if not SERVER then return end

hook.Add( "InitPostEntity", "glee_crapvidcam_randomspawn", function()
    GAMEMODE:RandomlySpawnEntTbl( "weapon_glee_crapvidcam", {
        maxCount = 1,
        chance = math.Rand( 1, 15 ),
        radius = math.random( 1000, 10000 ),
    } )

end )
