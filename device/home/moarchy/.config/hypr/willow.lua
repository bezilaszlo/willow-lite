-- Willow Lite Hyprland session, independent of the phone model.
-- device: output, mode, scale, transform. session: shell (QML path), keyboard (start wvkbd).
return function(device, session)
    hl.monitor({
        output = device.output,
        mode = device.mode,
        position = "0x0",
        scale = device.scale,
        transform = device.transform or 0,
    })

    hl.config({
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = 0,
            -- One app at a time fills the space the bar and keyboard leave.
            layout = "monocle",
        },
        decoration = {
            rounding = 0,
            shadow = { enabled = false },
            blur = { enabled = false },
        },
        animations = { enabled = true },
        input = {
            kb_layout = "us",
            touchdevice = { output = device.output },
        },
        cursor = {
            invisible = true,
            no_hardware_cursors = 1,
            hide_on_touch = true,
        },
        misc = {
            force_default_wallpaper = 0,
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            disable_watchdog_warning = true,
            background_color = 0xff111827,
            focus_on_activate = true,
        },
        ecosystem = {
            no_update_news = true,
            no_donation_nag = true,
        },
    })

    -- Short, cheap motion: fades and small pop-ins, no blur or shadows.
    hl.curve("willowOut", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
    hl.animation({ leaf = "global", enabled = true, speed = 3, bezier = "willowOut" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "willowOut", style = "popin 92%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "willowOut", style = "popin 92%" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "willowOut" })
    hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "willowOut" })
    hl.animation({ leaf = "layersIn", enabled = true, speed = 2.5, bezier = "willowOut", style = "fade" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "willowOut", style = "fade" })
    hl.animation({ leaf = "border", enabled = false })
    hl.animation({ leaf = "workspaces", enabled = false })
    hl.layer_rule({ name = "keyboard-slide", match = { namespace = "^wvkbd$" }, animation = "slide bottom" })
    -- Quickshell animates its own panels; a compositor fade on top would lag the finger.
    hl.layer_rule({ name = "shell-no-anim", match = { namespace = "^(quickshell|willow-.*)$" }, no_anim = true })

    hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
    hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
    hl.bind("SUPER + SHIFT + E", hl.dsp.exit())

    hl.on("hyprland.start", function()
        hl.exec_cmd("qs -p " .. session.shell)
        hl.exec_cmd("sh -c 'pid=$(pgrep -n -x Hyprland); [ -n \"$pid\" ] && exec systemd-cat -t willow-screenshot willow-screenshot-gesture --session-pid \"$pid\"'")
        if session.keyboard then
            hl.exec_cmd("wvkbd-mobintl -H 310 --hidden --wayland-layer overlay")
        end
    end)
end
