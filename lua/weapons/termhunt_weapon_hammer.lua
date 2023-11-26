-- SEE THIS ADDON FOR ORIGINAL CODE
-- https://steamcommunity.com/sharedfiles/filedetails/?id=1318285072
-- it looks like buzzofwar took it down and someone else reuploaded it
-- buzz commented on that upload, may 1st 2023 "Huh i lost the files to this an extremely long time ago"

-----------------------------------------Updated 3.0 9/20/2014--------------------------------------------------|
--Buzzofwar-- Please do not steal or copy this! I  put much effort and time into perfecting it------------------|
----------------------------------------------------------------------------------------------------------------|
------------------------------// General Settings \\------------------------------------------------------------|
SWEP.Author             = "Buzzofwar + Straw W Wagen"                           -- Your name.
SWEP.Contact             = "1318285072"                          -- How People could contact you.
SWEP.Base                 = "weapon_base"                       -- What base should the swep be based on.
SWEP.ViewModel             = "models/weapons/v_crowbar.mdl"     -- The viewModel, the model you see when you are holding it.
SWEP.WorldModel         = "models/weapons/w_buzzhammer.mdl"     -- The world model, The model you when it's down on the ground.
SWEP.HoldType             = "melee"                             -- How the swep is hold Pistol smg grenade melee.
SWEP.PrintName             = "Nailer"                           -- your sweps name.
SWEP.Category             = "Hunter's Glee"                     -- Make your own category for the swep.
SWEP.Instructions         = "Nail stuff together!"              -- How do people use your swep.
SWEP.Purpose             = ""                                   -- What is the purpose with this.
SWEP.ViewModelFlip         = true                               -- If the model should be flipped when you see it.
SWEP.UseHands            = true                                 -- Weather the player model should use its hands.
SWEP.AutoSwitchTo         = true                                -- when someone walks over the swep, should it automatically change to your swep.
SWEP.Spawnable             = true                               -- Can everybody spawn this swep.
SWEP.AutoSwitchFrom     = true                                  -- Does the weapon get changed by other sweps if you pick them up.
SWEP.FiresUnderwater     = true                                 -- Does your swep fire under water.
SWEP.DrawCrosshair         = true                               -- Do you want it to have a crosshair.
SWEP.DrawAmmo             = true                                -- Does the ammo show up when you are using it.
SWEP.ViewModelFOV         = 0                                   -- How much of the weapon do you see.
SWEP.Weight             = 10                                     -- Chose the weight of the Swep.
SWEP.SlotPos             = 2                                    -- Decide which slot you want your swep do be in.
SWEP.Slot                 = 1                                   -- Decide which slot you want your swep do be in.
------------------------------\\ General Settings //------------------------------------------------------------|
----------------------------------------------------------------------------------------------------------------|
SWEP.Primary.Automatic             = true                       -- Do We Have To Click Or Hold Down The Click
SWEP.Primary.Ammo                 = "none"                      -- What Ammo Does This SWEP Use (If Melee Then Use None)   
SWEP.Primary.Damage             = 0                             -- How Much Damage Does The SWEP Do                         
SWEP.Primary.Spread                 = 0                         -- How Much Of A Spread Is There (Should Be Zero)
SWEP.Primary.NumberofShots         = 0                          -- How Many Shots Come Out (should Be Zero)
SWEP.Primary.Recoil             = 6                             -- How Much Jump After An Attack        
SWEP.Primary.ClipSize           = math.huge                            -- Size Of The Clip
SWEP.Primary.Delay                 = 0.8                        -- How longer Till Our Next Attack       
SWEP.Primary.Force                 = 0                          -- The Amount Of Impact We Do To The World 
SWEP.Primary.Distance             = 75                          -- How far can we reach?
SWEP.SwingSound           = "weapons/iceaxe/iceaxe_swing1.wav"  -- Sound we make when we swing
SWEP.NailedSound            = "hammer_hitnail"
----------------------------------------------------------------------------------------------------------------|
SWEP.Secondary.Automatic         = false                         -- Do We Have To Click Or Hold Down The Click
SWEP.Secondary.Ammo             = "none"                         -- What Ammo Does This SWEP Use (If Melee Then Use None)   
SWEP.Secondary.Damage             = 0                            -- How Much Damage Does The SWEP Do                         
SWEP.Secondary.Spread             = 0                            -- How Much Of A Spread Is There (Should Be Zero)
SWEP.Secondary.NumberofShots     = 0                             -- How Many Shots Come Out (should Be Zero)
SWEP.Secondary.Recoil             = 6                            -- How Much Jump After An Attack        
SWEP.Secondary.ClipSize            = 0                           -- Size Of The Clip
SWEP.Secondary.Delay             = 1                             -- How longer Till Our Next Attack       
SWEP.Secondary.Force             = 0                             -- The Amount Of Impact We Do To The World 
SWEP.Secondary.Distance         = 75                             -- How far can we reach?
SWEP.SecSwingSound                = ""                           -- Sound we make when we swing
SWEP.SecWallSound                 = ""                           -- Sound when we hit something 
----------------------------------------------------------------------------------------------------------------|

