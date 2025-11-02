-- credit https://steamcommunity.com/sharedfiles/filedetails/?id=2186553332

local characters_chars = {}

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
        character_chars["height"] = math.Round( entity:GetBonePosition( bone ).z )
        character_chars["hullz"] = math.Round( ( entity:GetBonePosition( bone ).z + height ) / 2 )
        character_chars["hullzduck"] = math.Round( character_chars["hullz"] / 2 )
    else
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
        character_chars["heightduck"] = math.Round( entity:GetBonePosition( bone ).z )
        if character_chars["heightduck"] < 4 then
            character_chars["heightduck"] = 4
        end
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
    local model = ply:GetInfo( "cl_playermodel" )
    local character_chars = characters_chars[model]

    if not character_chars then return end
    ply:SetViewOffsetDucked( Vector( 0, 0, character_chars["heightduck"] ) )
    ply:SetViewOffset( Vector( 0, 0, character_chars["height"] ) )

    ply:SetHull( Vector( -character_chars["hull"], -character_chars["hull"], 0 ), Vector( character_chars["hull"], character_chars["hull"], character_chars["hullz"] ) )
    ply:SetHullDuck( Vector( -character_chars["hull"], -character_chars["hull"], 0 ), Vector( character_chars["hull"], character_chars["hull"], character_chars["hullzduck"] ) )

    ply:SetStepSize( character_chars["stepsize"] )

    local newMaxHealth = character_chars["health"]
    ply.Glee_BaseHealth = newMaxHealth
    ply:SetMaxHealth( newMaxHealth )

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

    end )
end )

hook.Add( "PlayerTick", "GLEE_PDM:PlayerTick", function( ply )
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