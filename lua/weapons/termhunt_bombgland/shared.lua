SWEP.PrintName = "Bomb gland"
SWEP.Author = "Straw W Wagen"
SWEP.Purpose = "Drop bombs, Left click for small bomb, Reload for big bomb.\nDetonate oldest bomb with right click"

SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.Spawnable = true
SWEP.Category = "Hunter's Glee"

SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.Weight = 1

SWEP.HoldType = "normal"
SWEP.MassForBomb = 14
SWEP.AccumulatedMass = 0
SWEP.OldBombBeats = 0
SWEP.UnstableBombCount = 4
SWEP.Instability = 0
SWEP.MaxInstability = 3

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

if CLIENT then
    resource.AddFile( "materials/entities/termhunt_bombgland.png" )

end

function SWEP:Initialize()
    self:DrawShadow( false )
    self:SetHoldType( "normal" )

    if not SERVER then return end
    self.Bombs = 0
    self.BombTable = {}

end

function SWEP:DrawWorldModel()                          end

function SWEP:CustomAmmoDisplay()

    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.SecondaryAmmo = nil
    self.AmmoDisplay.PrimaryAmmo = nil
    self.AmmoDisplay.PrimaryClip = self:GetBombs()

    return self.AmmoDisplay

end

function SWEP:GetBombs()
    if CLIENT then
        return self:GetNWInt( "bombgland_bombs", 0 )

    end
    if SERVER then
        return self.Bombs

    end
end

function SWEP:SetBombs( bombs )
    if not SERVER then return end
    self.Bombs = bombs

    self:SetNWInt( "bombgland_bombs", self.Bombs )

end

function SWEP:PunchValid()
    self:GetOwner():ViewPunch( Angle( -2,0,0 ) )

end

function SWEP:PunchInvalid()
    self:GetOwner():ViewPunch( Angle( 2,0,0 ) )

end

-- when it goes from on the ground to on the player
function SWEP:Equip()

    if not SERVER then return end

    local dmgHookName = self:GetOwner():GetCreationID() .. "bombGlandUnstableDamage"

    local hookBreak = function()
        hook.Remove( "EntityTakeDamage", dmgHookName )
    end

    hook.Add( "EntityTakeDamage", dmgHookName, function( target, dmg )
        if not IsValid( self ) then hookBreak() return end
        local owner = self:GetOwner()
        if not IsValid( owner ) then hookBreak() return end
        if not IsValid( owner:GetWeapon( self:GetClass() ) ) then hookBreak() end

        if target != owner then return end
        if owner:Health() <= 0 then return end

        if dmg:GetDamage() >= owner:Health() then
            self:BoomUser()
            return

        end

        if self:GetBombs() < self.UnstableBombCount then return end

        local add = 1
        if dmg:GetDamage() > 20 then
            add = 2
        end

        self.Instability = self.Instability + add

        local pit = 20 + ( self.Instability * 10 )

        if self.Instability >= self.MaxInstability then
            self:BoomUser()
            return

        end

        owner:EmitSound( "npc/headcrab_poison/ph_wallhit2.wav", 80, pit )
        owner:EmitSound( "physics/flesh/flesh_squishy_impact_hard4.wav", 80, pit + 20 )

        timer.Simple( 3, function()
            if not IsValid( self ) then return end
            self.Instability = math.Clamp( self.Instability + -1, 0, math.huge )
        end )

    end )

    local name = self:GetCreationID() .. "bombGlandManageBombsTimer"

    timer.Create( name, 0.05, 0, function()
        if not IsValid( self ) or not IsValid( self:GetOwner() ) or self:GetOwner():Health() <= 0 or not IsValid( self:GetOwner():GetActiveWeapon() ) then timer.Stop( name ) return end
        local oldBeats = self.OldBombBeats
        local beats = self:GetOwner().realHeartBeats

        if beats == oldBeats then return end

        self.OldBombBeats = beats

        self.AccumulatedMass = self.AccumulatedMass + 1

        if self.AccumulatedMass < self.MassForBomb then return end

        self.AccumulatedMass = 0
        self:SetBombs( self:GetBombs() + 1 )

        local pit = 30 + ( self:GetBombs() * 5 )
        self:EmitSound( "ambient/levels/canals/toxic_slime_gurgle5.wav", 65, pit, 1, CHAN_STATIC )

    end )
end

function SWEP:BoomUser()

    if self:GetBombs() < 1 then return end

    if GAMEMODE.Bleed then
        GAMEMODE:Bleed( self:GetOwner(), 50 )
        GAMEMODE:Bleed( self:GetOwner(), 50 )
    end

    local worldSpaceC = self:GetOwner():WorldSpaceCenter()

    for _ = 1, 4 + ( self:GetBombs() * 3 ) do
        self:GetOwner():EmitSound( "npc/antlion_grub/squashed.wav", 100, math.random( 50, 150 ), 1, CHAN_STATIC )

    end

    local explode = ents.Create( "env_explosion" )
    explode:SetPos( Vector( worldSpaceC.x, worldSpaceC.y, worldSpaceC.z ) )
    explode:SetOwner( self:GetOwner() )
    explode:Spawn()
    explode:SetKeyValue( "iMagnitude", math.Clamp( self:GetBombs(), 0, self.UnstableBombCount * 2 ) * 70 )
    explode:Fire( "Explode", 0, 0 )

    self:SetBombs( 0 )

