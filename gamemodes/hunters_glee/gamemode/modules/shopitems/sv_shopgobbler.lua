local GM = GM or GAMEMODE

local shopHelpers = GM.shopHelpers

local validPrefixes = {
    ["sh_"] = true,
    ["sv_"] = true,
    ["cl_"] = true,
}

function GM:ShopInitialThink()
    self:SetupShopCategories()

    self.shopItems = {}
    self.validServerItemDirectories = {}
    self.validClientItemDirectories = {}

    local shopFiles = file.Find( "glee_shopitems/*.lua", "LUA" )
    for _, name in ipairs( shopFiles ) do
        local prefix = string.sub( name, 1, 3 )
        if not validPrefixes[ prefix ] then
            ErrorNoHaltWithStack( "GLEE: Invalid shop item prefix " .. prefix .. " in file " .. name .. "\nNeeds to be sh_, sv_, or cl_" )
            continue

        end

        local shared = prefix == "sh_"
        local server = prefix == "sv_"
        local client = prefix == "cl_"

        local gobbleSv = server or shared
        local gobbleCl = client or shared

        if gobbleSv then
            local ok = ProtectedCall( function( nameProtected ) include( "glee_shopitems/" .. nameProtected ) end, name )

            if ok then
                self.validServerItemDirectories[ name ] = true

            end
        end
        if gobbleCl then
            AddCSLuaFile( "glee_shopitems/" .. name )
            self.validClientItemDirectories[ name ] = true

        end
    end
    local count = 0
    for shopItemName, shopItem in pairs( self.shopItems ) do
        if self:AddShopItem( shopItemName, shopItem ) then
            count = count + 1

        end
    end
    print( "GLEE: SV Gobbled " .. count .. " shop items..." )

    GAMEMODE:UpdateShopFor( player.GetAll() )

    self.GobbledShopItems = true
    hook.Run( "glee_post_shopitemgobble" )

end

util.AddNetworkString( "glee_gobbledirectories" )

function GM:UpdateShopFor( plyOrPlys )
    net.Start( "glee_gobbledirectories" )
        net.WriteUInt( table.Count( GAMEMODE.validClientItemDirectories ), 16 )
        for dir, _ in pairs( GAMEMODE.validClientItemDirectories ) do
            net.WriteString( dir )

        end
    net.Send( plyOrPlys )

end

hook.Add( "glee_full_load", "glee_shopgobbler_requestgobble", function( ply )
    GAMEMODE:UpdateShopFor( ply )

end )

function GM:GobbleShopItems( items )
    for name, data in pairs( items ) do
        self.shopItems[ name ] = data

    end
end

function GM:SetupShopItem() -- todo, finish
    return true

end