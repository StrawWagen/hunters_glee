include( "shared.lua" )

function ENT:Draw()
    self:DrawModel()

end


--[[------------------------------------
    Playback: every client plays the song from where SongStart says it's up to, so anyone arriving
    mid-song hears what everyone else does. Emitted songs are the server's, see PlaySong.

    Going dormant, it drifts off into the distance. Coming back, it drifts back in, still in sync.
--]]-------------------------------------

local FADE_NEAR, FADE_FAR = 350, 4500 -- BASS's 3d falloff, full volume inside near, stops getting quieter past far
local DRIFT_TIME = 4 -- seconds to fade out on dormancy, and back in after
local DUCKED_VOLUME = 0.5 -- under the gamemode's music
local DUCK_SPEED = 2 -- volume per second
local RESYNC_INTERVAL = 1
local MAX_DESYNC = 1 -- seconds off the server's position before it's seeked back

local volumeVar = CreateClientConVar( "cl_huntersglee_radiovolume", "1", true, false, "Volume of radios' music", 0, 1 )

-- keyed by entity, so a removed radio's channel can still be stopped
local radioStates = {}

local function channelVolume( state )
    return state.presence * state.duck * volumeVar:GetFloat()

end

local function stopChannel( state )
    state.loadGen = state.loadGen + 1
    state.loading = false
    if IsValid( state.channel ) then state.channel:Stop() end
    if IsValid( state.outgoing ) then state.outgoing:Stop() end
    state.channel = nil
    state.outgoing = nil

end

local function hasClientSong( radio )
    return radio:GetSong() > 0 and not radio:GetSongEmitted()

end

-- nil once a song that doesn't loop has ended
local function songPosition( radio, channel )
    local position = CurTime() - radio:GetSongStart()
    local length = channel:GetLength()
    if length <= 0 then return position end

    if radio.Stations[radio:GetSong()].loop then return position % length end
    if position >= length then return end

    return position

end

-- handOff keeps what's playing going until this one's loaded
local function startChannel( radio, state, handOff )
    local outgoing = handOff and ( state.channel or state.outgoing )
    state.channel = nil
    state.outgoing = nil
    stopChannel( state )
    state.outgoing = outgoing
    state.loading = true

    local gen = state.loadGen
    local station = radio.Stations[radio:GetSong()]
    local flat = state.flat
    local flags = flat and "noblock noplay" or "3d noblock noplay"

    sound.PlayFile( "sound/" .. station.path, flags, function( channel )
        if state.loadGen ~= gen or not IsValid( radio ) then
            if IsValid( channel ) then channel:Stop() end
            return

        end

        state.loading = false
        if IsValid( state.outgoing ) then state.outgoing:Stop() end
        state.outgoing = nil

        -- a missing file is as good as over, or every resync would retry it
        local position = IsValid( channel ) and songPosition( radio, channel )
        if not position then
            state.ended = true
            if IsValid( channel ) then channel:Stop() end
            return

        end

        channel:EnableLooping( station.loop == true )
        if not flat then
            channel:Set3DFadeDistance( FADE_NEAR, FADE_FAR )
            channel:SetPos( state.pos )

        end
        channel:SetVolume( channelVolume( state ) )
        -- dontDecode, otherwise it decodes everything up to there on the spot, a long freeze late into a song
        channel:SetTime( position, true )
        channel:Play()

        state.channel = channel

    end )
end

-- also what brings it back after a stopsound, or once it wakes up from dormancy
local function resync( radio, state )
    if state.ended or not hasClientSong( radio ) then
        stopChannel( state )
        return

    end

    if state.loading then return end

    local channel = state.channel
    if not IsValid( channel ) or channel:GetState() == GMOD_CHANNEL_STOPPED then
        startChannel( radio, state )
        return

    end

    local position = songPosition( radio, channel )
    if not position then
        state.ended = true
        stopChannel( state )
        return

    end

    if math.abs( channel:GetTime() - position ) > MAX_DESYNC then
        channel:SetTime( position, true )

    end

    if channel:GetState() == GMOD_CHANNEL_STALLED then
        channel:Play()

    end
end

