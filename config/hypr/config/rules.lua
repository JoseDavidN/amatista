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

-- No bloquear ni apagar la pantalla mientras haya algo en pantalla completa
-- (películas, videos, juegos), aunque la aplicación no lo pida por sí misma
hl.window_rule({
    name         = "idle-inhibit-fullscreen",
    match        = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Editor de capturas (satty, botón "Editar"): flotante y grande, para que la
-- captura se vea completa aunque el espacio tenga otras ventanas en mosaico
hl.window_rule({
    name   = "satty-editor",
    match  = { class = "^com\\.gabm\\.satty$" },
    float  = true,
    size   = "monitor_w*0.9 monitor_h*0.88",
    center = true,
})
