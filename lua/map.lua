// find the map lump
// maybe i can merge these 2?
function doom.maplump(wadfile, mapname)
    local entries = wadfile.entries

    for i = 1, #entries do
        if entries[i].name == mapname then
            return i
        end
    end

    return nil
end

function doom.lump(wadfile, name, start)
    local entries = wadfile.entries

    for i = start or 1, #entries do
        if entries[i].name == name then
            return entries[i].data
        end
    end

    return nil
end

// load a map
function doom.loadmap(wadfile, mapname)
    local start = doom.maplump(wadfile, mapname)

    if not start then
        return nil
    end

    // populate the map table
    local map = {name = mapname}

    map.vertices = doom.vertices(doom.lump(wadfile, "VERTEXES", start))
    map.linedefs = doom.linedefs(doom.lump(wadfile, "LINEDEFS", start))
    map.sidedefs = doom.sidedefs(doom.lump(wadfile, "SIDEDEFS", start))
    map.segs = doom.segs(doom.lump(wadfile, "SEGS", start))
    map.subsectors = doom.subsectors(doom.lump(wadfile, "SSECTORS", start))
    map.nodes = doom.nodes(doom.lump(wadfile, "NODES", start))
    map.sectors = doom.sectors(doom.lump(wadfile, "SECTORS", start))
    map.things = doom.things(doom.lump(wadfile, "THINGS", start))

    doomrenderer.buildNodeCache(map)

    return map
end

function doom.mapBounds(map)
    if #map.vertices == 0 then
        return -64, 64, -64, 64
    end

    local v = map.vertices[1]

    local minx = doom.fixedInt(v[1])
    local maxx = minx
    local miny = doom.fixedInt(v[2])
    local maxy = miny

    for i = 2, #map.vertices do
        v = map.vertices[i]

        local x = doom.fixedInt(v[1])
        local y = doom.fixedInt(v[2])

        minx = min(minx, x)
        maxx = max(maxx, x)
        miny = min(miny, y)
        maxy = max(maxy, y)
    end

    return minx - 64, maxx + 64, miny - 64, maxy + 64
end

function doom.pointOnSide(x, y, node)
    return (y - node.renderY) * node.renderDX - (x - node.renderX) * node.renderDY
end

function doom.intersection(a, b, va, vb)
    local denominator = va - vb

    if denominator == 0 then
        return {
            a[1],
            a[2]
        }
    end

    local t = doom.fixedDiv(va, denominator)

    local dx = b[1] - a[1]
    local dy = b[2] - a[2]

    local x = a[1] + doom.fixedInt(doom.fixedMul(dx * FU, t))
    local y = a[2] + doom.fixedInt(doom.fixedMul(dy * FU, t))

    return {
        x,
        y
    }
end

// clips a polygon on one side
function doom.clipPolygonSide(polygon, node, side)
    if #polygon == 0 then
        return {}
    end

    local result = {}

    local previous = polygon[#polygon]
    local previousValue = doom.pointOnSide(previous[1], previous[2], node)
    local previousInside

    if side == 0 then previousInside = previousValue < 0 else previousInside = previousValue >= 0 end

    for i = 1, #polygon do
        local current = polygon[i]
        local currentValue = doom.pointOnSide(current[1], current[2], node)
        local currentInside

        if side == 0 then currentInside = currentValue < 0 else currentInside = currentValue >= 0 end

        if currentInside != previousInside then
            local intersection = doom.intersection(previous, current, previousValue, currentValue)
            result[#result + 1] = intersection
        end

        if currentInside then
            result[#result + 1] = current
        end

        previous = current
        previousValue = currentValue
        previousInside = currentInside
    end

    return result
end

// find path to a subsector
function doom.findSubsectorPath(map, target)
    local path = {}

    local function search(nodeIndex)
        local node = map.nodes[nodeIndex + 1]

        if not node then
            return false
        end

        for side = 0, 1 do
            local child

            if side == 0 then child = node.right else child = node.left end

            if (child & 0x8000) != 0 then
                local index = child & 0x7FFF

                if child == 0xFFFF then
                    index = 0
                end

                if index == target then
                    path[#path + 1] =
                    {
                        node = node,
                        side = side
                    }
                    return true
                end
            elseif search(child) then
                path[#path + 1] =
                {
                    node = node,
                    side = side
                }
                return true
            end
        end

        return false
    end

    if #map.nodes > 0 then
        search(#map.nodes - 1)
    end

    return path
end

// construct a polygon out of a subsector
function gl.clipFlatPolygonNear(vertices, z)
    local count = #vertices

    if count < 3 then
        return nil
    end

    local result = {}

    local prev = vertices[count]

    local prevX = prev[1]
    local prevY = prev[2]

    local _, prevDepth = gl.transformVertexXYZ(prevX, prevY, z)

    local prevInside = prevDepth > gl.near

    for i = 1, count do
        local cur = vertices[i]

        local curX = cur[1]
        local curY = cur[2]

        local _, curDepth = gl.transformVertexXYZ(curX, curY, z)

        local curInside = curDepth > gl.near

        if curInside != prevInside then
            local depthDelta = curDepth - prevDepth

            if depthDelta != 0 then
                local t = doom.fixedDiv(gl.near - prevDepth, depthDelta)
                local x = prevX + doom.fixedMul(curX - prevX, t)
                local y = prevY + doom.fixedMul(curY - prevY, t)

                result[#result + 1] =
                {
                    x,
                    y
                }
            end
        end

        if curInside then
            result[#result + 1] =
            {
                curX,
                curY
            }
        end

        prevX = curX
        prevY = curY
        prevDepth = curDepth
        prevInside = curInside
    end

    if #result < 3 then
        return nil
    end

    return result
end

function doom.subsectorPolygon(map,index,minx,maxx,miny,maxy)
    local subsector = map.subsectors[index]

    if not subsector then
        return nil
    end

    local polygon =
    {
        {minx, miny},
        {maxx, miny},
        {maxx, maxy},
        {minx, maxy}
    }

    local path = doom.findSubsectorPath(map, index - 1)

    for i = #path, 1, -1 do
        local entry = path[i]

        polygon = doom.clipPolygonSide(polygon, entry.node, entry.side)

        if #polygon == 0 then
            return nil
        end
    end

    // clean up
    local cleaned = {}

    for i = 1, #polygon do
        local p = polygon[i]
        local previous = cleaned[#cleaned]

        if not previous or previous[1] != p[1] or previous[2] != p[2] then
            cleaned[#cleaned + 1] = p
        end
    end

    if #cleaned > 1 then
        local first = cleaned[1]
        local last = cleaned[#cleaned]

        if first[1] == last[1] and first[2] == last[2] then
            table.remove(cleaned)
        end
    end

    // invalid polygon?
    if #cleaned < 3 then
        return nil
    end

    local result = {}

    for i = 1, #cleaned do
        result[#result + 1] =
        {
            cleaned[i][1] * FU,
            cleaned[i][2] * FU
        }
    end

    return result
end
