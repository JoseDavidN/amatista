// Micrófono o pantalla en uso: solo se ve mientras alguna app los usa
// Clic: panel de audio de PipeWire (pavucontrol), si es el micrófono
import QtQuick
import Quickshell
import qs.Comun

Pildora {
    readonly property var s: ServicioPrivacidad

    visible: s.microfono || s.pantalla
    icono: s.microfono ? String.fromCodePoint(0xf036c) : String.fromCodePoint(0xf1483)
    colorIcono: Tema.naranja
    icono2: s.microfono && s.pantalla ? String.fromCodePoint(0xf1483) : ""
    colorIcono2: Tema.naranja
    colorFondo: Tema.pildoraPeligro
    colorHover: Tema.pildoraPeligro
    tooltip: [s.microfono ? "Micrófono en uso: " + s.appsMicrofono.join(", ") : "",
              s.pantalla ? "Se está capturando " + s.detallePantalla : ""].filter(t => t).join("\n")

    onClicIzquierdo: if (s.microfono) Quickshell.execDetached(["pavucontrol", "--tab=2"])
}
