// port/simplification of f_wipe.c
rawset(_G, "doomwipe", {})

doomwipe.active = false

doomwipe.y = {}

doomwipe.oldPixels = nil
doomwipe.newPixels = nil
doomwipe.scr = nil

doomwipe.width = 0
doomwipe.height = 0

// cant use random key in hud smh
doomwipe.randomSeed = P_RandomRange(0, 99999)

function doomwipe.random(max)
    doomwipe.randomSeed =
        (doomwipe.randomSeed * 1103515245 + 12345) & 0x7fffffff

    return doomwipe.randomSeed % max
end

function doomwipe.copyPixels()
    local fb = gl.framebuffer
    local copy = {}

    for i = 1, #fb.pixels do
        copy[i] = fb.pixels[i]
    end

    return copy
end

function doomwipe.start(oldPixels, newPixels)
    local fb = gl.framebuffer

    doomwipe.width = fb.width
    doomwipe.height = fb.height

    doomwipe.oldPixels = oldPixels
    doomwipe.newPixels = newPixels

    // wipe_scr starts as a copy of wipe_scr_start.
    doomwipe.scr = {}

    for i = 1, #oldPixels do
        doomwipe.scr[i] = oldPixels[i]
    end

    doomwipe.y = {}

    // see above for why im using a custom randomization function (previously P_RandomKey)
    doomwipe.y[1] = -doomwipe.random(16)

    local columns = fb.width / 2

    for i = 2, columns do
        local r = doomwipe.random(3) - 1
        local value = doomwipe.y[i - 1] + r

        if value > 0 then
            value = 0
        elseif value == -16 then
            value = -15
        end

        doomwipe.y[i] = value
    end

    doomwipe.active = true
end

function doomwipe.update(tics)
    if not doomwipe.active then
        return true
    end

    local width = doomwipe.width
    local height = doomwipe.height

    local oldPixels = doomwipe.oldPixels
    local newPixels = doomwipe.newPixels
    local scr = doomwipe.scr

    local columns = width / 2

    local done = true

    while tics > 0 do
        tics = tics - 1

        for i = 1, columns do
            local y = doomwipe.y[i]

            if y < 0 then
                doomwipe.y[i] = y + 1
                done = false
            elseif y < height then
                local dy

                if y < 16 then dy = y + 1 else dy = 8 end
                if y + dy >= height then dy = height - y end

                for j = 0, dy - 1 do
                    local srcY = y + j
                    local dstY = y + j

                    local src = srcY * width + (i - 1) * 2 + 1
                    local dst = dstY * width + (i - 1) * 2 + 1

                    scr[dst] = newPixels[src]
                    scr[dst + 1] = newPixels[src + 1]
                end

                y = $ + dy

                doomwipe.y[i] = y

                for j = 0, height - y - 1 do
                    local srcY = j
                    local dstY = y + j

                    local src = srcY * width + (i - 1) * 2 + 1
                    local dst = dstY * width + (i - 1) * 2 + 1

                    scr[dst] = oldPixels[src]
                    scr[dst + 1] = oldPixels[src + 1]
                end

                done = false
            end
        end
    end

    if done then
        doomwipe.active = false

        for i = 1, #scr do
            scr[i] = newPixels[i]
        end
    end

    local pixels = gl.framebuffer.pixels

    for i = 1, #scr do
        pixels[i] = scr[i]
    end

    return done
end

function doom.startGameWipe(player)
    local fb = gl.framebuffer
    local oldPixels = doomwipe.copyPixels()

    // create the destination screen
    local newPixels = {}

    for i = 1, #fb.pixels do
        newPixels[i] = 0
    end

    local originalPixels = fb.pixels
    fb.pixels = newPixels
    gl.clear(0)

    gl.vertexCache = {}

    doom.renderGame(player)
    fb.pixels = originalPixels

    // restore original screen
    for i = 1, #fb.pixels do
        fb.pixels[i] = oldPixels[i]
    end

    doomwipe.start(oldPixels, newPixels)
end
