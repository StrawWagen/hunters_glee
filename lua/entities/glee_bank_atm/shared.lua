ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category  = "Hunter's Glee"
ENT.PrintName = "Bank ATM"
ENT.Author    = "StrawWagen"
ENT.Spawnable = true
ENT.AdminOnly = game.IsDedicated()
ENT.RenderGroup = RENDERGROUP_BOTH -- the rocket's landing burn draws in DrawTranslucent

ENT.TransactionAmount       = 1000
ENT.DeadTransactionAmount   = 666
ENT.TransactionCooldown     = 0.25
ENT.TransactionCooldownDead = 1

function ENT:SetupDataTables()
    self:NetworkVar( "String", "State" )         -- "usable" | "arriving" | "broken"
    self:NetworkVar( "String", "ArrivalMethod" ) -- key into ENT.ArrivalMethods
    self:NetworkVar( "Bool",   "RocketBurning" ) -- engines lit, drives the flame effect
    self:NetworkVar( "Int",    "OwnersCut" )     -- score accumulating for the ATM owner
    self:NetworkVar( "Entity", "AtmOwner" )      -- purchasing player; NULL for auto-spawned ATMs

end

-- cl_plynames module draws a name panel for anything with a Nick
function ENT:Nick()
    if self:Health() > 0 then return "The ATM" end
    if self:Health() > 0 then return "A Dead ATM" end

end

local atmColor = Vector( 255, 190, 0 ) / 255
function ENT:GetPlayerColor()
    return atmColor

end

-- Returns true, or false + reason if the player cannot deposit right now.
function ENT:CanDeposit( ply )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not ply:BankHasAccount() then return false, "Click to open a bank account." end
    if ply:GetScore() <= 0 then return false, "No score to deposit" end
    return true

end

-- Returns true, or false + reason if the player cannot withdraw right now.
function ENT:CanWithdraw( ply )
    if self:GetState() ~= "usable" then return false, "ATM is not usable right now" end
    if not ply:BankHasAccount() then return false, "Click to open a bank account." end

    local bankFunds  = ply:GetNW2Int( "Glee_BankFunds", 0 )
    local minFunds   = gleefunc_BankMinFunds()
    local cap        = ply:Alive() and self.TransactionAmount or self.DeadTransactionAmount
    local toWithdraw = math.min( cap, math.max( 0, bankFunds - minFunds ) )

    if toWithdraw < cap then return false, "Your funds are too low.\nThe ATM's withdrawl threshold is 1000 score." end
    return true

end

--[[---------------------------------------------------------
    Arrival methods

    An arrival method is a property of a POSITION, not something anyone picks.
    terminator_Extras.glee_ATMArrivalAt walks this table in order, taking the first that
    fits, so the order below is the price of every spot on the map.

    init.lua fills in the half that moves the ATM: StartPos, Move, and the effects.
-----------------------------------------------------------]]

terminator_Extras = terminator_Extras or {}

-- ENT is the shared global that every entity's files are loaded against, so anything
-- outliving this file has to hold the table itself, not reach through ENT for it.
local arrivalMethods = {}
ENT.ArrivalMethods = arrivalMethods

