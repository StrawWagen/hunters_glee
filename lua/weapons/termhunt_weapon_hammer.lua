-- SEE THIS ADDON FOR ORIGINAL CODE
-- https://steamcommunity.com/sharedfiles/filedetails/?id=1318285072
-- it looks like buzzofwar took it down and someone else reuploaded it
-- buzz commented on that upload, may 1st 2023 "Huh i lost the files to this an extremely long time ago"

-----------------------------------------Updated 3.0 9/20/2014--------------------------------------------------|
--Buzzofwar-- Please do not steal or copy this! I  put much effort and time into perfecting it------------------|
----------------------------------------------------------------------------------------------------------------|
------------------------------// General Settings \\------------------------------------------------------------|
SWEP.Author             = "Buzzofwar + Straw W Wagen"                           -- Your name.
SWEP.Contact             = "1318285072"                         -- How People could contact you.
SWEP.Base                 = "weapon_base"                       -- What base should the swep be based on.
SWEP.ViewModel             = "models/weapons/c_barricadeswep.mdl" -- The viewModel, the model you see when you are holding it. FROM BARRICADE SWEP
SWEP.WorldModel         = "models/weapons/w_buzzhammer.mdl"     -- The world model, The model you when it's down on the ground.
SWEP.HoldType             = "melee"                             -- How the swep is hold Pistol smg grenade melee.
SWEP.PrintName             = "Nailer"                           -- your sweps name.
SWEP.Category             = "Hunter's Glee"                     -- Make your own category for the swep.
SWEP.Instructions         = "Nail stuff together!"              -- How do people use your swep.
SWEP.Purpose             = ""                                   -- What is the purpose with this.
SWEP.ViewModelFlip         = false                               -- If the model should be flipped when you see it.
SWEP.UseHands            = true                                 -- Weather the player model should use its hands.
SWEP.AutoSwitchTo         = true                                -- when someone walks over the swep, should it automatically change to your swep.
SWEP.Spawnable             = true                               -- Can everybody spawn this swep.
SWEP.AutoSwitchFrom     = true                                  -- Does the weapon get changed by other sweps if you pick them up.
SWEP.FiresUnderwater     = true                                 -- Does your swep fire under water.
SWEP.DrawCrosshair         = true                               -- Do you want it to have a crosshair.
SWEP.DrawAmmo             = true                                -- Does the ammo show up when you are using it.
SWEP.Weight             = 10                                    -- Chose the weight of the Swep.
SWEP.SlotPos             = 2                                    -- Decide which slot you want your swep do be in.
SWEP.Slot                 = 1                                   -- Decide which slot you want your swep do be in.
------------------------------\\ General Settings //------------------------------------------------------------|
----------------------------------------------------------------------------------------------------------------|
SWEP.Primary.Automatic             = true                       -- Do We Have To Click Or Hold Down The Click
SWEP.Primary.Ammo                 = "GLEE_NAILS"                      -- What Ammo Does This SWEP Use (If Melee Then Use None)   
SWEP.Primary.Damage             = 30                             -- How Much Damage Does The SWEP Do                         
SWEP.Primary.Spread                 = 0                         -- How Much Of A Spread Is There (Should Be Zero)
SWEP.Primary.NumberofShots         = 0                          -- How Many Shots Come Out (should Be Zero)
SWEP.Primary.Recoil             = 6                             -- How Much Jump After An Attack        
SWEP.Primary.ClipSize           = -1                            -- Size Of The Clip
SWEP.Primary.DefaultClip         = 30                           -- How Many Bullets Do You Start With
SWEP.Primary.Delay                 = 0.8                        -- How longer Till Our Next Attack       
SWEP.Primary.Force                 = 0                          -- The Amount Of Impact We Do To The World 
SWEP.Primary.Distance             = 75                          -- How far can we reach?
SWEP.SwingSound           = "weapons/iceaxe/iceaxe_swing1.wav"  -- Sound we make when we swing
SWEP.NailedSound            = "hammer_hitnail"
----------------------------------------------------------------------------------------------------------------|
SWEP.Secondary.Automatic         = true                         -- Do We Have To Click Or Hold Down The Click
SWEP.Secondary.Ammo             = ""                         -- What Ammo Does This SWEP Use (If Melee Then Use None)   
SWEP.Secondary.Damage             = 0                            -- How Much Damage Does The SWEP Do                         
SWEP.Secondary.Spread             = 0                            -- How Much Of A Spread Is There (Should Be Zero)
SWEP.Secondary.NumberofShots     = 0                             -- How Many Shots Come Out (should Be Zero)
SWEP.Secondary.Recoil             = 6                            -- How Much Jump After An Attack        
SWEP.Secondary.ClipSize            = 0                           -- Size Of The Clip
SWEP.Secondary.Delay             = 0.8                             -- How longer Till Our Next Attack       
SWEP.Secondary.Force             = 0                             -- The Amount Of Impact We Do To The World 
SWEP.Secondary.Distance         = 75                             -- How far can we reach?
----------------------------------------------------------------------------------------------------------------|

