// it stands for c(cool)hud
// created by xdf for her mods
// v0.1?

rawset(_G, "chud", {})
local cachedPatches = {}
local cachedSpritePatches = {}
local cachedSprite2Patches = {}

// caches a patch
function chud.cachePatch(v, string)
    local getPatch = v.cachePatch
    if cachedPatches[string] then return cachedPatches[string] end
    local patch = getPatch(string)
    cachedPatches[string] = patch
    return patch
end

// caches a sprite patch
function chud.cacheSpritePatch(v, sprite, frame, rotation, rollangle)
    local getPatch = v.getSpritePatch
    if cachedSpritePatches[sprite] then return cachedSpritePatches[sprite] end
    local patch = getPatch(sprite, frame, rotation, rollangle)
    cachedSpritePatches[sprite] = patch
    return patch
end

// caches a sprite2 patch
function chud.cacheSprite2Patch(v, skin, sprite2, super, frame, rotation, rollangle)
    local getPatch = v.getSprite2Patch
    if cachedSprite2Patches[string.format("%s-%s", skin, sprite2)] then return cachedSprite2Patches[string.format("%s-%s", skin, sprite2)] end
    local patch = getPatch(skin, sprite2, super, frame, rotation, rollangle)
    cachedSprite2Patches[string.format("%s-%s", skin, sprite2)] = patch
    return patch
end

// world to screen
function chud.worldToScreen(cam, x, y, z)
	local sx = cam.angle - R_PointToAngle(x, y)
	local visible = false
	local hdist = R_PointToDist(x, y)

	if sx > ANGLE_90 or sx < ANGLE_270 then
		visible = false
	else
		sx = doom.fixedMul(160*FU, tan($1)) + 160*FU
		visible = true
	end

	local sy = 100*FU + 160 * (tan(cam.aiming) - doom.fixedDiv(z-cam.z, 1 + doom.fixedMul(hdist, cos(cam.angle - R_PointToAngle(x, y))) ))
	local ss = doom.fixedDiv(160*FU, hdist)

	// x, y, scale
    return sx, sy, ss
end

chud.sw = {}

function chud.sw.create(width, height)
    local framebuffer =
    {
        pixels = {},
        width = width,
        height = height
    }

    for i = 1, width * height do
        framebuffer.pixels[i] = 0
    end

    return framebuffer
end

// draws a framebuffer inside another
// should be compatible with image!!
function chud.sw.addInto(destination, source, x, y, xscale, yscale)
    for sourceY = 0, source.height - 1 do
        for sourceX = 0, source.width - 1 do

            local color = source.pixels[sourceY * source.width + sourceX + 1]

            if color != -1 then
                for offsetY = 0, yscale - 1 do
                    local destinationY = y + sourceY * yscale + offsetY

                    if destinationY >= 0 and
                       destinationY < destination.height then

                        for offsetX = 0, xscale - 1 do
                            local destinationX = x + sourceX * xscale + offsetX

                            if destinationX >= 0 and
                               destinationX < destination.width then

                                destination.pixels[destinationY * destination.width + destinationX + 1] = color
                            end
                        end
                    end
                end
            end
        end
    end
end

// draws a framebuffer
function chud.sw.draw(v, framebuffer, posX, posY, xscale, yscale, flags)
    local coolerDrawFill = v.drawFill
    for y = 0, framebuffer.height - 1 do
        local x = 0

        while x < framebuffer.width do
            local color = framebuffer.pixels[(y*framebuffer.width)+(x+1)]

            if color == -1 then
                x = $ + 1
            else
                local startX = x

                while x < framebuffer.width and framebuffer.pixels[(y*framebuffer.width)+(x+1)] == color do
                    x = $ + 1
                end

                coolerDrawFill(posX+(startX*xscale), posY+(y*yscale), (x-startX)*xscale, yscale, color|flags)
            end
        end
    end
end

// draws a buffer of different palette
function chud.sw.drawPalette(v, framebuffer, palette, posX, posY, xscale, yscale, flags)
    local coolerDrawFill = v.drawFill

    for y = 0, framebuffer.height - 1 do
        local x = 0

        while x < framebuffer.width do
            local sourceColor = framebuffer.pixels[y * framebuffer.width + x + 1]

            if sourceColor == -1 then
                x = $ + 1
            else
                local startX = x

                while x < framebuffer.width and framebuffer.pixels[y * framebuffer.width + x + 1] == sourceColor do
                    x = $ + 1
                end

                local color = palette[sourceColor + 1]
                coolerDrawFill(posX+startX*xscale, posY+y*yscale, (x-startX)*xscale, yscale, color|flags)
            end
        end
    end
end
