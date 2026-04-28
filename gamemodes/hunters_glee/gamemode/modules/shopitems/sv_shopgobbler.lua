local GM = GM or GAMEMODE

local validPrefixes = {
    ["sh_"] = true,
    ["sv_"] = true,
    ["cl_"] = true,
}

function GM:ShopInitialThink()
    self:SetupShopCategories()

    self.GobbledShopItems = nil

    self.invalidShopItems = {}
    self.shopItems = {}
    self.validServerItemDirectories = {}
    self.validClientItemDirectories = {}

    local shopFiles = file.Find( "glee_shopitems/*.lua", "LUA" )
    for _, name in ipairs( shopFiles ) do
        local prefix = string.sub( name, 1, 3 )
        if not validPrefixes[prefix] then
            ErrorNoHaltWithStack( "GLEE: Invalid shop item prefix " .. prefix .. " in file " .. name .. "\nNeeds to be sh_, sv_, or cl_" )
            continue

        end

        -- all items need to be defined on server & client
        -- this is literally just here for if you want to have private server logic, no other reason
        local shared = prefix == "sh_"
        local server = prefix == "sv_"
        local client = prefix == "cl_"

        local gobbleSv = server or shared
        local gobbleCl = client or shared

        if gobbleSv then
            local ok = ProtectedCall( function( nameProtected ) include( "glee_shopitems/" .. nameProtected ) end, name )

            if ok then
                self.validServerItemDirectories[name] = true

            end
        end
        if gobbleCl then
            AddCSLuaFile( "glee_shopitems/" .. name )
            self.validClientItemDirectories[name] = true

        end
    end

    -- actually add the items
    local count = 0
    for shopItemName, shopItem in pairs( self.shopItems ) do
        if self:AddShopItem( shopItemName, shopItem ) then
            count = count + 1

        end
    end

    print( "GLEE: SV Gobbled " .. count .. " shop items..." )

    self.GobbledShopItems = true
    hook.Run( "glee_post_shopitemgobble" )

end


-- send directories to clients
-- we never send items to clients
-- just tell them what to include()
util.AddNetworkString( "glee_gobbledirectories" )

function GM:UpdateShopFor( plyOrPlys )
    net.Start( "glee_gobbledirectories" )
        net.WriteUInt( table.Count( GAMEMODE.validClientItemDirectories ), 16 ) -- max 65,535 directories lol
        for dir, _ in pairs( GAMEMODE.validClientItemDirectories ) do
            net.WriteString( dir )

        end
    net.Send( plyOrPlys )

end


-- client wants shopitem data! we'll wait and send it after GM.GobbledShopItems is true
util.AddNetworkString( "glee_pleasepleasegivemeshopdata" )
net.Receive( "glee_pleasepleasegivemeshopdata", function( len, ply )
    local nextRequest = ply.glee_NextShopDataRequest or 0
    if CurTime() < nextRequest then return end
    ply.glee_NextShopDataRequest = CurTime() + 0.1

    local requestTimerName = "glee_pleasepleasegivemeshopdata_timer_" .. ply:GetCreationID()
    timer.Create( requestTimerName, 0.1, 1, function()
        if not IsValid( ply ) then timer.Remove( requestTimerName ) return end
        if not GAMEMODE.GobbledShopItems then return end -- wait....

        GAMEMODE:UpdateShopFor( ply )
        timer.Remove( requestTimerName )

    end )
end )


-- update on fullload
hook.Add( "glee_full_load", "glee_shopgobbler_requestgobble", function( ply )
    GAMEMODE:UpdateShopFor( ply )

end )


-- ran inside each shopitem folder
function GM:GobbleShopItems( items )
    for name, data in pairs( items ) do
        self.shopItems[name] = data
    end

    -- Alert, should only happen if something misuses the shop gobbler or if files are being re-run for dev testing.
    if self.GobbledShopItems then
        print( "GLEE: !!!!!!!!!! Gobbled shop items late, you must run gmod_admin_cleanup to apply the changes !!!!!!!!!!!" )
        -- Calling GM:ShopInitialThink() in luapad also works!

    end

end
