-- SPDX-License-Identifier: GPL-2.0-only
-- Infrastructure only: no player powers, rate changes, shops or gameplay hooks.
local requested = false
local lastSave = os.time()
local event = GlobalEvent("OfflineLauncherLifecycle")
function event.onThink(interval)
    if requested then return true end
    local stop = io.open("offline-stop", "r")
    if stop then
        stop:close()
        requested = true
        saveServer()
        Game.setGameState(GAME_STATE_SHUTDOWN)
        return true
    end
    if os.time() - lastSave >= 60 then
        saveServer()
        lastSave = os.time()
    end
    return true
end
event:interval(1000)
event:register()
