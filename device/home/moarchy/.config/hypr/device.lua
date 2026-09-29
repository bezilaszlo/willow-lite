-- Willow (Redmi Note 8) display values, the only phone-specific part of the Hyprland config.
-- The 1080x2340 panel at scale 2 gives the shell a 540x1170 logical canvas.
return {
    output = "DSI-1",
    mode = "1080x2340@60",
    scale = 2,
    transform = 0,
}
