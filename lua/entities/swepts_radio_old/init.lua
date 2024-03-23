AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

-- https://combineoverwiki.net/wiki/Half-Life_2_soundtrack

ENT.Songs = {
    [0] = "ambient/_period.wav",
    [1] = "music/hl2_song4.mp3", -- "The Innsbruck Experiment"
    [2] = "music/hl2_song31.mp3", -- "Brane Scan"
    [3] = "music/hl2_song3.mp3", -- "Dark Energy"
    [4] = "music/ravenholm_1.mp3", -- "Requiem For Ravenholm"
    [5] = "music/hl2_song6.mp3", -- "Pulse Phase"
    [6] = "music/hl2_song7.mp3", -- "Ravenholm Reprise"
    [7] = "music/hl2_song33.mp3", -- Probably Not a Problem
    [8] = "music/hl2_song30.mp3", -- Calabi-Yau Model
    [9] = "music/hl2_song32.mp3", -- Slow Light
    [10] = "music/hl2_song29.mp3", -- Apprehension and Evasion
    [11] = "music/hl2_song26.mp3", -- Our Resurrected Teleport
    [12] = "music/hl2_song23_SuitSong3.mp3", -- Triage at Dawn
    [13] = "music/hl2_song2.mp3", --Lab Practicum
    [14] = "music/hl2_song19.mp3", --Nova Prospekt
    [15] = "music/hl2_song17.mp3", --Broken Symmetry
    [16] = "music/hl2_song16.mp3", --LG Orbifold
    [17] = "music/hl2_song15.mp3", --Kaon
    [18] = "music/hl2_song14.mp3", -- You're Not Supposed to Be Here
    [19] = "music/hl2_song12_long.mp3", --     Hard Fought 
    [20] = "music/hl2_song1.mp3", --Particle Ghost
    [21] = "music/hl1_song9.mp3", --Neutrino Trap
    [22] = "music/hl1_song6.mp3", --Zero Point Energy Field
    [23] = "music/hl1_song5.mp3", --Echoes of a Resonance Cascade
    [24] = "music/hl1_song3.mp3", --Black Mesa Inbound
    [25] = "music/hl1_song26.mp3", -- Xen Relay
    [26] = "music/hl1_song24.mp3", --Singularity
    [27] = "music/hl1_song21.mp3", --Dirac Shore
    [28] = "music/hl1_song20.mp3", -- Escape Array 
    [29] = "music/hl1_song19.mp3", --Negative Pressure
    [30] = "music/hl1_song17.mp3", --Tau-9
    [31] = "music/hl1_song15.mp3", --Something Secret Steers Us
    [32] = "music/hl1_song14.mp3", --Triple Entanglement
    [33] = "music/hl1_song10.mp3", --Lambda Core
    [34] = "music/hl2_song0.mp3", --Entanglement
    [35] = "music/hl2_song26_trainstation1.mp3", --Train Station 1
    [36] = "music/hl2_song27_trainstation2.mp3", --Train Station 2
    [37] = "music/radio1.mp3", --radio
    [38] = "ambient/music/bongo.wav",
    [39] = "ambient/music/piano1.wav",
    [40] = "ambient/music/country_rock_am_radio_loop.wav",
    [41] = "ambient/music/cubanmusic1.wav",
    [42] = "ambient/music/dustmusic2.wav",
    [43] = "ambient/music/piano2.wav",
    [44] = "ambient/music/flamenco.wav",
    [45] = "ambient/guit1.wav",
    [46] = "test/temp/soundscape_test/tv_music.wav",
    [47] = "ambient/music/latin.wav",
    [48] = "ambient/music/dustmusic1.wav",
    [49] = "ambient/opera.wav",
    [50] = "ambient/music/mirame_radio_thru_wall.wav",
    [51] = "ambient/music/dustmusic3.wav"
}
ENT.ActiveSong = 0

util.AddNetworkString( "OpenSTRadioMenu" )
util.AddNetworkString( "PlaySTRadioSong" )

function ENT:Initialize()
    self:SetModel( "models/props_lab/citizenradio.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()

    end

    self:SetUseType( CONTINUOUS_USE )

    self.takenDamageTimes = 0
    self.nextTakeDamageTime = 0
    self.audioDSP = 0

    self.nextResetGuiCreated = 0

end

hook.Add( "glee_genericprogress_exit" )

function ENT:Use( _, caller )
    if not caller:IsPlayer() then return end

    local progBarStatus = generic_WaitForProgressBar( caller, "termhunt_radio_use", 0.05, 20 )
    self.nextResetGuiCreated = CurTime() + 0.15

    if progBarStatus < 100 then return end

    if self.createdGUI then return end
    self.createdGUI = true

    net.Start( "OpenSTRadioMenu" )
        net.WriteUInt( self:EntIndex(), 16 )
        net.WriteUInt( self.ActiveSong, 16 )

    net.Send( caller )

end

function ENT:Think()
    if self.nextResetGuiCreated > CurTime() then return end
    self.nextResetGuiCreated = math.huge
    self.createdGUI = nil

end

local nextRecieve = 0

net.Receive( "PlaySTRadioSong", function()
    if nextRecieve > CurTime() then return end
    nextRecieve = CurTime() + 0.01

    local selfEnt = net.ReadEntity()
    local songIndex = net.ReadUInt( 16 )
    selfEnt:EmitSound( selfEnt.Songs[math.Round( songIndex )], 75, 100, 1, CHAN_ITEM, nil, selfEnt.audioDSP )
    selfEnt.ActiveSong = math.Round( songIndex )

end )

function ENT:OnRemove()
    self:EmitSound( "ambient/_period.wav", 75, 100, 1, CHAN_ITEM )

end

function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )

    if self.nextTakeDamageTime > CurTime() then return end
    self.nextTakeDamageTime = CurTime() + 0.1

    local rand = math.random( 1, 51 )
    self:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav" )
    self:EmitSound( self.Songs[rand], 75, 100, 1, CHAN_ITEM, nil, self.audioDSP )
    self.ActiveSong = rand

    self.takenDamageTimes = self.takenDamageTimes + 1

    if self.takenDamageTimes < 15 then return end
    if self.takenDamageTimes == 15 then
        self:EmitSound( "ambient/energy/zap" .. math.random( 5, 6 ) .. ".wav", 75, 100, CHAN_STATIC )

    end
    self:EmitSound( "ambient/energy/zap" .. math.random( 1, 3 ) .. ".wav", 75, 100, CHAN_STATIC )
    local target = 55 + ( self.takenDamageTimes % 5 )
    self.audioDSP = target

end

local GAMEMODE = GAMEMODE or GM
if not GAMEMODE.RandomlySpawnEnt then return end

GAMEMODE:RandomlySpawnEnt( "swepts_radio_old", 1, 100, 25 )