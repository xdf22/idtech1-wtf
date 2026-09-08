
// player 1 start
function doom.findstart(map)
    for i = 1, #map.things do
        local thing = map.things[i]

        if thing.type == 1 then
            return thing
        end
    end

    return nil
end

// camera movement
// todo: improve
function doom.camera(player)
    local cmd = player.cmd

    local speed = 8*FU

    local forward = doom.fixedMul(doom.fixedDiv(cmd.sidemove*FU, 50*FU), speed)
    local side = doom.fixedMul(doom.fixedDiv(cmd.forwardmove*FU, 50*FU), speed)

    if cmd.buttons & BT_JUMP then
        gl.cam.z = $ + speed
    end

    if cmd.buttons & BT_SPIN then
        gl.cam.z = $ - speed
    end

    local s = sin(gl.cam.yaw)
    local c = cos(gl.cam.yaw)

    gl.cam.x = $ + doom.fixedMul(c, forward)-doom.fixedMul(s, side)
    gl.cam.y = $ + doom.fixedMul(s, forward)+doom.fixedMul(c, side)

    gl.cam.yaw = camera.angle
    gl.cam.pitch = camera.aiming
end
