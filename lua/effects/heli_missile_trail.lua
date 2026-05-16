local math_random = math.random
local math_Rand = math.Rand
local VectorRand = VectorRand
local vectorZero = Vector( 0, 0, 0 )

EFFECT.Offset = Vector( -88, 0, 11 )
EFFECT.mat = Material( "sprites/light_glow02_add" )

local smokeMaterials = {
    "particle/smokesprites_0001",
    "particle/smokesprites_0002",
    "particle/smokesprites_0003",
    "particle/smokesprites_0004",
    "particle/smokesprites_0005",
    "particle/smokesprites_0006",
    "particle/smokesprites_0007",
    "particle/smokesprites_0008",
    "particle/smokesprites_0009",
    "particle/smokesprites_0010",
    "particle/smokesprites_0011",
    "particle/smokesprites_0012",
    "particle/smokesprites_0013",
    "particle/smokesprites_0014",
    "particle/smokesprites_0015",
    "particle/smokesprites_0016"
}

function EFFECT:Init( data )
    local ent = data:GetEntity()

    if not IsValid( ent ) then return end
    self.Entity = ent

    self.OldPos = ent:LocalToWorld( self.Offset )
    self.Emitter = ParticleEmitter( self.OldPos, false )
end

function EFFECT:doFX( pos )
    local ent = self.Entity
    local emitter = self.Emitter

    local entForward = ent:GetForward()
    local randomMat = smokeMaterials[math_random( 1, #smokeMaterials )]
    local particle = emitter:Add( randomMat, pos )

    if particle then
        particle:SetGravity( Vector( 0, 0, 100 ) + VectorRand() * 50 )
        particle:SetVelocity( -entForward * 500  )
        particle:SetAirResistance( 600 )
        particle:SetDieTime( math_Rand( 3, 5 ) )
        particle:SetStartAlpha( 150 )
        particle:SetStartSize( math_Rand( 6, 12 ) )
        particle:SetEndSize( math_Rand( 40, 90 ) )
        particle:SetRoll( math_Rand( -1, 1 ) )
        particle:SetColor( 50, 50, 50 )
        particle:SetCollide( false )
    end

    particle = emitter:Add( "particles/flamelet" .. math_random( 1, 5 ), pos )
    if particle then
        particle:SetVelocity( -entForward * 300 + ent:GetVelocity() )
        particle:SetDieTime( 0.1 )
        particle:SetAirResistance( 0 )
        particle:SetStartAlpha( 255 )
        particle:SetStartSize( 4 )
        particle:SetEndSize( 0 )
        particle:SetRoll( math_Rand( -1, 1 ) )
        particle:SetColor( 255, 255, 255 )
        particle:SetGravity( vectorZero )
        particle:SetCollide( false )
    end
end


function EFFECT:doFXbroken( pos )
    local ent = self.Entity
    local forward = ent:GetForward()
    local emitter = self.Emitter

    local randomMat = smokeMaterials[math_random( 1, table.Count( smokeMaterials ) )]
    local particle = emitter:Add( randomMat, pos )
    if particle then
        particle:SetGravity( Vector( 0, 0, 100 ) + VectorRand() * 50 )
        particle:SetVelocity( -forward * 500  )
        particle:SetAirResistance( 600 )
        particle:SetDieTime( math_Rand( 3, 5 ) )
        particle:SetStartAlpha( 150 )
        particle:SetStartSize( math_Rand( 6, 12 ) )
        particle:SetEndSize( math_Rand( 40, 90 ) )
        particle:SetRoll( math_Rand( -1, 1 ) )
        particle:SetColor( 50, 50, 50 )
        particle:SetCollide( false )
    end

    particle = emitter:Add( "particles/flamelet" .. math_random( 1, 5 ), pos )
    if particle then
        particle:SetVelocity( -forward * 500 + VectorRand() * 50 )
        particle:SetDieTime( 0.25 )
        particle:SetAirResistance( 600 )
        particle:SetStartAlpha( 255 )
        particle:SetStartSize( math_Rand( 25, 40 ) )
        particle:SetEndSize( math_Rand( 10, 15 ) )
        particle:SetRoll( math_Rand( -1, 1 ) )
        particle:SetColor( 255, 255, 255 )
        particle:SetGravity( vectorZero )
        particle:SetCollide( false )
    end
end

function EFFECT:Think()
    local ent = self.Entity
    local emitter = self.Emitter
    if not IsValid( ent ) then

        if emitter then
            emitter:Finish()
        end

        return false
    end

    local nextDFX = self.nextDFX or 0
    if nextDFX >= CurTime() then return true end
    self.nextDFX = CurTime() + 0.02

    local oldpos = self.OldPos
    local newpos = ent:LocalToWorld( self.Offset )

    self:SetPos( newpos )

    local disabled = ent:GetDisabled()
    self.Disabled = disabled -- for the sprite draw below

    local diff = newpos - oldpos
    local length = diff:Length()
    local dir = length < 0.01 and vectorZero or ( diff / length )

    self.OldPos = newpos

    for i = 0, length, 45 do
        local pos = oldpos + dir * i

        if disabled then
            self:doFXbroken( pos )
        else
            self:doFX( pos )
        end
    end

    return true
end

local render = render
local spriteColor = Color( 255, 100, 0 )
function EFFECT:Render() -- draw sprite
    if self.Disabled then return end

    local pos = self.Entity:LocalToWorld( self.Offset )

    render.SetMaterial( self.mat )
    render.DrawSprite( pos, 256, 256, spriteColor )
end