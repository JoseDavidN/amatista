// ==========================================================
// Panel de Bluetooth
// - Encender / apagar, buscar dispositivos
// - Conectar, desconectar y emparejar con un clic
// El estado se lee con el modulo nativo de Quickshell; las acciones
// usan bluetoothctl, que es mas fiable para emparejar y conectar.
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Comun

PanelEmergente {
    id: panel

    titulo: "Bluetooth"
    icono: "󰂯"
    colorIcono: Tema.acento

    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property bool encendido: adaptador !== null && adaptador.enabled
    readonly property bool buscando: adaptador !== null && adaptador.discovering

    // Acciones en curso: direccion -> "conectando" | "desconectando" | "emparejando"
    property var pendientes: ({})
    property int revision: 0

    function nombre(d) {
        return String(d.name || d.deviceName || d.address || "Dispositivo");
    }

    function conocido(d) {
        return d.connected || d.paired || d.bonded;
    }

    // Los dispositivos sin nombre real (solo direccion) no se muestran
    function tieneNombre(d) {
        const n = String(d.name || d.deviceName || "");
        return n !== "" && !/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(n);
    }

    readonly property var dispositivos: {
        const r = [];
        const lista = Bluetooth.devices.values;
        for (let i = 0; i < lista.length; i++) r.push(lista[i]);
        r.sort((a, b) => (b.connected - a.connected) || panel.nombre(a).localeCompare(panel.nombre(b)));
        return r;
    }
    readonly property var misDispositivos: dispositivos.filter(d => conocido(d))
    readonly property var cercanos: dispositivos.filter(d => !conocido(d) && tieneNombre(d))

    function iconoDe(d) {
        const i = String(d.icon || "");
        if (i.includes("headset") || i.includes("headphone") || i.includes("audio")) return "󰋋";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("gaming") || i.includes("joystick")) return "󰊗";
        if (i.includes("phone")) return "󰄜";
        if (i.includes("computer")) return "󰌢";
        if (i.includes("watch")) return "󰖉";
        return "󰂯";
    }

    function estado(d) {
        const p = pendientes[d.address];
        if (p === "conectando" && !d.connected) return "Conectando…";
        if (p === "emparejando" && !d.connected) return "Emparejando…";
        if (p === "desconectando" && d.connected) return "Desconectando…";
        if (d.connected) return "Conectado" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "% de batería" : "");
        if (d.paired || d.bonded) return "Emparejado";
        return "Clic para emparejar";
    }

    // La direccion se pasa como argumento ($1), nunca dentro del script
    function ejecutar(script, direccion) {
        Quickshell.execDetached(["sh", "-c", script, "sh", direccion]);
    }

    function marcar(d, accion) {
        const p = pendientes;
        p[d.address] = accion;
        pendientes = p;
        revision++;
        limpieza.restart();
    }

    function alPulsar(d) {
        if (d.connected) {
            marcar(d, "desconectando");
            ejecutar('timeout 10s bluetoothctl disconnect "$1"', d.address);
        } else if (d.paired || d.bonded) {
            marcar(d, "conectando");
            ejecutar('bluetoothctl trust "$1"; timeout 20s bluetoothctl connect "$1"', d.address);
        } else {
            marcar(d, "emparejando");
            ejecutar('timeout 25s bluetoothctl pair "$1"; bluetoothctl trust "$1"; timeout 20s bluetoothctl connect "$1"', d.address);
        }
    }

    function energia(encender) {
        Quickshell.execDetached(["sh", "-c", encender
            ? "rfkill unblock bluetooth; sleep 0.5; bluetoothctl power on"
            : "bluetoothctl power off"]);
    }

    // Busca dispositivos mientras el panel esta abierto
    Connections {
        target: panel
        function onAbiertoChanged() {
            if (panel.adaptador && panel.encendido) panel.adaptador.discovering = panel.abierto;
        }
        function onEncendidoChanged() {
            if (panel.adaptador && panel.encendido && panel.abierto) panel.adaptador.discovering = true;
        }
    }

    Timer {
        id: limpieza
        interval: 30000
        onTriggered: { panel.pendientes = ({}); panel.revision++; }
    }

    accesorio: Interruptor {
        activo: panel.encendido
        onAlternado: panel.energia(!panel.encendido)
    }

    // ---------- Mensajes de estado ----------
    Text {
        visible: panel.adaptador === null || !panel.encendido
        width: parent.width
        text: panel.adaptador === null ? "No se encontró un adaptador Bluetooth" : "Bluetooth apagado"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 13
    }

    // ---------- Mis dispositivos ----------
    TituloSeccion {
        visible: panel.encendido && panel.misDispositivos.length > 0
        texto: "Mis dispositivos"
    }

    Repeater {
        model: panel.encendido ? panel.misDispositivos : []

        delegate: FilaLista {
            required property var modelData
            icono: panel.iconoDe(modelData)
            colorIcono: modelData.connected ? Tema.cian : Tema.textoBarra
            titulo: panel.nombre(modelData)
            subtitulo: { panel.revision; return panel.estado(modelData); }
            colorSubtitulo: modelData.connected ? Tema.cian : Tema.tenue
            resaltada: modelData.connected
            detalle: modelData.connected ? "󰄬" : ""
            colorDetalle: Tema.cian
            onClic: panel.alPulsar(modelData)
        }
    }

    // ---------- Cercanos ----------
    TituloSeccion {
        visible: panel.encendido
        texto: "Dispositivos cercanos"
        extra: panel.buscando ? "Buscando…" : ""
    }

    Text {
        visible: panel.encendido && panel.cercanos.length === 0
        width: parent.width
        text: panel.buscando ? "Buscando dispositivos…" : "No hay dispositivos nuevos"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
    }

    Repeater {
        model: panel.encendido ? panel.cercanos.slice(0, 8) : []

        delegate: FilaLista {
            required property var modelData
            icono: panel.iconoDe(modelData)
            titulo: panel.nombre(modelData)
            subtitulo: { panel.revision; return panel.estado(modelData); }
            onClic: panel.alPulsar(modelData)
        }
    }

    // ---------- Pie ----------
    Item { width: 1; height: 2 }

    Row {
        spacing: 8

        BotonTexto {
            visible: panel.encendido
            icono: "󰑐"
            texto: panel.buscando ? "Detener búsqueda" : "Buscar"
            onClic: if (panel.adaptador) panel.adaptador.discovering = !panel.adaptador.discovering
        }

        BotonTexto {
            icono: "󰒓"
            texto: "Más opciones"
            onClic: {
                Quickshell.execDetached(["blueman-manager"]);
                panel.cerrar();
            }
        }
    }
}
