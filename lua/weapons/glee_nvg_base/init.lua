AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

-- the server side of the goggles, flipping them and keeping who has them on right

local nwKey = "glee_nvg_on"
local toggleCooldown = 0.4

local function turnOff( self, owner )
    if not IsValid( owner ) or not owner:IsPlayer() then return end
    if owner:GetGleeNVGOnClass() ~= self:GetClass() then return end
    owner:SetGleeNVGOn( nil, true )

end

function SWEP:OnDrop()
    turnOff( self, self.glee_LastNVGOwner )

end

function SWEP:OnRemove()
    turnOff( self, self:GetOwner() )

end

function SWEP:Equip( owner )
    self.glee_LastNVGOwner = owner

end

local plyMeta = FindMetaTable( "Player" )

function plyMeta:SetGleeNVGOn( class, quiet )
    class = class or ""
    local old = self:GetNW2String( nwKey, "" )
    if old == class then return end

    self:SetNW2String( nwKey, class )
    if quiet then return end

    local stored = weapons.GetStored( class ~= "" and class or old )
    local base = weapons.GetStored( "glee_nvg_base" )
    local snd = class == "" and ( stored and stored.GleeNVGOffSound or base.GleeNVGOffSound ) or ( stored and stored.GleeNVGOnSound or base.GleeNVGOnSound )
    self:EmitSound( snd, 60, math.random( 95, 105 ), 0.8 )

end

-- flip the goggles in the inventory down, or back up. called by the goggles' left click
function plyMeta:ToggleGleeNVG()
    if not self:Alive() then return end
    local nextToggle = self.glee_NextNVGToggle or 0
    if nextToggle > CurTime() then return end

    local wep = self:GetGleeNVG()
    if not IsValid( wep ) then self:SetGleeNVGOn( nil, true ) return end

    self.glee_NextNVGToggle = CurTime() + toggleCooldown
    if self:GetGleeNVGOnClass() ~= "" then
        self:SetGleeNVGOn( nil )

    else
        self:SetGleeNVGOn( wep:GetClass() )

    end
end

hook.Add( "PlayerDeath", "glee_nvg_off", function( ply ) ply:SetGleeNVGOn( nil, true ) end )
hook.Add( "PlayerSpawn", "glee_nvg_off", function( ply ) ply:SetGleeNVGOn( nil, true ) end )

-- only one pair of goggles in the inventory, whatever the kind
hook.Add( "PlayerCanPickupWeapon", "glee_nvg_onlyone", function( ply, wep )
    if not wep.IsGleeNVG then return end
    if IsValid( ply:GetGleeNVG() ) then return false end

end )

-- goggles that left the inventory, thrown, stripped or removed, can't stay on
timer.Create( "glee_nvg_validate", 0.5, 0, function()
    for _, ply in player.Iterator() do
        local class = ply:GetGleeNVGOnClass()
        if class ~= "" and not ply:HasWeapon( class ) then
            ply:SetGleeNVGOn( nil, true )

        end
    end
end )
