-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=3504739480
-- modified to stop recording faster when player dies

AddCSLuaFile()

sound.Add({
    name = "CrapVidCam.ToggleCamera_Glee",
    channel = CHAN_WEAPON,
    volume = 0.5,
    level = 70,
    pitch = 112,
    sound = "buttons/lightswitch2.wav",
})

SWEP.PrintName = "Crappy Video Camera"
SWEP.Instructions = [[
<color=green>[LMB]</color> Start/stop recording

<color=#00ffff>Videos will be saved in your garrysmod/videos folder in WEBM format.</color>
Credit teapot 3504739480]]

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "weapon_glee_crapvidcam", "vgui/entities/glee_weapon_crapvidcam" )
end

SWEP.Author = "teapot"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "rpg"

SWEP.WorldModel = Model("models/dav0r/camera.mdl")
SWEP.ViewModel = Model("models/dav0r/camera.mdl")
SWEP.ViewModelFOV = 55
SWEP.UseHands = false

SWEP.Slot = 4
SWEP.SlotPos = 3
SWEP.Weight = 1

SWEP.AutoSwitchFrom = false
SWEP.AutoSwitchTo = false

SWEP.Primary.Sound = Sound("CrapVidCam.ToggleCamera_Glee")
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

SWEP.IronsightsPos = Vector(16, 30, -6)
SWEP.IronsightsAng = Angle(0, 0, 0)
SWEP.IronsightsFOV = 0.8
SWEP.IronsightsSensitivity = 0.8
SWEP.IronsightsCrosshair = false
SWEP.UseIronsightsRecoil = true

SWEP.LoweredPos = Vector(16, 30, -6)
SWEP.LoweredAng = Angle(0, 0, 0)
SWEP.SelectFont = "HudDefault"
SWEP.IronAnimSpeed = 0.05
SWEP.NoEmptyAnims = true
SWEP.ReloadSpeed = 1.6
SWEP.IronAdjust = 0.5

SWEP.DefaultPos = Vector(16, 30, -6)
--SWEP.DefaultPos = Vector(0, 20, 0)

SWEP.DrawCrosshair = false

function SWEP:SetupDataTables()
    self:NetworkVar( "Float", "Quality" )
    self:NetworkVar( "Float", "FOVScale" )

end

function SWEP:Initialize()
    self:SetHoldType("rpg")
    self:SetQuality( math.Rand( 0.75, 3 ) )
    self:SetFOVScale( math.Rand( 0.75, 1.5 ) )

end

if SERVER then
    util.AddNetworkString("crapvidcam_glee")

    hook.Add("PlayerSpawn", "CrapVidCam_glee", function(ply)
        net.Start("crapvidcam_glee")
        net.Send(ply)
    end)

