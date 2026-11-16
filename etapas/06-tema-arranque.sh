#!/usr/bin/env bash
set -euo pipefail

# Tema Amatista fuera del escritorio: GRUB, Plymouth y las consolas de texto.
# Todo se copia al sistema (no depende del repo).

# ---------- GRUB ----------
# Para regenerar fondo, piezas y fuentes: herramientas/construir-grub.py
# Solo si el equipo arranca con GRUB
if [[ -f /etc/default/grub ]]; then
  sudo rm -rf /usr/share/grub/themes/amatista
  sudo install -d /usr/share/grub/themes/amatista
  sudo cp -r "$REPO/sistema/grub/amatista/." /usr/share/grub/themes/amatista/
  sudo sed -i -E '/^#?GRUB_THEME=/d' /etc/default/grub
  echo 'GRUB_THEME="/usr/share/grub/themes/amatista/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
  sudo sed -i -E '/^#?GRUB_GFXMODE=/d' /etc/default/grub
  echo 'GRUB_GFXMODE=1920x1080,auto' | sudo tee -a /etc/default/grub >/dev/null
  grep -q '^GRUB_GFXPAYLOAD_LINUX=' /etc/default/grub \
    || echo 'GRUB_GFXPAYLOAD_LINUX=keep' | sudo tee -a /etc/default/grub >/dev/null
  # Plymouth solo se muestra con "quiet splash" en la línea del kernel
  for opcion in quiet splash; do
    if ! grep -qE "^GRUB_CMDLINE_LINUX_DEFAULT=\"([^\"]* )?$opcion( [^\"]*)?\"" /etc/default/grub; then
      sudo sed -i -E "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"([^\"]*)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 $opcion\"/" /etc/default/grub
    fi
  done
  sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# ---------- Plymouth ----------
# Para regenerar las imágenes: herramientas/construir-plymouth.sh
sudo rm -rf /usr/share/plymouth/themes/amatista
sudo install -d -m 755 /usr/share/plymouth/themes/amatista
sudo install -m 644 "$REPO"/sistema/plymouth/amatista/* /usr/share/plymouth/themes/amatista/
if ! grep -qE '^HOOKS=\(.*\bplymouth\b' /etc/mkinitcpio.conf; then
  sudo sed -i -E '/^HOOKS=/ s/\b(systemd|udev)\b/& plymouth/' /etc/mkinitcpio.conf
fi
sudo plymouth-set-default-theme amatista
sudo mkinitcpio -P

# ---------- Consolas de texto (Ctrl+Alt+F2 ... F6) ----------
sudo install -Dm644 "$REPO/sistema/consola/vtrgb" /etc/amatista/vtrgb
sudo install -Dm644 "$REPO/sistema/consola/consola-amatista.service" /etc/systemd/system/consola-amatista.service
sudo systemctl daemon-reload
sudo systemctl enable --now consola-amatista.service
