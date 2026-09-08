// doom patch image decoder
// functions:
// doomgfx.cacheFile(string path)-caches a patch file from the specified path, otherwise use doomgfx.cache for lumps
// doomgfx.cache(string lumpname)-caches a patch lump with the specified name (ONLY WORKS ON CUSTOM BUILDS WITH io.openlocal)
// doomgfx.decode(string data)-decodes patch data
// doomgfx.draw(v, texture, int posX, int posY, flags, int scaleX, int scaleY)-draws a cached/decoded patch (texture) at
// 															    		         posX, posY with size of scaleX and scaleY
// usage:
// local patch = doomgfx.cache("ACRED02")
// addHook("HUD", function(v)
//      if patch then
//		    doomgfx.draw(v, flat, 10, 20, V_SNAPTOTOP|V_SNAPTOLEFT, 1, 1)
//      end
//  end, "game")
//
// NOTE: why would you use this instead of the builtin functions

// 9/2/2026: to make doom in srb2 :grin:

rawset(_G,"doomgfx",{})

// helper functions
local function UINT16(d, i)
    return d:byte(i) + d:byte(i + 1) * 256
end

local function UINT32(d,i)
	return d:byte(i)
	+ d:byte(i+1)*256
	+ d:byte(i+2)*65536
	+ d:byte(i+3)*16777216
end

---decodes doomgfx data
---@param data string: doomgfx data
---@return table decoded data: {width, height, pixels}
function doomgfx.decode(data)
    local width, height = UINT16(data,1), UINT16(data,3)
    local pixels = {}

    local leftoffset = doom.s16(data, 5)
    local topoffset = doom.s16(data, 7)

    for x = 0, width-1 do
        local columnPtr = UINT32(data, 9+x*4)+1

        while true do
            local yStart = data:byte(columnPtr)
            if yStart == 255 then break end

            local length = data:byte(columnPtr+1)
            columnPtr = columnPtr+3

            for i = 0, length-1 do
                local idx = (yStart + i) * width + x + 1
                pixels[idx] = data:byte(columnPtr+i)
            end

            columnPtr = columnPtr+length+1
        end
    end

    return {width = width, height = height, pixels = pixels, leftoffset = leftoffset, topoffset = topoffset}
end

---draws a decoded doomgfx
---@param v videolib: videolib variable
---@param texture table: decoded doomgfx from doomgfx.decode
---@param posX integer: x position for drawing
---@param posY integer: y position for drawing
---@param flags integer: V_ flags
---@param scaleX integer: X size of the drawn image
---@param scaleY integer: Y size of the drawn image
function doomgfx.draw(v, texture, posX, posY, flags, scaleX, scaleY)
	scaleX = $ or 1
	scaleY = $ or 1
	local coolerDrawFill = v.drawFill

	for pixelY = 0, texture.height-1 do
		local row = pixelY-texture.width

		for pixelX = 0, texture.width-1 do
			local color = texture.pixels[row+pixelX]
			if color != nil then
				coolerDrawFill((posX+pixelX)*scaleX, (posY+pixelY)*scaleY, scaleX, scaleY, color|flags)
			end

			if texture.pixels[row+pixelX] > 255 then texture.pixels[row+pixelX] = 0 end
		end
	end
end

---decodes doomgfx data from a file
---@param path string: path to doomgfx file
---@return table decoded data: {width, height, pixels}
function doomgfx.cacheFile(path)
	local f = assert(io.openlocal(path, "rb"))
	local data = f:read("*a")
	f:close()

	return doomgfx.decode(data)
end

---decodes doomgfx data from a lump (REQUIRES io.openlump)
---@param name string: lump name
---@return table decoded data: {width, height, pixels}
function doomgfx.cache(name)
	local f = assert(wad.getlump(name))
	local data = f.data

	return doomgfx.decode(data)
end
