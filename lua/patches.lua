// todo: cleanup
rawset(_G, "doompatch", {})

doompatch.cache = {}

// caches a new patch or return an already cached one
function doompatch.get(name)
    if not name or name == "" then
        return nil
    end

    local cached = doompatch.cache[name]

    if cached then
        return cached
    end

    local data = doom.lump(doomtex.wad, name, 1)

    if not data then
        return nil
    end

    local patch = doomgfx.decode(data)

    if patch then
        doompatch.cache[name] = patch
    end

    return patch
end

// v.drawScaled equivalent (integer scaling only, sorry lol)
function doompatch.draw(patch, x, y, scaleX, scaleY)
    if not gl.framebuffer or not patch then
        return
    end

    scaleX = scaleX or 1
    scaleY = scaleY or 1

    local framebuffer = gl.framebuffer
    local pixels = framebuffer.pixels

    local width = framebuffer.width
    local height = framebuffer.height

    local patchWidth = patch.width
    local patchHeight = patch.height

    // apply offsets
    local drawX = x - patch.leftoffset * scaleX
    local drawY = y - patch.topoffset * scaleY

    // resolution scaling
    local sx = FixedDiv(width * FU, 320 * FU)
    local sy = FixedDiv(height * FU, 200 * FU)

    for sourceY = 0, patchHeight - 1 do
        local logicalY = drawY + sourceY * scaleY
        local logicalY2 = logicalY + scaleY

        local destinationY = FixedInt(logicalY * sy)
        local destinationY2 = FixedInt(logicalY2 * sy)

        if destinationY2 > 0 and destinationY < height then
            local row = sourceY * patchWidth

            for sourceX = 0, patchWidth - 1 do
                local color = patch.pixels[row + sourceX + 1]

                if color != nil then
                    local logicalX = drawX + sourceX * scaleX
                    local logicalX2 = logicalX + scaleX

                    local destinationX = FixedInt(logicalX * sx)
                    local destinationX2 = FixedInt(logicalX2 * sx)

                    if destinationX2 > 0 and destinationX < width then
                        local startX = destinationX
                        local endX = destinationX2
                        local startY = destinationY
                        local endY = destinationY2

                        if startX < 0 then startX = 0 end
                        if startY < 0 then startY = 0 end
                        if endX > width then endX = width end
                        if endY > height then endY = height end

                        for py = startY, endY - 1 do
                            local base = py * width

                            for px = startX, endX - 1 do
                                pixels[base + px + 1] = color
                            end
                        end
                    end
                end
            end
        end
    end
end

// status bar big number drawing
function doompatch.drawNumber(number, x, y, scaleX, scaleY, percent)
    scaleX = scaleX or 1
    scaleY = scaleY or 1

    if number < 0 then
        number = 0
    end

    // font is monospace, every digit takes the same width as the 0 digit
    local zero = doompatch.get("STTNUM0")

    if not zero then
        return
    end

    local digitWidth = zero.width * scaleX
    local digits = {}

    repeat
        local digit = number % 10

        digits[#digits + 1] = digit

        number = ($ - digit) / 10
    until number == 0

    // draw digits
    local drawX = x

    for i = 1, #digits do
        drawX = $ - digitWidth

        local patch = doompatch.get(string.format("STTNUM%d", digits[i]))

        if patch then
            doompatch.draw(patch, drawX, y, scaleX, scaleY)
        end
    end

    // percentage sign
    if percent then
        local percentPatch = doompatch.get("STTPRCNT")

        if percentPatch then
            doompatch.draw(percentPatch, x, y, scaleX, scaleY)
        end
    end
end
