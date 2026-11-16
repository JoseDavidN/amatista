hl.on("hyprland.start", function ()
    -- Escritorio (barra, notificaciones, bloqueo). El inicio de sesión
    -- lo hace greetd antes de llegar aquí
    hl.exec_cmd("qs -c escritorio")

    -- Agente de polkit: muestra la ventana de contraseña
    -- cuando una aplicación pide permisos de administrador
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Fondo de pantalla
    hl.exec_cmd("hyprpaper")

    -- Historial del portapapeles (texto e imágenes)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
