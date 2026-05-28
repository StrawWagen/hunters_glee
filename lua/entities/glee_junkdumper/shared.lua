AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Junk Dumper"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Dumps Junk"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/blocks/cube2x2x1.mdl"

ENT.HullCheckSize = Vector( 47, 47, 19 )
ENT.PosOffset = Vector( 0, 0, -19 )
ENT.OverrideOffsetFromFloor = 100

ENT.JunkPerDrop = 6
ENT.NearbyRadius = 500
ENT.TooManyNearbyObjCount = 10 -- if above this count of nearby stuff, no longer profitable
ENT.CleanAreaScore = 100 -- score given when there are 0 nearby objects, further multiplied by nook score
ENT.ScoreMax = 100

ENT.CanPlaceColor = Color( 0, 255, 0, 100 )
ENT.CannotPlaceColor = Color( 255, 0, 0, 100 )

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreString = "Junk Dumping Score: " .. tostring( scoreGained )

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

function ENT:SkinRandomize()
    self:SetSkin( math.random( 0, self:SkinCount() ) )

end

if not SERVER then return end

function ENT:PostInitializeFunc()
    self:SetMaterial( "lights/white002" )

end

ENT.JunkModels = {
    "models/props_c17/bench01a.mdl",
    "models/props_c17/FurnitureDrawer001a.mdl",
    "models/props_c17/FurnitureDrawer001a_Chunk01.mdl",
    "models/props_c17/FurnitureDrawer001a_Chunk02.mdl",
    "models/props_c17/FurnitureDrawer001a_Chunk03.mdl",
    "models/props_c17/FurnitureDrawer001a_Chunk05.mdl",
    "models/props_c17/FurnitureDrawer001a_Chunk06.mdl",
    "models/props_c17/FurnitureDrawer002a.mdl",
    "models/props_c17/FurnitureDrawer003a.mdl",
    "models/props_c17/FurnitureDresser001a.mdl",
    "models/props_c17/FurnitureShelf001a.mdl",
    "models/props_c17/FurnitureShelf001b.mdl",
    "models/props_c17/FurnitureTable001a.mdl",
    "models/props_c17/FurnitureTable002a.mdl",
    "models/props_c17/FurnitureTable003a.mdl",
    "models/props_interiors/Furniture_shelf01a.mdl",
    "models/props_junk/cardboard_box001a.mdl",
    "models/props_junk/cardboard_box001b.mdl",
    "models/props_junk/cardboard_box002a.mdl",
    "models/props_junk/cardboard_box002b.mdl",
    "models/props_junk/cardboard_box004a.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/wood_crate001a_damagedmax.mdl",
    "models/props_junk/wood_crate001a_damaged.mdl",
    "models/props_junk/wood_crate002a.mdl",
    "models/props_junk/wood_pallet001a.mdl",
    "models/props_junk/wood_pallet001a_chunka.mdl",
    "models/props_junk/wood_pallet001a_chunka3.mdl",
    "models/props_junk/wood_pallet001a_chunka4.mdl",
    "models/props_junk/wood_pallet001a_chunkb2.mdl",
    "models/props_c17/furniturechair001a.mdl",
    "models/props_interiors/Furniture_chair01a.mdl",
    "models/props_interiors/Furniture_Couch01a.mdl",
    "models/props_interiors/Furniture_Couch02a.mdl",
    "models/props_c17/furniturearmchair001a.mdl",
    "models/props_c17/frame002a.mdl",
    "models/props_wasteland/barricade001a.mdl",
    "models/props_wasteland/barricade001a_chunk01.mdl",
    "models/props_wasteland/barricade001a_chunk02.mdl",
    "models/props_wasteland/barricade002a.mdl",
    "models/props_wasteland/barricade002a_chunk01.mdl",
    "models/props_wasteland/barricade002a_chunk02.mdl",
    "models/props_wasteland/cafeteria_bench001a.mdl",
    "models/props_wasteland/cafeteria_bench001a_chunk01.mdl",
    "models/props_wasteland/cafeteria_table001a.mdl",
    "models/props_wasteland/cafeteria_table001a_chunk01.mdl",
    "models/props_c17/playground_swingset_seat01a.mdl",
    "models/props_c17/playground_teetertoter_seat.mdl",
    "models/props_junk/garbage_coffeemug001a.mdl",
    "models/props_junk/garbage_glassbottle001a.mdl",
    "models/props_junk/garbage_glassbottle002a.mdl",
    "models/props_junk/garbage_glassbottle003a.mdl",
    "models/props_junk/glassjug01.mdl",
    "models/props_junk/GlassBottle01a.mdl",
    "models/props_junk/terracotta01.mdl",
    "models/props_wasteland/wood_fence02a_board01a.mdl",
    "models/props_wasteland/wood_fence02a_board03a.mdl",
    "models/props_wasteland/wood_fence02a_board04a.mdl",
    "models/props_wasteland/wood_fence02a_board05a.mdl",
    "models/props_wasteland/wood_fence02a_board07a.mdl",
    "models/props_wasteland/wood_fence02a_board08a.mdl",
    "models/props_wasteland/wood_fence02a_board09a.mdl",
    "models/props_wasteland/wood_fence02a.mdl",
    "models/props_canal/boat001a_chunk01.mdl",
    "models/props_canal/boat001a_chunk02.mdl",
    "models/props_canal/boat001a_chunk03.mdl",
    "models/props_canal/boat001a_chunk04.mdl",
    "models/props_canal/boat001a_chunk05.mdl",
    "models/props_canal/boat001a_chunk06.mdl",
    "models/props_canal/boat001a_chunk07.mdl",
    "models/props_canal/boat001a_chunk08.mdl",
    "models/props_canal/boat001b_chunk01.mdl",
    "models/props_canal/boat001b_chunk02.mdl",
    "models/props_canal/boat001b_chunk03.mdl",
    "models/props_canal/boat001b_chunk04.mdl",
    "models/props_canal/boat001b_chunk05.mdl",
    "models/props_canal/boat001b_chunk06.mdl",
    "models/props_canal/boat001b_chunk07.mdl",
    "models/props_canal/boat001b_chunk08.mdl",

    "models/props_debris/wood_board01a.mdl",
    "models/props_debris/wood_board02a.mdl",
    "models/props_debris/wood_board03a.mdl",
    "models/props_debris/wood_board04a.mdl",
    "models/props_debris/wood_board05a.mdl",
    "models/props_debris/wood_board06a.mdl",
    "models/props_debris/wood_board07a.mdl",

    "models/props_wasteland/dockplank_chunk01a.mdl",
    "models/props_docks/channelmarker_gib01.mdl",
    "models/props_docks/channelmarker_gib02.mdl",

    "models/props_wasteland/prison_toilet01.mdl",
    "models/props_wasteland/prison_sink001b.mdl",
    "models/props_junk/watermelon01.mdl",
    "models/props_combine/breenbust.mdl",
    "models/props_junk/watermelon01_chunk01c.mdl",
    "models/props_junk/vent001.mdl",
}

