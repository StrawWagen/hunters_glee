--[[
    Documents: terms a shop item makes you sign before buying it.

    Register one by name, then a shop item opts in by naming it:
        GAMEMODE:RegisterDocument( "skull_gains", function( ply ) return title, sections end )
        clDocument = "skull_gains",

    The builder runs every time the document opens, so figures in it can be read live.
    sections: { { heading = "DEFINITIONS", body = "..." }, ... }, numbered into articles here.
]]

local GAMEMODE = GAMEMODE or GM

local FRAME_MAX_H_1080P = 775 -- the settings menu's

GAMEMODE.documents = GAMEMODE.documents or {}

function GAMEMODE:RegisterDocument( name, builder )
    self.documents[name] = builder

end

local currentFrame

-- buy is called on agreeing, nothing is on declining. The form won't be signed while check says no
function GAMEMODE:OpenDocument( name, buy, check )
    local builder = self.documents[name]
    if not builder then
        ErrorNoHaltWithStack( "glee documents: no document named " .. tostring( name ) .. "\n" )
        return

    end

    local ply = LocalPlayer()

    local title, sections = builder( ply )

    for index, section in ipairs( sections ) do
        section.heading = "ARTICLE " .. index .. ". " .. section.heading

    end

    if IsValid( currentFrame ) then currentFrame:Remove() end

    local frame = vgui.Create( "glee_frame" )
    frame:SetPadContents( false ) -- the form brings its own

    local form = vgui.Create( "glee_consentform", frame )
    form:SetTitle( title )
    form:SetSigner( ply:Nick() )
    form:SetCheck( check )
    form:SetSections( sections )
    form:Dock( FILL )

    -- bought on signing, so closing the frame mid-stamp can't undo it
    function form:OnAgree()
        buy()

    end

    function form:OnStamped()
        frame:Close()

    end

    function form:OnDecline()
        frame:Close()

    end

    frame:SizeToContents( math.min( frame:Style():Scaled( FRAME_MAX_H_1080P ), ScrH() * 0.9 ) )
    frame:Center()

    terminator_Extras.easyClosePanel( frame )
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    currentFrame = frame

end
