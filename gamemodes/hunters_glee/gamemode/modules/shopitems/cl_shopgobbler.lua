local nextRecieve = 0

local GM = GAMEMODE or GM

function GM:ShopInitialThink()
    self:SetupShopCategories()
    self.shopItems = {}
    self.validClientItemDirectories = {}

end

net.Receive( "glee_gobbledirectories", function()
    if nextRecieve > CurTime() then return end
    nextRecieve = CurTime() + 0.1

    local count = net.ReadUInt( 16 )
    GAMEMODE.validClientItemDirectories = GAMEMODE.validClientItemDirectories or {}

    for _ = 1, count do
        local dir = net.ReadString()
        local ok = ProtectedCall( function( dirProtected ) include( "glee_shopitems/" .. dirProtected ) end, dir )

        if ok then
            GAMEMODE.validClientItemDirectories[ dir ] = true

        end
    end
end )

function GM:GobbleShopItems( items )
    for name, data in pairs( items ) do
        local existingData = self.shopItems[ name ]
        if existingData then
            table.Merge( existingData, data )

        else
            self.shopItems[ name ] = data

        end
    end
end
