#!/bin/sh
# Arranca el Hyprland del greeter (lo ejecuta greetd como el usuario "greeter").
# La carpeta personal de "greeter" es "/" y no se puede escribir en ella,
# así que la caché y el estado van a su carpeta temporal de sesión.
BASE="${XDG_RUNTIME_DIR:-/tmp/greeter-$(id -u)}"
export XDG_CACHE_HOME="$BASE/cache"
export XDG_STATE_HOME="$BASE/state"
export XDG_DATA_HOME="$BASE/data"
export XDG_CONFIG_HOME="$BASE/config"
mkdir -p "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

# Sin texto en la consola mientras arranca (pantalla limpia y sin cursor)
printf '\033[2J\033[H\033[?25l'
exec start-hyprland -- -c /etc/greetd/hyprland.lua >/dev/null 2>&1
