local WIDTH = 320
local HEIGHT = 200

local framebuffer = chud.sw.create(WIDTH, HEIGHT)
local map = nil

local wadfile = nil

function doom.enterMap(mapname, v)
    map = doom.loadmap(wadfile, mapname)

    if not map then
        print("failed to read map")
        return false
    end

    doom.prepareSegs(map)
    doomrenderer.buildPolygonCache(map)
    doomrenderer.buildSegCache(map)

    local start = doom.findstart(map)

    if not start then
        print("no start found for player 1")
        return false
    end

    gl.cam.x = start.x
    gl.cam.y = start.y

    local sector = doom.pointsector(map, start.x, start.y)

    if sector then
        gl.cam.z = sector.floorheight + 41*FU
    else
        gl.cam.z = 41*FU
    end

    gl.cam.yaw = FixedAngle(start.angle * FU)
    gl.cam.pitch = 0

    // todo: DO NOT USE CONSOLEPLAYER
    doom.startGameWipe(consoleplayer)

    return true
end

function doom.renderGame(player)
    doom.camera(player)
    gl.updateCamera()

    doomrenderer.render(map)

    doom.drawStatusBar()
end

addHook("HUD", function(v, player)
    if not framebuffer or not wadfile then
        return
    end

    local bg = v.cachePatch("WALL02_2")

	for tx = 0, v.width(), bg.width do
		for ty = 0, v.height(), bg.height do
			v.draw(tx, ty, bg, V_SNAPTOTOP|V_SNAPTOLEFT)
		end
	end

    gl.setFramebuffer(framebuffer)
    gl.clear(0)

    // reset vertex cache every frame
    gl.vertexCache = {}

    if doomwipe.active then
        doomwipe.update(1)
    else
        gl.clear(0)

        if map then
            doom.renderGame(player)
        else
            local title = doompatch.get("TITLEPIC")

            if title then
                doompatch.draw(title, 0, 0, 1, 1)
            end
        end
    end

    // todo: change this binding
    if player.cmd.buttons & BT_ATTACK then
        if not doommenu.menuactive then
            doommenu.startControlPanel()

            doommenu.lastButtons = player.cmd.buttons
            doommenu.lastForward = player.cmd.forwardmove
            doommenu.lastSide = player.cmd.sidemove

            return
        end
    end

    doommenu.ticker(player)
    doommenu.draw()

    chud.sw.drawPalette(v, framebuffer, doomtex.srb2palette, 0, 0, 320/WIDTH, 200/HEIGHT, 0)
end)

addHook("ThinkFrame", function()
    doom.updateFace() // cant put this in hud
end)

COM_AddCommand("doom_loadwad", function(player, arg1)
    wadfile = wad.open(arg1)

    if not wadfile or not wadfile.entries then
        print("failed to open file, is it a valid WAD?")
        wadfile = nil
        return
    end

    doomtex.load(wadfile)
    doom.buildFaces()

    print("WAD loaded")
end)

COM_AddCommand("doom_loadmap", function(player, arg1)
    if not wadfile then
        print("no WAD loaded")
        return
    end

    doom.enterMap(arg1:upper())
end)

COM_AddCommand("doom_setres", function(player, arg1, arg2)
    WIDTH = tonumber(arg1)
    HEIGHT = tonumber(arg2)
    framebuffer = chud.sw.create(WIDTH, HEIGHT)
end)