if SERVER then
    -- these hit sounds are from barricade SWEP
    -- https://steamcommunity.com/sharedfiles/filedetails/?id=2953413221
    resource.AddFile( "sound/hammer/hit_nail01.wav" )
    resource.AddFile( "sound/hammer/hit_nail02.wav" )
    resource.AddFile( "sound/hammer/hit_nail03.wav" )
    resource.AddFile( "sound/hammer/hit_nail04.wav" )

    resource.AddFile( "models/weapons/w_buzzhammer.dx80.vtx" )
    resource.AddFile( "models/weapons/w_buzzhammer.dx90.vtx" )
    resource.AddFile( "models/weapons/w_buzzhammer.mdl" )
    resource.AddFile( "models/weapons/w_buzzhammer.phy" )
    resource.AddFile( "models/weapons/w_buzzhammer.sw.vtx" )
    resource.AddFile( "models/weapons/w_buzzhammer.vvd" )

    resource.AddFile( "materials/models/weapons/cade_hammer.vmt" )
    resource.AddFile( "materials/models/weapons/cade_hammer.vtf" )
    resource.AddFile( "materials/models/weapons/hammer.vmt" )
    resource.AddFile( "materials/models/weapons/hammer.vtf" )
    resource.AddFile( "materials/models/weapons/hammer2.vmt" )
    resource.AddFile( "materials/models/weapons/hammer2.vtf" )

    resource.AddFile( "materials/entities/termhunt_weapon_hammer.png" )

end

sound.Add( {
    name = "hammer_hitnail",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 73,
    pitch = { 90, 110 },
    sound = {
        "hammer/hit_nail01.wav",
        "hammer/hit_nail02.wav",
        "hammer/hit_nail03.wav",
        "hammer/hit_nail04.wav",

    }
} )

local nailTooCloseDist = 4
local yellow = Color( 255, 220, 0, a )

function SWEP:DrawWeaponSelection(x,y,w,t,a)

    draw.SimpleText( "C", "creditslogo", x + w / 2, y, yellow, TEXT_ALIGN_CENTER )

end

function SWEP:Initialize()
    self:SetWeaponHoldType( self.HoldType )
    if SERVER then
        self:SetWeaponHoldType( self.HoldType )
        self:SetClip1( 20 )
    end
end

function SWEP:CustomAmmoDisplay()
    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Clip1()

    return self.AmmoDisplay

end

local gunCock = Sound( "items/ammo_pickup.wav" )

function SWEP:EquipAmmo( newOwner )
    local theirWeap = newOwner:GetWeapon( self:GetClass() )
    theirWeap:Charge()
    newOwner:EmitSound( gunCock, 60, math.random( 90, 110 ) )

end

function SWEP:Charge()
    self:SetClip1( self:Clip1() + 20 )

end

SWEP.Offset = {
    Pos = { Up = -5, Right = 1, Forward = 3, },
    Ang = { Up = 0, Right = 0, Forward = 90, }
}
function SWEP:DrawWorldModel()
    local pl = self:GetOwner()
    if IsValid( pl ) then
        local boneIndex = pl:LookupBone( "ValveBiped.Bip01_R_Hand" )
        if boneIndex then
            local pos, ang = pl:GetBonePosition( boneIndex )
            pos = pos + ang:Forward() *           self.Offset.Pos.Forward + ang:Right() * self.Offset.Pos.Right + ang:Up() * self.Offset.Pos.Up
            ang:RotateAroundAxis( ang:Up(),       self.Offset.Ang.Up )
            ang:RotateAroundAxis( ang:Right(),    self.Offset.Ang.Right )
            ang:RotateAroundAxis( ang:Forward(),  self.Offset.Ang.Forward )
            self:SetRenderOrigin( pos )
            self:SetRenderAngles( ang )
            self:DrawModel()
        end
    else
        self:SetRenderOrigin( nil )
        self:SetRenderAngles( nil )
        self:DrawModel()
    end
end
----------------------------------------------------------------------------------------------------------------|
function SWEP:OnRemove()
    return true
