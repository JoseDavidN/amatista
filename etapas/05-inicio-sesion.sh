#!/usr/bin/env bash
set -euo pipefail

# Gestor de inicio de sesión: greetd + greeter en Quickshell.
# Al encender, el equipo entra directo a la pantalla de inicio de sesión.
# Todo se copia a /etc/greetd (no depende del repo).

ORIGEN="$REPO/sistema/greetd"
DESTINO="/etc/greetd"

sudo install -Dm644 "$ORIGEN/config.toml"          "$DESTINO/config.toml"
sudo install -Dm644 "$ORIGEN/hyprland.lua"         "$DESTINO/hyprland.lua"
sudo install -Dm755 "$ORIGEN/iniciar-greeter.sh"   "$DESTINO/iniciar-greeter.sh"
sudo install -Dm755 "$ORIGEN/sesion-greeter.sh"    "$DESTINO/sesion-greeter.sh"
sudo install -Dm755 "$ORIGEN/iniciar-sesion.sh"    "$DESTINO/iniciar-sesion.sh"
sudo install -Dm644 "$ORIGEN/greeter/shell.qml"      "$DESTINO/greeter/shell.qml"
sudo install -Dm644 "$ORIGEN/greeter/Superficie.qml" "$DESTINO/greeter/Superficie.qml"

# Misma paleta que el escritorio y el fondo del tema
# (el usuario greeter no puede leer tu carpeta personal)
sudo install -Dm644 "$REPO/config/quickshell/escritorio/Comun/Tema.qml" "$DESTINO/greeter/Comun/Tema.qml"
sudo install -Dm644 "$REPO/config/quickshell/escritorio/Comun/qmldir"   "$DESTINO/greeter/Comun/qmldir"
sudo install -Dm644 "$REPO/assets/amatista.png"                         "$DESTINO/greeter/fondo.png"

# PAM: el llavero (gnome-keyring) se desbloquea con la contraseña del inicio
# de sesión. greetd-greeter es el PAM del usuario "greeter" (sin llavero), y
# passwd mantiene igual la contraseña del llavero al cambiar la del usuario.
sudo install -Dm644 "$REPO/sistema/pam/greetd"         /etc/pam.d/greetd
sudo install -Dm644 "$REPO/sistema/pam/greetd-greeter" /etc/pam.d/greetd-greeter
sudo install -Dm644 "$REPO/sistema/pam/passwd"         /etc/pam.d/passwd

# Quitar el inicio automático en tty1 si existiera, y activar greetd
sudo rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
sudo systemctl enable greetd.service
