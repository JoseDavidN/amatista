#!/usr/bin/env bash
set -euo pipefail

sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now upower.service

# Perfiles de energía (solo se instala en equipos con batería)
if systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1; then
  sudo systemctl enable --now power-profiles-daemon.service
fi

# Correcciones de hardware detectadas: archivos de sistema (firmware, módulos...)
source "$REPO/lib/hardware.sh"
for c in $(hw_correcciones); do
  if [[ -d "$REPO/sistema/hardware/$c/sistema" ]]; then
    sudo cp -r --no-preserve=ownership "$REPO/sistema/hardware/$c/sistema/." /
    echo "corrección de hardware: $c"
  fi
done

# Servicios de usuario
systemctl --user daemon-reload
systemctl --user enable audio-automatico.service

# Llavero de contraseñas y agente SSH que lo usa
systemctl --user enable gnome-keyring-daemon.socket gcr-ssh-agent.socket
# git guarda usuario y token en el llavero
git config --global credential.helper /usr/lib/git-core/git-credential-libsecret

# Sin el indexador de archivos de GNOME (lo trae Nautilus): consume CPU y disco
# en segundo plano. La búsqueda de Nautilus sigue funcionando sin él.
systemctl --user mask localsearch-3.service localsearch-control-3.service localsearch-writeback-3.service
