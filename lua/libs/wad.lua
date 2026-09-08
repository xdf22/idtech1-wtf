// wheres all the data? its right here you idiot
rawset(_G, "wad", {})

// reads a 32bit integer
local function readInt32(f)
    local b1, b2, b3, b4 = f:read(1):byte(), f:read(1):byte(), f:read(1):byte(), f:read(1):byte()
    return b1 + b2*256 + b3*65536 + b4*16777216
end

// writes a 32bit integer
local function writeInt32(f, v)
    f:write(string.char(v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255))
end

---opens a wad file from path, can have any file extension because of srb2lua io limitations
---@param path string: path to the wad
---@return table wad: {file, type, entries[X] = {offset, size, name, data}}
function wad.open(path)
    local f = io.openlocal(path, "rb")
    if not f then return {} end

    local wadfile =
	{
        file = f,
        path = path,
		type = f:read(4), // IWAD or PWAD
        numlumps = 0,
        dirpos = 0,
        entries = {}
    }

    wadfile.numlumps = readInt32(f)
    wadfile.dirpos = readInt32(f)
    f:seek("set", wadfile.dirpos)

    for i = 1, wadfile.numlumps do
        wadfile.entries[i] =
		{
            offset = readInt32(f),
            size = readInt32(f),
            name = f:read(8):gsub("%z", ""),
            data = nil // look below
        }
    end

    for i = 1, wadfile.numlumps do
        local entry = wadfile.entries[i]
        f:seek("set", entry.offset)
        entry.data = f:read(entry.size)
    end

    return wadfile
end

---prints the entries of "w" (wadfile) in a cool format: `[entrynumber] lumpname, size = lumpsize, offset = lumpoffset`
---@param wadfile table: file from wad.open
---@param indicators boolean: if true, adds indicators and shortens the size (idk if im using the correct name for this but just look below)
function wad.list(wadfile, indicators)
    if not wadfile then return end

    for i = 1, wadfile.numlumps do
        local entry = wadfile.entries[i]
        local sizeStr

        if indicators then
            if entry.size >= 1024 * 1024 then
                sizeStr = string.format("%d MB", entry.size / (1024 * 1024))
            elseif entry.size >= 1024 then
                sizeStr = string.format("%d KB", entry.size / 1024)
            else
                sizeStr = string.format("%d B", entry.size)
            end
        else
            sizeStr = tostring(entry.size)
        end

        print(string.format("[%d] %-8s, size=%s, offset=%d", i, entry.name, sizeStr, entry.offset))
    end
end

---closes the wad
---@param wadfile table: file from wad.open
function wad.close(wadfile)
    if wadfile and wadfile.file then
        wadfile.file:close()
        wadfile.file = nil
    end
end

---writes changes made to a wad/lump
---@param wadfile table: file from wad.open
---@param outpath string: the path and filename to output
function wad.write(wadfile, outpath)
    if not wadfile or not wadfile.entries then return false end

    local f = io.openlocal(outpath, "wb")
    if not f then return false end

    f:write(wadfile.type)

    local numlumps = wadfile.numlumps or #wadfile.entries
    local dir = 0

    writeInt32(f, numlumps)
    f:write("\0\0\0\0")

    local offsets = {}

    for i = 1, numlumps do
        local entry = wadfile.entries[i]
        offsets[i] = f:seek()

        if entry.data then
            f:write(entry.data)
        else
            f:write("")
        end
    end

    dir = f:seek()

    for i = 1, numlumps do
        local entry = wadfile.entries[i]
        local offset = offsets[i]
        local size = entry.data and #entry.data or 0

        writeInt32(f, offset)
        writeInt32(f, size)

        local name = entry.name or ""
        name = (name .. "        "):sub(1, 8)
        f:write(name)
    end

    f:seek("set", 8)
    writeInt32(f, dir)

    f:close()
    return true
end

---creates a new "wad"
---@param type string: can either be "PWAD" or "IWAD"
function wad.create(type)
	if type != "PWAD" or type != "IWAD" then type = "PWAD" end

    local wadfile =
	{
        type = type or "PWAD",
        path = "",
        entries = {},
        numlumps = 0,
        dirpos = 0,
        file = nil
    }

    return wadfile
end

---creates a new "lump" in the wad
---@param wadfile table: file from wad.open
---@param name string: name of the lump
---@param data string: data of the lump
function wad.addlump(wadfile, name, data)
    if not wadfile then return end

    local entry =
	{
        offset = 0,
        size = #data,
        name = name,
        data = data
    }

    table.insert(wadfile.entries, entry)
    wadfile.numlumps = #wadfile.entries
end

---removes the last lump in a wad
---@param wadfile table: file from wad.open
function wad.removelump(wadfile)
    if not wadfile then return end

    table.remove(wadfile.entries, wadfile.numlumps)
    wadfile.numlumps = #wadfile.entries
end
