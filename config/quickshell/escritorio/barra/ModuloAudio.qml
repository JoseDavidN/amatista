// ==========================================================
// Volumen (PipeWire nativo)
// Rueda: +/- 5% · Clic: panel de audio · Derecho: pavucontrol · Central: silenciar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Comun
import qs.paneles

Pildora {
    id: mod

    readonly property string home: Quickshell.env("HOME")
    readonly property var salida: Pipewire.defaultAudioSink
    readonly property bool lista: salida !== null && salida.audio !== null
    readonly property int volumen: lista ? Math.round(salida.audio.volume * 100) : 0
    readonly property bool silenciado: lista && salida.audio.muted
    readonly property bool audifonos: {
        if (!salida) return false;
        const t = (String(salida.name) + " " + String(salida.description)).toLowerCase();
        return t.includes("headphone") || t.includes("headset") || t.includes("auricular") || t.includes("bluez");
    }

    // Necesario para que PipeWire entregue volumen y estado de la salida
    PwObjectTracker {
        objects: mod.salida ? [mod.salida] : []
    }

    icono: silenciado ? ""
         : audifonos ? ""
         : volumen < 34 ? ""
         : volumen < 67 ? ""
         : ""
    colorIcono: silenciado ? Tema.error : Tema.verde
    texto: silenciado ? "mute" : volumen + "%"
    tooltip: salida ? String(salida.description || salida.name) : "Sin salida de audio"

    onRueda: pasos => {
        if (!lista) return;
        salida.audio.volume = Math.max(0, Math.min(1, salida.audio.volume + pasos * 0.05));
    }
    PanelAudio {
        id: panel
        objetivo: mod
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
    onClicDerecho: Quickshell.execDetached(["pavucontrol"])
    onClicCentral: if (lista) salida.audio.muted = !salida.audio.muted
}
