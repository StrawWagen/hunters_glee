AddCSLuaFile()

local entMeta = FindMetaTable( "Entity" )

SWEP.Author = "Straw W Wagen."
SWEP.Contact = ""
SWEP.Purpose = "Your powers as the holy chosen."
SWEP.Instructions = [[
Hold primary to create a chain of lightning.

Hold secondary to charge a powerful single strike.

Jump in the air, to rise...

Crouch midair, to descend...]]
SWEP.PrintName = "Divine Chosen"
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.SlotPos          = 0
SWEP.Slot             = 0

SWEP.Spawnable        = true
SWEP.AdminOnly       = true
SWEP.Category = "Hunter's Glee"

SWEP.AutoSwitchTo    = true
SWEP.AutoSwitchFrom    = false
SWEP.Weight         = 1

SWEP.HoldType = "normal"

SWEP.Primary.ClipSize = math.huge
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

-- https://freesound.org/people/nlux/sounds/620497/
-- "sound/620497__nlux__choir-of-weeping-angels-loop.mp3"

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "termhunt_divine_chosen", "materials/vgui/hud/termhunt_divine_chosen.png" )

    function SWEP:HintPreStack()
        local owner = self:GetOwner()

        if not owner:GetNW2Bool( "divinechosen_singlestrike", false ) then return true, "PRIMARY ATTACK to summon a bolt of lightning." end
        if not owner:GetNW2Bool( "divinechosen_jumpinmidair", false ) then return true, "JUMP IN MIDAIR to fly..." end
        if not owner:IsOnGround() and not owner:GetNW2Bool( "divinechosen_dropinmidair", false ) then return true, "hold CROUCH IN MIDAIR to fall..." end
        if not owner:GetNW2Bool( "divinechosen_strikechained", false ) then return true, "HOLD DOWN PRIMARY ATTACK to create a chain of lightning." end

        if not owner:GetNW2Bool( "divinechosen_secondarystrike", false ) then return true, "RIGHT CLICK to charge a lightning strike of unrivaled power." end

    end
end

function SWEP:ShouldDrawViewModel() return false end

function SWEP:DrawHUD()             end

function SWEP:Reload()                    return false end
function SWEP:Holster()                    return true  end
function SWEP:ShouldDropOnDie()            return false end

function SWEP:CustomAmmoDisplay()
    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Clip1()

    return self.AmmoDisplay

end

local function SparkEffect( SparkPos )
    timer.Simple( 0, function() -- wow wouldnt it be cool if effects worked on the first tick personally i think that would be really cool
        local Sparks = EffectData()
        Sparks:SetOrigin( SparkPos )
        Sparks:SetMagnitude( 2 )
        Sparks:SetScale( 1 )
        Sparks:SetRadius( 6 )
        util.Effect( "Sparks", Sparks )

    end )
    sound.Play( "LoudSpark", SparkPos )

end

function SWEP:Initialize()
    self.oldClip = 0
    self.superStrikeCharge = 0
    self:SetHoldType( self.HoldType )

    self:DrawShadow( false )

    hook.Add( "huntersglee_blockwinning", self, function( _, ply )
        local owner = entMeta.GetOwner( self )
        if not IsValid( owner ) then return end
        if ply ~= owner then return end

        return true

    end )
end

function SWEP:Deploy()
    self:SetNextPrimaryFire( CurTime() + 0.1 )
    self.Thinking = true
    return true
end

function SWEP:Think()
end

function SWEP:CanPrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return false end
    return true

end

function SWEP:PrimaryAttack() return end

