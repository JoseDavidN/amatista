hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(b98cffee)", "rgba(ff9ad5ee)" }, angle = 45 },
            inactive_border = "rgba(52406faa)",
        },
        resize_on_border    = false,
        allow_tearing       = false,
        layout              = "dwindle",
    },
    decoration = {
        rounding             = 10,
        rounding_power       = 2,
        active_opacity       = 1.0,
        inactive_opacity    = 1.0,
        shadow = {
            enabled         = true,
            range           = 4,
            render_power    = 3,
            color           = 0xee1a1a1a,
        },
        blur = {
            enabled     = true,
            size        = 4,
            passes       = 1,
            vibrancy    = 0.1696,
        },
    },
    dwindle     = { preserve_split = true },
    master      = { new_status = "master" },
    scrolling   = { fullscreen_on_one_column = true },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
        disable_splash_rendering = true,  -- quita la frase aleatoria de abajo
    },
})
