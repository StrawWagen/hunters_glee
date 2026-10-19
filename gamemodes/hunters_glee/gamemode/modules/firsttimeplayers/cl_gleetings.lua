
-- Asks everyone else to wish a new player Gleetings, once their tutorial's done. sv_firsttimeplayers.lua sends it

local GAMEMODE = GAMEMODE or GM

local gleetingsAsk = CreateClientConVar( "cl_huntersglee_gleetingsask", 1, true, true, "Get a chat print when someone who's never played glee joins?" )

if not game.IsDedicated() then return end

local andThenYaps = {
    "And then push them off a cliff...",
    "Before you beartrap them...",
    "And then show them the ropes!",
    "And then help them learn the gamemode!",
    "And then gaslight them into thinking RDM is banned!",
    "And then temporally invert them!",
    "Then tell them the terminators are friendly!",
    "And then gaslight them into thinking someone's a traitor!",
    "And then... Uhh, i forgot.",
    "And then tell them the TRUTH about hunter's glee!",
    "And don't forget to help them place stuff while dead!",
    "Make sure they don't leave without a little bit of glee...",
    "Treat them to a gleeful first impression!",
    "First impressions matter, so push them off a cliff for good measure!",
    "Warn them about the crates, god the crates!",
    "Make sure they don't go into debt!",
    "And then push them into a beartrap!",
    "And then feed them to a barnacle!",
    "And then gaslight them into going Legally Bind!",
    "And warn them not to go Legally Blind!",
    "And revive them like your life depends on it!",
    "But silently curse their soul under your breath...",
    "And gain their trust, only to feed them to a barnacle...",
    "And gaslight them into thinking supercop's friendly!",
    "And gaslight them into debt!",
    "Before they get crushed in an elevator!",
    "Before they get stuck between a supercop and a hard place!",
    "Before you RTV to gm_skyblock!",
    "And bless them like their life depends on it, cause it does!",
    "And then temporally invert them into a pit of despair!",
    "And then temporally invert them to saftey!",

}

local white = Color( 255, 255, 255 )

net.Receive( "glee_askforgleetings", function()
    if not GAMEMODE:HasSeenTutorial() then return end -- we're new, we can't help anyone!
    if not gleetingsAsk:GetBool() then return end -- shut UP

    local firstTimePlayer = net.ReadEntity()
    if not IsValid( firstTimePlayer ) then return end -- might happen

    LocalPlayer():EmitSound( "garrysmod/save_load2.wav", 75, math.random( 110, 140 ), 0.65 )

    local gleetings = "GLEE: Please wish Gleetings! To " .. firstTimePlayer:GetName() .. "!\n" .. andThenYaps[math.random( 1, #andThenYaps )]
    chat.AddText( white, gleetings )
    -- EG;
    -- Please wish Gleetings! To StrawWagen!
    -- And then push them off a cliff...

end )
