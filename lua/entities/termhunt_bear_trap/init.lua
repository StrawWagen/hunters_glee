AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

resource.AddFile( "sound/beartrap.wav" )
resource.AddFile( "models/stiffy360/C_BearTrap.dx80.vtx" )
resource.AddFile( "models/stiffy360/C_BearTrap.dx90.vtx" )
resource.AddFile( "models/stiffy360/c_beartrap.mdl" )
resource.AddFile( "models/stiffy360/C_BearTrap.sw.vtx" )
resource.AddFile( "models/stiffy360/c_beartrap.vvd" )
resource.AddFile( "models/stiffy360/C_BearTrap.xbox.vtx" )
resource.AddFile( "models/stiffy360/BearTrap.dx80.vtx" )
resource.AddFile( "models/stiffy360/BearTrap.dx90.vtx" )
resource.AddFile( "models/stiffy360/beartrap.mdl" )
resource.AddFile( "models/stiffy360/BearTrap.phy" )
resource.AddFile( "models/stiffy360/BearTrap.sw.vtx" )
resource.AddFile( "models/stiffy360/beartrap.vvd" )
resource.AddFile( "models/stiffy360/BearTrap.xbox.vtx" )
resource.AddFile( "materials/models/freeman/beartrap_specular.vtf" )
resource.AddFile( "materials/models/freeman/beartrap_diffuse.vtf" )
resource.AddFile( "materials/models/freeman/trap_dif.vmt" )
resource.AddFile( "materials/models/models/stiffy360/C_BearTrap.dx80.vtx" )
resource.AddFile( "materials/models/models/stiffy360/C_BearTrap.dx90.vtx" )
resource.AddFile( "materials/models/models/stiffy360/c_beartrap.mdl" )
resource.AddFile( "materials/models/models/stiffy360/C_BearTrap.sw.vtx" )
resource.AddFile( "materials/models/models/stiffy360/c_beartrap.vvd" )
resource.AddFile( "materials/models/models/stiffy360/C_BearTrap.xbox.vtx" )
resource.AddFile( "materials/models/models/stiffy360/BearTrap.dx80.vtx" )
resource.AddFile( "materials/models/models/stiffy360/BearTrap.dx90.vtx" )
resource.AddFile( "materials/models/models/stiffy360//beartrap.mdl" )
resource.AddFile( "materials/models/models/stiffy360/BearTrap.phy" )
resource.AddFile( "materials/models/models/stiffy360/BearTrap.sw.vtx" )
resource.AddFile( "materials/models/models/stiffy360/beartrap.vvd" )
resource.AddFile( "materials/models/models/stiffy360/BearTrap.xbox.vtx" )
resource.AddFile( "materials/icon_beartrap.vmt" )
resource.AddFile( "materials/icon_beartrap.vtf" )


local MEMORY_BREAKABLE = 4

function ENT:Initialize()
    self:SetModel( "models/stiffy360/beartrap.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    if self:GetPhysicsObject():IsValid() then
        self:GetPhysicsObject():EnableMotion( false )
    end

    self:SetSequence( "ClosedIdle" )
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self:SetSequence( "OpenIdle" )
        self:EmitSound( "physics/metal/metal_box_strain1.wav", 65, 200 )

    end )
    self:SetUseType( CONTINUOUS_USE )
    self.dmg = 0

    if SERVER then
        self.terminatorHunterInnateReaction = function()
            return MEMORY_BREAKABLE
        end
    end

end

function ENT:IsReadyToSpring()
    if self:GetSequence() ~= 0 and self:GetSequence() ~= 2 then return true end
    return false

end

function ENT:Snap()
    self:SetPlaybackRate( 1 )
    self:SetCycle( 0 )
    self:SetSequence( "Snap" )
    timer.Simple( 0.05, function()
        if not IsValid( self ) then return end
        self:SetSequence( "ClosedIdle" )
        self:EmitSound( "beartrap.wav", 90 )
        self:EmitSound( "physics/metal/metal_box_strain1.wav", 65, 200 )

    end )
end

local function DoBleed( ent )
   if not IsValid( ent ) then
      return
   end

   local offset = VectorRand() * 50
   offset.z = -100

   util.Decal( "Blood", ent:WorldSpaceCenter(), ent:WorldSpaceCenter() + offset, ent )

end

local keysToHurt = {
    IN_JUMP,
    IN_FORWARD,
    IN_BACK,
    IN_MOVELEFT,
    IN_MOVERIGHT,

}