end

function SWEP:PrimaryAttack()
    if not SERVER then return end

    if ( self.nextPrimaryAttack or 0 ) > CurTime() then return end
    self.nextPrimaryAttack = CurTime() + 0.25

    local owner = self:GetOwner()

    if self:GetBombs() < 1 then
        owner:EmitSound( "physics/flesh/flesh_impact_hard3.wav", 55, 160 )
        self:PunchInvalid()
        return
    end
    self:PunchValid()
    self:SetBombs( math.Clamp( self:GetBombs() + -1, 0, math.huge ) )
    owner:EmitSound( "npc/barnacle/barnacle_crunch2.wav", 75, 100 )

    if GAMEMODE.Bleed then
        GAMEMODE:Bleed( owner, 1 )
    end

    timer.Simple( 0.25, function()
        if not IsValid( self ) then return end
        if GAMEMODE.Bleed then
            GAMEMODE:Bleed( owner, 3 )
        end
        local small = ents.Create( "termhunt_bombsmall" )
        small:SetCreator( ply )
        small:SetPos( owner:WorldSpaceCenter() )
        small:SetAngles( AngleRand() )
        small:Spawn()
        small:Activate()
        small:SetVelocity( owner:GetVelocity() )

        small:EmitSound( "npc/barnacle/neck_snap1.wav", 75, 120 )

        self:AddToDetList( small )

    end )

end

function SWEP:Reload()
    if not SERVER then return end

    if ( self.nextReloadAttack or 0 ) > CurTime() then return end
    self.nextReloadAttack = CurTime() + 1

    local owner = self:GetOwner()

    if self:GetBombs() < self.UnstableBombCount then
        self:PunchInvalid()
        owner:EmitSound( "physics/flesh/flesh_impact_hard3.wav", 55, 80 )
        return
    end
    self:PunchValid()
    self:SetBombs( math.Clamp( self:GetBombs() + -self.UnstableBombCount, 0, math.huge ) )
    owner:EmitSound( "npc/barnacle/barnacle_crunch2.wav", 75, 50 )

    if GAMEMODE.Bleed then
        GAMEMODE:Bleed( owner, 4 )
    end

    timer.Simple( 1, function()
        if not IsValid( self ) then return end
        if GAMEMODE.Bleed then
            GAMEMODE:Bleed( owner, 16 )
        end
        local big = ents.Create( "termhunt_bombbig" )
        big:SetCreator( ply )
        big:SetPos( owner:WorldSpaceCenter() )
        big:SetAngles( AngleRand() )
        big:Spawn()
        big:Activate()

        big:SetVelocity( owner:GetVelocity() )

        self:AddToDetList( big )

        big:EmitSound( "npc/barnacle/neck_snap1.wav", 75, 60 )

    end )
end

function SWEP:AddToDetList( bomb )
    self:CleanupDetonationList()
    table.insert( self.BombTable, bomb )

end

function SWEP:CleanupDetonationList()
    if not SERVER then return end
    for index, currBomb in ipairs( self.BombTable ) do
        if not IsValid( currBomb ) then
            table.remove( self.BombTable, index )

        end
    end
end

function SWEP:DetonateOldestBomb()
    if not SERVER then return end
    self:CleanupDetonationList()
    local oldestBomb = table.remove( self.BombTable, 1 )

    if not IsValid( oldestBomb ) then
        self:PunchInvalid()
        self:GetOwner():EmitSound( "physics/flesh/flesh_impact_hard5.wav", 55, 80 )
        return
    end

    self:PunchValid()
    self:GetOwner():EmitSound( "weapons/bugbait/bugbait_squeeze3.wav", 55, 140 )

    oldestBomb:Fire( "IgniteLifetime", 10 )
    oldestBomb:TakeDamage( oldestBomb.MaxHealth / 1.5, self:GetOwner(), self )

end

function SWEP:SecondaryAttack()
    if ( self.nextSecondaryAttack or 0 ) > CurTime() then return end
    self.nextSecondaryAttack = CurTime() + 0.1
    self:DetonateOldestBomb()

end

function SWEP:OnRemove()

end

local gtfo = Vector( 1, 1, 1 ) * 65000

function SWEP:GetViewModelPosition( _, ang )
    return gtfo,ang
end

function SWEP:OnDrop()
    SafeRemoveEntity( self )

end

function SWEP:Holster()
    return true

end