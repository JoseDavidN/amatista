// ==========================================================
// Multimedia (MPRIS nativo): icono de musica + nombre de la cancion
// Clic: panel de multimedia · Central: reproducir/pausa
// Solo aparece si hay algun reproductor abierto.
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Comun
import qs.paneles

Pildora {
    id: mod

    readonly property int maxCaracteres: 32

    readonly property var reproductores: Mpris.players.values
    // Fuente elegida a mano en el panel (null = automatico)
    property var elegido: null

    // Reproductor activo: el elegido si sigue abierto; si no, el que este
    // sonando; si ninguno suena, el primero de la lista
    readonly property var actual: {
        const l = reproductores;
        if (elegido && l.indexOf(elegido) >= 0) return elegido;
        for (let i = 0; i < l.length; i++)
            if (l[i].isPlaying) return l[i];
        return l.length > 0 ? l[0] : null;
    }

    readonly property string cancion: actual && actual.trackTitle ? actual.trackTitle : "Sin título"

    visible: actual !== null

    icono: "󰎆"
    colorIcono: actual && actual.isPlaying ? Tema.rosa : Tema.tenue
    texto: cancion.length > maxCaracteres ? cancion.slice(0, maxCaracteres - 1).trim() + "…" : cancion
    tooltip: actual ? [actual.trackArtist, actual.identity].filter(t => t).join(" · ") : ""

    PanelMultimedia {
        id: panel
        objetivo: mod
        reproductor: mod.actual
        onSeleccionar: r => mod.elegido = r
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
    onClicCentral: if (actual && actual.canTogglePlaying) actual.togglePlaying()
}