-- hit sounds are from barricade SWEP
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2953413221
-- "sound/hammer/hit_nail01.wav"
-- "sound/hammer/hit_nail02.wav"
-- "sound/hammer/hit_nail03.wav"
-- "sound/hammer/hit_nail04.wav"

-- view model is also from barricade swep
-- "models/weapons/c_barricadeswep.phy"

local className = "termhunt_weapon_hammer"
if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, className, "vgui/hud/killicon/" .. className .. ".png" )

    function SWEP:HintPostStack()
        local owner = self:GetOwner()
        if not IsValid( owner ) then return end
        if not owner:GetNW2Bool( "gleenailer_nailattempted", false ) then return true, "PRIMARY ATTACK to nail things together." end
        if not owner:GetNW2Bool( "gleenailer_goodnailed", false ) then return true, "The nails have to go through something.\nYou can't nail a wall to itself, etc." end

    end

    language.Add( "GLEE_NAILS_ammo", "Nails" )

    function SWEP:CustomAmmoDisplay()
        local ammo = self:GetOwner():GetAmmoCount( self:GetPrimaryAmmoType() )
        return {
            Draw = true,
            PrimaryClip = ammo

        }
    end
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

local nailTooCloseDist = 3
local nailFindDist = nailTooCloseDist * 5

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    self:SetMaterial( "models/weapons/hammer.vmt" )

end

function SWEP:GetNailCount() -- get the amount of nails we have left
    local owner = self:GetOwner()
    if not IsValid( owner ) then return 0 end
    return owner:GetAmmoCount( self.Primary.Ammo )

end

SWEP.Offset = {
    Pos = { Up = -5, Right = 1, Forward = 3, },
    Ang = { Up = 0, Right = 0, Forward = 90, }
}
function SWEP:DrawWorldModel()
    local pl = self:GetOwner()
    if IsValid( pl ) and pl:GetActiveWeapon() == self then
        local boneIndex = pl:LookupBone( "ValveBiped.Bip01_R_Hand" )
        if boneIndex then
            local pos, ang = pl:GetBonePosition( boneIndex )
            pos = pos + ang:Forward() *           self.Offset.Pos.Forward + ang:Right() * self.Offset.Pos.Right + ang:Up() * self.Offset.Pos.Up
            ang:RotateAroundAxis( ang:Up(),       self.Offset.Ang.Up )
            ang:RotateAroundAxis( ang:Right(),    self.Offset.Ang.Right )
            ang:RotateAroundAxis( ang:Forward(),  self.Offset.Ang.Forward )
            self:SetRenderOrigin( pos )
            self:SetRenderAngles( ang )
            self:SetupBones()
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
    self:SendWeaponAnim( ACT_VM_DRAW )
end
----------------------------------------------------------------------------------------------------------------|
function SWEP:OnDrop()
    return true
end
----------------------------------------------------------------------------------------------------------------|
function SWEP:Holster()
    return true
end

function SWEP:Miss()
    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay / 2 )
    self:SendWeaponAnim( ACT_VM_MISSCENTER )
    if not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()

    self:EmitSound( self.SwingSound, 70, math.random( 90, 120 ) )

    owner:SetAnimation( PLAYER_ATTACK1 )
    if not SERVER then return end

    local rnda = self.Primary.Recoil * -0.5
    local rndb = self.Primary.Recoil * math.Rand( -0.5, 1 )

    owner:ViewPunch( Angle( rnda,rndb,rnda ) )

end

