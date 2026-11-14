-- The riot shield's drawing, included by shared.lua
-- shields draw as their own IMeshes, copies of the model bent further out of shape the more worn they are
-- a model can't be bent for real, it's got one bone
-- start at the bottom, drawMeshes, everything above builds what it draws
-- the building's split by how often it changes, per model, per shield, then per rebuild

-- how far, in units, a shield about to break is bent out of shape, in the middle and at the edges
-- cell is how far apart, in units, the bends are, nearby points always move nearly together
-- a short cell with a big push tears apart pieces of the model that only touch, like the straps
-- a list, each layer's place in it goes into its noise, so every client bends a shield the same
local deform = {
    { cell = 16, middle = 2, edge = 4 }, -- broad bends
    { cell = 5, middle = 0, edge = 1 }, -- crumpled edges
}

-- no edge longer than this, in units
-- a big flat triangle can't bend, the strap panels in front of one sank behind it
local longestEdge = 4

-- wear's rounded to this many steps, so a shield's rebuilt at most this many times
local wearSteps = 20

-- a rebuild's spread across frames, getting this many seconds of each, the old one's drawn until it's done
local buildBudget = 0.001
-- triangles per IMesh, the smallest bit of a rebuild that can't be split across frames
local chunkTriangles = 512


-- Spreading the work across frames
-- every build runs in a coroutine, these yield it once the frame's share runs out

local buildDeadline = 0 -- set as each frame's share starts, see stepBuild

local function outOfTime()
    return SysTime() > buildDeadline

end

local function yieldIfOutOfTime()
    if outOfTime() then coroutine.yield() end

end


-- Per model, built once
-- what util.GetModelMeshes gives, subdivided, then flattened into arrays of numbers
-- one entry per vertex of every triangle, so a rebuild makes no tables or vectors
-- each vertex points at a spot, every copy of it in any triangle shares one, front and back too
-- and the bind pose of its one bone, the vertices are posed by it

-- how far y, z is from center, looking down the model's forward, the axis it's thin along
local function flatDistance( y, z, center )
    return math.sqrt( ( y - center.y ) ^ 2 + ( z - center.z ) ^ 2 )

end

local function midpoint( a, b )
    local normal = a.normal + b.normal
    normal:Normalize()
    return { pos = ( a.pos + b.pos ) * 0.5, normal = normal, u = ( a.u + b.u ) * 0.5, v = ( a.v + b.v ) * 0.5 }

end