function ENT:Touch( toucher )
    if not IsValid( toucher ) then return end
    if self:IsReadyToSpring() then

        local attacker = self:GetCreator() or game.GetWorld()
        local toucherId = toucher:GetCreationID()
        local timerName = "termhunt_beartrap_damage_" .. toucherId

        local timerObliterate = function()
            timer.Remove( timerName )
            if not IsValid( toucher ) then return end
            toucher.bearTrapped = nil

        end

        if toucher:IsPlayer() then

            self:Snap()

            local dmg = DamageInfo()
            dmg:SetAttacker( attacker )
            dmg:SetInflictor( self )
            dmg:SetDamage( 6 )
            dmg:SetDamageType( DMG_SLASH )

            for _ = 1, 5 do
                DoBleed( toucher )
            end

            toucher.bearTrapped = true

            local Hurt = function( toucher )
                toucher:TakeDamageInfo( dmg )
                DoBleed( toucher )

                if GAMEMODE.GivePanic then
                    GAMEMODE:GivePanic( toucher, 18 )

                end
            end

            timer.Create( timerName, 8, 0, function()
                if not IsValid( toucher ) then timerObliterate() return end
                if not IsValid( self ) then timerObliterate() return end
                if not toucher.bearTrapped then timerObliterate() return end
                if toucher:Health() <= 0 then timerObliterate() return end

                Hurt( toucher )

            end )

            local hookName = "termhunt_beartrapblockmove_", toucherId

            local hookObliterate = function()
                hook.Remove( "SetupMove", hookName )
                toucher.bearTrapped = nil

            end

            hook.Add( "SetupMove", hookName, function( ply, moveData, _ )
                if not IsValid( toucher ) then hookObliterate() return end
                if not IsValid( self ) then hookObliterate() return end
                if ply ~= toucher then return end
                if not toucher.bearTrapped then hookObliterate() return end
                if toucher:Health() <= 0 then hookObliterate() return end

                moveData:SetOrigin( self:GetPos() )

                if ( self.nextHurt or 0 ) > CurTime() then return end

                for _, keyThatCouldBeDown in ipairs( keysToHurt ) do
                    if moveData:KeyDown( keyThatCouldBeDown ) then
                        self.nextHurt = CurTime() + 0.25
                        Hurt( toucher )
                        break
                    end
                end
            end )
        elseif toucher.isTerminatorHunterBased then
            toucher.terminatorStucker = self

            timer.Create( timerName, 0.05, 0, function()
                if not IsValid( toucher ) then timerObliterate() return end
                if not IsValid( self ) then timerObliterate() return end
                if toucher:Health() <= 0 then timerObliterate() return end
                if toucher:GetPos():DistToSqr( self:GetPos() ) < 10^2 then return end
                toucher:SetPos( self:GetPos() )

            end )

            self:Snap()

            timer.Simple( 4, function()
                if not IsValid( self ) then return end
                self:EmitSound( "doors/vent_open1.wav", 90, 110, 1, CHAN_STATIC )
                self:PickUp()

            end )

            local dmg = DamageInfo()
            dmg:SetAttacker( attacker )
            dmg:SetInflictor( self )
            dmg:SetDamage( 100 )
            dmg:SetDamageType( DMG_SLASH )
            toucher:TakeDamageInfo( dmg )

        else
            self:Snap()

            local dmg = DamageInfo()
            dmg:SetAttacker( attacker )
            dmg:SetInflictor( self )
            dmg:SetDamage( 100 )
            dmg:SetDamageType( DMG_SLASH )
            dmg:SetDamageForce( vector_up * 500 )
            toucher:TakeDamageInfo( dmg )

        end
    end
end

function ENT:Use( user )
    if not IsValid( user ) then return end
    if user:IsPlayer() and user:GetEyeTrace().Entity == self then
        local step = 40
        if self:IsReadyToSpring() or user.bearTrapped then
            step = 7
        end
        local progBarStatus = generic_WaitForProgressBar( user, "termhunt_weapon_beartrap_disarm", 0.25, step )

        if isnumber( progBarStatus ) and progBarStatus <= step and progBarStatus ~= self.oldplaceStatus then
            self:EmitSound( "physics/metal/metal_box_impact_hard3.wav", 65, 90 )

        end
        self.oldplaceStatus = progBarStatus

        if progBarStatus < 100 then return end

        self:PickUp()
    end
    if user:IsNextBot() then
        self:PickUp()

    end
end

function ENT:PickUp()
    local beartrap = ents.Create( "termhunt_weapon_beartrap" )
    beartrap:SetPos( self:GetPos() )
    beartrap:SetAngles( self:GetAngles() )
    beartrap:Spawn()

    self:EmitSound( "doors/vent_open2.wav", 65, 180, 0.8 )

    SafeRemoveEntity( self )

end

function ENT:OnTakeDamage( dmg )
    self.dmg = self.dmg + dmg:GetDamage()
    if self.dmg < 25 then return end
    if self:IsReadyToSpring() then
        self:Snap()

    elseif self.dmg > 80 and dmg:IsDamageType( DMG_CLUB ) then
        self:EmitSound( "doors/vent_open1.wav", 90, 110, 1, CHAN_STATIC )
        self:PickUp()

    end
end