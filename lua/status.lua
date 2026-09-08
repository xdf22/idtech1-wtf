// face code, mostly copied from st_stuff.c
doom.ST_NUMPAINFACES = 5
doom.ST_NUMSTRAIGHTFACES = 3

doom.ST_TURNOFFSET = 9
doom.ST_OUCHOFFSET = 12
doom.ST_EVILGRINOFFSET = 15
doom.ST_RAMPAGEOFFSET = 18

doom.ST_GODFACE = 40
doom.ST_DEADFACE = 41

doom.ST_MUCHPAIN = 20
doom.ST_TURNCOUNT = 35
doom.ST_EVILGRINCOUNT = 2 * 35
doom.ST_RAMPAGEDELAY = 2 * 35
doom.ST_STRAIGHTFACECOUNT = 17

doom.face =
{
    index = 0,
    count = 0,
    priority = 0,
    oldHealth = 100,
    lastAttackDown = -1,
    oldWeaponsOwned = {}
}

function doom.calcPainOffset()
    local health = doom.player.health

    if health < 0 then health = 0 end
    if health > 100 then health = 100 end

    local pain = (100 - health) * 4
    pain = $ / 100
    pain = $ - (pain % 1)

    return pain * 8
end

doom.faces = {}

function doom.buildFaces()
    doom.faces = {}

    local facenum = 1

    for i = 0, 4 do
        for j = 0, 2 do
            doom.faces[facenum] = doompatch.get(string.format("STFST%d%d", i, j))
            facenum = $ + 1
        end

        doom.faces[facenum] = doompatch.get(string.format("STFTR%d0", i))
        facenum = $ + 1
        doom.faces[facenum] = doompatch.get(string.format("STFTL%d0", i))
        facenum = $ + 1
        doom.faces[facenum] = doompatch.get(string.format("STFOUCH%d", i))
        facenum = $ + 1
        doom.faces[facenum] = doompatch.get(string.format("STFEVL", i))
        facenum = $ + 1
        doom.faces[facenum] =doompatch.get(string.format("STFKILL", i))
        facenum = $ + 1
    end

    doom.faces[facenum] = doompatch.get("STFGOD0")
    facenum = $ + 1
    doom.faces[facenum] = doompatch.get("STFDEAD0")
end

function doom.setFace(index, priority, count)
    doom.face.index = index
    doom.face.priority = priority
    doom.face.count = count
end

function doom.drawFace()
    local face = doom.faces[doom.face.index + 1]

    if not face then
        return
    end

    doompatch.draw(face, 143, 168, 1, 1)
end

function doom.updateFace()
    local face = doom.face
    local i

    if face.priority < 10 then
        // dead
        if doom.player.health <= 0 then
            face.priority = 9
            face.index = doom.ST_DEADFACE
            face.count = 1
        end
    end

    if face.priority < 9 then
        // picking up bonus
    end

    if face.priority < 8 then
        // being attacked
    end

    if face.priority < 7 then
        // getting hurt because of your own damn stupidity
        if doom.player.damagecount and doom.player.damagecount > 0 then
            if doom.player.health - face.oldHealth > doom.ST_MUCHPAIN then
                face.priority = 7
                face.count = doom.ST_TURNCOUNT

                face.index = doom.calcPainOffset() + doom.ST_OUCHOFFSET
            else
                face.priority = 6
                face.count = doom.ST_TURNCOUNT

                face.index = doom.calcPainOffset() + doom.ST_RAMPAGEOFFSET
            end
        end
    end

    if face.priority < 6 then
        // rapid firing
        if doom.player.attackdown then
            if face.lastAttackDown == -1 then
                face.lastAttackDown = doom.ST_RAMPAGEDELAY
            else
                face.lastAttackDown = face.lastAttackDown - 1

                if face.lastAttackDown == 0 then
                    face.priority = 5

                    face.index = doom.calcPainOffset() + doom.ST_RAMPAGEOFFSET

                    face.count = 1
                    face.lastAttackDown = 1
                end
            end

        else
            face.lastAttackDown = -1
        end
    end

    if face.priority < 5 then
        // invulnerability
        if doom.player.godmode or doom.player.invulnerability then
            face.priority = 4
            face.index = doom.ST_GODFACE
            face.count = 1
        end
    end

    // normal face
    if face.count == 0 then
        face.index = doom.calcPainOffset() + P_RandomRange(0, 2)
        face.count = doom.ST_STRAIGHTFACECOUNT
        face.priority = 0
    end

    if face.count > 0 then
        face.count = face.count - 1
    end

    face.oldHealth = doom.player.health
end

function doom.drawStatusBar()
    local gun = doompatch.get("PISGA0")
    doompatch.draw(gun, 126, 106, 1, 1)
    local stbar = doompatch.get("STBAR")
    doompatch.draw(stbar, 0, 168, 1, 1)
    local arms = doompatch.get("STARMS")
    doompatch.draw(arms, 104, 168, 1, 1)

    doom.drawFace()

    doompatch.drawNumber(doom.player.ammo, 44, 171, 1, 1, false)
    doompatch.drawNumber(doom.player.health, 90, 171, 1, 1, true)
    //doompatch.drawNumber(doom.player.frag, 138, 171, 1, 1, false)
    doompatch.drawNumber(doom.player.armor, 221, 171, 1, 1, true)
end
