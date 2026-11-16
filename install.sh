#!/usr/bin/env bash
# ==========================================================
# Instalador de Amatista (Hyprland + Quickshell sobre Arch Linux)
#
#   ./install.sh          instalar
#   ./install.sh --demo   ver la interfaz con etapas simuladas (no instala nada)
#   ./install.sh --automatico   sin preguntas ni reinicio (pruebas en máquina virtual)
#
# Detecta el hardware solo (touchpad, batería, video, correcciones de audio),
# muestra las etapas en vivo y guarda todo en un registro. Al terminar, la
# carpeta del repo se puede borrar: todo queda copiado en el sistema.
# ==========================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO
DEMO=0; AUTO=0
case "${1:-}" in
  --demo)       DEMO=1 ;;
  --automatico) AUTO=1 ;;
esac

# Etapas: script y título que se muestra
ETAPAS_SCRIPT=(01-aur 02-paquetes 03-configuracion 04-servicios 05-inicio-sesion 06-tema-arranque)
ETAPAS_TITULO=(
  "Preparando el AUR (yay)"
  "Instalando paquetes"
  "Copiando la configuración"
  "Activando servicios"
  "Pantalla de inicio de sesión"
  "Tema de arranque (GRUB, Plymouth y consola)"
)
ETAPAS_ESTADO=()
for _ in "${ETAPAS_SCRIPT[@]}"; do ETAPAS_ESTADO+=(pendiente); done

REGISTROS="$HOME/.local/state/amatista"
REGISTRO="$REGISTROS/instalacion-$(date +%Y%m%d-%H%M%S).log"
REGISTRO_ETAPA="$REGISTRO"

# ---------- Comprobaciones antes de la interfaz ----------
salir() { printf '\n  %s\n\n' "$1" >&2; exit 1; }

[[ -f /etc/arch-release ]] || salir "Amatista solo se instala sobre Arch Linux."
[[ $EUID -ne 0 ]]          || salir "Ejecútalo como tu usuario, no como root (pedirá la contraseña)."

if ((DEMO)); then
  REGISTROS="${XDG_RUNTIME_DIR:-/tmp}/amatista-demo"
  REGISTRO="$REGISTROS/instalacion-demo.log"
fi
mkdir -p "$REGISTROS"
: > "$REGISTRO"

MANTENER_SUDO=""
if ((!DEMO)); then
  ping -c 1 -W 3 archlinux.org >/dev/null 2>&1 || salir "No hay conexión a internet."
  printf '\n  Amatista necesita permisos de administrador para instalar paquetes.\n\n'
  sudo -v || salir "Sin permisos de administrador no se puede instalar."
  # Mantener vivo sudo durante toda la instalación (las etapas no preguntan)
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
  MANTENER_SUDO=$!
fi

# gum: la herramienta de la interfaz (cajas, preguntas)
if ! command -v gum >/dev/null; then
  printf '  Preparando el instalador...\n'
  sudo pacman -S --needed --noconfirm gum >>"$REGISTRO" 2>&1 || salir "No se pudo instalar gum (ver $REGISTRO)."
fi

source "$REPO/lib/ui.sh"
source "$REPO/lib/hardware.sh"

terminar() {
  [[ -n $MANTENER_SUDO ]] && kill "$MANTENER_SUDO" 2>/dev/null
  printf '\033[?25h'   # mostrar el cursor
}
trap terminar EXIT
trap 'terminar; printf "\n\n  Instalación interrumpida. Registro: %s\n\n" "$REGISTRO"; exit 130' INT TERM

# ---------- Bienvenida ----------
clear
logo

gpus=$(hw_gpus | sed 's/intel/Intel/; s/amd/AMD/; s/nvidia/NVIDIA/; s/otra/otra/' | paste -sd ' ')
correcciones=""
for c in $(hw_correcciones); do
  correcciones+=$'\n'"  · $(cat "$REPO/sistema/hardware/$c/descripcion")"
done

caja "$(gum style --foreground "$ACENTO" --bold 'Equipo detectado')" "" \
  "Procesador   $(hw_cpu)" \
  "Video        ${gpus:-desconocido}" \
  "Touchpad     $(hw_tiene_touchpad && echo 'sí (gestos activados)' || echo 'no')" \
  "Batería      $(hw_tiene_bateria && echo 'sí (perfiles de energía)' || echo 'no')" \
  "Correcciones ${correcciones:- ninguna}"

echo
caja "$(gum style --foreground "$ACENTO" --bold 'Se instalará')" "" \
  "· Hyprland con la barra, menús, notificaciones y bloqueo de Quickshell" \
  "· Tema Amatista en GTK, Qt, terminal, cursor, iconos y apps" \
  "· Inicio de sesión gráfico, y GRUB, Plymouth y consola con el tema" \
  "" \
  "$(gum style --foreground "$TENUE" "Tu configuración actual se respalda (.respaldo-FECHA).")"
