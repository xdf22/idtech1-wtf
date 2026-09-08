// yes, this is heavily borrowed from m_menu.c
rawset(_G, "doommenu", {})

doommenu.currentMenu = nil
doommenu.itemOn = 0
doommenu.menuactive = false

doommenu.whichSkull = 0
doommenu.skullAnimCounter = 10

doommenu.epi = 0

doommenu.lastForward = 0
doommenu.lastSide = 0
doommenu.lastButtons = 0

// menu definitions
doommenu.MainMenu =
{
    {status = 1, patch = "M_NGAME", routine = "newgame", alphaKey = "n"},
    {status = 1, patch = "M_OPTION", routine = nil, alphaKey = "o"},
    {status = 1, patch = "M_LOADG", routine = nil, alphaKey = "l"},
    {status = 1, patch = "M_SAVEG", routine = nil, alphaKey = "s"},
    {status = 1, patch = "M_RDTHIS", routine = "readthis", alphaKey = "r"},
    {status = 1, patch = "M_QUITG", routine = nil, alphaKey = "q"}
}

doommenu.MainDef =
{
    numitems = #doommenu.MainMenu,
    prevMenu = nil,
    items = doommenu.MainMenu,
    routine = "drawMainMenu",
    x = 97,
    y = 64,
    lastOn = 0
}

doommenu.EpisodeMenu =
{
    {status = 1, patch = "M_EPI1", routine = "episode", alphaKey = "k"},
    {status = 1, patch = "M_EPI2", routine = "episode", alphaKey = "t"},
    {status = 1, patch = "M_EPI3", routine = "episode", alphaKey = "i"},
    {status = 1, patch = "M_EPI4", routine = "episode", alphaKey = "t"}
}

doommenu.EpiDef =
{
    numitems = #doommenu.EpisodeMenu,
    prevMenu = doommenu.MainDef,
    items = doommenu.EpisodeMenu,
    routine = "drawEpisode",
    x = 48,
    y = 63,
    lastOn = 0
}

doommenu.NewGameMenu =
{
    {status = 1, patch = "M_JKILL", routine = "skill", alphaKey = "i"},
    {status = 1, patch = "M_ROUGH", routine = "skill", alphaKey = "h"},
    {status = 1, patch = "M_HURT", routine = "skill", alphaKey = "h"},
    {status = 1, patch = "M_ULTRA", routine = "skill", alphaKey = "u"},
    {status = 1, patch = "M_NMARE", routine = "skill", alphaKey = "n"}
}

doommenu.NewDef =
{
    numitems = #doommenu.NewGameMenu,
    prevMenu = doommenu.EpiDef,
    items = doommenu.NewGameMenu,
    routine = "drawNewGame",
    x = 48,
    y = 63,
    lastOn = 2
}

doommenu.ReadMenu1 =
{
    {status = 1, patch = "", routine = "readthis2", alphaKey = nil}
}

doommenu.ReadDef1 =
{
    numitems = 1,
    prevMenu = doommenu.MainDef,
    items = doommenu.ReadMenu1,
    routine = "drawReadThis1",
    x = 280,
    y = 185,
    lastOn = 0
}

doommenu.ReadMenu2 =
{
    {status = 1, patch = "", routine = "finishReadThis", alphaKey = nil}
}

doommenu.ReadDef2 =
{
    numitems = 1,
    prevMenu = doommenu.ReadDef1,
    items = doommenu.ReadMenu2,
    routine = "drawReadThis2",
    x = 330,
    y = 175,
    lastOn = 0
}

// initialization
function doommenu.init()
    doommenu.currentMenu = doommenu.MainDef
    doommenu.menuactive = false

    doommenu.itemOn = doommenu.currentMenu.lastOn

    doommenu.whichSkull = 0
    doommenu.skullAnimCounter = 10

    doommenu.epi = 0

    doommenu.lastForward = 0
    doommenu.lastSide = 0
    doommenu.lastButtons = 0
end

doommenu.init()

function doommenu.clearMenus()
    doommenu.menuactive = false
end

function doommenu.setupNextMenu(menu)
    doommenu.currentMenu = menu
    doommenu.itemOn = menu.lastOn
end

function doommenu.startControlPanel()
    if doommenu.menuactive then
        return
    end

    doommenu.menuactive = true

    doommenu.currentMenu = doommenu.MainDef
    doommenu.itemOn = doommenu.currentMenu.lastOn
end

// helper functions
local function getItem()
    local menu = doommenu.currentMenu

    if not menu then
        return nil
    end

    return menu.items[doommenu.itemOn + 1]
end

local function moveDown()
    local menu = doommenu.currentMenu

    if not menu then
        return
    end

    repeat
        doommenu.itemOn = doommenu.itemOn + 1

        if doommenu.itemOn >= menu.numitems then
            doommenu.itemOn = 0
        end
    until menu.items[doommenu.itemOn + 1].status != -1
end

local function moveUp()
    local menu = doommenu.currentMenu

    if not menu then
        return
    end

    repeat
        doommenu.itemOn = doommenu.itemOn - 1

        if doommenu.itemOn < 0 then
            doommenu.itemOn = menu.numitems - 1
        end
    until menu.items[doommenu.itemOn + 1].status != -1
end

function doommenu.newgame(choice)
    // todo: doom 2 has no episodes (gamemode commercial)
    doommenu.setupNextMenu(doommenu.EpiDef)
end