-- halves the longest edge until none are too long, see longestEdge
-- split by length alone, at the middle, so a triangle and its neighbour split their shared edge at the same points
-- or there'd be cracks between them once it's bent
local function subdivide( a, b, c, out )
    local ab, bc, ca = a.pos:DistToSqr( b.pos ), b.pos:DistToSqr( c.pos ), c.pos:DistToSqr( a.pos )
    local longest = math.max( ab, bc, ca )
    if longest <= longestEdge ^ 2 then
        out[#out + 1] = a
        out[#out + 1] = b
        out[#out + 1] = c
        return

    end

    -- kept in the same winding
    if longest == ab then
        local mid = midpoint( a, b )
        subdivide( a, mid, c, out )
        subdivide( mid, b, c, out )

    elseif longest == bc then
        local mid = midpoint( b, c )
        subdivide( a, b, mid, out )
        subdivide( a, mid, c, out )

    else
        local mid = midpoint( c, a )
        subdivide( a, b, mid, out )
        subdivide( mid, b, c, out )

    end
end

local modelData = {}

-- only inside a build's coroutine, it yields
-- two shields building the same model at once both work it out, the last one done is kept
local function modelDataFor( model )
    local data = modelData[model]
    if data then return data end

    local meshes, bindPoses = util.GetModelMeshes( model )
    meshes = meshes or {}
    local rootPose = bindPoses and ( bindPoses[0] or bindPoses[1] )
    data = {
        bindPose = rootPose and rootPose.matrix or Matrix(),
        parts = {},
        spotY = {},
        spotZ = {},
        spotEdge = {}, -- 0 at the middle, 1 at the furthest edge
    }

    -- from the model as it is, the subdivided bits would pull it towards wherever's most split
    local center = Vector()
    local count = 0
    for _, source in ipairs( meshes ) do
        for _, vert in ipairs( source.triangles ) do
            center:Add( vert.pos )
            count = count + 1

        end
    end
    center:Div( math.max( count, 1 ) )

    local spotY, spotZ = data.spotY, data.spotZ
    local spotIds = {}
    for _, source in ipairs( meshes ) do
        local triangles = {}
        local sourceTriangles = source.triangles
        for index = 1, #sourceTriangles - 2, 3 do
            if index % 192 == 1 then yieldIfOutOfTime() end

            subdivide( sourceTriangles[index], sourceTriangles[index + 1], sourceTriangles[index + 2], triangles )

        end

        local mat = Material( source.material )
        local part = {
            material = mat,
            translucent = bit.band( mat:GetInt( "$flags" ) or 0, 2097152 ) ~= 0, -- MATERIAL_VAR_TRANSLUCENT
            count = #triangles,
            spot = {},
            px = {}, py = {}, pz = {},
            nx = {}, ny = {}, nz = {},
            u = {}, v = {},
            -- per triangle, its normal before it's bent
            fx = {}, fy = {}, fz = {},
        }

        for index, vert in ipairs( triangles ) do
            if index % 256 == 0 then yieldIfOutOfTime() end

            local pos, normal = vert.pos, vert.normal
            part.px[index], part.py[index], part.pz[index] = pos.x, pos.y, pos.z
            part.nx[index], part.ny[index], part.nz[index] = normal.x, normal.y, normal.z
            part.u[index], part.v[index] = vert.u, vert.v

            local key = pos.y .. " " .. pos.z
            local spot = spotIds[key]
            if not spot then
                spot = #spotY + 1
                spotIds[key] = spot
                spotY[spot], spotZ[spot] = pos.y, pos.z

            end
            part.spot[index] = spot

        end

        for tri = 1, #triangles / 3 do
            if tri % 256 == 0 then yieldIfOutOfTime() end

            local a, b, c = triangles[tri * 3 - 2], triangles[tri * 3 - 1], triangles[tri * 3]
            local face = ( b.pos - a.pos ):Cross( c.pos - a.pos )
            face:Normalize()
            if face:Dot( a.normal + b.normal + c.normal ) < 0 then face:Mul( -1 ) end
            part.fx[tri], part.fy[tri], part.fz[tri] = face.x, face.y, face.z

        end

        data.parts[#data.parts + 1] = part

    end

    local reach = 1
    for spot = 1, #spotY do
        reach = math.max( reach, flatDistance( spotY[spot], spotZ[spot], center ) )

    end
    for spot = 1, #spotY do
        data.spotEdge[spot] = flatDistance( spotY[spot], spotZ[spot], center ) / reach

    end

    modelData[model] = data
    return data

end


-- Per shield, worked out once
-- how far each spot goes at full wear, a rebuild just scales it

-- -1 to 1, the same for the same n every time, on every client
-- not util.SharedRandom, it mixes in the prediction seed, a shield would change shape every rebuild
local function hashed( n )
    local scrambled = math.sin( n ) * 43758.5453
    return ( scrambled - math.floor( scrambled ) ) * 2 - 1

end

-- a random push at each corner of a grid
local function cornerPush( seed, layer, axis, y, z )
    return hashed( seed * 7.13 + layer * 101.7 + axis * 37.719 + y * 12.9898 + z * 78.233 )

end

local function smoothstep( t )
    return t * t * ( 3 - 2 * t )

end

-- blended between the four grid corners around y, z, so it changes smoothly across the shield
local function smoothPush( seed, layer, axis, cell, y, z )
    local gridY, gridZ = y / cell, z / cell
    local y0, z0 = math.floor( gridY ), math.floor( gridZ )
    local alongY, alongZ = smoothstep( gridY - y0 ), smoothstep( gridZ - z0 )

    local a = cornerPush( seed, layer, axis, y0, z0 )
    local b = cornerPush( seed, layer, axis, y0 + 1, z0 )
    local c = cornerPush( seed, layer, axis, y0, z0 + 1 )
    local d = cornerPush( seed, layer, axis, y0 + 1, z0 + 1 )
    local low = a + ( b - a ) * alongY
    local high = c + ( d - c ) * alongY
    return low + ( high - low ) * alongZ

end

-- forward's left out of where a spot is, so the front and back move in lockstep, it's too thin to bend them apart
-- only inside a build's coroutine, it yields
local function pushesFor( shield, data )
    if shield.glee_PushesFor == data then return shield.glee_Pushes end

    local seed = shield:EntIndex()
    local pushX, pushY, pushZ = {}, {}, {}
    for spot = 1, #data.spotY do
        if spot % 64 == 0 then yieldIfOutOfTime() end

        local y, z, edge = data.spotY[spot], data.spotZ[spot], data.spotEdge[spot]
        local x, yPush, zPush = 0, 0, 0
        for layerIndex, layer in ipairs( deform ) do
            local amount = Lerp( edge, layer.middle, layer.edge )
            x = x + smoothPush( seed, layerIndex, 1, layer.cell, y, z ) * amount
            yPush = yPush + smoothPush( seed, layerIndex, 2, layer.cell, y, z ) * amount
            zPush = zPush + smoothPush( seed, layerIndex, 3, layer.cell, y, z ) * amount

        end
        pushX[spot], pushY[spot], pushZ[spot] = x, yPush, zPush

    end

    -- data's remade on autorefresh, so new deform settings get picked up
    shield.glee_Pushes = { x = pushX, y = pushY, z = pushZ }
    shield.glee_PushesFor = data
    return shield.glee_Pushes

end


-- Per rebuild
-- straight into the IMesh, through these two, reused
-- nothing between mesh.Begin and mesh.End can error, it'd leave the builder open
local scratchPos, scratchNormal = Vector(), Vector()

-- each vertex's normal turns as far as its face did, so an unworn shield shades just like the model
local function emitVertex( part, index, x, y, z, turnX, turnY, turnZ )
    local nx, ny, nz = part.nx[index] + turnX, part.ny[index] + turnY, part.nz[index] + turnZ
    local length = math.sqrt( nx * nx + ny * ny + nz * nz )
    if length > 0 then
        nx, ny, nz = nx / length, ny / length, nz / length

    end

    scratchPos:SetUnpacked( x, y, z )
    scratchNormal:SetUnpacked( nx, ny, nz )
    mesh.Position( scratchPos )
    mesh.Normal( scratchNormal )
    mesh.TexCoord( 0, part.u[index], part.v[index] )
    mesh.AdvanceVertex()

end

-- part's triangles first to last, as one IMesh
local function buildChunk( part, pushes, wear, first, last )
    local px, py, pz, spots = part.px, part.py, part.pz, part.spot
    local pushX, pushY, pushZ = pushes.x, pushes.y, pushes.z

    local imesh = Mesh()
    mesh.Begin( imesh, MATERIAL_TRIANGLES, last - first + 1 )
    for tri = first, last do
        local i1 = tri * 3 - 2
        local i2, i3 = i1 + 1, i1 + 2
        local s1, s2, s3 = spots[i1], spots[i2], spots[i3]

        local ax, ay, az = px[i1] + pushX[s1] * wear, py[i1] + pushY[s1] * wear, pz[i1] + pushZ[s1] * wear
        local bx, by, bz = px[i2] + pushX[s2] * wear, py[i2] + pushY[s2] * wear, pz[i2] + pushZ[s2] * wear
        local cx, cy, cz = px[i3] + pushX[s3] * wear, py[i3] + pushY[s3] * wear, pz[i3] + pushZ[s3] * wear

        local e1x, e1y, e1z = bx - ax, by - ay, bz - az
        local e2x, e2y, e2z = cx - ax, cy - ay, cz - az
        local fx, fy, fz = e1y * e2z - e1z * e2y, e1z * e2x - e1x * e2z, e1x * e2y - e1y * e2x
        local length = math.sqrt( fx * fx + fy * fy + fz * fz )
        if length > 0 then
            fx, fy, fz = fx / length, fy / length, fz / length

        end

        local beforeX, beforeY, beforeZ = part.fx[tri], part.fy[tri], part.fz[tri]
        if fx * beforeX + fy * beforeY + fz * beforeZ < 0 then
            fx, fy, fz = -fx, -fy, -fz

        end
        local turnX, turnY, turnZ = fx - beforeX, fy - beforeY, fz - beforeZ

        emitVertex( part, i1, ax, ay, az, turnX, turnY, turnZ )
        emitVertex( part, i2, bx, by, bz, turnX, turnY, turnZ )
        emitVertex( part, i3, cx, cy, cz, turnX, turnY, turnZ )

    end
    mesh.End()

    return imesh

end

-- a build's coroutine, every IMesh it makes goes in made, so a cancelled one can be cleaned up
-- returns the meshes, and the bind pose they're drawn through
local function buildParts( shield, wear, made )
    local data = modelDataFor( shield:GetModel() )
    local pushes = pushesFor( shield, data )
    local parts = {}
    for _, part in ipairs( data.parts ) do
        local triangles = part.count / 3
        for first = 1, triangles, chunkTriangles do
            yieldIfOutOfTime()

            local imesh = buildChunk( part, pushes, wear, first, math.min( first + chunkTriangles - 1, triangles ) )
            made[#made + 1] = imesh
            parts[#parts + 1] = { mesh = imesh, material = part.material, translucent = part.translucent }

        end
    end
    return parts, data.bindPose

end


-- Managing builds
-- a shield draws its last finished build while the next one's going
-- all kept on the shield, so an autorefresh still finds and destroys them

local function cancelBuild( shield )
    local build = shield.glee_Build
    if not build then return end

    for _, imesh in ipairs( build.made ) do
        imesh:Destroy()

    end
    shield.glee_Build = nil

end

local function startBuild( shield, wear )
    cancelBuild( shield )

    local made = {}
    shield.glee_Build = {
        wear = wear,
        made = made,
        routine = coroutine.create( function() return buildParts( shield, wear, made ) end ),
    }
end

local function destroyShown( shield )
    for _, part in ipairs( shield.glee_Parts or {} ) do
        part.mesh:Destroy()

    end
    shield.glee_Parts = nil

end

local function destroyParts( shield )
    cancelBuild( shield )
    destroyShown( shield )
    shield.glee_PartsWear = nil

end

-- once a frame, however many passes draw it
local function stepBuild( shield )
    local build = shield.glee_Build
    if build.frame == FrameNumber() then return end

    build.frame = FrameNumber()
    buildDeadline = SysTime() + buildBudget

    local ok, parts, bindPose = coroutine.resume( build.routine )
    if not ok then
        ErrorNoHalt( "glee_shield rebuild failed: ", parts, "\n" )
        cancelBuild( shield )
        shield.glee_PartsWear = build.wear -- so it's not tried again every frame
        return

    end
    if coroutine.status( build.routine ) ~= "dead" then return end

    shield.glee_Build = nil -- its meshes are the shield's now, not the build's to clean up
    destroyShown( shield )
    shield.glee_Parts = parts
    shield.glee_PartsBindPose = bindPose
    shield.glee_PartsWear = build.wear

end

-- what to draw, nil until its first build's done
-- rebuilt as its wear crosses a step, see wearSteps
local function partsFor( shield )
    local wear = math.Round( shield:GetWear() * wearSteps ) / wearSteps
    local build = shield.glee_Build
    if shield.glee_PartsWear ~= wear and ( not build or build.wear ~= wear ) then
        startBuild( shield, wear )

    end

    if shield.glee_Build then
        stepBuild( shield )

    end
    return shield.glee_Parts

end


-- Drawing it

-- the ambient cube's sides, in BOX_FRONT to BOX_BOTTOM order
local cubeSides = {
    Vector( 1, 0, 0 ),
    Vector( -1, 0, 0 ),
    Vector( 0, 1, 0 ),
    Vector( 0, -1, 0 ),
    Vector( 0, 0, 1 ),
    Vector( 0, 0, -1 ),
}

-- what drawParts draws, set by drawMeshes just before
-- so render.RenderFlashlights can be handed the same function every time
local drawing = {}

local function drawParts()
    cam.PushModelMatrix( drawing.matrix )
    for _, part in ipairs( drawing.parts ) do
        if part.translucent ~= drawing.translucent then continue end

        render.SetMaterial( part.material )
        part.mesh:Draw()

    end
    cam.PopModelMatrix()

end

-- an IMesh gets no model lighting of its own, so it's sampled at the shield and set by hand
-- anything that can error goes before the render state's touched, an error after leaves it broken for the whole map
local function drawMeshes( shield, translucent )
    local parts = partsFor( shield )
    if not parts then -- its first build's still going
        shield:DrawModel()
        return

    end

    shield:SetupBones()
    local bone = shield:GetBoneMatrix( 0 )
    if not bone then return end

    drawing.matrix = bone * shield.glee_PartsBindPose -- bone matrices carry the model scale too
    drawing.parts = parts
    drawing.translucent = translucent

    local center = shield:WorldSpaceCenter()
    render.SuppressEngineLighting( true )
    for index, side in ipairs( cubeSides ) do
        local light = render.ComputeLighting( center, side ) + render.ComputeDynamicLighting( center, side )
        render.SetModelLighting( index - 1, light.x, light.y, light.z )

    end

    drawParts()
    -- flashlights are their own pass, the engine doesn't light an IMesh with them
    render.RenderFlashlights( drawParts )

    render.SuppressEngineLighting( false )

end

function ENT:Draw()
    drawMeshes( self, false )

end

function ENT:DrawTranslucent()
    drawMeshes( self, true )

end

function ENT:DestroyMeshes()
    destroyParts( self )

end
