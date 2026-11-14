#!/usr/bin/env bash
set -euo pipefail

leer_lista() { grep -vE '^\s*(#|$)' "$1" || true; }

mapfile -t OFICIALES < <(leer_lista "$REPO/packages/oficiales.txt")
mapfile -t AUR < <(leer_lista "$REPO/packages/aur.txt")

sudo pacman -Syu --needed "${OFICIALES[@]}"

if ((${#AUR[@]})); then
  yay -S --needed "${AUR[@]}"
fi
