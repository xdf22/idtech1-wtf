// vertices lump
function doom.vertices(data)
    local result = {}
    if not data then return result end

    for p = 1, #data, 4 do
        result[#result + 1] =
        {
            doom.s16(data, p) * FU,
            doom.s16(data, p + 2) * FU
        }
    end

    return result
end

// sectors lump
function doom.sectors(data)
    local result = {}
    if not data or #data % 26 != 0 then return result end

    for p = 1, #data, 26 do
        result[#result + 1] =
        {
            floorheight = doom.s16(data, p) * FU,
            ceilingheight = doom.s16(data, p + 2) * FU,
            floortexture = data:sub(p + 4, p + 11):gsub("%z", ""):gsub("%s+$", ""),
            ceilingtexture = data:sub(p + 12, p + 19):gsub("%z", ""):gsub("%s+$", ""),
            lightlevel = doom.s16(data, p + 20),
            special = doom.u16(data, p + 22),
            tag = doom.u16(data, p + 24)
        }
    end

    return result
end

// sidedefs lump
function doom.sidedefs(data)
    local result = {}
    if not data then return result end

    for p = 1, #data - 29, 30 do
        result[#result + 1] =
        {
            xoffset = doom.s16(data, p) * FU,
            yoffset = doom.s16(data, p + 2) * FU,
            upper = data:sub(p + 4, p + 11),
            lower = data:sub(p + 12, p + 19),
            middle = data:sub(p + 20, p + 27),
            sector = doom.u16(data, p + 28)
        }
    end

    return result
end

// linedefs lump
function doom.linedefs(data)
    local result = {}
    if not data then return result end

    for p = 1, #data, 14 do
        result[#result + 1] =
        {
            v1 = doom.u16(data, p),
            v2 = doom.u16(data, p + 2),
            flags = doom.u16(data, p + 4),
            special = doom.u16(data, p + 6),
            tag = doom.u16(data, p + 8),
            side =
            {
                doom.u16(data, p + 10),
                doom.u16(data, p + 12)
            }
        }
    end

    return result
end

// segs lump
function doom.segs(data)
    local result = {}
    if not data then return result end

    for p = 1, #data, 12 do
        result[#result + 1] =
        {
            v1 = doom.u16(data, p),
            v2 = doom.u16(data, p + 2),
            angle = doom.u16(data, p + 4),
            linedef = doom.u16(data, p + 6),
            side = doom.u16(data, p + 8),
            offset = doom.s16(data, p + 10)
        }
    end

    return result
end

// subsectors lump
function doom.subsectors(data)
    local result = {}
    if not data then return result end

    for p = 1, #data, 4 do
        result[#result + 1] =
        {
            segcount = doom.u16(data, p),
            firstseg = doom.u16(data, p + 2)
        }
    end

    return result
end

// things
function doom.things(data)
    local result = {}
    if not data then return result end

    for p = 1, #data, 10 do
        result[#result + 1] =
        {
            x = doom.s16(data, p) * FU,
            y = doom.s16(data, p + 2) * FU,
            angle = doom.s16(data, p + 4),
            type = doom.u16(data, p + 6),
            flags = doom.u16(data, p + 8)
        }
    end

    return result
end

function doom.prepareSegs(map)
    for i = 1, #map.segs do
        local seg = map.segs[i]

        local linedef = map.linedefs[seg.linedef + 1]
        local v1 = map.vertices[seg.v1 + 1]
        local v2 = map.vertices[seg.v2 + 1]

        if linedef and v1 and v2 then
            seg.linedefRef = linedef
            seg.v1Ref = v1
            seg.v2Ref = v2

            local frontSideIndex =
                linedef.side[seg.side + 1]

            if frontSideIndex != 0xFFFF then
                local frontSide =
                    map.sidedefs[frontSideIndex + 1]

                if frontSide then
                    seg.frontSideRef = frontSide
                    seg.frontSectorRef =
                        map.sectors[frontSide.sector + 1]
                end
            end

            local backSideIndex

            if seg.side == 0 then
                backSideIndex = linedef.side[2]
            else
                backSideIndex = linedef.side[1]
            end

            if backSideIndex != 0xFFFF then
                local backSide =
                    map.sidedefs[backSideIndex + 1]

                if backSide then
                    seg.backSideRef = backSide
                    seg.backSectorRef =
                        map.sectors[backSide.sector + 1]
                end
            end
        end
    end
end
