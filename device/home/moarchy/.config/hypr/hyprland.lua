-- Phone entry point: willow.lua holds the session, device.lua this phone's display values.
local dir = os.getenv("HOME") .. "/.config/hypr/"
dofile(dir .. "willow.lua")(dofile(dir .. "device.lua"), {
    shell = os.getenv("HOME") .. "/.config/quickshell/willow.qml",
    keyboard = true,
})
