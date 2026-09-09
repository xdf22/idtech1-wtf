// somewhat inspired by my "obenjl" library
// except it works with chud framebuffers
// and has textured polygons instead of just quads and bilboarding
// oh my god this sucks

rawset(_G, "gl", {})

gl.cam = {x=0,y=0,z=0,yaw=0,pitch=0}

gl.depthClearValue = 0
gl.framebuffer = nil
gl.depthbuffer = nil

gl.camcos = 0
gl.camsin = 0
gl.campcos = 0
gl.campsin = 0

gl.centerX = 0
gl.centerY = 0
gl.fovX = 0
gl.fovY = 0

gl.near = 4*FU

function gl.updateCamera()
    gl.camcos = cos(-gl.cam.yaw)
    gl.camsin = sin(-gl.cam.yaw)

    gl.campcos = cos(-gl.cam.pitch)
    gl.campsin = sin(-gl.cam.pitch)
end

// sets gl.framebuffer and other stuff
function gl.setFramebuffer(framebuffer)
    gl.framebuffer = framebuffer

    gl.centerX = framebuffer.width * FU / 2
    gl.centerY = framebuffer.height * FU / 2

    gl.fovX = (framebuffer.width / 2) * FU
    gl.fovY = (framebuffer.width / 2) * FU

    gl.viewBottom = framebuffer.height - 24 / (200 / framebuffer.height)

    if not gl.depthbuffer or gl.depthbuffer.width != framebuffer.width or gl.depthbuffer.height != framebuffer.height then
        gl.depthbuffer =
        {
            values = {},
            width = framebuffer.width,
            height = framebuffer.height
        }

        for i = 1, framebuffer.width * framebuffer.height do
            gl.depthbuffer.values[i] = 0
        end
    end
end

function gl.clear(color)
    if not gl.framebuffer then
        return
    end

    local count = gl.framebuffer.width * gl.framebuffer.height

    for i = 1, count do
        gl.framebuffer.pixels[i] = color
        gl.depthbuffer.values[i] = gl.depthClearValue
    end
end

function gl.transformXYZ(x, y, z)
    if x == nil or y == nil or z == nil then
        return
    end

    x = $ - gl.cam.x
    y = $ - gl.cam.y
    z = $ - gl.cam.z

    local nx = doom.fixedMul(x, gl.camcos) - doom.fixedMul(y, gl.camsin)
    local ny = doom.fixedMul(x, gl.camsin) + doom.fixedMul(y, gl.camcos)

    x = nx
    y = ny

    local py = doom.fixedMul(y, gl.campcos) - doom.fixedMul(z, gl.campsin)
    local pz = doom.fixedMul(y, gl.campsin) + doom.fixedMul(z, gl.campcos)

    return x, py, pz
end

function gl.transformVertex(v)
    if not v then
        return nil
    end

    local x, y, z

    if v.x != nil then
        x = v.x
        y = v.y
        z = v.z
    else
        x = v[1]
        y = v[2]
        z = v[3]
    end

    if x == nil or y == nil or z == nil then
        return nil
    end

    return gl.transformXYZ(x, y, z)
end

function gl.getVertexXYZ(v)
    if not v then
        return nil, nil, nil
    end

    local x, y, z

    if v[1] != nil then
        x = v[1]
        y = v[2]
        z = v[3]
    elseif v.x != nil then
        x = v.x
        y = v.y
        z = v.z
    end

    return x, y, z
end

function gl.transformCachedVertex(v)
    if not v then
        return nil
    end

    local cached = gl.vertexCache[v]

    if cached then
        return cached[1], cached[2], cached[3]
    end

    local x, y, z = gl.transformVertex(v)

    if x == nil or y == nil or z == nil then
        return nil
    end

    cached = {x, y, z}
    gl.vertexCache[v] = cached

    return x, y, z
end

// projects a vertex (3d->2d)
function gl.projectVertex(x, y, z)
    if y <= gl.near then
        y = gl.near
    end

    local invY = doom.fixedDiv(FU, y)

    local sx = gl.centerX + doom.fixedMul(doom.fixedMul(x, invY), gl.fovX)
    local sy = gl.centerY - doom.fixedMul(doom.fixedMul(z, invY), gl.fovY)

    return doom.fixedInt(sx), doom.fixedInt(sy)
end

function gl.prepareVertex(v)
    local x, y, z = gl.getVertexXYZ(v)

    if x == nil or y == nil or z == nil then
        return
    end

    x, y, z = gl.transformXYZ(x, y, z)

    if x == nil or y == nil or z == nil then
        return
    end

    if y <= gl.near then
        return
    end

    local sx, sy = gl.projectVertex(x, y, z)

    return sx, sy, y
end