function SWEP:Equip()
    if not SERVER then return end

    local owner = self:GetOwner()

    owner:SetGravity( 0.25 )
    self.ownersOriginalModel = owner:GetModel()
    owner:SetModel( "models/player/monk.mdl" )

    local timerId = "huntersglee_regenammochosen" .. self:GetCreationID()
    self.timerId = timerId
    local hookId = "huntersglee_blockchosenselfdamage" .. self:GetCreationID()
    self.hookId = hookId
    self.nextClipRegen = 0
    self.nextHealthRegen = 0
    self.nextEpicLine = CurTime() + 3
    self.epicness = 12
    timer.Create( self.timerId, 0.05, 0, function()
        if not IsValid( self ) then timer.Remove( timerId ) return end
        if self:GetOwner():Health() <= 0 then timer.Remove( timerId ) return end
        self:ClipThink()
        self:ChosenThink()
        self:EpicnessThink()

    end )

    hook.Add( "EntityTakeDamage", self.hookId, function( target,dmg )
        if not IsValid( self ) then hook.Remove( "EntityTakeDamage", hookId ) return end
        local owner = self:GetOwner()
        if not IsValid( owner ) then hook.Remove( "EntityTakeDamage", hookId ) return end
        if owner:Health() <= 0 then hook.Remove( "EntityTakeDamage", hookId ) return end

        if target ~= owner then return end

        local chosenWeap = owner:GetWeapon( "termhunt_divine_chosen" )
        if not IsValid( chosenWeap ) then hook.Remove( "EntityTakeDamage", hookId ) return end

        local shockingSelf = ( dmg:IsDamageType( DMG_SHOCK ) or dmg:IsExplosionDamage() ) and dmg:GetAttacker() == owner
        if not shockingSelf then return end
        dmg:ScaleDamage( 0.15 )
        dmg:SetDamageForce( dmg:GetDamageForce() * 40 )

    end )

    local hookName = "divine_chosen_fly" .. owner:GetCreationID()

    -- do this so we can run code when the purchaser jumps
    hook.Add( "KeyPress", hookName, function( ply, key )
        if not IsValid( owner ) then hook.Remove( "KeyPress", hookName ) return end
        if not IsValid( self ) then hook.Remove( "KeyPress", hookName ) return end
        if ply ~= owner then return end

        local chosenWeap = ply:GetWeapon( "termhunt_divine_chosen" )
        if not IsValid( chosenWeap ) then hook.Remove( "KeyPress", hookName ) return end

        if key == IN_JUMP then
            if ply:OnGround() then return end

            local clip = chosenWeap:Clip1()
            local removed = clip - 30

            local upSpeed = 150
            if ply:WaterLevel() >= 1 then
                upSpeed = upSpeed * 2
                owner.glee_noswimming_briefrespite = CurTime() + 0.8 -- HACK to allow swimming
                owner.glee_noswimming_lastlandlubbering = CurTime()

                removed = clip - 5

            end

            if removed < 0 then return end

            chosenWeap:SetClip1( removed )

            owner:SetNW2Bool( "divinechosen_jumpinmidair", true )

            self:DoEpicness( 10 )

            local forward = ply:GetAimVector()
            forward.z = 0
            forward = forward:GetNormalized()

            ply:SetVelocity( ( vector_up * upSpeed ) + ( forward * 100 ) )

            local velLen = ply:GetVelocity():Length()
            local punch = velLen / 200
            local level = 75 + math.Clamp( velLen / 100, 75, 150 )
            local pitch = 130 + -( velLen / 50 )

            self:GetOwner():ViewPunch( Angle( 0.1,punch,math.random( -punch, punch ) ) )

            ply:EmitSound( "weapons/underwater_explode" .. math.random( 3, 4 ) .. ".wav", level, pitch )

            util.ScreenShake( owner:GetPos(), 20, 20, 0.5, 2000, true )

        end
    end )

    owner:EmitSound( "music/hl2_song10.mp3", 75, math.random( 90, 110 ), 1, CHAN_STATIC )

end