local function addArrivalMethod( method )
    arrivalMethods[#arrivalMethods + 1] = method
    arrivalMethods[method.name] = method

end

local belowCenterChecks = {
    Vector( 0, 0, -100 ),
    Vector( 0, 0, -200 ),
    Vector( 0, 0, -300 ),
    Vector( 0, 0, -600 ),
    Vector( 0, 0, -900 ),
    Vector( 0, 0, -1200 ),
}

-- The ATM drills up to the surface, so it needs unbroken solid the whole way down.
local function canBurrowUpAt( pos )
    for _, check in ipairs( belowCenterChecks ) do
        local checkPos = pos + check
        local solid = bit.band( util.PointContents( checkPos ), CONTENTS_SOLID ) ~= 0
        if not solid then
            -- if it's under a displacement, it's solid
            local definitelyUnder, probablyUnder = terminator_Extras.posIsUnderDisplacement( checkPos )
            if definitelyUnder or probablyUnder then
                solid = true

            end
        end

        if not solid then return false end

    end

    return true

end

local rocketSkyCheckOffset = Vector( 0, 0, 60 )

-- Open sky on its own isn't enough. The descent freefalls and then burns that speed
-- off again, and under this it has room for neither, so the spot prices up instead.
local rocketMinClearance = 700

local function canRocketDownAt( pos )
    local checkPos = pos + rocketSkyCheckOffset

    local underSky, skyPos = GAMEMODE:IsUnderSky( checkPos )

    if not underSky then return false end

    return ( skyPos.z - checkPos.z ) >= rocketMinClearance

end

--local function anywhereAtAll()
--    return true
--
--end

addArrivalMethod( {
    name       = "burrow",
    cost       = 750,
    duration   = 3,
    depth      = 1000,
    ejectDelay = 0.25,
    canPlaceAt = canBurrowUpAt,
} )

addArrivalMethod( {
    name       = "rocket",
    cost       = 1500,
    ejectDelay = 1,
    canPlaceAt = canRocketDownAt,

    gravity         = 600,  -- source units, matches sv_gravity's default
    thrust          = 1400, -- upward accel once the engines light, so 800 net
    entryHeight     = 6000, -- how far above the pad it enters, when the sky allows
    igniteMargin    = 1.05, -- burn this much earlier than the maths demands
    minIgniteHeight = 300,  -- always light the engines by here, however slow the fall
    touchdownSpeed  = 40,   -- never descends slower than this, so it can't hover
    releaseHeight   = 40,   -- a couple of feet up, where the engines quit and it drops

    -- the last couple of feet are a real fall, so nothing may put it back on the pad
    physicsLanding = true,

    -- the exhaust plume, for as long as the engines are lit
    blastRange  = 550, -- roughly; FindInCone's cone is cut from a box, so it overreaches
    blastCone   = 0.8, -- FindInCone's angle_cos, so roughly 35 degrees off straight down
    blastDamage = 5,   -- per pass, and Move runs the plume ten times a second
    blastForce  = 500,
    blastIgnite = { 2, 4 },
} )

-- Unfinished. While it is out there is no arrival that works everywhere, so
-- glee_ATMArrivalAt returns nil for spots that can neither be burrowed to nor
-- rocketed into, and those spots have no price at all rather than an expensive one.
--addArrivalMethod( {
--    name       = "teleport",
--    cost       = 3000,
--    duration   = 0.5,
--    ejectDelay = 0,
--    hidden     = true,
--    canPlaceAt = anywhereAtAll,
--} )

local roomCheckStartOffset = Vector( 0, 0, 5 )
local roomCheckOffset = Vector( 0, 0, 40 )

-- Whether an ATM fits here at all, before any question of how it would arrive.
local function hasRoomForATM( pos )
    local tr = util.TraceLine( {
        start  = pos + roomCheckStartOffset,
        endpos = pos + roomCheckOffset,
        mask   = MASK_SOLID_BRUSHONLY,
    } )

    return not tr.Hit

end

-- The cheapest arrival that works at pos, as a method name and the score it costs.
-- nil when no method can reach it, which is most enclosed spots while teleport is out.
function terminator_Extras.glee_ATMArrivalAt( pos )
    if not hasRoomForATM( pos ) then return nil end

    -- canRocketDownAt needs IsUnderSky, which only the glee gamemode has; everywhere
    -- else burrows, as the sandbox spawn always did
    if not GAMEMODE.IsUnderSky then
        local fallback = arrivalMethods[1]
        return fallback.name, fallback.cost

    end

    for _, method in ipairs( arrivalMethods ) do
        if method.canPlaceAt( pos ) then return method.name, method.cost end

    end
end

-- What the cheapest arrival anywhere would cost, for shop checks that run before
-- there is a position to price.
function terminator_Extras.glee_CheapestATMCost()
    return arrivalMethods[1].cost

end

-- There is only ever one ATM. Dormant clientside entities are still real ones.
function terminator_Extras.glee_ATMExists()
    for _, ent in ipairs( ents.FindByClass( "glee_bank_atm" ) ) do
        if CLIENT and ent:IsDormant() then continue end
        if IsValid( ent ) and ent:GetState() ~= "broken" then return true end

    end
    return false

end