function gl.prepareTriangle3D(a, b, c)
    local ax, ay, az = gl.transformCachedVertex(a)
    local bx, by, bz = gl.transformCachedVertex(b)
    local cx, cy, cz = gl.transformCachedVertex(c)

    if ay <= gl.near or by <= gl.near or cy <= gl.near then
        return nil
    end

    local sx1, sy1 = gl.projectVertex(ax, ay, az)
    local sx2, sy2 = gl.projectVertex(bx, by, bz)
    local sx3, sy3 = gl.projectVertex(cx, cy, cz)

    if not sx1 or not sx2 or not sx3 then
        return nil
    end

    return sx1, sy1, ay, sx2, sy2, by, sx3, sy3, cy
end

// BORING triangle
function gl.drawTriangle(x1, y1, x2, y2, x3, y3, color)
    gl.rasterTriangle(x1, y1, 1, x2, y2, 1, x3, y3, 1, nil,
        function(index,depth)
            gl.depthbuffer.values[index]=depth
            gl.framebuffer.pixels[index]=color
        end
    )
end

// big function
// todo: cleanup and optimize?
function gl.rasterTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, data, pixelFunc)
    local framebuffer = gl.framebuffer

    if not framebuffer then
        return
    end

    local minX = max(min(x1,min(x2,x3)),0)
    local maxX = min(max(x1,max(x2,x3)),framebuffer.width-1)

    local minY = max(min(y1,min(y2,y3)),0)
    local maxY = min(max(y1,max(y2,y3)),framebuffer.height-1)

    if maxY >= gl.viewBottom then
        maxY = gl.viewBottom-1
    end

    if minX > maxX or minY > maxY then
        return
    end

    local area = (x2-x1)*(y3-y1) - (y2-y1)*(x3-x1)

    if area == 0 then
        return
    end

    local w1dx = y2-y3
    local w2dx = y3-y1
    local w3dx = y1-y2

    local w1dy = x3-x2
    local w2dy = x1-x3
    local w3dy = x2-x1

    local w1 = (x2-minX)*(y3-minY) - (y2-minY)*(x3-minX)
    local w2 = (x3-minX)*(y1-minY) - (y3-minY)*(x1-minX)
    local w3 = (x1-minX)*(y2-minY) - (y1-minY)*(x2-minX)

    if area < 0 then
        area=-$

        w1=-$
        w2=-$
        w3=-$

        w1dx=-$
        w2dx=-$
        w3dx=-$

        w1dy=-$
        w2dy=-$
        w3dy=-$
    end

    local d1 = doom.fixedDiv(FU,z1)
    local d2 = doom.fixedDiv(FU,z2)
    local d3 = doom.fixedDiv(FU,z3)


    local depth = doom.fixedDiv(w1*d1+w2*d2+w3*d3, area)

    local depthDX = doom.fixedDiv(w1dx*d1+w2dx*d2+w3dx*d3, area)
    local depthDY = doom.fixedDiv(w1dy*d1+w2dy*d2+w3dy*d3, area)

    local interp = {}

    if data then
        for name,values in pairs(data) do
            local a = doom.fixedMul(values[1],d1)
            local b = doom.fixedMul(values[2],d2)
            local c = doom.fixedMul(values[3],d3)

            interp[name] =
            {
                current = doom.fixedDiv(w1*a+w2*b+w3*c, area),
                stepX = doom.fixedDiv(w1dx*a+w2dx*b+w3dx*c, area),
                stepY = doom.fixedDiv(w1dy*a+w2dy*b+w3dy*c, area)
            }
        end
    end

    local depthValues = gl.depthbuffer.values
    local pixels = framebuffer.pixels
    local width = framebuffer.width

    local startW1 = w1
    local startW2 = w2
    local startW3 = w3

    for y=minY,maxY do
        local rw1=startW1
        local rw2=startW2
        local rw3=startW3
        local currentDepth=depth

        local rowInterp={}

        for k,v in pairs(interp) do
            rowInterp[k]=v.current
        end

        local index = y*width+minX+1

        for x=minX,maxX do
            if rw1>=0 and rw2>=0 and rw3>=0 then
                if currentDepth > depthValues[index] then
                    local values={}

                    for k,v in pairs(interp) do
                        values[k] = doom.fixedDiv(rowInterp[k], currentDepth)
                    end

                    pixelFunc(index, currentDepth, values)
                end
            end

            rw1=$+w1dx
            rw2=$+w2dx
            rw3=$+w3dx

            currentDepth = currentDepth+depthDX

            for k,v in pairs(interp) do
                rowInterp[k]= rowInterp[k]+v.stepX
            end

            index=$+1
        end

        depth = depth+depthDY

        startW1=startW1+w1dy
        startW2=startW2+w2dy
        startW3=startW3+w3dy

        for k,v in pairs(interp) do
            v.current = $+v.stepY
        end
    end
end

function gl.drawTriangle3D(a,b,c,color)
    local x1,y1,z1 = gl.prepareVertex(a)
    local x2,y2,z2 = gl.prepareVertex(b)
    local x3,y3,z3 = gl.prepareVertex(c)

    if not x1 or not y1 or not z1 or not x2 or not y2 or not z2 or not x3 or not y3 or not z3 then
        return
    end

    gl.rasterTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, nil,
        function(index,depth)
            gl.depthbuffer.values[index]=depth
            gl.framebuffer.pixels[index]=color
        end
    )
