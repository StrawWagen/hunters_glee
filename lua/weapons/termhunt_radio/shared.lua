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

-- have internal channel inside radio, and have what we show to plys/other code
local legalChannels = {
    [1] = 0,
    [2] = 1,
    [3] = 2,
    [4] = 3,
    [5] = 4,
    [6] = 666

}
SWEP.totalChannels = #legalChannels

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
    self:SetNWInt( "glee_radiochannel_index", 2 )
    self.OldOwner = nil
    self.NextPrimaryFire = 0
    self.NextSecondaryFire = 0

end

function SWEP:UpdateServersideChannel()
    local channel = self:GetChannelTranslated()
    local owner = self:GetOwner()
    owner.termhuntRadio = self
    owner:SetGleeRadioChannel( channel )


end

function SWEP:GetChannelIndex()
    return self:GetNWInt( "glee_radiochannel_index" )

end

function SWEP:GetChannelTranslated()
    return legalChannels[ self:GetChannelIndex() ]

end

function SWEP:ChannelSwitch( add )
    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    local owner = self:GetOwner()
    owner:GetViewModel():SetPlaybackRate( 4 ) -- faster
    owner:SetAnimation( PLAYER_ATTACK1 )

    add = add or 1

    local can666 = owner:GetNWBool( "glee_cantalk_tothedead", false )
    local currChannel = self:GetChannelIndex()
    local newChannel = currChannel + add

    if newChannel >= 6 and not can666 then
        newChannel = 1

    elseif newChannel > self.totalChannels then
        newChannel = 1

    elseif newChannel < 1 then
        if can666 then
            newChannel = self.totalChannels

        else
            newChannel = 5

        end
    end

    self:SetNWInt( "glee_radiochannel_index", newChannel )

    if not SERVER then return end

    owner.huntersglee_preferredradiochannel = newChannel
    self:UpdateServersideChannel( newChannel )

    if newChannel == 1 then
        huntersGlee_Announce( { owner }, 1, 1.5, "Global chat turned off." )

    end
end

function SWEP:PrimaryAttack()
    if self.NextPrimaryFire > CurTime() then return end
    self.NextPrimaryFire = CurTime() + 0.2

    if IsFirstTimePredicted() then
        self:ChannelSwitch( 1 )
        if self:GetChannelIndex() == 1 then
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
        if self:GetChannelIndex() == 1 then
            self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65, 75 )

        else
            self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65 )

        end
    end
end

function SWEP:Reload()
    if self:GetChannelIndex() == 1 then return end
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
    self.AmmoDisplay.PrimaryClip = self:GetChannelTranslated()

    return self.AmmoDisplay

end

function SWEP:GetStaticPitch()
    return math.Rand( 59, 61 ) + self:GetChannelIndex() * 4.2

end

-- when it goes from on the ground to on the player
function SWEP:Equip()
    self:SetHoldType( "slam" )
    local owner = self:GetOwner()

    self.OldOwner = owner

    local name = self:GetCreationID() .. "staticmanagertimer"

    timer.Create( name, 0, 0, function()
        if not IsValid( self ) or not IsValid( self:GetOwner() ) or self:GetOwner():Health() <= 0 or not IsValid( self:GetOwner():GetActiveWeapon() ) then timer.Stop( name ) return end
        self:ManageSound()

    end )
    local preferredChannel = owner.huntersglee_preferredradiochannel
    if preferredChannel then
        if preferredChannel == 6 and not owner:GetNWBool( "glee_cantalk_tothedead", false ) then
            self:SetNWInt( "glee_radiochannel_index", 2 )
            owner.huntersglee_preferredradiochannel = 2

        else
            self:SetNWInt( "glee_radiochannel_index", preferredChannel )

        end
    end
    self:UpdateServersideChannel()

end

function SWEP:ShutDown()
    if not IsValid( self.OldOwner ) then return end
    self.static = nil
    self.OldOwner.termhuntRadio = nil
    self.OldOwner.glee_RadioChannel = nil

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
    if self == self:GetOwner():GetActiveWeapon() and self:GetOwner():Health() > 0 and self:GetChannelIndex() ~= 1 then
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


local plyMeta = FindMetaTable( "Player" )

function plyMeta:SetGleeRadioChannel( channel )
    self:SetNWInt( "glee_radiochannel", channel )
    self.glee_RadioChannel = channel

end

function plyMeta:GetGleeRadioChannel()
    if self:Health() <= 0 then
        return 666

    end

    return self:GetNWInt( "glee_radiochannel", 1 )

end
