-- ==========================================================
-- Atajos de teclado
--
-- Cada atajo lleva una descripcion con la forma "Categoria: Texto".
-- El panel de ayuda (Super + A) lee `hyprctl binds -j` al abrirse,
-- agrupa por la categoria (lo que va antes de ": ") y muestra el texto.
--   - Las categorias aparecen en el orden en que se definen aqui.
--   - Atajos con la MISMA descripcion se muestran en una sola fila
--     (por ejemplo los espacios 1-10, o Play y Pausa).
--   - Un atajo sin descripcion no aparece en el panel.
--
-- Ejemplo para añadir uno nuevo:
--   hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("..."), { description = "Escritorio: Hacer algo" })
-- ==========================================================
local programs = require("config.programs")

local mainMod = "SUPER" -- tecla windows como modificador principal

local qs = "qs -c escritorio ipc call " -- prefijo para hablar con Quickshell

-- ---------- Aplicaciones ----------
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(programs.terminal),    { description = "Aplicaciones: Terminal" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(programs.fileManager), { description = "Aplicaciones: Archivos" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(programs.browser),     { description = "Aplicaciones: Navegador" })

-- ---------- Escritorio (paneles de Quickshell) ----------
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(qs .. "lanzador alternar"),     { description = "Escritorio: Lanzador (apps, fondos y sesión)" })
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd(qs .. "fondos alternar"),       { description = "Escritorio: Elegir fondo de pantalla" })
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(qs .. "portapapeles alternar"), { description = "Escritorio: Historial del portapapeles" })
-- Ayuda de atajos (Super + A)
hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd(qs .. "ayuda alternar"),        { description = "Escritorio: Ver atajos de teclado" })

-- ---------- Sistema ----------
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("~/.local/bin/bloquear"),       { description = "Sistema: Bloquear pantalla" })
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(qs .. "inactividad alternar"),  { description = "Sistema: Activar/desactivar modo cafeína" })
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"),
    { description = "Sistema: Cerrar sesión de Hyprland" })

-- ---------- Ventanas ----------
hl.bind(mainMod .. " + C", hl.dsp.window.close(),                   { description = "Ventanas: Cerrar ventana" })
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Ventanas: Flotante / en mosaico" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(),                  { description = "Ventanas: Modo pseudo-mosaico" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"),            { description = "Ventanas: Cambiar división horizontal/vertical" }) -- solo con dwindle

-- Mover el foco con las flechas
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { description = "Ventanas: Enfocar ventana a la izquierda" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Ventanas: Enfocar ventana a la derecha" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { description = "Ventanas: Enfocar ventana de arriba" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { description = "Ventanas: Enfocar ventana de abajo" })

-- Mover y redimensionar ventanas con el mouse (clic izquierdo / derecho)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Ventanas: Mover ventana (arrastrar)" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Ventanas: Redimensionar ventana (arrastrar)" })

-- ---------- Espacios de trabajo ----------
-- 1-10: ir a uno, o mover la ventana a uno (misma descripcion = una sola fila en el panel)
for i = 1, 10 do
    local key = i % 10 -- el 10 corresponde a la tecla 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       { description = "Espacios: Ir al espacio" })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Espacios: Mover ventana al espacio" })
end

-- Espacio especial ("scratchpad")
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"),          { description = "Espacios: Mostrar/ocultar espacio especial" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Espacios: Mover ventana al espacio especial" })

-- Cambiar de espacio con la rueda del mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Espacios: Espacio siguiente" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Espacios: Espacio anterior" })

-- ---------- Multimedia ----------
-- Volumen (el OSD aparece solo)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Multimedia: Subir volumen" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true, description = "Multimedia: Bajar volumen" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true, description = "Multimedia: Silenciar" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true, description = "Multimedia: Silenciar micrófono" })

-- Reproductor
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Multimedia: Reproducir / pausar" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Multimedia: Reproducir / pausar" })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Multimedia: Pista siguiente" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Multimedia: Pista anterior" })

-- Brillo (con su indicador en pantalla)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(qs .. "osd brillo subir"), { locked = true, repeating = true, description = "Multimedia: Subir brillo" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qs .. "osd brillo bajar"), { locked = true, repeating = true, description = "Multimedia: Bajar brillo" })

-- ---------- Capturas de pantalla ----------
-- Se guardan en ~/Imágenes/Capturas y se copian al portapapeles
hl.bind("Print",         hl.dsp.exec_cmd("~/.local/bin/captura area"),     { description = "Capturas: Capturar un área" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.local/bin/captura pantalla"), { description = "Capturas: Capturar la pantalla" })
hl.bind("ALT + Print",   hl.dsp.exec_cmd("~/.local/bin/captura ventana"),  { description = "Capturas: Capturar la ventana" })

-- ---------- Color ----------
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("~/.local/bin/color"), { description = "Herramientas: Tomar un color de la pantalla" })

-- ---------- Grabación de pantalla ----------
hl.bind(mainMod .. " + ALT + R",         hl.dsp.exec_cmd("~/.local/bin/grabar alternar pantalla"), { description = "Herramientas: Grabar la pantalla (iniciar / detener)" })
hl.bind(mainMod .. " + ALT + SHIFT + R", hl.dsp.exec_cmd("~/.local/bin/grabar alternar area"),     { description = "Herramientas: Grabar un área (iniciar / detener)" })

-- ---------- Luz nocturna ----------
hl.bind(mainMod .. " + ALT + N", hl.dsp.exec_cmd("qs -c escritorio ipc call luznocturna alternar"), { description = "Herramientas: Luz nocturna" })
