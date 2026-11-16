#!/usr/bin/env bash
set -euo pipefail

# Copia la configuración (sin enlaces): al terminar la instalación
# la carpeta del repo se puede borrar sin romper nada.

DESTINO="$HOME/.config"
FECHA="$(date +%Y%m%d-%H%M%S)"

copiar() {
  local origen="$1" destino="$2"
  if [[ -e "$destino" || -L "$destino" ]]; then
    mv "$destino" "$destino.respaldo-$FECHA"
    echo "respaldo: $destino.respaldo-$FECHA"
  fi
  mkdir -p "$(dirname "$destino")"
  cp -a "$origen" "$destino"
  echo "copiado: $destino"
}

for carpeta in hypr kitty nvim quickshell gtk-3.0 gtk-4.0 qt6ct xdg-desktop-portal imv mpv zathura satty fastfetch; do
  copiar "$REPO/config/$carpeta" "$DESTINO/$carpeta"
done

# qt6ct necesita la ruta completa de la paleta
sed -i "s|@HOME@|$HOME|" "$DESTINO/qt6ct/qt6ct.conf"

# Correcciones de hardware detectadas (por ejemplo, el perfil de audio)
source "$REPO/lib/hardware.sh"
for c in $(hw_correcciones); do
  if [[ -d "$REPO/sistema/hardware/$c/config" ]]; then
    cp -a "$REPO/sistema/hardware/$c/config/." "$DESTINO/"
    echo "corrección de hardware: $c"
  fi
done

copiar "$REPO/config/zshrc" "$HOME/.zshrc"

# Nautilus: "Abrir terminal aquí" con kitty (clic derecho > Scripts),
# y Nautilus como programa predeterminado para abrir carpetas
for script in "$REPO"/config/nautilus-scripts/*; do
  install -Dm755 "$script" "$HOME/.local/share/nautilus/scripts/$(basename "$script")"
done
xdg-mime default org.gnome.Nautilus.desktop inode/directory

# Apps predeterminadas: cada una se asigna a los tipos de archivo que
# declara en su .desktop (xdg-mime acepta un solo tipo por llamada). Si dos
# apps declaran el mismo tipo, gana la última: zathura también abre imágenes,
# por eso va antes que imv.
predeterminada() {
  local archivo tipo
  archivo="$HOME/.local/share/applications/$1"
  [[ -f "$archivo" ]] || archivo="/usr/share/applications/$1"
  [[ -f "$archivo" ]] || { echo "falta $1"; return 0; }
  for tipo in $(sed -n 's/^MimeType=//p' "$archivo" | tr ';' ' '); do
    xdg-mime default "$1" "$tipo"
  done
}
# Neovim se abre dentro de kitty (el .desktop original pide "una terminal")
mkdir -p "$HOME/.local/share/applications"
sed -e 's/^Exec=nvim/Exec=kitty -e nvim/' -e 's/^Terminal=true/Terminal=false/' \
  /usr/share/applications/nvim.desktop > "$HOME/.local/share/applications/nvim.desktop"

predeterminada org.pwmt.zathura-pdf-mupdf.desktop  # PDF
predeterminada imv-dir.desktop                     # imágenes (con las demás de la carpeta)
predeterminada mpv.desktop                         # video y audio
predeterminada nvim.desktop                        # texto y scripts

# Servicios de usuario (cambio automático de audio)
for servicio in "$REPO"/config/systemd/user/*.service; do
  install -Dm644 "$servicio" "$DESTINO/systemd/user/$(basename "$servicio")"
done

# Apps ocultas en el lanzador (herramientas que traen otros paquetes,
# como las pruebas de cámara de v4l-utils)
for app in "$REPO"/config/applications/*.desktop; do
  install -Dm644 "$app" "$HOME/.local/share/applications/$(basename "$app")"
done

# Scripts propios (bloquear, ...) en ~/.local/bin
for script in "$REPO"/config/bin/*; do
  install -Dm755 "$script" "$HOME/.local/bin/$(basename "$script")"
done

# Tema GTK: sin esto gtk.css (paleta Amatista) no se aplica, porque sus
# colores solo los usan adw-gtk3-dark (GTK3) y libadwaita en modo oscuro (GTK4)
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Iconos: Colloid violeta oscuro (carpetas redondeadas, combinan con Amatista).
# Solo la variante violeta, para el usuario: el paquete del AUR compila e
# instala todas las variantes (Dracula, Gruvbox, Nord, ...) y todos los colores.
COLLOID="$(mktemp -d)"
git clone -q --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git "$COLLOID"
"$COLLOID/install.sh" -s default -t purple -d "$HOME/.local/share/icons"
rm -rf "$COLLOID"
# El script instala tres variantes (normal, clara y oscura) y la oscura enlaza
# archivos de la clara: se copian esos archivos y se borran las que sobran
ICONOS="$HOME/.local/share/icons"
OSCURO="$ICONOS/Colloid-Purple-Dark"
while IFS= read -r enlace; do
  destino="$(readlink -f "$enlace")" || continue
  case "$destino" in "$OSCURO"/*) continue ;; esac
  [[ -e "$destino" ]] || continue          # enlaces rotos que trae el tema
  rm "$enlace"
  cp -rL "$destino" "$enlace" 2>/dev/null || true   # dentro puede haber enlaces rotos
done < <(find "$OSCURO" -type l)
rm -rf "$ICONOS/Colloid-Purple" "$ICONOS/Colloid-Purple-Light"
gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Purple-Dark'

# Cursor Amatista: Bibata Modern recoloreado (lila con borde oscuro), con
# todas sus formas (texto, mano, espera, ...). Ya viene construido en
# assets/cursor; para regenerarlo: herramientas/construir-cursor.py.
# En /usr/share/icons para que también lo use la pantalla de inicio de sesión.
sudo rm -rf /usr/share/icons/Amatista
sudo cp -r "$REPO/assets/cursor/Amatista" /usr/share/icons/Amatista
sudo chmod -R a+rX /usr/share/icons/Amatista
gsettings set org.gnome.desktop.interface cursor-theme 'Amatista'
gsettings set org.gnome.desktop.interface cursor-size 24
# Apps que no leen XCURSOR_THEME ni gsettings (X11/XWayland)
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nInherits=Amatista\n' > "$HOME/.icons/default/index.theme"

# Fondos de pantalla (los lee el selector, Super + W). Primero se crean las
# carpetas de usuario con su nombre en el idioma del sistema (Imágenes,
# Vídeos, Descargas...), para no duplicarlas con nombres mal escritos.
xdg-user-dirs-update
FONDOS="$(xdg-user-dir PICTURES)/wallpaper"
install -Dm644 "$REPO/assets/amatista.png" "$FONDOS/amatista.png"
# Fondos incluidos en Hyprland y en Arch (archlinux-wallpaper): se copian,
# no se mueven, porque pertenecen a sus paquetes
for f in /usr/share/hypr/wall*.png; do
  if [ -e "$f" ]; then
    cp -n "$f" "$FONDOS/hyprland-$(basename "$f" .png | sed 's/^wall//').png"
  fi
done
find /usr/share/backgrounds/archlinux -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' \) \
  -exec cp -n -t "$FONDOS" {} + 2>/dev/null || true
sed -i "s|~/Imágenes/wallpaper|$FONDOS|" "$DESTINO/hypr/hyprpaper.conf"
