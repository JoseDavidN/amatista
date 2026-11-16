-- Hyprland del greeter: corre como el usuario "greeter" y solo muestra
-- la pantalla de inicio de sesión. Tu sesión real usa ~/.config/hypr.

-- Mismo cursor que el escritorio
hl.env("XCURSOR_THEME", "Amatista")
hl.env("XCURSOR_SIZE", "24")

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

hl.config({
    input = {
        kb_layout = "latam",
    },
    animations = {
        enabled = false,
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },
})

hl.on("hyprland.start", function ()
    hl.exec_cmd("/etc/greetd/iniciar-greeter.sh")
end)
