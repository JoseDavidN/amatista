// ==========================================================
// Notificaciones: campana con las que no se han leído
// Clic: historial · Derecho: no molestar · Central: borrar el historial
// ==========================================================
import QtQuick
import qs.Comun
import qs.notificaciones

Pildora {
    id: mod

    icono: String.fromCodePoint(Centro.noMolestar ? 0xf009b : 0xf009a)
    colorIcono: Centro.noMolestar ? Tema.tenue : Centro.sinLeer > 0 ? Tema.rosa : Tema.suave
    texto: Centro.sinLeer > 0 ? String(Centro.sinLeer) : ""
    tooltip: Centro.noMolestar ? "No molestar activado\nClic derecho para desactivarlo"
           : Centro.sinLeer > 0 ? Centro.sinLeer + " sin leer" : "Sin notificaciones nuevas"

    PanelNotificaciones {
        id: panel
        objetivo: mod
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
    onClicDerecho: Centro.noMolestar = !Centro.noMolestar
    onClicCentral: Centro.limpiar()
}
