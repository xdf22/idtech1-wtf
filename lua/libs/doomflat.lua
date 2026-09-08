// doomflat image decoder
// functions:
// doomflat.cacheFile(string path)-caches a flat file from the specified path, otherwise use doomflat.cache for lumps
// doomflat.cache(string lumpname)-caches a flat lump with the specified name (ONLY WORKS ON CUSTOM BUILDS WITH io.openlocal)
// doomflat.decode(string data, size)-decodes doom flat data
// doomflat.draw(v, texture, int posX, int posY, flags, int scale)-draws a cached/decoded flat (texture) at
// 															         posX, posY with size of scale
// usage:
// local flat = doomflat.cache("F_SKY1")
// addHook("HUD", function(v)
//      if flat then
//		    doomflat.draw(v, flat, 10, 20, V_SNAPTOTOP|V_SNAPTOLEFT, 1)
//      end
//  end, "game")
//
// NOTE: functions take Size, otherwise automatically detects from the square root of #bytes

// this was slightly modified from the version in image

rawset(_G, "doomflat", {})

---draws a decoded doomflat
---@param v videolib: videolib variable
---@param texture table: decoded doomgfx from doomgfx.decode
---@param x integer: x position for drawing
---@param y integer: y position for drawing
---@param flags integer: V_ flags
---@param scale integer: size of the drawn image
function doomflat.draw(v, texture, x, y, flags, scale)
	scale = scale or 1
	local coolerDrawFill = v.drawFill

	for pixelY = 0, texture.size-1 do
		local row = pixelY * texture.size

		for pixelX = 0, texture.size-1 do
			local c = texture.pixels[row+pixelX]

			if c != nil then
				coolerDrawFill((x+pixelX)*scale, (y+pixelY)*scale, scale, scale, c|flags)
			end
		end
	end
end

---decodes flat data
---@param data string: flat data
---@return table decoded data: {width, height, pixels}
function doomflat.decode(data, size)
    if not data then
        return {}
    end

    if not size then
        size = 64
    end

    local flat =
    {
        width = size,
        height = size,
        size = size,
        pixels = {}
    }

    for i = 1, #data do
        flat.pixels[i] = data:byte(i)
    end

    return flat
end

---decodes flat data from a file
---@param path string: path to flat file
---@return table decoded data: {width, height, pixels}
function doomflat.cacheFile(path, size)
	local file = assert(io.openlocal(path, "rb"))
	local data = file:read("*all")
	file:close()

	return doomflat.decode(data, size)
end

---decodes flat data from a lump (REQUIRES io.openlump)
---@param name string: lump name
---@return table decoded data: {width, height, pixels}
function doomflat.cache(name, size)
	local file = io.openlump(name, "rb")
	local data = file:read("*all")
	file:close()

	return doomflat.decode(data, size)
end
