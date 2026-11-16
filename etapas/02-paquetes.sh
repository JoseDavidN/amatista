#!/usr/bin/env bash
set -euo pipefail
source "$REPO/lib/hardware.sh"

leer_lista() { grep -vE '^\s*(#|$)' "$1" || true; }

# Reintenta hasta 3 veces: un servidor lento o un corte de red a mitad de la
# descarga no debe detener la instalación (lo ya descargado queda en caché)
reintentar() {
  local intento
  for intento in 1 2 3; do
    "$@" && return 0
    echo "Falló el intento $intento de 3; reintentando en 10 s..."
    sleep 10
  done
  return 1
}

mapfile -t OFICIALES < <(leer_lista "$REPO/packages/oficiales.txt")
mapfile -t AUR < <(leer_lista "$REPO/packages/aur.txt")
# Paquetes según el hardware detectado (drivers de video, energía, correcciones)
mapfile -t -O "${#OFICIALES[@]}" OFICIALES < <(hw_paquetes)

echo "Paquetes oficiales: ${#OFICIALES[@]} · AUR: ${#AUR[@]}"
reintentar sudo pacman -Syu --needed --noconfirm "${OFICIALES[@]}"

if ((${#AUR[@]})); then
  reintentar yay -S --needed --noconfirm --answerdiff None --answerclean None "${AUR[@]}"
fi
