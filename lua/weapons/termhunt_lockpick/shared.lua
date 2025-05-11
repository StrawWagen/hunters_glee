AddCSLuaFile()

if CLIENT then
    SWEP.Slot = 2
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

-- Variables that are used on both client and server

SWEP.PrintName = "Lock Pick"
SWEP.Author = "DarkRP Developers, Modifed by straw wegen"
SWEP.Instructions = "Left or right click to pick a lock"
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.IsDarkRPLockpick = true

SWEP.ViewModelFOV = 62
SWEP.ViewModelFlip = false
SWEP.ViewModel = Model( "models/weapons/c_crowbar.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_crowbar.mdl" )

SWEP.UseHands = true

SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "Hunter's Glee"

SWEP.Sound = Sound( "physics/wood/wood_box_impact_hard3.wav" )

SWEP.Primary.ClipSize = -1      -- Size of a clip
SWEP.Primary.DefaultClip = 0        -- Default number of bullets in a clip
SWEP.Primary.Automatic = false      -- Automatic/Semi Auto
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1        -- Size of a clip
SWEP.Secondary.DefaultClip = -1     -- Default number of bullets in a clip
SWEP.Secondary.Automatic = false        -- Automatic/Semi Auto
SWEP.Secondary.Ammo = ""

local className = "termhunt_lockpick"
if CLIENT then
    language.Add( className, SWEP.PrintName )
    killicon.Add( className, "vgui/hud/killicon/" .. className .. ".png", color_white )

else
    resource.AddFile( "materials/vgui/hud/killicon/" .. className .. ".png" )
    resource.AddFile( "materials/entities/termhunt_lockpick.png" )

end

function SWEP:SetupDataTables()
    self:NetworkVar( "Bool", 0, "IsLockpicking" )
    self:NetworkVar( "Float", 0, "LockpickStartTime" )
    self:NetworkVar( "Float", 1, "LockpickEndTime" )
    self:NetworkVar( "Float", 2, "NextSoundTime" )
    self:NetworkVar( "Int", 0, "TotalLockpicks" )
    self:NetworkVar( "Entity", 0, "LockpickEnt" )
end

function SWEP:Initialize()
    self:SetHoldType( "normal" )
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 0.5 )
    if self:GetIsLockpicking() then return end

    local Owner = self:GetOwner()

    if not IsValid( Owner ) then return end

    Owner:LagCompensation( true )
    local trace = Owner:GetEyeTrace()
    Owner:LagCompensation( false )
    local ent = trace.Entity
    if ent.realDoor then ent = ent.realDoor end

    if not IsValid( ent ) then return end

    local class = ent:GetClass()

    if not ( class == "prop_door_rotating" or ( ent:Health() and ent:Health() <= 90 ) ) then return end
    if trace.HitPos:Distance( Owner:GetShootPos() ) > 100 then return end

    if SERVER and ( ent.huntersglee_breakablenails or ( class == "prop_door_rotating" and not util.doorIsUsable( ent ) ) ) then
        ent:EmitSound( "doors/wood_stop1.wav", 60, math.random( 90, 100 ) )
        ent:Fire( "setanimation", "locked", 0 )
        return
    end

    self:SetHoldType( "pistol" )

    self:SetIsLockpicking( true )
    self:SetLockpickEnt( ent )
    self:SetLockpickStartTime( CurTime() )
    local endDelta = util.SharedRandom( "DarkRP_Lockpick" .. self:EntIndex() .. "_" .. self:GetTotalLockpicks(), 5, 10 )
    self:SetLockpickEndTime( CurTime() + endDelta )
    self:SetTotalLockpicks( self:GetTotalLockpicks() + 1 )

    if IsFirstTimePredicted() then
        hook.Call( "lockpickStarted", nil, Owner, ent, trace )
    end

    self.onFail = function( ply ) if ply == Owner then hook.Call( "onLockpickCompleted", nil, ply, false, ent ) end end

end

function SWEP:Holster()
    if self:GetIsLockpicking() and self:GetLockpickEndTime() ~= 0 then
        self:Fail()
    end
    return true
end

function SWEP:Succeed()
    self:SetHoldType( "normal" )

    local ent = self:GetLockpickEnt()
    self:SetIsLockpicking( false )
    self:SetLockpickEnt( nil )

    if not IsValid( ent ) then return end

    local override = hook.Call( "onLockpickCompleted", nil, self:GetOwner(), true, ent )

    if override then return end
    local class = ent:GetClass()
    local isGlass = class == "func_breakable_surf"
    if ent.Fire then
        if isGlass then
            local owner = self:GetOwner()
            owner:LagCompensation( true )
            local trace = owner:GetEyeTrace()
            owner:LagCompensation( false )
            ent:Fire( "Shatter", trace.HitPos )

        elseif ent:Health() > 0 and ent:Health() <= 90 then
            ent:TakeDamage( 90, self:GetOwner(), self )

        elseif ent.huntersglee_breakablenails then
            ent:EmitSound( "doors/wood_stop1.wav", 75, math.random( 90, 100 ) )
            return

        elseif ent:GetInternalVariable( "m_bLocked" ) == true then
            ent:EmitSound( "doors/door_squeek1.wav", 60 )
            ent:Fire( "unlock" )
            ent:Fire( "open", "" )
            ent:Fire( "setanimation", "open" )

        else
            ent:Fire( "lock" )
            ent:Fire( "setanimation", "locked", 0 )
            ent:EmitSound( "doors/door_locked2.wav", 60 )

        end
    end
end

function SWEP:Fail()
    self:SetIsLockpicking( false )
    self:SetHoldType( "normal" )

    hook.Call( "onLockpickCompleted", nil, self:GetOwner(), false, self:GetLockpickEnt() )
    self:SetLockpickEnt( nil )
end

function SWEP:Think()
    if not self:GetIsLockpicking() or self:GetLockpickEndTime() == 0 then return end

    if not IsValid( self:GetOwner() ) or self:GetOwner():Health() <= 0 then self.onFail() end

    local trace = self:GetOwner():GetEyeTrace()
    local ent = trace.Entity
    if ent.realDoor then ent = ent.realDoor end

    if ent.huntersglee_breakablenails then return end

    if CurTime() >= self:GetNextSoundTime() then
        local class = ent:GetClass()
        if class == "prop_door_rotating" or class == "item_item_crate" then
            self:SetNextSoundTime( CurTime() + 1 )
            local snd = { 1,3,4 }
            local soundNum = tostring( snd[math.Round( util.SharedRandom( "DarkRP_LockpickSnd" .. CurTime(), 1, #snd ) ) ] )
            self:EmitSound( "weapons/357/357_reload" .. soundNum .. ".wav", 50, 100 )
        end
    end

    if not SERVER then return end

    local step = 6
    local status = generic_WaitForProgressBar( self:GetOwner(), "termhunt_weapon_lockpick_picking", 0.25, step )

    if not IsValid( ent ) or ent ~= self:GetLockpickEnt() or trace.HitPos:DistToSqr( self:GetOwner():GetShootPos() ) > 100^2 then
        self:Fail()
    elseif status >= 100 then
        generic_KillProgressBar( self:GetOwner(), "termhunt_weapon_lockpick_picking" )
        self:Succeed()
    end
end

function SWEP:SecondaryAttack()
    self:PrimaryAttack()
end
