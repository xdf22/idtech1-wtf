rawset(_G, "doomrenderer", {})

doomrenderer.polygonCache = {}
doomrenderer.flatCache = {}
doomrenderer.wallTextureCache = {}
doomrenderer.skyCache = {}

doomrenderer.renderDistance = 4096 * FU

function doomrenderer.inRenderDistanceBox(box)
    if not box.minx then
        return false
    end

    local x = gl.cam.x
    local y = gl.cam.y

    local closestX = x
    local closestY = y

    if x < box.minx then closestX = box.minx elseif x > box.maxx then closestX = box.maxx end
    if y < box.miny then closestY = box.miny elseif y > box.maxy then closestY = box.maxy end

    return R_PointToDist2(x, y, closestX, closestY) <= doomrenderer.renderDistance
end

function doomrenderer.inRenderDistanceNodeBBox(x, y, top, bottom, left, right)
    local limit = doomrenderer.renderDistance

    local closestX = x
    local closestY = y

    if x < left then closestX = left elseif x > right then closestX = right end
    if y < bottom then closestY = bottom elseif y > top then closestY = top end

    local dx = closestX - x
    local dy = closestY - y

    if dx > limit or dx < -limit then return false end
    if dy > limit or dy < -limit then return false end

    return R_PointToDist2(x, y, closestX, closestY) <= limit
end

function doomrenderer.getFlat(name)
    if not name or name == "" then
        return nil
    end

    local cached = doomrenderer.flatCache[name]

    if cached then
        return cached
    end

    local lumpdata = doom.lump(doomtex.wad, name, 1)

    if not lumpdata then
        return nil
    end

    local flat = doomflat.decode(lumpdata)

    if flat then
        doomrenderer.flatCache[name] = flat
    end

    return flat
end

function doomrenderer.getWallTexture(name)
    if not name or name == "" or name == "-" then
        return nil
    end

    local cached = doomrenderer.wallTextureCache[name]

    if cached then
        return cached
    end

    local texture = doomtex.build(name)

    if texture then
        doomrenderer.wallTextureCache[name] = texture
    end

    return texture
end

function doomrenderer.buildPolygonCache(map)
    local cache = {}
    doomrenderer.polygonCache[map] = cache

    local minx, maxx, miny, maxy = doom.mapBounds(map)

    for i = 1, #map.subsectors do
        local polygon = doom.subsectorPolygon(map, i, minx, maxx, miny, maxy)

        local boxMinX = nil
        local boxMaxX = nil
        local boxMinY = nil
        local boxMaxY = nil

        if polygon then
            for j = 1, #polygon do
                local x = polygon[j][1]
                local y = polygon[j][2]

                if not boxMinX or x < boxMinX then boxMinX = x end
                if not boxMaxX or x > boxMaxX then boxMaxX = x end
                if not boxMinY or y < boxMinY then boxMinY = y end
                if not boxMaxY or y > boxMaxY then boxMaxY = y end
            end
        end

        local sector = doom.subsectorsector(map, i)

        local floorflat
        local ceilingflat

        if sector then
            floorflat = doomrenderer.getFlat(sector.floortexture)

            // dont draw F_SKY1
            if sector.ceilingtexture != "F_SKY1" then
                ceilingflat = doomrenderer.getFlat(sector.ceilingtexture)
            end
        end

        cache[i] =
        {
            polygon = polygon,
            sector = sector,

            floorflat = floorflat,
            ceilingflat = ceilingflat,

            minx = boxMinX,
            maxx = boxMaxX,
            miny = boxMinY,
            maxy = boxMaxY
        }
    end
end

function doomrenderer.buildSegCache(map)
    for i = 1, #map.segs do
        local seg = map.segs[i]

        local v1 = seg.v1Ref
        local v2 = seg.v2Ref
        local side = seg.frontSideRef

        if v1 and v2 and side then
            seg.renderLength = doom.fixedInt(R_PointToDist2(v1[1], v1[2], v2[1], v2[2]))
            seg.renderU1 = doom.fixedInt(side.xoffset) + FixedInt(seg.offset)
            seg.renderU2 = seg.renderU1 + seg.renderLength
            seg.renderMiddle = doomrenderer.getWallTexture(side.middle)
            seg.renderUpper = doomrenderer.getWallTexture(side.upper)
            seg.renderLower = doomrenderer.getWallTexture(side.lower)
        end
    end
