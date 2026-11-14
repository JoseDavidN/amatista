// ==========================================================
// Inactividad (reemplaza a hypridle)
//   5 min:  baja el brillo al 10 %
//  10 min:  bloquea la sesion
//  15 min:  apaga la pantalla
// Al mover el raton o tocar una tecla todo vuelve a la normalidad.
// No actua mientras una app lo impida (videos, llamadas...).
//
// Modo cafe (desactivar temporalmente):
//   qs -c escritorio ipc call inactividad alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: inactividad

    required property var bloqueo

    readonly property int minutosAtenuar: 5
    readonly property int minutosBloquear: 10
    readonly property int minutosApagar: 15

    property bool activa: true
    property bool atenuado: false
    property bool pantallaApagada: false

    IdleMonitor {
        enabled: inactividad.activa
        timeout: inactividad.minutosAtenuar * 60
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                inactividad.atenuado = true;
                Quickshell.execDetached(["sh", "-c", "brightnessctl -s set 10% >/dev/null 2>&1"]);
            } else if (inactividad.atenuado) {
                inactividad.atenuado = false;
                Quickshell.execDetached(["sh", "-c", "brightnessctl -r >/dev/null 2>&1"]);
            }
        }
    }

    IdleMonitor {
        enabled: inactividad.activa
        timeout: inactividad.minutosBloquear * 60
        respectInhibitors: true

        onIsIdleChanged: if (isIdle) inactividad.bloqueo.bloquear()
    }

    IdleMonitor {
        enabled: inactividad.activa
        timeout: inactividad.minutosApagar * 60
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                inactividad.pantallaApagada = true;
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"disable\" })"]);
            } else if (inactividad.pantallaApagada) {
                inactividad.pantallaApagada = false;
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"enable\" })"]);
            }
        }
    }

    IpcHandler {
        target: "inactividad"
        function alternar(): string {
            inactividad.activa = !inactividad.activa;
            Quickshell.execDetached(["notify-send", "-a", "Sistema", "-u", "low", "Inactividad",
                inactividad.activa ? "Bloqueo automático activado" : "Modo café: no se bloqueará ni apagará la pantalla"]);
            return inactividad.activa ? "activa" : "pausada";
        }
        function estado(): string { return inactividad.activa ? "activa" : "pausada"; }
    }
}