function SWEP:ShutDown()
    if not IsValid( self ) then return end

    local owner = self:GetOwner()
    local validOwner = IsValid( owner )

    if validOwner and self.ownersOriginalModel then
        owner:SetModel( self.ownersOriginalModel )

    end

    if self.glee_chosenregen then
        self.glee_chosenregen:Stop()
        self.glee_chosenregen = nil

    end

    if self.epicSound1 then
        self.epicSound1:Stop()
        self.epicSound1 = nil

    end
    if self.epicSound2 then
        self.epicSound2:Stop()
        self.epicSound2 = nil

    end

    if self.modifiedMaxHp and validOwner and owner:GetMaxHealth() == self.maxHpModifedTo and owner:Health() > 0 then
        owner:SetMaxHealth( owner.Glee_BaseHealth or 100 )
        owner:SetHealth( owner:GetMaxHealth() )

    end

    if validOwner then
        owner:SetGravity( 1 )

    end

    timer.Simple( 0, function()
        if not IsValid( owner ) then return end
        if owner:Health() <= 0 then return end
        owner:EmitSound( "ambient/levels/citadel/portal_beam_shoot3.wav", 90, math.random( 110, 120 ), 1, CHAN_STATIC )

    end )

    if self.timerId then
        timer.Remove( self.timerId )

    end
    if self.hookId then
        hook.Remove( "EntityTakeDamage", self.hookId )

    end
end

function SWEP:ChosenThink()
    local owner = self:GetOwner()
    local maxHp = owner:GetMaxHealth()
    local maxArmor = owner:GetMaxArmor()
    if maxHp < 200 then
        self.modifiedMaxHp = true
        self.maxHpModifedTo = 200
        self:GetOwner():SetMaxHealth( 200 )

    end
    local ownersHealth = owner:Health()
    local ownersArmor = owner:Armor()
    if ownersHealth > 0 and self.nextHealthRegen < CurTime() then
        self.nextHealthRegen = CurTime() + 0.05
        if ownersHealth < maxHp then
            owner:SetHealth( math.Clamp( ownersHealth + 4, 0, maxHp ) )

        end
        if ownersArmor < maxArmor then
            owner:SetArmor( math.Clamp( ownersArmor + 1, 0, maxArmor ) )

        end
    end
end

local maxClip = 150
local maxFastClip = 75

function SWEP:ClipThink()
    if self.nextClipRegen > CurTime() then return end
    self.nextClipRegen = CurTime() + 0.10

    local inHighIntensity = self.inHighIntensity or 0
    local addAmnt = 10
    if inHighIntensity > CurTime() then
        addAmnt = 30

    end

    local clip = self:Clip1()
    if clip >= maxFastClip then
        addAmnt = addAmnt / 8

    end

    local newClip = math.Clamp( clip + addAmnt, 0, maxClip )
    self:SetClip1( newClip )

    local owner = self:GetOwner()

    local doSound = nil
    local soundPitch = 0
    local soundVolume = 1
    local soundClip = math.Clamp( newClip, 0, maxFastClip )

    if owner:GetActiveWeapon() == self then
        doSound = true
        soundPitch = 115 + -soundClip / 3

    else
        doSound = nil

    end

    if ( not self.glee_chosenregen or ( self.glee_chosenregen and not self.glee_chosenregen:IsPlaying() ) ) and doSound then
        self.glee_chosenregen = CreateSound( owner, "620497__nlux__choir-of-weeping-angels-loop.mp3", nil )
        self.glee_chosenregen:Play()

    elseif self.glee_chosenregen and not doSound then
        self.glee_chosenregen:Stop()
        self.glee_chosenregen = nil

    end

    if self.glee_chosenregen and doSound then
        self.glee_chosenregen:ChangePitch( soundPitch, 0.09 )
        self.glee_chosenregen:ChangeVolume( soundVolume, 0.09 )

    end

    self.oldClip = newClip

end

