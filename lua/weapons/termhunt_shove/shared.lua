SWEP.Author         = "Based off of pac3 hands."
SWEP.Contact         = ""
SWEP.Purpose         = "To shove"
SWEP.Instructions   = "Left click to shove"
SWEP.PrintName      = "Shove"
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair    = true
SWEP.DrawWeaponInfoBox = false

SWEP.SlotPos          = 1
SWEP.Slot             = 0

SWEP.Spawnable        = true
SWEP.AdminSpawnable    = false
SWEP.Category = "Hunter's Glee"

SWEP.AutoSwitchTo    = false
SWEP.AutoSwitchFrom    = true
SWEP.Weight         = 1

SWEP.HoldType = "normal"

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = true
SWEP.Secondary.Ammo        = "none"

if CLIENT then
    local shovedBefore = CreateClientConVar( "cl_huntersgleehint_hasshoved", 0, true, false, "Player has shoved before?", 0, 1 )
    hook.Add( "InitPostEntity", "glee_clreadhints_shove", function()
        LocalPlayer().glee_DefinitelyShoved = shovedBefore:GetBool()

    end )

    function SWEP:HintPostStack()
        local owner = self:GetOwner()

        if owner.glee_DefinitelyShoved then return end
        local nwBool = owner:GetNW2Bool( "gleeshove_primaryattacked", false )
        if not nwBool then
            return true, "Primary attack to do a big shove!"

        elseif nwBool then
            owner.glee_DefinitelyShoved = true
            RunConsoleCommand( "cl_huntersgleehint_hasshoved", "1" )

        end
    end
else
    resource.AddFile( "materials/entities/termhunt_shove.png" )

end

function SWEP:DrawHUD()             end
function SWEP:PrintWeaponInfo()     end

function SWEP:DrawWeaponSelection( x, y, w, _, a )
    draw.SimpleText( "C", "creditslogo", x + w / 2, y, Color( 255, 220, 0, a ), TEXT_ALIGN_CENTER )

end

function SWEP:DrawWorldModel()                          end
function SWEP:DrawWorldModelTranslucent()              end
function SWEP:Reload()                    return false end
function SWEP:Holster()                    return true  end
function SWEP:ShouldDropOnDie()            return false end

SWEP.ShoveSounds1 = {
    "physics/body/body_medium_impact_hard1.wav",
    "physics/body/body_medium_impact_hard2.wav",
    "physics/body/body_medium_impact_hard3.wav",
    "physics/body/body_medium_impact_hard4.wav",
    "physics/body/body_medium_impact_hard5.wav",
    "physics/body/body_medium_impact_hard6.wav",
}
SWEP.ShoveSounds2 = {
    "physics/cardboard/cardboard_box_impact_hard6.wav",
    "weapons/slam/throw.wav",
}


function SWEP:ShoveSound( PitMod )
    PitMod = PitMod or 0
    local Sound1 = table.Random( self.ShoveSounds1 )
    local Sound2 = table.Random( self.ShoveSounds2 )
    self.Owner:EmitSound( Sound1, 66, math.random( 100, 120 ) + PitMod, 1, CHAN_STATIC )
    self.Owner:EmitSound( Sound2, 70, math.random( 60, 80 ) + PitMod, 1, CHAN_STATIC )

end

function SWEP:Initialize()
    if self.SetHoldType then
        self:SetHoldType( "normal" )
    else
        self:SetWeaponHoldType( "normal" )
    end

    self:DrawShadow( false )
end

function SWEP:Deploy()
    self:SetNextPrimaryFire( CurTime() + 0.5 )
    self.Thinking = true
    return true
end

function SWEP:Think()
end

local gtfo = Vector( 1, 1, 1 ) * 65000

function SWEP:GetViewModelPosition( _, ang )
    return gtfo,ang
end

function SWEP:PreDrawViewModel()
    return true
end


function SWEP:CanPrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return false end
    return true
end

function SWEP:SecondaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:PrimaryAttack( 0.25 )

end

function SWEP:ShoveAnim()
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        local owner = self:GetOwner()
        if not IsValid( owner ) then return end
        owner:DoAnimationEvent( ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND )

    end )
end

function SWEP:PrimaryAttack( firstMul )
    if not SERVER then return end
    if not self:CanPrimaryAttack() then return end

    local owner = self:GetOwner()
    if IsValid( owner ) and owner:InVehicle() then return end

    firstMul = firstMul or 1

    local pitchAdded = math.abs( firstMul - 1 ) * 5

    local NoHit = nil
    local AimVector = owner:GetAimVector()
    local ShootPos = owner:GetShootPos()
    local Filter = owner:GetChildren()
    Filter[#Filter + 1] = owner

    local TraceDat = {
        filter = Filter,
        start = ShootPos,
        endpos = ShootPos + AimVector * 50,
        mins = -Vector( 10, 10, 10 ),
        maxs = Vector( 10, 10, 10 ),
    }
    local Trace = util.TraceHull( TraceDat )
    local Hit = Trace.Entity

    local Force = AimVector
    local selfPush

    if IsValid( Hit ) then
        hook.Run( "glee_shover_shove", Hit )
        local Phys = Hit:GetPhysicsObject()
        if Phys and IsValid( Phys ) then
            Force.z = math.Clamp( Force.z, 0.5, 1 )
            self:ShoveSound( pitchAdded )
            if Hit:IsPlayer() then
                Force = Force * 500
                Hit:SetVelocity( ( Hit:GetVelocity() * 0.5 ) + Force * firstMul )
                selfPush = owner:GetVelocity() + ( -( Force * 0.25 ) * firstMul )
                self:SetNextPrimaryFire( CurTime() + 1 )

            else
                local PlyForce = -Force * 125
                Force = Force * math.Clamp( Phys:GetMass() / 400, 0.25, 1 )
                Force = Force * 40000
                Phys:ApplyForceOffset( Force * firstMul, Trace.HitPos )
                selfPush = owner:GetVelocity() + ( PlyForce * firstMul )

                self:SetNextPrimaryFire( CurTime() + 0.8 )

            end
            owner:ViewPunch( Angle( -15, 0, 0 ) * firstMul )
            self:ShoveAnim()

        else
            NoHit = true

        end
    elseif Hit:IsWorld() and not Trace.HitSky and owner:GetEyeTrace().HitWorld then -- make sure we dont do the 5 sec cooldown when they just missed an entity
        self:SetNextPrimaryFire( CurTime() + 2.2 )
        local mul = -150
        mul = mul * ( owner.parkourForce or 0.3 )
        Force = Force * mul * firstMul
        self:ShoveSound( -15 + pitchAdded )
        selfPush = ( owner:GetVelocity() * 0.4 ) + Force
        owner:ViewPunch( Angle( -20, 0, 0 ) * firstMul )
        self:ShoveAnim()

    else
        NoHit = true

    end
    if NoHit then
        self:SetNextPrimaryFire( CurTime() + 0.5 )
        owner:ViewPunch( Angle( -1, 0, 0 ) )
        owner:EmitSound( "weapons/slam/throw.wav", 66, 120 )

    else
        if firstMul >= 1 then
            owner:SetNW2Bool( "gleeshove_primaryattacked", true )

        else
            owner:SetNW2Bool( "gleeshove_secondaryattacked", true )

        end
    end

    if selfPush and not owner:InVehicle() then
        owner:SetVelocity( selfPush )

    end
end

function SWEP:OnDrop()
    if SERVER then
        self:Remove()
    end
end
