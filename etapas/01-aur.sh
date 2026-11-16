#!/usr/bin/env bash
set -euo pipefail

# Herramientas para compilar y yay (paquetes del AUR)
sudo pacman -S --needed --noconfirm base-devel git

if ! command -v yay >/dev/null; then
  TMP="$(mktemp -d)"
  git clone -q --depth 1 https://aur.archlinux.org/yay-bin.git "$TMP/yay-bin"
  (cd "$TMP/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$TMP"
fi
yay --version | head -n 1