end

function doomrenderer.buildNodeCache(map)
    for i = 1, #map.nodes do
        local node = map.nodes[i]

        node.renderX = doom.fixedInt(node.x)
        node.renderY = doom.fixedInt(node.y)
        node.renderDX = doom.fixedInt(node.dx)
        node.renderDY = doom.fixedInt(node.dy)
    end
end

function doomrenderer.getSkyTexture(name)
    if not name or name == "" then
        return nil
    end

    local cached = doomrenderer.skyCache[name]

    if cached then
        return cached
    end

    local texture = doomtex.build(name)

    if texture then
        doomrenderer.skyCache[name] = texture
    end

    return texture
end

// sky
function doomrenderer.sky(map)
    local texture = doomrenderer.getSkyTexture("SKY1") // temp

    if not texture then
        return
    end

    local framebuffer = gl.framebuffer

    if not framebuffer then
        return
    end

    local pixels = framebuffer.pixels
    local width = framebuffer.width
    local height = framebuffer.height
    local tw = texture.width
    local th = texture.height
    local texpixels = texture.pixels

    if tw <= 0 or th <= 0 then
        return
    end

    // sky offset
    local yaw = gl.cam.yaw >> 16
    local skyOffset = doom.fixedInt((yaw * tw) / 360)

    skyOffset = $ % tw

    if skyOffset < 0 then
        skyOffset = $ + tw
    end

    // draw it
    for y = 0, height - 1 do
        local v = y % th
        local texIndex = v * tw + skyOffset + 1
        local screenIndex = y * width + 1
        local u = skyOffset

        for x = 0, width - 1 do
            local color = texpixels[texIndex]

            if color != nil and color != -1 then
                pixels[screenIndex] = color
            end

            u = $ + 1
            if u >= tw then u = 0; texIndex = texIndex - tw + 1 else texIndex = $ + 1 end

            screenIndex = $ + 1
        end
    end
end

// wall drawing
function doomrenderer.wall(v1, v2, bottom, top, u1, u2, vtop, vbottom, texture, light)
    if not texture or top <= bottom then
        return
    end

    gl.drawTexturedQuad3D({x=v1[1], y=v1[2], z=bottom}, {x=v2[1], y=v2[2], z=bottom}, {x=v2[1], y=v2[2], z=top}, {x=v1[1], y=v1[2], z=top}, u1, u2, vtop, vbottom, texture, light)
end

function doomrenderer.wallV(texture, yoffset, height, flags, upper)
    yoffset = doom.fixedInt(yoffset)

    if upper then
        if (flags & 8) != 0 then
            local bottom = texture.height + yoffset
            return bottom - height, bottom
        end

        return yoffset, yoffset + height
    end

    if (flags & 16) != 0 then
        local bottom = texture.height + yoffset
        return bottom - height, bottom
    end

    local bottom = yoffset
    return bottom - height, bottom
end

function doomrenderer.seg(seg)
    local linedef = seg.linedefRef
    local v1 = seg.v1Ref
    local v2 = seg.v2Ref
    local frontSide = seg.frontSideRef
    local frontSector = seg.frontSectorRef

    if not linedef or not v1 or not v2 or not frontSide or not frontSector then
        return
    end

    local backSector = seg.backSectorRef

    local u1 = seg.renderU1
    local u2 = seg.renderU2

    // one sided wall
    if not backSector then
        if frontSide.middle == "-" or frontSide.middle == "" then
            return
        end

        local texture = seg.renderMiddle
        if texture then
            local bottom = frontSector.floorheight
            local top = frontSector.ceilingheight

            local height = doom.fixedInt(top - bottom)
            local vbottom = doom.fixedInt(frontSide.yoffset)
            local vtop = vbottom - height

            doomrenderer.wall(v1, v2, bottom, top, u1, u2, vtop, vbottom, texture, frontSector.lightlevel)
        end

        return
    end

    // upper texture
    if frontSide.upper != "-" and frontSide.upper != "" and backSector.ceilingheight < frontSector.ceilingheight then
        local texture = seg.renderUpper

        if texture then
            local height = doom.fixedInt(frontSector.ceilingheight - backSector.ceilingheight)
            local vtop, vbottom = doomrenderer.wallV(texture, frontSide.yoffset, height, linedef.flags, true)

            doomrenderer.wall(v1, v2, backSector.ceilingheight, frontSector.ceilingheight, u1, u2, vtop, vbottom, texture, frontSector.lightlevel)
        end
    end

    // lower texture
    if frontSide.lower != "-" and frontSide.lower != "" and backSector.floorheight > frontSector.floorheight then
        local texture = seg.renderLower

        if texture then
            local height = doom.fixedInt(backSector.floorheight - frontSector.floorheight)
            local vtop, vbottom = doomrenderer.wallV(texture, frontSide.yoffset, height, linedef.flags, false)

            doomrenderer.wall(v1, v2, frontSector.floorheight, backSector.floorheight, u1, u2, vtop, vbottom, texture, frontSector.lightlevel)
        end
    end

    // mid texture
    if frontSide.middle != "-" and frontSide.middle != "" then
        local texture = seg.renderMiddle

        if texture then
            local bottom = max(frontSector.floorheight, backSector.floorheight)
            local top = min(frontSector.ceilingheight, backSector.ceilingheight)

            if top > bottom then
                local height = doom.fixedInt(top - bottom)
                local vbottom = doom.fixedInt(frontSide.yoffset)
                local vtop = vbottom - height

                doomrenderer.wall(v1, v2, bottom, top, u1, u2, vtop, vbottom, texture, backSector.lightlevel)
            end
        end
    end
