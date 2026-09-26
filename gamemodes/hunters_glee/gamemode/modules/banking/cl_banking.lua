local bankFunctions = GM.bankFunctions
local GAMEMODE = GAMEMODE or GM

-- rebuilt from the NW2 vars sv_banking's checkBankAccount pushes, nil when there's no account
bankFunctions.checkBankAccount = function( ply )
    local has = ply:GetNW2Bool( "Glee_HasBankAccount", false )
    if not has then return end

    local funds = ply:GetNW2Int( "Glee_BankFunds", 0 )

    local items = {}
    for name in pairs( GAMEMODE.bankItems ) do
        if not ply:GetNW2Bool( "Glee_BankItem_" .. name, false ) then continue end

        local expires = ply:GetNW2Int( "Glee_BankItemExpires_" .. name, 0 )
        if expires == 0 then
            expires = nil

        end
        items[name] = { expires = expires }

    end

    return { funds = funds, items = items }

end

local meta = FindMetaTable( "Player" )

-- nil when there's no account
function meta:BankFunds()
    if not self:GetNW2Bool( "Glee_HasBankAccount", false ) then return end
    return self:GetNW2Int( "Glee_BankFunds", 0 )

end

local nextAsk = 0
local currCallback
function GAMEMODE:RequestAllBankAccounts( callback )
    if nextAsk > CurTime() then return false end
    nextAsk = CurTime() + 1

    net.Start( "glee_requestallbankaccounts" )
    net.SendToServer()
    currCallback = callback

    return true

end

net.Receive( "glee_requestallbankaccounts", function()
    if not currCallback then return end

    local accounts = {}
    local count = net.ReadUInt( 32 )
    for _ = 1, count do
        local steamID = net.ReadString()
        local ownersName = net.ReadString()
        local funds = net.ReadUInt( 32 )
        accounts[steamID] = {
            ownersName = ownersName,
            funds = funds,

        }
    end
    currCallback( accounts )
    currCallback = nil

end )
