// ==========================================================
// Reloj:  14:28   mié 11 nov   (igual que tu Waybar)
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun

Pildora {
    id: mod

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    icono: ""
    colorIcono: Tema.rosa
    texto: Qt.formatDateTime(reloj.date, "HH:mm")

    icono2: ""
    colorIcono2: Tema.acento
    // "%a %d %b" -> "mié 11 nov" (sin los puntos que agrega Qt en español)
    texto2: reloj.date.toLocaleString(Qt.locale("es_CO"), "ddd dd MMM").replace(/\./g, "")

    relleno: 14
}
