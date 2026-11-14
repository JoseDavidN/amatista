// ==========================================================
// Panel de audio (PipeWire nativo)
// - Volumen y silencio de la salida y del microfono
// - Elegir salida (parlantes, audifonos, HDMI...) y microfono
// - Volumen por aplicacion
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Comun

PanelEmergente {
    id: panel

    titulo: "Audio"
    icono: "󰕾"
    colorIcono: Tema.verde

    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource

    function filtrar(condicion) {
        const r = [];
        const lista = Pipewire.nodes.values;
        for (let i = 0; i < lista.length; i++) {
            const n = lista[i];
            if (n && n.audio && condicion(n)) r.push(n);
        }
        return r;
    }

    readonly property var salidas: filtrar(n => n.isSink && !n.isStream)
    readonly property var entradas: filtrar(n => !n.isSink && !n.isStream)
    readonly property var apps: filtrar(n => n.isStream && n.isSink)

    // PipeWire solo entrega volumen y estado de los nodos que se rastrean
    PwObjectTracker {
        objects: panel.salidas.concat(panel.entradas, panel.apps)
    }

    function nombreNodo(n) {
        return String(n.description || n.nickname || n.name || "Dispositivo");
    }

    function nombreApp(n) {
        const p = n.properties || {};
        return String(p["application.name"] || n.description || p["media.name"] || n.name || "Aplicación");
    }

    function iconoSalida(n) {
        const t = (String(n.name) + " " + String(n.description)).toLowerCase();
        if (t.includes("headphone") || t.includes("headset") || t.includes("bluez") || t.includes("auricular")) return "󰋋";
        if (t.includes("hdmi") || t.includes("displayport")) return "󰔂";
        return "󰓃";
    }

    function predeterminar(n) {
        Quickshell.execDetached(["wpctl", "set-default", String(n.id)]);
    }

    // ---------- Salida ----------
    TituloSeccion { texto: "Salida" }

    ControlVolumen {
        nodo: panel.salida
        icono: panel.salida ? panel.iconoSalida(panel.salida) : "󰓃"
        iconoSilencio: "󰖁"
    }

    Repeater {
        model: panel.salidas.length > 1 ? panel.salidas : []

        delegate: FilaLista {
            required property var modelData
            icono: panel.iconoSalida(modelData)
            titulo: panel.nombreNodo(modelData)
            resaltada: modelData === panel.salida
            detalle: resaltada ? "󰄬" : ""
            colorDetalle: Tema.acento
            onClic: panel.predeterminar(modelData)
        }
    }

    // ---------- Microfono ----------
    TituloSeccion {
        visible: panel.entrada !== null
        texto: "Micrófono"
    }

    ControlVolumen {
        visible: panel.entrada !== null
        nodo: panel.entrada
        icono: "󰍬"
        iconoSilencio: "󰍭"
        colorIcono: Tema.acento
    }

    Repeater {
        model: panel.entradas.length > 1 ? panel.entradas : []

        delegate: FilaLista {
            required property var modelData
            icono: "󰍬"
            titulo: panel.nombreNodo(modelData)
            resaltada: modelData === panel.entrada
            detalle: resaltada ? "󰄬" : ""
            colorDetalle: Tema.acento
            onClic: panel.predeterminar(modelData)
        }
    }

    // ---------- Aplicaciones ----------
    TituloSeccion {
        visible: panel.apps.length > 0
        texto: "Aplicaciones"
    }

    Repeater {
        model: panel.apps

        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 2

            Text {
                width: parent.width
                text: panel.nombreApp(modelData)
                color: Tema.suave
                font.family: Tema.fuenteBarra
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            ControlVolumen {
                nodo: modelData
                icono: "󰎇"
                iconoSilencio: "󰖁"
                colorIcono: Tema.morado
            }
        }
    }

    // ---------- Pie ----------
    Item { width: 1; height: 2 }

    Row {
        spacing: 8

        BotonTexto {
            icono: "󰒓"
            texto: "Ajustes avanzados"
            onClic: {
                Quickshell.execDetached(["pavucontrol"]);
                panel.cerrar();
            }
        }
    }
}
