// ==========================================================
// Respaldos: solo se ve si hay un problema (rojo) o uno en marcha (cian)
// Clic: estado, historial y botón para respaldar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Comun

Pildora {
    id: mod

    readonly property var s: ServicioRespaldos

    // Mostrarla un momento antes de abrir el panel, para que tenga su sitio
    property bool pedida: false
    Timer {
        id: apertura
        interval: 200
        onTriggered: {
            panel.alternar();
            mod.pedida = false;
        }
    }

    visible: s.hay && (s.mal || s.corriendo || pedida || panel.abierto)
    icono: String.fromCodePoint(s.mal ? 0xf163b : 0xf006f)
    colorIcono: s.mal ? Tema.error : Tema.cian
    colorFondo: s.mal ? Tema.pildoraPeligro : Tema.pildora
    tooltip: s.mal ? s.problemas.join("\n") : s.corriendo ? "Respaldo en marcha" : ""

    PanelRespaldos {
        id: panel
        objetivo: mod
    }

    // Abrir por IPC: solo en el monitor enfocado
    Connections {
        target: ServicioRespaldos
        function onPedirPanel() {
            const v = mod.QsWindow.window, m = Hyprland.focusedMonitor;
            if (panel.abierto) {
                panel.cerrar();
            } else if (ServicioRespaldos.hay && v && v.screen && m && v.screen.name === m.name) {
                mod.pedida = true;
                apertura.restart();
            }
        }
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
}