function SWEP:Think()
    if not SERVER then return end

    local owner = self:GetOwner()

    if owner:KeyDown( IN_DUCK ) then

        if owner:OnGround() then return end

        owner.chosen_CrouchedInMidairCount = ( owner.chosen_CrouchedInMidairCount or 0 ) + 1
        if owner.chosen_CrouchedInMidairCount <= 35 then
            owner:SetNW2Bool( "divinechosen_dropinmidair", true )

        end

        local forward = owner:GetAimVector()
        forward.z = 0
        forward = forward:GetNormalized()

        owner:SetVelocity( ( -vector_up * 8 ) + ( forward * 5 ) )

    end

    if owner:KeyDown( IN_ATTACK ) then
        if not self.lineOfStrikes then
            self.primaryHits = {}
        end
        self.lineOfStrikes = true
        local eyeTrace = owner:GetEyeTrace()

        local hit = eyeTrace.HitPos

        local oldPrimaryHit = self.oldPrimaryHit
        local goodNewHit = ( not oldPrimaryHit or hit:DistToSqr( oldPrimaryHit ) > 120^2 ) and self:Clip1() > 3

        if goodNewHit then
            self:SetClip1( self:Clip1() + -3 )
            self.oldPrimaryHit = hit
            SparkEffect( hit )
            if GAMEMODE.PanicSource then
                GAMEMODE:PanicSource( hit, 100, 200 )

            end
            table.insert( self.primaryHits, hit )
            sound.EmitHint( SOUND_DANGER, hit, 400, 2, owner )

            owner:SetNW2Bool( "divinechosen_singlestrike", true )

            owner:ViewPunch( Angle( 0.1,0,math.random( -1, 1 ) ) )

            self:DoEpicness( 1 )

        end
    elseif self.lineOfStrikes then
        self.lineOfStrikes = nil
        self.oldPrimaryHit = nil

        self:DoEpicness( #self.primaryHits )

        for step, hit in ipairs( self.primaryHits ) do
            if step > 8 then
                owner:SetNW2Bool( "divinechosen_strikechained", true )

            end
            timer.Simple( 0.4 + step * math.Rand( 0.06, 0.08 ), function()
                if not IsValid( self ) then return end

                local lightning = ents.Create( "glee_lightning" )
                lightning:SetOwner( owner )
                lightning:SetPos( hit )
                lightning:SetPowa( 1.25 )
                lightning:Spawn()

            end )
        end
    end

    if owner:KeyDown( IN_ATTACK2 ) then
        if not self.superStrike or not self.superStrikeCharge then
            self.nextSuperStrikeWarn = 0
            if self:Clip1() >= 20 then
                self.superStrikeCharge = 10
                self:SetClip1( self:Clip1() + -20 )

            else
                self.superStrikeCharge = 0

            end
        end
        self.superStrike = true
        if self:Clip1() >= 2 and self.superStrikeCharge < 200 then
            local additional = 1
            if self.superStrikeCharge > 100 then
                additional = 0.5
            end

            self.superStrikeCharge = self.superStrikeCharge + additional

            if self.superStrikeCharge >= 200 then
                self:DoEpicness( 110 )

            end

            self:SetClip1( self:Clip1() + -2 )
            local punch = self.superStrikeCharge / 400 * math.random( -5, 5 )
            owner:ViewPunch( Angle( 0,-punch,punch ) )

            self:DoEpicness( 1 )

        end
        if self.nextSuperStrikeWarn < CurTime() then
            local offset = 0.11 + -( self.superStrikeCharge / 800 )
            self.nextSuperStrikeWarn = CurTime() + offset
            local eyeHitPos = owner:GetEyeTrace().HitPos
            for _ = 1, math.ceil( self.superStrikeCharge / 50 ) do
                local sparkPos = eyeHitPos + VectorRand() * self.superStrikeCharge
                SparkEffect( sparkPos )
                if GAMEMODE.PanicSource then
                    GAMEMODE:PanicSource( sparkPos, 25, 200 )

                end
            end
            sound.EmitHint( SOUND_DANGER, eyeHitPos, self.superStrikeCharge * 20, 6, owner )

        end
    elseif self.superStrike and self.superStrikeCharge and self.superStrikeCharge > 0 then
        self.superStrike = nil
        self.nextSuperStrikeWarn = nil

        local eyeTrace = owner:GetEyeTrace()
        local powa = self.superStrikeCharge / 8
        owner:ViewPunch( Angle( -powa * 2,powa * math.Rand( -1, 1 ),0 ) )

        if powa > 8 then
            owner:SetNW2Bool( "divinechosen_secondarystrike", true )

        end

        timer.Simple( 0.25, function() -- effect ONLY FUCKING WORKS if i put it in a SIMPLE TIMER - the code literally proceeds fine all the way to util.Effect in the lighting folder but then it just DOESNT create the effect
            if not IsValid( self ) then return end

            local lightning = ents.Create( "glee_lightning" )
            lightning:SetOwner( owner )
            lightning:SetPos( eyeTrace.HitPos )
            lightning:SetPowa( powa )
            lightning:Spawn()

            owner:ViewPunch( Angle( powa * 4, powa * math.Rand( -1, 1 ), 0 ) )
            self:DoEpicness( self.superStrikeCharge )
            self.superStrikeCharge = nil

        end )
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:OnRemove()
    if not SERVER then return end
    self:ShutDown()

end

function SWEP:OnDrop()
    if not SERVER then return end
    self:ShutDown()
    SafeRemoveEntity( self )

end

function SWEP:DrawHUD()
    if not huntersGlee_PaintPlayer then return end
    local nextPlayerCheck = self.nextPlayerCheck or 0
    if nextPlayerCheck < CurTime() then
        self.nextPlayerCheck = CurTime() + 1
        self.alives = {}
        local plys = player.GetAll()
        local alives = {}

        for _, ply in ipairs( plys ) do
            if not IsValid( ply ) then continue end
            if ply == LocalPlayer() then continue end
            if ply:Health() <= 0 then continue end
            table.insert( alives, ply )

        end
        for _, ply in ipairs( alives ) do
            if not IsValid( ply ) then continue end
            table.insert( self.alives, ply )

        end
    end
    if self.alives then
        for _, ply in ipairs( self.alives ) do
            huntersGlee_PaintPlayer( ply )

        end
    end
end

local spriteOffsets = {
    Vector( 0,4,0 ),
    Vector( 0,-4,0 ),

}

local white = Color( 255, 255, 255 )
local mat

function SWEP:DrawWorldModel()

    local owner = self:GetOwner()

    if not IsValid( owner ) then return end
    if LocalPlayer():GetObserverMode() == OBS_MODE_IN_EYE and LocalPlayer():GetObserverTarget() == owner then return end

    if not mat then mat = Material( "sprites/glow04_noz.vmt" ) end

    local eyeId = owner:LookupAttachment( "eyes" )

    local eyes = owner:GetAttachment( eyeId )

    for _, offset in ipairs( spriteOffsets ) do
        cam.Start3D( EyePos(), EyeAngles(), nil, 0, 0, ScrW(), ScrH(), nil, nil )
            render.SetMaterial( mat )
            render.DrawSprite( eyes.Pos + offset, 100, 100, white )
        cam.End3D()
    end
end

if not SERVER then return end

local filterEveryone = RecipientFilter()

local ambientEpicness = {
    { "vo/ravenholm/engage01.wav", 3 },
    { "vo/ravenholm/engage04.wav", 1 },
    { "vo/ravenholm/engage05.wav", 1 },
    { "vo/ravenholm/engage06.wav", 1.8 },
    { "vo/ravenholm/engage07.wav", 2 },
    { "vo/ravenholm/engage08.wav", 3 },
    { "vo/ravenholm/engage09.wav", 2 },
    { "vo/ravenholm/monk_rant08.wav", 7 },
    { "vo/ravenholm/monk_rant07.wav", 7 },
    { "vo/ravenholm/monk_rant06.wav", 8.8 },
    { "vo/ravenholm/monk_rant05.wav", 8 },
    { "vo/ravenholm/monk_rant04.wav", 6.6 },
    { "vo/ravenholm/monk_quicklybro.wav", 1 },
    { "vo/ravenholm/shotgun_overhere.wav", 1 },
}

local justRants = {
    { "vo/ravenholm/monk_rant22.wav", 9 },
    { "vo/ravenholm/monk_rant21.wav", 6.5 },
    { "vo/ravenholm/monk_rant20.wav", 6.5 },
    { "vo/ravenholm/monk_rant19.wav", 7 },
    { "vo/ravenholm/monk_rant18.wav", 4 },
    { "vo/ravenholm/monk_rant17.wav", 4.5 },
    { "vo/ravenholm/monk_rant16.wav", 5.5 },
    { "vo/ravenholm/monk_rant15.wav", 6.5 },
    { "vo/ravenholm/monk_rant14.wav", 9 },
    { "vo/ravenholm/monk_rant13.wav", 12 },
    { "vo/ravenholm/monk_rant12.wav", 6.6 },
    { "vo/ravenholm/monk_rant11.wav", 5.5 },
    { "vo/ravenholm/monk_rant10.wav", 5 },
    { "vo/ravenholm/monk_rant09.wav", 11.8 },
    { "vo/ravenholm/monk_rant03.wav", 8.6 },
    { "vo/ravenholm/monk_rant02.wav", 6.3 },
    { "vo/ravenholm/monk_rant01.wav", 6.4 },
    { "vo/ravenholm/monk_rant08.wav", 7 },
    { "vo/ravenholm/monk_rant07.wav", 7 },
    { "vo/ravenholm/monk_rant06.wav", 8.8 },
    { "vo/ravenholm/monk_rant05.wav", 8 },
    { "vo/ravenholm/monk_rant04.wav", 6.6 },

}

local mediumIntensity = {
    { "vo/ravenholm/monk_kill01.wav", 1.6 },
    { "vo/ravenholm/monk_kill02.wav", 1.8 },
    { "vo/ravenholm/monk_kill03.wav", 1.8 },
    { "vo/ravenholm/monk_kill04.wav", 2.5 },
    { "vo/ravenholm/monk_kill05.wav", 2 },
    { "vo/ravenholm/monk_kill06.wav", 1.6 },
    { "vo/ravenholm/monk_kill07.wav", 2.2 },
    { "vo/ravenholm/monk_kill09.wav", 1.6 },
    { "vo/ravenholm/monk_kill10.wav", 2.4 },
    { "vo/ravenholm/monk_kill11.wav", 2.6 },
    { "vo/ravenholm/monk_rant22.wav", 9 },
    { "vo/ravenholm/monk_rant21.wav", 6.5 },
    { "vo/ravenholm/monk_rant20.wav", 6.5 },
    { "vo/ravenholm/monk_rant19.wav", 7 },
    { "vo/ravenholm/monk_rant18.wav", 4 },
    { "vo/ravenholm/monk_rant17.wav", 4.5 },
    { "vo/ravenholm/monk_rant16.wav", 5.5 },
    { "vo/ravenholm/monk_rant15.wav", 6.5 },
    { "vo/ravenholm/monk_rant14.wav", 9 },
    { "vo/ravenholm/monk_rant13.wav", 12 },
    { "vo/ravenholm/monk_rant12.wav", 6.6 },
    { "vo/ravenholm/monk_rant11.wav", 5.5 },
    { "vo/ravenholm/monk_rant10.wav", 5 },
    { "vo/ravenholm/monk_rant09.wav", 11.8 },
    { "vo/ravenholm/monk_rant03.wav", 8.6 },
    { "vo/ravenholm/monk_rant02.wav", 6.3 },
    { "vo/ravenholm/monk_rant01.wav", 6.4 },
    { "vo/ravenholm/wrongside_mendways.wav", 3 },
    { "vo/ravenholm/wrongside_seekchurch.wav", 2.5 },
    { "vo/ravenholm/wrongside_mendways.wav", 10 },
    { "vo/ravenholm/monk_mourn03.wav", 3.7 },
    { "vo/ravenholm/monk_mourn04.wav", 5.2 },
    { "vo/ravenholm/monk_mourn05.wav", 5.2 },
    { "vo/ravenholm/monk_mourn06.wav", 2.1 },
    { "vo/ravenholm/monk_mourn07.wav", 2.1 },
    { "vo/ravenholm/pyre_anotherlife.wav", 4.2 },
    { "vo/ravenholm/shotgun_hush.wav", 0.8 },
    { "vo/ravenholm/shotgun_catch.wav", 3 },
    { "vo/ravenholm/shotgun_theycome.wav", 1.1 },

}

local highIntensity = {
    { "vo/ravenholm/madlaugh01.wav", 2.8 },
    { "vo/ravenholm/madlaugh02.wav", 2.8 },
    { "vo/ravenholm/madlaugh03.wav", 5.8 },

}

local superHighIntensity = {
    { "vo/ravenholm/exit_salvation.wav", 11 },

}

-- how epic is the player being rn?
function SWEP:DoEpicness( amount )
    if not amount then return end
    local inHighIntensity = self.inHighIntensity or 0
    local epicness = self.epicness or 0
    self.epicness = epicness + amount
    -- dont interrupt the rants
    if amount >= 100 and inHighIntensity < CurTime() then
        self.nextEpicLine = CurTime() + 0.1

    end

    timer.Simple( 0.01, function()
        if not IsValid( self ) then return end
        local owner = self:GetOwner()

        if not IsValid( owner ) then return end

        filter = RecipientFilter()
        for _, ply in player.Iterator() do
            if ply == owner then continue end
            if ply:GetObserverTarget() == owner and ply:GetObserverMode() == OBS_MODE_IN_EYE then continue end
            filter:AddPlayer( ply )

        end

        local scale = 0.1 + amount / 8

        local flash = EffectData()
        flash:SetScale( scale )
        flash:SetOrigin( owner:GetShootPos() )
        flash:SetEntity( owner )
        util.Effect( "eff_huntersglee_divinelight", flash, true, filter )

        local nextEpicZzarp = self.nextEpicZzarp or 0
        if nextEpicZzarp > CurTime() then return end
        self.nextEpicZzarp = CurTime() + math.Rand( .1, .5 )

        local startingDir = vector_up + VectorRand()
        startingDir:Normalize()

        local hitTr = termHunt_ElectricalArcEffect( owner, owner:WorldSpaceCenter(), -vector_up, math.Rand( 0.5, 1 ), startingDir, 1000 )
        local zzarpedEnt = hitTr.Entity

        if not IsValid( zzarpedEnt ) then return end
        zzarpedEnt:Fire( "IgniteLifetime", 1 )

    end )
end

function SWEP:EpicnessThink()
    local epic = self.epicness or 0
    local targetEpicness = 0
    if epic ~= self.oldEpic then
        self.oldEpic = epic
        local owner = self:GetOwner()
        owner:SetNW2Int( "divinechosenhowepictheybeing", self.epicness )

    end

    local nextEpicLine = self.nextEpicLine or 0
    if nextEpicLine > CurTime() then return end

    local inHighIntensity = self.inHighIntensity or 0

    local theSound = ""
    if inHighIntensity < CurTime() and epic >= 100 then
        if epic >= 225 then
            -- once we do this line, activate a period of faster regen, and ranting
            huntersGlee_Announce( { self:GetOwner() }, 500, 8, "SHOW THEM" )
            local result = table.Random( superHighIntensity )
            theSound = result[1]
            self.nextEpicLine = CurTime() + result[2]
            self.inHighIntensity = CurTime() + epic / 8
            targetEpicness = 0
        -- not high enough, just rant
        elseif epic >= 100 then
            local result = table.Random( highIntensity )
            theSound = result[1]
            self.nextEpicLine = CurTime() + result[2]
            targetEpicness = 10

        end
    -- just do rants when we did a salvation
    elseif inHighIntensity > CurTime() then
        local result = table.Random( justRants )
        theSound = result[1]
        self.nextEpicLine = CurTime() + result[2] * 1.3
        targetEpicness = 0

    elseif epic >= 10 then
        local result = table.Random( mediumIntensity )
        theSound = result[1]
        self.nextEpicLine = CurTime() + result[2] * 1.8
        targetEpicness = 0

    else
        local result = table.Random( ambientEpicness )
        theSound = result[1]
        self.nextEpicLine = CurTime() + result[2] * 3
        targetEpicness = 0

    end

    local owner = self:GetOwner()

    self:SpeakLine( theSound, self, owner )

    self.epicness = targetEpicness

end

function SWEP:SpeakLine( theLine, speaker, speakerEcho )
    if theLine == self.oldSpokenLine then return end

    if self.epicSound1 then
        self.epicSound1:Stop()

    end
    if self.epicSound2 then
        self.epicSound2:Stop()

    end

    filterEveryone:AddAllPlayers()

    local pitch = math.random( 85, 95 )

    -- normal dsp
    self.epicSound1 = CreateSound( speaker, theLine, filterEveryone )
    self.epicSound1:SetSoundLevel( 95 )
    self.epicSound1:PlayEx( 1, pitch )

    -- w/echo DSP and 150 levl
    timer.Simple( 0.08, function()
        if not IsValid( speakerEcho ) then return end
        local emitter = self
        if not IsValid( self ) then
            emitter = speakerEcho

        end
        emitter.epicSound2 = CreateSound( speakerEcho, theLine, filterEveryone )
        emitter.epicSound2:SetDSP( 25 )
        emitter.epicSound2:SetSoundLevel( 150 )
        emitter.epicSound2:PlayEx( 0.4, pitch + -10 )

    end )

    self.oldSpokenLine = theLine

end

hook.Add( "OnDamagedByExplosion", "ChosenNoRinging", function( ply )
    if ply:HasWeapon( "termhunt_divine_chosen" ) then return true end

end )

hook.Add( "PlayerDeath", "glee_chosendeathsound", function( ply )
    local theWep = ply:GetWeapon( "termhunt_divine_chosen" )
    if not IsValid( theWep ) then return end

    theWep:ShutDown()

    if theWep.epicness < 50 then return end

    local placeholder = ents.Create( "prop_physics" )
    placeholder:SetPos( ply:GetPos() )
    placeholder:SetModel( "models/Gibs/HGIBS.mdl" )
    placeholder:Spawn()
    placeholder:GetPhysicsObject():EnableMotion( false )
    placeholder:SetNotSolid( true )
    placeholder:SetNoDraw( true )
    SafeRemoveEntityDelayed( placeholder, 10 )

    local placeholderEcho = ents.Create( "prop_physics" )
    placeholderEcho:SetPos( ply:GetPos() )
    placeholderEcho:SetModel( "models/Gibs/HGIBS.mdl" )
    placeholderEcho:Spawn()
    placeholderEcho:GetPhysicsObject():EnableMotion( false )
    placeholderEcho:SetNotSolid( true )
    placeholderEcho:SetNoDraw( true )
    SafeRemoveEntityDelayed( placeholderEcho, 10 )

    theWep:SpeakLine( "vo/ravenholm/monk_death07.wav", placeholder, placeholderEcho )

end )
