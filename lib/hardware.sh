#!/usr/bin/env bash
# Detección de hardware (la usan install.sh y las etapas). No necesita root
# ni paquetes extra: lee /proc y /sys.

# Nombre del procesador
hw_cpu() {
  sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n 1 | sed 's/(R)//g; s/(TM)//g; s/  */ /g'
}

# Fabricantes de las tarjetas de video (intel, amd, nvidia), una por línea
hw_gpus() {
  local d clase vendor
  for d in /sys/bus/pci/devices/*; do
    clase=$(cat "$d/class" 2>/dev/null) || continue
    [[ $clase == 0x03* ]] || continue
    vendor=$(cat "$d/vendor" 2>/dev/null)
    case "$vendor" in
      0x8086) echo intel ;;
      0x1002) echo amd ;;
      0x10de) echo nvidia ;;
      *)      echo otra ;;
    esac
  done | sort -u
}

hw_tiene_gpu() { hw_gpus | grep -qx "$1"; }

hw_tiene_touchpad() { grep -qi 'touchpad' /proc/bus/input/devices 2>/dev/null; }

hw_tiene_bateria() { compgen -G '/sys/class/power_supply/BAT*' >/dev/null; }

# Correcciones de sistema/hardware/* que este equipo necesita (nombre de carpeta)
hw_correcciones() {
  local c
  for c in "$REPO"/sistema/hardware/*/; do
    [[ -x "$c/detectar" ]] && "$c/detectar" && basename "$c"
  done
  return 0
}

# Paquetes extra según el hardware detectado
hw_paquetes() {
  # Video por hardware (VA-API) en Intel: el sistema usa el driver que
  # corresponda a la generación (iHD desde Broadwell, i965 en las anteriores)
  if hw_tiene_gpu intel; then
    echo intel-media-driver
    echo libva-intel-driver
  fi
  # Perfiles de energía (ahorro / equilibrado / rendimiento) en portátiles
  hw_tiene_bateria && echo power-profiles-daemon
  local c
  for c in $(hw_correcciones); do
    [[ -f "$REPO/sistema/hardware/$c/paquetes.txt" ]] &&
      grep -vE '^\s*(#|$)' "$REPO/sistema/hardware/$c/paquetes.txt"
  done
  return 0
}
