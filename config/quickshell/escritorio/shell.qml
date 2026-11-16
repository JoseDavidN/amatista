// ==========================================================
// Quickshell - escritorio principal
// Ubicacion: ~/.config/quickshell/escritorio/shell.qml
// Lanzar con: qs -c escritorio   (reiniciar: qsreiniciar)
//
//   Notificaciones      reemplaza a mako
//   Barra + paneles     reemplaza a Waybar, networkmanager-dmenu y blueman
//   Lanzador y apagado  reemplaza a rofi
//   Bloqueo             reemplaza a hyprlock
//   Inactividad         reemplaza a hypridle
//   OSD y portapapeles
//   Ayuda de atajos     Super + F1
// ==========================================================
import Quickshell
import qs.notificaciones
import qs.barra
import qs.menus
import qs.bloqueo
import qs.sistema
import qs.osd
import qs.portapapeles
import qs.fondos
import qs.ayuda

ShellRoot {
    Bloqueo { id: bloqueo }
    Inactividad { bloqueo: bloqueo }
    Notificaciones {}
    Barra {}
    Lanzador {}
    MenuApagado {}
    Osd {}
    Portapapeles {}
    SelectorFondos {}
    Ayuda {}
}
