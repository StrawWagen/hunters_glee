--- Special button only for traitors and usable from range

ENT.Type = "anim"
ENT.Base = "base_anim"

function ENT:SetupDataTables()
   self:NetworkVar("Float", 0, "Delay")
   self:NetworkVar("Float", 1, "NextUseTime")
   self:NetworkVar("Bool", 0, "Locked")
   self:NetworkVar("String", 0, "Description")
   self:NetworkVar("Int", 0, "UsableRange", {KeyName = "UsableRange"})
end

function ENT:IsUsable()
   local usable = true
   if self:GetLocked() then
      usable = false
      reason = "Button is locked"

   elseif self:GetNextUseTime() > CurTime() then
      usable = false
      reason = "Traitor button isn't usable yet"

   end
   return usable, reason

end