end
----------------------------------------------------------------------------------------------------------------|
function SWEP:Deploy()
    self:GetOwner():DrawViewModel(false)
    --self:EmitSound("")
    self:SendWeaponAnim(ACT_VM_DRAW)
end
----------------------------------------------------------------------------------------------------------------|
function SWEP:OnDrop()
    return true
end
----------------------------------------------------------------------------------------------------------------|
function SWEP:Holster()
    --self:EmitSound("")
    return true
end

function SWEP:Miss()
    local owner = self:GetOwner()

    self:EmitSound( self.SwingSound, 70, math.random( 90, 120 ) )

    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay / 2 )
    self:SendWeaponAnim(ACT_VM_MISSCENTER)
    owner:SetAnimation( PLAYER_ATTACK1 )

    local rnda = self.Primary.Recoil * -0.5
    local rndb = self.Primary.Recoil * math.Rand(-0.5, 1) 

    owner:ViewPunch( Angle( rnda,rndb,rnda ) ) 

end

function SWEP:BadHit( tr )
    if not SERVER then return end
    local owner = self:GetOwner()

    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay / 2 )
    self:SendWeaponAnim(ACT_VM_MISSCENTER)
    owner:SetAnimation( PLAYER_ATTACK1 )

    local rnda = self.Primary.Recoil * -0.5
    local rndb = self.Primary.Recoil * math.Rand(-0.5, 1) 

    if tr.HitPos:Distance( owner:GetShootPos() ) < self.Primary.Distance then
        local surfaceProperties = tr.SurfaceProps
        surfaceProperties = util.GetSurfaceData( surfaceProperties )
        if tr.Entity and surfaceProperties.material == MAT_FLESH then
            tr.Entity:TakeDamage( math.random( 25, 35 ), owner, self )
            tr.Entity:EmitSound( "Weapon_Crowbar.Melee_Hit", 75 )
            owner:EmitSound( "npc/zombie/claw_strike3.wav", 75, math.random( 120, 140 ), 1, CHAN_STATIC )

            rndb = rndb * 5
            rnda = rnda * 5

        else
            owner:EmitSound( "physics/metal/metal_grenade_impact_hard1.wav", 70, math.random( 150, 160 ), 1, CHAN_STATIC )

        end
    end

    owner:ViewPunch( Angle( rnda,rndb,rnda ) )

end

function SWEP:ValidEntityToNail( ent, physBone )
    if not IsValid( ent ) and not ent:IsWorld() then return end
    if ent:IsPlayer() then return end
    if ent:IsNextBot() then return end
    if ent:GetClass() == "gmod_glee_nail" then return end
    if ent.isDoorDamageListener then return end
    if SERVER then
        local validBone = util.IsValidPhysicsObject( ent, physBone )
        local isNpc = ent:IsNPC()

        if validBone and isNpc then
            -- manhack or something
        elseif validbone == true then -- wtf?
            return
        elseif isNpc then
            return
        end

    end
    if ent:GetClass() == "gmod_glee_nail" then return end

    return true

end

