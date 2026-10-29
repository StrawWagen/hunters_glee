AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

util.AddNetworkString( "glee_radio_open" )
util.AddNetworkString( "glee_radio_tune" )

local tuneCooldown = 0.2

function ENT:Initialize()
    self:SetModel( "models/props_lab/citizenradio.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()
        phys:SetMass( 25 )

    end

    self.takenDamageTimes = 0
    self.nextTakeDamageTime = 0
    self.audioDSP = 0
    self.audioPitch = 100
    self.nextSoundHint = 0

end


-- Playing -------------------------------------------------------------------

-- Clients play the song themselves, synced to SongStart, see cl_init.
-- Except once broken, BASS can't take the DSP, so those go out through EmitSound and only reach whoever's around as it starts
function ENT:PlaySong( index )
    local station = self.Stations[index]
    local emitted = self.RadioBroken == true

    self:SetSong( station and index or 0 )
    self:SetSongStart( CurTime() )
    self:SetSongEmitted( emitted )

    if not emitted then return end

    local path = station and station.path or self.OffSound

    local filterAllPlayers = RecipientFilter()
    filterAllPlayers:AddAllPlayers()

    self:EmitSound( path, 70, self.audioPitch, 1, CHAN_ITEM, nil, self.audioDSP, filterAllPlayers )

end

function ENT:OnRemove()
    self:PlaySong( 0 )

end

function ENT:Think()
    if self:GetSong() > 0 and self.nextSoundHint < CurTime() then
        self.nextSoundHint = CurTime() + 5
        local radius = self.RadioBroken and 100 or 200
        sound.EmitHint( SOUND_COMBAT, self:GetPos(), radius, 1, self )

    end
end


-- Tuning --------------------------------------------------------------------

-- Bots don't hold use for the wheel, so their use just picks it up. A player's use is the wheel's, see glee_carrying
function ENT:Use( _, caller )
    if not IsValid( caller ) or not caller:IsPlayer() or not caller:IsBot() then return end

    terminator_Extras.glee_Carrying.Carry( caller, self )

end

-- The wheel's pick, see glee_carrying. Only ever "tune", checked against CanUseAction already
function ENT:OnUseAction( ply )
    self:OpenTunerFor( ply )

    return true

end

-- No range check, the net message's receiver does that on every tune
function ENT:OpenTunerFor( ply )
    net.Start( "glee_radio_open" )
        net.WriteEntity( self )
    net.Send( ply )

end

net.Receive( "glee_radio_tune", function( _, ply )
    if ( ply.glee_NextRadioTune or 0 ) > CurTime() then return end
    ply.glee_NextRadioTune = CurTime() + tuneCooldown

    local radio = net.ReadEntity()
    local index = net.ReadUInt( 8 )

    if not IsValid( radio ) or radio:GetClass() ~= "swepts_radio_old" then return end
    if not radio:CanBeTunedBy( ply ) then return end
    if index ~= 0 and not radio.Stations[index] then return end
    if index == radio:GetSong() then return end

    radio:PlaySong( index )

end )


-- Damage --------------------------------------------------------------------

function ENT:TakeDamageRandomizeSong()
    self:PlaySong( math.random( 1, #self.Stations ) )

    self:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav" )
    self.takenDamageTimes = self.takenDamageTimes + 1

    if self.takenDamageTimes < 15 then return end
    if self.takenDamageTimes == 15 then
        self.RadioBroken = true
        self:EmitSound( "ambient/energy/zap" .. math.random( 5, 6 ) .. ".wav", 75, 100, CHAN_STATIC )

    end
    self:EmitSound( "ambient/energy/zap" .. math.random( 1, 3 ) .. ".wav", 75, 100, CHAN_STATIC )
    local target = 55 + ( self.takenDamageTimes % 5 )
    self.audioDSP = target
    self.audioPitch = math.random( 98, 102 )

end

function ENT:PhysicsCollide( data )
    if data.Speed < 500 then return end
    if self:IsPlayerHolding() then return end

    if self.nextTakeDamageTime > CurTime() then return end
    self.nextTakeDamageTime = CurTime() + 1

    self:TakeDamageRandomizeSong()

end

function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )

    if self.nextTakeDamageTime > CurTime() then return end
    self.nextTakeDamageTime = CurTime() + 0.1

    self:TakeDamageRandomizeSong()

end

local GAMEMODE = GAMEMODE or GM
if not GAMEMODE.RandomlySpawnEntTbl then return end

GAMEMODE:RandomlySpawnEntTbl( "swepts_radio_old", {
    maxCount = 1,
    chance = 50,
    minAreaSize = 25,
} )
