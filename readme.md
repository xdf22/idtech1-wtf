# ???
### i dont know what to call this

recreation of the DOOM engine (IDTech 1) for SRB2

## Currently Implemented:
- IWAD loading
- BSP
- Polygon based renderer (WIP)
- COLORMAP Lighting
- PLAYPAL conversion (thank you color library i love you <3)
- PNAMES/TEXTURE1/TEXTURE2 support
- Menus
- Status bar (partial port)
- Melt Wipes

## Todo:
- Movement and actual physics (currently its a freecam)
- MIDI playback (i have an implementation for this, just needs more work)
- mobjs, with thinkinng and their actions
- shooting :screaming:
- fix up for netgames
- linedef actions and sector specials (for doors, switches, etc)
- Saving and loading
- Demo recording and playback
- Status messages at the top left corner of the screen
- general optimization
- Automap
- Clean up repeated code (is this true anymore?)

## Commands:
- `doom_loadwad [path/to/wad]` loads a wad from the path relative to `luafiles/`, please note the file extension whitelist that IO has, once a wad has been loaded, you will be thrown into the menu if its valid
- `doom_loadmap [MAP01/E1M1]` same as the `map` command in srb2
- `doom_setres [width] [height]` set the resolution of the game (no higher than 320x200)
