local programs = require("config.programs")

local mainMod = "SUPER" -- tecla windows como modificador principal

-- Programas
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("qs -c escritorio ipc call lanzador alternar"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(programs.browser))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.local/bin/bloquear"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -c escritorio ipc call fondos alternar"))

-- Ventanas
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- solo con dwindle
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs -c escritorio ipc call portapapeles alternar"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("qs -c escritorio ipc call inactividad alternar"))

-- Teclas de volumen (el OSD aparece solo)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- Teclas de brillo
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs -c escritorio ipc call osd brillo subir"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs -c escritorio ipc call osd brillo bajar"), { locked = true, repeating = true })

-- Salir de Hyprland
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- Mover el foco con las flechas
hl.bind(mainMod .. " + left",   hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",  hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",     hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",   hl.dsp.focus({ direction = "down" }))

-- Espacios de trabajo 1-10: ir a uno, o mover la ventana a uno
for i = 1, 10 do
    local key = i % 10 -- el 10 corresponde a la tecla 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Espacio especial ("scratchpad")
hl.bind(mainMod .. " + S",          hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S",  hl.dsp.window.move({ workspace = "special:magic" }))

-- Cambiar de espacio con la rueda del mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mover y redimensionar ventanas con el mouse (clic izquierdo / derecho)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),    { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(),  { mouse = true })

-- Teclas multimedia: volumen, microfono, brillo y reproductor
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
