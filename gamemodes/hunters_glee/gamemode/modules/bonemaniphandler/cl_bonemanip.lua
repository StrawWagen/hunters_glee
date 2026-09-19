
-- Carries the server's bone manipulations over onto clientside death ragdolls.

local identityScale = Vector( 1, 1, 1 )
local identityPos = Vector( 0, 0, 0 )
local identityAng = Angle( 0, 0, 0 )

-- A ragdoll bone that's already manipulated is left alone. Other CreateClientsideRagdoll hooks manipulate ragdolls
-- too, and hook order isn't fixed, so skipping them is what lets theirs win whether they ran before or after this.
local function copyBone( ent, bone, ragdoll, ragdollBone )
    local scale = ent:GetManipulateBoneScale( bone )
    if scale ~= identityScale and ragdoll:GetManipulateBoneScale( ragdollBone ) == identityScale then
        ragdoll:ManipulateBoneScale( ragdollBone, scale )

    end

    local pos = ent:GetManipulateBonePosition( bone )
    if pos ~= identityPos and ragdoll:GetManipulateBonePosition( ragdollBone ) == identityPos then
        ragdoll:ManipulateBonePosition( ragdollBone, pos )

    end

    local ang = ent:GetManipulateBoneAngles( bone )
    if ang ~= identityAng and ragdoll:GetManipulateBoneAngles( ragdollBone ) == identityAng then
        ragdoll:ManipulateBoneAngles( ragdollBone, ang )

    end
end

hook.Add( "CreateClientsideRagdoll", "glee_copybonemanips", function( ent, ragdoll )
    if not IsValid( ent ) or not IsValid( ragdoll ) then return end
    if not ent:HasBoneManipulations() then return end

    for bone = 0, ( ent:GetBoneCount() or 0 ) - 1 do
        local ragdollBone = ragdoll:LookupBone( ent:GetBoneName( bone ) )
        if ragdollBone then
            copyBone( ent, bone, ragdoll, ragdollBone )

        end
    end
end )