function SWEP:BadHit( tr )

    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay / 2 )
    self:SendWeaponAnim( ACT_VM_MISSCENTER )
    if not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()

    local rnda = self.Primary.Recoil * -0.5
    local rndb = self.Primary.Recoil * math.Rand( -0.5, 1 )

    bullet = {}
    bullet.Num    = 1
    bullet.Src    = owner:GetShootPos()
    bullet.Dir    = owner:GetAimVector()
    bullet.Spread = Vector( 0, 0, 0 )
    bullet.Tracer = 0
    bullet.Force  = 10
    bullet.Distance = self.Primary.Distance
    bullet.Damage = self.Primary.Damage + math.random( -5, 5 )
    owner:FireBullets( bullet )

    if tr.HitPos:DistToSqr( owner:GetShootPos() ) < self.Primary.Distance^2 then
        local surfaceProperties = tr.SurfaceProps
        surfaceProperties = util.GetSurfaceData( surfaceProperties )
        if tr.Entity and surfaceProperties and surfaceProperties.material == MAT_FLESH then
            tr.Entity:EmitSound( "Weapon_Crowbar.Melee_Hit", 75 )
            owner:EmitSound( "npc/zombie/claw_strike3.wav", 75, math.random( 120, 140 ), 1, CHAN_STATIC )

            rndb = rndb * 5
            rnda = rnda * 5

        else
            owner:EmitSound( "physics/metal/metal_grenade_impact_hard1.wav", 70, math.random( 150, 160 ), 1, CHAN_STATIC )

        end
    else
        self:EmitSound( self.SwingSound, 70, math.random( 90, 120 ), 1 )

    end
    owner:SetAnimation( PLAYER_ATTACK1 )

    if not SERVER then return end
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

function SWEP:GetNailPos( owner, trace )
    local currOffset = ( owner:GetAimVector() * math.random( 4, 6 ) )
    return trace.HitPos - currOffset

end

function SWEP:FindNails( pos )
    return ents.FindInSphere( pos, nailFindDist )

end

function SWEP:CanNailPos( owner, trace, hitting )
    local whatWeHit = trace.Entity

    -- Bail if invalid
    if whatWeHit:IsWorld() or self:GetNailCount() <= 0 or trace.HitPos:DistToSqr( owner:GetShootPos() ) > self.Primary.Distance^2 or not self:ValidEntityToNail( whatWeHit, trace.PhysicsBone ) then
        if hitting and not IsValid( whatWeHit ) and not ( whatWeHit and whatWeHit:IsWorld() ) then
            self:Miss()
        elseif hitting then
            self:BadHit( trace )
        end
        return false

    end

    local vOrigin = self:GetNailPos( owner, trace )
    local nearNails = self:FindNails( vOrigin )

    for _, nail in ipairs( nearNails ) do -- dont nail when there's already a nail there
        if nail:GetClass() ~= "gmod_glee_nail" then continue end
        local nailsPos = nail:GetPos()
        if nailsPos:DistToSqr( vOrigin ) > nailTooCloseDist^2 then continue end
        return false

    end
    return true, vOrigin

end


function SWEP:Swing( owner, noNail ) -- create nail or melee attack
    owner:LagCompensation( true )

    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay / 2 ) -- always do half delay

    local trace = owner:GetEyeTrace()

    owner:SetNW2Bool( "gleenailer_nailattempted", true )

    local can, vOrigin = self:CanNailPos( owner, trace, false )

    if not can then -- just damage it
        self:BadHit( trace )
        owner:LagCompensation( false )
        return false

    end

    local whatWeHit = trace.Entity

    local tr = {}
    tr.start = trace.HitPos
    tr.endpos = trace.HitPos + ( owner:GetAimVector() * 20.0 )

    tr.filter = { owner, whatWeHit }
    local nails = whatWeHit.huntersglee_breakablenails or {}
    table.Add( tr.filter, nails )

    local trTwo = util.TraceLine( tr )
    local secondHit = trTwo.Entity

    if noNail or not self:ValidEntityToNail( secondHit, trTwo.PhysicsBone ) then -- just damage it
        self:BadHit( trace )
        owner:LagCompensation( false )
        return false

    end

    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

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

    self:SendWeaponAnim( ACT_VM_HITKILL )
    owner:SetAnimation( PLAYER_ATTACK1 )
    if not IsFirstTimePredicted() then owner:LagCompensation( false ) return end

    self:EmitSound( self.NailedSound )

    owner:ViewPunch( Angle( -10,-10,-10 ) )

    -- for the hint
    owner:SetNW2Bool( "gleenailer_goodnailed", true )

    -- Client can bail now
    if CLIENT then owner:LagCompensation( false ) return true end

    local vDirection = owner:GetAimVector():Angle()

    vOrigin = whatWeHit:WorldToLocal( vOrigin )

    -- Weld them!
    local constraint, nail = MakeNail( whatWeHit, secondHit, trace.PhysicsBone, trTwo.PhysicsBone, 50000, vOrigin, whatWeHit:WorldToLocalAngles( vDirection ) )
    if not constraint or not constraint:IsValid() then self:BadHit( trace ) owner:LagCompensation( false ) return end

    self:TakePrimaryAmmo( 1 )

    if owner.AddCleanup then -- sandbox support
        undo.Create( "Nail" )
        undo.AddEntity( constraint )
        undo.AddEntity( nail )
        undo.SetPlayer( owner )
        undo.Finish()

        owner:AddCleanup( "nails", constraint )
        owner:AddCleanup( "nails", nail )

    end

    owner:LagCompensation( false )
    return true

