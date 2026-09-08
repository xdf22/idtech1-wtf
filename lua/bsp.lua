
// nodes
function doom.nodes(data)
    local result = {}

    if not data then
        return result
    end

    if (#data % 28) != 0 then
        print("bad node size: " .. #data)
        return result
    end

    for p = 1, #data, 28 do
        result[#result+1] =
        {
            x = doom.s16(data, p) * FU,
            y = doom.s16(data, p+2) * FU,

            dx = doom.s16(data, p+4) * FU,
            dy = doom.s16(data, p+6) * FU,

            bbox =
            {
                doom.s16(data, p+8) * FU,
                doom.s16(data, p+10) * FU,
                doom.s16(data, p+12) * FU,
                doom.s16(data, p+14) * FU,

                doom.s16(data, p+16) * FU,
                doom.s16(data, p+18) * FU,
                doom.s16(data, p+20) * FU,
                doom.s16(data, p+22) * FU
            },

            right = doom.u16(data, p+24),
            left = doom.u16(data, p+26)
        }
    end

    return result
end

// BSP side test
function doom.pointside(x, y, node)
    local dx = x - node.x
    local dy = y - node.y

    local cross = doom.fixedMul(dx, node.dy)-doom.fixedMul(dy, node.dx)

    if cross <= 0 then
        return 0
    end

    return 1
end

// find a sector containing a point
function doom.pointsector(map, x, y)
    if #map.nodes == 0 then
        if map.subsectors[1] then
            local seg = map.segs[map.subsectors[1].firstseg+1]

            if seg then
                local linedef = map.linedefs[seg.linedef+1]

                if linedef then
                    local side = linedef.side[seg.side+1]

                    if side != 0xFFFF then
                        local sidedef = map.sidedefs[side+1]

                        if sidedef then
                            return map.sectors[sidedef.sector+1]
                        end
                    end
                end
            end
        end

        return nil
    end

    local node = map.nodes[#map.nodes]

    while node do
        local side = doom.pointside(x, y, node)

        local child

        if side == 0 then
            child = node.left
        else
            child = node.right
        end

        if (child & 0x8000) != 0 then
            local index = child & 0x7FFF

            if child == 0xFFFF then
                index = 0
            end

            local subsector = map.subsectors[index+1]

            if not subsector then
                return nil
            end

            local seg = map.segs[subsector.firstseg+1]

            if not seg then
                return nil
            end

            local linedef = map.linedefs[seg.linedef+1]

            if not linedef then
                return nil
            end

            local sideindex = linedef.side[seg.side+1]

            if sideindex == 0xFFFF then
                return nil
            end

            local sidedef = map.sidedefs[sideindex+1]

            if not sidedef then
                return nil
            end

            return map.sectors[sidedef.sector+1]
        end

        node = map.nodes[child+1]
    end

    return nil
end

function doom.subsectorsector(map, index)
    local subsector = map.subsectors[index]

    if not subsector then
        return nil
    end

    local seg = map.segs[subsector.firstseg+1]

    if not seg then
        return nil
    end

    local linedef = map.linedefs[seg.linedef+1]

    if not linedef then
        return nil
    end

    local sideindex = linedef.side[seg.side+1]

    if sideindex == 0xFFFF then
        return nil
    end

    local sidedef = map.sidedefs[sideindex+1]

    if not sidedef then
        return nil
    end

    return map.sectors[sidedef.sector+1]
end
