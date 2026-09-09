rawset(_G, "doomtex", {})

doomtex.pnames = {}
doomtex.textures = {}
doomtex.wad = nil
doomtex.colormaps = {}
doomtex.patchCache = {}
doomtex.textureCache = {}
doomtex.playpal = {}
doomtex.spriteFrames = {}

// PLAYPAL
function doomtex.loadPlaypal(data)
    doomtex.playpal = {}

    if not data or #data < 768 then
        return
    end

    for i = 0, 255 do
        local p = i * 3 + 1

        doomtex.playpal[i + 1] =
        {
            data:byte(p),
            data:byte(p + 1),
            data:byte(p + 2)
        }
    end
end

// builds a 2.2 palette out of the doom one
doomtex.srb2palette = {}

function doomtex.buildPalette()
    doomtex.srb2palette = {}

    for i = 1, 256 do
        local rgb = doomtex.playpal[i]

        if rgb then
            doomtex.srb2palette[i] = color.rgbToPalette(rgb[1], rgb[2], rgb[3])
        end
    end
end

// COLORMAP
function doomtex.loadColormap(data)
    doomtex.colormaps = {}
    if not data or #data < 32 * 256 then return end

    for map = 0, (#data / 256) - 1 do
        local colormap = {}

        for color = 0, 255 do
            colormap[color + 1] = data:byte(map * 256 + color + 1)
        end

        doomtex.colormaps[map + 1] = colormap
    end
end

function doomtex.name(data, p)
    return data:sub(p, p + 7):gsub("%z", ""):gsub("%s+$", ""):upper()
end

// PNAMES
function doomtex.loadPNames(data)
    doomtex.pnames = {}
    if not data or #data < 4 then return end

    local count = doom.u32(data, 1)

    for i = 0, count - 1 do
        local p = 5 + i * 8
        if p + 7 > #data then break end
        doomtex.pnames[i + 1] = doomtex.name(data, p)
    end
end

// TEXTURE1/TEXTURE2
function doomtex.loadTextures(data)
    if not data or #data < 4 then return end

    local count = doom.u32(data, 1)

    for i = 0, count - 1 do
        local op = 5 + i * 4
        if op + 3 > #data then break end

        local p = doom.u32(data, op) + 1

        if p + 21 > #data then break end

        local name = doomtex.name(data, p)
        local patches = {}
        local patchcount = doom.u16(data, p + 20)

        for j = 0, patchcount - 1 do
            local pp = p + 22 + j * 10
            if pp + 9 > #data then break end

            patches[#patches + 1] =
            {
                originx = doom.s16(data, pp),
                originy = doom.s16(data, pp + 2),
                patch = doom.u16(data, pp + 4),
                stepdir = doom.s16(data, pp + 6),
                colormap = doom.s16(data, pp + 8)
            }
        end

        doomtex.textures[name] =
        {
            name = name,
            masked = doom.u32(data, p + 8),
            width = doom.u16(data, p + 12),
            height = doom.u16(data, p + 14),
            patches = patches
        }
    end
end

// sprites
function doomtex.initSprites()
    if not doomtex.wad or not doomtex.wad.entries then
        return
    end

    for i = 1, doomtex.wad.numlumps do
        local lump = doomtex.wad.entries[i]
        local name = lump.name

        if name then
            name = name:gsub("%z", ""):gsub("%s+$", ""):upper()

            if #name == 6 or #name == 8 then
                local sprite = name:sub(1, 4)
                local frame1 = name:sub(5, 5)
                local rot1 = name:sub(6, 6)

                if frame1:match("^[A-Z]$") and rot1:match("^[0-8]$") then
                    local frames = doomtex.spriteFrames[sprite]

                    if not frames then
                        frames = {}
                        doomtex.spriteFrames[sprite] = frames
                    end

                    local frameIndex = string.byte(frame1) - string.byte("A")
                    local frame = frames[frameIndex]

                    if not frame then
                        frame =
                        {
                            rotate = false,
                            lump = {},
                            flip = {}
                        }

                        frames[frameIndex] = frame
                    end

                    if rot1 == "0" and #name == 6 then
                        frame.rotate = false
                        frame.lump[0] = i
                        frame.flip[0] = false
                    elseif rot1 != "0" then
                        local rotation = string.byte(rot1) - string.byte("1")

                        frame.rotate = true
                        frame.lump[rotation] = i
                        frame.flip[rotation] = false

                        if #name == 8 then
                            local frame2 = name:sub(7, 7)
                            local rot2 = name:sub(8, 8)

                            if frame2:match("^[A-Z]$") and rot2:match("^[1-8]$") then
                                local rotation2 = string.byte(rot2) - string.byte("1")
                                local frameIndex2 = string.byte(frame2) - string.byte("A")
                                local frame2data = frames[frameIndex2]

                                if not frame2data then
                                    frame2data =
                                    {
                                        rotate = false,
                                        lump = {},
                                        flip = {}
                                    }

                                    frames[frameIndex2] = frame2data
                                end

                                frame2data.rotate = true
                                frame2data.lump[rotation2] = i
                                frame2data.flip[rotation2] = true
                            end
                        end
                    end
                end
            end
        end
    end
end

// i guess this is like R_InitData or whatever its called
function doomtex.load(wadfile)
    doomtex.wad = wadfile
    doomtex.pnames = {}
    doomtex.textures = {}
    doomtex.colormaps = {}
    doomtex.patchCache = {}
    doomtex.textureCache = {}
    doomtex.playpal = {}
    doomtex.spriteFrames = {}

    if not wadfile then return end

    doomtex.loadPNames(doom.lump(wadfile, "PNAMES", 1))
    doomtex.loadTextures(doom.lump(wadfile, "TEXTURE1", 1))
    doomtex.loadTextures(doom.lump(wadfile, "TEXTURE2", 1))
    doomtex.loadColormap(doom.lump(wadfile, "COLORMAP", 1))
    doomtex.loadPlaypal(doom.lump(wadfile, "PLAYPAL", 1))
    doomtex.buildPalette()
    doomtex.initSprites()
end

function doomtex.patch(name)
    if not doomtex.wad or not name then return nil end

    name = name:gsub("%z", ""):gsub("%s+$", ""):upper()

    if name == "" or name == "-" then return nil end

    if doomtex.patchCache[name] then
        return doomtex.patchCache[name]
    end

    local data = doom.lump(doomtex.wad, name, 1)
    if not data or #data < 12 then return nil end

    local patch = doomgfx.decode(data)

    if patch and patch.width and patch.height and patch.pixels then
        doomtex.patchCache[name] = patch
        return patch
    end

    return nil
end

function doomtex.build(name)
    if not name then return nil end

    name = name:gsub("%z", ""):gsub("%s+$", ""):upper()

    if name == "" or name == "-" then return nil end

    if doomtex.textureCache[name] then
        return doomtex.textureCache[name]
    end

    local texture = doomtex.textures[name]

    if not texture then
        local patch = doomtex.patch(name)

        if patch then
            doomtex.textureCache[name] = patch
        end

        return patch
    end

    if texture.width <= 0 or texture.height <= 0 then
        return nil
    end

    local output = chud.sw.create(texture.width, texture.height)

    for i = 1, #output.pixels do
        output.pixels[i] = -1
    end

    for i = 1, #texture.patches do
        local info = texture.patches[i]
        local patchname = doomtex.pnames[info.patch + 1]

        if patchname then
            local patch = doomtex.patch(patchname)

            if patch then
                for py = 0, patch.height - 1 do
                    for px = 0, patch.width - 1 do
                        local source = patch.pixels[py * patch.width + px + 1]

                        if source != nil and source != -1 then
                            local x = info.originx + px
                            local y = info.originy + py

                            if x >= 0 and x < output.width and y >= 0 and y < output.height then
                                output.pixels[y * output.width + x + 1] = source
                            end
                        end
                    end
                end
            end
        end
    end

    doomtex.textureCache[name] = output
    return output
end

// returns the patch (and flip status) of a sprite string, its frame and rotation
function doomtex.sprite(sprite, frame, rotation)
    if not doomtex.spriteFrames then
        return nil
    end

    if not sprite then
        return nil
    end

    sprite = sprite:upper()

    if sprite:sub(1, 4) == "SPR_" then
        sprite = sprite:sub(5)
    end

    sprite = sprite:sub(1, 4)

    frame = $ & 15
    rotation = $ & 7

    local spriteTable = doomtex.spriteFrames[sprite]

    if not spriteTable then
        print(string.format("SPRITE: no table for %s", sprite))
        return nil
    end

    local frameData = spriteTable[frame]

    if not frameData then
        print(string.format("SPRITE: no frame %d for sprite %s", frame, sprite))
        return nil
    end

    local lumpnum = frameData.lump[rotation]

    if not lumpnum then
        lumpnum = frameData.lump[0]

        if not lumpnum then
            return nil
        end
    end

    local lump = doomtex.wad.entries[lumpnum]

    if not lump then
        return nil
    end

    local patch = doomtex.patch(lump.name:gsub("%z", ""):gsub("%s+$", ""):upper())

    if not patch then
        return nil
    end

    return
    {
        patch = patch,
        flip = frameData.flip[rotation] or false
    }
end
