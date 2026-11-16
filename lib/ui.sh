#!/usr/bin/env bash
# Interfaz del instalador (estilo Omarchy): logo, cajas y preguntas con gum,
# y una vista en vivo de las etapas con las últimas líneas del registro.

# ---------- Paleta Amatista ----------
ACENTO="#b98cff"; MORADO="#d0a8ff"; ROSA="#ff9ad5"; TEXTO="#f3eaff"
SUAVE="#d4c2f0"; TENUE="#a08cc0"; BORDE="#52406f"; VERDE="#9ee6b0"
ERROR="#ff7a9a"; AMBAR="#ffcf85"

# Colores para gum (preguntas y botones)
export GUM_CONFIRM_PROMPT_FOREGROUND="$TEXTO"
export GUM_CONFIRM_SELECTED_BACKGROUND="$ACENTO"
export GUM_CONFIRM_SELECTED_FOREGROUND="#1e1530"
export GUM_CONFIRM_UNSELECTED_BACKGROUND="#40305c"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="$SUAVE"
export GUM_CHOOSE_CURSOR_FOREGROUND="$ACENTO"
export GUM_CHOOSE_SELECTED_FOREGROUND="$ACENTO"
export GUM_CHOOSE_HEADER_FOREGROUND="$SUAVE"

# En la consola de texto (TTY) no hay truecolor ni la mayoría de símbolos:
# se usan equivalentes simples
if [[ ${TERM:-} == linux ]]; then
  SIMPLE=1
  GIRO=('|' '/' '-' '\')
  OK="+"; FALLO="x"; PENDIENTE="."; OMITIDA="-"
else
  SIMPLE=0
  GIRO=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  OK="✓"; FALLO="✗"; PENDIENTE="·"; OMITIDA="⤼"
fi

# Color de texto: truecolor o el ANSI más parecido en la TTY
color() {
  if ((SIMPLE)); then
    case "$1" in
      "$VERDE") printf '\033[32m' ;; "$ERROR") printf '\033[31m' ;;
      "$AMBAR") printf '\033[33m' ;; "$TENUE"|"$BORDE") printf '\033[90m' ;;
      "$TEXTO"|"$SUAVE") printf '\033[97m' ;; *) printf '\033[35m' ;;
    esac
  else
    local h=${1#\#}
    printf '\033[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
  fi
}
NORMAL=$'\033[0m'; NEGRITA=$'\033[1m'

# ---------- Logo ----------
# Gema en pixel art (lib/logo.ansi, generada con
# herramientas/construir-logo-instalador.py) con el nombre a la derecha
logo() {
  local a t n=0 fila texto
  a=$(color "$ACENTO"); t=$(color "$TENUE")
  echo
  while IFS= read -r fila; do
    case $n in
      3) texto="     ${NEGRITA}${a}A M A T I S T A${NORMAL}" ;;
      5) texto="     ${t}Hyprland · Quickshell · Arch Linux${NORMAL}" ;;
      *) texto="" ;;
    esac
    printf '\033[2K      %s%s\n' "$fila" "$texto"
    n=$((n + 1))
  done < "$REPO/lib/logo.ansi"
  echo
}

# Caja con borde redondeado (gum style)
caja() {
  gum style --border rounded --border-foreground "$BORDE" --foreground "$TEXTO" \
    --padding "1 3" --margin "0 4" "$@"
}

titulo() { gum style --foreground "$ACENTO" --bold --margin "0 4" "$@"; }

aviso_error() {
  gum style --border rounded --border-foreground "$ERROR" --foreground "$TEXTO" \
    --padding "1 3" --margin "0 4" "$@"
}

# ---------- Vista en vivo de las etapas ----------
# ETAPAS_TITULO[i], ETAPAS_ESTADO[i] (pendiente|activa|ok|fallo|omitida)

dibujar() {
  local activa=$1 inicio=$2 giro=$3 cols lineas ancho i simbolo col reloj
  cols=$(tput cols 2>/dev/null || echo 80)
  lineas=$(tput lines 2>/dev/null || echo 24)
  ancho=$((cols - 12)); ((ancho > 100)) && ancho=100; ((ancho < 30)) && ancho=30

  printf '\033[H'
  logo
  for i in "${!ETAPAS_TITULO[@]}"; do
    case "${ETAPAS_ESTADO[$i]}" in
      ok)       simbolo=$OK;        col=$(color "$VERDE") ;;
      fallo)    simbolo=$FALLO;     col=$(color "$ERROR") ;;
      omitida)  simbolo=$OMITIDA;   col=$(color "$AMBAR") ;;
      activa)   simbolo=${GIRO[giro % ${#GIRO[@]}]}; col=$(color "$ACENTO") ;;
      *)        simbolo=$PENDIENTE; col=$(color "$TENUE") ;;
    esac
    reloj=""
    if [[ $i == "$activa" ]]; then
      local s=$((SECONDS - inicio))
      reloj=$(printf '  %s%02d:%02d%s' "$(color "$TENUE")" $((s / 60)) $((s % 60)) "$NORMAL")
    fi
    printf '\033[2K    %s%s%s  %s%s%s%s\n' "$col" "$simbolo" "$NORMAL" \
      "$( [[ ${ETAPAS_ESTADO[$i]} == pendiente ]] && color "$TENUE" || color "$TEXTO")" \
      "${ETAPAS_TITULO[$i]}" "$NORMAL" "$reloj"
  done

  # Últimas líneas del registro, recortadas al ancho de la caja
  local alto=$((lineas - 15 - ${#ETAPAS_TITULO[@]} - 4))
  ((alto > 12)) && alto=12; ((alto < 3)) && alto=3
  printf '\033[2K\n\033[2K    %s╭─ registro %s╮%s\n' "$(color "$BORDE")" \
    "$(printf '─%.0s' $(seq 1 $((ancho - 11))))" "$NORMAL"
  local linea n=0
  while IFS= read -r linea; do
    # Sin colores ni retornos de carro, recortada y rellenada por caracteres
    # (no por bytes: los acentos ocupan dos bytes)
    linea=$(printf '%s' "${linea//$'\r'/}" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' |
      awk -v w=$((ancho - 1)) '{ s = substr($0, 1, w); printf "%s%*s", s, w - length(s), "" }')
    printf '\033[2K    %s│%s %s%s%s%s│%s\n' "$(color "$BORDE")" "$NORMAL" \
      "$(color "$TENUE")" "$linea" "$NORMAL" "$(color "$BORDE")" "$NORMAL"
    n=$((n + 1))
  done < <(tail -n "$alto" "$REGISTRO_ETAPA" 2>/dev/null)
  while ((n < alto)); do
    printf '\033[2K    %s│%*s│%s\n' "$(color "$BORDE")" "$ancho" "" "$NORMAL"
    n=$((n + 1))
  done
  printf '\033[2K    %s╰%s╯%s\n' "$(color "$BORDE")" "$(printf '─%.0s' $(seq 1 "$ancho"))" "$NORMAL"
  printf '\033[J'
}
