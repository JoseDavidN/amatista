#!/usr/bin/env bash
set -euo pipefail

DESTINO="$HOME/.config"
FECHA="$(date +%Y%m%d-%H%M%S)"

enlazar() {
  local origen="$1" destino="$2"
  if [[ -L "$destino" && "$(readlink -f "$destino")" == "$(readlink -f "$origen")" ]]; then
    echo "ya enlazado: $destino"
    return
  fi
  if [[ -e "$destino" || -L "$destino" ]]; then
    mv "$destino" "$destino.respaldo-$FECHA"
    echo "respaldo: $destino.respaldo-$FECHA"
  fi
  mkdir -p "$(dirname "$destino")"
  ln -s "$origen" "$destino"
  echo "enlazado: $destino"
}

# hardware.lua propio de la máquina elegida (enlace relativo dentro del repo)
ln -sfn "../../../maquinas/$MAQUINA/hardware.lua" "$REPO/config/hypr/config/hardware.lua"

for carpeta in hypr kitty nvim quickshell gtk-3.0 gtk-4.0; do
  enlazar "$REPO/config/$carpeta" "$DESTINO/$carpeta"
done

enlazar "$REPO/config/zshrc" "$HOME/.zshrc"

install -Dm644 "$REPO/assets/amatista.png" "$HOME/.local/share/fondos/amatista.png"
