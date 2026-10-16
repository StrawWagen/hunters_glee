-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=3504739480
-- modified to keep recording from the dropped cam for a few seconds after death

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
SWEP.AutoSwitchTo = false

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

local toggleRecording -- clientside only

if SERVER then
    util.AddNetworkString( "glee_crapvidcam_stoprecording" )

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

    local function biasAimTowards( cam, target )
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

    function SWEP:Equip( newOwner )
        self.glee_lastHolder = newOwner

    end

    function SWEP:OnDrop()
        local holder = self.glee_lastHolder
        if not IsValid( holder ) or holder:Health() > 0 then return end

        biasAimTowards( self, holder:GetPos() + bodyRestingOffset )

    end

else
    local deadRecordSecondsRange = { 2, 5 }
    local stopDeadRecordingAt
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

    local function lostTheCam( me )
        if not IsValid( recordingCam ) then return true end

        local camOwner = recordingCam:GetOwner()
        if IsValid( camOwner ) then return camOwner ~= me end

        return recordingCam:IsDormant()

    end

    local function beginRecording()
        hook.Add( "PreDrawViewModels", "glee_crapvidcam_recordframe", function()
            if not writer then return end

            local me = LocalPlayer()
            if not IsValid( me ) or not me:Alive() then
                stopDeadRecordingAt = stopDeadRecordingAt or CurTime() + math.Rand( deadRecordSecondsRange[1], deadRecordSecondsRange[2] )
                if stopDeadRecordingAt < CurTime() or lostTheCam( me ) then
                    toggleRecording()
                    return

                end
            end

            writer:AddFrame( FrameTime(), true )
            me:SetDSP( 38, true )

        end )
    end

    toggleRecording = function( camera )
        if writer then
            hook.Remove( "PreDrawViewModels", "glee_crapvidcam_recordframe" )
            chat.AddText( savedColor, "Saved video to garrysmod/videos/" .. currConfig.name .. ".webm" )
            writer:Finish()
            writer = nil
            recordingCam = nil
            stopDeadRecordingAt = nil
            LocalPlayer():SetDSP( 0, true )

        elseif IsValid( camera ) then
            recordingCam = camera
            currConfig = table.Copy( baseConfig )
            currConfig.quality = baseConfig.quality * camera:GetQuality()
            currConfig.fps = math.Clamp( baseConfig.fps * camera:GetQuality(), 5, 60 )
            currConfig.bitrate = baseConfig.bitrate * camera:GetQuality()
            currConfig.fovScale = baseConfig.fovScale * camera:GetFOVScale()

            currConfig.name = "GLEE_vidcam-" .. util.DateStamp()
            local w, h = ScrW(), ScrH()
            currConfig.width = math.min( w, 480 )
            currConfig.height = math.min( math.floor( ( currConfig.width * h ) / w ), w )

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

    local recTextColor = Color( 255, 100, 100 )
    local recOutlineColor = Color( 20, 20, 20 )

    hook.Add( "HUDPaint", "glee_crapvidcam_recordingtext", function()
        if not writer then return end
        if math.sin( CurTime() * 8 ) <= 0 then return end

        draw.SimpleTextOutlined( "RECORDING", "DermaLarge", ScrW() * 0.5, 0, recTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, recOutlineColor )

    end )

    -- alive, first person through the cam. dead, from wherever the dropped cam landed
    hook.Add( "glee_CalcView", "glee_crapvidcam_view", function( ply, pos, ang, fov )
        if not writer then return end

        fov = fov * currConfig.fovScale

        if ply:Alive() then
            return {
                origin = pos,
                angles = ang,
                fov = fov,
                drawviewer = false,

            }
        end

        -- still ours until the drop networks
        if not IsValid( recordingCam ) or IsValid( recordingCam:GetOwner() ) then return end

        local lens = recordingCam:OBBCenter()
        lens.x = recordingCam:OBBMaxs().x

        return {
            origin = recordingCam:LocalToWorld( lens ),
            angles = recordingCam:GetAngles(),
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

    if CLIENT and ( IsFirstTimePredicted() or game.SinglePlayer() ) then
        toggleRecording( self )

    end
end

function SWEP:Holster()
    if CLIENT and ( IsFirstTimePredicted() or game.SinglePlayer() ) and LocalPlayer() == self:GetOwner() then
        toggleRecording()

    end

    if game.SinglePlayer() then
        self:CallOnClient( "Holster" )

    end

    return true

end

local handBoneCandidates = {
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_R_Forearm",
    "RightHand",
    "r_hand",
}

local function handBonePose( ply )
    for _, boneName in ipairs( handBoneCandidates ) do
        local bone = ply:LookupBone( boneName )
        if not bone then continue end

        local matrix = ply:GetBoneMatrix( bone )
        if matrix then return matrix:GetTranslation(), matrix:GetAngles() end

        local bonePos, boneAng = ply:GetBonePosition( bone )
        if bonePos and boneAng then return bonePos, boneAng end

    end
end

function SWEP:DrawWorldModel()
    local ply = self:GetOwner()
    if not IsValid( ply ) or ply:GetActiveWeapon() ~= self then
        self:DrawModel()
        return

    end

    local pos, ang
    local att = ply:GetAttachment( ply:LookupAttachment( "anim_attachment_RH" ) )
    if att then
        ang = att.Ang
        pos = att.Pos + ang:Up() * 10 + ang:Right() + ang:Forward() * 2

    else
        -- playermodel without the attachment
        pos, ang = handBonePose( ply )
        if pos then
            pos = pos + ang:Up() * 8 + ang:Right() * 2 + ang:Forward() * 2

        else
            ang = ply:EyeAngles()
            pos = ply:EyePos() + ang:Right() * 11 + ang:Forward() * 4

        end
    end

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
