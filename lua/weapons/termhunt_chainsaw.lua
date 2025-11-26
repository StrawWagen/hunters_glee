-- model is from this https://steamcommunity.com/sharedfiles/filedetails/?id=2841514992&searchtext=no+more+room+in+helli melee pack 
-- GIVE THEM LOVE AND AWARD THEM YAYAYAYAYA 
-- billions must award YLW

SWEP.Base = "weapon_base"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.PrintName = "Chainsaw"
SWEP.Author = "Boomertaters"
SWEP.Purpose = "AHHHH... FRESH MEAT"

SWEP.ViewModel = "models/weapons/tfa_nmrih/v_me_chainsaw.mdl"
SWEP.WorldModel = "models/weapons/tfa_nmrih/w_me_chainsaw.mdl"
SWEP.ViewModelFOV = 80
SWEP.UseHands = true
SWEP.HoldType = "physgun"
SWEP.ViewModelFlip = true

SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1

function SWEP:SetupDataTables()
    self:NetworkVar( "Bool", "IsRevvedUp" )
    self:NetworkVar( "Bool", "IsTurningOn" )
    self:NetworkVar( "Bool", "IsTurningOff" )
    self:NetworkVar( "Bool", "IsAttacking" )
end

function SWEP:Initialize()
    self:SetIsRevvedUp( false )
    self:SetIsTurningOn( false )
    self:SetIsTurningOff( false )
    self:SetIsAttacking( false )
    self:SetHoldType( self.HoldType )
    
    self.currentSoundPath = nil
end

function SWEP:KillSound()
    if self.loopSound and self.loopSound:IsPlaying() then
        self.loopSound:Stop()
    end
    
    self.loopSound = nil
    self.currentSoundPath = nil
end

function SWEP:GetDesiredSoundPath()
    if self:GetIsTurningOn() or self:GetIsTurningOff() then return nil end
    if not self:GetIsRevvedUp() then return nil end
    
    if self:GetIsAttacking() then
        return "chainsaw/chainsaw_sawloop.wav"
    end
    
    return "chainsaw/chainsaw_idleloop.wav"
end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    local desiredSoundPath = self:GetDesiredSoundPath()
    
    if not self.loopSound then
        if desiredSoundPath then
            local loopSound = CreateSound( owner, desiredSoundPath )
            self.loopSound = loopSound
            self.currentSoundPath = desiredSoundPath
            
            self:CallOnRemove( "chainsaw_loopSound", function()
                if loopSound and loopSound:IsPlaying() then
                    loopSound:Stop()
                end
            end )
            
            if not self.loopSound:IsPlaying() then
                self.loopSound:Play()
            end
        end
    else
        if desiredSoundPath then
            if self.currentSoundPath ~= desiredSoundPath then
                self:KillSound()
                
                local loopSound = CreateSound( owner, desiredSoundPath )
                self.loopSound = loopSound
                self.currentSoundPath = desiredSoundPath
                
                self:CallOnRemove( "chainsaw_loopSound", function()
                    if loopSound and loopSound:IsPlaying() then
                        loopSound:Stop()
                    end
                end )
                
                if not self.loopSound:IsPlaying() then
                    self.loopSound:Play()
                end
            else
                if not self.loopSound:IsPlaying() then
                    self.loopSound:Play()
                end
            end
        else
            if self.loopSound and self.loopSound:IsPlaying() then
                self.loopSound:Stop()
            end
            self.currentSoundPath = nil
        end
    end

    if SERVER then
        local stopAttacking = self:GetIsAttacking() and self:GetIsRevvedUp() and not owner:KeyDown( IN_ATTACK )
        if stopAttacking then
            self:SetIsAttacking( false )
            
            local vm = owner:GetViewModel()
            if IsValid( vm ) then
                vm:SendViewModelMatchingSequence( vm:LookupSequence( "IdleOn" ) )
            end
        end

        local shouldIdle = self:GetIsRevvedUp() and not self:GetIsAttacking() and not self:GetIsTurningOn() and not self:GetIsTurningOff()
        if shouldIdle then
            local vm = owner:GetViewModel()
            if IsValid( vm ) and vm:GetSequence() ~= vm:LookupSequence( "IdleOn" ) then
                vm:SendViewModelMatchingSequence( vm:LookupSequence( "IdleOn" ) )
            end
        end
        
        if self.loopSound and not desiredSoundPath then
            self:KillSound()
        end
    end
