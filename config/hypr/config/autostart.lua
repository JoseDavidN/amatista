hl.on("hyprland.start", function ()
    -- Pantalla de bloqueo al encender: el inicio de sesión es automático
    -- (tty1), así que la contraseña se pide aquí
    hl.exec_cmd("qs -c escritorio")

    -- Agente de polkit: muestra la ventana de contraseña
    -- cuando una aplicación pide permisos de administrador
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Fondo de pantalla
    hl.exec_cmd("hyprpaper")

    -- Historial del portapapeles (texto e imágenes)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
   
    -- Temporal para conexion remota
    hl.exec_cmd("wayvnc 127.0.0.1 5900")
end)
