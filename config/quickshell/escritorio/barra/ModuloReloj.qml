// ==========================================================
// Reloj:  14:28   mié 11 nov   (igual que tu Waybar)
// Clic: panel del clima
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Comun
import qs.clima

Pildora {
    id: mod

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    icono: ""
    colorIcono: Tema.rosa
    texto: Qt.formatDateTime(reloj.date, "HH:mm")

    icono2: compacta ? "" : ""
    colorIcono2: Tema.acento
    // "%a %d %b" -> "mié 11 nov" (sin los puntos que agrega Qt en español)
    // En pantallas angostas solo la hora (la fecha queda en el tooltip)
    property bool compacta: false
    tooltip: compacta ? reloj.date.toLocaleString(Qt.locale("es_CO"), "dddd d 'de' MMMM") : ""
    texto2: compacta ? "" : reloj.date.toLocaleString(Qt.locale("es_CO"), "ddd dd MMM").replace(/\./g, "")

    relleno: 14

    PanelClima {
        id: panel
        objetivo: mod
    }

    // Abrir por IPC: solo en el monitor enfocado
    Connections {
        target: ServicioClima
        function onPedirPanel() {
            const v = mod.QsWindow.window, m = Hyprland.focusedMonitor;
            if (panel.abierto || (v && v.screen && m && v.screen.name === m.name)) panel.alternar();
        }
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
}