end

function SWEP:PrimaryAttack( noNail )
    local owner = self:GetOwner()
    self:Swing( owner, noNail )

end

function SWEP:CanPrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return false end

    return true

end

function SWEP:SecondaryAttack() -- pull nails or melee attack
    if not self:CanPrimaryAttack() then return end
    if self:GetNextPrimaryFire() > CurTime() then return end

    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay / 2 ) -- always do half delay

    local owner = self:GetOwner()

    local trace = owner:GetEyeTrace()
    local vOrigin = self:GetNailPos( owner, trace )
    local nearNails = self:FindNails( vOrigin )

    local smallestDistSqr = nailFindDist^2
    local nearestNail
    for _, nail in ipairs( nearNails ) do
        if nail:GetClass() ~= "gmod_glee_nail" then continue end
        local distSqr = nail:GetPos():DistToSqr( vOrigin )
        if distSqr < smallestDistSqr then
            nearestNail = nail
            smallestDistSqr = distSqr

        end
    end

    if not IsValid( nearestNail ) then self:Swing( owner, true ) return end

    owner:LagCompensation( true )
    if SERVER then
        nearestNail:Break()
        nearestNail:EmitSound( "physics/metal/metal_box_impact_hard" .. math.random( 1, 3 ) .. ".wav", 70, math.random( 90, 120 ) )

    end

    self:SendWeaponAnim( ACT_VM_HITKILL )
    owner:SetAnimation( PLAYER_ATTACK1 )
    owner:LagCompensation( false )
    return true

end

local function nailUnregister( nail, ent )
    local creationId = nail:GetCreationID()

    if not IsValid( ent ) then return end

    -- idk how this is gonna end up with a nil value but whatever
    local nails = ent.huntersglee_breakablenails or {}
    if nails[ creationId ] then
        nails[ creationId ] = nil

    end

    if table.Count( nails ) <= 0 then
        ent.huntersglee_breakablenails = nil
        local class = ent:GetClass()
        -- only unlock doors!
        if class == "prop_door_rotating" then
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
function MakeNail( Ent1, Ent2, Bone1, Bone2, forcelimit, Pos, LocalAng )

    local theConstraint = constraint.Weld( Ent1, Ent2, Bone1, Bone2, forcelimit, false )

    if not theConstraint then return end

    theConstraint.Type = "Glee_Nail"
    theConstraint.Pos = Pos
    theConstraint.Ang = LocalAng

    Pos = Ent1:LocalToWorld( Pos )

    local nail = ents.Create( "gmod_glee_nail" )
    nail:Attach( Pos, Ent1:LocalToWorldAngles( LocalAng ), Ent1, Bone1, Ent2, theConstraint )

    nail:Spawn()
    nail:Activate()

    -- register nails so we can find them later and break them
    registerNail( nail, Ent1 )
    registerNail( nail, Ent2 )

    nail:UpdateConstraints()

    return theConstraint, nail

end

duplicator.RegisterConstraint( "Glee_Nail", MakeNail, "Ent1", "Ent2", "Bone1", "Bone2", "forcelimit", "Pos", "Ang" )


function SWEP:GetCapabilities()
    return CAP_INNATE_MELEE_ATTACK1
end
