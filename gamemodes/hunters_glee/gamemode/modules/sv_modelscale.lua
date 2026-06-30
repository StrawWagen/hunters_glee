-- credit https://steamcommunity.com/sharedfiles/filedetails/?id=2186553332

local characters_chars = {}

local enabledVar = CreateConVar( "huntersglee_playermodelscaling", 0, { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Scale player hulls/view based on their playermodel?", 0, 1 )
local doMaxHealthVar = CreateConVar( "huntersglee_playermodelscaling_maxhealth", 0, { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Have playermodel scale change their max health? Requires restart to apply.", 0, 1 )

util.AddNetworkString( "GLEE_PDM:UpdatePlyHull" )

-- default hullz is 72
local dontActivateMax = 78
local dontActivateMin = 65

local function SetupCharacterChars( name )
    local character_chars = { -- default character stats
        ["height"] = 64,
        ["heightduck"] = 28,
        ["hullz"] = 72,
        ["hullzduck"] = 36,
        ["hull"] = 16,
        ["stepsize"] = 18,
        ["health"] = 100
    }

    local entity = ents.Create( "base_anim" )
    local model = player_manager.TranslatePlayerModel( name )

    entity:SetModel( model )

    local height = entity:OBBMaxs().z

    entity:ResetSequence( entity:LookupSequence( "idle_all_01" ) )
    local bone = entity:LookupBone( "ValveBiped.Bip01_Neck1" )
    if bone then
        -- if model has invalid head bone pos, default to normal height
        local boneHeight = math.Round( entity:GetBonePosition( bone ).z )
        boneHeight = boneHeight > 8 and boneHeight or character_chars["height"]

        character_chars["height"] = boneHeight
        character_chars["hullz"] = math.Round( ( boneHeight + height ) / 2 )
        character_chars["hullzduck"] = math.Round( character_chars["hullz"] / 2 )

    else
        local defaultHeightRatio = character_chars["height"] / character_chars["hullz"]
        character_chars["height"] = height * defaultHeightRatio
        character_chars["hullz"] = math.Round( height )
        character_chars["hullzduck"] = math.Round( character_chars["hullz"] / 2 )

    end

    if character_chars["hullz"] > dontActivateMin and character_chars["hullz"] < dontActivateMax then -- close enough, dont do anything weird
        entity:Remove()
        characters_chars[name] = character_chars
        return

    end

    entity:SetModel( model )
    entity:ResetSequence( entity:LookupSequence( "cidle_all" ) )
    bone = entity:LookupBone( "ValveBiped.Bip01_Neck1" )
    if bone then
        local boneHeightDuck = math.Round( entity:GetBonePosition( bone ).z )
        boneHeightDuck = boneHeightDuck > 4 and boneHeightDuck or character_chars["heightduck"]
        character_chars["heightduck"] = boneHeightDuck

    end

    character_chars["hull"] = math.Round( math.Min( entity:OBBMaxs().x, entity:OBBMaxs().y ) )

    local scaleMagicNum = 79
    local mul = ( ( character_chars["hullz"] + character_chars["hull"] ) / scaleMagicNum )
    character_chars["stepsize"] = math.Round( character_chars["stepsize"] * mul )

    if mul < 1 then -- small characters get like no health
        mul = mul^4

    end
    character_chars["health"] = math.Round( character_chars["health"] * mul )

    entity:Remove()

    characters_chars[name] = character_chars

end

local function Update( ply )
    local name = ply:GetInfo( "cl_playermodel" )
    local character_chars = characters_chars[name]

    if not character_chars then return end
    if enabledVar:GetBool() then
        ply:SetViewOffsetDucked( Vector( 0, 0, character_chars["heightduck"] ) )
        ply:SetViewOffset( Vector( 0, 0, character_chars["height"] ) )

        ply:SetHull( Vector( -character_chars["hull"], -character_chars["hull"], 0 ), Vector( character_chars["hull"], character_chars["hull"], character_chars["hullz"] ) )
        ply:SetHullDuck( Vector( -character_chars["hull"], -character_chars["hull"], 0 ), Vector( character_chars["hull"], character_chars["hull"], character_chars["hullzduck"] ) )

        ply:SetStepSize( character_chars["stepsize"] )

    end

    if doMaxHealthVar:GetBool() then
        local newMaxHealth = character_chars["health"]
        ply.glee_BaseHealth = newMaxHealth
        ply:SetMaxHealth( newMaxHealth )
        ply.glee_LastSetMaxHealthReason = "PDM_Update"

    else
        -- keep glee_BaseHealth meaningful for consumers ( divine chosen, innate hp )
        ply.glee_BaseHealth = ply:GetMaxHealth()

    end

    ply.PDM_charactername = ply:GetInfo( "cl_playermodel" )

    net.Start( "GLEE_PDM:UpdatePlyHull" )
        net.WriteUInt( character_chars["hull"], 16 )
        net.WriteUInt( character_chars["hullz"], 16 )
        net.WriteUInt( character_chars["hullzduck"], 16 )

    net.Send( ply )
end

local function InitCharactersChars()
    for name, _path in SortedPairs( player_manager.AllValidModels() ) do
        SetupCharacterChars( name )

    end
end

hook.Add( "InitPostEntity", "GLEE_PDM:InitPostEntity", function()
    InitCharactersChars()
    terminator_Extras.glee_PDM_Loaded = true

end )

if terminator_Extras.glee_PDM_Loaded then -- auto re fresh
    InitCharactersChars()

end


hook.Add( "PlayerSpawn", "GLEE_PDM:PlayerSpawn", function( ply )
    ply.PDM_Spawned = true
    timer.Simple( 0, function()
        ply:SetHealth( math.min( ply:Health(), ply:GetMaxHealth() ) )
        ply.glee_LastHealthSetReason = "PDM_PlayerSpawn"

    end )
end )

-- tick if either scaling or maxhealth scaling is enabled.
local scaleTick = enabledVar:GetBool() or doMaxHealthVar:GetBool()

cvars.AddChangeCallback( "huntersglee_playermodelscaling", function( _, _, new )
    scaleTick = tobool( new ) or doMaxHealthVar:GetBool()

end, "glee_scaletick_detectchange" )

cvars.AddChangeCallback( "huntersglee_playermodelscaling_maxhealth", function( _, _, new )
    scaleTick = tobool( new ) or enabledVar:GetBool()

end, "glee_scaletick_detectchange_maxhealth" )

hook.Add( "PlayerTick", "GLEE_PDM:PlayerTick", function( ply )
    if not scaleTick then return end

    local chars = characters_chars[ply.PDM_charactername]
    if
        ply.PDM_ModelPath ~= ply:GetModel()
        or ply.PDM_Spawned
        or (
            chars ~= nil
            and (
                ply:GetViewOffset()[3] ~= chars["height"]
                or ply:GetViewOffsetDucked()[3] ~= chars["heightduck"]
            )
        )
    then
        ply.PDM_ModelPath = ply:GetModel()

        Update( ply )

        ply.PDM_Spawned = nil

    end
end )