----------------------------------------------------------------------------------------------------------------|
function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay / 2 )
    if self:Clip1() <= 0 then
        if IsFirstTimePredicted() then
            owner:EmitSound( "weapons/pistol/pistol_empty.wav", 70 )

        end
        return false
    end

    local trace = owner:GetEyeTrace()
    self:SendWeaponAnim( ACT_VM_HITCENTER )

    local whatWeHit = trace.Entity

    -- Bail if invalid
    if whatWeHit:IsWorld() or not self:ValidEntityToNail( whatWeHit, trace.PhysicsBone ) then
        if not IsValid( whatWeHit ) then
            self:Miss()
        else
            self:BadHit( trace )
        end
        return false

    end

    local tr = {}
    tr.start = trace.HitPos
    tr.endpos = trace.HitPos + ( owner:GetAimVector() * 20.0 )
    tr.filter = { owner, whatWeHit }

    local nails = whatWeHit.huntersglee_breakablenails or {}
    table.Add( whatWeHit.filter, nails )

    local trTwo = util.TraceLine( tr )
    local secondHit = trTwo.Entity

    if IsFirstTimePredicted() then

        bullet = {}
        bullet.Num    = 1
        bullet.Src    = owner:GetShootPos()
        bullet.Dir    = owner:GetAimVector()
        bullet.Spread = Vector( 0, 0, 0 )
        bullet.Tracer = 0
        bullet.Force  = 10
        bullet.Distance = self.Primary.Distance
        bullet.Damage = 0
        owner:FireBullets( bullet )

        local nearNails = ents.FindInSphere( trace.HitPos, nailTooCloseDist * 10 )
        for _, nail in ipairs( nearNails ) do
            if nail:GetClass() ~= "gmod_glee_nail" then continue end
            local nailsPos = nail:GetPos() + nail:GetForward() * nail:GetModelRadius() / 2
            if nailsPos:DistToSqr( trace.HitPos ) > nailTooCloseDist^2 then continue end

            self:BadHit( trace )
            return false

        end

        if not self:ValidEntityToNail( secondHit, trTwo.PhysicsBone ) then
            if not IsValid( secondHit.Entity ) then
                self:Miss()
            else
                self:BadHit( trace )
            end
            return false

        end

        self:EmitSound( self.NailedSound )

        owner:SetAnimation( PLAYER_ATTACK1 )
        self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

        local rnda = self.Primary.Recoil * -2 
        local rndb = self.Primary.Recoil * math.random(-2, 3) 
        owner:ViewPunch( Angle( rnda,rndb,rnda ) )

        -- Client can bail now
        if ( CLIENT ) then return true end

        local vOrigin = trace.HitPos - ( owner:GetAimVector() * 8.0 )
        local vDirection = owner:GetAimVector():Angle()

        vOrigin = whatWeHit:WorldToLocal( vOrigin )

        -- Weld them!
        local constraint, nail = MakeNail( whatWeHit, secondHit, trace.PhysicsBone, trTwo.PhysicsBone, 50000, vOrigin, vDirection )
        if not constraint or not constraint:IsValid() then self:BadHit( trace ) return end

        self:SetClip1( math.Clamp( self:Clip1() + -1, 0, math.huge ) )

        if owner.AddCleanup then
            undo.Create( "Nail" )
            undo.AddEntity( constraint )
            undo.AddEntity( nail )
            undo.SetPlayer( owner )
            undo.Finish()

            owner:AddCleanup( "nails", constraint )
            owner:AddCleanup( "nails", nail )

        end

        return true
    end
end

function SWEP:SecondaryAttack()

end

local function nailUnregister( nail, ent )
    local creationId = nail:GetCreationID()
    -- idk how this is gonna end up with a nil value but whatever
    local nails = ent.huntersglee_breakablenails or {}
    if nails[ creationId ] then
        nails[ creationId ] = nil

    end

    if not IsValid( ent ) then return end

    if table.Count( nails ) <= 0 then
        ent.huntersglee_breakablenails = nil
        local class = ent:GetClass()
        -- only unlock doors!
        if class ==  "prop_door_rotating" then
            ent:Fire( "unlock", "", .01 )

        end
    else
        ent.huntersglee_breakablenails = nails

    end
end

local function registerNail( nail, ent )

    -- we dont have to track damage on the world
    if ent:IsWorld() then return end

    local nails = ent.huntersglee_breakablenails or {}
    local creationId = nail:GetCreationID()
    nails[ creationId ] = nail

    ent.huntersglee_breakablenails = nails

    nail.unregister = nailUnregister

    nail:CallOnRemove( "nailremoved", nailUnregister, ent )

    local class = ent:GetClass()
    if string.find( class, "door" ) then
        ent:Fire( "lock" )

    end
end


----------------------------------------------------------------------------------------------------------------|
function MakeNail( Ent1, Ent2, Bone1, Bone2, forcelimit, Pos, Ang )

    local constraint = constraint.Weld( Ent1, Ent2, Bone1, Bone2, forcelimit, false )

    if not constraint then return end

    constraint.Type = "Nail"
    constraint.Pos = Pos
    constraint.Ang = Ang

    Pos = Ent1:LocalToWorld( Pos )

    local nail = ents.Create( "gmod_glee_nail" )
    nail:Attach( Pos, Ang, Ent1, Bone1 )

    nail.realConstraint = constraint
    nail.mainEnt = Ent1
    nail.secondEnt = Ent2

    local constraintsNails = constraint.huntersGlee_nails or {}
    table.insert( constraintsNails, nail )
    constraint.huntersGlee_nails = constraintsNails

    constraint:CallOnRemove( "constraint_removeallmynails", function()
        if not constraint.huntersGlee_nails then return end
        for _, currNail in ipairs( constraint.huntersGlee_nails ) do
            if IsValid( currNail ) then
                nail:Break()
            end
        end
    end )

    nail:Spawn()
    nail:Activate()

    -- register nails so we can find them later and break them
    registerNail( nail, Ent1 )
    registerNail( nail, Ent2 )

    nail:UpdateConstraints()

    return constraint, nail

end

duplicator.RegisterConstraint( "Nail", MakeNail, "Ent1", "Ent2", "Bone1", "Bone2", "forcelimit", "Pos", "Ang" )