end

// flats
function doomrenderer.flat(map, index, ceiling)
    local cached = doomrenderer.polygonCache[map][index]

    if not cached or not cached.polygon or not cached.sector then
        return
    end

    local sector = cached.sector
    local texture = ceiling and cached.ceilingflat or cached.floorflat

    if not texture then
        return
    end

    local z = ceiling and sector.ceilingheight or sector.floorheight
    gl.drawFlatPolygon3D(cached.polygon, z, texture, sector.lightlevel)
end

// render a subsector
function doomrenderer.subsector(map, index)
    local sub = map.subsectors[index]
    local cached = doomrenderer.polygonCache[map][index]

    if not sub or not cached then
        return
    end

    // floor and ceiling
    doomrenderer.flat(map, index, false)
    doomrenderer.flat(map, index, true)

    local first = sub.firstseg + 1
    local last = first + sub.segcount - 1

    for i = first, last do
        doomrenderer.seg(map.segs[i])
    end
end

// bsp child
function doomrenderer.child(map, child, bbox)
    if bbox then
        if not doomrenderer.inRenderDistanceNodeBBox(bbox[1], bbox[2], bbox[3], bbox[4]) then
            return
        end
    end

    if (child & 0x8000) != 0 then
        local index = child & 0x7FFF

        if child == 0xFFFF then
            index = 0
        end

        doomrenderer.subsector(map, index + 1)
    else
        doomrenderer.node(map, child + 1)
    end
end

// bsp node
function doomrenderer.node(map, index)
    local node = map.nodes[index]

    if not node then
        return
    end

    local side = doom.pointside(gl.cam.x, gl.cam.y, node)
    local bbox = node.bbox

    if side == 0 then
        // front/left child
        if doomrenderer.inRenderDistanceNodeBBox(gl.cam.x, gl.cam.y, bbox[5], bbox[6], bbox[7], bbox[8]) then
            doomrenderer.child(map, node.left)
        end

        // back/right child
        if doomrenderer.inRenderDistanceNodeBBox(gl.cam.x, gl.cam.y, bbox[1], bbox[2], bbox[3], bbox[4]) then
            doomrenderer.child(map, node.right)
        end
    else
        // front/right child
        if doomrenderer.inRenderDistanceNodeBBox(gl.cam.x, gl.cam.y, bbox[1], bbox[2], bbox[3], bbox[4]) then
            doomrenderer.child(map, node.right)
        end

        // back/left child
        if doomrenderer.inRenderDistanceNodeBBox(gl.cam.x, gl.cam.y, bbox[5], bbox[6], bbox[7], bbox[8]) then
            doomrenderer.child(map, node.left)
        end
    end
end

// main function
function doomrenderer.render(map)
    doomrenderer.sky(map)
    if #map.nodes > 0 then
        doomrenderer.node(map, #map.nodes)
    else
        // no nodes? fallback to drawing all subsectors
        for i = 1, #map.subsectors do
            doomrenderer.subsector(map, i)
        end
    end
end