// reading this
function doommenu.readthis(choice)
    doommenu.setupNextMenu(doommenu.ReadDef1)
end

function doommenu.readthis2(choice)
    doommenu.setupNextMenu(doommenu.ReadDef2)
end

function doommenu.finishReadThis(choice)
    doommenu.setupNextMenu(doommenu.MainDef)
end

// episode
function doommenu.episode(choice)
    doommenu.epi = choice
    doommenu.setupNextMenu(doommenu.NewDef)
end

// confirm nightmare
function doommenu.verifyNightmare(ch)
    if ch != "y" then
        return
    end

    doommenu.clearMenus()

    if doommenu.startGame then
        doommenu.startGame(4, doommenu.epi + 1, 1)
    end
end

function doommenu.skill(choice)
    if choice == 4 then
        doommenu.nightmareMessage = true
        return
    end

    local episode = doommenu.epi + 1
    local mapname = "E" .. episode .. "M1"

    if doom.enterMap(mapname) then
        doommenu.clearMenus()
    elseif doom.enterMap("MAP01") then // doom 2 hack
        doommenu.clearMenus()
    end
end

// drawers
function doommenu.drawMainMenu()
    local patch = doompatch.get("M_DOOM")

    if patch then
        doompatch.draw(patch, 94, 2, 1, 1)
    end
end

function doommenu.drawNewGame()
    local patch = doompatch.get("M_NEWG")

    if patch then
        doompatch.draw(patch, 96, 14, 1, 1)
    end

    patch = doompatch.get("M_SKILL")

    if patch then
        doompatch.draw(patch, 54, 38, 1, 1)
    end
end

function doommenu.drawEpisode()
    local patch = doompatch.get("M_EPISOD")

    if patch then
        doompatch.draw(patch, 54, 38, 1, 1)
    end
end

function doommenu.drawReadThis1()
    local patch = doompatch.get("HELP1")

    if patch then
        doompatch.draw(patch, 0, 0, 1, 1)
    end
end

function doommenu.drawReadThis2()
    local patch = doompatch.get("HELP2")

    if patch then
        doompatch.draw(patch, 0, 0, 1, 1)
    end
end

// M_Drawer
function doommenu.draw()
    if not doommenu.menuactive then
        return
    end

    local menu = doommenu.currentMenu

    if not menu then
        return
    end

    // does the menu have its own drawer?
    if menu.routine then
        local routine = doommenu[menu.routine]

        if routine then
            routine()
        end
    end

    // menu items
    local x = menu.x
    local y = menu.y

    for i = 1, menu.numitems do
        local item = menu.items[i]

        if item.patch != "" then
            local patch = doompatch.get(item.patch)

            if patch then
                doompatch.draw(patch, x, y, 1, 1)
            end
        end

        y = $ + 16
    end

    // skull cursor
    local skull

    if doommenu.whichSkull == 0 then
        skull = doompatch.get("M_SKULL1")
    else
        skull = doompatch.get("M_SKULL2")
    end

    if skull then
        doompatch.draw(skull, x - 25, menu.y - 5 + doommenu.itemOn * 16, 1, 1)
    end
end

// M_Responder and M_Ticker
function doommenu.ticker(player)
    if not player then
        return
    end

    local cmd = player.cmd

    if not cmd then
        return
    end

    // skull cusor animationn
    doommenu.skullAnimCounter = doommenu.skullAnimCounter - 1

    if doommenu.skullAnimCounter <= 0 then
        doommenu.whichSkull = doommenu.whichSkull ^ 1
        doommenu.skullAnimCounter = 8
    end

    // controls
    local forward = cmd.forwardmove or 0
    local side = cmd.sidemove or 0
    local buttons = cmd.buttons or 0

    local forwardPressed = forward != 0 and doommenu.lastForward == 0
    local sidePressed = side != 0 and doommenu.lastSide == 0
    local buttonsPressed = buttons & ~doommenu.lastButtons

    doommenu.lastForward = forward
    doommenu.lastSide = side
    doommenu.lastButtons = buttons

    if not doommenu.menuactive then
        return
    end

    // nightmare difficulty
    if doommenu.nightmareMessage then
        // enter
        if buttonsPressed & BT_JUMP then
            doommenu.nightmareMessage = false
            doommenu.clearMenus()

            if doommenu.startGame then
                doommenu.startGame(4, doommenu.epi + 1, 1)
            end

            return
        end

        if forwardPressed or sidePressed then
            doommenu.nightmareMessage = false
            return
        end

        return
    end

    // up/down
    if forwardPressed then
        if forward > 0 then
            moveUp()
        else
            moveDown()
        end

        return
    end

    // left/right
    if sidePressed then
        local item = getItem()

        if item and item.routine and item.status == 2 then
            local routine = doommenu[item.routine]

            if routine then
                if side < 0 then
                    routine(0)
                else
                    routine(1)
                end
            end
        end

        return
    end

    // enter
    if buttonsPressed & BT_JUMP then
        local item = getItem()

        if item and item.routine and item.status != 0 and item.status != -1 then
            local routine = doommenu[item.routine]

            if routine then
                routine(doommenu.itemOn)
            end

            doommenu.currentMenu.lastOn = doommenu.itemOn
        end

        return
    end

    // escape
    if buttonsPressed & BT_SPIN then
        doommenu.currentMenu.lastOn = doommenu.itemOn
        doommenu.clearMenus()
        return
    end
end
