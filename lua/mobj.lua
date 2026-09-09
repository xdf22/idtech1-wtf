rawset(_G, "doom_mobj", {})

// sprite rotation 0->7
function doom_mobj.getSpriteRotation(mo)
    local ang = R_PointToAngle2(gl.cam.x, gl.cam.y, mo.x, mo.y)
    ang = $ - mo.angle

    local rotation = (ang + (ANGLE_45 / 2) * 9) >> 29
    rotation = $ & 7

    return rotation
end

doom_mobj.list = {}

// todo: move state and mobjinfo tables to a new file, and fill them out completely from info.c
doom_mobj.states =
{
    ["S_NULL"] =
    {
        sprite = "SPR_TROO",
        frame = 0,
        tics = -1,
        action = nil,
        nextstate = "S_NULL"
    },

    ["S_POSS_STND"] =
    {
        sprite = "SPR_POSS",
        frame = 0,
        tics = 10,
        action = nil, // A_Look,
        nextstate = "S_POSS_STND2"
    },

    ["S_POSS_STND2"] =
    {
        sprite = "SPR_POSS",
        frame = 1,
        tics = 10,
        action = nil, // A_Look,
        nextstate = "S_POSS_STND"
    }
}

doom_mobj.mobjinfo =
{
    ["MT_POSSESSED"] =
    {
        doomednum = 3004,

        spawnstate = "S_POSS_STND",
        spawnhealth = 20,

        radius = 20 * FU,
        height = 56 * FU,

        flags =
        {
            "MF_SOLID",
            "MF_SHOOTABLE",
            "MF_COUNTKILL"
        }
    }
}

function doom_mobj.findType(doomednum)
    for type, info in pairs(doom_mobj.mobjinfo) do
        if info.doomednum == doomednum then
            return type
        end
    end

    return nil
end

function doom_mobj.spawn(x, y, z, type, angle)
    local info = doom_mobj.mobjinfo[type]

    if not info then
        return nil
    end

    local state = doom_mobj.states[info.spawnstate]

    if not state then
        return nil
    end

    local mo =
    {
        type = type,

        x = x,
        y = y,
        z = z,

        angle = FixedAngle((angle or 0)*FU),

        radius = info.radius,
        height = info.height,

        flags = info.flags,
        health = info.spawnhealth,

        state = info.spawnstate,
        tics = state.tics,

        sprite = state.sprite,
        frame = state.frame,

        removed = false
    }

    doom_mobj.list[#doom_mobj.list + 1] = mo

    return mo
end

function doom_mobj.spawnMap(map)
    doom_mobj.list = {}

    if not map or not map.things then
        return
    end

    for i = 1, #map.things do
        local thing = map.things[i]

        local type = doom_mobj.findType(thing.type)

        if type then
            doom_mobj.spawn(thing.x, thing.y, 0, type, thing.angle)
        else
            print(string.format("Unknown thing type %d", thing.type))
        end
    end
end

function doom_mobj.draw(mo)
    if mo.removed then
        return
    end

    local rotation = doom_mobj.getSpriteRotation(mo)
    local sprite = doomtex.sprite(mo.sprite, mo.frame, rotation)

    if not sprite then
        return
    end

    gl.drawBillboard3D(mo.x, mo.y, mo.z, mo.radius * 2, mo.height, sprite.patch, sprite.flip)
end

function doom_mobj.drawAll()
    for i = 1, #doom_mobj.list do
        doom_mobj.draw(doom_mobj.list[i])
    end
end
