include( "shared.lua" )

function ENT:Draw()
    self:DrawModel()
end

local SongNames = {
    [0] = "Nothing",
    [1] = "The Innsbruck Experiment",
    [2] = "Brane Scan",
    [3] = "Dark Energy",
    [4] = "Requiem For Ravenholm",
    [5] = "Pulse Phase",
    [6] = "Ravenholm Reprise",
    [7] = "Probably Not a Problem",
    [8] = "Calabi-Yau Model",
    [9] = "Slow Light",
    [10] = "Apprehension and Evasion",
    [11] = "Our Resurrected Teleport",
    [12] = "Triage at Dawn",
    [13] = "Lab Practicum",
    [14] = "Nova Prospekt",
    [15] = "Broken Symmetry",
    [16] = "LG Orbifold",
    [17] = "Kaon",
    [18] = "You're Not Supposed to Be Here",
    [19] = "Hard Fought",
    [20] = "Particle Ghost",
    [21] = "Neutrino Trap",
    [22] = "Zero Point Energy Field",
    [23] = "Echoes of a Resonance Cascade",
    [24] = "Black Mesa Inbound",
    [25] = "Xen Relay",
    [26] = "Singularity",
    [27] = "Dirac Shore",
    [28] = "Escape Array",
    [29] = "Negative Pressure",
    [30] = "Tau-9",
    [31] = "Something Secret Steers Us",
    [32] = "Triple Entanglement",
    [33] = "Lambda Core",
    [34] = "Entanglement",
    [35] = "Train Station 1",
    [36] = "Train Station 2",
    [37] = "---",
    [38] = "CSS: The Sweet Sound of Bongo",
    [39] = "CSS: Only the Classics",
    [40] = "CSS: Country Rockin' Radio",
    [41] = "CSS: Cubic Cuban",
    [42] = "CSS: Desert Sands FM",
    [43] = "CSS: Fine-Tuned Tunes",
    [44] = "CSS: Flamenco Folk Music",
    [45] = "CSS: Glamorous Guitar",
    [46] = "CSS: Countryside Jams",
    [47] = "CSS: Latin Listening",
    [48] = "CSS: Tunes of the Middle East",
    [49] = "CSS: Outstanding Opera",
    [50] = "CSS: Songs of the Salsa",
    [51] = "CSS: Syrian Serenade"
}

local nextRecieve = 0
local shopItemColor = Color( 73, 73, 73, 255 )
local Tuner

net.Receive( "OpenSTRadioMenu", function()
    if nextRecieve > CurTime() then return end
    nextRecieve = CurTime() + 0.01

    local selfEnt = Entity( net.ReadUInt( 16 ) )
    local activeSong = net.ReadUInt( 16 )

    if Tuner and IsValid( Tuner ) then
        Tuner:Close()

    end

    Tuner = vgui.Create( "DFrame" )
    Tuner:SetSize( glee_sizeScaled( 500, 75 ) )
    Tuner:SetTitle( "" )
    Tuner:SetVisible( true )
    Tuner:SetDraggable( false )
    Tuner:ShowCloseButton( true )
    Tuner:MakePopup()
    Tuner:Center()

    function Tuner:Paint( w, h )
        draw.RoundedBox( 0, 0, 0, w, h, shopItemColor )
    end

    terminator_Extras.easyClosePanel( Tuner )

    local SongSlider = vgui.Create( "DNumSlider", Tuner )
    local margin = glee_sizeScaled( 15 )
    SongSlider:DockMargin( margin, margin, margin, margin )
    SongSlider:Dock( FILL )
    SongSlider:SetMin( 0 )
    SongSlider:SetMax( 51 )
    SongSlider:SetDecimals( 0 )
    SongSlider:SetValue( activeSong )
    SongSlider:SetText( "▶ " .. SongNames[math.Round( activeSong )] )
    SongSlider.OnValueChanged = function( _, val )
        SongSlider:SetText( "▶ " .. SongNames[math.Round( val )] )
        net.Start( "PlaySTRadioSong" )
            net.WriteEntity( selfEnt )
            net.WriteUInt( math.Round( val ), 16 )

        net.SendToServer()
    end
end )