// ==========================================================
// Qué apps usan el micrófono y si se está capturando la pantalla
//
// Micrófono: flujos de PipeWire que graban de una entrada de verdad (los que
// escuchan la salida, como el visualizador de música, no cuentan).
// Pantalla: eventos "screencastv2" de Hyprland. Las capturas instantáneas se
// ignoran. Una captura que empezó antes que el escritorio no se detecta
// hasta que vuelva a empezar.
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Singleton {
    id: servicio

    // ---------- Micrófono ----------
    readonly property var grupos: Pipewire.linkGroups.values.filter(g =>
        g && g.source && g.target && !g.source.isSink && !g.source.isStream && g.target.isStream)

    // Necesario para conocer el estado de cada enlace y los datos de la app
    PwObjectTracker {
        objects: servicio.grupos.concat(servicio.grupos.map(g => g.target))
    }

    readonly property var appsMicrofono: {
        const r = [];
        for (const g of grupos) {
            if (g.state !== PwLinkState.Active) continue;
            const p = g.target.properties || {};
            const n = String(p["application.name"] || g.target.description || g.target.name || "Una aplicación");
            // El medidor de pavucontrol no graba
            if (/pavucontrol|control de volumen|volume control/i.test(n + " " + g.target.name)) continue;
            if (r.indexOf(n) < 0) r.push(n);
        }
        return r;
    }
    readonly property bool microfono: appsMicrofono.length > 0

    // ---------- Pantalla ----------
    property var capturas: ({})       // "monitor,HDMI-A-1" -> cuántas
    readonly property bool capturando: Object.keys(capturas).some(k => capturas[k] > 0)
    readonly property bool soloVentana: !Object.keys(capturas).some(k => capturas[k] > 0 && !k.startsWith("window"))
    property bool pantalla: false     // lo mismo, sin parpadeos
    property string detallePantalla: ""

    onCapturandoChanged: {
        if (capturando) {
            fin.stop();
            if (!pantalla) comienzo.restart();
        } else {
            comienzo.stop();
            if (pantalla) fin.restart();
        }
    }

    Timer {
        id: comienzo
        interval: 1500
        onTriggered: {
            servicio.detallePantalla = servicio.soloVentana ? "una ventana" : "la pantalla";
            servicio.pantalla = true;
        }
    }
    // Algunos programas paran de capturar mientras nada se mueve
    Timer {
        id: fin
        interval: 8000
        onTriggered: servicio.pantalla = false
    }

    Connections {
        target: Hyprland
        function onRawEvent(evento) {
            if (evento.name !== "screencastv2") return;
            const i = evento.data.indexOf(",");
            const clave = evento.data.slice(i + 1);
            const c = Object.assign({}, servicio.capturas);
            c[clave] = Math.max(0, (c[clave] || 0) + (evento.data.slice(0, i) === "1" ? 1 : -1));
            if (c[clave] === 0) delete c[clave];
            servicio.capturas = c;
        }
    }
}
