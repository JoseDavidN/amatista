#!/usr/bin/env bash
# Regenera los PNG del tema Plymouth "Amatista" a partir de los SVG fuente.
# Uso: herramientas/construir-plymouth.sh
# Requiere: rsvg-convert (paquete librsvg).
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
fuente="$raiz/herramientas/plymouth-svg"
destino="$raiz/sistema/plymouth/amatista"
mkdir -p "$destino"

# nombre  ancho(px)   — los PNG van al doble del tamaño de pantalla a 1080p;
# el script los escala según la resolución real.
while read -r nombre ancho; do
    rsvg-convert -w "$ancho" "$fuente/$nombre.svg" -o "$destino/$nombre.png"
    echo "  $nombre.png (${ancho}px)"
done <<'LISTA'
logo    560
punto   48
vineta  40
caja    880
campo   720
candado 64
LISTA

echo "PNG generados en $destino"
