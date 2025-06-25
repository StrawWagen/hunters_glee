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

local entMeta = FindMetaTable( "Entity" )

-- have internal channel inside radio, and have what we show to plys/other code
local legalChannels = {
    [1] = 0,
    [2] = 1,
    [3] = 666

}

local undeadChannel = 3

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
    terminator_Extras.glee_CL_SetupSwep( SWEP, "termhunt_radio", "materials/vgui/hud/termhunt_radio.png" )

else
    util.PrecacheSound( "ambient/levels/prison/radio_random11.wav" )
    util.PrecacheSound( "ambient/levels/citadel/strange_talk11.wav" )

end
if SERVER then
    resource.AddFile( "materials/entities/termhunt_radio.png" )

end

function SWEP:Initialize()
    self:SetNWInt( "glee_radiochannel_index", 2 )
    self.OldOwner = nil
    self.NextPrimaryFire = 0
    self.NextSecondaryFire = 0

end

function SWEP:UpdateServersideChannel()
    local channel = self:GetChannelTranslated()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end
    if not SERVER then return end
    owner.termhuntRadio = self
    owner:SetGleeRadioChannel( channel )
    owner.huntersglee_preferredradiochannel = self:GetChannelIndex()

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

    if newChannel >= undeadChannel and not can666 then
        newChannel = 1

    elseif newChannel > self.totalChannels then
        newChannel = 1

    elseif newChannel < 1 then
        if can666 then
            newChannel = self.totalChannels

        else
            newChannel = 2

        end
    end

    if SERVER then
        if newChannel == 1 then
            huntersGlee_Announce( { owner }, 2, 1, "Global chat: Off" )

        elseif newChannel == 2 then
            huntersGlee_Announce( { owner }, 2, 1, "Global chat: On" )

        elseif newChannel == 3 then
            huntersGlee_Announce( { owner }, 2, 1, "Global chat: 666" )

        end
    end

    if not SERVER then return end
    self:SetNWInt( "glee_radiochannel_index", newChannel )

    self:UpdateServersideChannel()

end

function SWEP:SwitchedToNoChannelSnd()
    self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65, 75 )

end
function SWEP:SwitchedChannelSnd()
    self:EmitSound( "ambient/levels/prison/radio_random11.wav", 65, 75 )

end
function SWEP:SwitchedTo666Snd()
    self:EmitSound( "ambient/levels/citadel/strange_talk11.wav", 65, 120 )

end

function SWEP:PrimaryAttack()
    if self.NextPrimaryFire > CurTime() then return end
    self.NextPrimaryFire = CurTime() + 0.2

    if IsFirstTimePredicted() then
        self:ChannelSwitch( 1 )
        local index = self:GetChannelIndex()

        if index == undeadChannel then
            self:SwitchedTo666Snd()
            if CLIENT then glee_SoulsThinkNOW() end

        elseif index == 1 then
            self:SwitchedToNoChannelSnd()

        else
            self:SwitchedChannelSnd()

        end
    end
end

function SWEP:SecondaryAttack()
    if self.NextSecondaryFire > CurTime() then return end
    self.NextSecondaryFire = CurTime() + 0.2

    if IsFirstTimePredicted() then
        self:ChannelSwitch( -1 )

        local index = self:GetChannelIndex()

        if index == undeadChannel then
            self:SwitchedTo666Snd()
            if CLIENT then glee_SoulsThinkNOW() end

        elseif index == 1 then
            self:SwitchedToNoChannelSnd()

        else
            self:SwitchedChannelSnd()

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
        if not IsValid( self ) then timer.Stop( name ) return end
        owner = entMeta.GetOwner( self )
        if not IsValid( owner ) or entMeta.Health( owner ) <= 0 or not IsValid( owner:GetActiveWeapon() ) then timer.Stop( name ) return end
        self:ManageSound()

    end )
    local preferredChannel = owner.huntersglee_preferredradiochannel
    if preferredChannel then
        -- had 666, but not anymore!
        if preferredChannel == undeadChannel and not owner:GetNWBool( "glee_cantalk_tothedead", false ) then
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
    self.sound_static = nil
    self.sound_screams = nil
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
    local myTbl = entMeta.GetTable( self )
    local owner = entMeta.GetOwner( self )
    local index = myTbl.GetChannelIndex( self )
    if not IsValid( myTbl.sound_static ) or not myTbl.sound_static:IsPlaying() then
        myTbl.sound_static = myTbl.sound_static or CreateSound( owner, "ambient/levels/prison/radio_random1.wav" )

        if index ~= 1 and index ~= undeadChannel and self == owner:GetActiveWeapon() and owner:Health() > 0 then
            myTbl.doneFadeOut = nil
            myTbl.sound_static:PlayEx( 0.8, self:GetStaticPitch() )

        else
            if not myTbl.doneFadeOut then
                myTbl.doneFadeOut = true
                myTbl.sound_static:FadeOut( 0.25 )

            end
        end
    end

    if not IsValid( myTbl.sound_screams ) or not myTbl.sound_screams:IsPlaying() then
        myTbl.sound_screams = myTbl.sound_screams or CreateSound( owner, "ambient/levels/citadel/citadel_ambient_voices1.wav" )
        if index == undeadChannel and self == owner:GetActiveWeapon() and owner:Health() > 0 then
            myTbl.doneScreamsFadeOut = nil
            myTbl.sound_screams:SetSoundLevel( 65 )
            myTbl.sound_screams:PlayEx( 0.6, self:GetStaticPitch() )

        else
            if not myTbl.doneScreamsFadeOut then
                myTbl.doneScreamsFadeOut = true
                myTbl.sound_screams:FadeOut( 0.25 )

            end
        end
    end
end

function SWEP:Holster()
    return true

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

    return self:GetNWInt( "glee_radiochannel", 0 )

end

if not CLIENT then return end

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

hook.Add( "PlayerInitialSpawn", "setdefaultradio", function( spawned )
    spawned.huntersglee_preferredradiochannel = 2

end ) 