local function updateRadio( radio, state )
    local dormant = radio:IsDormant()
    if not dormant then
        state.pos = radio:WorldSpaceCenter()

    end

    -- it rides their bones, which trail their view, so in 3d it'd swing round their head as they turn
    local flat = terminator_Extras.glee_Carrying.IsCarriedBy( radio, LocalPlayer() )
    if flat ~= state.flat then
        state.flat = flat
        -- a channel can't change in or out of 3d, so it's reloaded
        if state.channel or state.loading then startChannel( radio, state, true ) end

    end

    local dt = FrameTime()
    state.presence = math.Approach( state.presence, dormant and 0 or 1, dt / DRIFT_TIME )

    local musicAudible = GAMEMODE.IsMusicAudible and GAMEMODE:IsMusicAudible()
    state.duck = math.Approach( state.duck, musicAudible and DUCKED_VOLUME or 1, dt * DUCK_SPEED )

    -- the start time too, damage can land a radio on the station it's already playing
    local songKey = radio:GetSong() .. "@" .. radio:GetSongStart()
    if songKey ~= state.songKey then
        state.songKey = songKey
        state.ended = false
        state.nextResync = 0
        stopChannel( state )

    end

    if dormant and state.presence <= 0 then
        if state.channel or state.loading then stopChannel( state ) end
        return

    end

    local channel = state.channel
    if IsValid( channel ) then
        if not state.flat then channel:SetPos( state.pos ) end
        channel:SetVolume( channelVolume( state ) )

    end

    if state.nextResync > RealTime() then return end
    state.nextResync = RealTime() + RESYNC_INTERVAL

    resync( radio, state )

end

hook.Add( "Think", "glee_radio_playback", function()
    for radio, state in pairs( radioStates ) do
        if IsValid( radio ) then
            updateRadio( radio, state )

        else
            stopChannel( state )
            radioStates[radio] = nil

        end
    end
end )

-- Only runs while it isn't dormant, the hook above carries it through dormancy
function ENT:Think()
    if radioStates[self] then return end

    radioStates[self] = {
        loadGen = 0,
        loading = false,
        pos = self:WorldSpaceCenter(),
        flat = false,
        presence = 0,
        duck = 1,
        nextResync = 0,
    }
end

function ENT:OnRemove( fullUpdate )
    if fullUpdate then return end -- it's coming straight back, the song plays on through

    local state = radioStates[self]
    if not state then return end

    stopChannel( state )
    radioStates[self] = nil

end


--[[------------------------------------
    Shake: the bass kicks of whichever radio they hear loudest nudge their view.
    A kick is the bass jumping over its recent average, a steady loud bassline doesn't shake.
--]]-------------------------------------

local shakeVar = CreateClientConVar( "cl_huntersglee_radioshake", "1", true, false, "Scale of the screenshake from radios' bass, 0 for none", 0, 1 )

local BASS_LOW, BASS_HIGH = 40, 150 -- hz
local FFT_SIZE = 2048 -- FFT_2048's, bins about 21hz wide at 44.1khz
local MIN_HEARD = 0.4 -- of full volume, it has to be at least this loud to them, about 900 units off in 3d
local ONSET_RATIO = 1.6 -- over the recent average, how far the bass has to jump
local ONSET_FLOOR = 0.05 -- or quiet passages would shake on their own small bumps
local AVERAGE_SPEED = 4 -- per second, how quickly the recent average catches up
local MIN_GAP = 0.12 -- seconds between shakes, any faster reads as a buzz
local MAX_AMPLITUDE = 2 -- util.ScreenShake's, which tops out at 16

local fft = {}

-- The channel's data doesn't include BASS's 3d falloff, so it's mirrored here
local function heardVolume( state )
    local volume = state.presence * state.duck
    if state.flat then return volume end

    local dist = math.Clamp( EyePos():Distance( state.pos ), FADE_NEAR, FADE_FAR )

    return volume * FADE_NEAR / dist

end

local function bassEnergy( channel )
    local binWidth = channel:GetSamplingRate() / FFT_SIZE
    channel:FFT( fft, FFT_2048 )

    local energy = 0
    for bin = math.floor( BASS_LOW / binWidth ) + 1, math.ceil( BASS_HIGH / binWidth ) + 1 do
        energy = energy + ( fft[bin] or 0 )

    end

    return energy

end

hook.Add( "Think", "glee_radio_shake", function()
    local scale = shakeVar:GetFloat()
    if scale <= 0 then return end

    local loudest, loudestHeard = nil, MIN_HEARD
    for _, state in pairs( radioStates ) do
        local channel = state.channel
        if IsValid( channel ) and channel:GetState() == GMOD_CHANNEL_PLAYING then
            local heard = heardVolume( state )
            if heard >= loudestHeard then
                loudest, loudestHeard = state, heard

            end
        end
    end

    if not loudest then return end

    local energy = bassEnergy( loudest.channel )
    local average = loudest.bassAverage or energy
    loudest.bassAverage = Lerp( math.min( FrameTime() * AVERAGE_SPEED, 1 ), average, energy )

    if energy < ONSET_FLOOR or energy < average * ONSET_RATIO then return end
    if ( loudest.nextShake or 0 ) > RealTime() then return end
    loudest.nextShake = RealTime() + MIN_GAP

    local amplitude = MAX_AMPLITUDE * math.Clamp( energy - average, 0, 1 ) * loudestHeard * scale
    util.ScreenShake( EyePos(), amplitude, 20, 0.15, 64 )

end )


