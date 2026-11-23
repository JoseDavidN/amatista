// ==========================================================
// Actualizaciones pendientes: solo se ve si hay alguna
// Clic: lista y botón para actualizar · Derecho: comprobar ahora
// ==========================================================
import QtQuick
import qs.Comun

Pildora {
    id: mod

    readonly property var s: ServicioActualizaciones

    visible: s.total > 0 || panel.abierto
    icono: String.fromCodePoint(0xf03d7)
    colorIcono: Tema.lima
    texto: String(s.total)
    tooltip: s.comprobando ? "Comprobando…"
           : [s.arch.length ? s.arch.length + " de Arch" : "", s.aur.length ? s.aur.length + " de AUR" : ""].filter(t => t).join(" · ")

    PanelActualizaciones {
        id: panel
        objetivo: mod
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
    onClicDerecho: s.comprobar()
}
