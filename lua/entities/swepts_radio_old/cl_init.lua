include( "shared.lua" )

function ENT:Draw()
    self:DrawModel()

end


--[[------------------------------------
    The tuner: the station's name over a dial you drag to find one. No list, finding a
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