--[[------------------------------------
    The tuner: the station's name over a dial you drag or scroll to find one. No list, finding a
    song is meant to take fiddling.

    While a drag is unsent, or the server hasn't caught up, it shows where the dial is.
    Otherwise it shows the radio's networked song, so damage or another player retuning it
    moves the dial too.
--]]-------------------------------------

local NAME_FONT = "medium"

local FM_LOW, FM_HIGH = 88, 108 -- the dial's band, stations spread evenly across it

local sendInterval = 0.25 -- just over the server's tune cooldown, so a send is never refused
local settleTime = 1 -- give up waiting on the server after this, and show what it says

local currentFrame

local function stationName( radio, index )
    if index == 0 then return "OFF" end

    return radio.Stations[index].name

end

local function longestStationName( radio )
    local longest = ""
    for _, station in ipairs( radio.Stations ) do
        if #station.name > #longest then longest = station.name end

    end

    return longest

end

-- of the dial, unrounded, so it creeps between stations
local function frequencyText( radio, position )
    if position < 0.5 then return "OFF" end

    local fraction = ( position - 1 ) / ( #radio.Stations - 1 )

    return string.format( "%.1f", Lerp( math.max( fraction, 0 ), FM_LOW, FM_HIGH ) )

end

local function sendTune( radio, index )
    net.Start( "glee_radio_tune" )
        net.WriteEntity( radio )
        net.WriteUInt( index, 8 )
    net.SendToServer()

end

local function openTuner( radio )
    if IsValid( currentFrame ) then currentFrame:Remove() end

    local ply = LocalPlayer()

    local frame = vgui.Create( "glee_frame" )
    local gap = frame:Style():Metric( "laneSpacing" )

    -- reserved, or the whole menu would resize under the cursor as the name changes
    local nameBox = vgui.Create( "glee_panel", frame )
    nameBox:SetFont( NAME_FONT )
    nameBox:SetTextAlign( TEXT_ALIGN_LEFT )
    nameBox:SetReservedText( longestStationName( radio ) )
    nameBox:SetText( stationName( radio, radio:GetSong() ) )
    nameBox:AutoSize()
    nameBox:Dock( TOP )

    local dial = vgui.Create( "glee_slider", frame )
    dial:SetLabel( "FM" )
    dial:SetReservedValue( string.format( "%.1f", FM_HIGH ) )
    dial:SetRange( 0, #radio.Stations )
    dial:SetPosition( radio:GetSong() )
    dial:Dock( TOP )
    dial:DockMargin( 0, gap, 0, 0 )

    local pending -- the station the dial last stopped on, nil once the radio's playing it
    local lastSent = radio:GetSong()
    local nextSend = 0
    local releasedAt = 0

    function dial:OnDragged( position )
        pending = math.Round( position )

    end

    function dial:OnReleased( position )
        pending = math.Round( position )
        releasedAt = CurTime()

    end

    -- a station per notch, from wherever the dial is headed
    function frame:OnMouseWheeled( delta )
        if dial:IsDragging() then return true end

        local from = pending or radio:GetSong()
        pending = math.Clamp( from + delta, 0, #radio.Stations )
        releasedAt = CurTime()
        dial:SetPosition( pending )

        return true

    end

    frame:SizeToContents()
    frame:Center()

    function frame:Think()
        if not IsValid( radio ) or not IsValid( ply ) or not radio:CanBeTunedBy( ply ) then
            self:Close()
            return

        end

        local song = radio:GetSong()
        local cur = CurTime()

        if pending and pending ~= lastSent and nextSend <= cur then
            sendTune( radio, pending )
            lastSent = pending
            nextSend = cur + sendInterval

        end

        local settled = pending == lastSent and ( pending == song or cur - releasedAt > settleTime )
        if pending and not dial:IsDragging() and settled then
            pending = nil

        end

        if not pending then
            dial:SetPosition( song )

        end

        nameBox:SetText( stationName( radio, pending or song ) )
        dial:SetValue( frequencyText( radio, dial:GetPosition() ) )

    end

    terminator_Extras.easyClosePanel( frame )
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    currentFrame = frame

end

net.Receive( "glee_radio_open", function()
    local radio = net.ReadEntity()
    if not IsValid( radio ) then return end

    openTuner( radio )

end )
