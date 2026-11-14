#!/usr/bin/env bash
set -euo pipefail

[[ -f /etc/arch-release ]] || { echo "Esto solo corre en Arch Linux"; exit 1; }
[[ $EUID -ne 0 ]] || { echo "No lo ejecutes como root"; exit 1; }
ping -c 1 -W 3 archlinux.org >/dev/null || { echo "Sin internet"; exit 1; }
command -v yay >/dev/null || { echo "Falta yay"; exit 1; }
sudo -v
