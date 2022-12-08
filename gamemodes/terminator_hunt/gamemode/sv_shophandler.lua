
 
function GM:purchaseItem( ply, argStr )
    --print( ply, argStr )
    if not GAMEMODE:canPurchase( ply, argStr ) then return end
    local dat = GAMEMODE.shopItems[argStr]
    local func = dat.purchaseFunc
    local repeated = nil
    if not func then return end
    func( ply, repeated ) 
end
 
 concommand.Add( "termhunt_purchase", function( ply, _, args, _ )
    GAMEMODE:purchaseItem( ply, args[1] )
    
 end, nil, "purchase an item", FCVAR_NONE )

-- items
    -- table of tables
    -- key
        -- name
        -- repeatable
        -- function
        -- description
        -- initial cost 

-- purchaser
    -- check if the round is in the right state to allow this 
    -- checks if player has enough frags to purchase
    -- if does,
    -- takes score and
    -- runs functions on player

    -- if it's repeatable then let them click the button multiple times
    -- else just let them click once per round

    -- save a table of purchased items on player
    -- give people a wipe all button that gives 50% refunds