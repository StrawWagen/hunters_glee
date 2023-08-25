function EFFECT:Init( data )
    self.Origin = data:GetOrigin()
    self.Scale = 100 * data:GetScale()
    self.Delay = math.min( data:GetScale(), 1 )
    self.EndTime = CurTime() + self.Delay

    self.RenderSize = Vector( self.Scale, self.Scale, self.Scale )

end

function EFFECT:Think()
    if self.EndTime < CurTime() then
        return false
    else
        return true
    end
end

local flashMat = CreateMaterial( "xeno/scoreball", "UnlitGeneric", {
    ["$basetexture"] = "sprites/lamphalo1",
    ["$additive"] = "1",
    ["$vertexcolor"] = "1",
    ["$vertexalpha"] = "1",
} )

function EFFECT:Render()
    self:SetRenderBoundsWS( self.Origin, self.Origin, self.RenderSize )

    render.SetMaterial( flashMat )
    local timeToEnd = ( CurTime() - self.EndTime ) / self.Delay
    local drawScale = self.Scale * timeToEnd
    render.DrawSprite( self.Origin, drawScale, drawScale, color_white )

end