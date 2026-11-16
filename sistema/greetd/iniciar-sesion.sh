#!/bin/sh
# Abre la sesión de Hyprland del usuario (lo lanza el greeter al iniciar sesión).
# La sesión corre en la consola tty1: se limpia la pantalla, se oculta el cursor
# y la salida de Hyprland no se escribe ahí, para que entre el login y el
# escritorio no se vea la terminal. Hyprland guarda su propio registro en
# $XDG_RUNTIME_DIR/hypr/*/hyprland.log
printf '\033[2J\033[H\033[?25l'
exec start-hyprland >/dev/null 2>&1