else
    local framesWhileDead = 0
    local framesWhileDeadRange = { 1, 90 } -- how many frames to record while dead before stopping
    local VIDCAM_WRITER, VIDCAM_ERROR
    local clrErr, clrSave = Color(255, 0, 0), Color(0, 255, 255)
    local VIDCAM_CONFIG = {
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

    local CurrConfig

    function beginRecording()
        hook.Add( "PreDrawViewModels", "CrapVidCam_glee", function()
            if not VIDCAM_WRITER then return end
            local me = LocalPlayer()
            if not IsValid( me ) or not me:Alive() then
                framesWhileDead = framesWhileDead - 1
                if framesWhileDead <= 0 then
                    VIDCAM_TOGGLE()
                    return
                end
            end
            VIDCAM_WRITER:AddFrame(FrameTime(), true)
            LocalPlayer():SetDSP(38, true)
        end )
    end

    function VIDCAM_TOGGLE( camera )
        if VIDCAM_WRITER then
            hook.Remove("PreDrawViewModels", "CrapVidCam_glee")
            chat.AddText(clrSave, "Saved video to garrysmod/videos/" .. CurrConfig.name .. ".webm")
            VIDCAM_WRITER:Finish()
            VIDCAM_WRITER = nil -- memory leak! whoops
            LocalPlayer():SetDSP(0, true)
        elseif IsValid( camera ) then
            CurrConfig = table.Copy( VIDCAM_CONFIG )
            CurrConfig.quality = VIDCAM_CONFIG.quality * camera:GetQuality()
            CurrConfig.fps = math.Clamp( VIDCAM_CONFIG.fps * camera:GetQuality(), 5, 60 )
            CurrConfig.bitrate = VIDCAM_CONFIG.bitrate * camera:GetQuality()
            CurrConfig.fovScale = VIDCAM_CONFIG.fovScale * camera:GetFOVScale()

            framesWhileDead = math.random( framesWhileDeadRange[1], framesWhileDeadRange[2] )
            CurrConfig.name = "GLEE_vidcam-" .. util.DateStamp()
            local w, h = ScrW(), ScrH()
            CurrConfig.width = math.min(w, 480)
            CurrConfig.height = math.min(math.floor((CurrConfig.width * h) / w), w)
            VIDCAM_WRITER, VIDCAM_ERROR = video.Record(CurrConfig)
            if VIDCAM_WRITER then
                VIDCAM_WRITER:SetRecordSound(true)
                beginRecording()
            else
                chat.AddText(clrErr, "Couldn't record video: " .. VIDCAM_ERROR)
            end
        end
    end

    net.Receive("crapvidcam_glee", function(len)
        if VIDCAM_WRITER then
            VIDCAM_TOGGLE()
        end
    end)

    local clrRec, clrRecB = Color(255, 100, 100), Color(20, 20, 20)
    hook.Add("HUDPaint", "CrapVidCam_glee", function()
        if VIDCAM_WRITER then
            if math.sin(CurTime() * 8) > 0 then
                draw.SimpleTextOutlined("RECORDING", "DermaLarge", ScrW() * 0.5, 0, clrRec, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, clrRecB)
            end
        end
    end)

    hook.Add("CalcView", "CrapVidCam_glee", function(ply, pos, angles, fov)
        if VIDCAM_WRITER then
            return {
                origin = pos,
                angles = angles,
                fov = fov * CurrConfig.fovScale,
            }
        end
    end)
end

function SWEP:CanSecondaryAttack() return false end

function SWEP:PrimaryAttack()
    if SERVER and game.SinglePlayer() then
        self:CallOnClient("PrimaryAttack")
        return
    end

    local curtime = CurTime()
    if curtime < self:GetNextPrimaryFire() then return end
    self:SetNextPrimaryFire(curtime + 0.1)
    self:EmitSound(self.Primary.Sound)

    if CLIENT and (IsFirstTimePredicted() or game.SinglePlayer()) then
        VIDCAM_TOGGLE( self )
    end
end

function SWEP:Holster()
    if CLIENT and (IsFirstTimePredicted() or game.SinglePlayer()) and LocalPlayer() == self:GetOwner() and VIDCAM_WRITER then
        VIDCAM_TOGGLE()
    end

    if game.SinglePlayer() then
        self:CallOnClient("Holster")
    end

    return true
end

function SWEP:DrawWorldModel()
    local ply = self:GetOwner()
    if not IsValid( ply ) then
        self:DrawModel()
        return

    end
    local att = ply:GetAttachment(ply:LookupAttachment("anim_attachment_RH"))
    local ang = att.Ang
    self:SetPos(att.Pos + ang:Up() * 10 + ang:Right() + ang:Forward() * 2)
    self:SetAngles(ang)
    self:SetupBones()
    self:DrawModel()
end

local camPos = Vector(16, 30, -6)

function SWEP:GetViewModelPosition(pos, ang)
    pos:Add(camPos[1] * ang:Right())
    pos:Add(camPos[2] * ang:Forward())
    pos:Add(camPos[3] * ang:Up())
    return pos, ang
end

if not SERVER then return end

hook.Add( "InitPostEntity", "CrapVidCam_glee", function()
    GAMEMODE:RandomlySpawnEnt( "weapon_glee_crapvidcam", math.random( 1, 2 ), math.Rand( 0.1, 4.5 ), nil, math.random( 2000, 10000 ) )

end )