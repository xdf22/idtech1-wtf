rawset(_G, "doom", {})

// integer reading
function doom.u16(data, p)
    local a = data:byte(p)
    local b = data:byte(p+1)

    return a + b * 256
end

function doom.s16(data, p)
    local n = doom.u16(data, p)

    if n >= 32768 then
        n = n-65536
    end

    return n
end

function doom.u32(data, p)
    local a = data:byte(p)
    local b = data:byte(p+1)
    local c = data:byte(p+2)
    local d = data:byte(p+3)

    return a + b * 256 + c * 65536 + d * 16777216
end

// lugent said this would be faster idk
doom.fixedDiv = FixedDiv
doom.fixedMul = FixedMul
doom.fixedInt = FixedInt
doom.abs = abs
// no im not doing every constant

doom.player =
{
    health = 100,
    ammo = 10,
    frag = 1,
    armor = 100,

    damagecount = 0,
    attacker = nil,

    attackdown = false,

    godmode = false,
    invulnerability = false,

    weaponowned = {}
}