end

// quad
function gl.drawQuad3D(a, b, c, d, color)
    gl.drawTriangle3D(a, b, c, color)
    gl.drawTriangle3D(a, c, d, color)
end

// polygon
function gl.triangleFan(vertices, func, ...)
    if #vertices < 3 then
        return
    end

    local a = vertices[1]

    for i = 2,#vertices-1 do
        func(a, vertices[i], vertices[i+1], ...)
    end
end

function gl.drawTexturedTriangle(x1, y1, depth1, x2, y2, depth2, x3, y3, depth3, u1, v1, u2, v2, u3, v3, texture, lightlevel)
    if not texture then
        return
    end

    local tw = texture.width
    local th = texture.height

    if tw <= 0 or th <= 0 then
        return
    end

    local pixels = texture.pixels

    // hack
    u1 = $ * FU
    v1 = $ * FU
    u2 = $ * FU
    v2 = $ * FU
    u3 = $ * FU
    v3 = $ * FU

    gl.rasterTriangle(x1,y1,depth1, x2,y2,depth2, x3,y3,depth3, {u = {u1,u2,u3}, v = {v1,v2,v3}},
        function(index,depth,uv)
            local u = doom.fixedInt(uv.u)
            local v = doom.fixedInt(uv.v)

            u = $ % tw
            v = $ % th

            if u < 0 then
                u = $ + tw
            end

            if v < 0 then
                v = $ + th
            end

            local color = pixels[v * tw + u + 1]

            if color and color != -1 then
                // light level stuff
                if lightlevel and doomtex.colormaps and #doomtex.colormaps > 0 and color >= 0 and color < 256 then
                    local light = lightlevel >> 4
                    if light < 0 then light = 0 elseif light >= 16 then light = 15 end

                    local startmap = (15 - light) * 4
                    local distance = doom.fixedDiv(FU, depth)
                    local projection = gl.centerX * FU
                    local rwScale = doom.fixedDiv(projection, distance)
                    local scaleIndex = rwScale >> 12
                    if scaleIndex < 0 then scaleIndex = 0 elseif scaleIndex >= 48 then scaleIndex = 47 end

                    local level = startmap - scaleIndex * gl.framebuffer.width / gl.framebuffer.width / 2
                    if level < 0 then level = 0 elseif level >= 32 then level = 31 end

                    local colormap = doomtex.colormaps[level + 1]
                    if colormap then color = colormap[color + 1] end
                end

                gl.depthbuffer.values[index] = depth
                gl.framebuffer.pixels[index] = color
            end
        end
    )
end

function gl.drawTexturedTriangle3D(a, b, c, u1, v1, u2, v2, u3, v3, texture, lightlevel)
    local x1,y1,z1 = gl.prepareVertex(a)
    local x2,y2,z2 = gl.prepareVertex(b)
    local x3,y3,z3 = gl.prepareVertex(c)

    if not x1 or not y1 or not z1 or not x2 or not y2 or not z2 or not x3 or not y3 or not z3 then
        return
    end

    gl.drawTexturedTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, u1, v1, u2, v2, u3, v3, texture, lightlevel)
end

function gl.drawTexturedQuad3D(a, b, c, d, u1,u2, v1,v2, texture, lightlevel)
    gl.drawTexturedTriangle3D(a, b, c, u1, v1, u2, v1, u2, v2, texture, lightlevel)
    gl.drawTexturedTriangle3D(a, c, d, u1, v1, u2, v2, u1, v2, texture, lightlevel)
end

// helper
function gl.drawFlatTriangle3D(a, b, c, z, texture, lightlevel)
    gl.drawTexturedTriangle3D({x=a[1],y=a[2],z=z}, {x=b[1],y=b[2],z=z}, {x=c[1],y=c[2],z=z}, doom.fixedInt(a[1]), doom.fixedInt(a[2]), doom.fixedInt(b[1]), doom.fixedInt(b[2]), doom.fixedInt(c[1]), doom.fixedInt(c[2]), texture, lightlevel)
end

function gl.drawFlatPolygon3D(vertices, z, texture, lightlevel)
    gl.triangleFan(vertices, gl.drawFlatTriangle3D, z, texture, lightlevel)
end

// billboard sprite
function gl.drawBillboard3D(x, y, z, width, height, texture, flip)
    if not texture then
        return
    end

    local dx = FixedMul(width / 2, cos(gl.cam.yaw))
    local dy = FixedMul(width / 2, sin(gl.cam.yaw))

    local x1 = x - dx
    local y1 = y - dy

    local x2 = x + dx
    local y2 = y + dy

    local u1 = 0
    local u2 = texture.width

    // flip vertically
    if flip then
        u1 = texture.width
        u2 = 0
    end

    gl.drawTexturedQuad3D(
        {x = x1, y = y1, z = z},
        {x = x2, y = y2, z = z},
        {x = x2, y = y2, z = z + height},
        {x = x1, y = y1, z = z + height},
        u1, u2, texture.height, 0, texture
    )
end
