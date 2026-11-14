-- Ignora las peticiones de maximamizar que hacen las propias aplicaciones
local suppressMaximizeRule = hl.window_rule({
    name    = "suppress-maximize-events",
    match   = { class = ".*" },
    suppress_event = "maximize",
})

-- Corrige probelmas al arrastrar en ventanas de aplicaciones XWayland
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class       = "^$",
        title       = "^$",
        xwayland    = true,
        float       = true,
        fullscreen  = false,
        pin         = false,
    },
    no_focus = true,
})

-- Ventana auxiliar de Hyprland: flotante, abajo a la izquierda
hl.window_rule({
    name    = "move-hyprland-run",
    match   = { class = "hyprland-run" },
    move    = "20 monitor_h-120",
    float   = true,
})

hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = ".*pavucontrol.*" },
    float = true,
})

hl.window_rule({
    name  = "float-blueman",
    match = { class = ".*blueman.*" },
    float = true,
})
