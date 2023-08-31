SWEP.PrintName = "Radio"
SWEP.Author = "Straw W Wagen + 635535045"
SWEP.Purpose = "Talk to people across the map. Need to be on the same channel."

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.Spawnable = true
SWEP.Category = "Hunter's Glee"

SWEP.ViewModel = Model( "models/radio/c_radio.mdl" )
SWEP.WorldModel = Model( "models/radio/w_radio.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.Weight = 1

SWEP.totalChannels = 4

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

if CLIENT then
    resource.AddFile( "materials/entities/termhunt_radio.png" )

end

function SWEP:Initialize()
    self.Range = 1800
    self.MeleeWeaponDistance = self.Range
    self:SetNWInt( "radiochannel", 1 )
    self.OldOwner = nil
    self.NextPrimaryFire = 0
    self.NextSecondaryFire = 0

end

function SWEP:UpdateServersideChannel( channelIn )
    local channel = channelIn or self:GetChannel()
    local owner = self:GetOwner()
    owner.termhuntRadio = self
    owner.termhuntRadioChannel = channel

end

function SWEP:GetChannel()
    return self:GetNWInt( "radiochannel" )

end

function SWEP:ChannelSwitch( add )
    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    local owner = self:GetOwner()
    owner:GetViewModel():SetPlaybackRate( 4 ) -- faster
    owner:SetAnimation( PLAYER_ATTACK1 )

    add = add or 1

    local currChannel = self:GetChannel()
    local newChannel = currChannel + add

    if newChannel > self.totalChannels then
        newChannel = 0

    elseif newChannel < 0 then
        newChannel = self.totalChannels

    end

    self:SetNWInt( "radiochannel", newChannel )

    if not SERVER then return end

    owner.huntersglee_preferredradiochannel = newChannel
    self:UpdateServersideChannel( newChannel )

    if newChannel == 0 then
        huntersGlee_Announce( { owner }, 1, 1.5, "Global chat turned off." )

    end
end

function SWEP:PrimaryAttack()

    if self.NextPrimaryFire > CurTime() then return end
    self.NextPrimaryFire = CurTime() + 0.2

    if IsFirstTimePredicted() then
        self:ChannelSwitch( 1 )
        if self:GetChannel() == 0 then
            self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65, 75 )

        else
            self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65 )

        end
    end
end

function SWEP:SecondaryAttack()
    if self.NextSecondaryFire > CurTime() then return end
    self.NextSecondaryFire = CurTime() + 0.2

    if IsFirstTimePredicted() then
        self:ChannelSwitch( -1 )
        if self:GetChannel() == 0 then
            self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65, 75 )

        else
            self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65 )

        end
    end
end

function SWEP:Reload()
    if self:GetChannel() == 0 then return end
    nextReload = self.nextReload or 0
    if nextReload > CurTime() then return end

    self.nextReload = CurTime() + 0.3

    self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65, 75 )
    self:ChannelSwitch( self.totalChannels + 1 )

end

function SWEP:GetViewModelPosition( pos, ang )
    local offset = Vector( 0, 0, -5 )
    return pos + offset, ang

end

function SWEP:CustomAmmoDisplay()
    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.SecondaryAmmo = nil
    self.AmmoDisplay.PrimaryAmmo = nil
    self.AmmoDisplay.PrimaryClip = self:GetChannel()

    return self.AmmoDisplay

end

function SWEP:GetStaticPitch()
    return math.Rand( 59, 61 ) + self:GetChannel() * 5

end

-- when it goes from on the ground to on the player
function SWEP:Equip()
    self:SetHoldType( "slam" )

    self.OldOwner = self:GetOwner()

    local name = self:GetCreationID() .. "staticmanagertimer"

    timer.Create( name, 0, 0, function()
        if not IsValid( self ) or not IsValid( self:GetOwner() ) or self:GetOwner():Health() <= 0 or not IsValid( self:GetOwner():GetActiveWeapon() ) then timer.Stop( name ) return end
        self:ManageSound()

    end )
    local preferredChannel = self:GetOwner().huntersglee_preferredradiochannel
    if preferredChannel then
        self:SetNWInt( "radiochannel", preferredChannel )

    end
    self:UpdateServersideChannel()

end

function SWEP:ShutDown()
    if not IsValid( self.OldOwner ) then return end
    self.static = nil
    self.OldOwner.termhuntRadio = nil
    self.OldOwner.termhuntRadioChannel = nil

end

function SWEP:OnRemove()
    self:ShutDown()

end

function SWEP:OnDrop()
    self:ShutDown()
    self:Remove()

end

function SWEP:ManageSound()
    if not SERVER then return end
    if IsValid( self.static ) and self.static:IsPlaying() then return end
    self.static = self.static or CreateSound( self:GetOwner(), "ambient/levels/prison/radio_random1.wav" )
    if self == self:GetOwner():GetActiveWeapon() and self:GetOwner():Health() > 0 and self:GetColor().a ~= 0 and self:GetNWInt( "radiochannel" ) ~= 0 then
        self.doneFadeOut = nil
        self.static:PlayEx( 0.8, self:GetStaticPitch() )
    else
        if not self.doneFadeOut then
            self.doneFadeOut = true
            self.static:FadeOut( 0.5 )
        end
    end
end

function SWEP:Holster()
    return true

end

function SWEP:GetCapabilities()
    return CAP_WEAPON_RANGE_ATTACK1
end

function SWEP:ShouldDropOnDie()
    return false

end