ENT.RareJunkChance = 2

ENT.RareJunkModels = {
    "models/props_junk/flare.mdl",
    "models/props_wasteland/interior_fence004b.mdl",
    "models/props_c17/fence01b.mdl",
    "models/props_c17/canister_propane01a.mdl",
    "models/props_c17/streetsign004f.mdl",
    "models/props_c17/oildrumchunk01a.mdl",
    "models/props_wasteland/gear01.mdl",
    "models/props_junk/Shoe001a.mdl",
    "models/props_junk/garbage_bag001a.mdl",
    "models/props_junk/gascan001a.mdl",
    "models/props_junk/sawblade001a.mdl",
    "models/props_vehicles/tire001c_car.mdl",
    "models/props_junk/TrafficCone001a.mdl",
    "models/props_junk/CinderBlock01a.mdl",
    "models/props_c17/TrapPropeller_Engine.mdl",
    "models/props_lab/hevplate.mdl",
    "models/props_vehicles/carparts_door01a.mdl",
    "models/props_debris/rebar_medthin02c.mdl",
}

function ENT:UpdateGivenScore()
    local myPos = self:GetPos()
    local nearby = ents.FindInSphere( myPos, self.NearbyRadius )

    local floorPos = terminator_Extras.getFloorTr( myPos ).HitPos
    local nearbyFloorPos = ents.FindInSphere( floorPos, self.NearbyRadius )
    terminator_Extras.tableAdd( nearby, nearbyFloorPos )

    local nearbyCount = 0

    for _, ent in ipairs( nearby ) do
        if not IsValid( ent ) then continue end
        if not ent:IsSolid() then continue end
        if not ent:Alive() then continue end
        if not IsValid( ent:GetPhysicsObject() ) then continue end
        local mass = ent:GetPhysicsObject():GetMass()
        if mass <= 5 then continue end
        nearbyCount = nearbyCount + 1

    end

    -- Clean area = profit, cluttered area = cost. Break-even at TooManyNearbyObjCount.
    local scoreGiven = self.CleanAreaScore * ( 1 - nearbyCount / self.TooManyNearbyObjCount )
    scoreGiven = math.min( scoreGiven, self.ScoreMax )
    local nookScore = terminator_Extras.GetNookScore( myPos )
    if nookScore <= 2 then -- too open
        scoreGiven = -math.abs( scoreGiven ) * 0.5

    else
        scoreGiven = scoreGiven + ( nookScore * 6 )

    end

    self:SetGivenScore( scoreGiven )

end

function ENT:Place()
    local betrayalScore = self:GetGivenScore()

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    for i = 1, self.JunkPerDrop do
        timer.Simple( ( i - 1 ) * 0.1, function()
            if not IsValid( self ) then return end

            local model
            if math.random( 1, 100 ) <= self.RareJunkChance then
                model = self.RareJunkModels[math.random( #self.RareJunkModels )]
            else
                model = self.JunkModels[math.random( #self.JunkModels )]
            end

            local junk = ents.Create( "prop_physics" )
            junk:SetPos( self:GetPos() + Vector( math.Rand( -50, 50 ), math.Rand( -50, 50 ), 10 ) )
            junk:SetModel( model )
            junk:SetAngles( Angle( 0, math.Rand( -180, 180 ), 0 ) )
            junk:Spawn()

            terminator_Extras.SmartSleepEntity( junk, 10 )
            timer.Simple( 0.1, function()
                terminator_Extras.DoPFXFromEnt( "glee_ghostly_ectoplasm", junk )

            end )

            junk:EmitSound( "physics/wood/wood_box_impact_hard1.wav", 65, 90 + math.random( -10, 10 ) )

        end )
    end

    self.player = nil
    self:SetOwner( NULL )

    timer.Simple( ( self.JunkPerDrop - 1 ) * 0.1 + 0.1, function()
        SafeRemoveEntity( self )

    end )
end