echo

if ((!AUTO)); then
  gum confirm --affirmative "Instalar" --negative "Cancelar" --default=true \
    "  ¿Instalar Amatista en este equipo?" || { echo; titulo "Instalación cancelada."; echo; exit 0; }
fi

# ---------- Etapas ----------
# Modo demostración: imprime líneas parecidas a las reales, sin tocar nada.
# La etapa 4 falla la primera vez, para ver las opciones de error.
etapa_simulada() {
  local n
  for n in $(seq 1 $((12 + RANDOM % 10))); do
    echo "(${n}/20) ${ETAPAS_TITULO[$1]}: procesando elemento $n ..."
    sleep 0.2
  done
  if [[ $1 == 3 && ! -e "$REGISTROS/demo-fallo" ]]; then
    touch "$REGISTROS/demo-fallo"
    echo "error: fallo simulado (elige Reintentar para continuar)"
    return 1
  fi
}

ejecutar_etapa() {
  local i=$1 pid inicio giro=0
  REGISTRO_ETAPA="$REGISTROS/etapa-${ETAPAS_SCRIPT[$i]}.log"
  : > "$REGISTRO_ETAPA"
  ETAPAS_ESTADO[$i]=activa
  inicio=$SECONDS

  if ((DEMO)); then
    etapa_simulada "$i" </dev/null >"$REGISTRO_ETAPA" 2>&1 &
  else
    bash "$REPO/etapas/${ETAPAS_SCRIPT[$i]}.sh" </dev/null >"$REGISTRO_ETAPA" 2>&1 &
  fi
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    dibujar "$i" "$inicio" "$giro"
    giro=$((giro + 1))
    sleep 0.15
  done
  wait "$pid"
  local codigo=$?

  { printf '\n===== %s (%s) — código %d =====\n' "${ETAPAS_TITULO[$i]}" "${ETAPAS_SCRIPT[$i]}" "$codigo"
    cat "$REGISTRO_ETAPA"; } >>"$REGISTRO"
  return "$codigo"
}

clear
printf '\033[?25l'   # ocultar el cursor mientras se dibuja
i=0
while ((i < ${#ETAPAS_SCRIPT[@]})); do
  if ejecutar_etapa "$i"; then
    ETAPAS_ESTADO[$i]=ok
    i=$((i + 1))
    continue
  fi

  # La etapa falló: mostrar el final del registro y preguntar qué hacer
  ETAPAS_ESTADO[$i]=fallo
  dibujar -1 0 0
  printf '\033[?25h'
  echo
  aviso_error "$(gum style --foreground "$ERROR" --bold "Falló: ${ETAPAS_TITULO[$i]}")" "" \
    "Registro completo: $REGISTRO_ETAPA"
  echo
  if ((AUTO)); then
    opcion="Salir"
  else
    opcion=$(gum choose --header "  ¿Qué hacer?" "Reintentar" "Omitir esta etapa" "Salir") || opcion="Salir"
  fi
  case "$opcion" in
    Reintentar)          ETAPAS_ESTADO[$i]=pendiente ;;
    "Omitir esta etapa") ETAPAS_ESTADO[$i]=omitida; i=$((i + 1)) ;;
    *)                   echo; titulo "Instalación detenida. Registro: $REGISTRO"; echo; exit 1 ;;
  esac
  printf '\033[?25l'
  clear
done

# ---------- Final ----------
dibujar -1 0 0
printf '\033[?25h'
echo

omitidas=0
for e in "${ETAPAS_ESTADO[@]}"; do [[ $e == omitida ]] && omitidas=$((omitidas + 1)); done

if ((omitidas)); then
  caja "$(gum style --foreground "$AMBAR" --bold "Instalación terminada con $omitidas etapa(s) omitida(s)")" "" \
    "Puedes repetirla más tarde ejecutando de nuevo ./install.sh" \
    "Registro: $REGISTRO"
else
  caja "$(gum style --foreground "$VERDE" --bold 'Amatista quedó instalado')" "" \
    "Al reiniciar entrarás a la pantalla de inicio de sesión." \
    "Super + A muestra todos los atajos de teclado." \
    "" \
    "$(gum style --foreground "$TENUE" "La carpeta del repo ya se puede borrar.")" \
    "$(gum style --foreground "$TENUE" "Registro: $REGISTRO")"
fi
echo

if ((!AUTO)) && gum confirm --affirmative "Reiniciar" --negative "Más tarde" "  ¿Reiniciar ahora?"; then
  if ((DEMO)); then rm -f "$REGISTROS/demo-fallo"; titulo "(demo: no se reinicia)"; echo
  else systemctl reboot; fi
fi
if ((DEMO)); then rm -f "$REGISTROS/demo-fallo"; fi
exit 0
