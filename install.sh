#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO

echo "Máquinas disponibles:"
ls "$REPO/maquinas"
read -rp "¿Cuál es esta máquina? " MAQUINA
[[ -d "$REPO/maquinas/$MAQUINA" ]] || { echo "No existe maquinas/$MAQUINA"; exit 1; }
export MAQUINA

for etapa in "$REPO"/etapas/*.sh; do
  echo "==> $(basename "$etapa")"
  bash "$etapa"
done