end

function SWEP:PlayTurningOnSound()
    self:EmitSound( "chainsaw/chainsaw_failedstart.wav" )
end

function SWEP:PlayTurningOnSound2()
    self:EmitSound( "chainsaw/chainsaw_successstart.wav" )
end

function SWEP:PlayTurningOffSound()
    self:EmitSound( "chainsaw/chainsaw_turnoff.wav" )
end

function SWEP:Reload()
    if not IsFirstTimePredicted() then return end
    if self:GetIsTurningOn() or self:GetIsTurningOff() then return end

    if self:GetIsRevvedUp() then
        self:TurnOff()
    else
        self:TurnOn()
    end
end

function SWEP:TurnOn()
    if not SERVER then return end
    if self:GetIsTurningOn() or self:GetIsRevvedUp() then return end

    self:SetIsTurningOn( true )
    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "TurnOn" ) )

    timer.Simple( 0.7, function()
        if not IsValid( self ) or not self:GetIsTurningOn() then return end
        self:PlayTurningOnSound()
    end )

    timer.Simple( 1.5, function()
        if not IsValid( self ) or not self:GetIsTurningOn() then return end
        self:PlayTurningOnSound2()
    end )

    timer.Simple( 2.8, function()
        if not IsValid( self ) or not self:GetIsTurningOn() then return end
        self:SetIsRevvedUp( true )
        self:SetIsTurningOn( false )
        
        local vm2 = self:GetOwner():GetViewModel()
        if IsValid( vm2 ) then
            vm2:SendViewModelMatchingSequence( vm2:LookupSequence( "IdleOn" ) )
        end
    end )

    self:SetNextPrimaryFire( CurTime() + 0.6 )
end

function SWEP:TurnOff()
    if not SERVER then return end
    if self:GetIsTurningOff() then return end

    self:SetIsTurningOff( true )
    self:SetIsAttacking( false )

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "TurnOff" ) )

    self:PlayTurningOffSound()

    timer.Simple( 1.0, function()
        if not IsValid( self ) then return end
        self:SetIsRevvedUp( false )
        self:SetIsTurningOff( false )
    end )

    self:SetNextPrimaryFire( CurTime() + 1.0 )
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    if self:GetIsTurningOn() or self:GetIsTurningOff() then return end

    if not self:GetIsRevvedUp() then
        self:TurnOn()
        return
    end

    if not SERVER then return end

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "Attack_On" ) )

    if not self:GetIsAttacking() then
        self:SetIsAttacking( true )
        vm:SendViewModelMatchingSequence( 11 )
    end

    self:DealDamage()
    self:SetNextPrimaryFire( CurTime() + 0.1 )
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:SecondaryAttack()
end


function SWEP:DealDamage()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    local tr = util.TraceLine( {
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 90,
        filter = owner
    } )

    if tr.Hit and tr.HitPos:Distance( owner:GetShootPos() ) <= 90 then
        local ent = tr.Entity

        local bullet = {
            Num = 1,
            Src = owner:GetShootPos(),
            Dir = owner:GetAimVector(),
            Spread = Vector( 0, 0, 0 ),
            Tracer = 0,
            Force = 3,
            Damage = math.random( 8, 31 ),
            Distance = 90
        }

        owner:FireBullets( bullet )

        if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
            sound.Play( "physics/body/body_medium_break" .. math.random( 2, 4 ) .. ".wav", tr.HitPos, 75, math.random( 100, 155 ), 1 )
            sound.Play( "npc/antlion_guard/antlion_guard_shellcrack" .. math.random( 1, 2 ) .. ".wav", tr.HitPos, 75, math.random( 100, 155 ), 1 )
            sound.Play( "ambient/machines/slicer" .. math.random( 1, 4 ) .. ".wav", tr.HitPos, 75, math.random( 100, 155 ), 1 )

            local ed = EffectData()
            ed:SetOrigin( tr.HitPos )
            ed:SetNormal( tr.HitNormal )
            ed:SetScale( 8 )
            ed:SetFlags( 3 )
            util.Effect( "bloodspray", ed, true, true )
        end
    end
end

function SWEP:Holster()
    if self:GetIsRevvedUp() then
        self:TurnOff()
    end
    
    self:KillSound()
    return true
end

function SWEP:OnRemove()
    self:KillSound()
end

